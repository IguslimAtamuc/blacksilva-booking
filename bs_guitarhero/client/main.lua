-- ============================================================================
--  bs_guitarhero :: client
--  /e guitar  ->  animatie de chitara + Rhythm Highway HUD sincronizat pe mp3
-- ============================================================================

local ESX = nil

CreateThread(function()
    while ESX == nil do
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then
            ESX = obj
        else
            TriggerEvent('esx:getSharedObject', function(obj2) ESX = obj2 end)
        end
        if ESX == nil then Wait(250) end
    end
    _G.ESX = ESX
end)

local function notify(msg)
    if Config.Notify then
        Config.Notify(msg)
    else
        TriggerEvent('esx:showNotification', msg)
    end
end

-- ---------------------------------------------------------------------------
--  Stare
-- ---------------------------------------------------------------------------

local state = {
    playing  = false,  -- animatia de chitara e activa
    inGame   = false,  -- NUI-ul de joc e deschis
    prop     = nil,
    animMode = nil,    -- 'emote' | 'scenario' | 'anim' | 'none'
}

-- ---------------------------------------------------------------------------
--  Animatie + prop
-- ---------------------------------------------------------------------------

local function loadDict(dict, timeoutMs)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 3000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

local function loadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return hash
end

local function attachGuitarProp(ped)
    local a = Config.Animation
    if not a.prop then return end
    local hash = loadModel(a.prop)
    if not hash then return end

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    AttachEntityToEntity(
        obj, ped, GetPedBoneIndex(ped, a.propBone),
        a.propPos.x, a.propPos.y, a.propPos.z,
        a.propRot.x, a.propRot.y, a.propRot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
    state.prop = obj
end

local function removeGuitarProp()
    if state.prop and DoesEntityExist(state.prop) then
        DetachEntity(state.prop, true, true)
        DeleteEntity(state.prop)
    end
    state.prop = nil
end

-- Resursele de emote-uri pe care le cunoastem. Daca una ruleaza, animatia de
-- chitara e luata de la ea -- e cea pe care o vezi la `/e guitar` si are deja
-- prop-ul pozitionat corect in mana.
local EMOTE_RESOURCES = {
    'dpemotes', 'rpemotes', 'rpemotes-reborn', 'dpemotes-reborn',
    'nc-emotes', 'scully_emotemenu',
}

local function findEmoteResource()
    if Config.Animation.emoteResource then
        return Config.Animation.emoteResource
    end
    for _, res in ipairs(EMOTE_RESOURCES) do
        if GetResourceState(res) == 'started' then return res end
    end
    return nil
end

local function startEmoteAnim()
    if not findEmoteResource() then return false end
    ExecuteCommand(('%s %s'):format(Config.EmoteForwardCommand or 'emote', Config.EmoteKeyword))
    state.animMode = 'emote'
    return true
end

local function startScenarioAnim()
    local scenario = Config.Animation.scenario
    if not scenario then return false end
    TaskStartScenarioInPlace(PlayerPedId(), scenario, 0, true)
    state.animMode = 'scenario'
    return true
end

local function startOwnAnim()
    local ped = PlayerPedId()
    local a   = Config.Animation
    if not loadDict(a.dict) then return false end
    TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, a.flag or 1, 0.0, false, false, false)
    RemoveAnimDict(a.dict)
    attachGuitarProp(ped)
    state.animMode = 'anim'
    return true
end

local function startGuitarAnim()
    if not Config.PlayAnimation then
        state.animMode = 'none'
        return true
    end

    -- Ordinea de incercare, in functie de modul cerut. Daca modul preferat nu e
    -- disponibil (de exemplu nu ai nicio resursa de emote-uri), coborim la
    -- urmatorul, ca sa ramai mereu cu o chitara in mana.
    local mode  = Config.Animation.mode or 'emote'
    local chain =
        mode == 'anim'     and { startOwnAnim, startScenarioAnim, startEmoteAnim } or
        mode == 'scenario' and { startScenarioAnim, startEmoteAnim, startOwnAnim } or
                               { startEmoteAnim, startScenarioAnim, startOwnAnim }

    for _, fn in ipairs(chain) do
        if fn() then return true end
    end
    return false
