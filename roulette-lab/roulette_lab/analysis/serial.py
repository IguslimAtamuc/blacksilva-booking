"""Relatia dintre pozitia in secventa si rezultat.

Doua intrebari distincte:
  a) conteaza pozitia modulo m? (ex. "fiecare a 5-a rotire e verde")
  b) exista un trend in timp? (ex. verde apare tot mai des pe masura ce joci)
"""
from __future__ import annotations

import math
from collections import Counter

from ..data.schema import Dataset
from ..stats.tests import chi2_independence, permutation_test
from ._util import adaptive_iterations
from .base import AnalysisResult, register, skipped


def modulo_chi2(values, symbols, m: int) -> float:
    table = [[0] * len(symbols) for _ in range(m)]
    index = {s: j for j, s in enumerate(symbols)}
    for i, v in enumerate(values):
        table[i % m][index[v]] += 1
    return chi2_independence(table).statistic


@register("serial_position")
def analyze_serial_position(ds: Dataset, seed: int = 12345, max_mod: int = 12,
                            **_) -> AnalysisResult:
    values = ds.values
    symbols = ds.symbols
    n = len(values)
    if n < 60:
        return skipped("serial_position", "Pozitie in secventa vs. rezultat",
                       "Rezultatul depinde de pozitia rotirii in secventa?",
                       f"Necesare minim 60 de rotiri (sunt {n}).", 60, n)

    mods = [m for m in range(2, max_mod + 1) if n // m >= 10]
    if not mods:
        return skipped("serial_position", "Pozitie in secventa vs. rezultat",
                       "Rezultatul depinde de pozitia rotirii?",
                       "Prea putine rotiri pe clasa de rest.", 60, n)

    def max_mod_chi2(seq) -> float:
        return max(modulo_chi2(seq, symbols, m) for m in mods)

    observed = max_mod_chi2(values)
    outcome = permutation_test(values, max_mod_chi2,
                               adaptive_iterations(n, 2000, len(mods)), seed, "greater")
    per_mod = {m: modulo_chi2(values, symbols, m) for m in mods}
    best_mod = max(per_mod, key=per_mod.get)

    # Trend: se schimba frecventele monoton de la inceput spre sfarsit?
    # Testul Cochran-Armitage pe simbolul cel mai frecvent.
    top_symbol = Counter(values).most_common(1)[0][0]
    indicator = [1 if v == top_symbol else 0 for v in values]
    mean_x = (n - 1) / 2
    sxx = sum((i - mean_x) ** 2 for i in range(n))
    p_hat = sum(indicator) / n
    slope_num = sum((i - mean_x) * indicator[i] for i in range(n))
    var = p_hat * (1 - p_hat) * sxx
    z_trend = slope_num / math.sqrt(var) if var > 0 else 0.0
    from ..stats.distributions import norm_two_sided
    p_trend = norm_two_sided(z_trend)

    explanation = (
        f"(a) Pozitie modulo m: am testat m = {mods[0]}..{mods[-1]}. Cea mai mare "
        f"dependenta apare la m = {best_mod} (hi-patrat = {per_mod[best_mod]:.2f}); "
        f"p pentru maximul pe toti m = {outcome.p_value:.4f} (permutare). "
        f"(b) Trend in timp pentru {ds.label(top_symbol)}: z = {z_trend:+.2f}, "
        f"p = {p_trend:.4f}. "
    )
    if outcome.p_value >= 0.05 and p_trend >= 0.05:
        explanation += (
            "Nici pozitia rotirii, nici trecerea timpului nu influenteaza rezultatul. "
            "Adica: nu exista 'a n-a rotire e mereu verde' si nici deriva a sanselor "
            "pe masura ce joci."
        )
    else:
        explanation += "Exista o relatie intre pozitie si rezultat -- de investigat."

    return AnalysisResult(
        key="serial_position", title="Pozitie in secventa vs. rezultat",
        question="Rezultatul depinde de pozitia rotirii sau deriveaza in timp?",
        statistic=observed, statistic_name="hi-patrat maxim pe modulo",
        p_value=min(1.0, min(outcome.p_value, p_trend) * 2),  # doua intrebari: Bonferroni intern
        p_method="permutation + normal",
        effect=math.sqrt(observed / max(1, n)), effect_name="V (Cramer) aproximativ",
        n_used=n, min_n=60, recommended_n=400,
        explanation=explanation,
        detail={"per_modulo_chi2": per_mod, "best_modulo": best_mod,
                "trend_z": z_trend, "trend_p": p_trend, "trend_symbol": top_symbol,
                "p_modulo": outcome.p_value},
    )
