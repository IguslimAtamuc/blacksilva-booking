"""Teste de comportament pe date cu adevar CUNOSCUT.

Acestea sunt cele mai importante teste din proiect. Verifica proprietatea pe care
se sprijina totul: pe date aleatoare tool-ul NU gaseste tipare si NU prezice,
iar pe date cu structura reala o gaseste si prezice. Un tool de predictie care
nu trece ambele jumatati este inutil, indiferent cat de bine arata.
"""
import math
import random
import unittest

from roulette_lab.analysis import EVIDENCE, run_all
from roulette_lab.backtest import run_backtest
from roulette_lab.data.io import (dump_csv, dump_json, load_any, load_csv, load_text,
                                  migrate_legacy)
from roulette_lab.data.schema import Dataset, PredictionRecord
from roulette_lab.decide import REFUSAL, decide
from roulette_lab.models import default_models
from roulette_lab.report import build_report, render

SEED = 20240501


def dataset_from(values, **kwargs):
    ds = Dataset(**kwargs)
    ds.extend(values)
    return ds


def iid_sequence(n, seed=SEED):
    rng = random.Random(seed)
    return [rng.choices("RNV", weights=[0.47, 0.47, 0.06])[0] for _ in range(n)]


def markov_sequence(n, seed=SEED):
    rng = random.Random(seed)
    out, cur = [], "R"
    weights = {"R": [0.20, 0.74, 0.06], "N": [0.74, 0.20, 0.06], "V": [0.47, 0.47, 0.06]}
    for _ in range(n):
        out.append(cur)
        cur = rng.choices("RNV", weights=weights[cur])[0]
    return out


def cyclic_sequence(n, noise=0.10, seed=SEED):
    rng = random.Random(seed)
    base = list("RRNVRNN")
    return [base[i % 7] if rng.random() > noise else rng.choice("RNV") for i in range(n)]


class TestRefusesOnRandomData(unittest.TestCase):
    """Proprietatea centrala: fara dovezi, nicio predictie garantata."""

    def test_refuses_on_iid(self):
        decision = decide(dataset_from(iid_sequence(800)), seed=SEED)
        self.assertFalse(decision.allowed)
        self.assertIn(REFUSAL, decision.message)
        self.assertIsNone(decision.prediction)

    def test_refuses_on_tiny_dataset(self):
        decision = decide(dataset_from(iid_sequence(39)), seed=SEED)
        self.assertFalse(decision.allowed)
        self.assertFalse(decision.checks[0]["passed"])

    def test_no_false_evidence_on_iid(self):
        """Cu corectie pentru teste multiple, hazardul pur nu trebuie sa produca
        dovezi de dependenta -- doar, eventual, de frecventa inegala."""
        report = run_all(dataset_from(iid_sequence(800)), seed=SEED)
        dependence = {"markov", "autocorrelation", "entropy", "periodicity",
                      "repeats", "serial_position", "resets"}
        found = [r.key for r in report.results
                 if r.verdict == EVIDENCE and r.key in dependence]
        self.assertEqual(found, [], f"fals pozitiv de dependenta: {found}")

    def test_no_model_beats_baseline_on_iid(self):
        bt = run_backtest(dataset_from(iid_sequence(800)), seed=SEED)
        for key, comp in bt.comparisons.items():
            self.assertGreater(comp["p_value_corrected"], 0.01,
                               f"{key} pare semnificativ pe date aleatoare")


