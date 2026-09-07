"""Manifest de reproductibilitate.

Ca sa poti demonstra la scoala CUM ai ajuns la o concluzie, raportul trebuie sa
contina tot ce ar permite cuiva sa refaca exact aceleasi cifre: datele (prin
amprenta lor), versiunea codului, seed-ul aleator si parametrii folositi.
"""
from __future__ import annotations

import hashlib
import os
import platform
import sys
from datetime import datetime, timezone

from ..data.schema import Dataset

VERSION = "1.0.0"


def code_fingerprint() -> str:
    """SHA-256 peste toate sursele pachetului -- identifica versiunea exacta a codului."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    digest = hashlib.sha256()
    for folder, _, files in sorted(os.walk(root)):
        if "__pycache__" in folder:
            continue
        for name in sorted(files):
            if name.endswith(".py"):
                path = os.path.join(folder, name)
                digest.update(os.path.relpath(path, root).encode())
                with open(path, "rb") as fh:
                    digest.update(fh.read())
    return digest.hexdigest()


def build_manifest(ds: Dataset, seed: int, config: dict) -> dict:
    return {
        "tool": "roulette-lab",
        "tool_version": VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "random_seed": seed,
        "config": dict(config),
        "dataset": {
            "name": ds.name,
            "n_spins": len(ds),
            "alphabet": ds.symbols,
            "preset": ds.preset,
            "source": ds.source,
            "fingerprint_sha256": ds.fingerprint(),
            "has_timestamps": ds.has_timestamps,
            "has_sessions": ds.has_sessions,
            "n_sessions": len(ds.sessions()),
        },
        "code_fingerprint_sha256": code_fingerprint(),
        "reproduce_with": (
            f"python -m roulette_lab report --data <fisierul-tau> --seed {seed}"
        ),
    }
