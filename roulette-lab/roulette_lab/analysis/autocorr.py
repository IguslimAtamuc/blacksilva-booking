"""Autocorelatie: rezultatul de acum depinde de cel de acum k rotiri?"""
from __future__ import annotations

import math

from ..data.schema import Dataset
from ..stats.tests import permutation_test
from ._util import adaptive_iterations, collision_probability
from .base import AnalysisResult, register, skipped


def agreement_profile(values, max_lag: int) -> list[float]:
    """Rata de coincidenta la fiecare decalaj: P(x_i == x_{i+k})."""
    out = []
    for k in range(1, max_lag + 1):
        pairs = len(values) - k
        if pairs <= 0:
            out.append(0.0)
            continue
        out.append(sum(1 for i in range(pairs) if values[i] == values[i + k]) / pairs)
    return out


@register("autocorrelation")
def analyze_autocorrelation(ds: Dataset, seed: int = 12345, max_lag: int | None = None,
                            **_) -> AnalysisResult:
    values = ds.values
    n = len(values)
    if n < 50:
        return skipped("autocorrelation", "Autocorelatie",
                       "Rezultatul depinde de rezultatul de acum k rotiri?",
                       f"Necesare minim 50 de rotiri (sunt {n}).", 50, n)

    lag_max = max_lag or min(40, n // 4)
    baseline = collision_probability(values)
    profile = agreement_profile(values, lag_max)

    # Statistica = cea mai mare abatere pe orice decalaj. Folosind maximul,
    # testul de permutare corecteaza automat pentru cele `lag_max` decalaje
    # verificate -- nu putem "alege decalajul norocos" dupa ce vedem datele.
    def max_deviation(seq) -> float:
        prof = agreement_profile(seq, lag_max)
        return max(abs(a - baseline) for a in prof)

    observed = max(abs(a - baseline) for a in profile)
    outcome = permutation_test(values, max_deviation,
                               adaptive_iterations(n, 3000, lag_max), seed, "greater")

    best_lag = max(range(lag_max), key=lambda i: abs(profile[i] - baseline)) + 1
    # eroare standard aproximativa a ratei de coincidenta la un decalaj
    se = math.sqrt(baseline * (1 - baseline) / max(1, n - best_lag))
    z = (profile[best_lag - 1] - baseline) / se if se > 0 else 0.0

    explanation = (
        f"Sub independenta, doua rotiri coincid in {baseline*100:.1f}% din cazuri "
        f"(asta rezulta doar din frecventele culorilor, nu din vreo memorie). "
        f"Am verificat decalajele 1..{lag_max}. Cea mai mare abatere apare la "
        f"decalajul {best_lag}: coincidenta {profile[best_lag-1]*100:.1f}% "
        f"(z = {z:+.2f}). p = {outcome.p_value:.4f} pentru maximul pe toate decalajele "
        f"(test de permutare). "
    )
    if outcome.p_value >= 0.05:
        explanation += (
            "Nicio autocorelatie peste nivelul hazardului. Concret: cunoasterea "
            f"rezultatului de acum {best_lag} rotiri nu iti spune nimic despre urmatorul. "
            "Observatie importanta: intr-o serie de decalaje verificate, unul va parea "
            "mereu 'cel mai bun' -- de asta testam maximul, nu fiecare decalaj separat."
        )
    else:
        explanation += (
            f"Exista autocorelatie reala la decalajul {best_lag}. Acesta este un semnal "
            "exploatabil: verifica daca modelul Markov si backtesting-ul il confirma "
            "out-of-sample."
        )

    return AnalysisResult(
        key="autocorrelation", title="Autocorelatie",
        question="Rezultatul curent depinde de rezultatul de acum k rotiri?",
        statistic=observed, statistic_name="abatere maxima a coincidentei",
        p_value=outcome.p_value, p_method="permutation",
        effect=observed, effect_name="abatere absoluta",
        effect_note="fata de rata de coincidenta a hazardului",
        n_used=n, min_n=50, recommended_n=400,
        explanation=explanation,
        detail={"baseline": baseline, "max_lag": lag_max, "profile": profile,
                "best_lag": best_lag, "best_z": z,
                "null_p95": outcome.detail.get("null_p95")},
    )
