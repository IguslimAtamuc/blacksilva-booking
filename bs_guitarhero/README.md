# bs_guitarhero — Rhythm Highway HUD

Minijoc de ritm pentru **FiveM / ESX**. `/e guitar` porneste animatia de chitara,
apoi direct **3 · 2 · 1** si melodia.

Melodii incluse:

| id | melodie |
|---|---|
| `ichwill` | Ich Will — Rammstein |
| `pahare` | O Mie De Pahare — White Mahala |

HUD-ul e un **overlay complet transparent** — se vede jocul si personajul prin el.
Se joaca din **cele 4 sageti**: `←` `↓` `↑` `→`.

---

## 1. Instalare

1. Copiaza folderul `bs_guitarhero` in `resources/`.
2. In `server.cfg`, **dupa** resursa de emote-uri:

```cfg
ensure dpemotes
ensure bs_guitarhero
```

> Ordinea conteaza. `bs_guitarhero` preia comanda `/e` si trimite mai departe la
> `/emote` orice alt emote decat `guitar`. Daca porneste inaintea lui `dpemotes`,
> emote-ul original ramane activ si jocul nu mai porneste.

3. Restart server.

## 2. Cum se joaca

| Comanda | Efect |
|---|---|
| `/e guitar` | animatie de chitara + minijoc, cu o melodie la intamplare |
| `/e guitar pahare` | o melodie anume (vezi id-urile de mai sus) |
| `/guitarhero [id]` | acelasi lucru, fara resursa de emote-uri |
| `/e <orice altceva>` | pleaca normal la `dpemotes` / `rpemotes` |

`Config.SongPick = 'first'` face ca `/e guitar` sa porneasca mereu prima melodie
din lista in loc de una la intamplare.

| Tasta | Actiune |
|---|---|
| `←` `↓` `↑` `→` | cele 4 culoare |
| `P` | pauza |
| `ESC` | iesi |
| `SPACE` | inca o tura (din ecranul de final) |
| `[` `]` | calibrare audio ±5 ms (se salveaza per client) |
| `-` `+` | volum |

**Daca notele nu par sincronizate cu sunetul**, regleaza din `[` si `]` in timpul
melodiei. Valoarea ramane salvata local, deci se regleaza o singura data.

## 3. Animatia de chitara

Implicit animatia e luata **de la resursa ta de emote-uri** — adica exact ce vezi
cand dai `/e guitar` normal, cu chitara tinuta corect in mana. Noi doar pornim
`/emote guitar` la ea si o anulam cu `/emote c` la final.

`Config.Animation.mode`:

| mod | ce face |
|---|---|
| `'emote'` (implicit) | ia animatia de la `dpemotes` / `rpemotes` / etc. |
| `'scenario'` | scenariul `WORLD_HUMAN_MUSICIAN` din GTA — jocul spawneaza singur chitara |
| `'anim'` | dictionarul si prop-ul din config, atasate de noi |

Daca modul ales nu e disponibil (de exemplu n-ai nicio resursa de emote-uri) se
coboara automat la urmatorul, deci ramai mereu cu o chitara in mana.

Resursele de emote-uri sunt detectate singure. Daca folosesti alta decat cele
cunoscute, pune-i numele in `Config.Animation.emoteResource`.

Doar la `mode = 'anim'`: `/guitarprop x y z rx ry rz` muta prop-ul pe loc si scrie
valorile in consola (F8), ca sa le poti copia in config.

## 4. HUD-ul

Layout-ul, culorile, geometria (perspectiva 860px / `rotateX(58deg)`), hexagoanele
receptoare si constantele de timing sunt cele din designul
`Rhythm Highway HUD.dc.html`. Fonturile (Chakra Petch + JetBrains Mono, licenta
OFL) sunt impachetate local in `html/fonts/`, deci HUD-ul arata la fel si daca
clientul n-are internet.

Randul de dificultati din design a fost inlocuit cu bara **ROCK METER**, in
acelasi stil de chip — jocul n-are nivele de dificultate.

Nimic din pagina nu deseneaza un fundal opac: ~90% din suprafata e complet
transparenta, restul sunt elementele HUD-ului.

Doua abateri de la design, ambele pentru ca browserul din FiveM (CEF) nu le
randeaza corect:

* haloul receptorilor se stinge in nuanta benzii cu alpha 0, nu in `rgba(0,0,0,0)`
  — CEF interpoleaza gradientul prin negru si iesea un chenar intunecat in jurul
  fiecarui hexagon;
* `backdrop-filter: blur()` de pe hexagoane e scos — in CEF poate fi randat ca
  dreptunghi opac peste conturul hexagonal.

Reglabil din `Config.Hud`:

