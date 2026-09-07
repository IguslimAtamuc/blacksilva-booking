"""Server local pentru interfata web.

Foloseste doar http.server din biblioteca standard: zero dependinte, ruleaza
offline. Analizele grele sunt puse in cache dupa amprenta datelor, ca sa nu
reruleze zeci de mii de permutari la fiecare click.
"""
from __future__ import annotations

import json
import os
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from .analysis import run_all
from .backtest import run_backtest
from .data.io import (ImportError_, dump_csv, dump_json, dump_text, load_any,
                      normalize_symbol, read_dataset, save_dataset)
from .data.schema import PRESETS, Dataset
from .decide import decide, make_record
from .live import LiveEngine
from .prng import identify
from .report import build_report, render

WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
MIME = {".html": "text/html; charset=utf-8", ".js": "application/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8", ".svg": "image/svg+xml"}


class Store:
    """Datele + cache-ul rezultatelor, protejate de un lock (serverul e multi-thread)."""

    def __init__(self, path: str, preset: str):
        self.path = path
        self.preset = preset
        self.lock = threading.Lock()
        self._cache: dict[str, tuple[str, object]] = {}
        self.ds = self._load()
        self.live = LiveEngine(self.ds.symbols)
        self.live.rebuild(self.ds.values)

    def _load(self) -> Dataset:
        if os.path.exists(self.path):
            return read_dataset(self.path)
        return Dataset(preset=self.preset, name="dataset")

    def save(self) -> None:
        save_dataset(self.ds, self.path)
        self._cache.clear()          # datele s-au schimbat: rezultatele vechi nu mai sunt valide

    def rebuild_live(self) -> None:
        """Reconstruieste motorul live dupa undo/import/clear, cand ordinea s-a schimbat."""
        self.live = LiveEngine(self.ds.symbols)
        self.live.rebuild(self.ds.values)

    def cached(self, key: str, compute):
        fingerprint = self.ds.fingerprint()
        hit = self._cache.get(key)
        if hit and hit[0] == fingerprint:
            return hit[1]
        value = compute()
        self._cache[key] = (fingerprint, value)
        return value


def _state_payload(store: Store) -> dict:
    ds = store.ds
    info = ds.preset_info
    from collections import Counter
    counts = Counter(ds.values)
    resolved = ds.resolved_predictions
    return {
        "name": ds.name,
        "preset": ds.preset,
        "preset_name": info.get("name", ds.preset),
        "symbols": ds.symbols,
        "labels": {s: ds.label(s) for s in ds.symbols},
        "colors": info.get("ui", {}),
        "n": len(ds),
        "counts": {s: counts.get(s, 0) for s in ds.symbols},
        "fingerprint": ds.fingerprint(),
        "has_timestamps": ds.has_timestamps,
        "sessions": {k: len(v) for k, v in ds.sessions().items()},
        "notes": ds.notes,
        "spins": [{"index": s.index, "value": s.value, "ts": s.ts,
                   "session": s.session, "meta": s.meta} for s in ds.spins],
        "predictions": [p.to_dict() for p in ds.predictions],
        "prediction_accuracy": (
            {"total": len(resolved),
             "correct": sum(1 for r in resolved if r.correct),
             "gated_total": sum(1 for r in resolved if r.gated),
             "gated_correct": sum(1 for r in resolved if r.gated and r.correct)}
            if resolved else None),
        "presets": {k: {"name": v["name"], "symbols": v["symbols"]} for k, v in PRESETS.items()},
    }


