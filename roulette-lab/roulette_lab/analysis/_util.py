"""Utilitare partajate de analizoare."""
from __future__ import annotations

import math
from collections import Counter
from typing import Sequence

from ..stats.distributions import chi2_sf


def probs_from(values: Sequence[str], symbols: Sequence[str], laplace: float = 0.0) -> dict[str, float]:
    counts = Counter(values)
    total = len(values) + laplace * len(symbols)
    if total <= 0:
        return {s: 1.0 / len(symbols) for s in symbols}
    return {s: (counts.get(s, 0) + laplace) / total for s in symbols}


def collision_probability(values: Sequence[str]) -> float:
    """P(doua rotiri independente dau acelasi simbol) = suma p_i^2.

    Este linia de baza corecta pentru orice test de tip "cat de des se repeta":
    intr-o ruleta cu 49% rosu, doua rotiri consecutive coincid in ~40% din
    cazuri CHIAR DACA sunt complet independente.
    """
    counts = Counter(values)
    n = len(values)
    if n < 2:
        return 0.0
    return sum((c / n) ** 2 for c in counts.values())


def adaptive_iterations(n: int, base: int = 5000, cost: int = 1,
                        budget: int = 4_000_000, floor: int = 1000) -> int:
    """Numarul de iteratii de permutare, ajustat ca timpul de rulare sa ramana rezonabil.

    Exista un prag de jos pentru ca rezolutia p-ului este 1/(iteratii+1): cu 500
    de iteratii cel mai mic p raportabil este 0.002, suficient pentru a compara
    cu alfa=0.05 dupa corectie, dar nu si pentru afirmatii mai fine de atat.
    Testele scumpe (spectral) folosesc pragul redus; restul, cel implicit.
    """
    per_iteration = max(1, n * cost)
    return max(floor, min(base, budget // per_iteration))


def cramers_v(chi2: float, n: int, rows: int, cols: int) -> float:
    """Marimea efectului pentru chi-patrat: 0 = nimic, 0.1 mic, 0.3 mediu, 0.5 mare."""
    k = min(rows - 1, cols - 1)
    if n <= 0 or k <= 0:
        return 0.0
    return math.sqrt(chi2 / (n * k))


def cohens_w(observed: Sequence[float], expected: Sequence[float]) -> float:
    """Marimea efectului pentru goodness-of-fit."""
    n = sum(observed)
    if n <= 0:
        return 0.0
    total = 0.0
    for o, e in zip(observed, expected):
        if e > 0:
            total += (o / n - e / n) ** 2 / (e / n)
    return math.sqrt(total)


def chi2_ppf(p: float, df: int) -> float:
    """Cuantila chi-patrat prin bisectie pe functia de supravietuire."""
    lo, hi = 0.0, 10.0
    while chi2_sf(hi, df) > 1 - p:
        hi *= 2
        if hi > 1e7:
            break
    for _ in range(200):
        mid = (lo + hi) / 2
        if chi2_sf(mid, df) > 1 - p:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def chi2_power(df: int, lam: float, alpha: float = 0.05) -> float:
    """Puterea unui test chi-patrat cu parametru de necentralitate lam.

    Foloseste aproximarea Patnaik: chi-patrat necentrala se aproximeaza cu
    c * chi-patrat centrala, unde c = (df+2*lam)/(df+lam) si
    f = (df+lam)^2/(df+2*lam) grade de libertate.
    """
    if lam <= 0:
        return alpha
    crit = chi2_ppf(1 - alpha, df)
    c = (df + 2 * lam) / (df + lam)
    f = (df + lam) ** 2 / (df + 2 * lam)
    return chi2_sf(crit / c, f)   # f poate fi fractionar; gamma_q accepta asta


def lambda_for_power(df: int, power: float = 0.80, alpha: float = 0.05) -> float:
    """Parametrul de necentralitate necesar pentru puterea ceruta."""
    lo, hi = 0.0, 10.0
    while chi2_power(df, hi, alpha) < power and hi < 1e6:
        hi *= 2
    for _ in range(80):
        mid = (lo + hi) / 2
        if chi2_power(df, mid, alpha) < power:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def n_for_chi2_power(w: float, df: int, power: float = 0.80, alpha: float = 0.05) -> int:
    """Cate observatii sunt necesare pentru a detecta un efect de marime w.

    Relatia este lambda = n * w^2, deci n = lambda / w^2. Raspunde direct la
    intrebarea "cate rotiri trebuie sa colectez ca sa pot demonstra ceva?".
    """
    if w <= 0:
        return 10 ** 9
    return int(math.ceil(lambda_for_power(df, power, alpha) / (w * w)))


def entropy_bits(counts) -> float:
    counts = [c for c in counts if c > 0]
    total = sum(counts)
    if total <= 0:
        return 0.0
    return -sum((c / total) * math.log2(c / total) for c in counts)


def longest_repeat_length(values: Sequence[str]) -> int:
    """Lungimea celui mai lung sub-sir care apare de cel putin doua ori.

    Cautare binara pe lungime + hash-uri de sub-siruri: O(n log n).
    """
    n = len(values)
    if n < 2:
        return 0
    s = values if isinstance(values, str) else "\x01".join(values)
    unit = 1 if isinstance(values, str) else 2   # pas in caractere per simbol
    lo, hi, best = 1, n - 1, 0
    while lo <= hi:
        mid = (lo + hi) // 2
        width = mid * unit - (unit - 1)
        seen: set[str] = set()
        found = False
        for i in range(0, n - mid + 1):
            chunk = s[i * unit: i * unit + width]
            if chunk in seen:
                found = True
                break
            seen.add(chunk)
        if found:
            best = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def max_lag_match_run(values: Sequence[str]) -> tuple[int, int, int]:
    """Cea mai lunga potrivire a secventei cu ea insasi decalata -> (lungime, lag, start).

    Este exact tiparul pe care tool-urile de ruleta il numesc "ciclu":
    o bucata care se repeta identic dupa `lag` rotiri.
    """
    n = len(values)
    best = (0, 0, 0)
    for lag in range(1, n):
        run = 0
        for i in range(n - lag):
            if values[i] == values[i + lag]:
                run += 1
                if run > best[0]:
                    best = (run, lag, i - run + 1)
            else:
                run = 0
    return best
