"""Poarta de evidenta: singurul loc din proiect care are voie sa emita o predictie.

Filozofia, pe scurt: analiza gaseste MEREU ceva -- asta e natura ei. Decizia
trebuie sa fie separata si sa aiba dreptul de veto. O predictie iese pe usa
doar daca trece TOATE conditiile de mai jos, fiecare dintre ele necesara:

  1. volum minim de date         -- sub el, orice concluzie e zgomot;
  2. castig out-of-sample > 0    -- masurat prin backtesting walk-forward, nu pe
                                    datele pe care modelul a fost construit;
  3. castig peste pragul util    -- 0.01 biti/rotire; sub asta efectul e real
                                    dar inutilizabil;
  4. intervalul de incredere 95% -- complet peste zero, nu doar media;
  5. semnificatie dupa corectie  -- p corectat pentru numarul de modele testate.

Daca oricare pica, iesirea este refuzul explicit. Tool-ul nu are voie sa
inventeze o predictie doar ca sa afiseze ceva.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field

from ..analysis import EVIDENCE, run_all
from ..backtest import BacktestReport, run_backtest
from ..data.schema import Dataset, PredictionRecord
from ..models import BASELINE_KEY, default_models

REFUSAL = "Nu exista suficiente dovezi ca urmatorul rezultat poate fi prezis."

# Praguri de decizie. Sunt declarate aici, o singura data, si NU se ajusteaza
# dupa ce au fost vazute rezultatele -- asta ar fi exact greseala pe care
# proiectul incearca sa o evite.
DEFAULTS = {
    "min_spins": 200,          # sub 200 de rotiri nu discutam despre predictie
    "min_evaluated": 50,       # puncte de evaluare out-of-sample necesare
    "min_bits_gain": 0.01,     # castig informational minim ca sa fie util
    "alpha": 0.01,             # prag de semnificatie dupa corectie
}


def build_guess(ds: Dataset, bt: BacktestReport | None) -> dict | None:
    """Cea mai buna ghicitura, INDIFERENT daca poarta de evidenta o aproba.

    Exista pentru ca "arata-mi oricum o culoare" este o cerere legitima -- dar
    o cifra fara context este exact capcana in care a cazut versiunea anterioara
    a acestui tool. Asa ca ghicitura vine intotdeauna insotita de:
      - acuratetea ei REALA, masurata pe rotiri nevazute la antrenare;
      - acuratetea unui model care nu presupune niciun tipar (baseline);
      - diferenta dintre ele, care este singurul numar care conteaza.
    Daca diferenta e ~0, ghicitura e o moneda aruncata cu pasi in plus.
    """
    values = ds.values
    if len(values) < 30 or bt is None or not bt.runs:
        return None
    best_key = bt.best_key
    run = bt.runs[best_key]
    model = next((m for m in default_models() if m.key == best_key), None)
    if model is None:
        return None
    dist = model.predict(values, ds.symbols)
    symbol = max(dist, key=dist.get)
    baseline = bt.runs.get(BASELINE_KEY)
    baseline_accuracy = baseline.metrics["accuracy"] if baseline else 0.0
    measured = run.metrics["accuracy"]
    delta = measured - baseline_accuracy
    comp = bt.comparisons.get(best_key)

    most_common = ds.label(max(set(values), key=values.count))
    if delta < -0.01:
        honesty = (
            f"Aceasta ghicitura nimereste {measured*100:.1f}% din timp pe rotiri "
            f"nevazute -- MAI PUTIN decat cele {baseline_accuracy*100:.1f}% pe care "
            f"le obtii apasand pur si simplu mereu pe {most_common}. Modelul nu doar "
            f"ca nu ajuta: incearca sa gaseasca tipare acolo unde nu sunt si iese "
            f"in pierdere."
        )
    elif delta <= 0.01:
        honesty = (
            f"Aceasta ghicitura nimereste {measured*100:.1f}% din timp pe rotiri "
            f"nevazute -- practic identic cu {baseline_accuracy*100:.1f}% cat obtii "
            f"apasand mereu pe {most_common}. Modelul nu aduce nimic peste asta."
        )
    else:
        honesty = (
            f"Aceasta ghicitura nimereste {measured*100:.1f}% din timp pe rotiri "
            f"nevazute, fata de {baseline_accuracy*100:.1f}% pentru un model fara "
            f"tipare -- un avantaj de {delta*100:+.1f} puncte."
        )
        if comp and comp["p_value_corrected"] >= 0.01:
            honesty += (" Diferenta NU este insa semnificativa statistic: la acest "
                        "volum de date poate fi pur si simplu noroc.")

    return {
        "symbol": symbol,
        "label": ds.label(symbol),
        "probabilities": {k: round(v, 6) for k, v in dist.items()},
        "model_confidence": dist[symbol],
        "model": run.name,
        "measured_accuracy": measured,
        "baseline_accuracy": baseline_accuracy,
        "accuracy_delta": delta,
        "evaluated_on": bt.n_evaluated,
        "honesty": honesty,
        "beats_baseline_significantly": bool(
            comp and comp["p_value_corrected"] < 0.01 and comp["mean_bits_saved"] > 0.01),
    }


@dataclass
class Decision:
    allowed: bool
    prediction: str | None
    probabilities: dict[str, float]
    confidence: float
    model_key: str | None
    model_name: str | None
    message: str
    checks: list[dict] = field(default_factory=list)
    evidence: dict = field(default_factory=dict)
    transparency: dict = field(default_factory=dict)
    guess: dict | None = None
    elapsed_s: float = 0.0

    def to_dict(self) -> dict:
        return {
            "allowed": self.allowed, "prediction": self.prediction,
            "probabilities": {k: round(v, 6) for k, v in self.probabilities.items()},
            "confidence": round(self.confidence, 6),
            "model_key": self.model_key, "model_name": self.model_name,
            "message": self.message, "checks": self.checks,
            "evidence": self.evidence, "transparency": self.transparency,
            "guess": self.guess,
            "elapsed_s": round(self.elapsed_s, 3),
        }


def _check(name: str, passed: bool, detail: str, required: str, observed: str) -> dict:
    return {"name": name, "passed": passed, "detail": detail,
            "required": required, "observed": observed}


def decide(ds: Dataset, config: dict | None = None, seed: int = 12345,
           backtest: BacktestReport | None = None,
           analysis=None) -> Decision:
    started = time.perf_counter()
    cfg = {**DEFAULTS, **(config or {})}
    values = ds.values
    n = len(values)
    symbols = ds.symbols
    checks: list[dict] = []

    # --- Conditia 1: volum de date ----------------------------------------
    enough_data = n >= cfg["min_spins"]
    checks.append(_check(
        "Volum de date", enough_data,
        "Sub acest prag, diferenta dintre un tipar real si zgomot nu poate fi "
        "masurata: intervalele de incredere sunt mai largi decat orice efect plauzibil.",
        f">= {cfg['min_spins']} rotiri", f"{n} rotiri"))

    early_bt = backtest
    if early_bt is None and n >= 20:
        early_bt = run_backtest(ds, default_models(), seed=seed)
    guess = build_guess(ds, early_bt)

    if not enough_data:
        needed = cfg["min_spins"] - n
        return Decision(
            allowed=False, prediction=None, probabilities={}, confidence=0.0,
            model_key=None, model_name=None,
            message=(f"{REFUSAL} Ai {n} rotiri; sunt necesare cel putin "
                     f"{cfg['min_spins']} pentru ca backtesting-ul sa poata distinge "
                     f"un tipar real de hazard. Mai colecteaza {needed} rezultate."),
            checks=checks, guess=guess,
            transparency={
                "data_used": f"{n} rotiri, alfabet {symbols}",
                "model_used": "niciunul -- nu s-a ajuns la etapa de modelare",
                "pattern_detected": "netestat",
                "evidence_strength": "insuficienta pentru orice afirmatie",
                "why": "Poarta s-a oprit la prima conditie: volum de date.",
            },
            elapsed_s=time.perf_counter() - started)

    # --- Backtesting walk-forward -----------------------------------------
    bt = early_bt or run_backtest(ds, default_models(), seed=seed)
    enough_eval = bt.n_evaluated >= cfg["min_evaluated"]
    checks.append(_check(
        "Puncte de evaluare out-of-sample", enough_eval,
        "Predictiile trebuie testate pe rotiri pe care modelul nu le-a vazut la "
        "antrenare. Prea putine puncte inseamna teste fara putere.",
        f">= {cfg['min_evaluated']}", f"{bt.n_evaluated}"))

    # cel mai bun model, excluzand referintele
    candidates = {k: v for k, v in bt.comparisons.items() if k != "uniform"}
    if not candidates or not enough_eval:
        return _refuse(ds, bt, checks, started, cfg,
                       "Nu exista suficiente puncte de evaluare out-of-sample.",
                       guess=guess)

    best_key = max(candidates, key=lambda k: candidates[k]["mean_bits_saved"])
    comp = candidates[best_key]
    run = bt.runs[best_key]

    # --- Conditia 2: bate baseline-ul -------------------------------------
    beats = comp["mean_bits_saved"] > 0
    checks.append(_check(
        "Bate modelul fara memorie", beats,
        "Baseline-ul este frecventa empirica. A prezice 'Rosu' pentru ca Rosu "
        "apare cel mai des nu inseamna a descoperi un tipar.",
        "castig > 0 biti/rotire", f"{comp['mean_bits_saved']:+.4f} biti/rotire"))

    # --- Conditia 3: castigul e util practic ------------------------------
    useful = comp["mean_bits_saved"] >= cfg["min_bits_gain"]
    checks.append(_check(
        "Castig utilizabil practic", useful,
        "Un efect poate fi real si statistic semnificativ, dar prea mic pentru a "
        "schimba ceva. Pragul separa 'exista' de 'conteaza'.",
        f">= {cfg['min_bits_gain']} biti/rotire", f"{comp['mean_bits_saved']:.4f}"))

    # --- Conditia 4: intervalul de incredere nu atinge zero ---------------
    ci_ok = comp["ci95_low"] > 0
    checks.append(_check(
        "Interval de incredere 95% peste zero", ci_ok,
        "Media poate fi pozitiva din intamplare. Cerem ca si limita de jos a "
        "intervalului bootstrap sa fie pozitiva.",
        "limita inferioara > 0",
        f"[{comp['ci95_low']:+.4f}, {comp['ci95_high']:+.4f}]"))

    # --- Conditia 5: semnificatie dupa corectie ---------------------------
    sig = comp["p_value_corrected"] < cfg["alpha"]
    checks.append(_check(
        "Semnificatie statistica (corectata)", sig,
        f"Test pereche prin inversarea semnelor pe diferentele de log-loss, "
        f"corectat Bonferroni pentru cele {comp['models_compared']} modele incercate.",
        f"p corectat < {cfg['alpha']}", f"p = {comp['p_value_corrected']:.4f}"))

    analysis_report = analysis or run_all(ds, seed=seed)
    supporting = [r.title for r in analysis_report.results if r.verdict == EVIDENCE]

    passed = all(c["passed"] for c in checks)
    if not passed:
        failed = [c["name"] for c in checks if not c["passed"]]
        return _refuse(ds, bt, checks, started, cfg,
                       f"Conditii nerespectate: {', '.join(failed)}.",
                       analysis_report, best_key, guess=guess)

    # --- Predictia propriu-zisa -------------------------------------------
    model = next(m for m in default_models() if m.key == best_key)
    dist = model.predict(values, symbols)
    prediction = max(dist, key=dist.get)
    confidence = dist[prediction]
    calib_error = run.metrics.get("calibration_error", 0.0)

    return Decision(
        allowed=True, prediction=prediction, probabilities=dist, confidence=confidence,
        model_key=best_key, model_name=run.name,
        message=(
            f"Predictie permisa: {ds.label(prediction)} cu {confidence*100:.1f}%. "
            f"Modelul {run.name} economiseste {comp['mean_bits_saved']:.4f} biti/rotire "
            f"fata de frecventa empirica, pe {bt.n_evaluated} rotiri nevazute la "
            f"antrenare (p corectat = {comp['p_value_corrected']:.4g})."
        ),
        checks=checks,
        evidence={
            "backtest": bt.to_dict(),
            "comparison": comp,
            "supporting_analyses": supporting,
            "calibration_error": calib_error,
        },
        transparency={
            "data_used": f"{n} rotiri (fingerprint {ds.fingerprint()[:12]})",
            "model_used": run.name,
            "pattern_detected": model.explain(values, symbols),
            "evidence_strength": (
                f"castig {comp['mean_bits_saved']:.4f} biti/rotire "
                f"(IC95 [{comp['ci95_low']:+.4f}, {comp['ci95_high']:+.4f}]), "
                f"p corectat {comp['p_value_corrected']:.4g}, "
                f"acuratete out-of-sample {run.metrics['accuracy']*100:.1f}% fata de "
                f"{bt.runs[BASELINE_KEY].metrics['accuracy']*100:.1f}% baseline"),
            "estimated_probability": {k: round(v, 4) for k, v in dist.items()},
            "calibration": (
                f"eroare medie de calibrare {calib_error*100:.1f} puncte procentuale "
                f"-- cand modelul afiseaza X%, realitatea a fost in medie la "
                f"{calib_error*100:.1f} puncte distanta"),
            "supporting_analyses": supporting,
            "caveat": (
                "Un avantaj statistic real nu inseamna automat un avantaj practic: "
                "orice joc de acest tip are un avantaj al casei incorporat, care "
                "poate depasi castigul masurat aici."),
            "why": "Toate cele cinci conditii ale portii au fost indeplinite.",
        },
        guess=guess,
        elapsed_s=time.perf_counter() - started)


def _refuse(ds: Dataset, bt: BacktestReport, checks: list[dict], started: float,
            cfg: dict, reason: str, analysis_report=None,
            best_key: str | None = None, guess: dict | None = None) -> Decision:
    baseline = bt.runs.get(BASELINE_KEY)
    best = bt.runs.get(best_key) if best_key else None
    comp = bt.comparisons.get(best_key) if best_key else None

    detail = ""
    if best and comp and baseline:
        detail = (
            f" Cel mai bun model incercat ({best.name}) a obtinut "
            f"{comp['mean_bits_saved']:+.4f} biti/rotire fata de frecventa empirica "
            f"pe {bt.n_evaluated} rotiri nevazute -- adica "
            f"{'nu mai mult decat' if comp['mean_bits_saved'] <= 0 else 'prea putin peste'} "
            f"hazardul. Acuratete: {best.metrics['accuracy']*100:.1f}% fata de "
            f"{baseline.metrics['accuracy']*100:.1f}% pentru un model care nu "
            f"presupune niciun tipar."
        )

    supporting = []
    if analysis_report is not None:
        supporting = [r.title for r in analysis_report.results if r.verdict == EVIDENCE]

    return Decision(
        allowed=False, prediction=None, probabilities={}, confidence=0.0,
        model_key=best_key, model_name=best.name if best else None,
        message=f"{REFUSAL} {reason}{detail}",
        checks=checks, guess=guess,
        evidence={"backtest": bt.to_dict(), "comparison": comp,
                  "supporting_analyses": supporting},
        transparency={
            "data_used": f"{len(ds)} rotiri (fingerprint {ds.fingerprint()[:12]})",
            "model_used": f"{best.name} (respins)" if best else "niciunul",
            "pattern_detected": (
                "Analizele au gasit: " + ", ".join(supporting) if supporting else
                "Niciun tipar care sa supravietuiasca corectiei pentru teste multiple."),
            "evidence_strength": "sub pragul de decizie",
            "estimated_probability": "nu se emite -- ar fi o cifra fara acoperire",
            "why": reason,
            "what_would_change_this": (
                "Mai multe date (tinta: 1000-2000 de rotiri), inregistrarea numarului "
                "slotului in loc de culoare, si adaugarea de timestamp-uri si id-uri "
                "de sesiune pentru a testa ipoteza resetarii seed-ului."),
        },
        elapsed_s=time.perf_counter() - started)


def make_record(decision: Decision, at_index: int) -> PredictionRecord:
    """Transforma decizia intr-o inregistrare care va fi evaluata la rotirea urmatoare."""
    return PredictionRecord(
        at_index=at_index,
        predicted=decision.prediction,
        probabilities=decision.probabilities,
        confidence=decision.confidence,
        model=decision.model_name or "-",
        gated=decision.allowed,
        reason=decision.message,
        ts=time.time(),
    )
