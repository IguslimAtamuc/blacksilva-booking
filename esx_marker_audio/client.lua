ESX = nil

CreateThread(function()
    while ESX == nil do
        if exports['es_extended'] then
            ESX = exports['es_extended']:getSharedObject()
        end
        Wait(100)
    end
end)

local isInside     = false   -- daca jucatorul este in cerc
local isPlaying    = false   -- daca audio-ul ruleaza in acest moment

local function debugPrint(msg)
    if Config.Debug then
        print(('[esx_marker_audio] %s'):format(msg))
    end
end

-- Porneste audio-ul prin NUI (player HTML)
local function startAudio()
    if isPlaying then return end
    isPlaying = true
    SendNUIMessage({
        action = 'play',
        file   = Config.Audio.file,
        volume = Config.Audio.volume,
        loop   = Config.Audio.loop
    })
    debugPrint('Audio pornit: ' .. Config.Audio.file)
end

-- Opreste audio-ul
local function stopAudio()
    if not isPlaying then return end
    isPlaying = false
    SendNUIMessage({ action = 'stop' })
    debugPrint('Audio oprit')
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Thread 1: Deseneaza markerul cand jucatorul e in apropiere    ║
-- ╚══════════════════════════════════════════════════════════════╝
CreateThread(function()
    local m = Config.Marker
    while true do
        local sleep = 1000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist   = #(coords - m.coords)

        if dist <= Config.DrawDistance then
            sleep = 0
            DrawMarker(
                m.type,
                m.coords.x, m.coords.y, m.coords.z,
                0.0, 0.0, 0.0,        -- directie
                0.0, 0.0, 0.0,        -- rotatie
                m.size.x, m.size.y, m.size.z,
                m.color.r, m.color.g, m.color.b, m.color.a,
                m.bobUpDown, m.faceCamera, 2, m.rotate,
                nil, nil, false
            )
        end

        Wait(sleep)
    end
end)

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Thread 2: Detecteaza intrarea/iesirea din cerc -> audio       ║
-- ╚══════════════════════════════════════════════════════════════╝
CreateThread(function()
    while true do
        local sleep  = 1000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist   = #(coords - Config.Marker.coords)

        if dist <= Config.DrawDistance then
            sleep = 250
            if dist <= Config.TriggerRadius then
                -- Jucatorul a INTRAT in cerc
                if not isInside then
                    isInside = true
                    debugPrint('Jucator a intrat in cerc')
                    startAudio()
                end
            else
                -- Jucatorul este aproape, dar in afara cercului
                if isInside then
                    isInside = false
                    debugPrint('Jucator a iesit din cerc')
                    if Config.Audio.stopOnLeave then
                        stopAudio()
                    end
                end
            end
        else
            -- Jucatorul e departe
            if isInside then
                isInside = false
                if Config.Audio.stopOnLeave then
                    stopAudio()
                end
            end
        end

        Wait(sleep)
    end
end)

-- Opreste audio-ul daca resursa este oprita
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        stopAudio()
    end
end)
