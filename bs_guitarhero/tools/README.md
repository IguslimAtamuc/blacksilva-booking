# tools/build_chart.py

Scriptul cu care a fost generat `html/data/faint.json` din tab-ul Guitar Pro.

```bash
pip install pyguitarpro
python3 build_chart.py        # scrie chart.json in folderul curent
```

Constantele din capul fisierului sunt cele masurate pe mp3-ul livrat:

```python
BPM    = 135.03   # tempo detectat in inregistrare
OFFSET = 0.823    # secunda la care incepe masura 1 in mp3
```

Ce face scriptul:

1. desface repetitiile si casutele de final (1./2.) din `.gp4` — ies 91 de masuri,
   adica exact 162.56 s la 135.03 BPM, cat tine si inregistrarea;
2. ia notele din pista de chitara solo, iar unde aceasta tace foloseste clapele
   sau chitara ritmica;
3. transforma inaltimea reala a fiecarui acord in culoar 0–4, echilibrand
   culoarele dupa cat de des apare fiecare inaltime;
4. marcheaza fiecare nota cu subdiviziunea ei, ca sa se poata filtra pe dificultati.

Pentru alt tab schimba `SRC`, `BPM` si `OFFSET`.