| camp | ce face |
|---|---|
| `anchor` | `'bottom'` (implicit) tine HUD-ul jos ca sa se vada personajul; `'center'` = layout-ul exact din design |
| `scale` | `0.8` = HUD mai mic, `1.2` = mai mare |
| `highwayVh` | inaltimea autostrazii, in % din inaltimea ecranului (implicit 34) |
| `opacity` | transparenta intregului HUD |
| `hints` | randul cu ESC / P / calibrare / volum |

## 5. Cum functioneaza sincronizarea

Ceasul jocului nu e un timer separat: e derivat direct din `audio.currentTime`.
Cand melodia incetineste (penalizare), notele incetinesc odata cu ea si raman
sincronizate — fara nicio corectie manuala.

Cele doua melodii sunt facute prin metode diferite, pentru ca sunt inregistrari
diferite.

### Ich Will — din tab, tempo fix

Chart-ul e generat **din tab-ul Guitar Pro** si aliniat pe inregistrare
masurand-o:

| | |
|---|---|
| Tempo detectat in mp3 | **127.99 BPM** (autocorelatie pe fluxul spectral) |
| Masuri in tab | **113**, fara repetitii |
| Note generate | **742** |

Fisierul primit era varianta de videoclip: primele ~33 de secunde sunt intro-ul
filmului, nu melodia. E taiat la limita de cadru MPEG (`tools/trim_mp3.py`,
fara re-encodare), deci melodia incepe direct de la secunda 0 si fisierul e cu
0.8 MB mai mic.

Alinierea a fost verificata pe doua repere structurale independente din
inregistrare, nu ghicita:

* intrarea in **Breakdown** (m77) — banda se opreste la 140.3 s in fisierul taiat
* revenirea in **Chorus** (m94) — banda reintra la 172.2 s

Amandoua cad exact unde le pune tab-ul la 127.99 BPM. Ultima masura se termina la
209.7 s, iar fisierul are 211.7 s.

### O Mie De Pahare — din audio, tempo variabil

Aici n-a existat tab Guitar Pro, doar o foaie de acorduri fara timpi. Si, mai
important, **piesa nu are tempo constant**: variaza intre **116 si 144 BPM**,
accelerand spre final. Chiar foaia de acorduri o spune — *„speed up, slow down,
speed up"*.

Cu o grila fixa notele ies din sincron dupa vreo 30 de secunde. Verificat pe
felii de 20 s, o grila fixa cade pe evenimentele din audio doar in **4 din 9**
felii, cu deriva de 222 ms pe 80 de secunde.

Asa ca bataile vin din **beat tracking cu programare dinamica**
(`tools/beat_track.py`), care urmareste tempo-ul in loc sa-l presupuna. Aceeasi
verificare da **9 din 9** felii, cu raport 1.8–3.4x. Chart-ul memoreaza lista de
batai reale, iar liniile de masura din HUD merg pe ele, nu pe o grila.

Notele cad pe optimile pe care se aude efectiv o lovitura, deci densitatea
urmeaza energia piesei (1.4–2.9 note/s dupa sectiune). Sunt 409 note.

**Ce nu e exact aici:** culoarele nu sunt acordurile reale. Am incercat sa scot
progresia din audio in trei feluri (chromagram, registrul de bas, si Viterbi pe
grila corecta) — cam jumatate din masuri ies sigure, cealalta jumatate e
ghiceala, pentru ca mixul e prea incarcat. Culoarele urmeaza in schimb accentele
de strumming si se rotesc pe fraze de 4 masuri. Ritmul e corect, doar sageata
aleasa nu corespunde acordului. Daca apare un tab Guitar Pro pentru piesa,
se poate reface exact ca la Ich Will.

## 6. De unde vin notele (Ich Will)

Partea ta e **chitara ritmica distorsionata** — pista *Richard Kruspe-Bernstein,
Guitar 1*, cea completa (Guitar 2 o dubleaza, dar tace in breakdown).

In tab, chitara tace complet pe 16 masuri in primul verse (m13–m28, ~30 de
secunde). Acolo notele vin din **bas**, care canta exact aceeasi figura ritmica
sincopata ca riff-ul, deci se simte ca o continuare a aceleiasi parti si nu stai
degeaba jumatate de minut. Sunt 136 din cele 742 de note.

Culoarul fiecarei note vine din acord: **nota cea mai inalta + cate coarde suna**.
A doua parte conteaza — riff-ul din Ich Will alterneaza doua acorduri cu acelasi
varf, diferite doar prin coarda in plus de pe accent; dupa inaltime singura ar fi
iesit un singur culoar pe tot riff-ul. Acordurile, ordonate dupa inaltime, sunt
impartite in 4 blocuri consecutive alese prin programare dinamica, ca sa incarce
culoarele cat mai egal fara sa strice conturul melodic.

Cum se imparte pe sectiuni:

