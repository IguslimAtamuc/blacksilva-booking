"""Import / export: CSV, TXT, JSON -- plus migrarea formatului vechi.

Parser-ul e deliberat permisiv la INTRARE (accepta 'R', 'r', 'rosu', 'red',
'ROSU') si strict la IESIRE (scrie mereu forma canonica), pentru ca datele
introduse manual sunt inevitabil neuniforme.
"""
from __future__ import annotations

import csv
import io
import json
import os
import re
from datetime import datetime, timezone
from typing import Any, Iterable

from .schema import PRESETS, Dataset, PredictionRecord, Spin

# Sinonime acceptate la import pentru alfabetul de culori.
COLOR_ALIASES: dict[str, str] = {
    "r": "R", "rosu": "R", "roșu": "R", "red": "R", "rouge": "R",
    "n": "N", "negru": "N", "black": "N", "b": "N", "noir": "N",
    "v": "V", "verde": "V", "green": "V", "g": "V", "zero": "V", "0": "V",
}

# Maparea standard numar -> culoare pe o ruleta europeana (pentru analize derivate).
RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


class ImportError_(ValueError):
    """Eroare de import cu mesaj destinat utilizatorului."""


def normalize_symbol(token: str, preset: str) -> str:
    token = str(token).strip()
    if not token:
        raise ImportError_("valoare goala")
    if preset == "color3":
        key = token.lower()
        if key in COLOR_ALIASES:
            return COLOR_ALIASES[key]
        if token.upper() in ("R", "N", "V"):
            return token.upper()
        raise ImportError_(
            f"nu inteleg valoarea {token!r}; foloseste R/N/V (sau rosu/negru/verde)"
        )
    if preset == "roulette37":
        if not token.lstrip("-").isdigit() or not 0 <= int(token) <= 36:
            raise ImportError_(f"numarul {token!r} nu este intre 0 si 36")
        return str(int(token))
    return token


def number_to_color(number: int) -> str:
    if number == 0:
        return "V"
    return "R" if number in RED_NUMBERS else "N"


