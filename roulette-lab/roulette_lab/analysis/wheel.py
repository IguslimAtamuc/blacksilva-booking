"""Compara datele cu modelul unei rulete fizice standard.

Intrebare de reverse engineering: jocul simuleaza o ruleta reala (37 sloturi,
18 rosii / 18 negre / 1 verde) sau foloseste propriile probabilitati?
Raspunsul spune ce fel de generator cautam mai departe.
"""
from __future__ import annotations

import random
from collections import Counter

from ..data.schema import Dataset
from ..stats.tests import chi2_gof, monte_carlo_p
from ._util import adaptive_iterations, cohens_w
from .base import AnalysisResult, register, skipped

# Modele candidate: nume -> probabilitati pe simbolurile R/N/V
WHEEL_MODELS: dict[str, dict[str, float]] = {
    "europeana_37": {"R": 18 / 37, "N": 18 / 37, "V": 1 / 37},
    "americana_38": {"R": 18 / 38, "N": 18 / 38, "V": 2 / 38},
    "uniforma_3":   {"R": 1 / 3, "N": 1 / 3, "V": 1 / 3},
    "crash_style":  {"R": 0.47, "N": 0.47, "V": 0.06},
}


@register("wheel_model")
def analyze_wheel_model(ds: Dataset, seed: int = 12345, **_) -> AnalysisResult:
    if ds.preset != "color3":
        return skipped("wheel_model", "Model de ruleta",
                       "Datele corespund unei rulete fizice standard?",
                       "Se aplica doar alfabetului de culori R/N/V.")
    values = ds.values
    n = len(values)
    if n < 30:
        return skipped("wheel_model", "Model de ruleta",
                       "Datele corespund unei rulete fizice standard?",
                       f"Necesare minim 30 de rotiri (sunt {n}).", 30, n)

    symbols = ["R", "N", "V"]
    counts = [Counter(values).get(s, 0) for s in symbols]
    scores: dict[str, dict] = {}
    for model_name, probs in WHEEL_MODELS.items():
        expected = [probs[s] * n for s in symbols]
        outcome = chi2_gof(counts, expected)
        p_value, method = outcome.p_value, outcome.method
        if min(expected) < 5:
            def sample(rng: random.Random, pr=probs) -> float:
                draw = Counter(rng.choices(symbols, weights=[pr[s] for s in symbols], k=n))
                return sum((draw.get(s, 0) - pr[s] * n) ** 2 / (pr[s] * n) for s in symbols)
            mc = monte_carlo_p(outcome.statistic, sample, adaptive_iterations(n, 20000), seed)
            p_value, method = mc.p_value, "monte-carlo"
        scores[model_name] = {"chi2": outcome.statistic, "p": p_value, "method": method,
                              "expected": dict(zip(symbols, expected))}

    best = min(scores, key=lambda m: scores[m]["chi2"])
    # Testul principal: se potriveste ruleta europeana? (modelul de referinta)
    ref = scores["europeana_37"]
    w = cohens_w(counts, [WHEEL_MODELS["europeana_37"][s] * n for s in symbols])
    observed = {s: counts[i] / n for i, s in enumerate(symbols)}

    compatible = [m for m, v in scores.items() if v["p"] >= 0.05]
    explanation = (
        f"Frecventa observata a Verde este {observed['V']*100:.1f}%. Pe o ruleta "
        f"europeana reala ar trebui sa fie 2.7% (1 slot din 37), pe una americana 5.3%. "
        f"Test contra modelului european: hi-patrat = {ref['chi2']:.2f}, p = {ref['p']:.4g}. "
    )
    if ref["p"] < 0.05:
        explanation += (
            "Datele sunt INCOMPATIBILE cu o ruleta europeana standard. Concluzia de "
            "reverse engineering: jocul nu simuleaza o roata fizica de 37 de sloturi, "
            "ci foloseste propriile probabilitati -- probabil un simplu apel de tip "
            "random() comparat cu praguri fixe. Asta reduce spatiul de generatoare "
            "candidate si inseamna ca nu are rost sa cautam structura de roata fizica."
        )
    else:
        explanation += ("Datele sunt compatibile cu o ruleta europeana standard.")
    explanation += (
        f" Modelul cel mai apropiat dintre cele testate: {best}. "
        f"Compatibile la p>=0.05: {', '.join(compatible) if compatible else 'niciunul'}."
    )

    return AnalysisResult(
        key="wheel_model", title="Model de ruleta (fizica vs. software)",
        question="Datele corespund unei rulete fizice standard sau unor probabilitati proprii?",
        statistic=ref["chi2"], statistic_name="hi-patrat vs. ruleta europeana",
        p_value=ref["p"], p_method=ref["method"], df=2,
        effect=w, effect_name="w (Cohen)", effect_note="fata de modelul european",
        n_used=n, min_n=30, recommended_n=150,
        explanation=explanation,
        detail={"observed": observed, "models": scores, "best_fit": best,
                "compatible_models": compatible},
    )
