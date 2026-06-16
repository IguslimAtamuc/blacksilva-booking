local ESX = exports['es_extended']:getSharedObject()

-- =====================================================================
--  BLACKSILVA - STORY MODE QUEST ENGINE (server)
--  Persistenta progresului (currentQuest, currentStep, completedQuests),
--  validare avans pas, recompense la final de quest si comanda admin
--  /quest set <nr> [serverId].
-- =====================================================================

-- helper: gaseste un quest dupa id
local function getQuest(id) return Config.Quests[id] end

-- numarul total de questuri configurate (id-uri 1..N consecutive)
local function questCount()
    local n = 0
    while Config.Quests[n + 1] do n = n + 1 end
    return n
end

-- =====================================================================
--  Baza de date
-- =====================================================================
CreateThread(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `blacksilva_quests` (
            `identifier` VARCHAR(60) NOT NULL,
            `data`       LONGTEXT DEFAULT '{}',
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
end)

local cache = {} -- [identifier] = { currentQuest, currentStep, completed = {} }

local function defaultState()
    return { currentQuest = Config.StartQuest or 1, currentStep = 1, completed = {} }
end

local function loadState(identifier, cb)
    if cache[identifier] then return cb(cache[identifier]) end
    MySQL.Async.fetchAll('SELECT data FROM blacksilva_quests WHERE identifier = @id', {
        ['@id'] = identifier
    }, function(result)
        local state
        if result and result[1] and result[1].data then
            state = json.decode(result[1].data) or defaultState()
        else
            state = defaultState()
            MySQL.Async.execute('INSERT INTO blacksilva_quests (identifier, data) VALUES (@id, @data)', {
                ['@id'] = identifier, ['@data'] = json.encode(state)
            })
        end
        state.completed = state.completed or {}
        if not state.currentQuest then state.currentQuest = Config.StartQuest or 1 end
        if not state.currentStep then state.currentStep = 1 end
        cache[identifier] = state
        cb(state)
    end)
end

local function saveState(identifier)
    if not cache[identifier] then return end
    MySQL.Async.execute('UPDATE blacksilva_quests SET data = @data WHERE identifier = @id', {
        ['@data'] = json.encode(cache[identifier]),
        ['@id']   = identifier
    })
end

-- =====================================================================
--  Sync catre client
-- =====================================================================
local function pushState(src, state)
    TriggerClientEvent('blacksilva-quests:state', src, {
        quest     = state.currentQuest,
        step      = state.currentStep,
        completed = state.completed,
    })
end

RegisterNetEvent('blacksilva-quests:request', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    loadState(xPlayer.getIdentifier(), function(state) pushState(src, state) end)
end)

-- =====================================================================
--  Recompense la final de quest
-- =====================================================================
local function giveItem(src, xPlayer, name, count)
    if Config.Inventory == 'ox' then
        pcall(function() exports.ox_inventory:AddItem(src, name, count) end)
    else
        pcall(function() xPlayer.addInventoryItem(name, count) end)
    end
end

local function grantReward(src, xPlayer, q)
    local r = q.reward or {}
    if r.money and r.money > 0 then
        if Config.RewardAccount == 'bank' then xPlayer.addAccountMoney('bank', r.money)
        else xPlayer.addMoney(r.money) end
    end
    if r.bank and r.bank > 0 then xPlayer.addAccountMoney('bank', r.bank) end
    if r.items then
        for _, it in ipairs(r.items) do giveItem(src, xPlayer, it.name, it.count or 1) end
    end
    if r.xp and r.xp > 0 and Config.ExpCommand and Config.ExpCommand ~= '' then
        ExecuteCommand(('%s %d %d'):format(Config.ExpCommand, src, r.xp))
    end
end

-- =====================================================================
--  Avans pas (apelat din client cand pasul curent e complet)
-- =====================================================================
RegisterNetEvent('blacksilva-quests:advance', function(quest, step)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()

    loadState(identifier, function(state)
        -- valideaza: clientul trebuie sa fie chiar pe pasul pe care il avanseaza
        if quest ~= state.currentQuest or step ~= state.currentStep then
            pushState(src, state) -- resync (anti-desync)
            return
        end
        local q = getQuest(state.currentQuest)
        if not q then return end

        local nextStep = step + 1
        if nextStep > #q.steps then
            -- quest complet
            state.completed[tostring(state.currentQuest)] = true
            grantReward(src, xPlayer, q)
            TriggerClientEvent('blacksilva-quests:reward', src,
                (q.reward and q.reward.money) or 0,
                (q.reward and q.reward.xp) or 0, q.title)
            if q.nextQuest and getQuest(q.nextQuest) then
                state.currentQuest = q.nextQuest
                state.currentStep  = 1
            else
                state.currentStep = nextStep -- dincolo de final -> client afiseaza "terminat"
            end
        else
            state.currentStep = nextStep
        end

        saveState(identifier)
        pushState(src, state)
    end)
end)

-- =====================================================================
--  Comanda /quest  si  /quest set <nr> [serverId]
-- =====================================================================
local function doQuestSet(src, targetId, questNr)
    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Jucatorul nu este online!') end
        return
    end
    if not getQuest(questNr) then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, ('~r~Questul #%s nu exista!'):format(tostring(questNr))) end
        return
    end

    local identifier = target.getIdentifier()
    loadState(identifier, function(state)
        state.currentQuest = questNr
        state.currentStep  = 1
        -- questurile inainte de N = facute; de la N in sus = nefacute (refacute)
        state.completed = {}
        for id = 1, questCount() do
            if id < questNr then state.completed[tostring(id)] = true end
        end
        saveState(identifier)
        -- curatare la client (NPC/props/blip/chase) inainte sa porneasca noul quest
        TriggerClientEvent('blacksilva-quests:forceCleanup', targetId)
        pushState(targetId, state)

        TriggerClientEvent('esx:showNotification', targetId, ('~y~Ai fost mutat la questul #%d.'):format(questNr))
        if src ~= 0 and src ~= targetId then
            TriggerClientEvent('esx:showNotification', src, ('~g~Jucatorul a fost setat la questul #%d.'):format(questNr))
        end
    end)
end

RegisterCommand(Config.Command, function(source, args)
    local src = source

    -- /quest  (fara argumente) -> deschide jurnalul pentru jucator
    if not args[1] then
        if src ~= 0 then TriggerClientEvent('blacksilva-quests:openJournal', src) end
        return
    end

    -- /quest set <nr> [serverId]  -> doar admin
    if args[1] == 'set' then
        if src ~= 0 then
            local caller = ESX.GetPlayerFromId(src)
            if not caller or caller.getGroup() ~= Config.AdminGroup then
                TriggerClientEvent('esx:showNotification', src, '~r~Nu ai permisiunea!')
                return
            end
        end
        local questNr = tonumber(args[2])
        if not questNr then
            if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Foloseste: /quest set <numar> [serverId]') end
            return
        end
        local targetId = tonumber(args[3]) or src
        if targetId == 0 then
            TriggerClientEvent('esx:showNotification', src, '~r~Da un serverId: /quest set <nr> <serverId>')
            return
        end
        doQuestSet(src, targetId, questNr)
        return
    end

    if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Foloseste: /quest  sau  /quest set <numar>') end
end, false)

-- =====================================================================
--  Salveaza la deconectare
-- =====================================================================
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        local id = xPlayer.getIdentifier()
        saveState(id)
        cache[id] = nil
    end
end)
