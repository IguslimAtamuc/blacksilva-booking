# BlackSilva — Story Mode Quest Engine (ESX) — v2.0

Sistem de misiuni **interactive, story mode** pentru FiveM (ESX). Nu mai sunt
simple checkpoint-uri: fiecare quest are **NPC-uri reale**, **dialoguri chat**,
**props pentru livrari**, **urmariri reale cu NPC-uri si politie**, pasi
multipli, progres salvat in baza de date si cleanup complet.

## Dependinte
- `es_extended` (ESX)
- `mysql-async` (tabela `blacksilva_quests` se creeaza singura la pornire)
- `ox_inventory` — optional, doar pentru `reward.items` (vezi `Config.Inventory`)

## Instalare
1. Pune folderul `blacksilva-missions` in `resources`.
2. In `server.cfg`: `ensure blacksilva-missions`.
3. Apasa **F5** in joc pentru jurnalul de misiuni. Misiunea curenta porneste automat.

## Cum functioneaza
- Progresul fiecarui jucator = `currentQuest`, `currentStep`, `completed{}`,
  salvat in `blacksilva_quests`. La (re)conectare misiunea continua de unde a ramas.
- Un quest = o lista de **pasi** (`steps`) care se ruleaza pe rand. Cand un pas e
  gata, clientul anunta serverul, serverul valideaza si trece la pasul urmator.
- La ultimul pas se acorda recompensa si se trece la `nextQuest`.
- Daca mori, pasul curent se reia in siguranta (fara NPC/props duplicate).

## Tipuri de pasi (`step.type`)
| type | ce face | campuri |
|------|---------|---------|
| `dialogue` | spawn NPC + dialog chat interactiv (cu optiuni) | `npc`, `dialogue` |
| `goto` | mergi la coordonate (marker+blip); optional in vehicul | `coords`, `radius`, `inVehicle`, `blip` |
| `giveProp` | primesti un prop atasat in mana (livrari) | `prop` |
| `deliverProp` | predai prop-ul (apesi **E**) la coords / NPC | `coords` sau `npc`, `radius` |
| `getVehicle` | spawn vehicul de furat — gata cand intri in el | `model`, `coords`, `blip` |
| `chase` | NPC-uri te urmaresc real cu masini — scapi / ii elimini | `chasers`, `escapeDistance`, `escapeTime` |
| `policeChase` | politisti NPC te urmaresc real — scapa de ei | `units`, `wanted`, `escapeDistance`, `escapeTime` |
| `killTargets` | elimina X NPC-uri ostile | `count`, `spawn`, `spread`, `model`, `weapon` |
| `hideVehicle` | du vehiculul la o ascunzatoare si abandoneaza-l | `coords`, `radius`, `blip` |
| `scene` | moment narativ (banner cinematic), auto-advance | `title`, `text`, `duration` |

Orice pas are `objective = 'text afisat in HUD'`.

## Dialoguri (chat)
```lua
dialogue = {
  npcName = 'Marco',
  lines = {
    { who = 'npc',    text = 'Ai intarziat...' },
    { who = 'player', text = 'Ce trebuie sa fac?' },
    { who = 'choice', options = {
        { text = 'Si daca ma urmareste cineva?', reply = { who='npc', text='Atunci nu te opri.' } },
        { text = 'Ma descurc.',                  reply = { who='npc', text='Asa sper.' } },
    }},
  },
}
```
Liniile apar treptat (typing), cu buton **Continua / Enter**. Optiunile se aleg
cu mouse-ul sau tastele **1–4**.

## Comanda `/quest set <numar>` (admin)
- `/quest set 15` → muta jucatorul direct la questul 15 (questurile 1–14 devin
  *completate*, 15+ devin *nefacute*).
- `/quest set 2` → reseteaza inapoi la questul 2 (questurile 3+ devin *nefacute*
  si pot fi refacute).
- `/quest set 15 12` → aplica pe jucatorul cu serverId `12`.
- Inainte de schimbare se face **cleanup complet** (NPC, props, blip, chase).
- Doar grupul `Config.AdminGroup` (default `admin`). Daca numarul nu exista → eroare.
- `/quest` (fara argumente) deschide jurnalul.

## Cum adaug o misiune noua
In `config.lua`, in `Config.Quests`, adaugi o intrare noua cu **id consecutiv**
si o legi de lant cu `nextQuest`:
```lua
[6] = {
    id = 6,
    title = 'Titlul Misiunii',
    intro = 'Subtitlu cinematic',
    description = 'Ce trebuie sa faca jucatorul.',
    reward = { money = 25000, bank = 0, xp = 3, items = { { name = 'water', count = 1 } } },
    nextQuest = 7, -- sau nil daca e ultima
    steps = {
        { type='dialogue', objective='Vorbeste cu X',
          npc = { model='s_m_y_dealer_01', coords=vec4(0.0,0.0,70.0,90.0),
                  scenario='WORLD_HUMAN_STAND_IMPATIENT', blip={sprite=280,color=5,label='X'} },
          dialogue = { npcName='X', lines = { { who='npc', text='Salut.' } } } },
        { type='giveProp',   objective='Ia pachetul', prop={ model='prop_cs_package_01', label='Pachet', bone=28422 } },
        { type='goto',       objective='Mergi la livrare', coords=vec3(100.0,200.0,30.0), inVehicle=true,
          blip={sprite=1,color=5,label='Livrare'} },
        { type='chase',      objective='Scapa de urmaritori!',
          chasers={ { model='g_m_y_mexgang_01', vehicle='sultan', weapon='WEAPON_PISTOL' } } },
        { type='deliverProp',objective='Livreaza pachetul', coords=vec3(100.0,205.0,30.0) },
    },
},
```
Atat — nu trebuie sa modifici `client/main.lua` sau `server/main.lua`. Toata
logica de gameplay e generica si citeste din config.

## Note de integrare
- **Coordonatele / modelele de NPC / vehicule / props** sunt repere standard
  GTA V; ajusteaza-le la harta/serverul tau daca e cazul.
- `policeChase` foloseste **politisti NPC scriptati** (stabil pe orice server)
  si optional seteaza `wanted` pentru ambianta.
- Recompensele: `money`/`bank` prin ESX, `items` prin `ox_inventory` sau ESX
  (vezi `Config.Inventory`), `xp` prin `Config.ExpCommand`.

## Cleanup
La schimbarea questului, `/quest set`, moarte, deconectare sau oprirea resursei
se sterg: NPC-urile, vehiculele si props-urile spawnate, blip-urile, se opresc
urmaririle si thread-urile pasului si se reseteaza nivelul de cautare setat de quest.
