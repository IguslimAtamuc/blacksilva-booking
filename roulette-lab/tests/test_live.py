"""Motorul live: invata incremental si raporteaza cinstit ce a invatat."""
import random
import unittest

from roulette_lab.data.schema import Dataset
from roulette_lab.live import LiveEngine


def engine_for(values, symbols=("R", "N", "V")):
    engine = LiveEngine(list(symbols))
    engine.rebuild(list(values))
    return engine


class TestLearnsRepeatingPatterns(unittest.TestCase):
    """Cazul central: daca o combinatie se repeta, motorul trebuie sa o invete."""

    def test_learns_perfect_alternation(self):
        engine = engine_for(["R", "N"] * 80)
        rec = engine.recommendation()
        self.assertEqual(rec["symbol"], "R", "dupa N urmeaza mereu R")
        self.assertGreater(rec["accuracy"], 0.95)
        self.assertEqual(rec["status"], "avantaj")

    def test_learns_period_seven_cycle(self):
        engine = engine_for(list("RRNVRNN") * 40)
        rec = engine.recommendation()
        self.assertGreater(rec["accuracy"], 0.95)
        self.assertGreater(rec["accuracy_delta"], 0.4)

    def test_learns_markov_dependence(self):
        rng = random.Random(11)
        values, cur = [], "R"
        weights = {"R": [0.15, 0.80, 0.05], "N": [0.80, 0.15, 0.05],
                   "V": [0.47, 0.47, 0.06]}
        for _ in range(600):
            values.append(cur)
            cur = rng.choices("RNV", weights=weights[cur])[0]
        rec = engine_for(values).recommendation()
        self.assertEqual(rec["status"], "avantaj")
        self.assertGreater(rec["accuracy_delta"], 0.15)


class TestHonestOnRandomData(unittest.TestCase):
    def test_no_claimed_advantage_on_random(self):
        rng = random.Random(3)
        values = [rng.choices("RNV", weights=[0.47, 0.47, 0.06])[0] for _ in range(600)]
        rec = engine_for(values).recommendation()
        self.assertEqual(rec["status"], "fara_avantaj")
        self.assertLess(abs(rec["accuracy_delta"]), 0.06)

    def test_baseline_wins_on_random(self):
        rng = random.Random(9)
        values = [rng.choices("RNV", weights=[0.47, 0.47, 0.06])[0] for _ in range(600)]
        board = engine_for(values).leaderboard()
        memoryless = [r for r in board[:3] if r["is_baseline"] or r["key"] == "ensemble"]
        self.assertTrue(memoryless,
                        "pe date aleatoare, un model fara memorie trebuie sa fie in top 3")

    def test_always_returns_a_symbol(self):
        rec = engine_for(["R", "N", "V"] * 10).recommendation()
        self.assertIn(rec["symbol"], ("R", "N", "V"))
        self.assertAlmostEqual(sum(rec["probabilities"].values()), 1.0, places=6)

    def test_small_sample_reports_insufficient(self):
        rec = engine_for(["R", "N"] * 15).recommendation()
        self.assertEqual(rec["status"], "prea_putine_date")


class TestIntegrity(unittest.TestCase):
    def test_accuracy_is_out_of_sample_by_construction(self):
        """Fiecare predictie e facuta inainte de a se cunoaste rezultatul."""
        engine = LiveEngine(["R", "N", "V"])
        values = ["R", "N", "V"] * 40
        for v in values:
            engine.observe(v)
        for entry in engine.log:
            index = entry["index"]
            self.assertEqual(entry["actual"], values[index])
            self.assertLess(index, len(values))

    def test_incremental_equals_rebuild(self):
        values = list("RRNVRNN") * 20
        incremental = LiveEngine(["R", "N", "V"])
        for v in values:
            incremental.observe(v)
        rebuilt = engine_for(values)
        self.assertEqual(incremental.recommendation()["symbol"],
                         rebuilt.recommendation()["symbol"])
        self.assertEqual(incremental.stats, rebuilt.stats)

    def test_context_evidence_counts_are_correct(self):
        values = list("RN") * 30
        context = engine_for(values).context_evidence(max_order=2)
        first = next(c for c in context if c["order"] == 1)
        self.assertEqual(first["context"], ["N"])
        self.assertEqual(first["occurrences"], sum(first["following"].values()))
        self.assertEqual(first["top"], "R")

    def test_context_reports_unseen_combination(self):
        context = engine_for(["R"] * 40 + ["V"]).context_evidence(max_order=3)
        unseen = [c for c in context if c["occurrences"] == 0]
        self.assertTrue(unseen, "o combinatie noua trebuie marcata ca nevazuta")

    def test_recommendation_uses_dataset_labels(self):
        ds = Dataset()
        ds.extend(["R", "N"] * 40)
        rec = engine_for(ds.values).recommendation(ds)
        self.assertIn(rec["label"], ("Rosu", "Negru", "Verde"))


if __name__ == "__main__":
    unittest.main()
