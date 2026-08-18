# bs_guitarhero — Rhythm Highway HUD

Minijoc de ritm pentru **FiveM / ESX**, sincronizat pe *Faint — Linkin Park* (Meteora).
Cand jucatorul scrie `/e guitar` porneste animatia de chitara **si** minijocul.
Daca rateaza note, melodia incetineste progresiv; daca rateaza prea multe, melodia esueaza.

---

## 1. Instalare

1. Copiaza folderul `bs_guitarhero` in `resources/`.
2. In `server.cfg`, **dupa** resursa de emote-uri (`dpemotes` / `rpemotes`):

```cfg
ensure dpemotes
ensure bs_guitarhero
```

> Ordinea conteaza. `bs_guitarhero` preia comanda `/e` si trimite mai departe la
> `/emote` orice alt emote decat `guitar`. Daca porneste inaintea lui `dpemotes`,
> emote-ul original ramane activ si jocul nu mai porneste.

3. Restart server. Gata — nu trebuie configurat nimic altceva.

## 2. Cum se joaca

| Comanda | Efect |
|---|---|
| `/e guitar` | animatie de chitara + minijoc |
| `/e guitar hard` | direct pe o anumita dificultate |
| `/guitarhero [dificultate]` | comanda proprie (merge si fara resursa de emote-uri) |
| `/e <orice altceva>` | pleaca normal la `dpemotes` / `rpemotes` |

In joc:

| Tasta | Actiune |
|---|---|
| `A` `S` `D` `F` `G` (sau `1`–`5`) | cele 5 culoare |
| `SPACE` | start / reincearca |
| `←` `→` | dificultate (in ecranul de start) |
| `P` | pauza |
| `ESC` | pauza, apoi iesire |
| `[` `]` | calibrare audio ±5 ms (se salveaza per client) |
| `-` `+` | volum |

**Daca notele nu par sincronizate cu sunetul**, regleaza din `[` si `]` in timpul
melodiei. Valoarea ramane salvata local, deci se regleaza o singura data.

## 3. Cum functioneaza sincronizarea

Chart-ul a fost generat **direct din tab-ul Guitar Pro** (`linkin_park-faint.gp4`)
si aliniat pe fisierul audio:

| | |
|---|---|
| Tempo detectat in mp3 | **135.03 BPM** (autocorelatie pe fluxul spectral) |
| Prima masura in mp3 | **0.823 s** |
| Masuri (cu repetitiile desfacute) | **91** |
| Sfarsit calculat | 162.56 s — se potriveste cu finalul real al piesei |
| Note generate | **659** |

Ceasul jocului nu e un timer separat: e derivat direct din `audio.currentTime`.
Asta inseamna ca atunci cand melodia incetineste (penalizare), notele incetinesc
odata cu ea si raman perfect sincronizate — fara nicio corectie manuala.

Notele vin din pista de chitara solo (*Brad Delson*); acolo unde chitara tace
(intro-ul, de exemplu) se foloseste riff-ul de clape (*Joseph Hahn*), asa cum e
in tab. Inaltimea reala a fiecarui acord decide culoarul, deci conturul melodic
de pe autostrada urmeaza riff-ul adevarat.

## 4. Incetinire si esec

Bara **ROCK METER** porneste de la 65%.

* nota lovita → +0.6 … +2.2 (dupa cat de precis)
* nota ratata → −2.0 … −5.0 (dupa dificultate)
* tasta apasata aiurea → −2.0 si se rupe streak-ul

Sub **60%** melodia incepe sa incetineasca, pana la **0.72×** viteza la 0%
(cu `preservesPitch = false`, deci se aude ca o banda care se opreste).
La **0%** melodia esueaza.

Acuratetea minima ca sa supravietuiesti, pe dificultate: `easy` ~50%,
`normal` ~60%, `hard` ~67%, `expert` ~71%.

## 5. Configurare — `config.lua`

Totul se regleaza de acolo:

* `Config.HijackEmoteCommand` — preluarea comenzii `/e`
* `Config.ForwardGuitarToEmoteScript` — daca vrei sa lasi emote-ul tau de chitara
  in loc de animatia noastra
* `Config.Animation` — dictionar, clip, prop, os si pozitie
* `Config.Keys` / `Config.AltKeys` — tastele celor 5 culoare
* `Config.Difficulties` — ferestre de lovire si penalizari
* `Config.Meter` — start, prag de incetinire, viteza minima
* `Config.Rewards` — bani la final (validati pe server)

## 6. Recompense (ESX)

Se platesc **doar de pe server**, dupa validare:

* scorul raportat nu poate depasi maximul teoretic (`note × 100 × 4`)
* acuratetea raportata trebuie sa se potriveasca cu notele lovite (±5%)
* runda trebuie sa fi durat cel putin 85% din durata reala a melodiei
* cooldown per identifier (`Config.Rewards.cooldown`, implicit 10 min)
* melodia esuata nu plateste nimic

Formula: `base + bonus × acuratete (+ fullCombo) × multiplicator_dificultate`.

## 7. Integrare din alte resurse

```lua
-- client
exports['bs_guitarhero']:StartGuitarHero('hard')
exports['bs_guitarhero']:StopGuitarHero()
local activ = exports['bs_guitarhero']:IsPlaying()

-- din server sau alta resursa
TriggerClientEvent('bs_guitarhero:start', src, 'normal')
```

## 8. Alta melodie

1. Pune `melodia.mp3` in `html/audio/`.
2. Genereaza un chart cu aceeasi structura ca `html/data/faint.json`:

```json
{ "title":"...", "artist":"...", "bpm":135.03, "offset":0.823,
  "duration":162.56,
  "sections":[{"t":0.823,"name":"Intro"}],
  "notes":[{"t":0.823,"l":3,"d":0.22,"s":0}] }
```

`t` = secunda in mp3, `l` = culoar 0–4, `d` = durata, `s` = subdiviziune
(0 = inceput de masura, 1 = patrime, 2 = optime, 3 = mai marunt — de asta
depinde filtrarea pe dificultati).

3. Actualizeaza `Config.Song` (`chart`, `audio`, `duration`) si `files{}` din
   `fxmanifest.lua`.

## 9. Note

* `html/audio/faint.mp3` (3.9 MB) se descarca o singura data de fiecare client.
* Melodia se aude **doar la jucatorul care canta**. Sincronizarea audio catre
  jucatorii din jur nu e inclusa.
* Fisierul audio si tab-ul sunt materialul pe care l-ai furnizat tu; asigura-te
  ca ai dreptul sa le distribui pe serverul tau.

## 10. Structura

```
bs_guitarhero/
├── fxmanifest.lua
├── config.lua
├── client/main.lua        animatie, comenzi, NUI, watchdog
├── server/main.lua        validare scor + recompense ESX
└── html/
    ├── index.html
    ├── css/style.css
    ├── js/game.js         motorul de joc + randare canvas
    ├── data/faint.json    chart generat din .gp4
    └── audio/faint.mp3
```
