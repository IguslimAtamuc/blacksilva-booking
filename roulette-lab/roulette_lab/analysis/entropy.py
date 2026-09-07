"""Entropie si compresibilitate: cati biti de informatie se pot extrage din istoric?

Este cea mai directa masura a predictibilitatii. Entropia conditionata spune
exact cat de mult scade incertitudinea rezultatului urmator daca stii trecutul.
Daca scaderea e zero, predictia e imposibila -- indiferent de algoritm.
"""
from __future__ import annotations

import math
import zlib
from collections import Counter, defaultdict

from ..data.schema import Dataset
from ..stats.tests import permutation_test
from ._util import adaptive_iterations, entropy_bits
from .base import AnalysisResult, register, skipped


def conditional_entropy(values, order: int) -> tuple[float, int]:
    """H(X_t | ultimele `order` simboluri), in biti, cu numarul de contexte observate."""
    if order == 0:
        return entropy_bits(Counter(values).values()), 1
    contexts: dict[tuple, Counter] = defaultdict(Counter)
    for i in range(order, len(values)):
        contexts[tuple(values[i - order:i])][values[i]] += 1
    total = sum(sum(c.values()) for c in contexts.values())
    if total == 0:
        return 0.0, 0
    h = 0.0
    for counter in contexts.values():
        weight = sum(counter.values()) / total
        h += weight * entropy_bits(counter.values())
    return h, len(contexts)


def miller_madow(h_plugin: float, n: int, nonzero_cells: int) -> float:
    """Corectie de bias Miller-Madow.

    Entropia estimata din esantion e sistematic SUBESTIMATA, ceea ce creeaza
    iluzia de predictibilitate. Corectia adauga (m-1)/(2n log 2) biti.
    Fara ea, orice secventa scurta pare sa contina structura.
    """
    if n <= 0:
        return h_plugin
    return h_plugin + (nonzero_cells - 1) / (2 * n * math.log(2))


@register("entropy")
def analyze_entropy(ds: Dataset, seed: int = 12345, max_order: int = 3, **_) -> AnalysisResult:
    values = ds.values
    n = len(values)
    k = len(ds.symbols)
    if n < 60:
        return skipped("entropy", "Entropie si compresibilitate",
                       "Cati biti de informatie despre urmatorul rezultat contine istoricul?",
                       f"Necesare minim 60 de rotiri (sunt {n}).", 60, n)

    h_max = math.log2(k)
    h0_raw = entropy_bits(Counter(values).values())
    h0 = miller_madow(h0_raw, n, len({v for v in values}))

    profile: dict[int, dict] = {}
    for order in range(0, max_order + 1):
        if n <= (order + 1) * k ** order:
            break
        h_raw, ctx = conditional_entropy(values, order)
        cells = ctx * k
        profile[order] = {
            "h_raw": h_raw,
            "h_corrected": miller_madow(h_raw, max(1, n - order), cells),
            "contexts": ctx,
            "obs_per_cell": (n - order) / max(1, cells),
        }

    best_order = max(profile)
    gain_raw = h0_raw - profile[best_order]["h_raw"]
    gain_corrected = h0 - profile[best_order]["h_corrected"]

    # Test de compresie: un compresor generic gaseste orice regularitate exploatabila.
    blob = "".join(values).encode() if k <= 40 else ",".join(values).encode()
    def compressed_size(seq) -> float:
        data = "".join(seq).encode() if k <= 40 else ",".join(seq).encode()
        return -len(zlib.compress(data, 9))     # negativ: mai mic = mai comprimabil = mai structurat

    observed_size = compressed_size(values)
    comp = permutation_test(values, compressed_size,
                            adaptive_iterations(n, 4000), seed, "greater")

    # p pentru castigul de entropie la ordinul 1 (aceeasi ipoteza nula: ordine amestecata)
    def gain_stat(seq) -> float:
        h_raw, _ = conditional_entropy(seq, 1)
        return entropy_bits(Counter(seq).values()) - h_raw

    ent = permutation_test(values, gain_stat, adaptive_iterations(n, 4000, 3), seed, "greater")

    explanation = (
        f"Entropia marginala (fara memorie) = {h0:.4f} biti din maximum {h_max:.4f} "
        f"posibili pentru {k} simboluri. Cunoscand ultimul rezultat, entropia scade la "
        f"{profile.get(1, profile[best_order])['h_corrected']:.4f} biti. "
        f"Castig brut la ordinul {best_order}: {gain_raw:.4f} biti/rotire; dupa corectia "
        f"de bias Miller-Madow: {gain_corrected:.4f} biti/rotire (p = {ent.p_value:.4f}). "
        f"Testul de compresie zlib: secventa reala se comprima la {-observed_size} octeti, "
        f"fata de {-comp.detail['null_mean']:.1f} octeti in medie pentru aceleasi simboluri "
        f"amestecate (p = {comp.p_value:.4f}). "
    )
    if min(ent.p_value, comp.p_value) >= 0.05:
        explanation += (
            "Istoricul nu contine informatie utilizabila despre rezultatul urmator. "
            "Diferenta dintre castigul brut si cel corectat arata de ce: pe esantioane "
            "mici, entropia estimata pare mereu mai mica decat este -- de aici iluzia "
            "de tipar."
        )
    else:
        explanation += (
            "Istoricul contine informatie reala despre rezultatul urmator. Marimea "
            f"({gain_corrected:.4f} biti) spune si CAT de utila e: sub ~0.01 biti/rotire, "
            "efectul e prea mic pentru a fi exploatabil practic."
        )

    return AnalysisResult(
        key="entropy", title="Entropie si compresibilitate",
        question="Cata informatie despre rezultatul urmator contine istoricul?",
        statistic=gain_corrected, statistic_name="castig informational (biti/rotire)",
        p_value=min(ent.p_value, comp.p_value) * 2,   # doua teste inrudite: corectie Bonferroni interna
        p_method="permutation",
        effect=gain_corrected, effect_name="biti/rotire",
        effect_note=f"din {h_max:.2f} biti maximi",
        n_used=n, min_n=60, recommended_n=500,
        explanation=explanation,
        detail={"h_max": h_max, "h0_raw": h0_raw, "h0_corrected": h0,
                "profile": profile, "gain_raw": gain_raw,
                "gain_corrected": gain_corrected,
                "compression_bytes": -observed_size,
                "compression_null_mean": -comp.detail["null_mean"],
                "p_entropy": ent.p_value, "p_compression": comp.p_value},
    )
