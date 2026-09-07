"""Atacuri concrete de recuperare a starii / seed-ului.

Regula: fiecare atac declara EXACT de ce are nevoie si esueaza explicit daca
nu are. Nu exista "poate ca e un LCG" -- ori reproducem secventa, ori nu.
"""
from __future__ import annotations

import math
import time
from dataclasses import dataclass, field
from typing import Callable, Iterator, Sequence

from .generators import CATALOG, LCG_PARAMS, MT19937, untemper
from .mappings import Mapping


@dataclass
class AttackResult:
    attack: str
    generator: str
    success: bool
    reason: str
    seed: int | None = None
    offset: int = 0
    mapping: str | None = None
    predicted_next: list[str] = field(default_factory=list)
    tried: int = 0
    elapsed_s: float = 0.0
    detail: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "attack": self.attack, "generator": self.generator, "success": self.success,
            "reason": self.reason, "seed": self.seed, "offset": self.offset,
            "mapping": self.mapping, "predicted_next": self.predicted_next,
            "tried": self.tried, "elapsed_s": round(self.elapsed_s, 3),
            "detail": self.detail,
        }


# --------------------------------------------------------------------------
# 1. LCG: recuperare algebrica a parametrilor din output-uri complete
# --------------------------------------------------------------------------
def recover_lcg_parameters(outputs: Sequence[int], modulus: int) -> tuple[int, int] | None:
    """Recupereaza (a, c) dintr-un LCG cunoscand modulul si >=3 output-uri consecutive.

    Din x2 = a*x1 + c si x1 = a*x0 + c rezulta (x2-x1) = a*(x1-x0) mod m,
    deci a = (x2-x1) * (x1-x0)^-1 mod m. Necesita ca (x1-x0) sa fie inversabil
    modulo m. Este algebra exacta, nu cautare: daca datele sunt un LCG cu acest
    modul, iese instantaneu.
    """
    if len(outputs) < 3:
        return None
    x0, x1, x2 = outputs[0] % modulus, outputs[1] % modulus, outputs[2] % modulus
    d1 = (x1 - x0) % modulus
    d2 = (x2 - x1) % modulus
    if math.gcd(d1, modulus) != 1:
        return None                     # diferenta nu e inversabila modulo m
    a = (d2 * pow(d1, -1, modulus)) % modulus
    c = (x1 - a * x0) % modulus
    # verificare pe toate output-urile disponibile
    state = outputs[0] % modulus
    for expected in outputs[1:]:
        state = (a * state + c) % modulus
        if state != expected % modulus:
            return None
    return a, c


def attack_lcg_algebraic(raw_outputs: Sequence[int]) -> AttackResult:
    """Incearca recuperarea directa a unui LCG din numere brute observate."""
    started = time.perf_counter()
    if len(raw_outputs) < 4:
        return AttackResult("lcg-algebraic", "LCG (modul necunoscut)", False,
                            f"Necesare minim 4 output-uri BRUTE consecutive "
                            f"(sunt {len(raw_outputs)}).",
                            elapsed_s=time.perf_counter() - started)
    candidates = sorted({m for _, _, m, _ in LCG_PARAMS.values()} |
                        {2 ** 31, 2 ** 32, 2 ** 48, 2 ** 64, 2 ** 31 - 1})
    for modulus in candidates:
        if max(raw_outputs) >= modulus:
            continue
        found = recover_lcg_parameters(raw_outputs, modulus)
        if found:
            a, c = found
            state = raw_outputs[-1] % modulus
            nxt = []
            for _ in range(5):
                state = (a * state + c) % modulus
                nxt.append(str(state))
            known = next((name for name, (aa, cc, mm, _) in LCG_PARAMS.items()
                          if (aa, cc, mm) == (a, c, modulus)), None)
            return AttackResult(
                "lcg-algebraic", f"LCG a={a} c={c} m={modulus}", True,
                f"Parametri recuperati algebric din {len(raw_outputs)} output-uri"
                + (f"; corespund generatorului cunoscut '{known}'." if known else "."),
                seed=raw_outputs[0], mapping=None, predicted_next=nxt,
                tried=len(candidates), elapsed_s=time.perf_counter() - started,
                detail={"a": a, "c": c, "modulus": modulus, "known_as": known},
            )
    return AttackResult("lcg-algebraic", "LCG", False,
                        f"Niciun modul dintre cele {len(candidates)} testate nu explica "
                        "secventa. Datele nu sunt output brut de LCG (sau sunt trunchiate, "
                        "caz care necesita reducere de retea -- in afara scopului acestui tool).",
                        tried=len(candidates), elapsed_s=time.perf_counter() - started)


