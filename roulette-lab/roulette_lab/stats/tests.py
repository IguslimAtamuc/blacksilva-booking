"""Teste statistice: parametrice acolo unde ipotezele tin, altfel prin permutare.

Regula proiectului: cand o aproximatie asimptotica nu e valida (esantion mic,
frecvente asteptate < 5), NU raportam p-ul asimptotic ca si cum ar fi bun --
il inlocuim cu un p empiric obtinut prin simulare si marcam metoda folosita.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import Callable, Iterable, Sequence

from .distributions import binom_pmf, binom_sf, chi2_sf


@dataclass
class TestOutcome:
    """Rezultatul brut al unui test statistic."""

    statistic: float
    p_value: float
    method: str                      # "asymptotic" | "monte-carlo" | "exact"
    df: int | None = None
    detail: dict = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)


# --------------------------------------------------------------------------
# Teste de baza
# --------------------------------------------------------------------------
def binom_test(k: int, n: int, p: float, alternative: str = "two-sided") -> float:
    """Test binomial exact.

    `alternative`: "greater" (k mai mare decat asteptat), "less", "two-sided".
    Varianta two-sided foloseste metoda densitatii: insumam toate rezultatele
    cel putin la fel de improbabile ca cel observat.
    """
    if n <= 0:
        return 1.0
    k = max(0, min(n, k))
    if alternative == "greater":
        return binom_sf(k - 1, n, p)
    if alternative == "less":
        return 1.0 - binom_sf(k, n, p)
    observed = binom_pmf(k, n, p)
    total = 0.0
    for i in range(n + 1):
        pi = binom_pmf(i, n, p)
        if pi <= observed * (1 + 1e-9):
            total += pi
    return min(1.0, total)


def chi2_gof(observed: Sequence[float], expected: Sequence[float]) -> TestOutcome:
    """Test chi-patrat de concordanta (goodness-of-fit)."""
    if len(observed) != len(expected):
        raise ValueError("observed si expected trebuie sa aiba aceeasi lungime")
    stat = 0.0
    for o, e in zip(observed, expected):
        if e > 0:
            stat += (o - e) ** 2 / e
    df = len(observed) - 1
    warns = []
    small = [e for e in expected if e < 5]
    if small:
        warns.append(
            f"{len(small)} din {len(expected)} frecvente asteptate sunt sub 5 -- "
            "aproximatia chi-patrat nu este de incredere; foloseste varianta Monte Carlo."
        )
    return TestOutcome(stat, chi2_sf(stat, df), "asymptotic", df,
                       {"expected": list(expected)}, warns)


def chi2_independence(table: Sequence[Sequence[float]]) -> TestOutcome:
    """Test chi-patrat de independenta pe un tabel de contingenta."""
    rows = len(table)
    cols = len(table[0]) if rows else 0
    total = sum(sum(r) for r in table)
    if total <= 0 or rows < 2 or cols < 2:
        return TestOutcome(0.0, 1.0, "degenerate", 0, {}, ["tabel degenerat"])
    row_sums = [sum(r) for r in table]
    col_sums = [sum(table[i][j] for i in range(rows)) for j in range(cols)]
    stat = 0.0
    n_small = 0
    for i in range(rows):
        for j in range(cols):
            exp = row_sums[i] * col_sums[j] / total
            if exp < 5:
                n_small += 1
            if exp > 0:
                stat += (table[i][j] - exp) ** 2 / exp
    df = (rows - 1) * (cols - 1)
    warns = []
    if n_small:
        warns.append(
            f"{n_small} din {rows * cols} celule au frecventa asteptata sub 5 -- "
            "p-ul asimptotic este optimist."
        )
    return TestOutcome(stat, chi2_sf(stat, df), "asymptotic", df,
                       {"row_sums": row_sums, "col_sums": col_sums}, warns)


# --------------------------------------------------------------------------
# Teste bazate pe re-esantionare
# --------------------------------------------------------------------------
def monte_carlo_p(observed_stat: float, null_sample: Callable[[random.Random], float],
                  iterations: int = 10000, seed: int = 12345,
                  alternative: str = "greater") -> TestOutcome:
    """p empiric: cat de des produce ipoteza nula o statistica la fel de extrema?

    Foloseste corectia (hits + 1) / (iterations + 1), care garanteaza un p
    nenul si controleaza corect rata de eroare de tip I la simulari putine.
    """
    rng = random.Random(seed)
    hits = 0
    draws = []
    for _ in range(iterations):
        value = null_sample(rng)
        draws.append(value)
        if alternative == "greater":
            if value >= observed_stat:
                hits += 1
        elif alternative == "less":
            if value <= observed_stat:
                hits += 1
        else:
            hits += 1 if abs(value) >= abs(observed_stat) else 0
    p = (hits + 1) / (iterations + 1)
    draws.sort()
    return TestOutcome(
        observed_stat, p, "monte-carlo", None,
        {
            "iterations": iterations,
            "null_mean": sum(draws) / len(draws) if draws else 0.0,
            "null_p95": draws[int(0.95 * (len(draws) - 1))] if draws else 0.0,
            "null_max": draws[-1] if draws else 0.0,
        },
    )


def permutation_test(sequence: Sequence, statistic: Callable[[Sequence], float],
                     iterations: int = 5000, seed: int = 12345,
                     alternative: str = "greater") -> TestOutcome:
    """Test de permutare: amesteca secventa, pastrand frecventele marginale.

    Aceasta este ipoteza nula corecta pentru "exista structura temporala?":
    aceleasi simboluri, aceeasi compozitie, doar ordinea distrusa.
    """
    observed = statistic(sequence)
    items = list(sequence)

    def sample(rng: random.Random) -> float:
        rng.shuffle(items)
        return statistic(items)

    outcome = monte_carlo_p(observed, sample, iterations, seed, alternative)
    outcome.method = "permutation"
    return outcome


def sign_flip_test(differences: Sequence[float], iterations: int = 10000,
                   seed: int = 12345, alternative: str = "greater") -> TestOutcome:
    """Test pereche prin inversarea semnelor.

    Ipoteza nula: diferentele sunt simetrice in jurul lui 0. E testul potrivit
    pentru "modelul A are log-loss mai mic decat modelul B pe aceleasi spin-uri",
    pentru ca respecta imperecherea observatiilor si nu presupune normalitate.
    """
    n = len(differences)
    if n == 0:
        return TestOutcome(0.0, 1.0, "sign-flip", None, {}, ["fara observatii"])
    observed = sum(differences) / n
    values = list(differences)

    def sample(rng: random.Random) -> float:
        return sum(v if rng.random() < 0.5 else -v for v in values) / n

    outcome = monte_carlo_p(observed, sample, iterations, seed, alternative)
    outcome.method = "sign-flip"
    outcome.detail["n"] = n
    return outcome


def bootstrap_mean_ci(values: Sequence[float], confidence: float = 0.95,
                      iterations: int = 5000, seed: int = 12345) -> tuple[float, float, float]:
    """Interval de incredere bootstrap percentil pentru medie -> (medie, jos, sus)."""
    n = len(values)
    if n == 0:
        return (0.0, 0.0, 0.0)
    rng = random.Random(seed)
    mean = sum(values) / n
    means = []
    for _ in range(iterations):
        means.append(sum(values[rng.randrange(n)] for _ in range(n)) / n)
    means.sort()
    alpha = (1.0 - confidence) / 2.0
    lo = means[int(alpha * (iterations - 1))]
    hi = means[int((1 - alpha) * (iterations - 1))]
    return (mean, lo, hi)


# --------------------------------------------------------------------------
# Corectia pentru teste multiple
# --------------------------------------------------------------------------
def benjamini_hochberg(p_values: Sequence[float]) -> list[float]:
    """Corectie Benjamini-Hochberg -> q-values (rata de descoperiri false).

    Motivul pentru care exista in acest proiect: bateria noastra ruleaza ~9
    analizoare. La prag 0.05 si zero semnal real, sansa ca macar unul sa iasa
    "semnificativ" este ~37%. Fara aceasta corectie, tool-ul ar raporta cu
    incredere tipare inexistente -- exact defectul versiunii anterioare.
    """
    n = len(p_values)
    if n == 0:
        return []
    order = sorted(range(n), key=lambda i: p_values[i])
    q = [0.0] * n
    prev = 1.0
    for rank in range(n - 1, -1, -1):
        idx = order[rank]
        value = min(prev, p_values[idx] * n / (rank + 1))
        q[idx] = min(1.0, value)
        prev = q[idx]
    return q


def entropy_bits(counts: Iterable[float]) -> float:
    """Entropia Shannon in biti a unei distributii date prin frecvente."""
    counts = [c for c in counts if c > 0]
    total = sum(counts)
    if total <= 0:
        return 0.0
    return -sum((c / total) * math.log2(c / total) for c in counts)
