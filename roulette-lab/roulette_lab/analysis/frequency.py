"""Distributia rezultatelor: exista bias fata de ce ar trebui sa produca ruleta?"""
from __future__ import annotations

import random
from collections import Counter

from ..data.schema import Dataset
from ..stats.tests import chi2_gof, monte_carlo_p
from ._util import adaptive_iterations, cohens_w, n_for_chi2_power
from .base import AnalysisResult, register, skipped


@register("frequency")
def analyze_frequency(ds: Dataset, seed: int = 12345, **_) -> AnalysisResult:
    values = ds.values
    symbols = ds.symbols
    n = len(values)
    k = len(symbols)
    if n < 20 or k < 2:
        return skipped("frequency", "Distributia rezultatelor",
                       "Apar culorile/numerele cu frecventele asteptate?",
                       f"Necesare minim 20 de rotiri (sunt {n}).", 20, n)

    counts = [Counter(values).get(s, 0) for s in symbols]
    expected = [n / k] * k
    outcome = chi2_gof(counts, expected)
    w = cohens_w(counts, expected)

    # Cand frecventele asteptate sunt mici, p-ul asimptotic minte. Il inlocuim.
    p_method, p_value = outcome.method, outcome.p_value
    if min(expected) < 5 or n < 5 * k:
        def sample(rng: random.Random) -> float:
            draw = Counter(rng.choices(symbols, k=n))
            return sum((draw.get(s, 0) - n / k) ** 2 / (n / k) for s in symbols)

        mc = monte_carlo_p(outcome.statistic, sample,
                           adaptive_iterations(n, 20000), seed)
        p_value, p_method = mc.p_value, "monte-carlo"

    freqs = {s: counts[i] / n for i, s in enumerate(symbols)}
    dominant = max(freqs, key=freqs.get)
    needed = n_for_chi2_power(max(w, 0.15), k - 1)

    explanation = (
        f"Distributia observata: "
        + ", ".join(f"{ds.label(s)} {freqs[s]*100:.1f}%" for s in symbols)
        + f". Sub ipoteza echiprobabilitatii, fiecare simbol ar aparea in "
        f"{100/k:.1f}% din cazuri. Statistica hi-patrat = {outcome.statistic:.2f} "
        f"(p = {p_value:.4f}, metoda: {p_method}). Marimea efectului w = {w:.3f} "
        f"({'neglijabila' if w < 0.1 else 'mica' if w < 0.3 else 'medie' if w < 0.5 else 'mare'}). "
    )
    if p_value >= 0.05:
        explanation += (
            f"Abaterea de la echiprobabilitate este in limitele hazardului. "
            f"Faptul ca {ds.label(dominant)} apare cel mai des NU inseamna ca este "
            f"favorizat: cu {n} rotiri, un simbol trebuie sa iasa cel mai des."
        )
    else:
        explanation += (
            "Distributia se abate semnificativ de la echiprobabilitate. Atentie: "
            "un bias de frecventa NU inseamna predictibilitate. O moneda masluita "
            "care da 60% cap este in continuare imposibil de prezis rotire cu rotire "
            "peste rata de 60%."
        )
    if ds.preset == "color3":
        explanation += (
            " Nota: pe o ruleta europeana reala, distributia asteptata NU este 33/33/33, "
            "ci 48.6% rosu, 48.6% negru, 2.7% verde (18/18/1 din 37 de sloturi). "
            "Daca datele tale seamana cu asta, e semnul unei rulete standard."
        )

    return AnalysisResult(
        key="frequency", title="Distributia rezultatelor",
        question="Apar simbolurile cu frecvente egale, sau exista bias?",
        statistic=outcome.statistic, statistic_name="hi-patrat",
        p_value=p_value, p_method=p_method, df=k - 1,
        effect=w, effect_name="w (Cohen)",
        effect_note="0.1 mic / 0.3 mediu / 0.5 mare",
        n_used=n, min_n=20, recommended_n=needed,
        explanation=explanation, warnings=list(outcome.warnings),
        detail={"counts": dict(zip(symbols, counts)), "freqs": freqs,
                "expected": dict(zip(symbols, expected)),
                "european_wheel_expected": {"R": 18/37, "N": 18/37, "V": 1/37}},
    )
