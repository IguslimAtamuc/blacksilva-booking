Config = {}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  CONFIGURARE GENERALA                          ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Distanta de la care se randeaza markerul (optimizare performanta)
Config.DrawDistance = 25.0

-- Activeaza mesajele de debug in consola (F8)
Config.Debug = false

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  CONFIGURARE MARKER                            ║
-- ╚══════════════════════════════════════════════════════════════╝

Config.Marker = {
    type   = 27,                                   -- Tipul markerului (27 = cerc plat)
    coords = vector3(382.4492, -1076.2772, 29.4699), -- Coordonatele markerului

    size = {
        x = 2.0,   -- Latime
        y = 2.0,   -- Lungime
        z = 1.0    -- Inaltime
    },

    -- Culoare ALBA (RGBA, valori 0-255)
    color = {
        r = 255,
        g = 255,
        b = 255,
        a = 150    -- Transparenta (0 = invizibil, 255 = opac)
    },

    rotate    = false,  -- Markerul se roteste
    bobUpDown = false,  -- Markerul se misca sus-jos
    faceCamera = false, -- Markerul se orienteaza spre camera
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  CONFIGURARE ZONA / CERC                       ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Raza cercului in care jucatorul declanseaza audio-ul
Config.TriggerRadius = 2.0

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  CONFIGURARE AUDIO (MP3)                       ║
-- ╚══════════════════════════════════════════════════════════════╝

Config.Audio = {
    -- Numele fisierului MP3 (trebuie pus in folderul html/audio/)
    file = 'audio.mp3',

    -- Volumul audio-ului (0.0 = mut, 1.0 = volum maxim)
    volume = 0.5,

    -- Daca audio-ul se reia automat in bucla cat timp jucatorul e in cerc
    -- false = se reda o singura data, pana la final (NU in bucla)
    loop = false,

    -- Daca true, audio-ul se opreste cand jucatorul iese din cerc
    -- false = audio-ul continua sa ruleze pana se termina, chiar daca iesi din cerc
    stopOnLeave = false,
}
