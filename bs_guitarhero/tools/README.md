# tools/

## build_chart.py

Genereaza `html/data/ichwill.json` din tab-ul Guitar Pro.

```bash
pip install pyguitarpro
python3 build_chart.py        # scrie ichwill.json in folderul curent
```

Constantele din capul fisierului sunt cele masurate pe inregistrare:

```python
BPM    = 127.99            # tempo detectat in mp3
TRIM   = 33.0188           # cat s-a taiat din fisierul original
OFFSET = 30.802 - TRIM     # unde cade masura 1 pe noua axa de timp
```

Ce face:

1. citeste pista de chitara ritmica distorsionata (Guitar 1) si, unde aceasta
   tace, foloseste basul — care canta aceeasi figura ritmica;
2. transforma fiecare acord in culoar 0–3 dupa nota cea mai inalta **si** numarul
   de coarde care suna (riff-ul alterneaza doua acorduri cu acelasi varf);
3. imparte acordurile, ordonate dupa inaltime, in 4 blocuri consecutive alese
   prin programare dinamica, ca sa incarce culoarele cat mai egal;
4. marcheaza fiecare nota cu subdiviziunea ei.

Pentru alt tab schimba `SRC`, `BPM` si `OFFSET`.

## trim_mp3.py

Taie un mp3 la limita de cadru MPEG, fara re-encodare si fara ffmpeg.

```bash
python3 trim_mp3.py sursa.mp3 iesire.mp3 33.0 244.7
```

Argumentele sunt secunda de start si (optional) secunda de final. Scriptul scrie
in consola secunda exacta a primului cadru pastrat — aia e valoarea care se scade
din `OFFSET` in `build_chart.py`.

## build_chart_audio.py

Chart doar din inregistrare, cand nu exista tab Guitar Pro. Folosit pentru
*O Mie De Pahare*.

Notele cad pe optimile pe care se aude efectiv o lovitura, iar bataile vin din
`beat_track.py`, deci merg si pe piese cu tempo variabil. Culoarele urmeaza
accentele si se rotesc pe fraze de 4 masuri — **nu** sunt acordurile reale.

Constante de reglat in capul fisierului: `TRIM` (cat s-a taiat din original),
`START` / `END`, si percentilele `FLOOR` / `OFFBEAT` care decid cat de dese ies
notele.

## beat_track.py

Beat tracking cu programare dinamica (stil Ellis 2007). Il folosesti cand
autocorelatia da un tempo care nu se lipeste de toata piesa — semn ca
inregistrarea accelereaza sau incetineste. Scrie `beats3.npy`, lista de batai in
secunde, pe care `build_chart_audio.py` o ia mai departe.
