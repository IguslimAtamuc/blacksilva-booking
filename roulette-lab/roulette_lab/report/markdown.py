"""Randarea raportului in Markdown -- formatul de predat la scoala."""
from __future__ import annotations

import json

from ..analysis.base import VERDICT_LABELS

BAR = {"dovada": "###", "slab": "##", "fara_dovada": "-", "insuficient": "?"}


def render(report: dict) -> str:
    m = report["manifest"]
    a = report["analysis"]
    d = report["decision"]
    b = report.get("backtest")
    p = report.get("prng")
    c = report["conclusion"]
    L: list[str] = []

    L.append(f"# Raport de analiza -- {m['dataset']['name']}")
    L.append("")
    L.append(f"**Concluzie:** {c['headline']}")
    L.append("")
    L.append("| | |")
    L.append("|---|---|")
    L.append(f"| Rotiri analizate | {m['dataset']['n_spins']} |")
    L.append(f"| Alfabet | {', '.join(m['dataset']['alphabet'])} |")
    L.append(f"| Amprenta date (SHA-256) | `{m['dataset']['fingerprint_sha256'][:32]}...` |")
    L.append(f"| Amprenta cod (SHA-256) | `{m['code_fingerprint_sha256'][:32]}...` |")
    L.append(f"| Seed aleator | {m['random_seed']} |")
    L.append(f"| Generat la | {m['generated_at']} |")
    L.append(f"| Timestamp-uri / sesiuni | "
             f"{'da' if m['dataset']['has_timestamps'] else 'nu'} / "
             f"{m['dataset']['n_sessions']} |")
    L.append("")
    L.append(f"Reproducere: `{m['reproduce_with']}`")
    L.append("")

    # --- 1. Analiza -------------------------------------------------------
    L.append("## 1. Analiza secventei")
    L.append("")
    L.append(a["summary"])
    L.append("")
    L.append("| Test | Verdict | Statistica | p | q (BH) | Marime efect | n |")
    L.append("|---|---|---|---|---|---|---|")
    for r in a["results"]:
        q = "-" if r["q_value"] is None else f"{r['q_value']:.4f}"
        stat = "-" if not r["applicable"] else f"{r['statistic']:.3f}"
        pv = "-" if not r["applicable"] else f"{r['p_value']:.4f}"
        eff = "-" if not r["applicable"] else f"{r['effect']:.4f} ({r['effect_name']})"
        L.append(f"| {r['title']} | **{VERDICT_LABELS[r['verdict']]}** | {stat} | "
                 f"{pv} | {q} | {eff} | {r['n_used']} |")
    L.append("")
    L.append("### Detalii pe fiecare test")
    L.append("")
    for r in a["results"]:
        L.append(f"#### {r['title']}")
        L.append(f"*Intrebare:* {r['question']}")
        L.append("")
        L.append(r["explanation"])
        for w in r["warnings"]:
            L.append(f"> **Avertisment:** {w}")
        L.append("")

    # --- 2. PRNG ----------------------------------------------------------
    if p:
        L.append("## 2. Identificarea generatorului")
        L.append("")
        L.append(p["summary"])
        L.append("")
        L.append(f"Informatie colectata: **{p['budget']['total_bits_collected']:.0f} biti** "
                 f"({p['bits_per_spin']:.2f} biti/rotire din maximum "
                 f"{p['budget']['bits_per_spin_max']:.2f} posibili).")
        L.append("")
        L.append("| Generator | Stare (biti) | Rotiri minime | Avem destul? | Status |")
        L.append("|---|---|---|---|---|")
        for row in p["budget"]["rows"]:
            L.append(f"| {row['name']} | {row['state_bits']} | "
                     f"{row['min_spins_information']} | "
                     f"{'da' if row['sufficient_information'] else 'nu'} | "
                     f"{row['status']} |")
        L.append("")
        if p["attacks"]:
            L.append("**Atacuri rulate:**")
            L.append("")
            for atk in p["attacks"]:
                mark = "REUSIT" if atk["success"] else "esuat"
                L.append(f"- `{atk['attack']}` pe {atk['generator']}: **{mark}** -- "
                         f"{atk['reason']} ({atk['tried']} incercari, {atk['elapsed_s']}s)")
            L.append("")
        for note in p["notes"]:
            L.append(f"> {note}")
            L.append("")

    # --- 3. Backtesting ---------------------------------------------------
    if b:
        L.append("## 3. Backtesting walk-forward")
        L.append("")
        L.append(f"Protocol: primele **{b['warmup']}** rotiri servesc doar la invatare; "
                 f"apoi fiecare rotire este prezisa inainte de a fi vazuta, iar rezultatul "
                 f"real este adaugat la istoric. Puncte de evaluare: **{b['n_evaluated']}**.")
        L.append("")
        L.append("| Model | Log-loss (biti) | Perplexitate | Acuratete | Brier | "
                 "Eroare calibrare | Biti castigati | p corectat |")
        L.append("|---|---|---|---|---|---|---|---|")
        for key, run in b["runs"].items():
            comp = b["comparisons"].get(key)
            gain = "-" if not comp else f"{comp['mean_bits_saved']:+.4f}"
            pv = "-" if not comp else f"{comp['p_value_corrected']:.4f}"
            marker = " (baseline)" if key == b["baseline_key"] else ""
            L.append(f"| {run['name']}{marker} | {run['log_loss_bits']:.4f} | "
                     f"{run['perplexity']:.3f} | {run['accuracy']*100:.1f}% | "
                     f"{run['brier']:.4f} | {run['calibration_error']*100:.1f}pp | "
                     f"{gain} | {pv} |")
        L.append("")
        L.append("Reperul care conteaza este **log-loss**, in biti. Baseline-ul "
                 "'frecventa empirica' nu presupune niciun tipar; un model care nu "
                 "coboara sub el nu a invatat nimic despre secventa.")
        L.append("")
        base = b["runs"].get(b["baseline_key"], {})
        if base:
            L.append("### Precizie / recall pe simbol (baseline)")
            L.append("")
            L.append("| Simbol | Suport | Precizie | Recall | F1 |")
            L.append("|---|---|---|---|---|")
            for sym, v in base.get("per_class", {}).items():
                L.append(f"| {sym} | {v['support']} | {v['precision']*100:.1f}% | "
                         f"{v['recall']*100:.1f}% | {v['f1']:.3f} |")
            L.append("")

    # --- 4. Decizie -------------------------------------------------------
    L.append("## 4. Decizia de predictie")
    L.append("")
    L.append(f"**{d['message']}**")
    L.append("")
    L.append("| Conditie | Rezultat | Cerut | Obtinut |")
    L.append("|---|---|---|---|")
    for chk in d["checks"]:
        L.append(f"| {chk['name']} | {'TRECE' if chk['passed'] else 'PICA'} | "
                 f"{chk['required']} | {chk['observed']} |")
    L.append("")
    if d["allowed"]:
        L.append("### Probabilitati estimate")
        L.append("")
        for sym, prob in sorted(d["probabilities"].items(), key=lambda x: -x[1]):
            L.append(f"- **{sym}**: {prob*100:.2f}%")
        L.append("")
    L.append("### Transparenta")
    L.append("")
    for key, value in d["transparency"].items():
        if isinstance(value, (dict, list)):
            value = json.dumps(value, ensure_ascii=False)
        L.append(f"- **{key}**: {value}")
    L.append("")

    # --- 5. Concluzii -----------------------------------------------------
    L.append("## 5. Ce putem si ce nu putem afirma")
    L.append("")
    L.append("**Sustinut de date:**")
    L.append("")
    for claim in c["what_we_can_claim"]:
        L.append(f"- {claim}")
    L.append("")
    L.append("**NU este sustinut de date:**")
    L.append("")
    for claim in c["what_we_cannot_claim"]:
        L.append(f"- {claim}")
    L.append("")
    return "\n".join(L)
