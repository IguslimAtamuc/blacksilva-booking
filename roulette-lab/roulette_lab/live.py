"""Modul live: introduci o culoare, primesti instant predictia urmatoare.

Diferenta fata de `decide` nu este in matematica, ci in cost. `decide` reface
intreaga analiza (zeci de mii de permutari) si dureaza secunde bune. Aici
mentinem starea modelelor incremental: fiecare culoare noua costa O(1), deci
raspunsul e instantaneu chiar si dupa mii de rotiri.

Onestitatea este garantata prin CONSTRUCTIE, nu prin discipline: fiecare model
face predictia INAINTE ca rezultatul sa fie cunoscut, si abia apoi primeste
rezultatul real. Acuratetea afisata este deci intotdeauna out-of-sample --
imposibil de umflat, oricat de bine s-ar potrivi modelul pe trecut.
"""
from __future__ import annotations

import math
from collections import Counter

from .data.schema import Dataset
from .models import BASELINE_KEY, default_models
from .models.base import log_loss_bits
from .stats.distributions import norm_ppf
from .stats.tests import binom_test


class LiveEngine:
    """Predictor online: invata din fiecare rezultat introdus, in ordine."""

    # Cate rotiri initiale nu intra la socoteala acuratetii: la inceput toate
    # modelele ghicesc din nimic, iar includerea acelor predictii ar face
    # statistica mai zgomotoasa fara sa spuna ceva util.
    WARMUP = 20

    def __init__(self, symbols: list[str]):
        self.symbols = list(symbols)
        self.models = default_models()
        self.reset()

    def reset(self) -> None:
        self.states = {m.key: m.make_state(self.symbols) for m in self.models}
        self.stats = {m.key: {"n": 0, "correct": 0, "loss": 0.0} for m in self.models}
        self.history: list[str] = []
        self.log: list[dict] = []          # istoricul predictiilor live

    def rebuild(self, values: list[str]) -> None:
        """Reconstruieste starea rejucand tot istoricul, in ordine."""
        self.reset()
        for value in values:
            self.observe(value)

    def observe(self, value: str) -> None:
        """Inregistreaza rezultatul real -- dupa ce toate modelele au prezis."""
        history = self.history
        scored = len(history) >= self.WARMUP
        entry = {"index": len(history), "actual": value, "predictions": {}}
        for m in self.models:
            dist = self.states[m.key].predict(history)
            pick = max(dist, key=dist.get)
            if scored:
                st = self.stats[m.key]
                st["n"] += 1
                st["correct"] += 1 if pick == value else 0
                st["loss"] += log_loss_bits(dist, value)
            entry["predictions"][m.key] = {"pick": pick, "p": dist[value],
                                           "correct": pick == value}
        for m in self.models:
            self.states[m.key].observe(history, value)
        history.append(value)
        if scored:
            self.log.append(entry)
            if len(self.log) > 2000:
                self.log = self.log[-2000:]

    # ------------------------------------------------------------------
    def leaderboard(self) -> list[dict]:
        """Clasamentul modelelor dupa performanta lor reala de pana acum."""
        rows = []
        for m in self.models:
            st = self.stats[m.key]
            n = st["n"]
            accuracy = st["correct"] / n if n else 0.0
            rows.append({
                "key": m.key, "name": m.name, "n": n,
                "correct": st["correct"], "accuracy": accuracy,
                "log_loss": st["loss"] / n if n else float("nan"),
                "is_baseline": m.key == BASELINE_KEY,
            })
        rows.sort(key=lambda r: (r["log_loss"] if r["n"] else float("inf")))
        return rows

    def recommendation(self, dataset: Dataset | None = None) -> dict:
        """Ce culoare recomanda motorul acum, si cat de mult merita crezut.

        Modelul recomandat este cel cu cel mai mic log-loss real de pana acum --
        nu cel care "pare" mai destept. Daca modelele cu memorie nu au facut
        nimic mai bun decat numaratul simplu de frecvente, castigatorul va fi
        chiar acela, iar recomandarea va fi, corect, "nu stiu mai mult decat
        culoarea cea mai frecventa".
        """
        board = self.leaderboard()
        best = board[0]
        baseline = next(r for r in board if r["is_baseline"])
        dist = self.states[best["key"]].predict(self.history)
        pick = max(dist, key=dist.get)
        label = dataset.label(pick) if dataset else pick

        n = best["n"]
        delta = best["accuracy"] - baseline["accuracy"]
        # Intervalul Wilson 95% pentru acuratetea masurata: cu putine predictii,
        # o acuratete de 60% poate insemna orice.
        if n:
            z = norm_ppf(0.975)
            p = best["accuracy"]
            denom = 1 + z * z / n
            centre = (p + z * z / (2 * n)) / denom
            half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
            ci = (max(0.0, centre - half), min(1.0, centre + half))
            # Bate modelul fara memorie mai des decat ar face-o norocul?
            p_value = binom_test(best["correct"], n, max(1e-9, baseline["accuracy"]),
                                 "greater")
        else:
            ci, p_value = (0.0, 1.0), 1.0

        if n < 50:
            status, verdict = "prea_putine_date", (
                f"Doar {n} predictii evaluate. Sub 50 nu se poate spune nimic despre "
                "acuratete. Continua sa introduci rezultate.")
        elif delta < -0.01:
            status, verdict = "fara_avantaj", (
                f"Modelul nimereste {best['accuracy']*100:.1f}% (interval real "
                f"{ci[0]*100:.0f}–{ci[1]*100:.0f}%), MAI PUTIN decat cele "
                f"{baseline['accuracy']*100:.1f}% pe care le-ai obtine apasand mereu pe "
                f"culoarea cea mai frecventa. Combinatiile care par sa se repete l-au "
                f"dus in eroare -- exact asta face hazardul cu un model care cauta tipare.")
        elif delta <= 0.01 or p_value >= 0.05:
            status, verdict = "fara_avantaj", (
                f"Modelul nimereste {best['accuracy']*100:.1f}% (interval real "
                f"{ci[0]*100:.0f}–{ci[1]*100:.0f}%), fata de {baseline['accuracy']*100:.1f}% "
                f"cat obtii apasand mereu pe culoarea cea mai frecventa. "
                f"Diferenta de {delta*100:+.1f} puncte nu depaseste norocul "
                f"(p = {p_value:.3f}). Combinatiile care par sa se repete nu au produs "
                f"inca niciun avantaj masurabil.")
        else:
            status, verdict = "avantaj", (
                f"Modelul nimereste {best['accuracy']*100:.1f}% (interval real "
                f"{ci[0]*100:.0f}–{ci[1]*100:.0f}%), fata de {baseline['accuracy']*100:.1f}% "
                f"baseline -- un avantaj de {delta*100:+.1f} puncte, p = {p_value:.4f}. "
                f"Modelul a invatat ceva real din combinatiile din istoric.")

        return {
            "symbol": pick, "label": label,
            "probabilities": {k: round(v, 6) for k, v in dist.items()},
            "confidence": dist[pick],
            "model": best["name"], "model_key": best["key"],
            "n_evaluated": n,
            "accuracy": best["accuracy"], "accuracy_ci": ci,
            "baseline_accuracy": baseline["accuracy"],
            "accuracy_delta": delta, "p_value": p_value,
            "status": status, "verdict": verdict,
            "leaderboard": board,
            "recent": self.log[-40:],
            "context": self.context_evidence(),
        }

    def context_evidence(self, max_order: int = 5) -> list[dict]:
        """Ce s-a intamplat istoric dupa combinatia curenta -- dovada bruta.

        Este exact intrebarea "se repeta combinatiile?", pusa pe cifre: pentru
        fiecare lungime de context, de cate ori a mai aparut si ce a urmat.
        Coloana care conteaza este numarul de aparitii: un context vazut de 3 ori
        nu spune nimic, oricat de convingator ar arata procentul.
        """
        out = []
        history = self.history
        for order in range(1, max_order + 1):
            if len(history) < order + 1:
                break
            context = tuple(history[-order:])
            following: Counter = Counter()
            for i in range(order, len(history)):
                if tuple(history[i - order:i]) == context:
                    following[history[i]] += 1
            total = sum(following.values())
            if not total:
                out.append({"order": order, "context": list(context), "occurrences": 0,
                            "following": {}, "note": "combinatia nu a mai aparut niciodata"})
                continue
            top = following.most_common(1)[0]
            # p pentru "acest simbol domina mai mult decat ar face-o frecventa lui globala"
            global_rate = history.count(top[0]) / len(history)
            p_value = binom_test(top[1], total, global_rate, "greater")
            out.append({
                "order": order, "context": list(context), "occurrences": total,
                "following": dict(following),
                "top": top[0], "top_rate": top[1] / total,
                "global_rate": global_rate, "p_value": p_value,
                "note": ("prea putine aparitii pentru orice concluzie"
                         if total < 20 else
                         "domina semnificativ" if p_value < 0.05 else
                         "nu domina mai mult decat frecventa lui generala"),
            })
        return out