class Handler(BaseHTTPRequestHandler):
    store: Store = None            # injectat in `serve`
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):    # jurnal mai linistit
        if "/api/" in str(args[0] if args else ""):
            print(f"  {self.address_string()} {fmt % args}")

    # -- utilitare -------------------------------------------------------
    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, payload, code: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")
        self._send(code, body, "application/json; charset=utf-8")

    def _error(self, message: str, code: int = 400) -> None:
        self._json({"error": message}, code)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"corp JSON invalid: {exc}") from exc

    # -- rutare ----------------------------------------------------------
    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        route = parsed.path
        query = parse_qs(parsed.query)
        store = self.store
        try:
            if route in ("/", "/index.html"):
                return self._static("index.html")
            if route in ("/app.js", "/style.css"):
                return self._static(route.lstrip("/"))
            if route == "/api/state":
                with store.lock:
                    return self._json(_state_payload(store))
            if route == "/api/live":
                with store.lock:
                    if not len(store.ds):
                        return self._error("Nu exista date. Introdu primul rezultat.")
                    return self._json(store.live.recommendation(store.ds))
            if route == "/api/analyze":
                with store.lock:
                    if len(store.ds) < 10:
                        return self._error("Sunt necesare cel putin 10 rotiri pentru analiza.")
                    report = store.cached("analyze", lambda: run_all(store.ds))
                    return self._json(report.to_dict())
            if route == "/api/prng":
                with store.lock:
                    seeds = int(query.get("max_seeds", ["20000"])[0])
                    return self._json(store.cached(
                        f"prng{seeds}", lambda: identify(store.ds, max_seeds=seeds)))
            if route == "/api/backtest":
                with store.lock:
                    if len(store.ds) < 20:
                        return self._error("Sunt necesare cel putin 20 de rotiri "
                                           "pentru backtesting.")
                    warm = query.get("warmup", [None])[0]
                    warm = int(warm) if warm else None
                    return self._json(store.cached(
                        f"bt{warm}",
                        lambda: run_backtest(store.ds, warmup=warm)).to_dict())
            if route == "/api/export":
                with store.lock:
                    fmt = query.get("format", ["csv"])[0]
                    if fmt not in ("csv", "json", "txt"):
                        return self._error("format necunoscut")
                    text = {"csv": dump_csv, "json": dump_json, "txt": dump_text}[fmt](store.ds)
                    ctype = {"csv": "text/csv", "json": "application/json",
                             "txt": "text/plain"}[fmt]
                    self.send_response(200)
                    self.send_header("Content-Type", f"{ctype}; charset=utf-8")
                    body = text.encode("utf-8")
                    self.send_header("Content-Length", str(len(body)))
                    self.send_header("Content-Disposition",
                                     f'attachment; filename="{store.ds.name}.{fmt}"')
                    self.end_headers()
                    return self.wfile.write(body)
            if route == "/api/report":
                with store.lock:
                    report = store.cached("report", lambda: build_report(store.ds))
                    if query.get("format", ["md"])[0] == "json":
                        return self._json(report)
                    body = render(report).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "text/markdown; charset=utf-8")
                    self.send_header("Content-Length", str(len(body)))
                    self.send_header("Content-Disposition",
                                     f'attachment; filename="raport-{store.ds.name}.md"')
                    self.end_headers()
                    return self.wfile.write(body)
            return self._error("ruta necunoscuta", 404)
        except Exception as exc:                      # nu lasam serverul sa cada
            return self._error(f"{type(exc).__name__}: {exc}", 500)

    def do_POST(self) -> None:
        route = urlparse(self.path).path
        store = self.store
        try:
            body = self._body()
            if route == "/api/spins":
                with store.lock:
                    values = body.get("values") or []
                    if isinstance(values, str):
                        values = [values]
                    session = body.get("session") or None
                    ts = body.get("ts")
                    added = 0
                    for raw in values:
                        symbol = normalize_symbol(raw, store.ds.preset)
                        store.ds.add(symbol, ts=float(ts) if ts else time.time(),
                                     session=session)
                        store.live.observe(symbol)   # invata incremental, in O(1)
                        added += 1
                    store.save()
                    return self._json({"added": added,
                                       "live": store.live.recommendation(store.ds),
                                       **_state_payload(store)})
            if route == "/api/undo":
                with store.lock:
                    removed = store.ds.undo()
                    store.save()
                    store.rebuild_live()
                    return self._json({"removed": removed.value if removed else None,
                                       "live": (store.live.recommendation(store.ds)
                                                if len(store.ds) else None),
                                       **_state_payload(store)})
            if route == "/api/clear":
                with store.lock:
                    store.ds.clear()
                    store.save()
                    store.rebuild_live()
                    return self._json(_state_payload(store))
            if route == "/api/import":
                with store.lock:
                    text = body.get("text", "")
                    filename = body.get("filename", "import.txt")
                    preset = body.get("preset", store.ds.preset)
                    try:
                        incoming = load_any(text, filename, preset)
                    except ImportError_ as exc:
                        return self._error(str(exc))
                    if body.get("append") and len(store.ds):
                        for spin in incoming.spins:
                            store.ds.add(spin.value, spin.ts, spin.session, spin.meta)
                    else:
                        store.ds = incoming
                        store.path = store.path
                    store.save()
                    store.rebuild_live()
                    return self._json({"imported": len(incoming),
                                       "live": (store.live.recommendation(store.ds)
                                                if len(store.ds) else None),
                                       **_state_payload(store)})
            if route == "/api/predict":
                with store.lock:
                    # Refolosim backtestul si analiza din cache: `decide` le-ar
                    # recalcula de la zero (zeci de mii de permutari), ceea ce ar
                    # face butonul sa para blocat 30+ secunde.
                    def _decide():
                        bt = store.cached("btNone",
                                          lambda: run_backtest(store.ds)) if len(store.ds) >= 20 else None
                        an = store.cached("analyze", lambda: run_all(store.ds)) \
                            if len(store.ds) >= 10 else None
                        return decide(store.ds, backtest=bt, analysis=an)

                    decision = store.cached("decide", _decide)
                    if body.get("log"):
                        store.ds.log_prediction(make_record(decision, len(store.ds)))
                        save_dataset(store.ds, store.path)
                    return self._json({"decision": decision.to_dict(),
                                       "state": _state_payload(store)})
            if route == "/api/preset":
                with store.lock:
                    preset = body.get("preset", "color3")
                    if preset not in PRESETS:
                        return self._error("preset necunoscut")
                    if len(store.ds):
                        return self._error("Nu pot schimba alfabetul cat timp exista date. "
                                           "Exporta datele, apoi sterge-le.")
                    store.ds = Dataset(preset=preset, name=store.ds.name)
                    store.save()
                    return self._json(_state_payload(store))
            return self._error("ruta necunoscuta", 404)
        except ValueError as exc:
            return self._error(str(exc))
        except Exception as exc:
            return self._error(f"{type(exc).__name__}: {exc}", 500)

    def _static(self, name: str) -> None:
        path = os.path.join(WEB_DIR, name)
        if not os.path.isfile(path):
            return self._error("fisier inexistent", 404)
        with open(path, "rb") as fh:
            data = fh.read()
        ext = os.path.splitext(name)[1]
        self._send(200, data, MIME.get(ext, "application/octet-stream"))


def serve(data_path: str, host: str = "127.0.0.1", port: int = 8000,
          preset: str = "color3", open_browser: bool = True) -> None:
    Handler.store = Store(data_path, preset)
    server = ThreadingHTTPServer((host, port), Handler)
    url = f"http://{host}:{port}/"
    print(f"Roulette Lab ruleaza pe {url}")
    print(f"Date: {os.path.abspath(data_path)} ({len(Handler.store.ds)} rotiri)")
    print("Opreste cu Ctrl+C.")
    if open_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nOprit.")
        server.shutdown()
