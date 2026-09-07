"""Sub-siruri repetate: exista bucati care se repeta mai mult decat la intamplare?

Acesta este tiparul care convinge cel mai usor un observator uman ca ruleta
"are un ciclu" -- si tot el este cel mai bine imitat de hazardul pur.
"""
from __future__ import annotations

from ..data.schema import Dataset
from ..stats.tests import permutation_test
from ._util import adaptive_iterations, longest_repeat_length, max_lag_match_run
from .base import AnalysisResult, register, skipped


@register("repeats")
def analyze_repeats(ds: Dataset, seed: int = 12345, **_) -> AnalysisResult:
    values = ds.values
    n = len(values)
    if n < 25:
        return skipped("repeats", "Sub-siruri repetate",
                       "Exista bucati care se repeta identic mai des decat la intamplare?",
                       f"Necesare minim 25 de rotiri (sunt {n}).", 25, n)

    # Cel mai lung sub-sir repetat == cea mai lunga potrivire a secventei cu ea
    # insasi decalata. Calculam lungimea in O(n log n), iar pozitia concreta o
    # aflam o singura data, pe datele reale (scanare O(n^2), niciodata in bucla).
    observed = longest_repeat_length(values)
    run_len, lag, start = max_lag_match_run(values)

    outcome = permutation_test(values, longest_repeat_length,
                               adaptive_iterations(n, 4000, 4), seed, "greater")

    fragment = "".join(values[start:start + run_len]) if ds.preset == "color3" \
        else ",".join(values[start:start + run_len])
    null_mean = outcome.detail["null_mean"]
    null_p95 = outcome.detail["null_p95"]

    explanation = (
        f"Cel mai lung fragment care se repeta identic are {observed} simboluri: "
        f"[{fragment}], la pozitiile {start+1} si {start+lag+1} (distanta {lag}). "
        f"In secvente COMPLET ALEATOARE cu exact aceleasi frecvente, cel mai lung "
        f"fragment repetat are in medie {null_mean:.1f} simboluri, iar in 5% din cazuri "
        f"cel putin {null_p95:.0f}. p = {outcome.p_value:.4f}. "
    )
    if outcome.p_value >= 0.05:
        explanation += (
            "Repetarea observata este exact cat produce hazardul. Aceasta este "
            "cea mai importanta concluzie a analizei pentru un ochi uman: creierul "
            "trateaza un fragment repetat drept dovada de mecanism, dar aleatorul "
            "genereaza obligatoriu astfel de fragmente. Un fragment repetat NU permite "
            "predictia simbolului care urmeaza dupa el."
        )
    else:
        explanation += (
            "Repetarea depaseste ce produce hazardul -- posibil ciclu real sau "
            "un generator cu perioada scurta. De verificat cu analiza de periodicitate "
            "si cu backtesting."
        )

    return AnalysisResult(
        key="repeats", title="Sub-siruri repetate",
        question="Exista fragmente care se repeta mai mult decat la intamplare?",
        statistic=observed, statistic_name="lungimea celui mai lung fragment repetat",
        p_value=outcome.p_value, p_method="permutation",
        effect=observed - null_mean, effect_name="simboluri peste asteptare",
        effect_note="observat minus media hazardului",
        n_used=n, min_n=25, recommended_n=300,
        explanation=explanation,
        detail={"length": observed, "lag": lag, "start": start,
                "fragment": list(values[start:start + run_len]),
                "null_mean": null_mean, "null_p95": null_p95,
                "null_max": outcome.detail.get("null_max")},
    )