class TestDetectsRealStructure(unittest.TestCase):
    """Cealalta jumatate: cand structura EXISTA, trebuie gasita si folosita."""

    def test_detects_markov_dependence(self):
        report = run_all(dataset_from(markov_sequence(800)), seed=SEED)
        markov = next(r for r in report.results if r.key == "markov")
        self.assertEqual(markov.verdict, EVIDENCE)
        self.assertGreater(markov.effect, 0.05)

    def test_allows_prediction_on_markov(self):
        decision = decide(dataset_from(markov_sequence(800)), seed=SEED)
        self.assertTrue(decision.allowed, "trebuie sa prezica atunci cand datele o sustin")
        self.assertIn(decision.prediction, ("R", "N", "V"))
        self.assertTrue(all(c["passed"] for c in decision.checks))
        self.assertAlmostEqual(sum(decision.probabilities.values()), 1.0, places=6)
        self.assertGreater(decision.confidence, 0.5)

    def test_detects_cycle_period(self):
        report = run_all(dataset_from(cyclic_sequence(600)), seed=SEED)
        periodicity = next(r for r in report.results if r.key == "periodicity")
        self.assertEqual(periodicity.verdict, EVIDENCE)
        self.assertEqual(periodicity.detail["best_period"] % 7, 0,
                         "perioada gasita trebuie sa fie multiplu al celei reale (7)")


class TestGuessMode(unittest.TestCase):
    """Modul 'arata-mi oricum o culoare' -- cu acuratetea reala alaturi."""

    def test_guess_always_returns_a_symbol(self):
        decision = decide(dataset_from(iid_sequence(800)), seed=SEED)
        self.assertIsNotNone(decision.guess)
        self.assertIn(decision.guess["symbol"], ("R", "N", "V"))
        self.assertFalse(decision.allowed, "ghicitul nu schimba verdictul de evidenta")

    def test_guess_reports_measured_accuracy(self):
        decision = decide(dataset_from(iid_sequence(800)), seed=SEED)
        guess = decision.guess
        self.assertGreaterEqual(guess["measured_accuracy"], 0.0)
        self.assertLessEqual(guess["measured_accuracy"], 1.0)
        self.assertIn("baseline_accuracy", guess)

    def test_guess_on_random_data_is_not_better_than_baseline(self):
        guess = decide(dataset_from(iid_sequence(800)), seed=SEED).guess
        self.assertLess(abs(guess["measured_accuracy"] - guess["baseline_accuracy"]), 0.08)

    def test_guess_needs_some_data(self):
        self.assertIsNone(decide(dataset_from(["R", "N"]), seed=SEED).guess)


class TestBacktestIntegrity(unittest.TestCase):
    def test_no_lookahead_leakage(self):
        """Modificarea viitorului nu are voie sa schimbe predictiile trecute."""
        values = markov_sequence(300)
        base = run_backtest(dataset_from(values), warmup=100, seed=SEED)
        altered = run_backtest(dataset_from(values[:250] + ["V"] * 50),
                               warmup=100, seed=SEED)
        for i in range(150):
            for key in base.runs:
                self.assertEqual(base.runs[key].distributions[i],
                                 altered.runs[key].distributions[i],
                                 f"{key} vede in viitor la pozitia {i}")

    def test_all_models_evaluated_on_same_points(self):
        bt = run_backtest(dataset_from(iid_sequence(300)), warmup=100, seed=SEED)
        counts = {k: r.metrics["n"] for k, r in bt.runs.items()}
        self.assertEqual(len(set(counts.values())), 1, f"puncte diferite: {counts}")

    def test_probabilities_are_valid(self):
        symbols = ["R", "N", "V"]
        prefix = markov_sequence(200)
        for model in default_models():
            dist = model.predict(prefix, symbols)
            self.assertAlmostEqual(sum(dist.values()), 1.0, places=9, msg=model.name)
            for s in symbols:
                self.assertGreater(dist[s], 0.0, f"{model.name} a dat probabilitate 0")

    def test_uniform_baseline_has_expected_log_loss(self):
        bt = run_backtest(dataset_from(iid_sequence(400)), seed=SEED)
        self.assertAlmostEqual(bt.runs["uniform"].metrics["log_loss_bits"],
                               math.log2(3), places=6)

    def test_incremental_state_equals_full_rescan(self):
        """Optimizarea de viteza nu are voie sa schimbe niciun rezultat."""
        symbols = ["R", "N", "V"]
        values = markov_sequence(200)
        for model in default_models():
            state = model.make_state(symbols)
            for t in range(len(values)):
                fast = state.predict(values[:t])
                slow = model.predict(values[:t], symbols)
                for s in symbols:
                    self.assertAlmostEqual(fast[s], slow[s], places=9,
                                           msg=f"{model.name} la t={t}")
                state.observe(values[:t], values[t])


