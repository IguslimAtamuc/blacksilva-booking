"""Distributii statistice implementate pur in stdlib.

Nu folosim scipy pentru ca proiectul trebuie sa ruleze oriunde exista Python 3.9+.
Toate functiile sunt validate in tests/test_stats.py contra valorilor de referinta.
"""
from __future__ import annotations

import math

_EPS = 1e-15
_MAXIT = 500


# --------------------------------------------------------------------------
# Functia gamma incompleta -> chi-patrat
# --------------------------------------------------------------------------
def _gamma_p_series(a: float, x: float) -> float:
    """P(a, x) prin dezvoltare in serie (converge rapid pentru x < a+1)."""
    if x <= 0:
        return 0.0
    total = 1.0 / a
    term = total
    ap = a
    for _ in range(_MAXIT):
        ap += 1.0
        term *= x / ap
        total += term
        if abs(term) < abs(total) * _EPS:
            break
    return total * math.exp(-x + a * math.log(x) - math.lgamma(a))


def _gamma_q_continued_fraction(a: float, x: float) -> float:
    """Q(a, x) prin fractie continua (converge rapid pentru x >= a+1)."""
    tiny = 1e-300
    b = x + 1.0 - a
    c = 1.0 / tiny
    d = 1.0 / b
    h = d
    for i in range(1, _MAXIT):
        an = -i * (i - a)
        b += 2.0
        d = an * d + b
        if abs(d) < tiny:
            d = tiny
        c = b + an / c
        if abs(c) < tiny:
            c = tiny
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < _EPS:
            break
    return h * math.exp(-x + a * math.log(x) - math.lgamma(a))


def gamma_q(a: float, x: float) -> float:
    """Functia gamma incompleta superioara regularizata Q(a, x) = 1 - P(a, x)."""
    if x < 0 or a <= 0:
        raise ValueError("gamma_q necesita a > 0 si x >= 0")
    if x == 0:
        return 1.0
    if x < a + 1.0:
        return 1.0 - _gamma_p_series(a, x)
    return _gamma_q_continued_fraction(a, x)


def chi2_sf(x: float, df: float) -> float:
    """P(X > x) pentru X ~ chi-patrat cu df grade de libertate."""
    if df <= 0:
        return 1.0
    if x <= 0:
        return 1.0
    return max(0.0, min(1.0, gamma_q(df / 2.0, x / 2.0)))


# --------------------------------------------------------------------------
# Functia beta incompleta -> binomial, Student t
# --------------------------------------------------------------------------
def _betacf(a: float, b: float, x: float) -> float:
    tiny = 1e-300
    qab, qap, qam = a + b, a + 1.0, a - 1.0
    c = 1.0
    d = 1.0 - qab * x / qap
    if abs(d) < tiny:
        d = tiny
    d = 1.0 / d
    h = d
    for m in range(1, _MAXIT):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        if abs(d) < tiny:
            d = tiny
        c = 1.0 + aa / c
        if abs(c) < tiny:
            c = tiny
        d = 1.0 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        if abs(d) < tiny:
            d = tiny
        c = 1.0 + aa / c
        if abs(c) < tiny:
            c = tiny
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < _EPS:
            break
    return h


def betainc(a: float, b: float, x: float) -> float:
    """Functia beta incompleta regularizata I_x(a, b)."""
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 1.0
    front = math.exp(
        math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
        + a * math.log(x) + b * math.log(1.0 - x)
    )
    if x < (a + 1.0) / (a + b + 2.0):
        return front * _betacf(a, b, x) / a
    return 1.0 - math.exp(
        math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
        + b * math.log(1.0 - x) + a * math.log(x)
    ) * _betacf(b, a, 1.0 - x) / b


# --------------------------------------------------------------------------
# Normala
# --------------------------------------------------------------------------
def norm_cdf(z: float) -> float:
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


def norm_sf(z: float) -> float:
    return 1.0 - norm_cdf(z)


def norm_two_sided(z: float) -> float:
    return 2.0 * norm_sf(abs(z))


def norm_ppf(p: float) -> float:
    """Inversa CDF normale (algoritmul Acklam, eroare < 1.15e-9)."""
    if not 0.0 < p < 1.0:
        raise ValueError("norm_ppf necesita 0 < p < 1")
    a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
         1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
    b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
         6.680131188771972e+01, -1.328068155288572e+01]
    c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
         -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
    d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
         3.754408661907416e+00]
    plow, phigh = 0.02425, 1 - 0.02425
    if p < plow:
        q = math.sqrt(-2 * math.log(p))
        return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / \
               ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
    if p > phigh:
        q = math.sqrt(-2 * math.log(1 - p))
        return -(((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / \
                ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
    q = p - 0.5
    r = q * q
    return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5]) * q / \
           (((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)


# --------------------------------------------------------------------------
# Binomial
# --------------------------------------------------------------------------
def binom_pmf(k: int, n: int, p: float) -> float:
    if k < 0 or k > n:
        return 0.0
    if p <= 0.0:
        return 1.0 if k == 0 else 0.0
    if p >= 1.0:
        return 1.0 if k == n else 0.0
    log_pmf = (math.lgamma(n + 1) - math.lgamma(k + 1) - math.lgamma(n - k + 1)
               + k * math.log(p) + (n - k) * math.log1p(-p))
    return math.exp(log_pmf)


def binom_sf(k: int, n: int, p: float) -> float:
    """P(X > k) = I_p(k+1, n-k)."""
    if k >= n:
        return 0.0
    if k < 0:
        return 1.0
    return betainc(k + 1, n - k, p)


def binom_cdf(k: int, n: int, p: float) -> float:
    return 1.0 - binom_sf(k, n, p)
