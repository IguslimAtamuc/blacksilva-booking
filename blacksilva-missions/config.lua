Config = {}

-- =====================================================================
--  BLACKSILVA - SISTEM DE MISIUNI (ESX)
--  Aici editezi TOT. Adaugi/stergi misiuni usor in Config.Missions.
-- =====================================================================

-- Tasta de deschidere a meniului (Pasul 1)
Config.OpenKey      = 'F5'          -- tasta default (se poate schimba din setarile FiveM)
Config.Command      = 'misiuni'     -- comanda alternativa: /misiuni

-- Sistemul de inventar folosit (pentru detectarea itemelor folosite/primite)
--   'ox'  -> ox_inventory
--   'esx' -> inventarul default ESX
Config.Inventory    = 'ox'

-- Recompensa la finalizare
Config.RewardAccount = 'money'      -- 'money' (cash) sau 'bank'
-- Comanda care da experienta instant la finalizarea unei misiuni.
-- Se ruleaza pe server ca: <ExpCommand> <serverId> <level>
-- Ex: "addlevel 12 1"
Config.ExpCommand    = 'addlevel'

-- Camera & emote-ul cu clipboard (Pasul 2)
Config.Emote = {
    -- Daca folosesti rpemotes, poti lasa true ca sa ruleze /e clipboard.
    -- Daca pui false, scriptul joaca singur animatia cu clipboard (recomandat, fara dependinte).
    useRpEmotes  = false,
    rpEmoteName  = 'clipboard',
    animDict     = 'amb@world_human_clipboard@male@idle_a',
    animName     = 'idle_c',
    propModel    = 'p_amb_clipboard_01',
}

-- Culoarea principala a meniului (accent)
Config.Accent = '#E8930C' -- portocaliu (ca in design)

-- Pozitia orizontala a panoului (in vw, masurat din dreapta ecranului).
-- Valoare MAI MARE = panoul se muta mai spre STANGA (mai echilibrat estetic).
Config.PanelRight = 9

-- Pozitionarea camerei (regula treimilor).
-- Personajul trebuie sa apara pe TREIMEA din STANGA, panoul pe dreapta.
-- 'sideAim' NEGATIV = personajul se muta spre STANGA ecranului.
-- Mareste valoarea (ex: -0.7) ca sa-l muti mai spre stanga, micsoreaz-o spre centru.
Config.Camera = {
    forward   = 2.1,    -- cat de in fata e camera fata de personaj
    height    = 0.55,   -- inaltimea camerei
    sideAim   = -0.55,  -- decalaj lateral (negativ = personaj spre stanga)
    pointZ    = 0.55,   -- inaltimea punctului catre care priveste camera
    fov       = 38.0,
    interp    = 1200,   -- durata tranzitiei (ms)

    -- Blur de fundal (Depth of Field): personajul ramane clar, fundalul blurat.
    dof         = true,
    dofNear     = 0.6,  -- de la ce distanta incepe sa fie clar
    dofFar      = 3.2,  -- dupa aceasta distanta fundalul devine blurat
    dofStrength = 1.0,  -- intensitatea blur-ului (0.0 - 1.0)
}

-- Markerul folosit pentru misiunile cu locatie (job center, gunshop-uri etc.)
Config.Marker = {
    type   = 1,
    size   = vector3(1.5, 1.5, 1.0),
    color  = { r = 74, g = 222, b = 80, a = 120 },
    radius = 2.0,        -- distanta la care se considera "ai ajuns"
    drawDistance = 50.0, -- de la ce distanta se deseneaza markerul
}

