"""Bugetul informational: ce se POATE demonstra din datele disponibile.

Ideea centrala, si probabil cea mai importanta lectie a proiectului:
identificarea unui generator este o problema de INFORMATIE, nu de destepataciune
algoritmica. Ca sa determini o stare de B biti, ai nevoie de cel putin B biti de
observatii. Nicio metoda nu poate ocoli asta.
"""
from __future__ import annotations

import math
from collections import Counter
from typing import Sequence

from .generators import CATALOG


def observed_bits_per_spin(values: Sequence[str]) -> float:
    """Cata informatie transporta efectiv o rotire inregistrata (entropia empirica)."""
    n = len(values)
    if n == 0:
        return 0.0
    counts = Counter(values)
    return -sum((c / n) * math.log2(c / n) for c in counts.values() if c > 0)


def budget_table(values: Sequence[str], alphabet_size: int) -> dict:
    """Cate rotiri ar fi necesare pentru fiecare generator candidat."""
    n = len(values)
    bits_each = observed_bits_per_spin(values)
    bits_max = math.log2(max(2, alphabet_size))
    total = n * bits_each

    rows = []
    for key, (spec, _) in CATALOG.items():
        needed_bits = spec.state_bits
        needed_spins = math.ceil(needed_bits / bits_each) if bits_each > 0 else float("inf")
        # Limita informationala e necesara, nu suficienta: pentru MT19937 atacul
        # cunoscut cere output-uri COMPLETE de 32 de biti, nu biti adunati din culori.
        if spec.key == "mt19937":
            practical = ("Imposibil din culori: atacul prin inversarea temperarii cere "
                         "624 de output-uri complete de 32 de biti, nu biti agregati. "
                         "Recuperarea din valori trunchiate ar cere rezolvarea unui "
                         "sistem de 19937 de ecuatii peste GF(2).")
            status = "imposibil-practic"
        elif spec.state_bits <= 32:
            practical = (f"Fezabil: spatiul de {2**spec.state_bits:,} seed-uri se poate "
                         "parcurge, iar daca seed-ul vine din ceas sunt doar cateva zeci "
                         "de mii de candidati.")
            status = "fezabil"
        elif spec.state_bits <= 64:
            practical = (f"Partial: {2**spec.state_bits:,} de seed-uri sunt prea multe "
                         "pentru forta bruta, dar un seed derivat din timp ramane in "
                         "raza de cautare.")
            status = "doar-seed-din-timp"
        else:
            practical = ("Doar cu output-uri brute complete; din culori nu exista atac "
                         "cunoscut fezabil.")
            status = "imposibil-practic"

        rows.append({
            "key": key, "name": spec.name, "state_bits": spec.state_bits,
            "where_used": spec.where_used,
            "min_spins_information": needed_spins,
            "have_spins": n,
            "sufficient_information": n >= needed_spins,
            "status": status, "practical_note": practical,
            "attack_outputs_needed": spec.outputs_needed,
        })
    rows.sort(key=lambda r: r["state_bits"])

    return {
        "n_spins": n,
        "bits_per_spin_observed": bits_each,
        "bits_per_spin_max": bits_max,
        "total_bits_collected": total,
        "efficiency": bits_each / bits_max if bits_max else 0.0,
        "rows": rows,
    }


def false_match_probability(n_symbols: int, bits_per_spin: float, tests: int) -> float:
    """Probabilitatea ca o cautare de seed sa gaseasca o potrivire din pura intamplare.

    E intrebarea pe care nimeni nu si-o pune: daca incerci 10 milioane de seed-uri
    pe o secventa de 10 culori, VEI gasi unul care se potriveste, si nu inseamna nimic.
    """
    if bits_per_spin <= 0:
        return 1.0
    return min(1.0, tests * (2.0 ** (-n_symbols * bits_per_spin)))


def spins_for_credible_match(tests: int, bits_per_spin: float,
                             target_probability: float = 0.001) -> int:
    """Cate rotiri trebuie sa se potriveasca pentru ca un seed gasit sa fie credibil."""
    if bits_per_spin <= 0:
        return 10 ** 9
    return math.ceil(math.log2(tests / target_probability) / bits_per_spin)