# --------------------------------------------------------------------------
# 2. MT19937: recuperarea starii prin inversarea temperarii
# --------------------------------------------------------------------------
def attack_mt19937_state(raw_outputs: Sequence[int]) -> AttackResult:
    """Reconstruieste starea MT19937 din 624 de output-uri complete consecutive."""
    started = time.perf_counter()
    need = 624
    if len(raw_outputs) < need:
        return AttackResult(
            "mt19937-state", "MT19937", False,
            f"Necesare {need} output-uri de 32 de biti CONSECUTIVE si COMPLETE "
            f"(sunt {len(raw_outputs)}). Acesta nu este un detaliu tehnic ci o limita "
            "informationala: starea are 19937 de biti si nu poate fi determinata de "
            "mai putina informatie.",
            tried=0, elapsed_s=time.perf_counter() - started,
            detail={"needed": need, "have": len(raw_outputs)})
    if any(o > 0xFFFFFFFF for o in raw_outputs[:need]):
        return AttackResult("mt19937-state", "MT19937", False,
                            "Output-urile depasesc 32 de biti -- nu sunt cuvinte MT19937.",
                            elapsed_s=time.perf_counter() - started)
    state = [untemper(o) for o in raw_outputs[:need]]
    clone = MT19937(state=state)
    # verificam pe output-urile ramase, daca exista
    extra = list(raw_outputs[need:])
    for i, expected in enumerate(extra):
        if clone.next() != expected:
            return AttackResult("mt19937-state", "MT19937", False,
                                f"Starea reconstruita nu reproduce output-ul #{need+i}. "
                                "Output-urile nu provin dintr-un MT19937, sau nu sunt consecutive.",
                                elapsed_s=time.perf_counter() - started)
    predicted = [str(clone.next()) for _ in range(5)]
    return AttackResult(
        "mt19937-state", "MT19937", True,
        f"Stare reconstruita integral din {need} output-uri si verificata pe "
        f"{len(extra)} output-uri suplimentare. Toate rezultatele viitoare sunt "
        "acum determinate exact.",
        predicted_next=predicted, tried=need,
        elapsed_s=time.perf_counter() - started,
        detail={"verified_on": len(extra)})


