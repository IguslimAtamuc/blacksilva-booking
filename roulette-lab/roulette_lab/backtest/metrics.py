"""Metrici de evaluare.

De ce log-loss este metrica principala, si nu acuratetea:
  - acuratetea ignora increderea. Un model care zice "Rosu 51%" si unul care zice
    "Rosu 99%" primesc acelasi punctaj daca iese Rosu, desi al doilea a facut o
    afirmatie mult mai puternica;
  - acuratetea e insensibila pe clase dezechilibrate: cu 49% Rosu, un model care
    zice mereu "Rosu" obtine 49% si pare sa "functioneze";
  - log-loss se masoara in biti si se compara direct cu limita teoretica a
    informatiei disponibile.
Acuratetea ramane raportata pentru ca e intuitiva -- dar nu ea decide nimic.
"""
from __future__ import annotations

import math
from collections import Counter, defaultdict
from typing import Sequence

from ..models.base import brier_score, log_loss_bits


def per_class_metrics(predicted: Sequence[str], actual: Sequence[str],
                      symbols: Sequence[str]) -> dict[str, dict]:
    """Precizie, recall si F1 pentru fiecare simbol."""
    out: dict[str, dict] = {}
    for s in symbols:
        tp = sum(1 for p, a in zip(predicted, actual) if p == s and a == s)
        fp = sum(1 for p, a in zip(predicted, actual) if p == s and a != s)
        fn = sum(1 for p, a in zip(predicted, actual) if p != s and a == s)
        precision = tp / (tp + fp) if tp + fp else 0.0
        recall = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        out[s] = {"tp": tp, "fp": fp, "fn": fn, "support": tp + fn,
                  "precision": precision, "recall": recall, "f1": f1,
                  "predicted_count": tp + fp}
    return out


def calibration_bins(probabilities: Sequence[float], hits: Sequence[bool],
                     n_bins: int = 10) -> list[dict]:
    """Calibrare: cand modelul zice 70%, se intampla in 70% din cazuri?

    Un model necalibrat este periculos chiar daca are acuratete buna, pentru ca
    numarul de incredere afisat utilizatorului este atunci o minciuna.
    """
    bins = [{"lo": i / n_bins, "hi": (i + 1) / n_bins, "n": 0, "sum_p": 0.0, "hits": 0}
            for i in range(n_bins)]
    for p, hit in zip(probabilities, hits):
        idx = min(n_bins - 1, int(p * n_bins))
        bins[idx]["n"] += 1
        bins[idx]["sum_p"] += p
        bins[idx]["hits"] += 1 if hit else 0
    for b in bins:
        b["mean_predicted"] = b["sum_p"] / b["n"] if b["n"] else 0.0
        b["observed"] = b["hits"] / b["n"] if b["n"] else 0.0
    return bins


def expected_calibration_error(bins: Sequence[dict]) -> float:
    total = sum(b["n"] for b in bins)
    if not total:
        return 0.0
    return sum(b["n"] / total * abs(b["mean_predicted"] - b["observed"]) for b in bins)


def summarize(distributions: Sequence[dict], actual: Sequence[str],
              symbols: Sequence[str]) -> dict:
    """Toate metricile pentru o serie de predictii probabiliste."""
    n = len(actual)
    if n == 0:
        return {"n": 0}
    losses = [log_loss_bits(d, a) for d, a in zip(distributions, actual)]
    briers = [brier_score(d, a, symbols) for d, a in zip(distributions, actual)]
    predicted = [max(d, key=d.get) for d in distributions]
    hits = [p == a for p, a in zip(predicted, actual)]
    top_probs = [max(d.values()) for d in distributions]
    bins = calibration_bins(top_probs, hits)

    return {
        "n": n,
        "log_loss_bits": sum(losses) / n,
        "log_loss_series": losses,
        "brier": sum(briers) / n,
        "accuracy": sum(hits) / n,
        "correct": sum(hits),
        "per_class": per_class_metrics(predicted, actual, symbols),
        "calibration_bins": bins,
        "calibration_error": expected_calibration_error(bins),
        "mean_confidence": sum(top_probs) / n,
        "prediction_distribution": dict(Counter(predicted)),
        "perplexity": 2 ** (sum(losses) / n),
    }
