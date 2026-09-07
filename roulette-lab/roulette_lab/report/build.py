"""Construieste raportul complet: analiza + PRNG + backtesting + decizie."""
from __future__ import annotations

from ..analysis import run_all
from ..backtest import run_backtest
from ..data.schema import Dataset
from ..decide import DEFAULTS, decide
from ..prng import identify
from .manifest import build_manifest


def build_report(ds: Dataset, seed: int = 12345, config: dict | None = None,
                 run_prng: bool = True, prng_max_seeds: int = 50_000) -> dict:
    cfg = {**DEFAULTS, **(config or {})}
    analysis = run_all(ds, alpha=0.05, seed=seed)
    backtest = run_backtest(ds, seed=seed) if len(ds) >= 20 else None
    decision = decide(ds, cfg, seed=seed, backtest=backtest, analysis=analysis)
    prng = identify(ds, max_seeds=prng_max_seeds) if run_prng else None

    return {
        "manifest": build_manifest(ds, seed, cfg),
        "analysis": analysis.to_dict(),
        "prng": prng,
        "backtest": backtest.to_dict() if backtest else None,
        "decision": decision.to_dict(),
        "conclusion": _conclusion(ds, analysis, decision),
    }


def _conclusion(ds, analysis, decision) -> dict:
    n = len(ds)
    if decision.allowed:
        headline = ("Datele sustin o capacitate de predictie masurabila, validata "
                    "out-of-sample.")
    elif n < 200:
        headline = ("Nedemonstrabil cu volumul actual de date. Nu am aratat ca ruleta "
                    "este predictibila, si nici ca nu este.")
    else:
        headline = ("Datele NU sustin predictibilitatea: niciun model nu bate un model "
                    "fara memorie pe rotiri nevazute la antrenare.")
    return {
        "headline": headline,
        "n_spins": n,
        "analysis_summary": analysis.summary(),
        "decision_message": decision.message,
        "what_we_can_claim": _claims(ds, analysis, decision),
        "what_we_cannot_claim": [
            "Ca ruleta este 'aleatoare' in sens absolut -- am aratat doar ca nu "
            "detectam structura in aceste date, cu aceste teste.",
            "Ca un anumit PRNG este folosit, atata timp cat nu i-am reprodus "
            "output-ul exact.",
            "Ca absenta unui tipar acum garanteaza absenta lui in alte conditii "
            "(alta versiune a jocului, alt mod de joc, alt server).",
        ],
    }


def _claims(ds, analysis, decision) -> list[str]:
    out = []
    n = len(ds)
    if n >= 30:
        freq = next((r for r in analysis.results if r.key == "frequency"), None)
        if freq and freq.applicable:
            out.append(f"Distributia observata a rezultatelor pe {n} rotiri, cu "
                       f"interval de incredere corespunzator acestui volum.")
        wheel = next((r for r in analysis.results if r.key == "wheel_model"), None)
        if wheel and wheel.applicable and wheel.p_value < 0.05:
            out.append("Ca jocul NU foloseste probabilitatile unei rulete europene "
                       "standard de 37 de sloturi.")
    if decision.allowed:
        out.append("Ca exista un castig predictiv real, cu marimea si intervalul "
                   "de incredere raportate.")
    elif n >= 200:
        out.append("Ca orice castig predictiv, daca exista, este sub pragul pe care "
                   "l-am putut detecta cu acest volum de date.")
    if not out:
        out.append("Foarte putin: volumul de date nu sustine nicio afirmatie solida.")
    return out
