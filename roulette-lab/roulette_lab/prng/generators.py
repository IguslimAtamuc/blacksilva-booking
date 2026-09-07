"""Implementari ale generatoarelor candidate.

Toate sunt scrise de la zero ca sa putem si sa le rulam inainte, si sa le
inversam. Un generator este descris de: dimensiunea starii, functia de avans
si (unde exista) atacul de recuperare a starii.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterator

M32 = 0xFFFFFFFF
M64 = 0xFFFFFFFFFFFFFFFF


@dataclass
class PRNGSpec:
    key: str
    name: str
    state_bits: int
    output_bits: int
    description: str
    modulus: int = 2 ** 32          # domeniul output-ului, folosit la mapare
    seedable: bool = True           # se poate initializa cu un seed intreg
    invertible: bool = False        # exista atac de recuperare a starii din output-uri
    outputs_needed: int = 0         # cate output-uri complete cere atacul (0 = nu se aplica)
    where_used: str = ""


# --------------------------------------------------------------------------
# LCG -- generatoare congruentiale liniare
# --------------------------------------------------------------------------
LCG_PARAMS: dict[str, tuple[int, int, int, str]] = {
    # nume: (multiplicator a, increment c, modul m, unde e folosit)
    "glibc_rand":       (1103515245, 12345, 2 ** 31, "glibc rand() / ANSI C"),
    "msvc_rand":        (214013, 2531011, 2 ** 31, "Microsoft Visual C++ rand()"),
    "java_random":      (0x5DEECE66D, 0xB, 2 ** 48, "java.util.Random / Android"),
    "minstd":           (16807, 0, 2 ** 31 - 1, "MINSTD / Lehmer, Park-Miller"),
    "minstd_new":       (48271, 0, 2 ** 31 - 1, "MINSTD revizuit (C++ minstd_rand)"),
    "numerical_recipes": (1664525, 1013904223, 2 ** 32, "Numerical Recipes ranqd1"),
    "borland":          (22695477, 1, 2 ** 32, "Borland C/C++ rand()"),
}


class LCG:
    """x_{n+1} = (a * x_n + c) mod m."""

    def __init__(self, a: int, c: int, m: int, seed: int):
        self.a, self.c, self.m = a, c, m
        self.state = seed % m

    def next(self) -> int:
        self.state = (self.a * self.state + self.c) % self.m
        return self.state

    def stream(self, count: int) -> list[int]:
        return [self.next() for _ in range(count)]


def make_lcg(variant: str, seed: int) -> LCG:
    a, c, m, _ = LCG_PARAMS[variant]
    return LCG(a, c, m, seed)


# --------------------------------------------------------------------------
# Xorshift
# --------------------------------------------------------------------------
class Xorshift32:
    def __init__(self, seed: int):
        self.state = (seed & M32) or 0x9E3779B9   # starea 0 e un punct fix; o evitam

    def next(self) -> int:
        x = self.state
        x ^= (x << 13) & M32
        x ^= x >> 17
        x ^= (x << 5) & M32
        self.state = x & M32
        return self.state


class Xorshift128Plus:
    """Varianta folosita ani la rand de V8 pentru Math.random() in JavaScript."""

    def __init__(self, seed: int):
        # initializare de tip splitmix64, ca in majoritatea implementarilor
        self.s0 = _splitmix64_next(seed)
        self.s1 = _splitmix64_next(self.s0)

    def next(self) -> int:
        s1, s0 = self.s0, self.s1
        self.s0 = s0
        s1 ^= (s1 << 23) & M64
        s1 ^= s1 >> 17
        s1 ^= s0
        s1 ^= s0 >> 26
        self.s1 = s1 & M64
        return (self.s0 + self.s1) & M64


def _splitmix64_next(state: int) -> int:
    state = (state + 0x9E3779B97F4A7C15) & M64
    z = state
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & M64
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & M64
    return (z ^ (z >> 31)) & M64


# --------------------------------------------------------------------------
# PCG32
# --------------------------------------------------------------------------
class PCG32:
    MULT = 6364136223846793005
    INC = 1442695040888963407

    def __init__(self, seed: int, inc: int | None = None):
        self.inc = ((inc if inc is not None else self.INC) << 1 | 1) & M64
        self.state = 0
        self.next()
        self.state = (self.state + seed) & M64
        self.next()

    def next(self) -> int:
        old = self.state
        self.state = (old * self.MULT + self.inc) & M64
        xorshifted = (((old >> 18) ^ old) >> 27) & M32
        rot = (old >> 59) & 31
        return ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & M32


# --------------------------------------------------------------------------
# Mersenne Twister MT19937 -- generatorul din Python, PHP, Ruby, C++ std
# --------------------------------------------------------------------------
class MT19937:
    N, M = 624, 397
    MATRIX_A = 0x9908B0DF
    UPPER, LOWER = 0x80000000, 0x7FFFFFFF

    def __init__(self, seed: int | None = None, state: list[int] | None = None):
        if state is not None:
            if len(state) != self.N:
                raise ValueError(f"starea MT19937 are exact {self.N} cuvinte")
            self.mt = list(state)
            self.index = self.N
        else:
            self.mt = [0] * self.N
            self.mt[0] = (seed or 0) & M32
            for i in range(1, self.N):
                self.mt[i] = (1812433253 * (self.mt[i - 1] ^ (self.mt[i - 1] >> 30)) + i) & M32
            self.index = self.N

    @classmethod
    def from_key_array(cls, key: list[int]) -> "MT19937":
        """Initializare init_by_array -- exact ce foloseste CPython pentru random.seed(n).

        Exista doua scheme de seeding standard si NU sunt echivalente:
          - init_genrand(seed)     -> C++ std::mt19937, PHP mt_srand
          - init_by_array(key[])   -> CPython random.seed(int)
        Daca tintesti un joc scris in Python, trebuie aceasta varianta.
        """
        mt = cls(19650218)
        i, j = 1, 0
        k = max(cls.N, len(key))
        while k:
            mt.mt[i] = ((mt.mt[i] ^ ((mt.mt[i - 1] ^ (mt.mt[i - 1] >> 30)) * 1664525))
                        + key[j] + j) & M32
            i += 1
            j += 1
            if i >= cls.N:
                mt.mt[0] = mt.mt[cls.N - 1]
                i = 1
            if j >= len(key):
                j = 0
            k -= 1
        k = cls.N - 1
        while k:
            mt.mt[i] = ((mt.mt[i] ^ ((mt.mt[i - 1] ^ (mt.mt[i - 1] >> 30)) * 1566083941))
                        - i) & M32
            i += 1
            if i >= cls.N:
                mt.mt[0] = mt.mt[cls.N - 1]
                i = 1
            k -= 1
        mt.mt[0] = 0x80000000
        mt.index = cls.N
        return mt

    @classmethod
    def from_python_seed(cls, seed: int) -> "MT19937":
        """Reproduce exact random.Random(seed) din CPython pentru seed intreg."""
        seed = abs(int(seed))
        key = []
        while seed:
            key.append(seed & M32)
            seed >>= 32
        return cls.from_key_array(key or [0])

    def _generate(self) -> None:
        for i in range(self.N):
            y = (self.mt[i] & self.UPPER) | (self.mt[(i + 1) % self.N] & self.LOWER)
            nxt = self.mt[(i + self.M) % self.N] ^ (y >> 1)
            if y & 1:
                nxt ^= self.MATRIX_A
            self.mt[i] = nxt
        self.index = 0

    def next(self) -> int:
        if self.index >= self.N:
            self._generate()
        y = self.mt[self.index]
        self.index += 1
        return temper(y)


def temper(y: int) -> int:
    y ^= y >> 11
    y ^= (y << 7) & 0x9D2C5680
    y ^= (y << 15) & 0xEFC60000
    y ^= y >> 18
    return y & M32


def untemper(y: int) -> int:
    """Inverseaza functia de temperare a MT19937.

    Temperarea este bijectiva, deci un output de 32 de biti se poate transforma
    inapoi in cuvantul de stare care l-a produs. Cu 624 de output-uri consecutive
    reconstruim INTEGRAL starea interna si putem prezice tot ce urmeaza -- exact.
    """
    y = _unshift_right(y, 18)
    y = _unshift_left_mask(y, 15, 0xEFC60000)
    y = _unshift_left_mask(y, 7, 0x9D2C5680)
    y = _unshift_right(y, 11)
    return y & M32


def _unshift_right(y: int, shift: int) -> int:
    result = y
    for _ in range(32 // shift + 1):
        result = y ^ (result >> shift)
    return result & M32


def _unshift_left_mask(y: int, shift: int, mask: int) -> int:
    result = y
    for _ in range(32 // shift + 1):
        result = y ^ ((result << shift) & mask)
    return result & M32


# --------------------------------------------------------------------------
# Catalogul de candidati
# --------------------------------------------------------------------------
def _lcg_factory(variant: str) -> Callable[[int], Iterator[int]]:
    def factory(seed: int):
        gen = make_lcg(variant, seed)
        while True:
            yield gen.next()
    return factory


def _wrap(cls) -> Callable[[int], Iterator[int]]:
    def factory(seed: int):
        gen = cls(seed)
        while True:
            yield gen.next()
    return factory


CATALOG: dict[str, tuple[PRNGSpec, Callable[[int], Iterator[int]]]] = {}

for _variant, (_a, _c, _m, _where) in LCG_PARAMS.items():
    _bits = (_m - 1).bit_length()
    CATALOG[_variant] = (
        PRNGSpec(key=_variant, name=f"LCG {_variant}", state_bits=_bits, output_bits=_bits,
                 description=f"x' = ({_a} * x + {_c}) mod {_m}", modulus=_m,
                 invertible=True, outputs_needed=3, where_used=_where),
        _lcg_factory(_variant),
    )

CATALOG["xorshift32"] = (
    PRNGSpec("xorshift32", "Xorshift32", 32, 32,
             "x ^= x<<13; x ^= x>>17; x ^= x<<5", modulus=2 ** 32,
             invertible=True, outputs_needed=1,
             where_used="jocuri simple, generatoare embedded"),
    _wrap(Xorshift32))

CATALOG["xorshift128plus"] = (
    PRNGSpec("xorshift128plus", "Xorshift128+", 128, 64,
             "generatorul Math.random() din V8 (Chrome/Node) pana in 2015+",
             modulus=2 ** 64, invertible=True, outputs_needed=2,
             where_used="JavaScript Math.random() in V8"),
    _wrap(Xorshift128Plus))

CATALOG["pcg32"] = (
    PRNGSpec("pcg32", "PCG32", 64, 32,
             "LCG pe 64 de biti + permutare de iesire XSH-RR", modulus=2 ** 32,
             invertible=False, outputs_needed=0,
             where_used="NumPy (implicit din 2019), Rust rand"),
    _wrap(PCG32))

CATALOG["mt19937"] = (
    PRNGSpec("mt19937", "Mersenne Twister MT19937", 19937, 32,
             "generatorul standard din Python random, PHP mt_rand, Ruby, C++ std",
             modulus=2 ** 32, invertible=True, outputs_needed=624,
             where_used="Python, PHP, Ruby, C++ std::mt19937"),
    _wrap(MT19937))
