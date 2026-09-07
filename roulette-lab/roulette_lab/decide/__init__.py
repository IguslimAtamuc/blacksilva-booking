"""Poarta de decizie."""
from .gate import DEFAULTS, REFUSAL, Decision, decide, make_record

__all__ = ["decide", "Decision", "make_record", "REFUSAL", "DEFAULTS"]
