"""Validarea generatoarelor si a atacurilor pe date cu adevar cunoscut."""
import random
import unittest

from roulette_lab.prng.attacks import (attack_lcg_algebraic, attack_mt19937_state,
                                       attack_seed_search, recover_lcg_parameters,
                                       time_seed_candidates)
from roulette_lab.prng.budget import budget_table, spins_for_credible_match
from roulette_lab.prng.generators import (LCG_PARAMS, MT19937, PCG32, Xorshift32,
                                          make_lcg, temper, untemper)
from roulette_lab.prng.mappings import build_mappings


class TestGenerators(unittest.TestCase):
    def test_mt19937_matches_cpython(self):
        """Daca aceasta cade, implementarea noastra de MT19937 nu e cea reala."""
        for seed in (0, 7, 12345, 2 ** 40 + 13):
            reference = random.Random(seed)
            mine = MT19937.from_python_seed(seed)
            for i in range(300):
                self.assertEqual(mine.next(), reference.getrandbits(32),
                                 f"seed={seed}, output #{i}")

    def test_temper_is_bijective(self):
        for value in (0, 1, 2 ** 31, 0xDEADBEEF, 0xFFFFFFFF, 123456789):
            self.assertEqual(untemper(temper(value)), value)

    def test_lcg_determinism(self):
        self.assertEqual(make_lcg("java_random", 42).stream(5),
                         make_lcg("java_random", 42).stream(5))

    def test_generators_stay_in_range(self):
        self.assertLess(Xorshift32(42).next(), 2 ** 32)
        self.assertLess(PCG32(42).next(), 2 ** 32)
        self.assertNotEqual(Xorshift32(0).next(), 0, "starea 0 trebuie evitata")


class TestAttacks(unittest.TestCase):
    def test_recover_lcg_parameters(self):
        for name, (a, c, m, _) in LCG_PARAMS.items():
            outputs = make_lcg(name, 987654321).stream(6)
            found = recover_lcg_parameters(outputs, m)
            if found:                       # unele module dau diferente neinversabile
                self.assertEqual(found, (a, c), name)

    def test_attack_lcg_algebraic_identifies_known_generator(self):
        result = attack_lcg_algebraic(make_lcg("java_random", 555).stream(6))
        self.assertTrue(result.success)
        self.assertEqual(result.detail["known_as"], "java_random")

    def test_attack_lcg_rejects_non_lcg(self):
        rng = random.Random(1)
        result = attack_lcg_algebraic([rng.getrandbits(31) for _ in range(10)])
        self.assertFalse(result.success)

    def test_mt19937_state_recovery(self):
        source = random.Random(999)
        outputs = [source.getrandbits(32) for _ in range(630)]
        result = attack_mt19937_state(outputs)
        self.assertTrue(result.success)
        expected = [str(source.getrandbits(32)) for _ in range(5)]
        self.assertEqual(result.predicted_next, expected,
                         "starea recuperata trebuie sa prezica exact ce urmeaza")

    def test_mt19937_refuses_with_insufficient_outputs(self):
        source = random.Random(1)
        result = attack_mt19937_state([source.getrandbits(32) for _ in range(623)])
        self.assertFalse(result.success)
        self.assertIn("624", result.reason)

    def test_seed_search_recovers_time_seed(self):
        ts = 1700000000
        gen = make_lcg("numerical_recipes", ts)
        mapping = next(m for m in build_mappings("color3", {"R": .47, "N": .47, "V": .06})
                       if m.key == "threshold_RNV")
        observed = [mapping.fn(gen.next(), 2 ** 32) for _ in range(120)]
        results = attack_seed_search(
            observed, ["numerical_recipes"],
            build_mappings("color3", {"R": .47, "N": .47, "V": .06}),
            time_seed_candidates(ts, 200), max_seeds=500)
        self.assertTrue(results[0].success)
        self.assertEqual(results[0].seed, ts)

    def test_seed_search_finds_nothing_in_true_random(self):
        rng = random.Random(4)
        observed = [rng.choice("RNV") for _ in range(120)]
        results = attack_seed_search(
            observed, ["numerical_recipes", "xorshift32"],
            build_mappings("color3"), iter(range(3000)), max_seeds=3000)
        self.assertFalse(any(r.success for r in results),
                         "nu are voie sa 'gaseasca' un generator in date aleatoare")


class TestBudget(unittest.TestCase):
    def test_budget_scales_with_information(self):
        colors = budget_table(["R", "N"] * 200, 3)
        self.assertLess(colors["bits_per_spin_observed"], 1.01)
        mt = next(r for r in colors["rows"] if r["key"] == "mt19937")
        self.assertGreater(mt["min_spins_information"], 10000)
        self.assertEqual(mt["status"], "imposibil-practic")

    def test_more_spins_needed_for_more_candidates(self):
        few = spins_for_credible_match(100, 1.4)
        many = spins_for_credible_match(10 ** 9, 1.4)
        self.assertGreater(many, few)


if __name__ == "__main__":
    unittest.main()