end

local function stopGuitarAnim()
    local ped = PlayerPedId()
    if state.animMode == 'emote' then
        -- `c` e argumentul de anulare din dpemotes / rpemotes; el sterge si prop-ul
        ExecuteCommand(('%s c'):format(Config.EmoteForwardCommand or 'emote'))
    else
        ClearPedTasks(ped)
    end
    removeGuitarProp()
    state.animMode = nil
end

-- ---------------------------------------------------------------------------
--  NUI
-- ---------------------------------------------------------------------------

local function buildPayload()
    return {
        song     = Config.Song,
        hud      = Config.Hud,
        meter    = Config.Meter,
        offsetMs = Config.AudioOffsetMs,
        volume   = Config.Volume,
    }
end

local function openGame()
    state.inGame = true
    SendNUIMessage({ action = 'open', data = buildPayload() })
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(false)
end

local function closeGame()
    if not state.inGame then return end
    state.inGame = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ---------------------------------------------------------------------------
--  Start / stop
-- ---------------------------------------------------------------------------

local function canPlay()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return false, Config.Locale.dead end
    if IsPedInAnyVehicle(ped, false) then return false, Config.Locale.need_on_foot end
    if IsPedSwimming(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) then
        return false, Config.Locale.need_on_foot
    end
    return true
end

function StopGuitarHero(silent)
    if not state.playing then return end
    state.playing = false
    closeGame()
    stopGuitarAnim()
    TriggerServerEvent('bs_guitarhero:abort')
    if not silent then notify(Config.Locale.stopped) end
end

function StartGuitarHero()
    if state.playing then
        notify(Config.Locale.already_playing)
        return
    end

    local ok, reason = canPlay()
    if not ok then
        notify(reason)
        return
    end

    if not startGuitarAnim() then
        notify(Config.Locale.dead)
        return
    end

    state.playing = true
    TriggerServerEvent('bs_guitarhero:begin', Config.Song.id)
    openGame()
    notify(Config.Locale.started)
end

exports('StartGuitarHero', StartGuitarHero)
exports('StopGuitarHero',  StopGuitarHero)
exports('IsPlaying', function() return state.playing end)

RegisterNetEvent('bs_guitarhero:start', function() StartGuitarHero() end)
RegisterNetEvent('bs_guitarhero:stop',  function() StopGuitarHero() end)

-- ---------------------------------------------------------------------------
--  Comenzi
-- ---------------------------------------------------------------------------

local function handleEmoteCommand(_, args, _)
    local first = args[1] and tostring(args[1]):lower() or nil

    if first == Config.EmoteKeyword then
        StartGuitarHero()
        return
    end

    -- orice altceva pleaca mai departe catre resursa de emote-uri
    if Config.EmoteForwardCommand then
        ExecuteCommand(('%s %s'):format(Config.EmoteForwardCommand, table.concat(args, ' ')))
    end
end

