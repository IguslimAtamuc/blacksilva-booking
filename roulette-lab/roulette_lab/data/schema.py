"""Modelul de date: o rotire (Spin) si un set de date (Dataset).

Decizie de design: valoarea unui spin este un STRING arbitrar, nu un enum de
culori. Asta permite acelasi tool sa analizeze culori (R/N/V), numere de slot
(0-36) sau orice alt alfabet, fara sa schimbam nimic in stratul de analiza.
Numarul slotului contine ~5.2 biti de informatie pe rotire, culoarea doar ~1.4:
diferenta decide daca identificarea unui PRNG este macar teoretic posibila.
"""
from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from typing import Any, Iterable, Sequence

SCHEMA_VERSION = 1

# Alfabete predefinite. `ui` da culoarea de afisare in interfata.
PRESETS: dict[str, dict[str, Any]] = {
    "color3": {
        "name": "Culori (Rosu / Negru / Verde)",
        "symbols": ["R", "N", "V"],
        "labels": {"R": "Rosu", "N": "Negru", "V": "Verde"},
        "ui": {"R": "#e0242b", "N": "#2b2f3a", "V": "#12a150"},
        "bits_per_spin": math.log2(3),
        "note": "Pierzi ~75% din informatia unei rulete de 37 de sloturi.",
    },
    "roulette37": {
        "name": "Numere ruleta europeana (0-36)",
        "symbols": [str(i) for i in range(37)],
        "labels": {str(i): str(i) for i in range(37)},
        "ui": {},
        "bits_per_spin": math.log2(37),
        "note": "Formatul recomandat: pastreaza toata informatia rotirii.",
    },
    "binary": {
        "name": "Binar (0/1)",
        "symbols": ["0", "1"],
        "labels": {"0": "0", "1": "1"},
        "ui": {"0": "#2b2f3a", "1": "#e0242b"},
        "bits_per_spin": 1.0,
        "note": "Util pentru testarea tool-ului pe generatoare cunoscute.",
    },
}


@dataclass
class Spin:
    """O singura rotire observata."""

    index: int                       # pozitia in ordinea observarii (0-based)
    value: str                       # rezultatul, ca simbol din alfabet
    ts: float | None = None          # timestamp UNIX (secunde), daca e cunoscut
    session: str | None = None       # id de sesiune de joc (restart = sesiune noua)
    meta: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {k: v for k, v in asdict(self).items() if v is not None and v != {}}

    @classmethod
    def from_dict(cls, raw: dict, fallback_index: int = 0) -> "Spin":
        return cls(
            index=int(raw.get("index", fallback_index)),
            value=str(raw["value"]).strip(),
            ts=float(raw["ts"]) if raw.get("ts") not in (None, "") else None,
            session=str(raw["session"]) if raw.get("session") not in (None, "") else None,
            meta=dict(raw.get("meta") or {}),
        )

    @property
    def datetime(self) -> datetime | None:
        if self.ts is None:
            return None
        return datetime.fromtimestamp(self.ts, tz=timezone.utc)


@dataclass
class PredictionRecord:
    """O predictie emisa, impreuna cu ce s-a intamplat de fapt.

    Se scrie in momentul emiterii (cu `actual=None`) si se completeaza cand
    urmatorul spin este introdus. Asta face imposibila rescrierea istoricului
    de predictii dupa ce rezultatul e cunoscut.
    """

    at_index: int                    # cate spin-uri erau cunoscute la emitere
    predicted: str | None
    probabilities: dict[str, float]
    confidence: float
    model: str
    gated: bool                      # True daca poarta de evidenta a permis predictia
    reason: str
    ts: float
    actual: str | None = None
    correct: bool | None = None

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, raw: dict) -> "PredictionRecord":
        return cls(
            at_index=int(raw["at_index"]),
            predicted=raw.get("predicted"),
            probabilities={str(k): float(v) for k, v in (raw.get("probabilities") or {}).items()},
            confidence=float(raw.get("confidence", 0.0)),
            model=str(raw.get("model", "?")),
            gated=bool(raw.get("gated", False)),
            reason=str(raw.get("reason", "")),
            ts=float(raw.get("ts", 0.0)),
            actual=raw.get("actual"),
            correct=raw.get("correct"),
        )