| sectiune | note | note/s | culoare folosite |
|---|---|---|---|
| Intro | 52 | 2.3 | 3 |
| Verse | 104 | 3.5 | 2 |
| Interlude | 52 | 3.5 | 3 |
| Verse | 72 | 2.4 | 3 |
| Chorus | 180 | 4.0 | 4 |
| Breakdown | 128 | 4.0 | 3 |
| Chorus | 128 | 4.3 | 3 |
| Outro | 26 | 3.5 | 2 |

Riff-ul principal chiar e format din doua acorduri, deci in verse joci pe doua
culoare; refrenul si breakdown-ul deschid toate patru.

## 7. Incetinire si esec

Bara **ROCK METER** porneste de la 65%.

* nota lovita → +1.2 (GOOD) sau +2.2 (PERFECT, sub ±55 ms)
* nota ratata → −3.0
* sageata apasata aiurea → −2.0 si se rupe streak-ul

Sub **60%** melodia incepe sa incetineasca, pana la **0.72×** viteza la 0%
(cu `preservesPitch = false`, deci se aude ca o banda care se opreste).
La **0%** melodia esueaza.

Ai nevoie de aproximativ **62% acuratete** ca sa supravietuiesti pana la final.
Se regleaza din `Config.Meter`.

## 8. Recompense (ESX)

Se platesc **doar de pe server**, dupa validare:

* scorul raportat nu poate depasi maximul teoretic (`note × 100 × 4`)
* acuratetea raportata trebuie sa se potriveasca cu notele lovite (±5%)
* runda trebuie sa fi durat cel putin 85% din durata reala a melodiei
* cooldown per identifier (`Config.Rewards.cooldown`, implicit 10 min)
* melodia esuata nu plateste nimic

Formula: `base + bonus × acuratete (+ fullCombo)`.

## 9. Integrare din alte resurse

```lua
-- client
exports['bs_guitarhero']:StartGuitarHero()
exports['bs_guitarhero']:StopGuitarHero()
local activ = exports['bs_guitarhero']:IsPlaying()

-- din server sau alta resursa
TriggerClientEvent('bs_guitarhero:start', src)
```

## 10. Alta melodie

1. Pune fisierul in `html/audio/`. Daca are intro de taiat:
   `python3 tools/trim_mp3.py sursa.mp3 iesire.mp3 <start_sec> [<end_sec>]`
2. Genereaza chart-ul: `tools/build_chart.py` daca ai tab Guitar Pro,
   `tools/build_chart_audio.py` daca ai doar mp3. Vezi `tools/README.md`.
3. Adauga o intrare in `Config.Songs` si doua linii in `files{}` din
   `fxmanifest.lua`.

Formatul chart-ului:

```json
{ "title":"...", "artist":"...", "bpm":127.99, "offset":-2.2168,
  "songEnd":209.68,
  "sections":[{"t":-2.2168,"name":"Intro"}],
  "notes":[{"t":5.518,"l":0,"d":0.234,"s":2}] }
```

`t` = secunda in mp3, `l` = culoar 0–3 (`← ↓ ↑ →`), `d` = durata (peste 0.42 s se
deseneaza coada; se joaca tot prin apasare simpla), `s` = subdiviziune.

## 11. De stiut

* HUD-ul ia focus de tastatura cat timp joci (`SetNuiFocus`), deci nu te poti
  misca in acest timp — sagetile merg in joc, nu in GTA. Jocul iese singur daca
  mori, urci in masina sau intri in ragdoll.
* Fisierele audio (4.8 MB + 3.9 MB) se descarca o singura data de fiecare client.
* Melodia se aude **doar la jucatorul care canta**. Sincronizarea audio catre
  jucatorii din jur nu e inclusa.
* Fisierul audio si tab-ul sunt materialul pe care l-ai furnizat tu; asigura-te
  ca ai dreptul sa le distribui pe serverul tau. Fonturile sunt OFL, se pot
  redistribui liber.

## 12. Structura

```
bs_guitarhero/
├── fxmanifest.lua
├── config.lua
├── client/main.lua          animatie, comenzi, NUI, watchdog
├── server/main.lua          validare scor + recompense ESX
├── tools/
│   ├── build_chart.py       chart din tab Guitar Pro (tempo fix)
│   ├── build_chart_audio.py chart doar din audio (tempo variabil)
│   ├── beat_track.py        beat tracking pentru piese cu tempo variabil
│   ├── trim_mp3.py          taiere mp3 fara re-encodare
│   └── rammstein-ich_will.gp4
└── html/
    ├── index.html
    ├── css/style.css        HUD-ul portat din design
    ├── css/fonts.css
    ├── fonts/*.woff2        Chakra Petch + JetBrains Mono (OFL)
    ├── js/game.js           motorul de joc
    ├── data/*.json          chart-uri
    └── audio/*.mp3
```
