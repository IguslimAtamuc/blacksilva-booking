local ESX = exports['es_extended']:getSharedObject()

local isUIOpen   = false
local missions   = {}            -- starea misiunilor (din server)
local missionCfg = {}            -- index pe id catre config
for _, m in ipairs(Config.Missions) do missionCfg[m.id] = m end

-- =====================================================================
--  Helpers
-- =====================================================================
local function notify(msg)
    TriggerEvent('esx:showNotification', msg)
end

local function getMissionState(id)
    for _, m in ipairs(missions) do
        if m.id == id then return m end
    end
    return nil
end

local function isCompleted(id)
    local s = getMissionState(id)
    return s and s.completed
end

-- o misiune e deblocata doar daca toate misiunile dinaintea ei sunt completate
local function isMissionUnlocked(id)
    for _, m in ipairs(Config.Missions) do
        if m.id == id then return true end
        if not isCompleted(m.id) then return false end
    end
    return true
end

-- trimite progres la server (doar daca misiunea e deblocata)
local function setProgress(id, value)
    if not isMissionUnlocked(id) then return end
    TriggerServerEvent('blacksilva-missions:updateProgress', id, value, 'set')
end
local function addProgress(id, value)
    if not isMissionUnlocked(id) then return end
    TriggerServerEvent('blacksilva-missions:updateProgress', id, value, 'add')
end

-- numara itemele dintr-un inventar (ox sau esx)
local function getItemCount(name)
    if Config.Inventory == 'ox' then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search('count', name)
        end)
        if ok and count then return count end
        return 0
    else
        local count = 0
        local data = ESX.GetPlayerData()
        if data and data.inventory then
            for _, item in ipairs(data.inventory) do
                if item.name == name then count = count + (item.count or 0) end
            end
        end
        return count
    end
end

-- numara cate iteme de tip arma (WEAPON_*) sunt in inventar
local function getWeaponItemCount()
    local total = 0
    if Config.Inventory == 'ox' then
        local ok, items = pcall(function() return exports.ox_inventory:GetPlayerItems() end)
        if ok and items then
            for _, item in pairs(items) do
                if item.name and string.upper(item.name):find('^WEAPON_') then
                    total = total + (item.count or 1)
                end
            end
        end
    else
        local data = ESX.GetPlayerData()
        if data and data.inventory then
            for _, item in ipairs(data.inventory) do
                if item.name and string.upper(item.name):find('^WEAPON_') then
                    total = total + (item.count or 0)
                end
            end
        end
    end
    return total
end

-- =====================================================================
--  Sincronizare date din server
-- =====================================================================
RegisterNetEvent('blacksilva-missions:receiveData')
AddEventHandler('blacksilva-missions:receiveData', function(data)
    missions = data or {}
    refreshBlips()
    if isUIOpen then
        SendNUIMessage({ type = 'updateMissions', missions = missions })
    end
end)

RegisterNetEvent('blacksilva-missions:missionCompleted')
AddEventHandler('blacksilva-missions:missionCompleted', function(id, title, reward, level)
    PlaySoundFrontend(-1, "RANK_UP", "HUD_AWARDS", true)
    notify(('~g~Misiune completata!~s~\n~y~%s~s~\nRecompensa: ~g~$%s~s~  +%d nivel'):format(title, reward, level))
    if isUIOpen then
        SendNUIMessage({ type = 'missionCompleted', id = id, title = title, reward = reward })
    end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    TriggerServerEvent('blacksilva-missions:requestData')
end)

CreateThread(function()
    Wait(2000)
    if ESX.IsPlayerLoaded() then
        TriggerServerEvent('blacksilva-missions:requestData')
    end
end)

-- =====================================================================
--  CAMERA + EMOTE CLIPBOARD (Pasul 2)
-- =====================================================================
local missionCam = nil
local camTransitioning = false
local clipboardProp = nil

local function startClipboardEmote()
    local ped = PlayerPedId()
    if Config.Emote.useRpEmotes then
        ExecuteCommand('e ' .. Config.Emote.rpEmoteName)
        return
    end

    RequestAnimDict(Config.Emote.animDict)
    local t = 0
    while not HasAnimDictLoaded(Config.Emote.animDict) and t < 100 do Wait(10); t = t + 1 end
    TaskPlayAnim(ped, Config.Emote.animDict, Config.Emote.animName, 2.0, -2.0, -1, 49, 0, false, false, false)

    -- atasam prop-ul de clipboard in mana
    local model = GetHashKey(Config.Emote.propModel)
    RequestModel(model)
    t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(10); t = t + 1 end
    local coords = GetEntityCoords(ped)
    clipboardProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, true)
    local bone = GetPedBoneIndex(ped, 18905) -- mana stanga
    AttachEntityToEntity(clipboardProp, ped, bone, 0.16, 0.08, 0.02, -130.0, -50.0, 0.0, true, true, false, true, 1, true)
