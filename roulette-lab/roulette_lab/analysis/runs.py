"""Testul seriilor (Wald-Wolfowitz): rezultatele se grupeaza sau alterneaza anormal?"""
from __future__ import annotations

from collections import Counter

from ..data.schema import Dataset
from ..stats.tests import permutation_test
from ._util import adaptive_iterations, collision_probability
from .base import AnalysisResult, register, skipped


def count_runs(values) -> int:
    if not values:
        return 0
    return 1 + sum(1 for a, b in zip(values, values[1:]) if a != b)


def longest_streak(values) -> tuple[int, str]:
    best, best_sym, cur = 0, "", 0
    for i, v in enumerate(values):
        cur = cur + 1 if i and values[i - 1] == v else 1
        if cur > best:
            best, best_sym = cur, v
    return best, best_sym


@register("runs")
def analyze_runs(ds: Dataset, seed: int = 12345, **_) -> AnalysisResult:
    values = ds.values
    n = len(values)
    if n < 30:
        return skipped("runs", "Testul seriilor (runs test)",
                       "Rezultatele se grupeaza in serii mai lungi decat normal?",
                       f"Necesare minim 30 de rotiri (sunt {n}).", 30, n)

    observed_runs = count_runs(values)
    collision = collision_probability(values)
    expected_runs = 1 + (n - 1) * (1 - collision)

    # Ipoteza nula corecta: aceleasi simboluri, aceleasi frecvente, alta ordine.
    # Testul de permutare o implementeaza exact, fara aproximari normale.
    # Statistica e |observat - asteptat|, deci un singur test surprinde ambele
    # directii (prea multe SI prea putine serii) fara sa dublam testele.
    def deviation(seq) -> float:
        return abs(count_runs(seq) - expected_runs)

    outcome = permutation_test(values, deviation,
                               adaptive_iterations(n, 10000), seed, "greater")

    streak, streak_sym = longest_streak(values)
    ratio = observed_runs / expected_runs if expected_runs else 1.0
    direction = ("mai putine serii decat asteptat (rezultatele se lipesc / streak-uri)"
                 if observed_runs < expected_runs else
                 "mai multe serii decat asteptat (alternanta excesiva)")

    explanation = (
        f"Secventa contine {observed_runs} serii de simboluri identice; sub "
        f"independenta, cu aceleasi frecvente, ar fi asteptate {expected_runs:.1f} "
        f"({direction}). Raport observat/asteptat = {ratio:.3f}. "
        f"p = {outcome.p_value:.4f} (test de permutare, {outcome.detail['iterations']} amestecari). "
        f"Cel mai lung streak: {streak}x {ds.label(streak_sym)}."
    )
    if outcome.p_value >= 0.05:
        explanation += (
            " Gruparea observata este cea normala pentru rezultate independente. "
            "Streak-urile lungi sunt asteptate, nu anormale: intr-o secventa de "
            f"{n} rotiri cu aceste frecvente, un streak de {streak} nu surprinde."
        )
    else:
        explanation += (
            " Structura seriilor se abate semnificativ de la independenta -- acesta "
            "este unul dintre putinele semne care ar putea indica dependenta reala "
            "intre rotiri consecutive. De confirmat cu testul Markov."
        )

    return AnalysisResult(
        key="runs", title="Testul seriilor (Wald-Wolfowitz)",
        question="Rezultatele se grupeaza sau alterneaza mai mult decat ar face-o hazardul?",
        statistic=observed_runs, statistic_name="numar de serii",
        p_value=outcome.p_value, p_method="permutation",
        effect=ratio - 1.0, effect_name="abatere relativa",
        effect_note="0 = exact cat asteapta independenta",
        n_used=n, min_n=30, recommended_n=200,
        explanation=explanation,
        detail={"observed_runs": observed_runs, "expected_runs": expected_runs,
                "longest_streak": streak, "longest_streak_symbol": streak_sym,
                "collision_probability": collision,
                "streak_histogram": _streak_histogram(values)},
    )


def _streak_histogram(values) -> dict[int, int]:
    hist: Counter = Counter()
    cur = 1
    for i in range(1, len(values) + 1):
        if i < len(values) and values[i] == values[i - 1]:
            cur += 1
        else:
            hist[cur] += 1
            cur = 1
    return dict(sorted(hist.items()))
