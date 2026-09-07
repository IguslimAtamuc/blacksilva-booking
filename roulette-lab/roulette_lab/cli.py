"""Interfata de linie de comanda."""
from __future__ import annotations

import argparse
import json
import os
import random
import sys

from .analysis import VERDICT_LABELS, run_all
from .backtest import run_backtest
from .data.io import (dump_csv, dump_json, dump_text, load_any, normalize_symbol,
                      read_dataset, save_dataset)
from .data.schema import PRESETS, Dataset
from .decide import decide, make_record
from .prng import identify
from .report import build_report, render

DEFAULT_DATA = os.path.join("data", "dataset.json")


def _load(path: str, preset: str = "color3") -> Dataset:
    if os.path.exists(path):
        return read_dataset(path)
    ds = Dataset(preset=preset, name=os.path.splitext(os.path.basename(path))[0])
    return ds


def _p(text: str = "") -> None:
    print(text)


def _bar(value: float, width: int = 24, cap: float = 1.0) -> str:
    filled = int(max(0.0, min(1.0, value / cap)) * width)
    return "#" * filled + "." * (width - filled)


# --------------------------------------------------------------------------
def cmd_add(args) -> int:
    ds = _load(args.data, args.preset)
    added = 0
    for token in args.values:
        for piece in (token.split(",") if "," in token else [token]):
            piece = piece.strip()
            if not piece:
                continue
            if ds.preset == "color3" and len(piece) > 1 and piece.upper().strip("RNV") == "":
                for ch in piece.upper():
                    ds.add(ch, session=args.session)
                    added += 1
                continue
            ds.add(normalize_symbol(piece, ds.preset), session=args.session)
            added += 1
    save_dataset(ds, args.data)
    _p(f"Adaugate {added} rotiri. Total: {len(ds)}. Fisier: {args.data}")
    return 0


def cmd_import(args) -> int:
    with open(args.file, "r", encoding="utf-8") as fh:
        text = fh.read()
    incoming = load_any(text, args.file, args.preset)
    if args.append and os.path.exists(args.data):
        ds = read_dataset(args.data)
        for spin in incoming.spins:
            ds.add(spin.value, spin.ts, spin.session, spin.meta)
    else:
        ds = incoming
    save_dataset(ds, args.data)
    _p(f"Importate {len(incoming)} rotiri din {args.file}. Total in dataset: {len(ds)}.")
    if incoming.predictions:
        _p(f"Importate si {len(incoming.predictions)} predictii istorice (marcate ca "
           f"neverificate statistic).")
    return 0


def cmd_export(args) -> int:
    ds = read_dataset(args.data)
    text = {"csv": dump_csv, "json": dump_json, "txt": dump_text}[args.format](ds)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text)
        _p(f"Export scris in {args.out} ({len(ds)} rotiri, format {args.format}).")
    else:
        sys.stdout.write(text)
    return 0


def cmd_show(args) -> int:
    ds = read_dataset(args.data)
    from collections import Counter
    counts = Counter(ds.values)
    _p(f"Dataset: {ds.name}  |  {len(ds)} rotiri  |  alfabet {ds.symbols}")
    _p(f"Amprenta: {ds.fingerprint()[:32]}")
    _p(f"Timestamp-uri: {'da' if ds.has_timestamps else 'nu'}  |  "
       f"Sesiuni: {len(ds.sessions())}")
    _p("")
    for sym in ds.symbols:
        c = counts.get(sym, 0)
        pct = c / len(ds) * 100 if len(ds) else 0
        _p(f"  {ds.label(sym):<8} {c:>5}  {pct:5.1f}%  {_bar(pct/100, 30)}")
    _p("")
    tail = ds.values[-60:]
    _p("Ultimele rotiri:")
    _p("  " + ("".join(tail) if ds.preset == "color3" else " ".join(tail)))
    resolved = ds.resolved_predictions
    if resolved:
        ok = sum(1 for r in resolved if r.correct)
        gated = [r for r in resolved if r.gated]
        _p("")
        _p(f"Predictii evaluate: {ok}/{len(resolved)} corecte "
           f"({ok/len(resolved)*100:.1f}%), din care {len(gated)} au trecut poarta "
           f"de evidenta.")
    return 0


