# Roulette Lab

Instrument educational pentru analiza unei secvente de ruleta din jocul *How to Fish*:
**invata din rezultatele pe care i le introduci si iti spune culoarea urmatoare** —
impreuna cu acuratetea lui reala, masurata cinstit.

Zero dependinte externe. Ruleaza pe Python 3.9+ si offline.

---

## Pornire rapida

**Cea mai simpla cale — fara terminal:**

| Sistem | Dublu-click pe |
|---|---|
| Windows | `START-WINDOWS.bat` |
| macOS / Linux | `start-mac-linux.command` |

Se deschide singur in browser pe `http://127.0.0.1:8000`. Apesi o culoare,
primesti instant urmatoarea. Lasi fereastra neagra deschisa cat timp folosesti
aplicatia; ca sa opresti, o inchizi.

Ai nevoie doar de Python 3.9+ instalat ([python.org/downloads](https://www.python.org/downloads/) —
pe Windows bifeaza **„Add Python to PATH"** la instalare). Nimic altceva: fara pip,
fara librarii.

**Din terminal**, daca preferi:

```bash
cd roulette-lab
python3 -m roulette_lab serve
```

Din linia de comanda:
```bash
python3 -m roulette_lab add R N V R R      # adauga rezultate
python3 -m roulette_lab predict            # ce urmeaza + cat de mult merita crezut
python3 -m roulette_lab analyze -v         # bateria de teste statistice
python3 -m roulette_lab backtest           # cat de bine ar fi mers pe trecut
python3 -m roulette_lab prng               # se poate identifica generatorul?
python3 -m roulette_lab report             # raport complet, reproductibil
```

## Verifica singur ca instrumentul functioneaza

Nu ma crede pe cuvant. Genereaza date unde adevarul e cunoscut si vezi ce face:

```bash
python3 -m roulette_lab demo                                  # 4 seturi de test
python3 -m roulette_lab predict --data data/demo/demo-markov.json   # TREBUIE sa prezica
python3 -m roulette_lab predict --data data/demo/demo-aleator.json  # TREBUIE sa refuze
python3 -m roulette_lab prng    --data data/demo/demo-lcg.json      # TREBUIE sa afle seed-ul
python3 -m unittest discover -s tests                         # 50+ teste automate
```

| Set de date | Adevarul | Ce face instrumentul |
|---|---|---|
| `demo-markov` | dependenta reala intre rotiri | prezice, 70.2% vs 42.5% baseline |
| `demo-ciclu` | ciclu de perioada 7 | gaseste perioada 7 prin analiza spectrala |
| `demo-lcg` | LCG cu seed din ceas | **recupereaza seed-ul exact** din culori |
| `demo-aleator` | hazard pur | refuza sa prezica |

Ultimul rand este cel important: un instrument care "prezice" si pe date aleatoare
nu prezice nimic, niciodata — doar arata convingator.

---

## Cum functioneaza

### Modul live — ce vezi cand joci

Motorul tine minte ce a urmat istoric dupa fiecare combinatie de lungime 1–5 si
recomanda culoarea cea mai probabila. Cost per rotire noua: sub 1 milisecunda,
si dupa mii de rezultate.

Acuratetea afisata este **imposibil de umflat**: fiecare predictie e facuta
inainte ca rezultatul sa fie cunoscut, apoi comparata cu realitatea. Langa ea
apare mereu si baseline-ul — cat ai obtine apasand mereu pe culoarea cea mai
frecventa. Doar diferenta dintre cele doua conteaza.

### Cele doua straturi

| Strat | Rol |
|---|---|
| **Analiza** (`analysis/`) | 10 teste independente. Gaseste mereu ceva — asta e natura ei. |
| **Decizia** (`decide/`) | Are drept de veto. Aproba o predictie doar daca trece 5 conditii. |

Separarea exista pentru ca hazardul pur produce obligatoriu tipare. Un tool care
n-are strat de decizie confunda zgomotul cu mecanismul — exact ce s-a intamplat
cu versiunea anterioara.

### Cele 5 conditii ale portii

1. **Volum**: minim 200 de rotiri.
2. **Bate modelul fara memorie** pe rotiri nevazute la antrenare.
3. **Castig ≥ 0.01 biti/rotire** — separa "exista" de "conteaza".
4. **Intervalul de incredere 95%** complet peste zero.
5. **p corectat < 0.01** dupa corectie pentru numarul de modele incercate.

Daca oricare pica, poarta refuza — dar culoarea cea mai probabila ti se arata
oricum, cu acuratetea ei reala alaturi.

---

## Structura

```
roulette_lab/
  stats/       chi-patrat, binomial, permutari, bootstrap, Benjamini-Hochberg
  data/        schema Spin + import/export CSV/TXT/JSON + migrare din tool-ul vechi
  analysis/    10 analizoare (frecventa, serii, autocorelatie, Markov, entropie,
               repetitii, periodicitate, pozitie, resetari, model de roata)
  prng/        LCG, Xorshift, PCG, MT19937 + atacuri reale + buget informational
  models/      baseline, Markov, ordin variabil, ansamblu cu ponderi exponentiale
  backtest/    walk-forward prequential + log-loss, Brier, calibrare, precizie/recall
  decide/      poarta de evidenta
  live.py      motorul online (raspuns instant)
  report/      raport Markdown + JSON cu amprenta SHA-256 a datelor si a codului
  server.py    API stdlib + interfata web
```

Modular prin design: un analizor nou = un fisier cu `@register("cheie")`.
Un model nou = o clasa cu `predict()` si `make_state()`. Nimic altceva nu se atinge.

## Formatul de colectare

CSV, coloana `value` obligatorie, restul optionale dar valoroase:

```csv
index,value,ts,session
0,R,1700000000,sesiune-1
1,N,1700000012,sesiune-1
2,V,1700000025,sesiune-1
```

- **`value`** — `R`/`N`/`V`, sau `rosu`/`negru`/`verde`. **Daca jocul afiseaza si
  numarul slotului, inregistreaza numarul** (`--preset roulette37`): contine de
  ~4 ori mai multa informatie decat culoarea.
- **`ts`** — momentul rotirii. Necesar pentru a testa ipoteza "seed derivat din ceas",
  singurul mecanism realist prin care o ruleta software devine predictibila.
- **`session`** — id nou la fiecare repornire a jocului. Necesar pentru a detecta
  daca secventa se reia dupa restart.

Se accepta si TXT simplu: `RRNVRN` sau `R,N,V,R`.

## Cate rotiri sunt necesare

| Obiectiv | Rotiri |
|---|---|
| Distributia culorilor | ~150 |
| Dependenta intre rotiri consecutive (efect mediu) | ~350 |
| Prag minim pentru orice predictie aprobata | 200 |
| Dependenta de ordin 2 sau efecte mici | 1500–3000 |
| Identificarea unui LCG pe 32 de biti prin cautare de seed | ~40 (cu timestamp) |
| Recuperarea starii MT19937 | 624 output-uri **brute** — imposibil din culori |

## Documentatie

- [`docs/METODOLOGIE.md`](docs/METODOLOGIE.md) — fiecare test, ce masoara, cum se citeste
- [`docs/LIMITE.md`](docs/LIMITE.md) — ce nu poate face acest instrument, si de ce

## Licenta si scop

Proiect educational, pentru studiul metodelor statistice si de reverse engineering.