-- =====================================================================
--  MISIUNILE
--  Fiecare misiune are:
--    id          - numar unic
--    title       - titlul afisat
--    description - descrierea
--    reward      - banii primiti la finalizare
--    level       - cate niveluri primesti (folosit cu Config.ExpCommand)
--    icon        - emoji/text afisat pe card
--    type        - tipul logicii (vezi client/main.lua)
--    target      - cate "puncte" de progres trebuie strans
--    ...params specifice fiecarui tip
-- =====================================================================
Config.Missions = {

    -- MISIUNEA 1: Foloseste bauturile energizante (exp, exp2, exp3) -----
    {
        id          = 1,
        title       = 'Energizant',
        description = 'Deschide inventarul (I / F2 / Tab) si foloseste bauturile energizante pentru a primi experienta.',
        reward      = 10000,
        level       = 1,
        icon        = 'bottle',
        type        = 'use_item',
        items       = { 'exp', 'exp2', 'exp3' }, -- itemele de monitorizat
        target      = 3,                          -- cate iteme trebuie folosite (cate una din fiecare)
        distinct    = true,                       -- true = trebuie folosit cate unul DIN FIECARE tip
    },

    -- MISIUNEA 2: Spawneaza un scooter din meniul K --------------------
    {
        id          = 2,
        title       = 'Scooter',
        description = 'Deschide meniul K si spawneaza un scooter (faggio, faggio2 sau faggio3).',
        reward      = 20000,
        level       = 1,
        icon        = 'car',
        type        = 'spawn_vehicle',
        models      = { 'faggio', 'faggio2', 'faggio3' },
        target      = 1,
    },

    -- MISIUNEA 3: Mergi la Job Center ---------------------------------
    {
        id          = 3,
        title       = 'Job Center',
        description = 'Deschide meniul K, ia un vehicul si mergi la Job Center. Intra in marker pentru a finaliza.',
        reward      = 30000,
        level       = 1,
        icon        = 'map',
        type        = 'reach_location',
        location    = vector3(-535.2607, -212.9792, 37.6498),
        blip        = { sprite = 351, color = 2, label = 'Misiune: Job Center' },
        target      = 1,
    },

    -- MISIUNEA 4: Treci prin radare cu 200+ km/h ----------------------
    {
        id          = 4,
        title       = 'Radare',
        description = 'Cumpara sau fura o masina si treci printr-un radar cu 200 km/h sau mai mult.',
        reward      = 40000,
        level       = 1,
        icon        = 'camera',
        type        = 'speed_radar',
        minSpeed    = 200, -- km/h
        radars      = {
            vector3(1954.1500, 2473.8416, 54.5564),
            vector3(2490.2295, 5533.9136, 44.7608),
            vector3(-121.8262, 6260.9146, 31.1556),
            vector3(-1881.9817, 4635.9844, 57.0025),
            vector3(-2685.9927, 2445.0269, 16.6794),
        },
        radarRadius = 25.0,
        target      = 1, -- de cate ori trebuie sa treci printr-un radar cu viteza
    },

    -- MISIUNEA 5: Completeaza 2 stunt-uri -----------------------------
    {
        id          = 5,
        title       = 'Stunt-uri',
        description = 'Completeaza 2 stunt-uri cu un vehicul (sari si aterizeaza pe roti).',
        reward      = 50000,
        level       = 1,
        icon        = 'car',
        type        = 'stunts',
        target      = 2,
        minAirTime  = 800, -- ms in aer pentru a conta ca stunt
    },

    -- MISIUNEA 6: Viziteaza toate gunshop-urile -----------------------
    {
        id          = 6,
        title       = 'Gunshop-uri',
        description = 'Mergi la toate gunshop-urile din oras pentru a cumpara diferite licente pentru arme.',
        reward      = 60000,
        level       = 1,
        icon        = 'gun',
        type        = 'visit_locations',
        locations   = {
            vector3(-662.1,   -935.3,  21.8),
            vector3(810.2,   -2157.6,  29.6),
            vector3(1693.4,   3760.2,  34.7),
            vector3(-330.2,   6083.9,  31.5),
            vector3(252.3,     -50.0,  69.9),
            vector3(22.1,    -1107.3,  29.8),
            vector3(2567.7,    294.4, 108.7),
            vector3(-1117.6,  2698.6,  18.6),
            vector3(842.4,   -1033.4,  28.2),
            vector3(-1305.2,  -393.5,  36.7),
        },
        blip        = { sprite = 110, color = 1, label = 'Gunshop' },
        -- target se calculeaza automat = numarul de locatii
    },

    -- MISIUNEA 7: Construieste prima ta arma --------------------------
    {
        id          = 7,
        title       = 'Construieste Arma',
        description = 'Mergi la atelier si construieste prima ta arma. Misiunea se finalizeaza cand arma apare in inventar.',
        reward      = 70000,
        level       = 1,
        icon        = 'wrench',
        type        = 'obtain_weapon',
        location    = vector3(-1171.3990, 4926.5522, 224.2403),
        blip        = { sprite = 110, color = 5, label = 'Misiune: Atelier Arme' },
        radius      = 30.0, -- trebuie sa fii in apropiere cand obtii arma
        target      = 1,
    },

    -- MISIUNEA 8: Foloseste comanda /liber ----------------------------
    {
        id          = 8,
        title       = 'Comanda /liber',
        description = 'Foloseste comanda /liber.',
        reward      = 80000,
        level       = 1,
        icon        = 'flag',
        type        = 'command',
        command     = 'liber',
        target      = 1,
        -- Daca /liber exista deja in alt script, pune registerCommand = false
        -- si apeleaza din scriptul tau: TriggerEvent('blacksilva-missions:commandUsed', 'liber')
        registerCommand = true,
    },

    -- MISIUNEA 9: Omoara 50 de jucatori -------------------------------
    {
        id          = 9,
        title       = 'Vanator I',
        description = 'Omoara 50 de jucatori.',
        reward      = 90000,
        level       = 1,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 50,
    },

    -- MISIUNEA 10: Omoara 100 de jucatori -----------------------------
    {
        id          = 10,
        title       = 'Vanator II',
        description = 'Omoara 100 de jucatori.',
        reward      = 100000,
        level       = 1,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 100,
    },

    -- =====================================================================
    --  CAMPANIA "IMPERIUL BLACKSILVA" - 50 de misiuni (mod poveste)
    --  Un singur fir narativ, continuu: de la un nou-venit fara un ban,
    --  pana la cel mai temut nume din Los Santos. Misiunile raman
    --  secventiale (se deblocheaza pe rand, in ordinea de mai jos).
    --
    --  NOTA: coordonatele sunt repere din Los Santos si pot fi ajustate la
    --  harta serverului tau. Numele itemelor (ex: 'lockpick') si ale unor
    --  vehicule pot diferi pe serverul tau - editeaza-le daca e cazul.
    --
    --  ACT I   (11-20): SOSIREA       - primii pasi in oras
    --  ACT II  (21-30): STRADA        - reputatie si prima banda
    --  ACT III (31-40): CRIMA ORG.    - laborator, contrabanda, prima banca
    --  ACT IV  (41-50): RAZBOIUL      - tradare, razboi de banda, preluarea
    --  ACT V   (51-60): IMPERIUL      - extindere, cazino si legenda
    -- =====================================================================

    ----------------------------------------------------------------------
    --  ACT I - SOSIREA IN LOS SANTOS
    ----------------------------------------------------------------------

    -- 11
    {
        id          = 11,
        title       = 'Bun venit in Los Santos',
        description = 'Cobori din autobuz fara un ban in buzunar. Mergi in Piata Legion si priveste orasul care iti va deveni casa.',
        reward      = 120000,
        level       = 2,
        icon        = 'map',
        type        = 'reach_location',
        location    = vector3(195.17, -934.21, 30.69),
        blip        = { sprite = 351, color = 5, label = 'Sosire: Piata Legion' },
        target      = 1,
    },

    -- 12
    {
        id          = 12,
        title       = 'Un acoperis deasupra capului',
        description = 'Inchiriaza o camera la motelul din Strawberry. Toata lumea trebuie sa inceapa de undeva.',
        reward      = 140000,
        level       = 2,
        icon        = 'building',
        type        = 'reach_location',
        location    = vector3(324.9, -204.2, 54.1),
        blip        = { sprite = 40, color = 3, label = 'Motel' },
        target      = 1,
    },

    -- 13
    {
        id          = 13,
        title       = 'Primul ban cinstit',
        description = 'Imprumuta o duba veche pentru livrari. Urca-te intr-o duba (speedo, burrito sau rumpo).',
        reward      = 160000,
        level       = 2,
        icon        = 'truck',
        type        = 'spawn_vehicle',
        models      = { 'speedo', 'burrito', 'rumpo' },
        target      = 1,
    },

    -- 14
    {
        id          = 14,
        title       = 'Livrari prin oras',
        description = 'Du coletele la toate adresele marcate pe harta. Munca cinstita, plata mica.',
        reward      = 180000,
        level       = 2,
        icon        = 'box',
        type        = 'visit_locations',
        locations   = {
            vector3(-47.5, -1758.0, 29.4),
            vector3(373.0, 325.0, 103.5),
            vector3(-707.0, -914.0, 19.2),
            vector3(1135.0, -982.0, 46.2),
            vector3(-1820.0, 792.0, 138.0),
        },
        blip        = { sprite = 501, color = 5, label = 'Livrare' },
    },

    -- 15
    {
        id          = 15,
        title       = 'Intalnire pe alee',
        description = 'Un necunoscut zice ca are de lucru mai bine platit. Mergi la intalnirea de pe alee.',
        reward      = 200000,
        level       = 2,
        icon        = 'eye',
        type        = 'reach_location',
        location    = vector3(-1175.0, -888.0, 13.9),
        blip        = { sprite = 280, color = 5, label = 'Intalnire' },
        target      = 1,
    },

    -- 16
    {
        id          = 16,
        title       = 'Mesaj codat',
        description = 'Necunoscutul iti trimite un cod. Raspunde-i scriind comanda /raspund in chat.',
        reward      = 220000,
        level       = 2,
        icon        = 'phone',
        type        = 'command',
        command     = 'raspund',
        target      = 1,
        registerCommand = true,
    },

    -- 17
    {
        id          = 17,
        title       = 'Marfa mica',
        description = 'Ridica primul colet de la casa conspirativa. Nu intreba ce e inauntru.',
        reward      = 240000,
        level       = 2,
        icon        = 'bag',
        type        = 'reach_location',
        location    = vector3(108.0, -1937.0, 21.2),
        blip        = { sprite = 306, color = 5, label = 'Ridica marfa' },
        target      = 1,
    },

    -- 18
    {
        id          = 18,
        title       = 'Scapa printr-un salt',
        description = 'Cineva te urmareste. Pierde-l facand 2 sarituri spectaculoase cu masina.',
        reward      = 260000,
        level       = 2,
        icon        = 'car',
        type        = 'stunts',
        target      = 2,
        minAirTime  = 700,
    },

    -- 19
    {
        id          = 19,
        title       = 'Prima livrare riscanta',
        description = 'Du coletul la cumparator inainte sa-si piarda rabdarea. Ajunge la locul marcat.',
        reward      = 280000,
        level       = 2,
        icon        = 'map',
        type        = 'reach_location',
        location    = vector3(1148.0, -645.0, 56.0),
        blip        = { sprite = 501, color = 2, label = 'Livrare' },
        target      = 1,
    },

    -- 20
    {
        id          = 20,
        title       = 'Recrutat',
        description = 'Marco, seful retelei, e impresionat. Alatura-te echipei scriind comanda /alaturare.',
        reward      = 300000,
        level       = 2,
        icon        = 'flag',
        type        = 'command',
        command     = 'alaturare',
        target      = 1,
        registerCommand = true,
    },

    ----------------------------------------------------------------------
    --  ACT II - STRADA
    ----------------------------------------------------------------------

    -- 21
    {
        id          = 21,
        title       = 'Masina potrivita',
        description = 'Un curier are nevoie de roti rapide. Fa rost de o masina de strada (sultan, kuruma sau elegy).',
        reward      = 330000,
        level       = 3,
        icon        = 'car',
        type        = 'spawn_vehicle',
        models      = { 'sultan', 'kuruma', 'elegy' },
        target      = 1,
    },

    -- 22
    {
        id          = 22,
        title       = 'Recuperare datorii',
        description = 'Un datornic intarzie cu banii. Mergi la adresa lui si transmite-i mesajul lui Marco.',
        reward      = 360000,
        level       = 3,
        icon        = 'building',
        type        = 'reach_location',
        location    = vector3(-47.0, -1757.0, 29.4),
        blip        = { sprite = 351, color = 1, label = 'Datornic' },
        target      = 1,
    },

    -- 23
    {
        id          = 23,
        title       = 'Avertisment',
        description = 'O banda rivala calca pe teritoriul nostru. Elimina 3 dintre oamenii lor ca avertisment.',
        reward      = 390000,
        level       = 3,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 3,
    },

    -- 24
    {
        id          = 24,
        title       = 'Curse ilegale',
        description = 'Demonstreaza ca esti rapid. Treci printr-un radar de cursa cu cel putin 180 km/h.',
        reward      = 420000,
        level       = 3,
        icon        = 'bolt',
        type        = 'speed_radar',
        minSpeed    = 180,
        radars      = {
            vector3(1954.15, 2473.84, 54.56),
            vector3(2490.23, 5533.91, 44.76),
            vector3(-121.83, 6260.91, 31.16),
        },
        radarRadius = 25.0,
        target      = 1,
    },

    -- 25
    {
        id          = 25,
        title       = 'Spectacol pe roti',
        description = 'Impresioneaza echipa. Reuseste 3 stunturi cu masina (sari si aterizeaza pe roti).',
        reward      = 450000,
        level       = 3,
        icon        = 'car',
        type        = 'stunts',
        target      = 3,
        minAirTime  = 800,
    },

    -- 26
    {
        id          = 26,
        title       = 'Arsenal',
        description = 'E timpul sa te inarmezi. Mergi la Ammu-Nation si obtine prima ta arma adevarata.',
        reward      = 480000,
        level       = 3,
        icon        = 'gun',
        type        = 'obtain_weapon',
        location    = vector3(22.1, -1107.3, 29.8),
        blip        = { sprite = 110, color = 1, label = 'Arsenal' },
        radius      = 30.0,
        target      = 1,
    },

    -- 27
    {
        id          = 27,
        title       = 'Teritoriu',
        description = 'Marcheaza colturile cartierului ca fiind ale noastre. Viziteaza toate punctele marcate.',
        reward      = 510000,
        level       = 3,
        icon        = 'flag',
        type        = 'visit_locations',
        locations   = {
            vector3(96.0, -1916.0, 21.0),
            vector3(8.0, -1858.0, 25.0),
            vector3(123.0, -1853.0, 24.5),
            vector3(-12.0, -1973.0, 22.0),
        },
        blip        = { sprite = 351, color = 2, label = 'Teritoriu' },
    },

    -- 28
    {
        id          = 28,
        title       = 'Jaf la magazin',
        description = 'Da prima ta lovitura. Mergi la magazinul 24/7 marcat pe harta.',
        reward      = 540000,
        level       = 3,
        icon        = 'mask',
        type        = 'reach_location',
        location    = vector3(25.7, -1347.3, 29.5),
        blip        = { sprite = 925, color = 1, label = 'Magazin 24/7' },
        target      = 1,
    },

    -- 29
    {
        id          = 29,
        title       = 'Fuga de politie',
        description = 'Politia e pe urmele tale. Scapa de ei trecand printr-un radar cu peste 160 km/h.',
        reward      = 570000,
        level       = 3,
        icon        = 'bolt',
        type        = 'speed_radar',
        minSpeed    = 160,
        radars      = {
            vector3(195.17, -934.21, 30.69),
            vector3(149.4, -1042.0, 29.4),
            vector3(-47.0, -1757.0, 29.4),
        },
        radarRadius = 30.0,
        target      = 1,
    },

    -- 30
    {
        id          = 30,
        title       = 'Locotenent',
        description = 'Marco te promoveaza. Vino la cartierul general ca sa primesti gradul de locotenent.',
        reward      = 600000,
        level       = 4,
        icon        = 'star',
        type        = 'reach_location',
        location    = vector3(717.0, -962.0, 24.9),
        blip        = { sprite = 40, color = 5, label = 'Cartierul general' },
        target      = 1,
    },

    ----------------------------------------------------------------------
    --  ACT III - CRIMA ORGANIZATA
    ----------------------------------------------------------------------

    -- 31
    {
        id          = 31,
        title       = 'Laboratorul',
        description = 'Reteaua produce marfa proprie. Inspecteaza laboratorul ascuns in desert.',
        reward      = 650000,
        level       = 4,
        icon        = 'flask',
        type        = 'reach_location',
        location    = vector3(1391.0, 3605.0, 38.9),
        blip        = { sprite = 499, color = 2, label = 'Laborator' },
        target      = 1,
    },

    -- 32
    {
        id          = 32,
        title       = 'Transport marfa',
        description = 'Marfa trebuie mutata in cantitati mari. Fa rost de un camion (mule, pounder sau hauler).',
        reward      = 700000,
        level       = 4,
        icon        = 'truck',
        type        = 'spawn_vehicle',
        models      = { 'mule', 'pounder', 'hauler' },
        target      = 1,
    },

    -- 33
    {
        id          = 33,
        title       = 'Ruta de contrabanda',
        description = 'Condu marfa pe toata ruta de contrabanda, de la coasta pana in desert.',
        reward      = 750000,
        level       = 4,
        icon        = 'route',
        type        = 'visit_locations',
        locations   = {
            vector3(-1604.0, -1013.0, 13.0),
            vector3(-337.0, -2559.0, 6.0),
            vector3(1208.0, -2980.0, 6.0),
            vector3(2470.0, 4970.0, 45.5),
            vector3(1697.0, 3759.0, 34.7),
        },
        blip        = { sprite = 514, color = 5, label = 'Punct de contrabanda' },
    },

    -- 34
    {
        id          = 34,
        title       = 'Ambuscada',
        description = 'Rivalii iti intind o capcana pe drum. Supravietuieste si elimina 5 atacatori.',
        reward      = 800000,
        level       = 4,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 5,
    },

    -- 35
    {
        id          = 35,
        title       = 'Spargere',
        description = 'Intra in depozitul rivalilor. Foloseste un lockpick (sperachet) ca sa fortezi usa.',
        reward      = 850000,
        level       = 4,
        icon        = 'key',
        type        = 'use_item',
        items       = { 'lockpick' }, -- schimba cu numele itemului de pe serverul tau
        target      = 1,
        distinct    = false,
    },

    -- 36
    {
        id          = 36,
        title       = 'Banca Fleeca',
        description = 'Echipa pregateste o lovitura mare. Studiaza banca Fleeca din oras.',
        reward      = 900000,
        level       = 4,
        icon        = 'building',
        type        = 'reach_location',
        location    = vector3(149.4, -1042.0, 29.4),
        blip        = { sprite = 107, color = 3, label = 'Banca Fleeca' },
        target      = 1,
    },

    -- 37
    {
        id          = 37,
        title       = 'Masina de evadare',
        description = 'Pentru un jaf ai nevoie de o masina rapida si rezistenta (kuruma, sultan sau elegy).',
        reward      = 950000,
        level       = 4,
        icon        = 'car',
        type        = 'spawn_vehicle',
        models      = { 'kuruma', 'sultan', 'elegy' },
        target      = 1,
    },

    -- 38
    {
        id          = 38,
        title       = 'Lovitura',
        description = 'E ziua cea mare. Intra in banca si sparge seiful.',
        reward      = 1000000,
        level       = 4,
        icon        = 'bag',
        type        = 'reach_location',
        location    = vector3(311.0, -284.0, 54.2),
        blip        = { sprite = 107, color = 5, label = 'Lovitura: Banca' },
        target      = 1,
    },

    -- 39
    {
        id          = 39,
        title       = 'Evadare la mare viteza',
        description = 'Cu banii in portbagaj, scapa de urmaritori. Treci printr-un radar cu peste 200 km/h.',
        reward      = 1050000,
        level       = 4,
        icon        = 'bolt',
        type        = 'speed_radar',
        minSpeed    = 200,
        radars      = {
            vector3(1954.15, 2473.84, 54.56),
            vector3(-1881.98, 4635.98, 57.0),
            vector3(-2685.99, 2445.03, 16.68),
        },
        radarRadius = 25.0,
        target      = 1,
    },

    -- 40
    {
        id          = 40,
        title       = 'Spalare de bani',
        description = 'Banii murdari trebuie albiti. Plimba-i prin toate afacerile de fatada marcate.',
        reward      = 1100000,
        level       = 5,
        icon        = 'coins',
        type        = 'visit_locations',
        locations   = {
            vector3(127.4, -1307.7, 29.2),
            vector3(-1388.0, -587.0, 30.3),
            vector3(-565.2, 276.6, 83.1),
            vector3(925.0, 46.0, 81.1),
        },
        blip        = { sprite = 121, color = 2, label = 'Afacere de fatada' },
    },

    ----------------------------------------------------------------------
    --  ACT IV - RAZBOIUL
    ----------------------------------------------------------------------

    -- 41
    {
        id          = 41,
        title       = 'Tradarea',
        description = 'Marco te cheama la o intalnire ciudata, sus, langa semnul Vinewood. Ceva nu e in regula.',
        reward      = 1200000,
        level       = 5,
        icon        = 'mask',
        type        = 'reach_location',
        location    = vector3(720.0, 1198.0, 348.0),
        blip        = { sprite = 280, color = 1, label = 'Intalnire suspecta' },
        target      = 1,
    },

    -- 42
    {
        id          = 42,
        title       = 'Inarmare',
        description = 'Daca vrei sa supravietuiesti razboiului, inarmeaza-te serios. Obtine o arma grea de la Ammu-Nation din Sandy Shores.',
        reward      = 1300000,
        level       = 5,
        icon        = 'gun',
        type        = 'obtain_weapon',
        location    = vector3(2567.7, 294.4, 108.7),
        blip        = { sprite = 110, color = 1, label = 'Inarmare' },
        radius      = 30.0,
        target      = 1,
    },

    -- 43
    {
        id          = 43,
        title       = 'Recruteaza soldati',
        description = 'Ai nevoie de oameni loiali tie. Aduna recruti din toate colturile statului.',
        reward      = 1400000,
        level       = 5,
        icon        = 'flag',
        type        = 'visit_locations',
        locations   = {
            vector3(96.0, -1916.0, 21.0),
            vector3(1391.0, 3605.0, 38.9),
            vector3(-109.0, 6464.0, 31.6),
            vector3(-1175.0, -888.0, 13.9),
            vector3(2470.0, 4970.0, 45.5),
        },
        blip        = { sprite = 280, color = 5, label = 'Recrut' },
    },

    -- 44
    {
        id          = 44,
        title       = 'Razboi total',
        description = 'Razboiul cu reteaua lui Marco a inceput. Elimina 10 dintre oamenii lui.',
        reward      = 1550000,
        level       = 5,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 10,
    },

    -- 45
    {
        id          = 45,
        title       = 'Asediu',
        description = 'Loveste inima imperiului lui Marco. Ataca vila lui din dealurile Vinewood.',
        reward      = 1700000,
        level       = 5,
        icon        = 'fire',
        type        = 'reach_location',
        location    = vector3(-174.0, 502.0, 137.0),
        blip        = { sprite = 833, color = 1, label = 'Vila lui Marco' },
        target      = 1,
    },

    -- 46
    {
        id          = 46,
        title       = 'Atac fulger',
        description = 'Prinde-i descoperiti. Navaleste in teritoriul lor trecand printr-un radar cu peste 150 km/h.',
        reward      = 1850000,
        level       = 5,
        icon        = 'bolt',
        type        = 'speed_radar',
        minSpeed    = 150,
        radars      = {
            vector3(373.0, 325.0, 103.5),
            vector3(-174.0, 502.0, 137.0),
            vector3(195.17, -934.21, 30.69),
        },
        radarRadius = 35.0,
        target      = 1,
    },

    -- 47
    {
        id          = 47,
        title       = 'Vanatoarea',
        description = 'Marco fuge, dar locotenentii lui inca lupta. Vaneaza 7 dintre ei.',
        reward      = 2000000,
        level       = 5,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 7,
    },

    -- 48
    {
        id          = 48,
        title       = 'Cartierul general',
        description = 'Preia controlul vechiului cartier general. De acum, e al tau.',
        reward      = 2200000,
        level       = 5,
        icon        = 'building',
        type        = 'reach_location',
        location    = vector3(717.0, -962.0, 24.9),
        blip        = { sprite = 40, color = 5, label = 'Cartierul general' },
        target      = 1,
    },

    -- 49
    {
        id          = 49,
        title       = 'Confruntarea finala cu Marco',
        description = 'Marco e incoltit. Termina ce ai inceput: elimina-l intr-un ultim duel.',
        reward      = 2400000,
        level       = 5,
        icon        = 'skull',
        type        = 'kill_players',
        target      = 1,
    },

    -- 50
    {
        id          = 50,
        title       = 'Regele orasului',
        description = 'Tronul e liber, iar orasul iti apartine. Revendica-ti coroana scriind comanda /incoronare.',
        reward      = 2500000,
        level       = 7,
        icon        = 'crown',
        type        = 'command',
        command     = 'incoronare',
        target      = 1,
        registerCommand = true,
    },

    ----------------------------------------------------------------------
    --  ACT V - IMPERIUL
    ----------------------------------------------------------------------

    -- 51
    {
        id          = 51,
        title       = 'Imperiul se extinde',
        description = 'Niciun colt al statului nu mai scapa de tine. Revendica toate teritoriile noi.',
        reward      = 2700000,
        level       = 6,
        icon        = 'map',
        type        = 'visit_locations',
        locations   = {
            vector3(195.17, -934.21, 30.69),
            vector3(-1393.0, -606.0, 30.3),
            vector3(373.0, 325.0, 103.5),
            vector3(1697.0, 3759.0, 34.7),
            vector3(-109.0, 6464.0, 31.6),
            vector3(-337.0, -2559.0, 6.0),
        },
        blip        = { sprite = 439, color = 5, label = 'Teritoriu nou' },
    },

    -- 52
    {
        id          = 52,
        title       = 'Viata de lux',
        description = 'Un rege merita un bolid pe masura. Fa rost de un supercar (adder, zentorno sau t20).',
        reward      = 2900000,
        level       = 6,
        icon        = 'car',
        type        = 'spawn_vehicle',
        models      = { 'adder', 'zentorno', 't20' },
        target      = 1,
    },

    -- 53
    {
        id          = 53,
        title       = 'Cazinoul',
        description = 'Pune mana pe cazinoul Diamond. Mergi acolo si preia afacerea.',
        reward      = 3200000,
        level       = 6,
        icon        = 'diamond',
        type        = 'reach_location',
        location    = vector3(925.0, 46.0, 81.1),
        blip        = { sprite = 679, color = 5, label = 'Cazinoul Diamond' },
        target      = 1,
    },

    -- 54
    {
        id          = 54,
        title       = 'Convoiul blindat',
        description = 'Un convoi blindat transporta o avere. Intercepteaza-l trecand printr-un radar cu peste 170 km/h.',
        reward      = 3500000,
        level       = 6,
        icon        = 'truck',
        type        = 'speed_radar',
        minSpeed    = 170,
        radars      = {
            vector3(2490.23, 5533.91, 44.76),
            vector3(-121.83, 6260.91, 31.16),
            vector3(1954.15, 2473.84, 54.56),
        },
        radarRadius = 25.0,
        target      = 1,
    },

    -- 55
    {
        id          = 55,
        title       = 'Afacere internationala',
        description = 'Cumparatori straini vor sa faca afaceri. Intalneste-i la hangarul de la aeroport.',
        reward      = 3900000,
        level       = 6,
        icon        = 'plane',
        type        = 'reach_location',
        location    = vector3(-1267.0, -3013.0, 13.9),
        blip        = { sprite = 138, color = 3, label = 'Hangar LSIA' },
        target      = 1,
    },

    -- 56
    {
        id          = 56,
        title       = 'Marfa pe apa',
        description = 'Un transport soseste pe mare. Fa rost de o barca rapida (jetmax, dinghy sau marquis).',
        reward      = 4300000,
        level       = 6,
        icon        = 'boat',
        type        = 'spawn_vehicle',
        models      = { 'jetmax', 'dinghy', 'marquis', 'seashark' },
        target      = 1,
    },

    -- 57
    {
        id          = 57,
        title       = 'Ultima tinta',
        description = 'Un informator vrea sa te dea pe mana federalilor. Redu-l la tacere, pe el si pe garzile lui (5 tinte).',
        reward      = 4800000,
        level       = 6,
        icon        = 'eye',
        type        = 'kill_players',
        target      = 5,
    },

    -- 58
    {
        id          = 58,
        title       = 'Curatenie',
        description = 'Nu lasa nicio urma. Mergi la vechiul laborator si distruge toate probele.',
        reward      = 5400000,
        level       = 6,
        icon        = 'fire',
        type        = 'reach_location',
        location    = vector3(1391.0, 3605.0, 38.9),
        blip        = { sprite = 321, color = 1, label = 'Distruge probele' },
        target      = 1,
    },

    -- 59
    {
        id          = 59,
        title       = 'Mostenirea',
        description = 'Priveste tot ce ai cucerit. Fa un tur al imperiului tau, pe la toate locurile cheie.',
        reward      = 6500000,
        level       = 6,
        icon        = 'trophy',
        type        = 'visit_locations',
        locations   = {
            vector3(717.0, -962.0, 24.9),
            vector3(925.0, 46.0, 81.1),
            vector3(-174.0, 502.0, 137.0),
            vector3(1391.0, 3605.0, 38.9),
            vector3(149.4, -1042.0, 29.4),
            vector3(720.0, 1198.0, 348.0),
        },
        blip        = { sprite = 439, color = 5, label = 'Mostenire' },
    },

    -- 60
    {
        id          = 60,
        title       = 'Legenda BlackSilva',
        description = 'De la un nimeni cu o duba veche, la cel mai temut nume din Los Santos. Pecetluieste-ti legenda scriind comanda /legenda.',
        reward      = 10000000,
        level       = 10,
        icon        = 'crown',
        type        = 'command',
        command     = 'legenda',
        target      = 1,
        registerCommand = true,
    },
}
