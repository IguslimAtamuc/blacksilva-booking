"""Importa toate analizoarele ca sa se inregistreze in registru.

Ca sa adaugi un analizor nou: creeaza un fisier, decoreaza functia cu
@register("cheie") si adauga-l aici. Nimic altceva nu trebuie modificat.
"""
from . import (  # noqa: F401
    autocorr, entropy, frequency, markov, periodicity, repeats, resets, runs, serial, wheel,
)