class TestDataIO(unittest.TestCase):
    def test_text_round_trip(self):
        self.assertEqual(load_text("R,N,V,rosu,negru,VERDE").values,
                         ["R", "N", "V", "R", "N", "V"])

    def test_compact_string(self):
        self.assertEqual(load_text("RRNVR").values, ["R", "R", "N", "V", "R"])

    def test_csv_with_metadata(self):
        ds = load_csv("index,value,ts,session,miza\n0,R,1700000000,s1,10\n"
                      "1,negru,2023-11-15 10:20:00,s1,20\n")
        self.assertEqual(ds.values, ["R", "N"])
        self.assertEqual(ds.spins[0].session, "s1")
        self.assertEqual(ds.spins[0].meta["miza"], "10")
        self.assertIsNotNone(ds.spins[1].ts)

    def test_csv_round_trip_preserves_values(self):
        ds = dataset_from(iid_sequence(50))
        self.assertEqual(load_csv(dump_csv(ds)).values, ds.values)

    def test_json_round_trip_preserves_fingerprint(self):
        ds = dataset_from(iid_sequence(50))
        self.assertEqual(load_any(dump_json(ds), "x.json").fingerprint(), ds.fingerprint())

    def test_rejects_unknown_symbol(self):
        with self.assertRaises(ValueError):
            load_text("R,X,N")

    def test_legacy_migration(self):
        ds = migrate_legacy({
            "history": ["R", "N", "V"],
            "predictions": [{"predicted": "R", "actual": "N", "correct": False}],
            "saved_at": "2026-09-07T21:18:33"})
        self.assertEqual(ds.values, ["R", "N", "V"])
        self.assertEqual(len(ds.predictions), 1)
        self.assertFalse(ds.predictions[0].gated)

    def test_prediction_resolved_on_next_spin(self):
        ds = dataset_from(["R", "N"])
        ds.log_prediction(PredictionRecord(at_index=2, predicted="V", probabilities={},
                                           confidence=0.5, model="test", gated=True,
                                           reason="", ts=0.0))
        ds.add("V")
        self.assertTrue(ds.predictions[0].correct)

    def test_undo_invalidates_prediction(self):
        ds = dataset_from(["R", "N"])
        ds.log_prediction(PredictionRecord(at_index=2, predicted="V", probabilities={},
                                           confidence=0.5, model="t", gated=True,
                                           reason="", ts=0.0))
        ds.add("V")
        ds.undo()
        self.assertIsNone(ds.predictions[0].actual)


class TestReport(unittest.TestCase):
    def test_report_is_reproducible(self):
        ds = dataset_from(iid_sequence(250))
        first = build_report(ds, seed=SEED, run_prng=False)
        second = build_report(ds, seed=SEED, run_prng=False)
        for a, b in zip(first["analysis"]["results"], second["analysis"]["results"]):
            self.assertEqual(a["p_value"], b["p_value"], f"{a['key']} nu e reproductibil")

    def test_markdown_renders_all_sections(self):
        report = build_report(dataset_from(iid_sequence(250)), seed=SEED, run_prng=False)
        text = render(report)
        for section in ("# Raport de analiza", "## 1. Analiza secventei",
                        "## 3. Backtesting", "## 4. Decizia de predictie",
                        "## 5. Ce putem si ce nu putem afirma"):
            self.assertIn(section, text)


if __name__ == "__main__":
    unittest.main()
