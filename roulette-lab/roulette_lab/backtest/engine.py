"""Backtesting walk-forward (prequential).

Protocolul, exact cum l-ai descris:
  - primele `warmup` rotiri sunt doar pentru invatare;
  - prezicem rotirea `warmup`, o comparam cu realitatea;
  - adaugam rezultatul real la istoric si prezicem urmatoarea;
  - repetam pana la capat.

Garantia critica: la pasul t, modelul vede EXACT values[:t] si nimic altceva.
Nu exista niciun punct in care un parametru sa fie ales privind la date viitoare.
De aceea nu exista aici "calibrare" cu constante alese dupa ce am vazut rezultatul.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Sequence

from ..data.schema import Dataset
from ..models import BASELINE_KEY, default_models
from ..stats.tests import bootstrap_mean_ci, sign_flip_test
from .metrics import summarize


class _FallbackState:
    """Adaptor pentru modele care nu ofera stare incrementala (ex. plugin-uri noi)."""

    def __init__(self, model, symbols):
        self.model, self.symbols = model, list(symbols)

    def observe(self, history, symbol) -> None:
        pass

    def predict(self, history) -> dict[str, float]:
        return self.model.predict(history, self.symbols)


@dataclass
class ModelRun:
    key: str
    name: str
    metrics: dict
    distributions: list = field(default_factory=list, repr=False)

    def to_dict(self, include_series: bool = False) -> dict:
        m = dict(self.metrics)
        if not include_series:
            m.pop("log_loss_series", None)
        return {"key": self.key, "name": self.name, **m}


@dataclass
class BacktestReport:
    n_total: int
    warmup: int
    n_evaluated: int
    symbols: list
    runs: dict[str, ModelRun]
    comparisons: dict[str, dict]
    baseline_key: str
    actual: list = field(default_factory=list, repr=False)
    elapsed_s: float = 0.0

    @property
    def best_key(self) -> str:
        return min(self.runs, key=lambda k: self.runs[k].metrics["log_loss_bits"])

    def to_dict(self, include_series: bool = False) -> dict:
        return {
            "n_total": self.n_total, "warmup": self.warmup,
            "n_evaluated": self.n_evaluated, "symbols": self.symbols,
            "baseline_key": self.baseline_key, "best_key": self.best_key,
            "elapsed_s": round(self.elapsed_s, 3),
            "runs": {k: r.to_dict(include_series) for k, r in self.runs.items()},
            "comparisons": self.comparisons,
        }


def default_warmup(n: int) -> int:
    """Cat istoric rezervam pentru invatare inainte de prima predictie evaluata.

    Compromis: prea mic si modelele prezic din zgomot; prea mare si raman prea
    putine puncte de evaluare. Folosim 30% din date, intre 30 si 200 de rotiri.
    """
    return max(min(30, max(1, n // 3)), min(200, int(n * 0.3)))


def run_backtest(ds: Dataset, models: Sequence | None = None, warmup: int | None = None,
                 seed: int = 12345, iterations: int = 10000) -> BacktestReport:
    started = time.perf_counter()
    values = ds.values
    symbols = ds.symbols
    n = len(values)
    models = list(models) if models is not None else default_models()
    warmup = warmup if warmup is not None else default_warmup(n)
    warmup = max(1, min(warmup, max(1, n - 1)))

    states = {}
    for m in models:
        maker = getattr(m, "make_state", None)
        states[m.key] = maker(symbols) if maker else _FallbackState(m, symbols)

    predictions: dict[str, list] = {m.key: [] for m in models}
    actual: list[str] = []

    for t in range(n):
        history = values[:t]
        if t >= warmup:
            for m in models:
                predictions[m.key].append(states[m.key].predict(history))
            actual.append(values[t])
        for m in models:
            states[m.key].observe(history, values[t])

    runs = {m.key: ModelRun(m.key, m.name, summarize(predictions[m.key], actual, symbols),
                            predictions[m.key]) for m in models}

    # --- comparatie statistica fata de baseline-ul empiric -----------------
    comparisons: dict[str, dict] = {}
    baseline = runs.get(BASELINE_KEY)
    if baseline and actual:
        base_losses = baseline.metrics["log_loss_series"]
        n_candidates = max(1, len([m for m in models if m.key != BASELINE_KEY]))
        for key, run in runs.items():
            if key == BASELINE_KEY:
                continue
            diffs = [b - m for b, m in zip(base_losses, run.metrics["log_loss_series"])]
            test = sign_flip_test(diffs, iterations=iterations, seed=seed,
                                  alternative="greater")
            mean, lo, hi = bootstrap_mean_ci(diffs, 0.95, min(4000, iterations), seed)
            comparisons[key] = {
                "mean_bits_saved": mean,          # >0 inseamna mai bun decat baseline
                "ci95_low": lo, "ci95_high": hi,
                "p_value": test.p_value,
                # corectia pentru numarul de modele incercate: fara ea, cu destule
                # modele, unul va parea mereu semnificativ
                "p_value_corrected": min(1.0, test.p_value * n_candidates),
                "models_compared": n_candidates,
                "accuracy_delta": run.metrics["accuracy"] - baseline.metrics["accuracy"],
                "beats_baseline": mean > 0,
            }

    return BacktestReport(n, warmup, len(actual), list(symbols), runs, comparisons,
                          BASELINE_KEY, actual, time.perf_counter() - started)
