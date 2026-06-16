Config = {}

-- =====================================================================
--  BLACKSILVA - STORY MODE QUEST ENGINE (ESX)
--  v2.0 - sistem de misiuni interactive: NPC-uri reale, dialoguri chat,
--  props pentru livrari, urmariri reale (NPC + politie), pasi multipli,
--  progres salvat in DB si comanda admin /quest set.
--
--  Framework detectat: es_extended (ESX). Nu se schimba framework-ul.
-- =====================================================================

-- Setari generale -----------------------------------------------------
Config.AdminGroup  = 'admin'      -- grupul ESX care poate folosi /quest set
Config.Command     = 'quest'      -- comanda: /quest, /quest set <nr>
Config.JournalKey  = 'F5'         -- tasta care deschide jurnalul de misiuni
Config.StartQuest  = 1            -- de la ce quest incepe un jucator nou

-- Recompense (cont folosit pentru bani)
Config.RewardAccount = 'money'    -- 'money' (cash) sau 'bank'
Config.ExpCommand    = 'addlevel' -- comanda server pentru XP: <cmd> <serverId> <nr>; '' = dezactivat

-- Inventar (pentru reward.items): 'ox' = ox_inventory, 'esx' = ESX default
Config.Inventory   = 'ox'

-- Markerul folosit pentru obiectivele cu locatie (goto / deliver / etc.)
Config.Marker = {
    type   = 1,
    size   = vector3(1.5, 1.5, 1.0),
    color  = { r = 232, g = 147, b = 12, a = 120 },
    radius = 2.5,         -- distanta default la care se considera "ai ajuns"
    drawDistance = 60.0,  -- de la ce distanta se deseneaza markerul
}

-- Parametri default pentru urmariri (se pot suprascrie pe fiecare pas)
Config.Chase = {
    escapeDistance = 170.0,  -- la ce distanta fata de TOTI urmaritorii esti "scapat"
    escapeTime     = 7000,   -- cat timp (ms) trebuie sa stai departe ca sa scapi
    spawnSpread    = 35.0,   -- la ce distanta in spatele tau apar urmaritorii
}

-- =====================================================================
--  TIPURI DE PASI (step.type) - vezi client/main.lua pentru logica:
--    'dialogue'    -> spawn NPC + dialog chat interactiv (cu optiuni)
--    'goto'        -> mergi la coords (marker+blip); optional inVehicle=true
--    'giveProp'    -> primesti un prop atasat in mana (livrari)
--    'deliverProp' -> predai prop-ul la coords sau la un NPC (apesi E)
--    'getVehicle'  -> spawn vehicul (fura-l/urca-te) -> complet cand intri
--    'chase'       -> NPC-uri te urmaresc real cu masini -> scapa/elimina
--    'policeChase' -> politisti NPC te urmaresc real -> scapa de ei
--    'killTargets' -> elimina X NPC-uri ostile
--    'hideVehicle' -> du vehiculul la o ascunzatoare (marker) si abandoneaza-l
--    'scene'       -> moment narativ (banner cinematic) cu auto-advance
--
--  Camp comun pe orice pas: objective = 'text afisat in HUD'.
-- =====================================================================

-- Helperi locali pentru a scrie config-ul mai usor (NPC/prop reutilizabile)
local PROPS = {
    package  = { model = 'prop_cs_package_01', label = 'Pachet',     bone = 28422, pos = vec3(0.12, 0.0, -0.02),  rot = vec3(0.0, 90.0, 0.0) },
    box      = { model = 'prop_cardbordbox_01', label = 'Cutie',     bone = 28422, pos = vec3(0.20, 0.05, -0.18), rot = vec3(0.0, -90.0, 0.0) },
    bag      = { model = 'p_ld_heist_bag_01',   label = 'Geanta',    bone = 28422, pos = vec3(0.10, 0.0, -0.03),  rot = vec3(0.0, 0.0, 0.0) },
    phone    = { model = 'prop_npc_phone_02',   label = 'Telefon',   bone = 28422, pos = vec3(0.14, 0.02, -0.01), rot = vec3(110.0, 0.0, -90.0) },
    docs     = { model = 'p_amb_clipboard_01',  label = 'Documente', bone = 28422, pos = vec3(0.16, 0.04, 0.0),   rot = vec3(0.0, 0.0, 0.0) },
    case     = { model = 'prop_ld_case_01',     label = 'Valiza',    bone = 28422, pos = vec3(0.10, 0.0, -0.02),  rot = vec3(0.0, 0.0, 0.0) },
}

