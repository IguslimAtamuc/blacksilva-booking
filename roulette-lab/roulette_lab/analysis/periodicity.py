"""Periodicitate spectrala: exista o perioada ascunsa in secventa?

Un generator cu perioada scurta, o lista de rezultate pre-generata care se
reia, sau o rotatie fixa ar produce un varf clar in periodograma.
"""
from __future__ import annotations

import math

from ..data.schema import Dataset
from ..stats.tests import permutation_test
from ._util import adaptive_iterations
from .base import AnalysisResult, register, skipped


def build_tables(n: int, periods: list[int]) -> list[tuple[list[float], list[float], float, float]]:
    """Precalculeaza cos/sin pentru fiecare perioada.

    Optimizare esentiala: tabelele nu depind de date, ci doar de lungimea
    secventei, deci se calculeaza O SINGURA DATA si se refolosesc la toate cele
    cateva mii de permutari. Fara ele, testul spectral domina timpul de rulare
    (17s din 25s masurate) pentru ca apeleaza exp() complex de milioane de ori.
    """
    tables = []
    for period in periods:
        omega = 2.0 * math.pi / period
        cos_t = [math.cos(omega * i) for i in range(n)]
        sin_t = [math.sin(omega * i) for i in range(n)]
        tables.append((cos_t, sin_t, sum(cos_t), sum(sin_t)))
    return tables


def max_power_from_positions(positions_by_symbol: dict[str, list[int]], n: int,
                             tables) -> float:
    """Cea mai mare putere spectrala, calculata direct din pozitiile fiecarui simbol.

    Pentru o serie indicator 0/1, suma peste toti indicii se reduce la o suma
    peste pozitiile unde apare simbolul -- deci simbolurile rare (ex. Verde)
    costa aproape nimic.
    """
    best = 0.0
    for positions in positions_by_symbol.values():
        k = len(positions)
        if k < 2 or k >= n:
            continue
        mean = k / n
        variance = k - k * k / n          # suma patratelor seriei centrate
        if variance <= 0:
            continue
        for cos_t, sin_t, sum_c, sum_s in tables:
            re = 0.0
            im = 0.0
            for i in positions:
                re += cos_t[i]
                im += sin_t[i]
            re -= mean * sum_c
            im -= mean * sum_s
            power = 2.0 * (re * re + im * im) / variance
            if power > best:
                best = power
    return best


def periodogram(indicator: list[float], periods: list[int]) -> list[float]:
    """Puterea spectrala normalizata pentru fiecare perioada candidata.

    Sub ipoteza nula, fiecare ordonata are aproximativ distributia chi-patrat cu
    2 grade de libertate -- de aceea o valoare de 8-10 pare mare pana realizezi
    cate perioade au fost verificate. Testul de permutare rezolva exact aceasta
    problema de comparatii multiple.
    """
    n = len(indicator)
    if n == 0:
        return [0.0] * len(periods)
    mean = sum(indicator) / n
    centered = [x - mean for x in indicator]
    variance = sum(x * x for x in centered)
    if variance <= 0:
        return [0.0] * len(periods)
    out = []
    for cos_t, sin_t, _, _ in build_tables(n, periods):
        re = sum(c * x for c, x in zip(cos_t, centered))
        im = sum(sv * x for sv, x in zip(sin_t, centered))
        out.append(2.0 * (re * re + im * im) / variance)
    return out


@register("periodicity")
def analyze_periodicity(ds: Dataset, seed: int = 12345, max_period: int | None = None,
                        **_) -> AnalysisResult:
    values = ds.values
    n = len(values)
    if n < 60:
        return skipped("periodicity", "Periodicitate (analiza spectrala)",
                       "Secventa are o perioada ascunsa / se reia un ciclu?",
                       f"Necesare minim 60 de rotiri (sunt {n}).", 60, n)

    # Cerem cel putin 4 repetari complete ale unei perioade ca sa o consideram
    # detectabila: sub atat, un "ciclu" nu se distinge de o coincidenta.
    top = max_period or min(40, max(4, n // 4))
    periods = list(range(2, top + 1))
    symbols = [s for s in ds.symbols if values.count(s) >= 5]
    if not symbols or len(periods) < 2:
        return skipped("periodicity", "Periodicitate (analiza spectrala)",
                       "Secventa are o perioada ascunsa?",
                       "Prea putine aparitii pe simbol pentru analiza spectrala.", 60, n)

    tables = build_tables(n, periods)

    def max_power(seq) -> float:
        positions: dict[str, list[int]] = {s: [] for s in symbols}
        for i, v in enumerate(seq):
            if v in positions:
                positions[v].append(i)
        return max_power_from_positions(positions, n, tables)

    observed = max_power(values)
    # Maximul peste toate perioadele SI toate simbolurile: testul de permutare
    # corecteaza intrinsec pentru cate ipoteze am incercat.
    outcome = permutation_test(values, max_power,
                               adaptive_iterations(n, 2000, len(periods), floor=500),
                               seed, "greater")

    spectra = {}
    for sym in symbols:
        ind = [1.0 if v == sym else 0.0 for v in values]
        spectra[sym] = periodogram(ind, periods)
    best_sym = max(spectra, key=lambda s: max(spectra[s]))
    best_period = periods[spectra[best_sym].index(max(spectra[best_sym]))]

    explanation = (
        f"Am cautat perioade intre 2 si {top} rotiri, pe seria indicator a fiecarui "
        f"simbol cu cel putin 5 aparitii. Cel mai puternic varf: perioada {best_period} "
        f"pentru {ds.label(best_sym)}, putere = {observed:.2f}. Sub ipoteza de "
        f"independenta, cel mai mare varf ajunge in medie la {outcome.detail['null_mean']:.2f} "
        f"(prag 95%: {outcome.detail['null_p95']:.2f}). p = {outcome.p_value:.4f}. "
    )
    if outcome.p_value >= 0.05:
        explanation += (
            "Nu exista periodicitate. Un varf trebuie sa fie mare intr-un mod care nu "
            "poate fi explicat prin numarul de perioade verificate -- aici nu este. "
            "Daca ruleta ar folosi o lista pre-generata scurta care se reia, acest test "
            "ar detecta-o clar."
        )
    else:
        explanation += (
            f"Exista o componenta periodica reala la perioada {best_period}. Aceasta "
            "este cea mai puternica pista de reverse engineering posibila din date: "
            "verifica daca perioada corespunde unei lungimi de lista pre-generate sau "
            "unei perioade scurte de generator."
        )

    return AnalysisResult(
        key="periodicity", title="Periodicitate (analiza spectrala)",
        question="Exista o perioada ascunsa dupa care se reia secventa?",
        statistic=observed, statistic_name="puterea spectrala maxima",
        p_value=outcome.p_value, p_method="permutation",
        effect=observed - outcome.detail["null_mean"], effect_name="putere peste asteptare",
        n_used=n, min_n=60, recommended_n=400,
        explanation=explanation,
        detail={"periods": periods, "spectra": spectra, "best_symbol": best_sym,
                "best_period": best_period, "null_mean": outcome.detail["null_mean"],
                "null_p95": outcome.detail["null_p95"]},
    )
