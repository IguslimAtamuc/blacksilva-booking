"""Modele de referinta. Orice model 'destept' trebuie sa le bata ca sa conteze."""
from __future__ import annotations

from collections import Counter
from typing import Sequence

from .base import normalize


class UniformBaseline:
    key = "uniform"
    name = "Uniform (hazard pur)"

    def predict(self, prefix, symbols) -> dict[str, float]:
        return {s: 1.0 / len(symbols) for s in symbols}

    def explain(self, prefix, symbols) -> str:
        return (f"Atribuie {100/len(symbols):.1f}% fiecarui simbol. Nu foloseste "
                "niciun fel de istoric. Este pragul absolut de jos.")


class EmpiricalBaseline:
    """Frecventele istorice, cu netezire Laplace. ACESTA este baseline-ul relevant.

    Un model care 'prezice' rosu pentru ca rosu apare cel mai des nu a descoperit
    un tipar -- a numarat. Ca sa demonstram predictibilitate trebuie sa batem
    acest model, nu pe cel uniform.
    """

    key = "empirical"
    name = "Frecventa empirica (fara memorie)"

    def __init__(self, alpha: float = 1.0):
        self.alpha = alpha

    def predict(self, prefix, symbols) -> dict[str, float]:
        counts = Counter(prefix)
        return normalize({s: counts.get(s, 0) + self.alpha for s in symbols}, symbols)

    def explain(self, prefix, symbols) -> str:
        counts = Counter(prefix)
        parts = ", ".join(f"{s}={counts.get(s, 0)}" for s in symbols)
        return (f"Doar frecventele din cele {len(prefix)} rotiri anterioare ({parts}), "
                f"netezite Laplace (alpha={self.alpha}). Nu presupune nicio dependenta "
                "intre rotiri.")


class _CountState:
    """Stare incrementala pentru modelele fara memorie."""

    def __init__(self, symbols, alpha: float):
        self.symbols, self.alpha = list(symbols), alpha
        self.counts: Counter = Counter()

    def observe(self, history, symbol) -> None:
        self.counts[symbol] += 1

    def predict(self, history) -> dict[str, float]:
        return normalize({s: self.counts.get(s, 0) + self.alpha for s in self.symbols},
                         self.symbols)


class _UniformState:
    def __init__(self, symbols):
        self.symbols = list(symbols)

    def observe(self, history, symbol) -> None:
        pass

    def predict(self, history) -> dict[str, float]:
        return {s: 1.0 / len(self.symbols) for s in self.symbols}


UniformBaseline.make_state = lambda self, symbols: _UniformState(symbols)
EmpiricalBaseline.make_state = lambda self, symbols: _CountState(symbols, self.alpha)
