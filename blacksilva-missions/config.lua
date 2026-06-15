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

-- =====================================================================
--  ACTIVITATI (50 misiuni in stil 'mergi acolo / ia X / livreaza Y').
--  Se pornesc din meniul F5 (butonul Incepe). Continut original.
--  Recompensa este pe DIFICULTATE (Config.ActivityPayments).
-- =====================================================================

Config.ActivityPayments = {        -- {min, max} bani per dificultate
    EASY    = { 25000, 50000 },
    MEDIUM  = { 50000, 100000 },
    HARD    = { 100000, 200000 },
    ILLEGAL = { 250000, 500000 },
}

Config.ActivityLevel = {           -- niveluri (experienta) per dificultate
    EASY = 1, MEDIUM = 1, HARD = 2, ILLEGAL = 3,
}

Config.ActivityCooldownDefault = 120  -- secunde (repetabila dupa cooldown)

-- Animatii/props implicite per tip (se pot suprascrie pe fiecare activitate)
Config.ActivityDefaults = {
    delivery = { pickupAnim = {"anim@heists@box_carry@", "idle"}, pickupProp = "hei_prop_heist_box", pickupLabel = "Ridica pachetul", deliverAnim = {"mp_common", "givetake1_a"}, deliverLabel = "Livreaza", duration = 2500 },
    collect  = { anim = {"random@domestic", "pickup_low"}, label = "Aduna", duration = 2200 },
    animation= { anim = {"amb@prop_human_movie_bulb@base", "base"}, label = "Lucreaza aici", duration = 3000 },
    photo    = { anim = {"amb@world_human_paparazzi@male@base", "base"}, label = "Fotografiaza", duration = 2500 },
}

