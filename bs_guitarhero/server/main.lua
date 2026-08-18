-- ============================================================================
--  bs_guitarhero :: server
--  Valideaza rezultatul minijocului si plateste recompensa (ESX).
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
end)

-- sesiuni active: [src] = { songId, difficulty, startedAt }
local sessions = {}
-- ultima plata: [identifier] = os.time()
local lastReward = {}

local function difficultyMultiplier(id)
    local m = Config.Rewards.difficultyMult or {}
    return tonumber(m[id]) or 1.0
end

local function isKnownDifficulty(id)
    for _, d in ipairs(Config.Difficulties) do
        if d.id == id then return true end
    end
    return false
end

RegisterNetEvent('bs_guitarhero:begin', function(songId, difficulty)
    local src = source
    if songId ~= Config.Song.id then return end
    if not isKnownDifficulty(difficulty) then difficulty = Config.DefaultDifficulty end

    sessions[src] = {
        songId     = songId,
        difficulty = difficulty,
        startedAt  = os.time(),
    }
end)

RegisterNetEvent('bs_guitarhero:abort', function()
    sessions[source] = nil
end)

RegisterNetEvent('bs_guitarhero:finish', function(payload)
    local src = source
    local session = sessions[src]
    sessions[src] = nil

    if type(payload) ~= 'table' then return end
    if not session then return end
    if payload.songId ~= session.songId then return end

    -- --- validare de baza --------------------------------------------------
    local notesTotal = math.floor(tonumber(payload.notesTotal) or 0)
    local notesHit   = math.floor(tonumber(payload.notesHit) or 0)
    local score      = math.floor(tonumber(payload.score) or 0)
    local maxCombo   = math.floor(tonumber(payload.maxCombo) or 0)
    local accuracy   = tonumber(payload.accuracy) or 0.0
    local failed     = payload.failed and true or false

    if notesTotal <= 0 or notesTotal > 5000 then return end
    if notesHit < 0 or notesHit > notesTotal then return end
    if maxCombo < 0 or maxCombo > notesTotal then return end
    if accuracy < 0.0 or accuracy > 1.0 then return end

    -- scor maxim teoretic: 100 puncte * multiplicator 4 pe nota
    local maxScore = notesTotal * 100 * 4
    if score < 0 or score > maxScore then
        print(('[bs_guitarhero] scor invalid de la %s (%d / max %d)'):format(GetPlayerName(src) or src, score, maxScore))
        return
    end

    -- acuratetea raportata trebuie sa se potriveasca cu notele lovite
    local expected = notesHit / notesTotal
    if math.abs(expected - accuracy) > 0.05 then return end

    if not Config.Rewards.enabled then return end
    if failed then return end

    -- melodia trebuie sa fi rulat cel putin ~85% din durata reala
    local elapsed = os.time() - session.startedAt
    if elapsed < math.floor(Config.Song.duration * 0.85) then
        print(('[bs_guitarhero] finish prea rapid de la %s (%ds)'):format(GetPlayerName(src) or src, elapsed))
        return
    end

    if accuracy < (Config.Rewards.minAccuracy or 0.0) then return end

    -- --- plata -------------------------------------------------------------
    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local now = os.time()
    if lastReward[identifier] and (now - lastReward[identifier]) < (Config.Rewards.cooldown or 0) then
        TriggerClientEvent('esx:showNotification', src, Config.Locale.reward_cooldown)
        return
    end

    local amount = (Config.Rewards.base or 0) + math.floor((Config.Rewards.bonus or 0) * accuracy)
    if notesHit == notesTotal then
        amount = amount + (Config.Rewards.fullCombo or 0)
    end
    amount = math.floor(amount * difficultyMultiplier(session.difficulty))
    if amount <= 0 then return end

    lastReward[identifier] = now
    xPlayer.addAccountMoney(Config.Rewards.account or 'money', amount)
    TriggerClientEvent('esx:showNotification', src, Config.Locale.reward:format(amount))

    print(('[bs_guitarhero] %s a terminat %s (%s) - scor %d, acuratete %.1f%%, plata $%d')
        :format(GetPlayerName(src) or src, session.songId, session.difficulty, score, accuracy * 100, amount))
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
