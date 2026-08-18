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
    playing   = false,   -- animatia de chitara e activa
    inGame    = false,   -- NUI-ul de joc e deschis
    prop      = nil,
    difficulty= Config.DefaultDifficulty,
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

local function startGuitarAnim()
    if not Config.PlayAnimation then return true end

    if Config.ForwardGuitarToEmoteScript and Config.EmoteForwardCommand then
        ExecuteCommand(('%s %s'):format(Config.EmoteForwardCommand, Config.EmoteKeyword))
        return true
    end

    local ped = PlayerPedId()
    local a   = Config.Animation

    if loadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, a.flag or 1, 0.0, false, false, false)
        RemoveAnimDict(a.dict)
    elseif a.fallbackScenario then
        TaskStartScenarioInPlace(ped, a.fallbackScenario, 0, true)
    else
        return false
    end

    attachGuitarProp(ped)
    return true
end

local function stopGuitarAnim()
    local ped = PlayerPedId()
    if Config.ForwardGuitarToEmoteScript then
        ExecuteCommand('e c') -- comanda standard de "cancel emote" din dpemotes/rpemotes
    else
        ClearPedTasks(ped)
    end
    removeGuitarProp()
end

-- ---------------------------------------------------------------------------
--  NUI
-- ---------------------------------------------------------------------------

local function buildPayload()
    return {
        song        = Config.Song,
        keys        = Config.Keys,
        altKeys     = Config.AltKeys,
        difficulties= Config.Difficulties,
        difficulty  = state.difficulty,
        meter       = Config.Meter,
        travel      = Config.NoteTravelSeconds,
        offsetMs    = Config.AudioOffsetMs,
        volume      = Config.Volume,
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

function StartGuitarHero(difficulty)
    if state.playing then
        notify(Config.Locale.already_playing)
        return
    end

    local ok, reason = canPlay()
    if not ok then
        notify(reason)
        return
    end

    if difficulty then state.difficulty = difficulty end

    if not startGuitarAnim() then
        notify(Config.Locale.dead)
        return
    end

    state.playing = true
    openGame()
    notify(Config.Locale.started)
end

exports('StartGuitarHero', StartGuitarHero)
exports('StopGuitarHero',  StopGuitarHero)
exports('IsPlaying', function() return state.playing end)

RegisterNetEvent('bs_guitarhero:start', function(difficulty) StartGuitarHero(difficulty) end)
RegisterNetEvent('bs_guitarhero:stop',  function() StopGuitarHero() end)

-- ---------------------------------------------------------------------------
--  Comenzi
-- ---------------------------------------------------------------------------

local function handleEmoteCommand(_, args, _)
    local first = args[1] and tostring(args[1]):lower() or nil

    if first == Config.EmoteKeyword then
        StartGuitarHero(args[2])
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
        RegisterCommand(Config.StandaloneCommand, function(_, args)
            StartGuitarHero(args[1])
        end, false)
        TriggerEvent('chat:addSuggestion', '/' .. Config.StandaloneCommand,
            'Porneste Rhythm Highway (Faint - Linkin Park)',
            {{ name = 'dificultate', help = 'easy | normal | hard | expert' }})
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
    -- data: { failed, score, accuracy, maxCombo, notesHit, notesTotal, difficulty }
    TriggerServerEvent('bs_guitarhero:finish', {
        songId     = Config.Song.id,
        failed     = data.failed and true or false,
        score      = tonumber(data.score) or 0,
        accuracy   = tonumber(data.accuracy) or 0,
        maxCombo   = tonumber(data.maxCombo) or 0,
        notesHit   = tonumber(data.notesHit) or 0,
        notesTotal = tonumber(data.notesTotal) or 0,
        difficulty = tostring(data.difficulty or state.difficulty),
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

RegisterNUICallback('setDifficulty', function(data, cb)
    if data and data.difficulty then state.difficulty = tostring(data.difficulty) end
    cb('ok')
end)

-- NUI-ul anunta ca a inceput efectiv o runda (si la retry) -> deschidem o sesiune
-- noua pe server, ca validarea de timp sa fie corecta.
RegisterNUICallback('runStarted', function(data, cb)
    if data and data.difficulty then state.difficulty = tostring(data.difficulty) end
    TriggerServerEvent('bs_guitarhero:begin', Config.Song.id, state.difficulty)
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
