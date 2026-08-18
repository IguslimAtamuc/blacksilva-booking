Config = {}

-- ==========================================================================
--  COMENZI
-- ==========================================================================

-- Preia comanda de emote (`/e guitar`) si porneste animatia + minijocul.
-- Resursa TREBUIE pornita DUPA dpemotes / rpemotes in server.cfg,
-- altfel emote-ul ramane cel original si jocul nu mai porneste.
Config.HijackEmoteCommand = true
Config.EmoteCommand       = 'e'        -- comanda interceptata
Config.EmoteAliases       = { 'emote' }-- alte comenzi de emote de interceptat (poate fi {})
Config.EmoteKeyword       = 'guitar'   -- argumentul care declanseaza jocul

-- Comanda catre resursa de emote-uri pentru orice ALT emote decat cel de chitara.
-- dpemotes / rpemotes inregistreaza atat `/e` cat si `/emote`, deci putem prelua
-- `/e` si trimite restul mai departe la `/emote`.
Config.EmoteForwardCommand = 'emote'

-- Comanda proprie, mereu disponibila (functioneaza si fara resursa de emote-uri).
Config.StandaloneCommand = 'guitarhero'

-- ==========================================================================
--  ANIMATIE
-- ==========================================================================

Config.PlayAnimation = true

-- Daca e true, animatia NU e jucata de noi ci lasam resursa de emote-uri
-- sa ruleze `/emote guitar` (util daca ai deja un emote personalizat de chitara).
Config.ForwardGuitarToEmoteScript = false

Config.Animation = {
    dict      = 'amb@world_human_musician@guitar@male@base',
    clip      = 'base',
    flag      = 1,              -- 1 = loop
    prop      = 'prop_acc_guitar_01',
    propBone  = 28422,
    propPos   = vector3(0.11, -0.02, -0.05),
    propRot   = vector3(0.0, 0.0, 0.0),
    -- daca dictionarul de mai sus nu se incarca, folosim scenariul asta
    fallbackScenario = 'WORLD_HUMAN_MUSICIAN',
}

-- ==========================================================================
--  MINIJOC
-- ==========================================================================

Config.Song = {
    id       = 'faint',
    title    = 'Faint',
    artist   = 'Linkin Park',
    album    = 'Meteora',
    chart    = 'data/faint.json',
    audio    = 'audio/faint.mp3',
    duration = 163.0,           -- secunde (folosit de server la validare)
}

-- Taste pentru cele 5 culoare (cod KeyboardEvent.code din NUI).
Config.Keys = { 'KeyA', 'KeyS', 'KeyD', 'KeyF', 'KeyG' }
-- Taste alternative (aceleasi culoare, in aceeasi ordine).
Config.AltKeys = { 'Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5' }

-- Dificultati: filtreaza notele dupa subdiviziune.
--   0 = doar inceput de masura, 1 = patrimi, 2 = optimi, 3 = tot
-- `missPenalty` stabileste practic acuratetea minima cu care supravietuiesti:
--   prag = missPenalty / (missPenalty + castig_mediu_pe_nota)
Config.Difficulties = {
    { id = 'easy',   name = 'EASY',   maxSub = 1, hitWindow = 0.165, missPenalty = 2.0 }, -- ~50% acuratete
    { id = 'normal', name = 'NORMAL', maxSub = 2, hitWindow = 0.135, missPenalty = 3.0 }, -- ~60%
    { id = 'hard',   name = 'HARD',   maxSub = 3, hitWindow = 0.115, missPenalty = 4.0 }, -- ~67%
    { id = 'expert', name = 'EXPERT', maxSub = 3, hitWindow = 0.090, missPenalty = 5.0 }, -- ~71%
}
Config.DefaultDifficulty = 'normal'

-- Bara de energie ("rock meter").
Config.Meter = {
    start        = 65.0,   -- 0..100
    max          = 100.0,
    perfect      = 2.2,
    great        = 1.4,
    good         = 0.6,
    overstrum    = 2.0,    -- penalizare pentru apasare gresita (fara nota in apropiere)
    -- Sub pragul `slowFrom` melodia incepe sa incetineasca pana la `minRate`
    -- exact la 0. Peste prag ruleaza normal.
    slowFrom     = 60.0,
    minRate      = 0.72,
    failAt       = 0.0,
}

-- Timp de calibrare audio/video, in milisecunde.
-- Poate fi reglat si in joc din tastele [ si ] (se salveaza local, per client).
Config.AudioOffsetMs = 0

-- Cat de departe (in secunde) se vede pe autostrada. Mai mult = note mai lente vizual.
Config.NoteTravelSeconds = 1.55

-- Volum initial 0..1 (reglabil in joc cu - si +)
Config.Volume = 0.55

-- ==========================================================================
--  RECOMPENSE (server-side, validate)
-- ==========================================================================

Config.Rewards = {
    enabled   = true,
    account   = 'money',        -- 'money' | 'bank' | 'black_money'
    -- Se plateste doar daca melodia a fost terminata (nu failed) si acuratetea
    -- e cel putin `minAccuracy`.
    minAccuracy = 0.60,
    -- suma = base + bonus * accuracy
    base      = 150,
    bonus     = 650,
    -- bonus suplimentar pentru Full Combo
    fullCombo = 400,
    -- Multiplicator pe dificultate
    difficultyMult = { easy = 0.5, normal = 1.0, hard = 1.35, expert = 1.75 },
    -- Nu se poate lua recompensa mai des de atat (secunde)
    cooldown  = 600,
}

Config.Notify = function(msg)
    -- inlocuieste cu sistemul tau de notificari daca folosesti altceva
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(msg)
    else
        TriggerEvent('esx:showNotification', msg)
    end
end

Config.Locale = {
    already_playing   = 'Deja canti la chitara.',
    need_on_foot      = 'Trebuie sa fii pe jos ca sa canti.',
    dead              = 'Nu poti canta acum.',
    started           = 'Ai inceput ~y~Faint~s~ - Linkin Park. Apasa ~b~SPACE~s~ pentru start.',
    stopped           = 'Ai lasat chitara jos.',
    failed            = 'Ai ratat prea multe note. ~r~Melodia a esuat~s~.',
    completed         = 'Melodia s-a terminat! Scor: ~g~%s~s~ (%s%% acuratete)',
    reward            = 'Ai primit ~g~$%s~s~ pentru show.',
    reward_cooldown   = 'Ai cantat prea recent pentru bani. Mai incearca mai tarziu.',
}
