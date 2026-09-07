# Limitele acestui proiect

Sectiune scrisa inainte de a vedea rezultatele, ca sa nu fie o rationalizare
de dupa.

## Ce nu poate face, prin constructie

**Nu poate dovedi ca ruleta este aleatoare.** Poate arata doar ca *aceste* teste,
pe *aceste* date, nu au gasit structura. Un tipar mai subtil decat sensibilitatea
testelor ramane invizibil. Concluzia corecta a unui rezultat negativ este
"nedemonstrat", nu "inexistent".

**Nu poate identifica generatorul din culori.** Culoarea transporta ~1.4 biti pe
rotire. Un MT19937 are 19937 de biti de stare, iar atacul cunoscut cere 624 de
output-uri **complete** de 32 de biti — nu biti agregati din culori. Aceasta este
o limita informationala, nu una de efort sau de destepatciune algoritmica.

**Nu poate testa serios ipoteza resetarii** fara date pe sesiuni. Daca jocul
reporneste de la un seed previzibil, singurul mod de a o detecta este sa avem
mai multe sesiuni inregistrate separat, fiecare cu primele rotiri de dupa
deschiderea jocului.

**Nu vede nimic din interiorul jocului** — nici traficul de retea, nici memoria,
nici codul. Lucreaza exclusiv cu ce ii introduci.

## Ce nu poate face, practic

**Un avantaj statistic nu este un avantaj practic.** Orice joc de acest tip are
un avantaj al casei incorporat. Un model care castiga 0.02 biti/rotire poate fi
real, semnificativ si complet inutil, pentru ca avantajul casei il depaseste.

**Rezultatele nu se transfera.** Un tipar gasit intr-o versiune a jocului poate
disparea la urmatoarea actualizare, pe alt server, sau in alt mod de joc.

**Nimic din ce iese de aici nu garanteaza un castig.** Chiar si un model cu
avantaj real confirmat greseste des; pe termen scurt, varianta domina.

## Prejudecati cognitive pe care le contracareaza explicit

**Iluzia tiparului.** Hazardul produce obligatoriu fragmente repetate, streak-uri
si simetrii. Pe cele 39 de rotiri din datele initiale, cel mai lung fragment
repetat avea 9 simboluri — iar 8% dintre secventele complet aleatoare de aceeasi
lungime contin unul cel putin la fel de lung. Testul de permutare compara mereu
cu acest reper, nu cu intuitia.

**Eroarea jucatorului.** "N-a mai iesit Verde de mult, deci urmeaza Verde" este
falsa prin definitie pentru orice proces fara memorie. Versiunea anterioara a
acestui tool avea aceasta eroare codificata intr-o functie `gap_analysis()`.
Aici nu exista niciun model bazat pe "e randul lui".

**Increderea inventata.** Un numar de incredere are voie sa existe doar daca a fost
verificat out-of-sample. Raportul include eroarea de calibrare: daca modelul afiseaza
80% dar realitatea a fost 50%, numarul afisat era o minciuna, si se vede.

## Ce s-a schimbat fata de versiunea anterioara

| Problema in `predictor.py` v2 | Cum e rezolvata |
|---|---|
| ~50 de cautari de tipare, raportat castigatorul | corectie Benjamini-Hochberg pe toata bateria |
| `calibrate_confidence()` cu constante alese la ochi | increderea vine din backtesting, nu din formule inventate |
| `gap_analysis()` = eroarea jucatorului | eliminata |
| `detect_cycle()` ancorat la indexul 0 | analiza spectrala, gaseste cicluri oriunde ar incepe |
| bug in `find_repeating_sequences`: `next_idx < len - seq_len` arunca potriviri | Markov de ordin variabil cu backoff, fara pierderi |
| nicio iesire "nu stiu" | poarta de evidenta cu 5 conditii |
| nicio masuratoare out-of-sample | backtesting walk-forward + test de scurgere de date |

## Onestitate despre datele initiale

Cele 39 de rotiri din `history.json`:

- acuratetea tool-ului vechi: 19/36 = 52.8%, fata de 48.7% obtinut apasand mereu
  pe Rosu — diferenta are p = 0.74, adica zero dovada;
- 6 din 10 analizoare nu au putut rula deloc din lipsa de date;
- singurele rezultate semnificative privesc **frecventa** culorilor, nu
  predictibilitatea lor;
- Verde apare in 12.8% din rotiri, incompatibil cu o ruleta europeana standard
  (2.7%) la p = 0.003 — asta e o descoperire reala de reverse engineering despre
  cum e construit jocul, dar nu ajuta la predictie.
