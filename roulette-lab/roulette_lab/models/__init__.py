"""Predictori."""
from .base import Predictor, brier_score, log_loss_bits, normalize
from .baselines import EmpiricalBaseline, UniformBaseline
from .ensemble import ExponentialWeightsEnsemble
from .markov_model import MarkovPredictor, VariableOrderMarkov


def default_models(max_order: int = 3) -> list:
    """Setul standard evaluat de backtesting.

    Ordinea conteaza: primele doua sunt referinte, restul sunt ipoteze.
    """
    members = [EmpiricalBaseline()] + [MarkovPredictor(o) for o in range(1, max_order + 1)] \
        + [VariableOrderMarkov(max_order=max(4, max_order))]
    return [UniformBaseline(), EmpiricalBaseline()] \
        + [MarkovPredictor(o) for o in range(1, max_order + 1)] \
        + [VariableOrderMarkov(max_order=max(4, max_order)),
           ExponentialWeightsEnsemble(members)]


BASELINE_KEY = "empirical"

__all__ = ["Predictor", "normalize", "log_loss_bits", "brier_score",
           "UniformBaseline", "EmpiricalBaseline", "MarkovPredictor",
           "VariableOrderMarkov", "ExponentialWeightsEnsemble",
           "default_models", "BASELINE_KEY"]
