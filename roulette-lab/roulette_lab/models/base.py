"""Contractul predictorilor.

Reguli obligatorii pentru orice model din acest proiect:

  1. Returneaza o DISTRIBUTIE completa, nu un singur simbol. "Rosu" nu e o
     predictie; "Rosu 51%, Negru 43%, Verde 6%" este.
  2. Nicio probabilitate nu poate fi zero. Un model care atribuie 0 unui
     rezultat care apoi apare primeste log-loss infinit -- si pe buna dreptate,
     pentru ca a declarat imposibil ceva posibil.
  3. Vede DOAR prefixul primit. Orice acces la viitor este scurgere de date si
     invalideaza complet backtesting-ul.
  4. Stie sa explice pe ce s-a bazat.
"""
from __future__ import annotations

import math
from typing import Protocol, Sequence


class Predictor(Protocol):
    key: str
    name: str

    def predict(self, prefix: Sequence[str], symbols: Sequence[str]) -> dict[str, float]: ...
    def explain(self, prefix: Sequence[str], symbols: Sequence[str]) -> str: ...


def normalize(scores: dict[str, float], symbols: Sequence[str],
              floor: float = 1e-6) -> dict[str, float]:
    """Transforma scoruri in probabilitati valide, cu prag minim nenul."""
    clean = {s: max(floor, float(scores.get(s, 0.0))) for s in symbols}
    total = sum(clean.values())
    return {s: v / total for s, v in clean.items()}


def log_loss_bits(dist: dict[str, float], actual: str) -> float:
    """-log2 P(rezultatul real). Unitate: biti de surpriza.

    Reperul care conteaza: un model care nu stie nimic despre 3 simboluri
    egal probabile obtine log2(3) = 1.585 biti. Orice model care nu coboara
    sub baseline-ul empiric nu a invatat nimic.
    """
    p = max(1e-12, dist.get(actual, 0.0))
    return -math.log2(p)


def brier_score(dist: dict[str, float], actual: str, symbols: Sequence[str]) -> float:
    """Scor Brier multiclasa: suma patratelor erorilor de probabilitate."""
    return sum((dist.get(s, 0.0) - (1.0 if s == actual else 0.0)) ** 2 for s in symbols)
