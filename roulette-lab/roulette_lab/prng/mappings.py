"""Maparea output PRNG -> simbol observat.

Este veriga lipsa a oricarei identificari de generator: chiar daca ghicim
generatorul, nu vedem numerele lui brute, ci doar culoarea afisata de joc.
Trebuie deci sa cautam simultan generatorul SI functia de mapare. Fiecare
mapare in plus multiplica spatiul de cautare -- motiv in plus sa inregistram
numarul slotului, unde maparea e aproape sigur `raw % 37` sau `floor(u*37)`.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


@dataclass
class Mapping:
    key: str
    name: str
    fn: Callable[[int, int], str]      # (raw, modulus) -> simbol
    description: str


def _number_color(number: int) -> str:
    if number == 0:
        return "V"
    return "R" if number in RED_NUMBERS else "N"


def build_mappings(preset: str, probs: dict[str, float] | None = None) -> list[Mapping]:
    """Maparile candidate pentru un alfabet dat."""
    out: list[Mapping] = []
    if preset == "roulette37":
        out.append(Mapping("mod37", "raw % 37", lambda r, m: str(r % 37),
                           "cea mai comuna implementare: restul impartirii la 37"))
        out.append(Mapping("float37", "floor(raw/m * 37)",
                           lambda r, m: str(min(36, int(r / m * 37))),
                           "tipic pentru Math.floor(Math.random()*37)"))
        out.append(Mapping("mod37_hi", "biti superiori % 37",
                           lambda r, m: str((r >> 16) % 37),
                           "unele implementari folosesc bitii superiori, mai 'buni'"))
        return out

    if preset == "color3":
        p = probs or {"R": 0.47, "N": 0.47, "V": 0.06}
        for order in (("R", "N", "V"), ("N", "R", "V"), ("V", "R", "N")):
            cuts = []
            acc = 0.0
            for sym in order[:-1]:
                acc += p.get(sym, 0.0)
                cuts.append(acc)

            def make(order=order, cuts=cuts):
                def fn(raw: int, modulus: int) -> str:
                    u = raw / modulus
                    for i, cut in enumerate(cuts):
                        if u < cut:
                            return order[i]
                    return order[-1]
                return fn

            out.append(Mapping(
                f"threshold_{''.join(order)}", f"praguri pe u=raw/m, ordine {'-'.join(order)}",
                make(), "u < p1 -> primul simbol, etc. (praguri din frecventele observate)"))
        out.append(Mapping("mod37_color", "culoarea slotului (raw % 37)",
                           lambda r, m: _number_color(r % 37),
                           "jocul alege un slot 0-36, apoi afiseaza culoarea lui"))
        out.append(Mapping("mod3", "raw % 3", lambda r, m: "RNV"[r % 3],
                           "varianta naiva cu trei rezultate egal probabile"))
        return out

    return [Mapping("mod_k", "raw % k", lambda r, m: str(r), "mapare identitate")]
