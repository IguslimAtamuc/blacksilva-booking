"""Detectarea resetarilor: se schimba comportamentul la restart / in timp?

Raspunde direct la punctul "ce se intampla cand inchizi si redeschizi jocul".
Daca secventa se reseteaza la un seed fix, ar aparea DOUA semne:
  1. sesiuni diferite ar incepe cu aceleasi rezultate;
  2. distributia s-ar schimba brusc la granita dintre sesiuni.
Ambele sunt testate aici. Necesita ca datele sa contina `session` si/sau `ts`.
"""
from __future__ import annotations

import math
from collections import Counter, defaultdict
from datetime import timezone

from ..data.schema import Dataset
from ..stats.tests import chi2_independence, monte_carlo_p, permutation_test
from ._util import adaptive_iterations, cramers_v
from .base import AnalysisResult, register, skipped


def cusum_max(indicator: list[float]) -> float:
    """Statistica CUSUM: cea mai mare abatere cumulata de la media globala.

    Detecteaza un punct de schimbare fara sa stim dinainte unde este.
    """
    n = len(indicator)
    if n < 2:
        return 0.0
    mean = sum(indicator) / n
    acc, best = 0.0, 0.0
    for x in indicator:
        acc += x - mean
        best = max(best, abs(acc))
    return best / math.sqrt(n)