def cmd_analyze(args) -> int:
    ds = read_dataset(args.data)
    report = run_all(ds, alpha=args.alpha, seed=args.seed)
    _p(f"=== ANALIZA SECVENTEI ({len(ds)} rotiri) ===")
    _p("")
    for r in report.results:
        mark = {"dovada": "[DOVADA]", "slab": "[SLAB]  ",
                "fara_dovada": "[-]     ", "insuficient": "[?]     "}[r.verdict]
        _p(f"{mark} {r.title}")
        if r.applicable and r.n_used >= r.min_n:
            q = "-" if r.q_value is None else f"{r.q_value:.4f}"
            _p(f"          {r.statistic_name} = {r.statistic:.3f}, p = {r.p_value:.4f}, "
               f"q(BH) = {q}, {r.effect_name} = {r.effect:.4f}")
        if args.verbose:
            for line in _wrap(r.explanation, 96):
                _p(f"          {line}")
            for w in r.warnings:
                for line in _wrap("AVERTISMENT: " + w, 96):
                    _p(f"          {line}")
        _p("")
    _p("--- CONCLUZIE ---")
    for line in _wrap(report.summary(), 100):
        _p(line)
    return 0


def cmd_prng(args) -> int:
    ds = read_dataset(args.data)
    result = identify(ds, max_seeds=args.max_seeds, time_window_s=args.window,
                      max_offset=args.max_offset)
    _p("=== IDENTIFICAREA GENERATORULUI ===")
    _p("")
    for line in _wrap(result["summary"], 100):
        _p(line)
    _p("")
    b = result["budget"]
    _p(f"Buget informational: {b['total_bits_collected']:.0f} biti colectati "
       f"({b['bits_per_spin_observed']:.2f}/rotire din {b['bits_per_spin_max']:.2f} maximi, "
       f"eficienta {b['efficiency']*100:.0f}%)")
    _p("")
    _p(f"{'Generator':<28}{'stare':>7}{'rotiri min':>12}  status")
    for row in b["rows"]:
        _p(f"{row['name']:<28}{row['state_bits']:>7}{row['min_spins_information']:>12}  "
           f"{row['status']}")
    _p("")
    if result["attacks"]:
        _p("Atacuri rulate:")
        for atk in result["attacks"]:
            mark = "REUSIT" if atk["success"] else "esuat "
            _p(f"  [{mark}] {atk['attack']} / {atk['generator']}")
            for line in _wrap(atk["reason"], 92):
                _p(f"           {line}")
    _p("")
    for note in result["notes"]:
        for line in _wrap("* " + note, 100):
            _p(line)
    return 0


def cmd_backtest(args) -> int:
    ds = read_dataset(args.data)
    bt = run_backtest(ds, warmup=args.warmup, seed=args.seed)
    _p(f"=== BACKTESTING WALK-FORWARD ===")
    _p(f"Total {bt.n_total} rotiri | invatare pe primele {bt.warmup} | "
       f"evaluate {bt.n_evaluated} | {bt.elapsed_s:.1f}s")
    _p("")
    header = (f"{'Model':<34}{'log-loss':>10}{'acuratete':>11}{'Brier':>8}"
              f"{'biti castigati':>16}{'p corectat':>12}")
    _p(header)
    _p("-" * len(header))
    for key, run in bt.runs.items():
        comp = bt.comparisons.get(key)
        gain = "  (baseline)" if key == bt.baseline_key else (
            f"{comp['mean_bits_saved']:+.4f}" if comp else "-")
        pv = "" if key == bt.baseline_key else (
            f"{comp['p_value_corrected']:.4f}" if comp else "-")
        _p(f"{run.name:<34}{run.metrics['log_loss_bits']:>10.4f}"
           f"{run.metrics['accuracy']*100:>10.1f}%{run.metrics['brier']:>8.4f}"
           f"{gain:>16}{pv:>12}")
    _p("")
    base = bt.runs[bt.baseline_key]
    _p(f"Referinta: hazard pur = {bt.runs['uniform'].metrics['log_loss_bits']:.4f} biti; "
       f"frecventa empirica = {base.metrics['log_loss_bits']:.4f} biti.")
    _p("Un model conteaza doar daca scade log-loss-ul sub frecventa empirica, "
       "cu semnificatie dupa corectie.")
    return 0


def cmd_predict(args) -> int:
    ds = read_dataset(args.data)
    decision = decide(ds, seed=args.seed)
    _p("=== PREDICTIA URMATOAREI ROTIRI ===")
    _p("")
    g = decision.guess
    if g:
        _p("+" + "-" * 74 + "+")
        _p(f"|  CEA MAI PROBABILA CULOARE:  {g['label'].upper():<44}|")
        _p(f"|  Increderea modelului: {g['model_confidence']*100:5.1f}%"
           f"{'':<44}|")
        _p("+" + "-" * 74 + "+")
        for line in _wrap(g["honesty"], 74):
            _p(f"   {line}")
        _p("")
    for line in _wrap(decision.message, 100):
        _p(line)
    _p("")
    _p(f"{'Conditie':<40}{'':4}{'cerut':<28}obtinut")
    for c in decision.checks:
        _p(f"{c['name']:<40}{'OK' if c['passed'] else 'PICA':<4}"
           f"{c['required']:<28}{c['observed']}")
    if decision.allowed:
        _p("")
        _p("Probabilitati:")
        for sym, prob in sorted(decision.probabilities.items(), key=lambda x: -x[1]):
            _p(f"  {ds.label(sym):<10}{prob*100:6.2f}%  {_bar(prob, 30)}")
        _p("")
        _p("Transparenta:")
        for key, value in decision.transparency.items():
            if isinstance(value, dict):
                value = json.dumps(value, ensure_ascii=False)
            for i, line in enumerate(_wrap(str(value), 78)):
                _p(f"  {key if i == 0 else '':<22}{line}")
    if args.log:
        ds.log_prediction(make_record(decision, len(ds)))
        save_dataset(ds, args.data)
        _p("")
        _p("Predictie inregistrata; va fi evaluata automat la urmatoarea rotire adaugata.")
    return 0