-- =====================================================================
--  MISIUNILE (story mode). Cheia = questId. Lanteste-le cu nextQuest.
-- =====================================================================
Config.Quests = {

    -- ==================================================================
    -- QUEST 1 - PRIMUL CONTACT
    -- vorbesti cu Marco -> iei pachetul -> conduci spre Sandy Shores ->
    -- esti urmarit -> scapi -> livrezi -> vorbesti cu omul de legatura
    -- ==================================================================
    [1] = {
        id          = 1,
        title       = 'Primul Contact',
        intro       = 'Un nou inceput in Los Santos...',
        description = 'Marco are o slujba pentru tine. Nimic complicat. Inca.',
        reward      = { money = 5000, xp = 1 },
        nextQuest   = 2,
        steps = {
            {
                type      = 'dialogue',
                objective = 'Vorbeste cu Marco',
                npc = {
                    model = 's_m_y_dealer_01',
                    coords = vec4(-47.0, -1757.0, 29.4, 50.0),
                    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
                    blip = { sprite = 280, color = 5, label = 'Marco' },
                },
                dialogue = {
                    npcName = 'Marco',
                    lines = {
                        { who = 'npc',    text = 'Ai intarziat. Stii cum e cu timpul in afacerea asta?' },
                        { who = 'player', text = 'Sunt aici acum. Ce trebuie sa fac?' },
                        { who = 'npc',    text = 'Iei un pachet de la mine si il duci la garajul din Sandy Shores. Fara intrebari.' },
                        { who = 'choice', options = {
                            { text = 'Si daca ma urmareste cineva?', reply = { who = 'npc', text = 'Atunci nu te opri. Conduci si scapi de ei. Simplu.' } },
                            { text = 'Ma descurc.',                  reply = { who = 'npc', text = 'Asa sper. Nu ma face de ras.' } },
                        }},
                        { who = 'npc',    text = 'Hai, ia pachetul si misca.' },
                    },
                },
            },
            {
                type      = 'giveProp',
                objective = 'Ia pachetul de la Marco',
                prop      = PROPS.package,
            },
            {
                type      = 'goto',
                objective = 'Urca intr-un vehicul si porneste spre Sandy Shores',
                coords    = vec3(1390.0, 3597.0, 34.9),
                radius    = 60.0,
                inVehicle = true,
                blip      = { sprite = 477, color = 5, label = 'Sandy Shores' },
            },
            {
                type      = 'chase',
                objective = 'Scapa de urmaritori!',
                escapeDistance = 180.0,
                escapeTime     = 7000,
                chasers = {
                    { model = 'g_m_y_mexgang_01', vehicle = 'sultan',  weapon = 'WEAPON_PISTOL' },
                    { model = 'g_m_y_mexgang_01', vehicle = 'buffalo', weapon = 'WEAPON_PISTOL' },
                },
            },
            {
                type      = 'deliverProp',
                objective = 'Livreaza pachetul la garaj',
                coords    = vec3(1736.5, 3316.5, 41.2),
                radius    = 3.0,
                blip      = { sprite = 477, color = 2, label = 'Livrare' },
            },
            {
                type      = 'dialogue',
                objective = 'Vorbeste cu omul de legatura',
                npc = {
                    model = 'a_m_m_hillbilly_01',
                    coords = vec4(1739.0, 3314.0, 41.2, 200.0),
                    scenario = 'WORLD_HUMAN_SMOKING',
                    blip = { sprite = 280, color = 2, label = 'Contact' },
                },
                dialogue = {
                    npcName = 'Contactul',
                    lines = {
                        { who = 'npc',    text = 'Tu esti omul lui Marco? Ai ajuns intreg, bravo.' },
                        { who = 'player', text = 'Pachetul e al tau. Marco zice sa-l ai.' },
                        { who = 'npc',    text = 'Perfect. O sa auzi de noi. Esti bun, pustiule.' },
                    },
                },
            },
        },
    },

    -- ==================================================================
    -- QUEST 2 - TELEFONUL
    -- primesti telefon -> mergi la locatie -> observi politia ->
    -- furi un vehicul -> scapi de politie -> ascunzi vehiculul
    -- ==================================================================
    [2] = {
        id          = 2,
        title       = 'Telefonul',
        intro       = 'Un apel care schimba totul...',
        description = 'Un job mai serios. De data asta e politie la mijloc.',
        reward      = { money = 9000, xp = 1 },
        nextQuest   = 3,
        steps = {
            {
                type      = 'dialogue',
                objective = 'Raspunde-i lui Vince',
                npc = {
                    model = 'a_m_y_business_01',
                    coords = vec4(195.0, -934.0, 30.7, 145.0),
                    scenario = 'WORLD_HUMAN_STAND_MOBILE',
                    blip = { sprite = 280, color = 5, label = 'Vince' },
                },
                dialogue = {
                    npcName = 'Vince',
                    lines = {
                        { who = 'npc',    text = 'Ia telefonul asta. E curat. Toate ordinele vin pe el.' },
                        { who = 'player', text = 'Si primul ordin?' },
                        { who = 'npc',    text = 'E o masina parcata langa depozit. O vrem. Dar e politie pe zona.' },
                        { who = 'choice', options = {
                            { text = 'Cum scap de politie?', reply = { who = 'npc', text = 'Conduci ca dracu si te pierzi prin oras. Stii tu.' } },
                            { text = 'Fara probleme.',       reply = { who = 'npc', text = 'Asa te vreau.' } },
                        }},
                    },
                },
            },
            {
                type      = 'giveProp',
                objective = 'Ia telefonul',
                prop      = PROPS.phone,
            },
            {
                type      = 'goto',
                objective = 'Mergi la depozit',
                coords    = vec3(961.0, -1670.0, 31.1),
                radius    = 30.0,
                blip      = { sprite = 1, color = 3, label = 'Depozit' },
            },
            {
                type      = 'scene',
                objective = 'Observa politia',
                title     = 'Atentie',
                text      = 'Politia patruleaza zona. Fura masina si nu te lasa prins.',
                duration  = 4500,
            },
            {
                type      = 'getVehicle',
                objective = 'Fura vehiculul',
                model     = 'sentinel',
                coords    = vec4(944.0, -1644.0, 30.9, 90.0),
                blip      = { sprite = 225, color = 5, label = 'Vehicul tinta' },
            },
            {
                type      = 'policeChase',
                objective = 'Scapa de politie!',
                units          = 3,
                escapeDistance = 200.0,
                escapeTime     = 9000,
                wanted         = 2, -- seteaza si nivel de cautare pentru ambianta (optional)
            },
            {
                type      = 'hideVehicle',
                objective = 'Ascunde vehiculul in garaj',
                coords    = vec3(1175.0, 2640.0, 37.8),
                radius    = 5.0,
                blip      = { sprite = 357, color = 2, label = 'Garaj ascuns' },
            },
        },
    },

    -- ==================================================================
    -- QUEST 3 - RAZBOI DE STRADA
    -- dialog -> mergi la teritoriu -> elimina banda rivala -> scapa de ranforsari
    -- ==================================================================
    [3] = {
        id          = 3,
        title       = 'Razboi de Strada',
        intro       = 'Sange pe asfalt...',
        description = 'O banda rivala a calcat pe teritoriul nostru. Trimite un mesaj.',
        reward      = { money = 14000, xp = 2 },
        nextQuest   = 4,
        steps = {
            {
                type      = 'dialogue',
                objective = 'Vorbeste cu Marco',
                npc = {
                    model = 's_m_y_dealer_01',
                    coords = vec4(-47.0, -1757.0, 29.4, 50.0),
                    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
                    blip = { sprite = 280, color = 5, label = 'Marco' },
                },
                dialogue = {
                    npcName = 'Marco',
                    lines = {
                        { who = 'npc',    text = 'Vagos au inceput sa vanda pe strada noastra. Nu putem lasa asa.' },
                        { who = 'player', text = 'Cati sunt?' },
                        { who = 'npc',    text = 'Destui. Du-te in Davis si curata-i. Ia o arma, o sa ai nevoie.' },
                    },
                },
            },
            {
                type      = 'goto',
                objective = 'Mergi in teritoriul Vagos (Davis)',
                coords    = vec3(96.0, -1916.0, 21.0),
                radius    = 30.0,
                blip      = { sprite = 84, color = 1, label = 'Teritoriu Vagos' },
            },
            {
                type      = 'killTargets',
                objective = 'Elimina membrii Vagos',
                count     = 5,
                spawn     = vec3(96.0, -1916.0, 21.0),
                spread    = 18.0,
                model     = 'g_m_y_mexgang_01',
                weapon    = 'WEAPON_PISTOL',
                blip      = { sprite = 84, color = 1, label = 'Vagos' },
            },
            {
                type      = 'chase',
                objective = 'Scapa de ranforsarile Vagos!',
                escapeDistance = 170.0,
                escapeTime     = 6000,
                chasers = {
                    { model = 'g_m_y_mexgang_01', vehicle = 'manana', weapon = 'WEAPON_MICROSMG' },
                    { model = 'g_m_y_mexgang_01', vehicle = 'tornado', weapon = 'WEAPON_PISTOL' },
                },
            },
        },
    },

    -- ==================================================================
    -- QUEST 4 - RECUPERAREA
    -- dialog -> mergi la o casa -> elimina garzile -> ia documentele ->
    -- esti urmarit -> livreaza documentele
    -- ==================================================================
    [4] = {
        id          = 4,
        title       = 'Recuperarea',
        intro       = 'Cineva ne datoreaza ceva...',
        description = 'Un tradator a luat niste documente. Ia-le inapoi.',
        reward      = { money = 20000, xp = 2 },
        nextQuest   = 5,
        steps = {
            {
                type      = 'dialogue',
                objective = 'Vorbeste cu Vince',
                npc = {
                    model = 'a_m_y_business_01',
                    coords = vec4(195.0, -934.0, 30.7, 145.0),
                    scenario = 'WORLD_HUMAN_STAND_MOBILE',
                    blip = { sprite = 280, color = 5, label = 'Vince' },
                },
                dialogue = {
                    npcName = 'Vince',
                    lines = {
                        { who = 'npc',    text = 'Un fost de-al nostru a fugit cu niste documente. Le vrem inapoi.' },
                        { who = 'player', text = 'Unde e?' },
                        { who = 'npc',    text = 'Intr-o casa in dealuri. Are oameni cu el. Fii atent.' },
                        { who = 'choice', options = {
                            { text = 'Ii las in viata?', reply = { who = 'npc', text = 'Fa ce trebuie. Documentele conteaza, nu ei.' } },
                            { text = 'Ma ocup.',         reply = { who = 'npc', text = 'Bun. Adu-le repede.' } },
                        }},
                    },
                },
            },
            {
                type      = 'goto',
                objective = 'Mergi la casa din dealuri',
                coords    = vec3(-174.0, 502.0, 137.0),
                radius    = 25.0,
                blip      = { sprite = 40, color = 1, label = 'Casa tradatorului' },
            },
            {
                type      = 'killTargets',
                objective = 'Elimina garzile',
                count     = 4,
                spawn     = vec3(-174.0, 502.0, 137.0),
                spread    = 12.0,
                model     = 'g_m_m_armboss_01',
                weapon    = 'WEAPON_PISTOL',
                blip      = { sprite = 84, color = 1, label = 'Garda' },
            },
            {
                type      = 'giveProp',
                objective = 'Ia documentele',
                prop      = PROPS.docs,
            },
            {
                type      = 'chase',
                objective = 'Scapa cu documentele!',
                escapeDistance = 180.0,
                escapeTime     = 7000,
                chasers = {
                    { model = 'g_m_m_armboss_01', vehicle = 'baller2', weapon = 'WEAPON_SMG' },
                    { model = 'g_m_m_armboss_01', vehicle = 'kuruma',  weapon = 'WEAPON_PISTOL' },
                },
            },
            {
                type      = 'deliverProp',
                objective = 'Du documentele lui Vince',
                coords    = vec3(195.0, -934.0, 30.7),
                radius    = 3.0,
                blip      = { sprite = 280, color = 2, label = 'Vince' },
            },
        },
    },

    -- ==================================================================
    -- QUEST 5 - ULTIMA LIVRARE
    -- dialog -> ia valiza -> condu spre port -> politia te prinde ->
    -- scapa de politie -> livreaza valiza -> dialog final
    -- ==================================================================
    [5] = {
        id          = 5,
        title       = 'Ultima Livrare',
        intro       = 'Cea mai mare lovitura...',
        description = 'O valiza, o intreaga avere si tot LSPD pe urmele tale.',
        reward      = { money = 50000, xp = 5 },
        nextQuest   = nil, -- ultimul quest din lant
        steps = {
            {
                type      = 'dialogue',
                objective = 'Vorbeste cu Marco',
                npc = {
                    model = 's_m_y_dealer_01',
                    coords = vec4(-47.0, -1757.0, 29.4, 50.0),
                    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
                    blip = { sprite = 280, color = 5, label = 'Marco' },
                },
                dialogue = {
                    npcName = 'Marco',
                    lines = {
                        { who = 'npc',    text = 'Asta e cea mare. Valiza asta valoreaza cat n-ai vazut tu vreodata.' },
                        { who = 'player', text = 'Unde o duc?' },
                        { who = 'npc',    text = 'La port. Dar o sa ai toata politia pe cap. Nu o pierde.' },
                        { who = 'choice', options = {
                            { text = 'Si dupa asta?', reply = { who = 'npc', text = 'Dupa asta esti unul de-al nostru. Pe bune.' } },
                            { text = 'Sa mergem.',    reply = { who = 'npc', text = 'Noroc, pustiule.' } },
                        }},
                    },
                },
            },
            {
                type      = 'giveProp',
                objective = 'Ia valiza',
                prop      = PROPS.case,
            },
            {
                type      = 'goto',
                objective = 'Condu spre port',
                coords    = vec3(338.0, -2715.0, 38.5),
                radius    = 40.0,
                inVehicle = true,
                blip      = { sprite = 410, color = 5, label = 'Portul LS' },
            },
            {
                type      = 'policeChase',
                objective = 'Scapa de politie cu valiza!',
                units          = 4,
                escapeDistance = 220.0,
                escapeTime     = 10000,
                wanted         = 3,
            },
            {
                type      = 'deliverProp',
                objective = 'Livreaza valiza la doc',
                coords    = vec3(266.0, -2967.0, 5.9),
                radius    = 3.5,
                blip      = { sprite = 410, color = 2, label = 'Doc livrare' },
            },
            {
                type      = 'dialogue',
                objective = 'Vorbeste cu cumparatorul',
                npc = {
                    model = 'g_m_m_armboss_01',
                    coords = vec4(268.0, -2970.0, 5.9, 180.0),
                    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
                    blip = { sprite = 280, color = 2, label = 'Cumparator' },
                },
                dialogue = {
                    npcName = 'Cumparatorul',
                    lines = {
                        { who = 'npc',    text = 'Ai reusit. Si cu tot LSPD pe urma. Esti nebun, imi place.' },
                        { who = 'player', text = 'Afacerea e incheiata?' },
                        { who = 'npc',    text = 'Incheiata. De acum, esti o legenda pe strazile astea.' },
                    },
                },
            },
        },
    },
}
