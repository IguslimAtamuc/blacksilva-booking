"""Generarea rapoartelor."""
from .build import build_report
from .manifest import VERSION, build_manifest, code_fingerprint
from .markdown import render

__all__ = ["build_report", "render", "build_manifest", "code_fingerprint", "VERSION"]