def parse_timestamp(token: str) -> float | None:
    token = str(token).strip()
    if not token:
        return None
    # epoca in secunde sau milisecunde
    if re.fullmatch(r"\d{9,13}(\.\d+)?", token):
        value = float(token)
        return value / 1000.0 if value > 1e11 else value
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M",
                "%Y-%m-%d", "%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M"):
        try:
            return datetime.strptime(token, fmt).replace(tzinfo=timezone.utc).timestamp()
        except ValueError:
            continue
    try:  # ISO-8601 cu fus orar
        return datetime.fromisoformat(token.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


# --------------------------------------------------------------------------
# Import
# --------------------------------------------------------------------------
def load_csv(text: str, preset: str = "color3", name: str = "import-csv") -> Dataset:
    """Citeste CSV cu antet. Coloana obligatorie: `value` (sau `rezultat`).

    Coloane optionale recunoscute: index, timestamp/ts/time, session/sesiune,
    plus orice alta coloana, care ajunge in `meta`.
    """
    sniff = text.lstrip()
    if not sniff:
        raise ImportError_("fisierul CSV este gol")
    delimiter = ";" if sniff.splitlines()[0].count(";") > sniff.splitlines()[0].count(",") else ","
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    if not reader.fieldnames:
        raise ImportError_("CSV-ul nu are antet")
    header = {(h or "").strip().lower(): (h or "") for h in reader.fieldnames}

    def column(*candidates: str) -> str | None:
        for c in candidates:
            if c in header:
                return header[c]
        return None

    col_value = column("value", "rezultat", "outcome", "culoare", "color", "numar", "number")
    if col_value is None:
        raise ImportError_(
            "CSV-ul trebuie sa aiba o coloana 'value' (sau 'rezultat'). "
            f"Coloane gasite: {', '.join(reader.fieldnames)}"
        )
    col_ts = column("ts", "timestamp", "time", "ora", "data")
    col_session = column("session", "sesiune", "run")
    known = {c for c in (col_value, col_ts, col_session) if c}

    ds = Dataset(preset=preset, name=name, source="csv")
    for line_no, row in enumerate(reader, start=2):
        raw = (row.get(col_value) or "").strip()
        if not raw:
            continue
        try:
            value = normalize_symbol(raw, preset)
        except ImportError_ as exc:
            raise ImportError_(f"linia {line_no}: {exc}") from exc
        meta = {k: v for k, v in row.items()
                if k and k not in known and v not in (None, "")}
        ds.add(value,
               ts=parse_timestamp(row.get(col_ts, "")) if col_ts else None,
               session=(row.get(col_session) or None) if col_session else None,
               meta=meta)
    if not len(ds):
        raise ImportError_("nu am gasit niciun rand valid in CSV")
    return ds


def load_text(text: str, preset: str = "color3", name: str = "import-txt") -> Dataset:
    """Citeste TXT: un rezultat pe linie, separate prin virgula/spatiu, sau lipite ('RRNVR')."""
    stripped = "\n".join(l for l in text.splitlines() if not l.strip().startswith("#"))
    tokens: list[str]
    if re.search(r"[,\s;]", stripped.strip()):
        tokens = [t for t in re.split(r"[,\s;]+", stripped) if t]
    elif preset == "color3":
        tokens = list(stripped.strip())          # sir lipit: "RRNVR"
    else:
        tokens = [stripped.strip()]
    ds = Dataset(preset=preset, name=name, source="txt")
    for pos, token in enumerate(tokens, start=1):
        try:
            ds.add(normalize_symbol(token, preset))
        except ImportError_ as exc:
            raise ImportError_(f"elementul #{pos}: {exc}") from exc
    if not len(ds):
        raise ImportError_("nu am gasit niciun rezultat in text")
    return ds


def load_json(text_or_obj: str | dict, name: str = "import-json") -> Dataset:
    """Citeste formatul nativ SAU formatul vechi al predictor.py (migrare)."""
    raw = json.loads(text_or_obj) if isinstance(text_or_obj, str) else text_or_obj
    if isinstance(raw, list):                     # lista simpla de valori
        ds = Dataset(preset="color3", name=name, source="json")
        for v in raw:
            ds.add(normalize_symbol(v, "color3"))
        return ds
    if "spins" in raw:                            # format nativ
        return Dataset.from_dict(raw)
    if "history" in raw:                          # format vechi predictor.py
        return migrate_legacy(raw, name=name)
    raise ImportError_("JSON nerecunoscut: astept cheia 'spins' sau 'history'")


def migrate_legacy(raw: dict, name: str = "legacy") -> Dataset:
    """Converteste history.json din tool-ul vechi in formatul nativ.

    Predictiile vechi sunt pastrate ca istoric, dar marcate `gated=False` si
    `model="legacy-v2"`: nu au trecut prin nicio poarta de evidenta, deci nu
    pot fi folosite ca dovada a vreunei capacitati predictive.
    """
    ds = Dataset(preset="color3", name=name, source="legacy-import")
    ds.notes = "Importat din history.json (predictor.py v2). Fara timestamp-uri per rotire."
    for value in raw.get("history", []):
        ds.add(normalize_symbol(value, "color3"))
    saved_at = parse_timestamp(raw.get("saved_at", "")) or 0.0
    # In formatul vechi, predictia #i viza rotirea #(i+1).
    for i, rec in enumerate(raw.get("predictions", [])):
        predicted, actual = rec.get("predicted"), rec.get("actual")
        if predicted is None or actual is None:
            continue
        ds.predictions.append(PredictionRecord(
            at_index=i + 1,
            predicted=normalize_symbol(predicted, "color3"),
            probabilities={},
            confidence=0.0,
            model="legacy-v2",
            gated=False,
            reason="Import din tool-ul vechi; predictie neverificata statistic.",
            ts=saved_at,
            actual=normalize_symbol(actual, "color3"),
            correct=bool(rec.get("correct")),
        ))
    return ds


def load_any(text: str, filename: str = "", preset: str = "color3") -> Dataset:
    """Detecteaza formatul dupa extensie, apoi dupa continut."""
    ext = os.path.splitext(filename)[1].lower()
    stem = os.path.splitext(os.path.basename(filename))[0] or "import"
    if ext == ".json":
        return load_json(text, name=stem)
    if ext == ".csv":
        return load_csv(text, preset, name=stem)
    if ext in (".txt", ".dat", ""):
        head = text.lstrip()[:1]
        if head in "{[":
            return load_json(text, name=stem)
        first = text.strip().splitlines()[0] if text.strip() else ""
        if ("," in first or ";" in first) and re.search(r"[a-z_]+", first, re.I) \
                and any(k in first.lower() for k in ("value", "rezultat", "ts", "timestamp")):
            return load_csv(text, preset, name=stem)
        return load_text(text, preset, name=stem)
    raise ImportError_(f"extensie nesuportata: {ext or '(fara)'} -- foloseste .csv, .txt sau .json")


# --------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------
def dump_csv(ds: Dataset) -> str:
    out = io.StringIO()
    meta_keys = sorted({k for s in ds.spins for k in s.meta})
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(["index", "value", "label", "ts", "iso_time", "session", *meta_keys])
    for s in ds.spins:
        dt = s.datetime
        writer.writerow([
            s.index, s.value, ds.label(s.value),
            "" if s.ts is None else f"{s.ts:.3f}",
            dt.isoformat() if dt else "",
            s.session or "",
            *[s.meta.get(k, "") for k in meta_keys],
        ])
    return out.getvalue()


def dump_json(ds: Dataset, indent: int = 2) -> str:
    return json.dumps(ds.to_dict(), indent=indent, ensure_ascii=False)


def dump_text(ds: Dataset) -> str:
    return "".join(ds.values) if ds.preset == "color3" else ",".join(ds.values)


def save_dataset(ds: Dataset, path: str) -> None:
    tmp = f"{path}.tmp"
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(dump_json(ds))
    os.replace(tmp, path)          # scriere atomica: nu pierdem datele la crash


def read_dataset(path: str) -> Dataset:
    with open(path, "r", encoding="utf-8") as fh:
        return load_json(fh.read(), name=os.path.splitext(os.path.basename(path))[0])
