local ESX = exports['es_extended']:getSharedObject()

local isUIOpen   = false
local missions   = {}            -- starea misiunilor (din server)
local missionCfg = {}            -- index pe id catre config
for _, m in ipairs(Config.Missions) do missionCfg[m.id] = m end

local activities = {}            -- starea activitatilor (din server)
local activityCfg = {}           -- index pe id catre config
for _, a in ipairs(Config.Activities or {}) do activityCfg[a.id] = a end
local activeActivityId = nil     -- activitatea pornita acum (client)

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
    data = data or {}
    missions   = data.missions or {}
    activities = data.activities or {}
    refreshBlips()
    if isUIOpen then
        SendNUIMessage({ type = 'update', missions = missions, activities = activities, activeActivity = activeActivityId })
    end
end)

-- recompensa revendicata din meniu (fara notificare de joc)
RegisterNetEvent('blacksilva-missions:claimed')
AddEventHandler('blacksilva-missions:claimed', function(money, level, label)
    if isUIOpen then
        PlaySoundFrontend(-1, "PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET", true)
        SendNUIMessage({ type = 'claimed', money = money, level = level, label = label })
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

-- thread care mentine blur-ul de fundal (DOF) cat timp meniul e deschis
local dofThreadRunning = false
local function startDofThread()
    if dofThreadRunning then return end
    dofThreadRunning = true
    CreateThread(function()
        while isUIOpen and missionCam do
            SetUseHiDof()
            Wait(0)
        end
        dofThreadRunning = false
    end)
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

    -- Depth of Field: personajul ramane clar, fundalul devine blurat
    if c.dof then
        SetCamUseShallowDofMode(missionCam, true)
        SetCamNearDof(missionCam, c.dofNear or 0.6)
        SetCamFarDof(missionCam, c.dofFar or 3.2)
        SetCamDofStrength(missionCam, c.dofStrength or 1.0)
        startDofThread()
    end

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

    SendNUIMessage({
        type = 'openUI',
        missions = missions,
        activities = activities,
        activeActivity = activeActivityId,
        accent = Config.Accent,
        panelRight = Config.PanelRight,
    })
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

RegisterNUICallback('claim', function(data, cb)
    if data and data.id then
        TriggerServerEvent('blacksilva-missions:claim', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('claimAll', function(_, cb)
    TriggerServerEvent('blacksilva-missions:claimAll')
    cb('ok')
end)

RegisterNUICallback('startActivity', function(data, cb)
    cb('ok')
    if data and data.id then
        CloseMissionsMenu()
        StartActivity(data.id)
    end
end)

RegisterNUICallback('cancelActivity', function(_, cb)
    cb('ok')
    CancelActivity()
end)

RegisterNUICallback('claimActivity', function(data, cb)
    cb('ok')
    if data and data.id then
        TriggerServerEvent('blacksilva-missions:activityClaim', data.id)
    end
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
--  MOTOR ACTIVITATI (pornite din meniul F5, fara NPC)
-- =====================================================================
local activityRunning = false
local activityBlip    = nil
local activityProp    = nil

local function clearActivityWorld()
    if activityBlip and DoesBlipExist(activityBlip) then RemoveBlip(activityBlip) end
    activityBlip = nil
    if activityProp and DoesEntityExist(activityProp) then DeleteEntity(activityProp) end
    activityProp = nil
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
    end
end

local function setActivityBlip(coord, label)
    if activityBlip and DoesBlipExist(activityBlip) then RemoveBlip(activityBlip) end
    activityBlip = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(activityBlip, 1)
    SetBlipColour(activityBlip, 5)
    SetBlipScale(activityBlip, 0.9)
    SetBlipRoute(activityBlip, true)
    SetBlipRouteColour(activityBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(label or "Activitate")
    EndTextCommandSetBlipName(activityBlip)
end

local function drawTxt3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function playActionAnim(anim, propModel, duration)
    local ped = PlayerPedId()
    if anim and anim[1] then
        RequestAnimDict(anim[1])
        local t = 0
        while not HasAnimDictLoaded(anim[1]) and t < 60 do Wait(10); t = t + 1 end
        TaskPlayAnim(ped, anim[1], anim[2], 4.0, -4.0, duration, 1, 0, false, false, false)
    end
    if propModel then
        local m = GetHashKey(propModel)
        RequestModel(m)
        local t = 0
        while not HasModelLoaded(m) and t < 60 do Wait(10); t = t + 1 end
        local c = GetEntityCoords(ped)
        activityProp = CreateObject(m, c.x, c.y, c.z, true, true, true)
        local bone = GetPedBoneIndex(ped, 28422) -- mana dreapta
        AttachEntityToEntity(activityProp, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    end
    Wait(duration)
    if activityProp and DoesEntityExist(activityProp) then DeleteEntity(activityProp) end
    activityProp = nil
    if not IsEntityDead(ped) then ClearPedTasks(ped) end
end

-- construieste pasii unei activitati din config
local function buildSteps(a)
    local def   = (Config.ActivityDefaults or {})[a.type] or {}
    local steps = {}
    if a.type == 'delivery' then
        steps[#steps + 1] = {
            coord = a.pickup,
            label = a.pickupLabel or def.pickupLabel or 'Ridica',
            anim  = a.pickupAnim or def.pickupAnim,
            prop  = a.pickupProp or def.pickupProp,
            dur   = a.duration or def.duration or 2500,
        }
        for _, d in ipairs(a.dropoffs or {}) do
            steps[#steps + 1] = {
                coord = d,
                label = a.deliverLabel or def.deliverLabel or 'Livreaza',
                anim  = a.deliverAnim or def.deliverAnim,
                dur   = a.duration or def.duration or 2200,
            }
        end
    else
        for _, p in ipairs(a.points or {}) do
            steps[#steps + 1] = {
                coord = p,
                label = a.label or def.label or 'Actiune',
                anim  = a.anim or def.anim,
                prop  = a.prop or def.prop,
                dur   = a.duration or def.duration or 2500,
            }
        end
    end
    return steps
end

function StartActivity(id)
    if activityRunning then
        notify('~y~Ai deja o activitate in desfasurare. Deschide F5 -> Renunta pentru a o opri.')
        return
    end
    local a = activityCfg[id]
    if not a then return end
    local steps = buildSteps(a)
    if #steps == 0 then return end

    activeActivityId = id
    activityRunning  = true
    TriggerServerEvent('blacksilva-missions:activityStart', id)
    notify(('~b~Activitate pornita: ~w~%s ~b~(%d pasi). Urmareste GPS-ul.'):format(a.title, #steps))

    CreateThread(function()
        local stepIndex = 1
        while activityRunning and stepIndex <= #steps do
            local step = steps[stepIndex]
            if not step.coord then break end
            setActivityBlip(step.coord, a.title)

            local done = false
            while activityRunning and not done do
                Wait(0)
                local ped  = PlayerPedId()
                local pc   = GetEntityCoords(ped)
                local dist = #(pc - vector3(step.coord.x, step.coord.y, step.coord.z))
                if dist <= 60.0 then
                    DrawMarker(1, step.coord.x, step.coord.y, step.coord.z - 0.95, 0,0,0, 0,0,0,
                        1.5, 1.5, 0.8, 233, 147, 12, 140, false, true, 2, false, nil, nil, false)
                end
                if dist <= 2.0 then
                    drawTxt3D(step.coord.x, step.coord.y, step.coord.z + 0.5,
                        ('[E] %s  (%d/%d)'):format(step.label, stepIndex, #steps))
                    if IsControlJustPressed(0, 38) then -- E
                        FreezeEntityPosition(ped, true)
                        playActionAnim(step.anim, step.prop, step.dur)
                        FreezeEntityPosition(ped, false)
                        done = true
                        notify(('~g~%s (%d/%d)'):format(step.label, stepIndex, #steps))
                    end
                end
            end

            if not activityRunning then break end
            stepIndex = stepIndex + 1
        end

        if activityRunning and stepIndex > #steps then
            TriggerServerEvent('blacksilva-missions:activityComplete', id)
            notify('~g~Activitate finalizata! Deschide F5 si apasa Revendica.')
        end

        activityRunning  = false
        activeActivityId = nil
        clearActivityWorld()
        if isUIOpen then SendNUIMessage({ type = 'setActive', id = nil }) end
    end)
end

function CancelActivity()
    if not activityRunning then return end
    activityRunning  = false
    activeActivityId = nil
    clearActivityWorld()
    notify('~r~Activitate anulata.')
    if isUIOpen then SendNUIMessage({ type = 'setActive', id = nil }) end
end

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
        if activityBlip and DoesBlipExist(activityBlip) then RemoveBlip(activityBlip) end
        if activityProp and DoesEntityExist(activityProp) then DeleteEntity(activityProp) end
    end
end)
