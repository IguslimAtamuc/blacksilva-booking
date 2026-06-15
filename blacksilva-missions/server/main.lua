local ESX = exports['es_extended']:getSharedObject()

-- =====================================================================
--  Helper: gaseste o misiune dupa id din config
-- =====================================================================
local function getMission(id)
    for _, m in ipairs(Config.Missions) do
        if m.id == id then return m end
    end
    return nil
end

-- target real (vizitarea locatiilor isi calculeaza target din lista)
local function getTarget(mission)
    if mission.type == 'visit_locations' and mission.locations then
        return #mission.locations
    end
    return mission.target or 1
end

-- =====================================================================
--  Baza de date
-- =====================================================================
CreateThread(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `blacksilva_missions` (
            `identifier` VARCHAR(60) NOT NULL,
            `progress`   LONGTEXT DEFAULT '{}',
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
end)

-- progres in memorie: [identifier] = { ["1"] = { current = 0, completed = false }, ... }
local cache = {}

local function loadProgress(identifier, cb)
    if cache[identifier] then return cb(cache[identifier]) end
    MySQL.Async.fetchAll('SELECT progress FROM blacksilva_missions WHERE identifier = @id', {
        ['@id'] = identifier
    }, function(result)
        local data = {}
        if result and result[1] then
            data = json.decode(result[1].progress) or {}
        else
            MySQL.Async.execute('INSERT INTO blacksilva_missions (identifier, progress) VALUES (@id, @data)', {
                ['@id'] = identifier, ['@data'] = '{}'
            })
        end
        cache[identifier] = data
        cb(data)
    end)
end

local function saveProgress(identifier)
    if not cache[identifier] then return end
    MySQL.Async.execute('UPDATE blacksilva_missions SET progress = @data WHERE identifier = @id', {
        ['@data'] = json.encode(cache[identifier]),
        ['@id']   = identifier
    })
end

-- =====================================================================
--  Blocare secventiala: o misiune e deblocata doar daca TOATE misiunile
--  dinaintea ei (in ordinea din Config.Missions) sunt completate.
-- =====================================================================
local function isUnlocked(data, missionId)
    for _, m in ipairs(Config.Missions) do
        if m.id == missionId then
            return true
        end
        local prog = data[tostring(m.id)]
        if not (prog and prog.completed) then
            return false
        end
    end
    return true
end

-- =====================================================================
--  Construieste payload-ul pentru UI (cu starea de blocare)
-- =====================================================================
local function buildPayload(data)
    local missions = {}
    local prevCompleted = true
    for _, m in ipairs(Config.Missions) do
        local key  = tostring(m.id)
        local prog = data[key] or { current = 0, completed = false, claimed = false }
        local target = getTarget(m)
        local completed = prog.completed or false
        missions[#missions + 1] = {
            id          = m.id,
            title       = m.title,
            description = m.description,
            reward      = m.reward,
            level       = m.level or 1,
            icon        = m.icon or 'target',
            type        = m.type,
            current     = math.min(prog.current or 0, target),
            target      = target,
            completed   = completed,
            claimed     = prog.claimed or false,
            locked      = not prevCompleted,
        }
        if not completed then prevCompleted = false end
    end
    return missions
end

local function pushData(src, data)
    TriggerClientEvent('blacksilva-missions:receiveData', src, buildPayload(data))
end

RegisterNetEvent('blacksilva-missions:requestData')
AddEventHandler('blacksilva-missions:requestData', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    loadProgress(xPlayer.getIdentifier(), function(data)
        pushData(src, data)
    end)
end)

-- =====================================================================
--  Revendicare recompensa (banii + experienta) - manual, din meniu
--  La finalizarea unei misiuni NU se da nimic automat si NU apare nicio
--  notificare; jucatorul apasa "Revendica" in meniu.
-- =====================================================================
local function grantReward(src, xPlayer, mission)
    if mission.reward and mission.reward > 0 then
        if Config.RewardAccount == 'bank' then
            xPlayer.addAccountMoney('bank', mission.reward)
        else
            xPlayer.addMoney(mission.reward)
        end
    end
    local lvl = mission.level or 1
    if lvl > 0 and Config.ExpCommand and Config.ExpCommand ~= '' then
        ExecuteCommand(('%s %d %d'):format(Config.ExpCommand, src, lvl))
    end
    return mission.reward or 0, lvl
end

-- revendica o singura misiune (returneaza bani, niveluri revendicate)
local function claimOne(src, xPlayer, data, mission)
    if not mission then return 0, 0 end
    local key = tostring(mission.id)
    local prog = data[key]
    if not prog or not prog.completed or prog.claimed then return 0, 0 end
    if not isUnlocked(data, mission.id) then return 0, 0 end
    prog.claimed = true
    return grantReward(src, xPlayer, mission)
end

RegisterNetEvent('blacksilva-missions:claim')
AddEventHandler('blacksilva-missions:claim', function(missionId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local mission = getMission(missionId)
    if not mission then return end

    local identifier = xPlayer.getIdentifier()
    loadProgress(identifier, function(data)
        local money, lvl = claimOne(src, xPlayer, data, mission)
        if money > 0 or lvl > 0 then
            saveProgress(identifier)
            pushData(src, data)
            TriggerClientEvent('blacksilva-missions:claimed', src, money, lvl, mission.title)
        end
    end)
end)

RegisterNetEvent('blacksilva-missions:claimAll')
AddEventHandler('blacksilva-missions:claimAll', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.getIdentifier()
    loadProgress(identifier, function(data)
        local totalMoney, totalLvl, count = 0, 0, 0
        for _, mission in ipairs(Config.Missions) do
            local money, lvl = claimOne(src, xPlayer, data, mission)
            if money > 0 or lvl > 0 then
                totalMoney = totalMoney + money
                totalLvl   = totalLvl + lvl
                count = count + 1
            end
        end
        if count > 0 then
            saveProgress(identifier)
            pushData(src, data)
            TriggerClientEvent('blacksilva-missions:claimed', src, totalMoney, totalLvl, count .. ' misiuni')
        end
    end)
end)

-- =====================================================================
--  Actualizare progres (apelat din client)
-- =====================================================================
RegisterNetEvent('blacksilva-missions:updateProgress')
AddEventHandler('blacksilva-missions:updateProgress', function(missionId, value, mode)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local mission = getMission(missionId)
    if not mission then return end

    local identifier = xPlayer.getIdentifier()
    loadProgress(identifier, function(data)
        -- respecta ordinea: misiunea trebuie sa fie deblocata
        if not isUnlocked(data, missionId) then return end

        local key = tostring(missionId)
        if not data[key] then data[key] = { current = 0, completed = false, claimed = false } end
        if data[key].completed then return end

        local target = getTarget(mission)
        value = tonumber(value) or 0

        if mode == 'add' then
            data[key].current = (data[key].current or 0) + value
        else
            data[key].current = math.max(data[key].current or 0, value)
        end
        if data[key].current > target then data[key].current = target end

        -- la finalizare doar marcam misiunea (recompensa se revendica din meniu)
        if data[key].current >= target and not data[key].completed then
            data[key].completed = true
            data[key].current = target
        end

        saveProgress(identifier)
        pushData(src, data) -- payload complet -> actualizeaza si blocarile
    end)
end)

-- =====================================================================
--  Kill de jucator: conteaza pentru PRIMA misiune kill_players activa
--  (deblocata si necompletata) - asa se respecta ordinea 9 -> 10.
-- =====================================================================
RegisterNetEvent('blacksilva-missions:playerKill')
AddEventHandler('blacksilva-missions:playerKill', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()

    loadProgress(identifier, function(data)
        for _, mission in ipairs(Config.Missions) do
            if mission.type == 'kill_players' then
                local key = tostring(mission.id)
                if not data[key] then data[key] = { current = 0, completed = false, claimed = false } end
                if not data[key].completed and isUnlocked(data, mission.id) then
                    local target = getTarget(mission)
                    data[key].current = math.min((data[key].current or 0) + 1, target)
                    if data[key].current >= target then
                        data[key].completed = true
                    end
                    saveProgress(identifier)
                    pushData(src, data)
                    return -- un kill = un singur progres
                end
            end
        end
    end)
end)

-- =====================================================================
--  Admin: /resetmisiuni [id]
-- =====================================================================
RegisterCommand('resetmisiuni', function(source, args)
    local src = source
    if src ~= 0 then
        local caller = ESX.GetPlayerFromId(src)
        if not caller or caller.getGroup() ~= 'admin' then
            TriggerClientEvent('esx:showNotification', src, '~r~Nu ai permisiunea!')
            return
        end
    end

    local targetId = tonumber(args[1])
    if not targetId then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Foloseste: /resetmisiuni [ID]') end
        return
    end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Jucatorul nu este online!') end
        return
    end

    local identifier = target.getIdentifier()
    cache[identifier] = {}
    MySQL.Async.execute('UPDATE blacksilva_missions SET progress = @data WHERE identifier = @id', {
        ['@data'] = '{}', ['@id'] = identifier
    }, function()
        pushData(targetId, {})
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~g~Misiuni resetate!') end
        TriggerClientEvent('esx:showNotification', targetId, '~y~Misiunile tale au fost resetate de un admin!')
    end)
end, false)

-- =====================================================================
--  Admin: /skip [numar misiune] [serverId?]
--  Marcheaza misiunile ca fiind COMPLETATE pana la (si inclusiv) numarul
--  dat. Completam tot lantul pana acolo ca sa respectam blocarea
--  secventiala (altfel o misiune din mijloc ar aparea "completata" dar
--  blocata). Recompensa NU se da automat - se revendica din meniu.
--    /skip 30        -> sare misiunile 1..30 pentru tine
--    /skip 30 12     -> sare misiunile 1..30 pentru jucatorul cu id 12
--  Ca sa-l faci disponibil pentru TOTI jucatorii, sterge blocul de mai jos
--  cu verificarea "caller.getGroup() ~= 'admin'".
-- =====================================================================
RegisterCommand('skip', function(source, args)
    local src = source
    if src ~= 0 then
        local caller = ESX.GetPlayerFromId(src)
        if not caller or caller.getGroup() ~= 'admin' then
            TriggerClientEvent('esx:showNotification', src, '~r~Nu ai permisiunea!')
            return
        end
    end

    local missionId = tonumber(args[1])
    if not missionId then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Foloseste: /skip [numar misiune]') end
        return
    end
    if not getMission(missionId) then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Misiunea #' .. missionId .. ' nu exista!') end
        return
    end

    -- jucatorul tinta: implicit cel care a dat comanda; admin poate da un al 2-lea arg
    local targetId = tonumber(args[2]) or src
    if targetId == 0 then
        TriggerClientEvent('esx:showNotification', src, '~r~Ruleaza /skip din joc sau da un serverId: /skip [id] [serverId]')
        return
    end
    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        if src ~= 0 then TriggerClientEvent('esx:showNotification', src, '~r~Jucatorul nu este online!') end
        return
    end

    local identifier = target.getIdentifier()
    loadProgress(identifier, function(data)
        local count = 0
        -- iteram in ORDINEA din Config.Missions si ne oprim dupa misiunea ceruta
        for _, m in ipairs(Config.Missions) do
            local key = tostring(m.id)
            if not data[key] then data[key] = { current = 0, completed = false, claimed = false } end
            if not data[key].completed then
                data[key].completed = true
                data[key].current   = getTarget(m)
                count = count + 1
            end
            if m.id == missionId then break end
        end
        saveProgress(identifier)
        pushData(targetId, data)
        if src ~= 0 then
            TriggerClientEvent('esx:showNotification', src, ('~g~Gata pana la misiunea #%d (%d marcate). Revendica din meniu.'):format(missionId, count))
        end
        if targetId ~= src then
            TriggerClientEvent('esx:showNotification', targetId, ('~y~Un admin ti-a deblocat misiunile pana la #%d!'):format(missionId))
        end
    end)
end, false)

-- elibereaza din cache la deconectare
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        local id = xPlayer.getIdentifier()
        saveProgress(id)
        cache[id] = nil
    end
end)
