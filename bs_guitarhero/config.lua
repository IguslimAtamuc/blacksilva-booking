Config = {}

-- ==========================================================================
--  COMENZI
-- ==========================================================================

-- Preia comanda de emote (`/e guitar`) si porneste animatia + minijocul.
-- Resursa TREBUIE pornita DUPA dpemotes / rpemotes in server.cfg,
-- altfel emote-ul ramane cel original si jocul nu mai porneste.
Config.HijackEmoteCommand = true
Config.EmoteCommand       = 'e'          -- comanda interceptata
Config.EmoteAliases       = { 'emote' }  -- alte comenzi de emote de interceptat
Config.EmoteKeyword       = 'guitar'     -- argumentul care declanseaza jocul

-- Comanda catre resursa de emote-uri pentru orice ALT emote decat cel de chitara.
Config.EmoteForwardCommand = 'emote'

-- Comanda proprie, mereu disponibila (functioneaza si fara resursa de emote-uri).
Config.StandaloneCommand = 'guitarhero'

-- ==========================================================================
--  ANIMATIE
-- ==========================================================================

Config.PlayAnimation = true

-- Daca e true, animatia NU e jucata de noi ci lasam resursa de emote-uri
-- sa ruleze `/emote guitar`.
Config.ForwardGuitarToEmoteScript = false

Config.Animation = {
    dict      = 'amb@world_human_musician@guitar@male@base',
    clip      = 'base',
    flag      = 1,              -- 1 = loop
    prop      = 'prop_acc_guitar_01',
    propBone  = 28422,
    propPos   = vector3(0.11, -0.02, -0.05),
    propRot   = vector3(0.0, 0.0, 0.0),
    fallbackScenario = 'WORLD_HUMAN_MUSICIAN',
}

-- ==========================================================================
--  MELODIE
-- ==========================================================================

Config.Song = {
    id      = 'ichwill',
    title   = 'Ich Will',
    artist  = 'Rammstein',
    album   = 'Mutter',
    chart   = 'data/ichwill.json',
    audio   = 'audio/ichwill.mp3',

    -- Fisierul livrat e deja taiat (varianta de videoclip avea ~33 s de intro
    -- de film inaintea melodiei), deci pornim de la 0. Daca pui alt fisier,
    -- de aici sari peste inceputul lui.
    startAt = 0.0,

    -- Cat dureaza o runda completa, in secunde (folosit de server la validare).
    duration = 211.7,
}

-- ==========================================================================
--  HUD (overlay peste joc)
-- ==========================================================================

Config.Hud = {
    anchor    = 'bottom',  -- 'bottom' lasa personajul vizibil deasupra; 'center' = layout-ul din design
    scale     = 1.0,       -- 0.8 = HUD mai mic, 1.2 = mai mare
    highwayVh = 34,        -- inaltimea autostrazii, in % din inaltimea ecranului
    opacity   = 1.0,       -- transparenta intregului HUD
    hints     = true,      -- randul cu ESC / P / calibrare / volum
}

-- ==========================================================================
--  JOC
-- ==========================================================================

-- Bara de energie. Se pierde la note ratate, se recupereaza la note lovite.
Config.Meter = {
    start     = 65.0,   -- 0..100
    max       = 100.0,
    perfect   = 2.2,    -- castig la o nota PERFECT
    good      = 1.2,    -- castig la o nota GOOD
    miss      = 3.0,    -- pierdere la o nota ratata  (~62% acuratete = prag de supravietuire)
    overstrum = 2.0,    -- pierdere la o apasare fara nota
    -- Sub `slowFrom` melodia incepe sa incetineasca, pana la `minRate` la 0.
    slowFrom  = 60.0,
    minRate   = 0.72,
    failAt    = 0.0,    -- sub asta melodia esueaza
}

-- Calibrare audio/video, in milisecunde. Se poate regla si in joc din [ si ]
-- (valoarea se salveaza local, per client).
Config.AudioOffsetMs = 0

-- Volum initial 0..1 (reglabil in joc cu - si +)
Config.Volume = 0.55

-- ==========================================================================
--  RECOMPENSE (server-side, validate)
-- ==========================================================================

Config.Rewards = {
    enabled     = true,
    account     = 'money',      -- 'money' | 'bank' | 'black_money'
    minAccuracy = 0.60,
    base        = 200,
    bonus       = 800,
    fullCombo   = 500,
    cooldown    = 600,          -- secunde intre doua plati, per jucator
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
    already_playing = 'Deja canti la chitara.',
    need_on_foot    = 'Trebuie sa fii pe jos ca sa canti.',
    dead            = 'Nu poti canta acum.',
    started         = 'Ich Will ~y~Rammstein~s~. Sagetile ~b~<- v ^ ->~s~ pe ritm.',
    stopped         = 'Ai lasat chitara jos.',
    failed          = 'Ai ratat prea multe note. ~r~Melodia a esuat~s~.',
    completed       = 'Melodia s-a terminat! Scor: ~g~%s~s~ (%s%% acuratete)',
    reward          = 'Ai primit ~g~$%s~s~ pentru show.',
    reward_cooldown = 'Ai cantat prea recent pentru bani. Mai incearca mai tarziu.',
}
