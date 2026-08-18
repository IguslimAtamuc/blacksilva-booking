# bs_guitarhero — Rhythm Highway HUD

Minijoc de ritm pentru **FiveM / ESX**, sincronizat pe *Ich Will — Rammstein* (Mutter).
`/e guitar` porneste animatia de chitara, apoi direct **3 · 2 · 1** si melodia.

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
| `/e guitar` | animatie de chitara + minijoc, pornire directa |
| `/guitarhero` | acelasi lucru, fara resursa de emote-uri |
| `/e <orice altceva>` | pleaca normal la `dpemotes` / `rpemotes` |

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

## 3. HUD-ul

Layout-ul, culorile, geometria (perspectiva 860px / `rotateX(58deg)`), hexagoanele
receptoare si constantele de timing sunt cele din designul
`Rhythm Highway HUD.dc.html`. Fonturile (Chakra Petch + JetBrains Mono, licenta
OFL) sunt impachetate local in `html/fonts/`, deci HUD-ul arata la fel si daca
clientul n-are internet.

Randul de dificultati din design a fost inlocuit cu bara **ROCK METER**, in
acelasi stil de chip — jocul n-are nivele de dificultate.

Nimic din pagina nu deseneaza un fundal opac: ~90% din suprafata e complet
transparenta, restul sunt elementele HUD-ului.

Reglabil din `Config.Hud`:

| camp | ce face |
|---|---|
| `anchor` | `'bottom'` (implicit) tine HUD-ul jos ca sa se vada personajul; `'center'` = layout-ul exact din design |
| `scale` | `0.8` = HUD mai mic, `1.2` = mai mare |
| `highwayVh` | inaltimea autostrazii, in % din inaltimea ecranului (implicit 34) |
| `opacity` | transparenta intregului HUD |
| `hints` | randul cu ESC / P / calibrare / volum |

## 4. Cum functioneaza sincronizarea

Chart-ul e generat **din tab-ul Guitar Pro**, nu scris de mana, si aliniat pe
inregistrare masurand-o:

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

Ceasul jocului nu e un timer separat: e derivat direct din `audio.currentTime`.
Cand melodia incetineste (penalizare), notele incetinesc odata cu ea si raman
sincronizate — fara nicio corectie manuala.

## 5. De unde vin notele

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

## 6. Incetinire si esec

Bara **ROCK METER** porneste de la 65%.

* nota lovita → +1.2 (GOOD) sau +2.2 (PERFECT, sub ±55 ms)
* nota ratata → −3.0
* sageata apasata aiurea → −2.0 si se rupe streak-ul

Sub **60%** melodia incepe sa incetineasca, pana la **0.72×** viteza la 0%
(cu `preservesPitch = false`, deci se aude ca o banda care se opreste).
La **0%** melodia esueaza.

Ai nevoie de aproximativ **62% acuratete** ca sa supravietuiesti pana la final.
Se regleaza din `Config.Meter`.

## 7. Recompense (ESX)

Se platesc **doar de pe server**, dupa validare:

* scorul raportat nu poate depasi maximul teoretic (`note × 100 × 4`)
* acuratetea raportata trebuie sa se potriveasca cu notele lovite (±5%)
* runda trebuie sa fi durat cel putin 85% din durata reala a melodiei
* cooldown per identifier (`Config.Rewards.cooldown`, implicit 10 min)
* melodia esuata nu plateste nimic

Formula: `base + bonus × acuratete (+ fullCombo)`.

## 8. Integrare din alte resurse

```lua
-- client
exports['bs_guitarhero']:StartGuitarHero()
exports['bs_guitarhero']:StopGuitarHero()
local activ = exports['bs_guitarhero']:IsPlaying()

-- din server sau alta resursa
TriggerClientEvent('bs_guitarhero:start', src)
```

## 9. Alta melodie

1. Pune fisierul in `html/audio/`. Daca are intro de taiat:
   `python3 tools/trim_mp3.py sursa.mp3 iesire.mp3 <start_sec> [<end_sec>]`
2. Genereaza chart-ul: vezi `tools/README.md`.
3. Actualizeaza `Config.Song` si `files{}` din `fxmanifest.lua`.

Formatul chart-ului:

```json
{ "title":"...", "artist":"...", "bpm":127.99, "offset":-2.2168,
  "songEnd":209.68,
  "sections":[{"t":-2.2168,"name":"Intro"}],
  "notes":[{"t":5.518,"l":0,"d":0.234,"s":2}] }
```

`t` = secunda in mp3, `l` = culoar 0–3 (`← ↓ ↑ →`), `d` = durata (peste 0.42 s se
deseneaza coada; se joaca tot prin apasare simpla), `s` = subdiviziune.

## 10. De stiut

* HUD-ul ia focus de tastatura cat timp joci (`SetNuiFocus`), deci nu te poti
  misca in acest timp — sagetile merg in joc, nu in GTA. Jocul iese singur daca
  mori, urci in masina sau intri in ragdoll.
* `html/audio/ichwill.mp3` (4.8 MB) se descarca o singura data de fiecare client.
* Melodia se aude **doar la jucatorul care canta**. Sincronizarea audio catre
  jucatorii din jur nu e inclusa.
* Fisierul audio si tab-ul sunt materialul pe care l-ai furnizat tu; asigura-te
  ca ai dreptul sa le distribui pe serverul tau. Fonturile sunt OFL, se pot
  redistribui liber.

## 11. Structura

```
bs_guitarhero/
├── fxmanifest.lua
├── config.lua
├── client/main.lua          animatie, comenzi, NUI, watchdog
├── server/main.lua          validare scor + recompense ESX
├── tools/
│   ├── build_chart.py       chart din .gp4
│   ├── trim_mp3.py          taiere mp3 fara re-encodare
│   └── rammstein-ich_will.gp4
└── html/
    ├── index.html
    ├── css/style.css        HUD-ul portat din design
    ├── css/fonts.css
    ├── fonts/*.woff2        Chakra Petch + JetBrains Mono (OFL)
    ├── js/game.js           motorul de joc
    ├── data/ichwill.json    chart generat din tab
    └── audio/ichwill.mp3
```