end

local function stopClipboardEmote()
    local ped = PlayerPedId()
    if Config.Emote.useRpEmotes then
        ExecuteCommand('e c')
    else
        ClearPedTasks(ped)
    end
    if clipboardProp and DoesEntityExist(clipboardProp) then
        DeleteEntity(clipboardProp)
        clipboardProp = nil
    end
end

local function createMissionCamera()
    local ped = PlayerPedId()
    local c   = Config.Camera
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, c.forward, c.height)
    -- punctul tinta e mutat lateral ca personajul sa apara pe STANGA ecranului
    local aim = GetOffsetFromEntityInWorldCoords(ped, c.sideAim, 0.0, c.pointZ)

    missionCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(missionCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(missionCam, aim.x, aim.y, aim.z)
    SetCamFov(missionCam, c.fov)
    SetCamActiveWithInterp(missionCam, GetRenderingCam(), c.interp, true, true)
    RenderScriptCams(true, true, c.interp, true, false)

    camTransitioning = true
    SetTimeout(c.interp, function() camTransitioning = false end)
end

local function destroyMissionCamera()
    if missionCam then
        RenderScriptCams(false, true, 800, true, false)
        SetTimeout(800, function()
            if missionCam then
                DestroyCam(missionCam, false)
                missionCam = nil
            end
        end)
    end
end

-- =====================================================================
--  Deschidere / inchidere meniu (Pasul 1)
-- =====================================================================
function OpenMissionsMenu()
    if isUIOpen then return end
    isUIOpen = true
    SetNuiFocus(true, true)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)

    startClipboardEmote()
    createMissionCamera()

    -- cere date proaspete
    TriggerServerEvent('blacksilva-missions:requestData')

    SendNUIMessage({ type = 'openUI', missions = missions, accent = Config.Accent })
end

function CloseMissionsMenu()
    if not isUIOpen then return end
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'closeUI' })

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    stopClipboardEmote()
    destroyMissionCamera()
end

RegisterNUICallback('close', function(_, cb)
    CloseMissionsMenu()
    cb('ok')
end)

-- tasta F5 (configurabila din setarile FiveM) + comanda /misiuni
RegisterCommand('blacksilva_missions_open', function()
    if isUIOpen then CloseMissionsMenu() else OpenMissionsMenu() end
end, false)
RegisterKeyMapping('blacksilva_missions_open', 'Deschide Misiuni', 'keyboard', Config.OpenKey)

RegisterCommand(Config.Command, function()
    if isUIOpen then CloseMissionsMenu() else OpenMissionsMenu() end
end, false)

-- =====================================================================
--  DETECTAREA MISIUNILOR
-- =====================================================================

-- ---------- MISIUNEA 1: use_item (poll pe contoare inventar) ----------
-- ---------- MISIUNEA 7: obtain_weapon (poll pe contor arme) -----------
CreateThread(function()
    Wait(3000)
    -- snapshot initial pentru fiecare item monitorizat
    local lastItemCount = {}
    local usedDistinct  = {}
    for _, m in ipairs(Config.Missions) do
        if m.type == 'use_item' and m.items then
            usedDistinct[m.id] = {}
            for _, it in ipairs(m.items) do
                lastItemCount[it] = getItemCount(it)
            end
        end
    end
    local lastWeaponCount = getWeaponItemCount()

    while true do
        Wait(1500)
        if ESX.IsPlayerLoaded() then
            -- use_item
            for _, m in ipairs(Config.Missions) do
                if m.type == 'use_item' and m.items and not isCompleted(m.id) then
                    for _, it in ipairs(m.items) do
                        local now = getItemCount(it)
                        local prev = lastItemCount[it] or 0
                        if now < prev then
                            -- s-a folosit un item
                            if m.distinct then
                                usedDistinct[m.id][it] = true
                                local count = 0
                                for _ in pairs(usedDistinct[m.id]) do count = count + 1 end
                                setProgress(m.id, count)
                            else
                                addProgress(m.id, prev - now)
                            end
                        end
                        lastItemCount[it] = now
                    end
                end
            end

            -- obtain_weapon (misiunea 7): arma noua aparuta langa locatie
            local nowWeapons = getWeaponItemCount()
            if nowWeapons > lastWeaponCount then
                local gained = nowWeapons - lastWeaponCount
                local pedCoords = GetEntityCoords(PlayerPedId())
                for _, m in ipairs(Config.Missions) do
                    if m.type == 'obtain_weapon' and not isCompleted(m.id) then
                        local dist = #(pedCoords - m.location)
                        if dist <= (m.radius or 30.0) then
                            addProgress(m.id, gained)
                        end
                    end
                end
            end
            lastWeaponCount = nowWeapons
        end
    end
end)

