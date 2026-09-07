# Metodologie

## Intrebarea de cercetare

> Avem o secventa de rezultate. Ce dovezi avem ca este generata de un proces predictibil?

Nu "cum prezicem urmatorul rezultat", ci intai daca se poate. Ordinea conteaza:
raspunsul la a doua intrebare este lipsit de sens daca prima nu a fost pusa.

## Trei capcane, si cum le evita acest proiect

### 1. Comparatii multiple

Fiecare test are ~5% sansa de fals pozitiv. Zece teste independente au ~40% sansa
ca **macar unul** sa "gaseasca" un tipar inexistent. Un tool care ruleaza 50 de
cautari de tipare si raporteaza castigatorul gaseste garantat ceva, pe orice date.

**Solutie:** o singura corectie Benjamini-Hochberg peste toata bateria, plus
statistici de tip maxim (ex. "cea mai mare abatere pe toate decalajele") care
corecteaza intrinsec pentru cate ipoteze s-au incercat.

### 2. Aproximatii invalide pe esantioane mici

Statistica hi-patrat presupune frecvente asteptate de cel putin 5 pe celula.
Cu Verde aparand de 5 ori in 39 de rotiri, p-ul asimptotic este pur si simplu gresit.

**Solutie:** teste de permutare peste tot unde ipotezele nu tin. Ipoteza nula
este "aceleasi simboluri, aceleasi frecvente, alta ordine" — exact intrebarea
"exista structura temporala?", fara nicio aproximatie.

### 3. Suprapotrivire pe propriile date

Orice model gaseste tipare in datele pe care a fost construit. Increderea
calculata pe aceleasi date pe care s-a antrenat modelul nu inseamna nimic.

**Solutie:** backtesting walk-forward. La pasul `t` modelul vede exact `values[:t]`.
Exista un test automat (`test_no_lookahead_leakage`) care modifica viitorul si
verifica faptic ca predictiile trecute raman neschimbate.

---

## Bateria de analize

| Test | Metoda | Ipoteza nula | Ce ar insemna respingerea |
|---|---|---|---|
| Distributia rezultatelor | hi-patrat GOF (+ Monte Carlo daca frecventele sunt mici) | simboluri echiprobabile | bias de frecventa (**nu** predictibilitate) |
| Model de ruleta | hi-patrat contra 18/18/1, 18/18/2, uniform, custom | jocul simuleaza o roata fizica | jocul foloseste praguri proprii pe `random()` |
| Testul seriilor | Wald-Wolfowitz prin permutare | rotiri independente | grupare/alternanta anormala |
| Autocorelatie | abatere maxima a ratei de coincidenta, decalaje 1..40 | fara memorie | rezultatul depinde de cel de acum k pasi |
| Dependenta Markov | raport de verosimilitate G + selectie BIC | fara memorie | contextul influenteaza rezultatul |
| Entropie | entropie conditionata + corectie Miller-Madow + compresie zlib | fara informatie in istoric | istoricul reduce incertitudinea |
| Sub-siruri repetate | cel mai lung fragment repetat, prin permutare | repetari la nivel de hazard | ciclu real sau perioada scurta |
| Periodicitate | periodograma, maxim pe perioade 2..40 si pe simboluri | fara componenta periodica | lista pre-generata sau perioada de generator |
| Pozitie in secventa | hi-patrat pe index modulo m + trend Cochran-Armitage | pozitia nu conteaza | "a n-a rotire e mereu X" sau deriva in timp |
| Resetari | CUSUM + hi-patrat pe sesiuni + prefixe comune + ora + pauze | comportament stabil | seed reinitializat previzibil |

Fiecare analizor raporteaza patru lucruri separat, pentru ca sunt lucruri diferite:
**statistica** (cat de mare e efectul), **p-value** (cat de des il produce hazardul),
**marimea efectului** (cat conteaza practic) si **puterea** (daca esantionul putea
decide). Un esantion prea mic da verdictul "date insuficiente", niciodata
"nu exista tipar" — absenta dovezii nu e dovada absentei.

