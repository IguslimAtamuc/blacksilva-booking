"""Identificarea generatoarelor pseudo-aleatoare."""
from .attacks import (attack_lcg_algebraic, attack_mt19937_state, attack_seed_search,
                      recover_lcg_parameters, time_seed_candidates)
from .budget import budget_table, observed_bits_per_spin, spins_for_credible_match
from .generators import CATALOG, LCG, MT19937, PCG32, Xorshift32, temper, untemper
from .identify import identify

__all__ = ["identify", "CATALOG", "LCG", "MT19937", "PCG32", "Xorshift32",
           "temper", "untemper", "budget_table", "observed_bits_per_spin",
           "spins_for_credible_match", "attack_lcg_algebraic", "attack_mt19937_state",
           "attack_seed_search", "recover_lcg_parameters", "time_seed_candidates"]
