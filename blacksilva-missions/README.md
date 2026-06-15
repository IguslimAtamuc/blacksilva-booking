# BlackSilva Missions (ESX)

Sistem de misiuni pentru FiveM (ESX) cu UI cinematic: la deschidere camera se
apropie de personaj (pozitionat pe **treimea din stanga** a ecranului, dupa
regula treimilor) care sta cu **clipboard in mana**, iar pe **dreapta apare un
panou de misiuni** in stilul din design (carduri cu inel de progres, status,
recompensa si detalii la click).

> **Ordine obligatorie:** misiunile se fac **pe rand** (1 → 2 → 3 → ...). O
> misiune este **blocata** pana cand cea dinaintea ei este completata. Blocarea
> este verificata si pe server, deci nu poate fi ocolita.

## Doua sectiuni in meniul F5
Meniul are doua tab-uri:
- **Misiuni** — cele 10 misiuni "story", secventiale (de la inceput).
- **Activitati** — **50 de activitati** repetabile (livrari, colectare, animatii,
  fotografie) pe care le **pornesti direct din meniu**, fara NPC. Apesi pe o
  activitate → **Incepe**, urmaresti GPS-ul/markerele, apesi **E** la fiecare
  punct, iar la final deschizi F5 → **Revendica** recompensa.

### Activitatile (continut original)
- Se pornesc 100% din F5 (buton **Incepe**), fara NPC de la care iei quest-ul.
- Tipuri: `delivery` (ridici de la un punct si livrezi la altele), `collect`
  (aduni de la mai multe puncte), `animation` (faci o actiune la fiecare punct),
  `photo` (fotografiezi la fiecare punct).
- **Recompensa pe dificultate** (`Config.ActivityPayments`):
  EASY, MEDIUM, HARD, ILLEGAL — fiecare cu un interval de bani (random) + nivel.
- **Repetabile** cu **cooldown** (`cooldown` pe fiecare activitate, sau
  `Config.ActivityCooldownDefault`).
- Le editezi/adaugi usor in `Config.Activities` din `config.lua` (titlu,
  descriere, dificultate, coordonate, animatii/props).
- Recompensa se ia tot din meniu (buton **Revendica** / **Revendica tot**),
  fara notificare in joc.

## Instalare

1. Pune folderul `blacksilva-missions` in `resources`.
2. Adauga in `server.cfg`:
   ```
   ensure blacksilva-missions
   ```
3. Tabela `blacksilva_missions` se creeaza singura la pornire (necesita `mysql-async`).

### Dependinte
- `es_extended` (ESX)
- `mysql-async`
- `ox_inventory` (sau inventarul default ESX — vezi `Config.Inventory`)

## Cum se foloseste
- Apasa **F5** (sau `/misiuni`) ca sa deschizi meniul.
- **ESC** inchide meniul.

## Cum editezi / adaugi misiuni
Totul se face in **`config.lua`**. Fiecare misiune are: `title`, `description`,
`reward` (bani), `level` (experienta), `icon`, `type` si parametrii specifici.
Ca sa adaugi o misiune noua copiezi un bloc existent si ii schimbi `id`-ul.

### Tipuri de misiuni disponibile
| type | descriere | parametri |
|------|-----------|-----------|
| `use_item` | foloseste anumite iteme | `items`, `target`, `distinct` |
| `spawn_vehicle` | intra intr-un vehicul anume | `models`, `target` |
| `reach_location` | ajunge la o locatie (marker) | `location`, `blip`, `target` |
| `speed_radar` | treci prin radar cu viteza | `radars`, `minSpeed`, `radarRadius`, `target` |
| `stunts` | fa stunt-uri cu vehiculul | `target`, `minAirTime` |
| `visit_locations` | viziteaza toate locatiile | `locations`, `blip` |
| `obtain_weapon` | obtine o arma langa o locatie | `location`, `radius`, `target` |
| `command` | foloseste o comanda | `command`, `registerCommand`, `target` |
| `kill_players` | omoara X jucatori | `target` |

## Progress bar (culori)
- **Rosu** — sub 50%
- **Galben** — peste 50%
- **Verde** — 100% / completat

Culoarea de accent a meniului (portocaliu implicit) se schimba din
`Config.Accent`.

## Ordinea misiunilor
Misiunile trebuie facute in ordinea din `Config.Missions` (1, 2, 3, ...). Cardul
unei misiuni blocate apare gri, cu lacat, si nu primeste progres pana cand
misiunea anterioara nu e completata. Ordinea = ordinea elementelor din lista, nu
neaparat `id`-ul (poti rearanja blocurile ca sa schimbi ordinea).

## Recompense (revendicare manuala)
Cand termini o misiune **nu primesti nimic automat si nu apare nicio
notificare** in joc. Recompensa se ia manual din meniu:
- apesi pe card → butonul **Revendica** (bani + nivel), sau
- butonul **Revendica tot** din footer pentru toate misiunile terminate.

La revendicare primesti:
- banii din `reward` (cont configurat in `Config.RewardAccount`);
- experienta prin comanda din `Config.ExpCommand` rulata pe server ca
  `addlevel <serverId> <level>` (configurabil).

## Estetica (camera, blur, pozitie)
- Personajul e incadrat pe treimea din stanga (`Config.Camera.sideAim`).
- Fundalul jocului este **blurat** (Depth of Field) ca focusul sa fie pe
  personaj si pe meniu; se regleaza din `Config.Camera.dof / dofNear / dofFar /
  dofStrength` (sau `dof = false` ca sa-l dezactivezi).
- Pozitia orizontala a panoului se regleaza din `Config.PanelRight` (valoare mai
  mare = panoul mai spre stanga).

## Misiunile incluse (cerute)
1. Foloseste bauturile energizante `exp`, `exp2`, `exp3` — 10.000$
2. Spawneaza un scooter (`faggio`, `faggio2`, `faggio3`) din meniul K — 20.000$
3. Mergi la Job Center — 30.000$
4. Treci printr-un radar cu 200+ km/h — 40.000$
5. Fa 2 stunt-uri — 50.000$
6. Viziteaza toate gunshop-urile — 60.000$
7. Construieste prima arma la atelier — 70.000$
8. Foloseste comanda `/liber` — 80.000$
9. Omoara 50 de jucatori — 90.000$
10. Omoara 100 de jucatori — 100.000$

## Note importante de integrare
- **Numele itemelor** (`exp`, `exp2`, `exp3`) si **modelele scooterelor** trebuie
  sa fie exact cele de pe serverul tau. Editeaza-le in `config.lua` daca difera.
- **Misiunea 7** se completeaza cand apare o arma noua (item `WEAPON_*`) in
  inventar in timp ce esti langa atelier. Functioneaza cu `ox_inventory`.
- **Misiunea 8 (`/liber`)**: daca aceasta comanda exista deja in alt script,
  pune `registerCommand = false` pe misiune si apeleaza din scriptul tau:
  ```lua
  TriggerEvent('blacksilva-missions:commandUsed', 'liber')
  ```
- **Camera/personaj**: daca personajul nu e bine pozitionat pe stanga, ajusteaza
  `Config.Camera` (in special `sideAim` si `forward`).
- **Emote clipboard**: implicit scriptul joaca singur animatia. Daca vrei sa
  folosesti `rpemotes` (`/e clipboard`), pune `Config.Emote.useRpEmotes = true`.

## Admin
- `/resetmisiuni [ID]` — reseteaza progresul unui jucator (doar grup `admin`).
