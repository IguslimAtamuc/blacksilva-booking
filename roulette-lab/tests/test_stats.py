"""Validarea primitivelor statistice contra valorilor de referinta publicate."""
import unittest

from roulette_lab.stats.distributions import (betainc, binom_sf, chi2_sf, norm_cdf,
                                              norm_ppf)
from roulette_lab.stats.tests import (benjamini_hochberg, binom_test, bootstrap_mean_ci,
                                      chi2_gof, chi2_independence, sign_flip_test)


class TestDistributions(unittest.TestCase):
    def test_chi2_sf_matches_tables(self):
        for x, df, expected in [(3.841, 1, 0.05), (5.991, 2, 0.05), (7.815, 3, 0.05),
                                (9.488, 4, 0.05), (11.070, 5, 0.05), (16.919, 9, 0.05),
                                (6.635, 1, 0.01), (13.277, 4, 0.01)]:
            self.assertAlmostEqual(chi2_sf(x, df), expected, places=3,
                                   msg=f"chi2_sf({x}, {df})")

    def test_chi2_sf_edges(self):
        self.assertEqual(chi2_sf(0, 3), 1.0)
        self.assertEqual(chi2_sf(-1, 3), 1.0)
        self.assertLess(chi2_sf(1000, 1), 1e-100)

    def test_norm_cdf(self):
        for z, expected in [(0, .5), (1, .8413447), (1.96, .9750021), (-2.5, .0062097)]:
            self.assertAlmostEqual(norm_cdf(z), expected, places=6)

    def test_norm_ppf_inverts_cdf(self):
        for p in (0.001, 0.025, 0.5, 0.9, 0.975, 0.999):
            self.assertAlmostEqual(norm_cdf(norm_ppf(p)), p, places=6)

    def test_binom_sf(self):
        self.assertAlmostEqual(binom_sf(59, 100, 0.5), 0.0284439, places=6)
        self.assertAlmostEqual(binom_sf(4, 10, 0.5), 0.6230469, places=6)
        self.assertEqual(binom_sf(10, 10, 0.5), 0.0)

    def test_betainc_bounds(self):
        self.assertEqual(betainc(2, 3, 0.0), 0.0)
        self.assertEqual(betainc(2, 3, 1.0), 1.0)
        self.assertAlmostEqual(betainc(2, 3, 0.5), 0.6875, places=6)


class TestTests(unittest.TestCase):
    def test_binom_test_symmetric(self):
        self.assertAlmostEqual(binom_test(50, 100, 0.5), 1.0, places=6)
        self.assertLess(binom_test(70, 100, 0.5), 0.0001)
        self.assertAlmostEqual(binom_test(19, 36, 0.487), 0.7393, places=3)

    def test_binom_test_directions(self):
        self.assertLess(binom_test(70, 100, 0.5, "greater"), 0.0001)
        self.assertGreater(binom_test(70, 100, 0.5, "less"), 0.99)

    def test_chi2_gof_flags_small_expected(self):
        outcome = chi2_gof([10, 8, 2], [6.67, 6.67, 6.67])
        self.assertGreater(outcome.statistic, 0)
        outcome = chi2_gof([10, 8, 2], [9, 9, 2])
        self.assertTrue(outcome.warnings, "trebuie sa avertizeze cand asteptatul < 5")

    def test_chi2_independence_on_independent_table(self):
        outcome = chi2_independence([[50, 50], [50, 50]])
        self.assertAlmostEqual(outcome.statistic, 0.0, places=9)
        self.assertAlmostEqual(outcome.p_value, 1.0, places=6)

    def test_chi2_independence_on_dependent_table(self):
        outcome = chi2_independence([[90, 10], [10, 90]])
        self.assertLess(outcome.p_value, 1e-15)

    def test_benjamini_hochberg_monotone_and_bounded(self):
        ps = [0.001, 0.008, 0.039, 0.041, 0.042, 0.06, 0.074, 0.205, 0.212, 0.216]
        qs = benjamini_hochberg(ps)
        self.assertEqual(len(qs), len(ps))
        self.assertTrue(all(0 <= q <= 1 for q in qs))
        ordered = [q for _, q in sorted(zip(ps, qs))]
        self.assertEqual(ordered, sorted(ordered), "q trebuie sa fie monoton in p")
        self.assertTrue(all(q >= p for p, q in zip(ps, qs)), "q >= p intotdeauna")

    def test_benjamini_hochberg_empty(self):
        self.assertEqual(benjamini_hochberg([]), [])

    def test_sign_flip_null_and_alternative(self):
        self.assertGreater(sign_flip_test([0.1, -0.1] * 30, seed=1).p_value, 0.2)
        self.assertLess(sign_flip_test([0.3] * 40, seed=1).p_value, 0.01)

    def test_bootstrap_ci_contains_mean(self):
        mean, lo, hi = bootstrap_mean_ci([1, 2, 3, 4, 5] * 40, seed=1)
        self.assertAlmostEqual(mean, 3.0, places=6)
        self.assertLess(lo, 3.0)
        self.assertGreater(hi, 3.0)


if __name__ == "__main__":
    unittest.main()
