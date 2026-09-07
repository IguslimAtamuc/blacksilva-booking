"""Modele Markov cu netezire si backoff -- forma corecta a ideii de 'sequence matching'.

Tool-ul vechi cauta manual secvente identice si raporta ce a urmat. Aceea este,
matematic, exact estimarea unui model Markov de ordin variabil -- doar ca fara
netezire si fara backoff, adica in varianta care supra-invata cel mai tare.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from typing import Sequence

from .base import normalize


class MarkovPredictor:
    """Markov de ordin fix, cu netezire Krichevsky-Trofimov (alpha = 1/2)."""

    def __init__(self, order: int = 1, alpha: float = 0.5):
        self.order = order
        self.alpha = alpha
        self.key = f"markov{order}"
        self.name = f"Markov ordin {order}"

    def _context_counts(self, prefix: Sequence[str]) -> Counter:
        if self.order == 0:
            return Counter(prefix)
        if len(prefix) < self.order:
            return Counter()
        context = tuple(prefix[-self.order:])
        counts: Counter = Counter()
        for i in range(self.order, len(prefix)):
            if tuple(prefix[i - self.order:i]) == context:
                counts[prefix[i]] += 1
        return counts

    def predict(self, prefix, symbols) -> dict[str, float]:
        counts = self._context_counts(prefix)
        return normalize({s: counts.get(s, 0) + self.alpha for s in symbols}, symbols)

    def explain(self, prefix, symbols) -> str:
        counts = self._context_counts(prefix)
        total = sum(counts.values())
        if self.order == 0:
            return "Frecventele globale, netezite."
        context = "".join(prefix[-self.order:]) if len(prefix) >= self.order else "?"
        if total == 0:
            return (f"Contextul [{context}] nu a mai aparut niciodata in istoric. "
                    "Modelul cade pe netezire, adica pe aproape-uniform.")
        parts = ", ".join(f"{s}:{counts.get(s, 0)}" for s in symbols)
        return (f"Contextul [{context}] a mai aparut de {total} ori. Dupa el a urmat: "
                f"{parts}. Netezire KT (alpha={self.alpha}) ca sa nu declaram imposibil "
                f"un rezultat nevazut. Atentie: cu {total} observatii, marja de eroare "
                f"a acestor procente este de ordinul +/-{50/max(1,total**0.5):.0f} puncte.")


class VariableOrderMarkov:
    """Markov de ordin variabil cu backoff: foloseste cel mai lung context vazut destul.

    Amestecul intre ordine se face dupa numarul de observatii pe context
    (interpolare de tip Witten-Bell), nu dupa o constanta aleasa la ochi.
    """

    key = "vom"
    name = "Markov de ordin variabil (backoff)"

    def __init__(self, max_order: int = 4, alpha: float = 0.5):
        self.max_order = max_order
        self.alpha = alpha

    def predict(self, prefix, symbols) -> dict[str, float]:
        k = len(symbols)
        dist = {s: 1.0 / k for s in symbols}          # pornim de la uniform
        for order in range(0, self.max_order + 1):
            if len(prefix) < order:
                break
            counts = MarkovPredictor(order, self.alpha)._context_counts(prefix)
            total = sum(counts.values())
            if total == 0:
                continue
            distinct = sum(1 for s in symbols if counts.get(s, 0) > 0)
            # Witten-Bell: increderea in acest ordin creste cu numarul de observatii
            weight = total / (total + max(1, distinct))
            higher = {s: counts.get(s, 0) / total for s in symbols}
            dist = {s: weight * higher[s] + (1 - weight) * dist[s] for s in symbols}
        return normalize(dist, symbols)

    def explain(self, prefix, symbols) -> str:
        used = []
        for order in range(0, self.max_order + 1):
            if len(prefix) < order:
                break
            total = sum(MarkovPredictor(order, self.alpha)._context_counts(prefix).values())
            if total:
                ctx = "".join(prefix[-order:]) if order else "(global)"
                used.append(f"ordin {order} [{ctx}]: {total} obs.")
        return ("Combina mai multe lungimi de context, ponderate dupa cate observatii "
                "sustin fiecare: " + "; ".join(used) + ". Contextele lungi primesc "
                "pondere mare doar daca au fost vazute des -- asta impiedica "
                "supra-invatarea pe o singura potrivire.")


# --------------------------------------------------------------------------
# Stare incrementala pentru backtesting
# --------------------------------------------------------------------------
# Backtesting-ul walk-forward re-prezice pentru fiecare pozitie. Daca fiecare
# predictie rescaneaza tot istoricul, costul total e O(n^3) si devine imposibil
# peste cateva sute de rotiri. Starile de mai jos mentin aceleasi numaratori
# incremental, deci fiecare predictie costa O(1). Rezultatele sunt IDENTICE --
# doar timpul difera (verificat in tests/test_models.py).

class MarkovState:
    def __init__(self, order: int, alpha: float, symbols: Sequence[str]):
        self.order, self.alpha, self.symbols = order, alpha, list(symbols)
        self.table: dict[tuple, Counter] = defaultdict(Counter)

    def observe(self, history: Sequence[str], symbol: str) -> None:
        """Inregistreaza ca dupa `history` a urmat `symbol`."""
        if len(history) >= self.order:
            self.table[tuple(history[len(history) - self.order:])][symbol] += 1

    def counts(self, history: Sequence[str]) -> Counter:
        if len(history) < self.order:
            return Counter()
        return self.table.get(tuple(history[len(history) - self.order:]), Counter())

    def predict(self, history: Sequence[str]) -> dict[str, float]:
        counts = self.counts(history)
        return normalize({s: counts.get(s, 0) + self.alpha for s in self.symbols},
                         self.symbols)


class VOMState:
    def __init__(self, max_order: int, alpha: float, symbols: Sequence[str]):
        self.symbols = list(symbols)
        self.states = [MarkovState(o, alpha, symbols) for o in range(max_order + 1)]

    def observe(self, history: Sequence[str], symbol: str) -> None:
        for st in self.states:
            st.observe(history, symbol)

    def predict(self, history: Sequence[str]) -> dict[str, float]:
        k = len(self.symbols)
        dist = {s: 1.0 / k for s in self.symbols}
        for st in self.states:
            if len(history) < st.order:
                break
            counts = st.counts(history)
            total = sum(counts.values())
            if total == 0:
                continue
            distinct = sum(1 for s in self.symbols if counts.get(s, 0) > 0)
            weight = total / (total + max(1, distinct))
            higher = {s: counts.get(s, 0) / total for s in self.symbols}
            dist = {s: weight * higher[s] + (1 - weight) * dist[s] for s in self.symbols}
        return normalize(dist, self.symbols)


def _markov_make_state(self, symbols):
    return MarkovState(self.order, self.alpha, symbols)


def _vom_make_state(self, symbols):
    return VOMState(self.max_order, self.alpha, symbols)


MarkovPredictor.make_state = _markov_make_state
VariableOrderMarkov.make_state = _vom_make_state