-- ---------- MISIUNEA 2: spawn_vehicle (scooter) ----------------------
CreateThread(function()
    Wait(3000)
    while true do
        Wait(1000)
        if ESX.IsPlayerLoaded() then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                local model = GetEntityModel(veh)
                for _, m in ipairs(Config.Missions) do
                    if m.type == 'spawn_vehicle' and m.models and not isCompleted(m.id) then
                        for _, name in ipairs(m.models) do
                            if model == GetHashKey(name) then
                                setProgress(m.id, m.target or 1)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ---------- MISIUNEA 4: speed_radar --------------------------------
CreateThread(function()
    Wait(3000)
    local radarCooldown = {} -- evita dublarea cand stai langa radar
    while true do
        Wait(200)
        local handled = false
        if ESX.IsPlayerLoaded() then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                local speed = GetEntitySpeed(veh) * 3.6 -- km/h
                local coords = GetEntityCoords(ped)
                for _, m in ipairs(Config.Missions) do
                    if m.type == 'speed_radar' and not isCompleted(m.id) and speed >= (m.minSpeed or 200) then
                        for i, rcoord in ipairs(m.radars) do
                            local dist = #(coords - rcoord)
                            local key = m.id .. '_' .. i
                            if dist <= (m.radarRadius or 25.0) then
                                if not radarCooldown[key] or (GetGameTimer() - radarCooldown[key]) > 5000 then
                                    radarCooldown[key] = GetGameTimer()
                                    addProgress(m.id, 1)
                                    notify(('~g~Radar trecut cu %d km/h!'):format(math.floor(speed)))
                                end
                            end
                        end
                        handled = true
                    end
                end
            end
        end
        if not handled then Wait(300) end
    end
end)

-- ---------- MISIUNEA 5: stunts -------------------------------------
CreateThread(function()
    Wait(3000)
    local airborneSince = nil
    while true do
        Wait(250)
        if ESX.IsPlayerLoaded() then
            local ped = PlayerPedId()
            local hasStuntMission = false
            for _, m in ipairs(Config.Missions) do
                if m.type == 'stunts' and not isCompleted(m.id) then hasStuntMission = true end
            end

            if hasStuntMission and IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if IsEntityInAir(veh) then
                    if not airborneSince then airborneSince = GetGameTimer() end
                else
                    if airborneSince then
                        local airTime = GetGameTimer() - airborneSince
                        airborneSince = nil
                        -- aterizat pe roti, viu si a stat suficient in aer = stunt
                        if not IsEntityDead(veh) and not IsEntityDead(ped)
                           and IsVehicleOnAllWheels(veh) then
                            for _, m in ipairs(Config.Missions) do
                                if m.type == 'stunts' and not isCompleted(m.id)
                                   and airTime >= (m.minAirTime or 800) then
                                    addProgress(m.id, 1)
                                    notify('~g~Stunt reusit!')
                                end
                            end
                        end
                    end
                end
            else
                airborneSince = nil
            end
        end
    end
end)

-- ---------- MISIUNEA 3/6/7: locatii + markere + blip-uri ------------
-- blip-urile se afiseaza DOAR pentru misiunea deblocata si necompletata
local activeBlips = {}
function refreshBlips()
    for _, b in ipairs(activeBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    activeBlips = {}

    local function addBlip(loc, blip, title)
        local b = AddBlipForCoord(loc.x, loc.y, loc.z)
        SetBlipSprite(b, blip.sprite or 1)
        SetBlipColour(b, blip.color or 0)
        SetBlipScale(b, 0.8)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(blip.label or title)
        EndTextCommandSetBlipName(b)
        activeBlips[#activeBlips + 1] = b
    end

    for _, m in ipairs(Config.Missions) do
        if m.blip and not isCompleted(m.id) and isMissionUnlocked(m.id) then
            if m.location then
                addBlip(m.location, m.blip, m.title)
            elseif m.locations then
                for _, loc in ipairs(m.locations) do
                    addBlip(loc, m.blip, m.title)
                end
            end
        end
    end
end

-- marker + detectie locatie (reach_location, visit_locations, obtain_weapon)
local visited = {} -- [missionId] = { [index] = true }
CreateThread(function()
    Wait(3000)
    while true do
        local sleep = 1000
        if ESX.IsPlayerLoaded() then
            local coords = GetEntityCoords(PlayerPedId())
            local mk = Config.Marker

            for _, m in ipairs(Config.Missions) do
                if not isCompleted(m.id) and isMissionUnlocked(m.id) then
                    -- reach_location (job center) si obtain_weapon (atelier): markere
                    local single = m.location
                    if (m.type == 'reach_location' or m.type == 'obtain_weapon') and single then
                        local dist = #(coords - single)
                        if dist <= mk.drawDistance then
                            sleep = 0
                            DrawMarker(mk.type, single.x, single.y, single.z - 0.95, 0,0,0, 0,0,0,
                                mk.size.x, mk.size.y, mk.size.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a,
                                false, true, 2, false, nil, nil, false)
                            if dist <= mk.radius and m.type == 'reach_location' then
                                setProgress(m.id, m.target or 1)
                            end
                        end
                    end

                    -- visit_locations (gunshop-uri)
                    if m.type == 'visit_locations' and m.locations then
                        if not visited[m.id] then visited[m.id] = {} end
                        for i, loc in ipairs(m.locations) do
                            local dist = #(coords - loc)
                            if dist <= mk.drawDistance then
                                sleep = 0
                                if not visited[m.id][i] then
                                    DrawMarker(mk.type, loc.x, loc.y, loc.z - 0.95, 0,0,0, 0,0,0,
                                        mk.size.x, mk.size.y, mk.size.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a,
                                        false, true, 2, false, nil, nil, false)
                                end
                            end
                            if dist <= mk.radius and not visited[m.id][i] then
                                visited[m.id][i] = true
                                local count = 0
                                for _ in pairs(visited[m.id]) do count = count + 1 end
                                setProgress(m.id, count)
                                notify(('~g~Gunshop vizitat (%d/%d)'):format(count, #m.locations))
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------- MISIUNEA 8: command /liber -----------------------------
RegisterNetEvent('blacksilva-missions:commandUsed')
AddEventHandler('blacksilva-missions:commandUsed', function(cmd)
    for _, m in ipairs(Config.Missions) do
        if m.type == 'command' and m.command == cmd and not isCompleted(m.id) then
            setProgress(m.id, m.target or 1)
        end
    end
end)

CreateThread(function()
    for _, m in ipairs(Config.Missions) do
        if m.type == 'command' and m.registerCommand and m.command then
            RegisterCommand(m.command, function()
                TriggerEvent('blacksilva-missions:commandUsed', m.command)
            end, false)
        end
    end
end)

-- ---------- MISIUNEA 9/10: kill_players ----------------------------
local recentKills = {}
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim   = args[1]
    local attacker = args[2]
    local isFatal  = args[6]

    if attacker ~= PlayerPedId() then return end
    if victim == PlayerPedId() then return end
    if not DoesEntityExist(victim) then return end
    if not IsPedAPlayer(victim) then return end
    if isFatal ~= 1 then return end

    -- dedupe pe victima
    local key = tostring(victim)
    if recentKills[key] and (GetGameTimer() - recentKills[key]) < 3000 then return end

    SetTimeout(300, function()
        if DoesEntityExist(victim) and IsEntityDead(victim) then
            recentKills[key] = GetGameTimer()
            TriggerServerEvent('blacksilva-missions:playerKill')
        end
    end)
end)

-- =====================================================================
--  Blocare controale cat timp meniul e deschis
-- =====================================================================
CreateThread(function()
    while true do
        if isUIOpen then
            Wait(0)
            DisableControlAction(0, 1,  true)  -- look LR
            DisableControlAction(0, 2,  true)  -- look UD
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)  -- jump/space
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
        else
            Wait(500)
        end
    end
end)

-- curatare la oprirea resursei
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        if isUIOpen then
            SetNuiFocus(false, false)
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, false)
        end
        if clipboardProp and DoesEntityExist(clipboardProp) then DeleteEntity(clipboardProp) end
        if missionCam then RenderScriptCams(false, false, 0, true, false); DestroyCam(missionCam, false) end
    end
end)
