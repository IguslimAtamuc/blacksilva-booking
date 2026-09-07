"""Orchestrarea identificarii de PRNG.

Ordinea de lucru este deliberata:
  1. Ce informatie avem? (buget)  -> elimina din start ce e imposibil
  2. Avem output-uri brute?       -> atacuri algebrice, exacte
  3. Avem timestamp-uri?          -> cautare de seed derivat din ceas
  4. Ce ramane netestat si de ce?
Nu ghicim niciodata un generator din "aspectul" secventei.
"""
from __future__ import annotations

from ..data.schema import Dataset
from .attacks import (AttackResult, attack_lcg_algebraic, attack_mt19937_state,
                      attack_seed_search, time_seed_candidates)
from .budget import (budget_table, false_match_probability, observed_bits_per_spin,
                     spins_for_credible_match)
from .generators import CATALOG
from .mappings import build_mappings

# Generatoare al caror spatiu de seed-uri e mic destul pentru cautare directa.
SEARCHABLE = ["numerical_recipes", "borland", "glibc_rand", "msvc_rand",
              "minstd", "minstd_new", "xorshift32"]


def extract_raw_outputs(ds: Dataset) -> list[int]:
    """Output-uri brute de PRNG, daca utilizatorul a reusit sa le obtina.

    In mod normal NU sunt disponibile: jocul afiseaza o culoare, nu numarul intern.
    Se pot furniza printr-o coloana `raw` in CSV, daca cineva a extras valorile
    prin inspectarea traficului de retea sau a memoriei jocului.
    """
    out = []
    for spin in ds.spins:
        raw = spin.meta.get("raw") or spin.meta.get("raw_value")
        if raw is None:
            return []
        try:
            out.append(int(raw))
        except (TypeError, ValueError):
            return []
    return out


def identify(ds: Dataset, max_seeds: int = 100_000, time_window_s: int = 3600,
             max_offset: int = 0, run_search: bool = True) -> dict:
    values = ds.values
    n = len(values)
    bits = observed_bits_per_spin(values)
    budget = budget_table(values, len(ds.symbols))
    attacks: list[AttackResult] = []
    notes: list[str] = []

    # --- 1. Output-uri brute -> atacuri exacte ----------------------------
    raw = extract_raw_outputs(ds)
    if raw:
        notes.append(f"Am gasit {len(raw)} output-uri brute in coloana `raw`: "
                     "putem incerca atacurile algebrice exacte.")
        attacks.append(attack_lcg_algebraic(raw))
        attacks.append(attack_mt19937_state(raw))
    else:
        notes.append(
            "Datele nu contin output-uri brute de generator (doar rezultate afisate). "
            "Atacurile algebrice exacte -- recuperarea parametrilor LCG si inversarea "
            "temperarii MT19937 -- sunt indisponibile prin constructie, nu din lipsa "
            "de efort. Ele au nevoie de numerele interne ale generatorului."
        )

    # --- 2. Cautare de seed ----------------------------------------------
    probs = {s: values.count(s) / n for s in ds.symbols} if n else {}
    mappings = build_mappings(ds.preset, probs)
    tests_done = 0
    if run_search and n >= 12:
        seeds = None
        search_kind = ""
        if ds.has_timestamps:
            first = next((s.ts for s in ds.spins if s.ts is not None), None)
            seeds = time_seed_candidates(first, time_window_s)
            search_kind = (f"seed-uri derivate din ceas, +/-{time_window_s}s "
                           f"in jurul primei rotiri")
        else:
            seeds = iter(range(0, max_seeds))
            search_kind = f"seed-uri mici 0..{max_seeds}"
            notes.append(
                "Fara timestamp-uri, singura cautare posibila este pe seed-uri mici, "
                "care e o ipoteza slaba. Cu timestamp-uri am putea testa ipoteza "
                "realista 'jocul se initializeaza din ceas'."
            )
        results = attack_seed_search(values, SEARCHABLE, mappings, seeds,
                                     max_seeds=max_seeds, max_offset=max_offset)
        attacks.extend(results)
        tests_done = sum(r.tried for r in results) * len(mappings) * (max_offset + 1)
        notes.append(f"Cautare de seed rulata pe {search_kind}: "
                     f"{len(SEARCHABLE)} generatoare x {len(mappings)} mapari.")
    elif n < 12:
        notes.append(f"Prea putine rotiri ({n}) pentru o cautare de seed cu sens.")

    # --- 3. Cat de credibila ar fi o potrivire? ---------------------------
    credible_n = spins_for_credible_match(max(1, tests_done or max_seeds), bits)
    fp = false_match_probability(n, bits, max(1, tests_done or max_seeds))

    successes = [a for a in attacks if a.success]
    if successes:
        verdict = "generator_identificat"
        summary = (
            f"IDENTIFICAT: {successes[0].generator}. {successes[0].reason} "
            f"Verifica totusi lungimea potrivirii: cu {n} rotiri si "
            f"{tests_done or max_seeds:,} combinatii testate, probabilitatea unei "
            f"potriviri intamplatoare este {fp:.2e}."
        )
        if n < credible_n:
            verdict = "potrivire_nesigura"
            summary += (
                f" ATENTIE: potrivirea NU este credibila -- ar fi nevoie de cel putin "
                f"{credible_n} rotiri potrivite ca sa excludem hazardul la acest numar "
                "de incercari."
            )
    else:
        verdict = "neidentificat"
        summary = (
            f"Niciun generator candidat nu reproduce secventa. Am colectat "
            f"{budget['total_bits_collected']:.0f} biti de informatie din {n} rotiri "
            f"({bits:.2f} biti/rotire). Pentru referinta: cel mai mic generator din "
            f"catalog are 31 de biti de stare, iar MT19937 are 19937. "
            "Rezultatul negativ NU dovedeste ca jocul nu foloseste un PRNG -- toate "
            "jocurile folosesc unul. Dovedeste doar ca nu il putem identifica din "
            "aceste date, ceea ce e o afirmatie diferita si mult mai modesta."
        )

    return {
        "verdict": verdict,
        "summary": summary,
        "bits_per_spin": bits,
        "budget": budget,
        "attacks": [a.to_dict() for a in attacks],
        "mappings_tried": [{"key": m.key, "name": m.name, "description": m.description}
                           for m in mappings],
        "notes": notes,
        "false_match_probability": fp,
        "spins_needed_for_credible_match": credible_n,
        "catalog": [
            {"key": k, "name": s.name, "state_bits": s.state_bits,
             "where_used": s.where_used, "description": s.description,
             "outputs_needed": s.outputs_needed}
            for k, (s, _) in sorted(CATALOG.items(), key=lambda kv: kv[1][0].state_bits)
        ],
    }
