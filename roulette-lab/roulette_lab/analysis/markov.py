"""Dependenta Markov: rezultatul urmator depinde de contextul anterior?

Este testul central al proiectului. Daca ruleta este predictibila din propriul
istoric de rezultate, atunci EXISTA o dependenta de context detectabila aici.
Daca acest test nu gaseste nimic pe suficiente date, niciun model bazat doar pe
istoricul de culori nu poate functiona -- oricat de sofisticat ar fi.
"""
from __future__ import annotations

import math
from collections import Counter, defaultdict

from ..data.schema import Dataset
from ..stats.tests import permutation_test
from ._util import adaptive_iterations, n_for_chi2_power
from .base import AnalysisResult, register, skipped


def log_likelihood_order(values, symbols, order: int) -> tuple[float, int]:
    """Log-verosimilitatea maxima a unui model Markov de ordin dat -> (ll, parametri liberi)."""
    k = len(symbols)
    if order == 0:
        counts = Counter(values)
        n = len(values)
        ll = sum(c * math.log(c / n) for c in counts.values() if c > 0)
        return ll, k - 1
    contexts: dict[tuple, Counter] = defaultdict(Counter)
    for i in range(order, len(values)):
        contexts[tuple(values[i - order:i])][values[i]] += 1
    ll = 0.0
    for counter in contexts.values():
        total = sum(counter.values())
        ll += sum(c * math.log(c / total) for c in counter.values() if c > 0)
    # parametri liberi = (k-1) pentru fiecare context OBSERVAT, nu pentru toate
    # cele k^order posibile: penalizam doar ce am estimat efectiv din date
    return ll, len(contexts) * (k - 1)


def g_statistic(values, symbols, order: int = 1) -> float:
    """Raportul de verosimilitate G = 2*(ll_ordin - ll_iid), comparabil pe aceleasi date."""
    ll_hi, _ = log_likelihood_order(values, symbols, order)
    ll_lo, _ = log_likelihood_order(values[order:], symbols, 0)
    return 2.0 * (ll_hi - ll_lo)


@register("markov")
def analyze_markov(ds: Dataset, seed: int = 12345, max_order: int = 3, **_) -> AnalysisResult:
    values = ds.values
    symbols = ds.symbols
    n = len(values)
    k = len(symbols)
    if n < 40:
        return skipped("markov", "Dependenta Markov",
                       "Rezultatul urmator depinde de cele anterioare?",
                       f"Necesare minim 40 de rotiri (sunt {n}).", 40, n)

    g_obs = g_statistic(values, symbols, 1)
    df = (k - 1) ** 2

    # p prin permutare: nu ne bazam pe aproximatia hi-patrat, care e invalida
    # cand un simbol e rar (ex. Verde cu 5 aparitii)
    outcome = permutation_test(values, lambda s: g_statistic(s, symbols, 1),
                               adaptive_iterations(n, 5000, 3), seed, "greater")

    # Selectia ordinului prin BIC: penalizeaza modelele cu multi parametri
    bic: dict[int, float] = {}
    for order in range(0, max_order + 1):
        if n <= order + 10:
            break
        ll, params = log_likelihood_order(values[max_order - order:], symbols, order)
        bic[order] = -2 * ll + params * math.log(max(1, n - max_order))
    best_order = min(bic, key=bic.get) if bic else 0

    # Cate tranzitii avem pe context? Sub 5 pe celula, estimarile sunt zgomot.
    trans: dict[str, Counter] = defaultdict(Counter)
    for a, b in zip(values, values[1:]):
        trans[a][b] += 1
    per_context = {a: sum(c.values()) for a, c in trans.items()}
    min_cells = min((v / k for v in per_context.values()), default=0)

    matrix = {a: {b: trans[a].get(b, 0) for b in symbols} for a in symbols}
    rates = {a: {b: (trans[a].get(b, 0) / per_context[a]) if per_context.get(a) else 0.0
                 for b in symbols} for a in symbols}
    # castigul informational: cati biti economisim stiind simbolul anterior
    ll1, _ = log_likelihood_order(values, symbols, 1)
    ll0, _ = log_likelihood_order(values[1:], symbols, 0)
    bits_gained = (ll1 - ll0) / math.log(2) / max(1, n - 1)
    w = math.sqrt(max(0.0, g_obs) / max(1, n - 1))
    needed = n_for_chi2_power(max(w, 0.15), df)

    warnings = []
    if min_cells < 5:
        warnings.append(
            f"In medie doar {min_cells:.1f} observatii pe celula a matricei de tranzitie "
            f"(recomandat: minim 5). Matricea afisata este in mare parte zgomot."
        )

    explanation = (
        f"Testul compara un model care 'tine minte' rezultatul anterior cu unul fara "
        f"memorie. G = {g_obs:.2f} pe {df} grade de libertate, p = {outcome.p_value:.4f} "
        f"(test de permutare, {outcome.detail['iterations']} amestecari). "
        f"Castigul informational al memoriei: {bits_gained:.4f} biti/rotire "
        f"(pentru referinta, o predictie perfecta ar valora {math.log2(k):.2f} biti). "
        f"Selectia ordinului prin BIC alege ordinul {best_order}"
        f"{' (adica: fara memorie -- istoricul nu ajuta)' if best_order == 0 else ''}. "
    )
    if outcome.p_value >= 0.05:
        explanation += (
            "Nu exista dovada de dependenta intre rotiri consecutive. Toate metodele "
            "de tip 'dupa R-N urmeaza de obicei X' construite pe aceste date descriu "
            "zgomot, nu mecanism."
        )
    else:
        explanation += (
            "Exista dovada de dependenta. Urmatorul pas obligatoriu: backtesting "
            "walk-forward, care verifica daca dependenta se transforma in predictie "
            "utila pe date nevazute -- multe dependente reale sunt prea slabe pentru asta."
        )
    if n < needed:
        explanation += (
            f" Pentru a detecta cu 80% probabilitate un efect de marimea celui "
            f"observat (w={w:.3f}) ar fi nevoie de ~{needed} rotiri."
        )

    return AnalysisResult(
        key="markov", title="Dependenta Markov (ordin 1)",
        question="Rezultatul urmator depinde de rezultatul anterior?",
        statistic=g_obs, statistic_name="G (raport de verosimilitate)",
        p_value=outcome.p_value, p_method="permutation", df=df,
        effect=bits_gained, effect_name="biti castigati/rotire",
        effect_note=f"din maximum {math.log2(k):.2f} biti posibili",
        n_used=n, min_n=40, recommended_n=max(needed, 300),
        explanation=explanation, warnings=warnings,
        detail={"transition_counts": matrix, "transition_rates": rates,
                "bic_by_order": bic, "best_order_bic": best_order,
                "observations_per_context": per_context,
                "avg_cell_count": min_cells, "cramers_w": w},
    )