def cmd_report(args) -> int:
    ds = read_dataset(args.data)
    report = build_report(ds, seed=args.seed, run_prng=not args.no_prng,
                          prng_max_seeds=args.max_seeds)
    base = args.out or os.path.join("data", f"raport-{ds.name}")
    os.makedirs(os.path.dirname(os.path.abspath(base)) or ".", exist_ok=True)
    with open(base + ".md", "w", encoding="utf-8") as fh:
        fh.write(render(report))
    with open(base + ".json", "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, ensure_ascii=False, default=str)
    _p(f"Raport scris:")
    _p(f"  {base}.md    (de citit / de predat)")
    _p(f"  {base}.json  (toate cifrele brute)")
    _p("")
    _p(report["conclusion"]["headline"])
    _p(f"Amprenta date: {report['manifest']['dataset']['fingerprint_sha256'][:32]}")
    _p(f"Amprenta cod:  {report['manifest']['code_fingerprint_sha256'][:32]}")
    return 0


def cmd_demo(args) -> int:
    """Genereaza seturi de date cu adevar CUNOSCUT, pentru validarea tool-ului."""
    from .prng.generators import make_lcg
    from .prng.mappings import build_mappings
    os.makedirs(args.out, exist_ok=True)
    rng = random.Random(args.seed)
    probs = [0.47, 0.47, 0.06]
    made = []

    # a) aleator pur
    ds = Dataset(name="demo-aleator", notes="iid cu p=(0.47,0.47,0.06). Adevar: NEPREDICTIBIL.")
    ds.extend(rng.choices("RNV", weights=probs, k=args.n))
    save_dataset(ds, os.path.join(args.out, "demo-aleator.json"))
    made.append(("demo-aleator", "iid pur -- tool-ul TREBUIE sa refuze predictia"))

    # b) lant Markov real
    ds = Dataset(name="demo-markov", notes="Markov ordin 1. Adevar: PREDICTIBIL.")
    cur = "R"
    for _ in range(args.n):
        ds.add(cur)
        w = {"R": [0.20, 0.74, 0.06], "N": [0.74, 0.20, 0.06], "V": probs}[cur]
        cur = rng.choices("RNV", weights=w)[0]
    save_dataset(ds, os.path.join(args.out, "demo-markov.json"))
    made.append(("demo-markov", "dependenta reala -- tool-ul TREBUIE sa o gaseasca"))

    # c) ciclu periodic cu zgomot
    ds = Dataset(name="demo-ciclu", notes="Perioada 7 cu 10% zgomot. Adevar: PREDICTIBIL.")
    base = list("RRNVRNN")
    for i in range(args.n):
        ds.add(base[i % 7] if rng.random() > 0.10 else rng.choice("RNV"))
    save_dataset(ds, os.path.join(args.out, "demo-ciclu.json"))
    made.append(("demo-ciclu", "perioada 7 -- testul spectral TREBUIE sa o gaseasca"))

    # d) LCG cu seed din ceas -- identificabil prin cautare de seed
    ts = 1700000000
    lcg = make_lcg("numerical_recipes", ts)
    mapping = next(m for m in build_mappings("color3", {"R": .47, "N": .47, "V": .06})
                   if m.key == "threshold_RNV")
    ds = Dataset(name="demo-lcg", notes=f"LCG numerical_recipes, seed={ts} (din ceas). "
                                        "Adevar: COMPLET DETERMINIST.")
    for i in range(args.n):
        ds.add(mapping.fn(lcg.next(), 2 ** 32), ts=float(ts + i * 12))
    save_dataset(ds, os.path.join(args.out, "demo-lcg.json"))
    made.append(("demo-lcg", "seed din ceas -- `prng` TREBUIE sa recupereze seed-ul"))

    _p(f"Generate {len(made)} seturi de date de test in {args.out}/ ({args.n} rotiri fiecare):")
    for name, why in made:
        _p(f"  {name+'.json':<24} {why}")
    _p("")
    _p("Foloseste-le ca sa verifici ca tool-ul nu se auto-amageste:")
    _p(f"  python -m roulette_lab predict --data {args.out}/demo-aleator.json")
    _p(f"  python -m roulette_lab predict --data {args.out}/demo-markov.json")
    _p(f"  python -m roulette_lab prng    --data {args.out}/demo-lcg.json")
    return 0


def cmd_serve(args) -> int:
    from .server import serve
    serve(args.data, args.host, args.port, args.preset,
          open_browser=not args.no_browser)
    return 0


def _wrap(text: str, width: int) -> list[str]:
    words, lines, cur = text.split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width:
            lines.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    if cur:
        lines.append(cur)
    return lines or [""]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="roulette_lab",
        description="Analiza statistica si de reverse engineering a unei secvente de ruleta.",
        epilog="Proiect educational. Nu produce predictii nejustificate statistic.")
    parser.add_argument("--data", default=DEFAULT_DATA, help=f"fisierul de date (implicit {DEFAULT_DATA})")
    parser.add_argument("--seed", type=int, default=12345, help="seed pentru testele aleatoare")
    parser.add_argument("--preset", default="color3", choices=list(PRESETS),
                        help="alfabetul rezultatelor")
    # Aceleasi optiuni globale, acceptate SI dupa subcomanda: `predict --data X`
    # este ordinea pe care o scrie oricine in mod natural. `SUPPRESS` face ca
    # valoarea de la nivel superior sa fie pastrata daca nu e data explicit aici.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--data", default=argparse.SUPPRESS)
    common.add_argument("--seed", type=int, default=argparse.SUPPRESS)
    common.add_argument("--preset", choices=list(PRESETS), default=argparse.SUPPRESS)

    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("add", help="adauga rezultate", parents=[common])
    p.add_argument("values", nargs="+", help="ex: R N V, sau lipite: RNVRR")
    p.add_argument("--session", help="id de sesiune (o repornire a jocului = o sesiune noua)")
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("import", help="importa dintr-un fisier CSV/TXT/JSON", parents=[common])
    p.add_argument("file")
    p.add_argument("--append", action="store_true", help="adauga la datele existente")
    p.set_defaults(func=cmd_import)

    p = sub.add_parser("export", help="exporta datele", parents=[common])
    p.add_argument("--format", default="csv", choices=["csv", "json", "txt"])
    p.add_argument("--out", help="fisier de iesire (implicit: stdout)")
    p.set_defaults(func=cmd_export)

    p = sub.add_parser("show", help="rezumatul datelor", parents=[common])
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("analyze", help="bateria de teste statistice", parents=[common])
    p.add_argument("--alpha", type=float, default=0.05)
    p.add_argument("-v", "--verbose", action="store_true", help="include explicatiile")
    p.set_defaults(func=cmd_analyze)

    p = sub.add_parser("prng", help="identificarea generatorului", parents=[common])
    p.add_argument("--max-seeds", type=int, default=100_000, dest="max_seeds")
    p.add_argument("--window", type=int, default=3600, help="fereastra de secunde pentru seed din ceas")
    p.add_argument("--max-offset", type=int, default=0, dest="max_offset",
                   help="cate rotiri initiale pot lipsi din inregistrare")
    p.set_defaults(func=cmd_prng)

    p = sub.add_parser("backtest", help="backtesting walk-forward", parents=[common])
    p.add_argument("--warmup", type=int, help="rotiri rezervate pentru invatare")
    p.set_defaults(func=cmd_backtest)

    p = sub.add_parser("predict", help="predictie, daca este justificata statistic", parents=[common])
    p.add_argument("--log", action="store_true", help="inregistreaza predictia pentru evaluare")
    p.set_defaults(func=cmd_predict)

    p = sub.add_parser("report", help="raport complet reproductibil (Markdown + JSON)", parents=[common])
    p.add_argument("--out", help="prefixul fisierelor de iesire")
    p.add_argument("--no-prng", action="store_true", dest="no_prng")
    p.add_argument("--max-seeds", type=int, default=50_000, dest="max_seeds")
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("demo", help="genereaza seturi de date cu adevar cunoscut", parents=[common])
    p.add_argument("--out", default="data/demo")
    p.add_argument("-n", type=int, default=800)
    p.set_defaults(func=cmd_demo)

    p = sub.add_parser("serve", help="porneste interfata web", parents=[common])
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--no-browser", action="store_true", dest="no_browser",
                   help="nu deschide automat browserul (util pe un server fara ecran)")
    p.set_defaults(func=cmd_serve)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except FileNotFoundError as exc:
        print(f"Eroare: fisierul nu exista -- {exc.filename}", file=sys.stderr)
        print("Sugestie: incepe cu `python -m roulette_lab add R N V` sau "
              "`python -m roulette_lab demo`.", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"Eroare: {exc}", file=sys.stderr)
        return 2
