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
}