Config.Activities = {
    {
        id = 101, title = "Curier Express", icon = "box",
        description = "Ridica pachetul de la depozit si livreaza-l clientilor.",
        difficulty = "EASY", type = "delivery", cooldown = 180,
        pickup = vector3(1701.3000, 6416.0000, 32.8000),
        dropoffs = { vector3(1571.0000, 3604.0000, 35.4000), vector3(-1820.5000, 792.5000, 138.1000) },
    },
    {
        id = 102, title = "Livrare Pizza Nocturna", icon = "box",
        description = "Ia comanda calda si du-o fierbinte la adrese.",
        difficulty = "MEDIUM", type = "delivery", cooldown = 90,
        pickup = vector3(732.0000, -1088.7000, 22.2000),
        dropoffs = { vector3(315.0000, -267.6000, 54.1000), vector3(-561.0000, 288.0000, 82.2000) },
    },
    {
        id = 103, title = "Transport Colete", icon = "box",
        description = "Incarca coletele si distribuie-le pe ruta.",
        difficulty = "HARD", type = "delivery", cooldown = 90,
        pickup = vector3(-446.5000, -129.5000, 38.2000),
        dropoffs = { vector3(-707.5000, -914.2000, 19.2000), vector3(-2096.2000, -320.3000, 13.2000) },
    },
    {
        id = 104, title = "Livrare Flori", icon = "box",
        description = "Du buchetele proaspete la destinatari.",
        difficulty = "EASY", type = "delivery", cooldown = 240,
        pickup = vector3(404.5000, -1023.0000, 29.3000),
        dropoffs = { vector3(2680.0000, 3263.9000, 55.2000) },
    },
    {
        id = 105, title = "Curier Documente", icon = "flag",
        description = "Transporta plicuri confidentiale catre birouri.",
        difficulty = "ILLEGAL", type = "delivery", cooldown = 90,
        pickup = vector3(-1108.0000, 2696.5000, 18.6000),
        dropoffs = { vector3(-1820.5000, 792.5000, 138.1000), vector3(-1681.0000, -1066.0000, 13.2000), vector3(620.8000, 2779.5000, 42.1000) },
    },
    {
        id = 106, title = "Livrare Farmacie", icon = "box",
        description = "Du medicamentele la pacientii care le asteapta.",
        difficulty = "MEDIUM", type = "delivery", cooldown = 120,
        pickup = vector3(-1095.0000, -1690.0000, 4.4000),
        dropoffs = { vector3(-1681.0000, -1066.0000, 13.2000), vector3(-1820.5000, 792.5000, 138.1000), vector3(1224.0000, -1473.0000, 35.0000), vector3(-1393.0000, -606.6000, 30.3000) },
    },
    {
        id = 107, title = "Distributie Ziare", icon = "flag",
        description = "Imparte ziarele de dimineata in cartier.",
        difficulty = "HARD", type = "delivery", cooldown = 90,
        pickup = vector3(1392.5000, 3604.5000, 34.9000),
        dropoffs = { vector3(1224.0000, -1473.0000, 35.0000), vector3(2557.4000, 384.0000, 108.6000) },
    },
    {
        id = 108, title = "Livrare Cofetarie", icon = "box",
        description = "Transporta prajiturile fragile fara sa le strici.",
        difficulty = "EASY", type = "delivery", cooldown = 180,
        pickup = vector3(404.5000, -1023.0000, 29.3000),
        dropoffs = { vector3(-1108.0000, 2696.5000, 18.6000) },
    },
    {
        id = 109, title = "Transport Marfa", icon = "car",
        description = "Muta marfa intre depozite cat mai repede.",
        difficulty = "ILLEGAL", type = "delivery", cooldown = 90,
        pickup = vector3(1224.0000, -1473.0000, 35.0000),
        dropoffs = { vector3(-1108.0000, 2696.5000, 18.6000), vector3(-1437.5000, -276.7000, 46.2000), vector3(1163.0000, -323.8000, 69.2000) },
    },
    {
        id = 110, title = "Curier Bijuterii", icon = "coins",
        description = "Livreaza colete de valoare sub paza ta.",
        difficulty = "ILLEGAL", type = "delivery", cooldown = 300,
        pickup = vector3(1224.0000, -1473.0000, 35.0000),
        dropoffs = { vector3(-3039.6000, 585.0000, 7.9000), vector3(315.0000, -267.6000, 54.1000), vector3(1163.0000, -323.8000, 69.2000), vector3(-1108.0000, 2696.5000, 18.6000) },
    },
    {
        id = 111, title = "Livrare Bauturi", icon = "bottle",
        description = "Aprovizioneaza barurile cu lazi de bauturi.",
        difficulty = "MEDIUM", type = "delivery", cooldown = 90,
        pickup = vector3(1224.0000, -1473.0000, 35.0000),
        dropoffs = { vector3(-1095.0000, -1690.0000, 4.4000), vector3(-3144.0000, 1127.0000, 20.8000) },
    },
    {
        id = 112, title = "Posta Rapida", icon = "flag",
        description = "Distribuie corespondenta pe tot orasul.",
        difficulty = "EASY", type = "delivery", cooldown = 240,
        pickup = vector3(-1166.0000, 4926.0000, 224.2000),
        dropoffs = { vector3(372.5000, 326.5000, 103.6000), vector3(155.4000, 6641.9000, 31.9000) },
    },
    {
        id = 113, title = "Livrare Electronice", icon = "box",
        description = "Du pachetele cu electronice la magazine.",
        difficulty = "MEDIUM", type = "delivery", cooldown = 300,
        pickup = vector3(155.4000, 6641.9000, 31.9000),
        dropoffs = { vector3(-1305.4000, -394.6000, 36.7000), vector3(2680.0000, 3263.9000, 55.2000), vector3(-1437.5000, -276.7000, 46.2000) },
    },
    {
        id = 114, title = "Catering Eveniment", icon = "box",
        description = "Transporta platourile la locatia evenimentului.",
        difficulty = "HARD", type = "delivery", cooldown = 120,
        pickup = vector3(-2096.2000, -320.3000, 13.2000),
        dropoffs = { vector3(372.5000, 326.5000, 103.6000), vector3(732.0000, -1088.7000, 22.2000), vector3(-446.5000, -129.5000, 38.2000), vector3(147.6000, -1035.9000, 29.3000) },
    },
    {
        id = 115, title = "Curier Mancare", icon = "box",
        description = "Livreaza prânzul la birourile din centru.",
        difficulty = "EASY", type = "delivery", cooldown = 240,
        pickup = vector3(-538.2000, -854.2000, 29.2000),
        dropoffs = { vector3(620.8000, 2779.5000, 42.1000) },
    },
    {
        id = 116, title = "Livrare Panificatie", icon = "box",
        description = "Du painea calda la magazinele de cartier.",
        difficulty = "MEDIUM", type = "delivery", cooldown = 300,
        pickup = vector3(404.5000, -1023.0000, 29.3000),
        dropoffs = { vector3(-628.6000, -237.5000, 38.1000), vector3(1701.3000, 6416.0000, 32.8000) },
    },
    {
        id = 117, title = "Transport Piese Auto", icon = "wrench",
        description = "Aproviziona service-urile cu piese.",
        difficulty = "HARD", type = "delivery", cooldown = 240,
        pickup = vector3(404.5000, -1023.0000, 29.3000),
        dropoffs = { vector3(-1166.0000, 4926.0000, 224.2000), vector3(1135.8000, -982.3000, 46.2000) },
    },
    {
        id = 118, title = "Livrare Cadouri", icon = "box",
        description = "Surprinde clientii cu pachetele cadou.",
        difficulty = "EASY", type = "delivery", cooldown = 300,
        pickup = vector3(1224.0000, -1473.0000, 35.0000),
        dropoffs = { vector3(-628.6000, -237.5000, 38.1000), vector3(147.6000, -1035.9000, 29.3000) },
    },
    {
        id = 119, title = "Strange Gunoaie", icon = "box",
        description = "Aduna gunoaiele lasate prin parc.",
        difficulty = "MEDIUM", type = "collect", cooldown = 240,
        points = { vector3(155.4000, 6641.9000, 31.9000), vector3(1135.8000, -982.3000, 46.2000), vector3(-2096.2000, -320.3000, 13.2000), vector3(816.3000, -1284.2000, 26.3000), vector3(1986.5000, 3052.5000, 47.2000), vector3(1571.0000, 3604.0000, 35.4000) },
    },
    {
        id = 120, title = "Colectare Sticle", icon = "bottle",
        description = "Strange sticlele goale pentru reciclare.",
        difficulty = "EASY", type = "collect", cooldown = 90,
        points = { vector3(2553.0000, 2607.0000, 37.9000), vector3(1224.0000, -1473.0000, 35.0000), vector3(-1166.0000, 4926.0000, 224.2000), vector3(-78.4000, 6422.0000, 31.5000) },
    },
    {
        id = 121, title = "Cules Fructe", icon = "box",
        description = "Culege fructele coapte din livada.",
        difficulty = "MEDIUM", type = "collect", cooldown = 180,
        points = { vector3(-1224.6000, -906.2000, 12.3000), vector3(1571.0000, 3604.0000, 35.4000), vector3(147.6000, -1035.9000, 29.3000), vector3(25.0000, -1347.3000, 29.5000), vector3(155.4000, 6641.9000, 31.9000), vector3(2553.0000, 2607.0000, 37.9000) },
    },
    {
        id = 122, title = "Adunare Fier Vechi", icon = "wrench",
        description = "Strange fierul vechi din santier.",
        difficulty = "HARD", type = "collect", cooldown = 120,
        points = { vector3(620.8000, 2779.5000, 42.1000), vector3(1729.0000, 6418.0000, 35.0000), vector3(-1820.5000, 792.5000, 138.1000), vector3(-3144.0000, 1127.0000, 20.8000), vector3(-538.2000, -854.2000, 29.2000), vector3(2557.4000, 384.0000, 108.6000) },
    },
    {
        id = 123, title = "Cautare Comori", icon = "coins",
        description = "Gaseste obiectele ascunse pe plaja.",
        difficulty = "ILLEGAL", type = "collect", cooldown = 120,
        points = { vector3(-1393.0000, -606.6000, 30.3000), vector3(1729.0000, 6418.0000, 35.0000), vector3(-2096.2000, -320.3000, 13.2000), vector3(179.8000, -1568.0000, 29.3000), vector3(-78.4000, 6422.0000, 31.5000) },
    },
    {
        id = 124, title = "Recoltare Plante", icon = "box",
        description = "Recolteaza plantele de la ferma.",
        difficulty = "EASY", type = "collect", cooldown = 240,
        points = { vector3(2557.4000, 384.0000, 108.6000), vector3(-260.0000, -2014.0000, 30.2000), vector3(-1108.0000, 2696.5000, 18.6000), vector3(816.3000, -1284.2000, 26.3000) },
    },
    {
        id = 125, title = "Colectare Scoici", icon = "box",
        description = "Aduna scoicile de pe tarm.",
        difficulty = "MEDIUM", type = "collect", cooldown = 240,
        points = { vector3(-1166.0000, 4926.0000, 224.2000), vector3(-1224.6000, -906.2000, 12.3000), vector3(1392.5000, 3604.5000, 34.9000), vector3(1701.3000, 6416.0000, 32.8000), vector3(-2096.2000, -320.3000, 13.2000) },
    },
    {
        id = 126, title = "Strangere Doze", icon = "bottle",
        description = "Strange dozele de aluminiu de pe strada.",
        difficulty = "HARD", type = "collect", cooldown = 120,
        points = { vector3(1392.5000, 3604.5000, 34.9000), vector3(1571.0000, 3604.0000, 35.4000), vector3(-48.5000, -1757.5000, 29.4000), vector3(1729.0000, 6418.0000, 35.0000) },
    },
    {
        id = 127, title = "Recuperare Pachete", icon = "box",
        description = "Recupereaza pachetele pierdute pe ruta.",
        difficulty = "EASY", type = "collect", cooldown = 120,
        points = { vector3(-538.2000, -854.2000, 29.2000), vector3(-48.5000, -1757.5000, 29.4000), vector3(1701.3000, 6416.0000, 32.8000), vector3(404.5000, -1023.0000, 29.3000) },
    },
    {
        id = 128, title = "Cules Ciuperci", icon = "box",
        description = "Culege ciupercile din padure.",
        difficulty = "MEDIUM", type = "collect", cooldown = 180,
        points = { vector3(1224.0000, -1473.0000, 35.0000), vector3(372.5000, 326.5000, 103.6000), vector3(2557.4000, 384.0000, 108.6000), vector3(-446.5000, -129.5000, 38.2000), vector3(902.0000, -1530.0000, 30.5000), vector3(-1820.5000, 792.5000, 138.1000) },
    },
    {
        id = 129, title = "Colectare Anvelope", icon = "wrench",
        description = "Aduna anvelopele uzate din depozit.",
        difficulty = "EASY", type = "collect", cooldown = 240,
        points = { vector3(-1393.0000, -606.6000, 30.3000), vector3(1163.0000, -323.8000, 69.2000), vector3(1986.5000, 3052.5000, 47.2000), vector3(-1095.0000, -1690.0000, 4.4000) },
    },
    {
        id = 130, title = "Adunare Lemne", icon = "box",
        description = "Strange lemnele taiate din curte.",
        difficulty = "MEDIUM", type = "collect", cooldown = 240,
        points = { vector3(-3039.6000, 585.0000, 7.9000), vector3(1135.8000, -982.3000, 46.2000), vector3(-3144.0000, 1127.0000, 20.8000), vector3(-78.4000, 6422.0000, 31.5000) },
    },
    {
        id = 131, title = "Gradinarit Urban", icon = "wrench",
        description = "Ai grija de spatiile verzi din oras.",
        difficulty = "HARD", type = "animation", cooldown = 120,
        points = { vector3(-628.6000, -237.5000, 38.1000), vector3(-561.0000, 288.0000, 82.2000), vector3(-1820.5000, 792.5000, 138.1000), vector3(1163.0000, -323.8000, 69.2000) },
    },
    {
        id = 132, title = "Spalare Vehicule", icon = "car",
        description = "Spala masinile parcate la cerere.",
        difficulty = "EASY", type = "animation", cooldown = 90,
        points = { vector3(732.0000, -1088.7000, 22.2000), vector3(1163.0000, -323.8000, 69.2000), vector3(315.0000, -267.6000, 54.1000) },
    },
    {
        id = 133, title = "Reparatii Stradale", icon = "wrench",
        description = "Repara micile defecte de pe trotuar.",
        difficulty = "MEDIUM", type = "animation", cooldown = 90,
        points = { vector3(-3144.0000, 1127.0000, 20.8000), vector3(902.0000, -1530.0000, 30.5000), vector3(-1224.6000, -906.2000, 12.3000), vector3(1701.3000, 6416.0000, 32.8000) },
    },
    {
        id = 134, title = "Curatenie Parc", icon = "wrench",
        description = "Fa curatenie in zonele de relaxare.",
        difficulty = "HARD", type = "animation", cooldown = 180,
        points = { vector3(-561.0000, 288.0000, 82.2000), vector3(315.0000, -267.6000, 54.1000), vector3(1986.5000, 3052.5000, 47.2000), vector3(620.8000, 2779.5000, 42.1000), vector3(1729.0000, 6418.0000, 35.0000) },
    },
    {
        id = 135, title = "Ingrijire Flori", icon = "flag",
        description = "Uda si aranjeaza florile din ghivece.",
        difficulty = "EASY", type = "animation", cooldown = 240,
        points = { vector3(1986.5000, 3052.5000, 47.2000), vector3(-1305.4000, -394.6000, 36.7000), vector3(-2096.2000, -320.3000, 13.2000), vector3(1701.3000, 6416.0000, 32.8000) },
    },
    {
        id = 136, title = "Mecanic Ambulant", icon = "wrench",
        description = "Verifica vehiculele defecte din zona.",
        difficulty = "MEDIUM", type = "animation", cooldown = 90,
        points = { vector3(-628.6000, -237.5000, 38.1000), vector3(263.9000, -1261.5000, 29.4000), vector3(1986.5000, 3052.5000, 47.2000), vector3(179.8000, -1568.0000, 29.3000), vector3(480.5000, -1314.5000, 29.2000), vector3(25.0000, -1347.3000, 29.5000) },
    },
    {
        id = 137, title = "Vopsire Garduri", icon = "wrench",
        description = "Da o mana de vopsea gardurilor.",
        difficulty = "EASY", type = "animation", cooldown = 120,
        points = { vector3(1701.3000, 6416.0000, 32.8000), vector3(732.0000, -1088.7000, 22.2000), vector3(25.0000, -1347.3000, 29.5000), vector3(480.5000, -1314.5000, 29.2000) },
    },
    {
        id = 138, title = "Hranire Animale", icon = "flag",
        description = "Hraneste animalele de la ferma.",
        difficulty = "MEDIUM", type = "animation", cooldown = 180,
        points = { vector3(-2096.2000, -320.3000, 13.2000), vector3(263.9000, -1261.5000, 29.4000), vector3(480.5000, -1314.5000, 29.2000), vector3(315.0000, -267.6000, 54.1000), vector3(179.8000, -1568.0000, 29.3000), vector3(147.6000, -1035.9000, 29.3000) },
    },
    {
        id = 139, title = "Montaj Afise", icon = "flag",
        description = "Lipeste afisele pe panourile orasului.",
        difficulty = "HARD", type = "animation", cooldown = 120,
        points = { vector3(732.0000, -1088.7000, 22.2000), vector3(-446.5000, -129.5000, 38.2000), vector3(-628.6000, -237.5000, 38.1000), vector3(-1095.0000, -1690.0000, 4.4000), vector3(1392.5000, 3604.5000, 34.9000), vector3(-3039.6000, 585.0000, 7.9000) },
    },
    {
        id = 140, title = "Lustruire Statui", icon = "wrench",
        description = "Lustruieste statuile din centru.",
        difficulty = "EASY", type = "animation", cooldown = 120,
        points = { vector3(1392.5000, 3604.5000, 34.9000), vector3(-3039.6000, 585.0000, 7.9000), vector3(480.5000, -1314.5000, 29.2000), vector3(1729.0000, 6418.0000, 35.0000) },
    },
    {
        id = 141, title = "Verificare Hidranti", icon = "wrench",
        description = "Verifica hidrantii din cartier.",
        difficulty = "MEDIUM", type = "animation", cooldown = 180,
        points = { vector3(25.0000, -1347.3000, 29.5000), vector3(-1166.0000, 4926.0000, 224.2000), vector3(816.3000, -1284.2000, 26.3000), vector3(1986.5000, 3052.5000, 47.2000), vector3(263.9000, -1261.5000, 29.4000), vector3(-3039.6000, 585.0000, 7.9000) },
    },
    {
        id = 142, title = "Aranjare Marfa", icon = "box",
        description = "Aranjeaza marfa pe rafturile magazinelor.",
        difficulty = "HARD", type = "animation", cooldown = 180,
        points = { vector3(147.6000, -1035.9000, 29.3000), vector3(315.0000, -267.6000, 54.1000), vector3(-2096.2000, -320.3000, 13.2000), vector3(1392.5000, 3604.5000, 34.9000), vector3(1163.0000, -323.8000, 69.2000) },
    },
    {
        id = 143, title = "Fotografie Turistica", icon = "camera",
        description = "Fotografiaza obiectivele turistice.",
        difficulty = "EASY", type = "photo", cooldown = 120,
        points = { vector3(-3039.6000, 585.0000, 7.9000), vector3(-628.6000, -237.5000, 38.1000), vector3(-3144.0000, 1127.0000, 20.8000), vector3(1986.5000, 3052.5000, 47.2000) },
    },
    {
        id = 144, title = "Foto Imobiliare", icon = "camera",
        description = "Fa poze caselor scoase la vanzare.",
        difficulty = "MEDIUM", type = "photo", cooldown = 90,
        points = { vector3(2553.0000, 2607.0000, 37.9000), vector3(147.6000, -1035.9000, 29.3000), vector3(-2096.2000, -320.3000, 13.2000), vector3(1571.0000, 3604.0000, 35.4000), vector3(620.8000, 2779.5000, 42.1000) },
    },
    {
        id = 145, title = "Reportaj Fauna", icon = "camera",
        description = "Fotografiaza animalele salbatice.",
        difficulty = "EASY", type = "photo", cooldown = 240,
        points = { vector3(1986.5000, 3052.5000, 47.2000), vector3(-1437.5000, -276.7000, 46.2000), vector3(-260.0000, -2014.0000, 30.2000) },
    },
    {
        id = 146, title = "Fotografie Auto", icon = "camera",
        description = "Fa poze masinilor de epoca expuse.",
        difficulty = "MEDIUM", type = "photo", cooldown = 180,
        points = { vector3(-1393.0000, -606.6000, 30.3000), vector3(155.4000, 6641.9000, 31.9000), vector3(-2096.2000, -320.3000, 13.2000), vector3(179.8000, -1568.0000, 29.3000) },
    },
    {
        id = 147, title = "Foto Peisaj", icon = "camera",
        description = "Surprinde cele mai frumoase peisaje.",
        difficulty = "HARD", type = "photo", cooldown = 120,
        points = { vector3(25.0000, -1347.3000, 29.5000), vector3(1701.3000, 6416.0000, 32.8000), vector3(-1681.0000, -1066.0000, 13.2000), vector3(155.4000, 6641.9000, 31.9000) },
    },
    {
        id = 148, title = "Paparazzi", icon = "camera",
        description = "Prinde cadrele exclusive prin oras.",
        difficulty = "ILLEGAL", type = "photo", cooldown = 120,
        points = { vector3(-561.0000, 288.0000, 82.2000), vector3(1986.5000, 3052.5000, 47.2000), vector3(147.6000, -1035.9000, 29.3000), vector3(1701.3000, 6416.0000, 32.8000), vector3(-1108.0000, 2696.5000, 18.6000), vector3(902.0000, -1530.0000, 30.5000) },
    },
    {
        id = 149, title = "Foto Graffiti", icon = "camera",
        description = "Documenteaza arta stradala.",
        difficulty = "EASY", type = "photo", cooldown = 120,
        points = { vector3(-48.5000, -1757.5000, 29.4000), vector3(2553.0000, 2607.0000, 37.9000), vector3(1163.0000, -323.8000, 69.2000) },
    },
    {
        id = 150, title = "Documentar Oras", icon = "camera",
        description = "Realizeaza un documentar foto al orasului.",
        difficulty = "MEDIUM", type = "photo", cooldown = 120,
        points = { vector3(-3039.6000, 585.0000, 7.9000), vector3(-3144.0000, 1127.0000, 20.8000), vector3(25.0000, -1347.3000, 29.5000), vector3(263.9000, -1261.5000, 29.4000), vector3(-538.2000, -854.2000, 29.2000) },
    },
}