CreateThread(function()
    if Config.HijackEmoteCommand then
        RegisterCommand(Config.EmoteCommand, handleEmoteCommand, false)
        for _, alias in ipairs(Config.EmoteAliases or {}) do
            if alias ~= Config.EmoteForwardCommand then
                RegisterCommand(alias, handleEmoteCommand, false)
            end
        end
        TriggerEvent('chat:addSuggestion', '/' .. Config.EmoteCommand,
            'Emote-uri. `' .. Config.EmoteKeyword .. '` porneste minijocul de chitara.',
            {{ name = 'emote', help = 'numele emote-ului (ex: guitar)' }})
    end

    if Config.StandaloneCommand then
        RegisterCommand(Config.StandaloneCommand, function()
            StartGuitarHero()
        end, false)
        TriggerEvent('chat:addSuggestion', '/' .. Config.StandaloneCommand,
            ('Porneste Rhythm Highway (%s - %s)'):format(Config.Song.title, Config.Song.artist), {})
    end

    -- Reglaj live al prop-ului, folositor doar la Config.Animation.mode = 'anim'.
    if Config.Animation.tuneCommand then
        RegisterCommand(Config.Animation.tuneCommand, function(_, args)
            local a = Config.Animation
            local n = {}
            for i = 1, 6 do n[i] = tonumber(args[i]) end
            a.propPos = vector3(n[1] or a.propPos.x, n[2] or a.propPos.y, n[3] or a.propPos.z)
            a.propRot = vector3(n[4] or a.propRot.x, n[5] or a.propRot.y, n[6] or a.propRot.z)

            if state.prop and DoesEntityExist(state.prop) then
                local ped = PlayerPedId()
                AttachEntityToEntity(state.prop, ped, GetPedBoneIndex(ped, a.propBone),
                    a.propPos.x, a.propPos.y, a.propPos.z,
                    a.propRot.x, a.propRot.y, a.propRot.z,
                    true, true, false, true, 1, true)
            end

            print(('[bs_guitarhero] propPos = vector3(%.3f, %.3f, %.3f)  propRot = vector3(%.1f, %.1f, %.1f)')
                :format(a.propPos.x, a.propPos.y, a.propPos.z, a.propRot.x, a.propRot.y, a.propRot.z))
        end, false)
        TriggerEvent('chat:addSuggestion', '/' .. Config.Animation.tuneCommand,
            'Regleaza pozitia chitarei (doar la Config.Animation.mode = \'anim\')',
            {{ name = 'x y z rx ry rz', help = 'ex: 0.11 -0.02 -0.05 0 0 0' }})
    end
end)

-- ---------------------------------------------------------------------------
--  Callbacks din NUI
-- ---------------------------------------------------------------------------

RegisterNUICallback('exit', function(_, cb)
    StopGuitarHero(true)
    cb('ok')
end)

RegisterNUICallback('finished', function(data, cb)
    -- data: { failed, score, accuracy, maxCombo, notesHit, notesTotal }
    TriggerServerEvent('bs_guitarhero:finish', {
        songId     = Config.Song.id,
        failed     = data.failed and true or false,
        score      = tonumber(data.score) or 0,
        accuracy   = tonumber(data.accuracy) or 0,
        maxCombo   = tonumber(data.maxCombo) or 0,
        notesHit   = tonumber(data.notesHit) or 0,
        notesTotal = tonumber(data.notesTotal) or 0,
    })

    if data.failed then
        notify(Config.Locale.failed)
    else
        notify(Config.Locale.completed:format(
            tostring(math.floor(tonumber(data.score) or 0)),
            tostring(math.floor((tonumber(data.accuracy) or 0) * 100))
        ))
    end
    cb('ok')
end)

-- NUI-ul anunta ca a inceput efectiv o runda (si la retry) -> deschidem o sesiune
-- noua pe server, ca validarea de timp sa fie corecta.
RegisterNUICallback('runStarted', function(_, cb)
    TriggerServerEvent('bs_guitarhero:begin', Config.Song.id)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
--  Supraveghere: oprim jocul daca jucatorul moare / urca in masina / e lovit
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        if state.playing then
            local ped = PlayerPedId()
            if IsEntityDead(ped)
               or IsPedInAnyVehicle(ped, false)
               or IsPedRagdoll(ped)
               or IsPedSwimming(ped) then
                StopGuitarHero()
            end
            Wait(300)
        else
            Wait(750)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if state.inGame then SetNuiFocus(false, false) end
    removeGuitarProp()
    if state.playing then ClearPedTasks(PlayerPedId()) end
end)