## Corectia de bias a entropiei

Entropia estimata dintr-un esantion este sistematic **subestimata**, ceea ce creeaza
iluzia de predictibilitate exact acolo unde datele sunt putine. Corectia Miller-Madow
adauga `(m-1)/(2n·ln2)` biti, unde `m` este numarul de celule nenule. Diferenta dintre
castigul brut si cel corectat este vizibila in raport si este, singura, o lectie utila.

## Backtesting

```
pentru t de la warmup la n-1:
    distributie = model.prezice(values[:t])       # vede DOAR trecutul
    pierdere[t] = -log2(distributie[values[t]])   # surpriza, in biti
    model.observa(values[t])                      # abia acum afla rezultatul
```

`warmup` este 30% din date, intre 30 si 200 de rotiri. Toate modelele sunt evaluate
pe exact aceleasi pozitii (verificat automat).

### De ce log-loss si nu acuratete

- Acuratetea ignora increderea: "Rosu 51%" si "Rosu 99%" primesc acelasi punctaj.
- Acuratetea e inselatoare pe clase dezechilibrate: cu 49% Rosu, un model care
  spune mereu "Rosu" obtine 49% si pare ca functioneaza.
- Log-loss se masoara in biti si se compara direct cu limita informatiei disponibile.

Reperele: hazard pur pe 3 simboluri = 1.585 biti. Frecventa empirica = entropia
marginala. Un model care nu coboara sub al doilea nu a invatat nimic.

Acuratetea ramane raportata pentru ca e intuitiva — dar nu ea decide.

### Testul de semnificatie

Diferentele de log-loss per rotire, intre model si baseline, sunt perechi pe
aceleasi rotiri. Testul prin **inversarea semnelor** nu presupune normalitate si
respecta imperecherea. Rezultatul e corectat Bonferroni pentru numarul de modele
incercate — fara asta, cu destule modele, unul pare mereu semnificativ.

## Identificarea PRNG: bugetul informational

Ca sa determini o stare de B biti ai nevoie de cel putin B biti de observatii.
Nicio metoda nu ocoleste asta.

| Ce inregistrezi | Biti/rotire | MT19937 (19937 biti) | LCG 32 biti |
|---|---|---|---|
| Culoarea | ~1.4 | ≥14.000 rotiri, si tot nerezolvabil algebric | ~40 rotiri |
| Numarul slotului (0–36) | ~5.2 | ~3.850 rotiri consecutive | ~15 rotiri |

**Atacuri implementate si testate:**

1. **LCG algebric** — din `x2-x1 = a(x1-x0) mod m` rezulta `a` prin invers modular.
   Exact, instantaneu, dar cere output-uri **brute**.
2. **MT19937 prin inversarea temperarii** — temperarea e bijectiva, deci 624 de
   output-uri complete reconstruiesc integral starea. Implementarea e validata
   contra `random.Random` din CPython, bit cu bit.
3. **Cautare de seed** — peste (generator × mapare × decalaj). Fezabila doar daca
   seed-ul vine din ceas: o zi are 86.400 de valori in secunde, fata de 4 miliarde
   pentru un seed arbitrar de 32 de biti.

**Probabilitatea potrivirii false** este raportata mereu. Daca incerci 10 milioane
de seed-uri pe 10 culori, **vei** gasi unul care se potriveste, si nu inseamna nimic.
Formula: `incercari × 2^(-n × biti_per_rotire)`.

## Reproductibilitate

Fiecare raport contine: SHA-256 al datelor, SHA-256 al intregului cod sursa,
seed-ul aleator, versiunea Python, si comanda exacta de reproducere. Doua rulari
cu acelasi seed pe aceleasi date dau identic aceleasi p-values (test automat).
