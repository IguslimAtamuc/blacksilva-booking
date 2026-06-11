# PAPATRON OPTIMIZER

Task manager + optimizator + scaner antivirus pentru Windows, cu interfata
Dark Theme cu rosu.

## Cum il pornesti (1 pas)

1. Dezarhiveaza ZIP-ul oriunde (de ex. pe Desktop).
2. Dublu-click pe **START.bat** si apasa **Da** cand cere drepturi de Administrator.

Atat. Prima pornire instaleaza automat Python si bibliotecile necesare
(dureaza 1-2 minute, ai nevoie de internet doar prima data). Apoi aplicatia
porneste instant.

> Daca Windows SmartScreen intreaba, apasa "More info" -> "Run anyway".
> Scriptul doar instaleaza Python oficial si porneste aplicatia.

## Ce stie sa faca

### MONITOR
- Vede tot ce ruleaza pe calculator (aplicatii, jocuri, procese).
- Iti arata simplu cine consuma mult: **rosu = mare**, galben = mediu,
  albastru = proces de sistem (protejat, nu-l poti inchide din greseala).
- Bare live pentru sarcina totala: CPU, RAM, DISC.
- Poti inchide direct procesul selectat.

### OPTIMIZARE
1. Alegi jocul / aplicatia pe care vrei sa o folosesti (de ex. jocul tau sau Chrome).
2. Bifezi aplicatiile inutile pe care vrei sa le inchida.
3. Apesi **OPTIMIZEAZA!** si aplicatia:
   - pune jocul tau pe **prioritate MARE** la procesor;
   - inchide aplicatiile bifate;
   - activeaza planul de alimentare **High Performance**;
   - elibereaza RAM din procesele de fundal.
- Butonul **Restaureaza setarile normale** aduce totul la loc cand termini.

### ANTIVIRUS
- Foloseste motorul **real Windows Defender** (cel din Windows) — nu un antivirus
  inventat: scanare rapida, scanare completa, actualizare semnaturi.
- Iti arata pe intelesul tau ce virusi a gasit si ii poti **sterge cu un click**
  (butonul STERGE TOTI VIRUSII GASITI).
- **Cauta keyloggere (euristic)**: verifica procesele cu nume suspecte sau care
  ruleaza din locatii folosite de malware si iti recomanda scanarea lor.

## Important de stiut

- Aplicatia e facuta pentru **Windows 10/11**.
- Porneste-o mereu ca **Administrator** (START.bat face asta singur) — altfel
  stergerea virusilor si schimbarea prioritatilor pot fi refuzate de Windows.
- Procesele critice de Windows sunt protejate: aplicatia refuza sa le inchida.
- Inchiderea unei aplicatii pierde datele nesalvate din ea — aplicatia te
  intreaba mereu inainte.

## Pornire manuala (optional, daca ai deja Python)

```
pip install -r requirements.txt
python PAPATRON_OPTIMIZER.py
```