# --------------------------------------------------------------------------
# 3. Cautare de seed prin forta bruta, peste generator x mapare
# --------------------------------------------------------------------------
def attack_seed_search(observed: Sequence[str], generators: Sequence[str],
                       mappings: Sequence[Mapping], seeds: Iterator[int],
                       max_seeds: int = 200_000, max_offset: int = 0,
                       accept: float = 0.98, check_length: int = 200,
                       progress: Callable[[int], None] | None = None) -> list[AttackResult]:
    """Cauta un (generator, seed, mapare, decalaj) care reproduce secventa observata.

    Trei detalii care fac diferenta intre un rezultat util si unul inselator:

    1. Potrivire PARTIALA, nu exacta. Maparea reala a jocului (pragurile pe care
       le compara cu random()) nu ne este cunoscuta; o reconstruim din frecventele
       observate, deci difera usor. Cerand potrivire perfecta am rata generatorul
       corect. Acceptam deci >= `accept` din simboluri si raportam procentul.
    2. Abandon rapid. De indata ce un candidat depaseste numarul maxim de erori
       admis, il abandonam -- asa devine fezabila testarea a zeci de mii de seed-uri.
    3. Lungime de verificare marginita. 200 de simboluri la ~1.4 biti fiecare
       inseamna ~280 de biti de dovada, mult peste cat trebuie ca sa excludem
       hazardul intre cateva zeci de mii de candidati. Castigatorul e apoi
       verificat pe TOATA secventa.
    """
    results: list[AttackResult] = []
    observed = list(observed)
    check_n = min(len(observed), check_length)
    max_errors = int(check_n * (1.0 - accept))
    horizon = check_n + max_offset

    seed_list = []
    for i, s in enumerate(seeds):
        if i >= max_seeds:
            break
        seed_list.append(s)

    for gen_key in generators:
        spec, factory = CATALOG[gen_key]
        modulus = spec.modulus
        started = time.perf_counter()
        best: tuple[float, int, str, int] | None = None   # (acord, seed, mapare, decalaj)
        tried = 0

        for seed in seed_list:
            tried += 1
            if progress and tried % 5000 == 0:
                progress(tried)
            stream = factory(seed)
            raw = [next(stream) for _ in range(horizon)]
            for mapping in mappings:
                symbols = [mapping.fn(r, modulus) for r in raw]
                for offset in range(max_offset + 1):
                    errors = 0
                    matched = 0
                    for i in range(check_n):
                        if symbols[offset + i] == observed[i]:
                            matched += 1
                        else:
                            errors += 1
                            if errors > max_errors:
                                break
                    agreement = matched / check_n
                    if best is None or agreement > best[0]:
                        best = (agreement, seed, mapping.key, offset)
                    if errors <= max_errors:
                        # candidat plauzibil: verificam pe TOATA secventa observata
                        full = [mapping.fn(r, modulus) for r in
                                [next(stream) for _ in range(len(observed) + offset - horizon)]]
                        all_symbols = symbols + full
                        window = all_symbols[offset:offset + len(observed)]
                        hits = sum(1 for a, b in zip(window, observed) if a == b)
                        full_agreement = hits / len(observed)
                        nxt = [mapping.fn(r, modulus) for r in
                               [next(stream) for _ in range(5)]]
                        return_result = AttackResult(
                            "seed-search", spec.name, True,
                            f"Seed {seed} cu maparea '{mapping.name}' si decalajul "
                            f"{offset} reproduce {full_agreement*100:.1f}% din cele "
                            f"{len(observed)} rezultate observate "
                            f"({'potrivire exacta' if full_agreement == 1.0 else 'potrivire partiala -- maparea reconstruita difera usor de cea reala'}).",
                            seed=seed, offset=offset, mapping=mapping.key,
                            predicted_next=nxt, tried=tried,
                            elapsed_s=time.perf_counter() - started,
                            detail={"generator_key": gen_key,
                                    "agreement": full_agreement,
                                    "agreement_on_check": agreement,
                                    "check_length": check_n})
                        results.append(return_result)
                        best = None
                        break
                if best is None:
                    break
            if best is None:
                break

        if best is not None:
            agreement, bseed, bmap, boff = best
            results.append(AttackResult(
                "seed-search", spec.name, False,
                f"Niciun seed dintre cele {tried} testate (x {len(mappings)} mapari"
                f"{f' x {max_offset+1} decalaje' if max_offset else ''}) nu reproduce "
                f"secventa. Cel mai bun candidat: seed {bseed} cu {agreement*100:.1f}% "
                f"acord pe primele {check_n} rotiri -- sub pragul de {accept*100:.0f}% "
                f"si compatibil cu simpla intamplare.",
                tried=tried, elapsed_s=time.perf_counter() - started,
                detail={"generator_key": gen_key, "seed_space_bits": spec.state_bits,
                        "best_agreement": agreement, "best_seed": bseed,
                        "best_mapping": bmap, "check_length": check_n}))
    return results


def time_seed_candidates(center_ts: float, window_s: int = 3600,
                         milliseconds: bool = False) -> Iterator[int]:
    """Seed-uri plauzibile daca jocul se initializeaza din ceas.

    Este singurul atac prin forta bruta care are sanse reale: spatiul seed-urilor
    derivate din timp e mic (o zi = 86400 de valori in secunde), spre deosebire
    de cele 4 miliarde de valori ale unui seed de 32 de biti.
    """
    center = int(center_ts * 1000) if milliseconds else int(center_ts)
    span = window_s * 1000 if milliseconds else window_s
    for delta in range(0, span + 1):
        yield center - delta
        if delta:
            yield center + delta
