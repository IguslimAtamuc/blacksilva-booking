"""Contractul comun al analizoarelor + registrul de plugin-uri.

Fiecare analizor raspunde la EXACT o intrebare, si raporteaza patru lucruri
separat, pentru ca ele chiar sunt lucruri diferite:

  1. statistica  -- cat de mare e efectul masurat;
  2. p-value     -- cat de des produce hazardul pur un efect cel putin la fel;
  3. marimea efectului -- cat conteaza practic (un p mic pe 100.000 de rotiri
     poate insemna un efect complet inutilizabil);
  4. puterea     -- daca esantionul e prea mic, verdictul e "date insuficiente",
     NU "nu exista tipar". Absenta dovezii nu e dovada absentei.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Protocol

from ..data.schema import Dataset
from ..stats.tests import benjamini_hochberg

# Verdicte posibile, in ordinea puterii dovezii.
INSUFFICIENT = "insuficient"      # esantionul nu poate decide -- nici intr-un sens, nici in altul
NO_EVIDENCE = "fara_dovada"       # compatibil cu hazardul pur
WEAK = "slab"                     # sugestie, sub pragul de decizie
EVIDENCE = "dovada"               # efect care supravietuieste corectiei pentru teste multiple

VERDICT_LABELS = {
    INSUFFICIENT: "Date insuficiente",
    NO_EVIDENCE: "Fara dovada",
    WEAK: "Semnal slab",
    EVIDENCE: "Dovada",
}


@dataclass
class AnalysisResult:
    key: str
    title: str
    question: str                       # intrebarea la care raspunde, in romana
    statistic: float = 0.0
    statistic_name: str = "stat"
    p_value: float = 1.0
    p_method: str = "asymptotic"
    df: int | None = None
    effect: float = 0.0
    effect_name: str = "efect"
    effect_note: str = ""
    n_used: int = 0
    min_n: int = 0                      # esantionul minim pentru ca testul sa fie interpretabil
    recommended_n: int = 0              # esantionul pentru putere ~80% la un efect moderat
    verdict: str = NO_EVIDENCE
    q_value: float | None = None        # p corectat Benjamini-Hochberg (completat de registru)
    explanation: str = ""
    warnings: list[str] = field(default_factory=list)
    detail: dict = field(default_factory=dict)
    applicable: bool = True
    skip_reason: str = ""

    def finalize(self, alpha: float = 0.05) -> None:
        """Stabileste verdictul folosind q-value (nu p brut) si puterea testului."""
        q = self.q_value if self.q_value is not None else self.p_value
        if not self.applicable:
            self.verdict = INSUFFICIENT
        elif self.n_used < self.min_n:
            self.verdict = INSUFFICIENT
        elif q < alpha:
            self.verdict = EVIDENCE
        elif q < 2 * alpha:
            self.verdict = WEAK
        else:
            self.verdict = NO_EVIDENCE
        # Un rezultat "fara dovada" pe un esantion sub pragul recomandat este
        # neconcludent, nu negativ. Marcam explicit ca sa nu fie citit gresit.
        if self.verdict == NO_EVIDENCE and self.recommended_n and self.n_used < self.recommended_n:
            self.warnings.append(
                f"Esantion sub pragul recomandat ({self.n_used} < {self.recommended_n}): "
                "un tipar real de marime moderata ar ramane nedetectat. "
                "Rezultatul inseamna 'nedemonstrat', nu 'inexistent'."
            )

    def to_dict(self) -> dict:
        d = {
            "key": self.key, "title": self.title, "question": self.question,
            "statistic": round(self.statistic, 6), "statistic_name": self.statistic_name,
            "p_value": round(self.p_value, 6), "p_method": self.p_method, "df": self.df,
            "effect": round(self.effect, 6), "effect_name": self.effect_name,
            "effect_note": self.effect_note,
            "n_used": self.n_used, "min_n": self.min_n, "recommended_n": self.recommended_n,
            "verdict": self.verdict, "verdict_label": VERDICT_LABELS[self.verdict],
            "q_value": None if self.q_value is None else round(self.q_value, 6),
            "explanation": self.explanation, "warnings": list(self.warnings),
            "detail": self.detail, "applicable": self.applicable,
            "skip_reason": self.skip_reason,
        }
        return d


class Analyzer(Protocol):
    """Un analizor este orice callable Dataset -> AnalysisResult."""

    key: str

    def __call__(self, ds: Dataset, **kwargs) -> AnalysisResult: ...


_REGISTRY: dict[str, Callable[..., AnalysisResult]] = {}
_ORDER: list[str] = []


def register(key: str):
    """Decorator de inregistrare. Un analizor nou = un fisier + acest decorator."""
    def wrap(fn):
        _REGISTRY[key] = fn
        if key not in _ORDER:
            _ORDER.append(key)
        fn.key = key
        return fn
    return wrap


def available() -> list[str]:
    return list(_ORDER)


def skipped(key: str, title: str, question: str, reason: str,
            min_n: int = 0, n_used: int = 0) -> AnalysisResult:
    return AnalysisResult(key=key, title=title, question=question, applicable=False,
                          skip_reason=reason, min_n=min_n, n_used=n_used,
                          explanation=reason, verdict=INSUFFICIENT)


@dataclass
class AnalysisReport:
    results: list[AnalysisResult]
    alpha: float
    n: int
    fingerprint: str

    @property
    def significant(self) -> list[AnalysisResult]:
        return [r for r in self.results if r.verdict == EVIDENCE]

    @property
    def tested(self) -> list[AnalysisResult]:
        return [r for r in self.results if r.applicable]

    def summary(self) -> str:
        """Concluzia in limbaj natural, calibrata dupa cat de multe date exista."""
        strong = self.significant
        weak = [r for r in self.results if r.verdict == WEAK]
        untested = [r for r in self.results if not r.applicable or r.n_used < r.min_n]
        parts = [f"Am rulat {len(self.tested)} teste pe {self.n} rotiri "
                 f"(corectie Benjamini-Hochberg pentru teste multiple, alfa={self.alpha})."]
        if strong:
            parts.append("Dovezi care supravietuiesc corectiei: "
                         + "; ".join(f"{r.title} (q={r.q_value:.4f})" for r in strong) + ".")
        else:
            parts.append("Niciun test nu produce o dovada care sa supravietuiasca "
                         "corectiei pentru teste multiple.")
        if weak:
            parts.append("Semnale slabe, de reverificat cu mai multe date: "
                         + ", ".join(r.title for r in weak) + ".")
        if untested:
            parts.append(f"{len(untested)} teste nu au putut fi rulate din lipsa de date.")
        if self.n < 500:
            parts.append(
                f"ATENTIE: cu {self.n} rotiri, chiar si un tipar real de marime moderata "
                "ar ramane invizibil. Concluzia corecta la acest volum este "
                "'nedemonstrat', nu 'ruleta e aleatoare'."
            )
        return " ".join(parts)

    def to_dict(self) -> dict:
        return {
            "n": self.n, "alpha": self.alpha, "fingerprint": self.fingerprint,
            "summary": self.summary(),
            "results": [r.to_dict() for r in self.results],
            "counts": {
                "evidence": len(self.significant),
                "weak": sum(1 for r in self.results if r.verdict == WEAK),
                "no_evidence": sum(1 for r in self.results if r.verdict == NO_EVIDENCE),
                "insufficient": sum(1 for r in self.results if r.verdict == INSUFFICIENT),
            },
        }


def run_all(ds: Dataset, alpha: float = 0.05, seed: int = 12345,
            keys: list[str] | None = None) -> AnalysisReport:
    """Ruleaza bateria de analize si aplica O SINGURA corectie globala.

    Corectia globala este esentiala: fiecare test in parte are 5% sansa de
    fals pozitiv, deci 9 teste independente au ~37% sansa ca macar unul sa
    "gaseasca" un tipar inexistent.
    """
    from . import loader  # noqa: F401  (importa si inregistreaza analizoarele)

    selected = keys or _ORDER
    results: list[AnalysisResult] = []
    for key in selected:
        fn = _REGISTRY.get(key)
        if fn is None:
            continue
        try:
            results.append(fn(ds, seed=seed))
        except Exception as exc:  # un analizor stricat nu are voie sa opreasca raportul
            results.append(skipped(key, key, "-", f"Analizorul a esuat: {exc}"))

    testable = [r for r in results if r.applicable and r.n_used >= r.min_n]
    qs = benjamini_hochberg([r.p_value for r in testable])
    for r, q in zip(testable, qs):
        r.q_value = q
    for r in results:
        r.finalize(alpha)
    return AnalysisReport(results, alpha, len(ds), ds.fingerprint())