class Dataset:
    """Colectia de rotiri plus metadatele necesare pentru reproductibilitate."""

    def __init__(self, spins: Sequence[Spin] | None = None, preset: str = "color3",
                 name: str = "dataset", symbols: Sequence[str] | None = None,
                 source: str = "manual", notes: str = ""):
        self.spins: list[Spin] = list(spins or [])
        self.preset = preset if preset in PRESETS else "custom"
        self._symbols = list(symbols) if symbols else None
        self.name = name
        self.source = source
        self.notes = notes
        self.predictions: list[PredictionRecord] = []
        self.created_at = datetime.now(timezone.utc).isoformat()
        self._reindex()

    # -- alfabet ---------------------------------------------------------
    @property
    def symbols(self) -> list[str]:
        """Alfabetul rezultatelor posibile, in ordine stabila.

        Important: alfabetul include simboluri care NU au aparut inca, daca
        preset-ul le declara. Un simbol neobservat nu inseamna un simbol
        imposibil, iar modelele trebuie sa ii aloce probabilitate nenula.
        """
        if self._symbols:
            return list(self._symbols)
        if self.preset in PRESETS:
            return list(PRESETS[self.preset]["symbols"])
        seen: list[str] = []
        for s in self.spins:
            if s.value not in seen:
                seen.append(s.value)
        return sorted(seen)

    @property
    def observed_symbols(self) -> list[str]:
        seen: list[str] = []
        for s in self.spins:
            if s.value not in seen:
                seen.append(s.value)
        return seen

    def label(self, symbol: str) -> str:
        if self.preset in PRESETS:
            return PRESETS[self.preset]["labels"].get(symbol, symbol)
        return symbol

    @property
    def preset_info(self) -> dict:
        return PRESETS.get(self.preset, {
            "name": "Alfabet personalizat",
            "symbols": self.symbols,
            "labels": {s: s for s in self.symbols},
            "ui": {},
            "bits_per_spin": math.log2(max(2, len(self.symbols))),
            "note": "",
        })

    # -- continut --------------------------------------------------------
    @property
    def values(self) -> list[str]:
        return [s.value for s in self.spins]

    def __len__(self) -> int:
        return len(self.spins)

    def _reindex(self) -> None:
        for i, s in enumerate(self.spins):
            s.index = i

    def add(self, value: str, ts: float | None = None, session: str | None = None,
            meta: dict | None = None) -> Spin:
        value = str(value).strip()
        if not value:
            raise ValueError("valoarea unui spin nu poate fi goala")
        spin = Spin(index=len(self.spins), value=value, ts=ts, session=session,
                    meta=meta or {})
        self.spins.append(spin)
        self._resolve_pending_prediction(value)
        return spin

    def extend(self, values: Iterable[str], **kwargs) -> int:
        count = 0
        for v in values:
            self.add(v, **kwargs)
            count += 1
        return count

    def undo(self) -> Spin | None:
        if not self.spins:
            return None
        removed = self.spins.pop()
        # invalidam evaluarea predictiei care viza spin-ul sters
        for rec in self.predictions:
            if rec.at_index == removed.index:
                rec.actual, rec.correct = None, None
        return removed

    def clear(self) -> None:
        self.spins.clear()
        self.predictions.clear()

    # -- predictii -------------------------------------------------------
    def log_prediction(self, record: PredictionRecord) -> None:
        # o singura predictie per pozitie: reemiterea o inlocuieste pe cea veche
        self.predictions = [p for p in self.predictions if p.at_index != record.at_index]
        self.predictions.append(record)
        self.predictions.sort(key=lambda p: p.at_index)

    def _resolve_pending_prediction(self, actual: str) -> None:
        target = len(self.spins) - 1
        for rec in self.predictions:
            if rec.at_index == target and rec.actual is None:
                rec.actual = actual
                rec.correct = (rec.predicted == actual) if rec.predicted else None

    @property
    def resolved_predictions(self) -> list[PredictionRecord]:
        return [p for p in self.predictions if p.actual is not None and p.predicted]

    # -- sesiuni ---------------------------------------------------------
    def sessions(self) -> dict[str, list[Spin]]:
        groups: dict[str, list[Spin]] = {}
        for s in self.spins:
            groups.setdefault(s.session or "default", []).append(s)
        return groups

    @property
    def has_timestamps(self) -> bool:
        return any(s.ts is not None for s in self.spins)

    @property
    def has_sessions(self) -> bool:
        return len({s.session for s in self.spins if s.session}) > 1

    # -- serializare -----------------------------------------------------
    def to_dict(self) -> dict:
        return {
            "schema_version": SCHEMA_VERSION,
            "name": self.name,
            "preset": self.preset,
            "symbols": self._symbols,
            "source": self.source,
            "notes": self.notes,
            "created_at": self.created_at,
            "spins": [s.to_dict() for s in self.spins],
            "predictions": [p.to_dict() for p in self.predictions],
        }

    @classmethod
    def from_dict(cls, raw: dict) -> "Dataset":
        ds = cls(
            spins=[Spin.from_dict(s, i) for i, s in enumerate(raw.get("spins", []))],
            preset=raw.get("preset", "color3"),
            name=raw.get("name", "dataset"),
            symbols=raw.get("symbols"),
            source=raw.get("source", "manual"),
            notes=raw.get("notes", ""),
        )
        ds.created_at = raw.get("created_at", ds.created_at)
        ds.predictions = [PredictionRecord.from_dict(p) for p in raw.get("predictions", [])]
        return ds

    def fingerprint(self) -> str:
        """SHA-256 al continutului -- ancora de reproductibilitate a raportului.

        Se calculeaza doar peste rotiri (nu peste predictii sau note), ca doua
        analize ale acelorasi date sa aiba acelasi fingerprint.
        """
        payload = json.dumps(
            [[s.index, s.value, s.ts, s.session] for s in self.spins],
            sort_keys=True, separators=(",", ":"),
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()