@register("resets")
def analyze_resets(ds: Dataset, seed: int = 12345, **_) -> AnalysisResult:
    values = ds.values
    symbols = ds.symbols
    n = len(values)
    if n < 60:
        return skipped("resets", "Resetari, sesiuni si timp",
                       "Se schimba comportamentul ruletei la restart sau in timp?",
                       f"Necesare minim 60 de rotiri (sunt {n}).", 60, n)

    detail: dict = {"has_sessions": ds.has_sessions, "has_timestamps": ds.has_timestamps}
    sub_p: list[tuple[str, float]] = []
    notes: list[str] = []

    # --- 1. Punct de schimbare (functioneaza si fara metadate) --------------
    top = Counter(values).most_common(1)[0][0]
    indicator = [1.0 if v == top else 0.0 for v in values]
    observed_cusum = cusum_max(indicator)
    cusum_out = permutation_test(values,
                                 lambda s: cusum_max([1.0 if v == top else 0.0 for v in s]),
                                 adaptive_iterations(n, 5000), seed, "greater")
    sub_p.append(("punct de schimbare (CUSUM)", cusum_out.p_value))
    detail["cusum"] = {"statistic": observed_cusum, "p": cusum_out.p_value, "symbol": top}
    notes.append(
        f"Punct de schimbare: CUSUM = {observed_cusum:.3f}, p = {cusum_out.p_value:.4f} "
        f"(frecventa {ds.label(top)} este stabila pe parcurs)"
        if cusum_out.p_value >= 0.05 else
        f"Punct de schimbare DETECTAT: CUSUM = {observed_cusum:.3f}, p = {cusum_out.p_value:.4f}"
    )

    # --- 2. Sesiunile difera intre ele? ------------------------------------
    sessions = ds.sessions()
    usable = {k: v for k, v in sessions.items() if len(v) >= 10}
    if len(usable) >= 2:
        index = {s: j for j, s in enumerate(symbols)}
        table = []
        for spins in usable.values():
            row = [0] * len(symbols)
            for sp in spins:
                row[index[sp.value]] += 1
            table.append(row)
        out = chi2_independence(table)
        v = cramers_v(out.statistic, n, len(table), len(symbols))
        sub_p.append(("sesiuni diferite", out.p_value))
        detail["sessions"] = {"n_sessions": len(usable), "chi2": out.statistic,
                              "p": out.p_value, "cramers_v": v,
                              "sizes": {k: len(v_) for k, v_ in usable.items()}}
        notes.append(f"Sesiuni ({len(usable)} comparate): hi-patrat = {out.statistic:.2f}, "
                     f"p = {out.p_value:.4f}, V = {v:.3f}")

        # --- 3. Sesiunile incep la fel? (semnul unui seed fix) -------------
        starts = [[sp.value for sp in spins[:5]] for spins in usable.values()]
        max_prefix = 0
        for i in range(len(starts)):
            for j in range(i + 1, len(starts)):
                common = 0
                for a, b in zip(starts[i], starts[j]):
                    if a != b:
                        break
                    common += 1
                max_prefix = max(max_prefix, common)
        probs = [values.count(s) / n for s in symbols]
        collision = sum(p * p for p in probs)
        pairs = len(starts) * (len(starts) - 1) / 2

        def sample(rng) -> float:
            seqs = [[rng.choices(symbols, weights=probs)[0] for _ in range(5)]
                    for _ in range(len(starts))]
            best = 0
            for i in range(len(seqs)):
                for j in range(i + 1, len(seqs)):
                    c = 0
                    for a, b in zip(seqs[i], seqs[j]):
                        if a != b:
                            break
                        c += 1
                    best = max(best, c)
            return float(best)

        mc = monte_carlo_p(float(max_prefix), sample, 20000, seed)
        sub_p.append(("prefixe identice de sesiune", mc.p_value))
        detail["session_starts"] = {"max_common_prefix": max_prefix, "p": mc.p_value,
                                    "pairs_compared": int(pairs),
                                    "collision_probability": collision}
        notes.append(
            f"Inceputuri de sesiune: cel mai lung prefix comun intre doua sesiuni = "
            f"{max_prefix} rotiri, p = {mc.p_value:.4f}"
            + (" -- semn puternic de seed fix la restart!" if mc.p_value < 0.05 else "")
        )
    else:
        notes.append("Sesiuni: nu am cel putin 2 sesiuni cu 10+ rotiri -- "
                     "testul de resetare la restart nu poate fi rulat. "
                     "Inregistreaza coloana `session` (cate un id per repornire a jocului).")

    # --- 4. Ora din zi si pauzele dintre rotiri ----------------------------
    if ds.has_timestamps:
        stamped = [s for s in ds.spins if s.ts is not None]
        if len(stamped) >= 60:
            index = {s: j for j, s in enumerate(symbols)}
            buckets = 4
            table = [[0] * len(symbols) for _ in range(buckets)]
            for sp in stamped:
                hour = sp.datetime.astimezone(timezone.utc).hour
                table[hour * buckets // 24][index[sp.value]] += 1
            table = [r for r in table if sum(r) >= 10]
            if len(table) >= 2:
                out = chi2_independence(table)
                sub_p.append(("ora din zi", out.p_value))
                detail["time_of_day"] = {"chi2": out.statistic, "p": out.p_value,
                                         "buckets": len(table)}
                notes.append(f"Ora din zi: hi-patrat = {out.statistic:.2f}, p = {out.p_value:.4f}")

            # pauza dintre rotiri vs rezultat: testeaza daca timpul e folosit ca seed
            gaps = [(stamped[i].ts - stamped[i - 1].ts, stamped[i].value)
                    for i in range(1, len(stamped))]
            gaps = [(g, v) for g, v in gaps if 0 <= g < 3600]
            if len(gaps) >= 40:
                ordered = sorted(g for g, _ in gaps)
                cuts = [ordered[len(ordered) // 3], ordered[2 * len(ordered) // 3]]
                table = [[0] * len(symbols) for _ in range(3)]
                for g, v in gaps:
                    row = 0 if g <= cuts[0] else (1 if g <= cuts[1] else 2)
                    table[row][index[v]] += 1
                out = chi2_independence(table)
                sub_p.append(("pauza dintre rotiri", out.p_value))
                detail["inter_spin_gap"] = {"chi2": out.statistic, "p": out.p_value,
                                            "cuts_seconds": cuts, "n": len(gaps)}
                notes.append(
                    f"Pauza dintre rotiri vs. rezultat: hi-patrat = {out.statistic:.2f}, "
                    f"p = {out.p_value:.4f}"
                    + (" -- posibil seed dependent de timp!" if out.p_value < 0.05 else "")
                )
    else:
        notes.append("Timestamp-uri: absente. Fara ele nu putem testa daca rezultatul "
                     "depinde de momentul rotirii (ipoteza seed = timp).")

    # p global: cel mai mic p, corectat Bonferroni pentru sub-testele rulate
    best_name, best_p = min(sub_p, key=lambda x: x[1]) if sub_p else ("-", 1.0)
    combined = min(1.0, best_p * max(1, len(sub_p)))

    explanation = (
        f"Am rulat {len(sub_p)} sub-teste de resetare. " + " | ".join(notes) + ". "
        f"Cel mai puternic semnal: {best_name} (p brut = {best_p:.4f}; dupa corectia "
        f"Bonferroni pentru {len(sub_p)} sub-teste: {combined:.4f}). "
    )
    if combined >= 0.05:
        explanation += (
            "Nu exista dovada ca secventa se reseteaza, se schimba intre sesiuni sau "
            "depinde de ceas. Nota metodologica: pentru a testa serios ipoteza "
            "'jocul reporneste de la acelasi seed', ai nevoie de mai multe sesiuni "
            "inregistrate separat, fiecare cu primele rotiri dupa deschiderea jocului."
        )
    else:
        explanation += (
            "Exista dovada de schimbare structurala. Aceasta este cea mai valoroasa "
            "pista posibila: un seed reinitializat previzibil (de ex. din ceas) este "
            "singurul mecanism realist prin care o ruleta software devine predictibila."
        )

    return AnalysisResult(
        key="resets", title="Resetari, sesiuni si timp",
        question="Se schimba comportamentul la restart, intre sesiuni sau in timp?",
        statistic=observed_cusum, statistic_name="CUSUM maxim",
        p_value=combined, p_method="permutation + hi-patrat",
        effect=observed_cusum, effect_name="abatere cumulata normalizata",
        n_used=n, min_n=60, recommended_n=400,
        explanation=explanation,
        detail=detail,
        warnings=[] if (ds.has_sessions or ds.has_timestamps) else [
            "Datele nu contin nici sesiuni, nici timestamp-uri: majoritatea "
            "ipotezelor de resetare raman netestabile."],
    )
