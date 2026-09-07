"""Combinarea modelelor prin ponderi exponentiale (agregare bayesiana).

Ponderea fiecarui model creste sau scade dupa performanta lui REALA pe
predictiile trecute, nu dupa un scor inventat. Daca niciun model nu bate
frecventa empirica, ansamblul converge catre frecventa empirica -- adica
spune corect "nu stiu nimic in plus".
"""
from __future__ import annotations

import math
from typing import Sequence

from .base import log_loss_bits, normalize


class ExponentialWeightsEnsemble:
    key = "ensemble"
    name = "Ansamblu cu ponderi exponentiale"

    def __init__(self, members: Sequence, learning_rate: float = 0.5,
                 max_history: int = 500):
        self.members = list(members)
        self.learning_rate = learning_rate
        self.max_history = max_history

    def _weights(self, prefix: Sequence[str], symbols: Sequence[str]) -> list[float]:
        """Pondere ~ exp(-eta * pierdere cumulata), calculata doar din trecut."""
        losses = [0.0] * len(self.members)
        start = max(1, len(prefix) - self.max_history)
        for t in range(start, len(prefix)):
            history = prefix[:t]
            actual = prefix[t]
            for i, m in enumerate(self.members):
                losses[i] += log_loss_bits(m.predict(history, symbols), actual)
        if not any(losses):
            return [1.0 / len(self.members)] * len(self.members)
        best = min(losses)
        raw = [math.exp(-self.learning_rate * (l - best)) for l in losses]
        total = sum(raw)
        return [r / total for r in raw]

    def predict(self, prefix, symbols) -> dict[str, float]:
        weights = self._weights(prefix, symbols)
        mixed = {s: 0.0 for s in symbols}
        for w, m in zip(weights, self.members):
            dist = m.predict(prefix, symbols)
            for s in symbols:
                mixed[s] += w * dist[s]
        return normalize(mixed, symbols)

    def explain(self, prefix, symbols) -> str:
        weights = self._weights(prefix, symbols)
        ranked = sorted(zip(self.members, weights), key=lambda x: -x[1])
        parts = ", ".join(f"{m.name} {w*100:.0f}%" for m, w in ranked[:4])
        top, top_w = ranked[0]
        note = ""
        if top.key in ("empirical", "uniform") and top_w > 0.4:
            note = (" Ponderea dominanta a unui model FARA memorie inseamna ca modelele "
                    "cu memorie nu au adus nimic: ansamblul spune, corect, ca istoricul "
                    "nu ajuta.")
        return (f"Ponderi invatate din performanta reala pe istoric: {parts}." + note)


class EnsembleState:
    """Stare incrementala: ponderile se actualizeaza din pierderile membrilor.

    Este exact acelasi calcul ca `_weights`, dar acumulat pas cu pas in loc sa
    fie recalculat de la zero -- ceea ce face backtesting-ul fezabil.
    """

    def __init__(self, members, symbols, learning_rate: float):
        self.members = list(members)
        self.symbols = list(symbols)
        self.learning_rate = learning_rate
        self.states = [m.make_state(symbols) for m in self.members]
        self.losses = [0.0] * len(self.members)
        self._last: list[dict[str, float]] | None = None

    def _member_dists(self, history) -> list[dict[str, float]]:
        return [st.predict(history) for st in self.states]

    def weights(self) -> list[float]:
        if not any(self.losses):
            return [1.0 / len(self.members)] * len(self.members)
        best = min(self.losses)
        raw = [math.exp(-self.learning_rate * (l - best)) for l in self.losses]
        total = sum(raw)
        return [r / total for r in raw]

    def predict(self, history) -> dict[str, float]:
        self._last = self._member_dists(history)
        weights = self.weights()
        mixed = {s: 0.0 for s in self.symbols}
        for w, dist in zip(weights, self._last):
            for s in self.symbols:
                mixed[s] += w * dist[s]
        return normalize(mixed, self.symbols)

    def observe(self, history, symbol) -> None:
        dists = self._last if self._last is not None else self._member_dists(history)
        for i, dist in enumerate(dists):
            self.losses[i] += log_loss_bits(dist, symbol)
        for st in self.states:
            st.observe(history, symbol)
        self._last = None


ExponentialWeightsEnsemble.make_state = lambda self, symbols: EnsembleState(
    self.members, symbols, self.learning_rate)
