"""Bateria de analize statistice."""
from .base import (
    EVIDENCE, INSUFFICIENT, NO_EVIDENCE, WEAK, VERDICT_LABELS,
    AnalysisReport, AnalysisResult, available, register, run_all,
)

__all__ = ["AnalysisReport", "AnalysisResult", "run_all", "register", "available",
           "EVIDENCE", "WEAK", "NO_EVIDENCE", "INSUFFICIENT", "VERDICT_LABELS"]
