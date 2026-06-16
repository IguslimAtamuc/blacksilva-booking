local ESX = exports['es_extended']:getSharedObject()

-- =====================================================================
--  BLACKSILVA - STORY MODE QUEST ENGINE (client)
--  Ruleaza pas cu pas misiunea curenta primita de la server: spawneaza
--  NPC-uri/vehicule/props reale, ruleaza dialoguri chat, urmariri reale
--  (NPC + politie) si curata totul cand se schimba quest-ul / mori / iesi.
-- =====================================================================

-- starea autoritativa primita de la server
local State = { quest = 0, step = 0 }
local completedMap = {}

-- starea activa locala (ce e spawnat acum)
local A = {
    quest = 0, step = 0, token = 0,
    advancing = false,
    peds = {}, vehs = {}, blips = {},
    setWanted = false,
}
local heldProps = {}            -- props atasate care persista intre pasi (livrari)
local hostileGroup = nil

-- =====================================================================
--  Helperi
-- =====================================================================
local function notify(msg)
    TriggerEvent('esx:showNotification', msg)
end

local function helpText(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function dist3(a, b) return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z)) end

local function loadModel(model)
    local hash = (type(model) == 'number') and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 200 do Wait(10); t = t + 1 end
    return HasModelLoaded(hash)
end

local function ensureHostileGroup()
    if hostileGroup then return end
    local grp = AddRelationshipGroup('BS_HOSTILE')
    if type(grp) ~= 'number' then grp = GetHashKey('BS_HOSTILE') end
    hostileGroup = grp
    SetRelationshipBetweenGroups(5, hostileGroup, GetHashKey('PLAYER')) -- 5 = hate
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), hostileGroup)
end

-- NUI senders
local function nui(t) SendNUIMessage(t) end
local function hudUpdate(title, objective, idx, total)
    nui({ action = 'hud', show = true, title = title, objective = objective, step = idx, total = total })
end
local function hudHide() nui({ action = 'hud', show = false }) end
local function banner(title, sub) nui({ action = 'banner', title = title or '', sub = sub or '' }) end

-- =====================================================================
--  Spawn helpers
-- =====================================================================
local function makeBlip(coords, b)
    if not b then return nil end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, b.sprite or 1)
    SetBlipColour(blip, b.color or 0)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    if b.route then SetBlipRoute(blip, true); SetBlipRouteColour(blip, b.color or 5) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label or 'Misiune')
    EndTextCommandSetBlipName(blip)
    A.blips[#A.blips + 1] = blip
    return blip
end

local function makeEntityBlip(ent, b)
    if not b then return nil end
    local blip = AddBlipForEntity(ent)
    SetBlipSprite(blip, b.sprite or 1)
    SetBlipColour(blip, b.color or 0)
    SetBlipScale(blip, 0.85)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label or 'NPC')
    EndTextCommandSetBlipName(blip)
    A.blips[#A.blips + 1] = blip
    return blip
end

local function drawMarker(coords)
    local m = Config.Marker
    DrawMarker(m.type, coords.x, coords.y, coords.z - 0.95, 0,0,0, 0,0,0,
        m.size.x, m.size.y, m.size.z, m.color.r, m.color.g, m.color.b, m.color.a,
        false, true, 2, false, nil, nil, false)
end

local function spawnNpc(d)
    if not loadModel(d.model) then return nil end
    local c = d.coords
    local ped = CreatePed(4, GetHashKey(d.model), c.x, c.y, c.z - 1.0, c.w or 0.0, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if d.scenario then TaskStartScenarioInPlace(ped, d.scenario, 0, true) end
    SetModelAsNoLongerNeeded(GetHashKey(d.model))
    A.peds[#A.peds + 1] = ped
    if d.blip then makeEntityBlip(ped, d.blip) end
    return ped
end

local function spawnHostilePed(model, c, weapon)
    if not loadModel(model) then return nil end
    local ped = CreatePed(4, GetHashKey(model), c.x, c.y, c.z - 1.0, math.random(0, 359) + 0.0, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    ensureHostileGroup()
    SetPedRelationshipGroupHash(ped, hostileGroup)
    SetPedCombatAttributes(ped, 46, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 25)
    if weapon then GiveWeaponToPed(ped, GetHashKey(weapon), 250, false, true) end
    SetModelAsNoLongerNeeded(GetHashKey(model))
    A.peds[#A.peds + 1] = ped
    TaskCombatPed(ped, PlayerPedId(), 0, 16)
    SetPedKeepTask(ped, true)
    return ped
end

-- spawn un urmaritor (vehicul + sofer ostil) in spatele jucatorului
local function spawnVehChaser(d)
    local pp = PlayerPedId()
    local off = GetOffsetFromEntityInWorldCoords(pp, (math.random(-4, 4)) + 0.0,
        -(Config.Chase.spawnSpread + math.random(0, 18)) + 0.0, 0.0)
    if not loadModel(d.vehicle) then return nil end
    local veh = CreateVehicle(GetHashKey(d.vehicle), off.x, off.y, off.z, GetEntityHeading(pp), false, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 2)
    A.vehs[#A.vehs + 1] = veh
    SetModelAsNoLongerNeeded(GetHashKey(d.vehicle))

    if not loadModel(d.model) then return veh, nil end
    local ped = CreatePed(4, GetHashKey(d.model), off.x, off.y, off.z, 0.0, false, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetEntityAsMissionEntity(ped, true, true)
    ensureHostileGroup()
    SetPedRelationshipGroupHash(ped, hostileGroup)
    SetPedCombatAttributes(ped, 46, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedAccuracy(ped, 30)
    if d.weapon then GiveWeaponToPed(ped, GetHashKey(d.weapon), 250, false, true) end
    SetModelAsNoLongerNeeded(GetHashKey(d.model))
    A.peds[#A.peds + 1] = ped
    TaskVehicleChase(ped, pp)
    SetTaskVehicleChaseBehaviorFlag(ped, 1, true)
    SetDriveTaskDrivingStyle(ped, 786468) -- agresiv
    SetPedKeepTask(ped, true)
    return veh, ped
end

-- =====================================================================
--  Props (livrari)
-- =====================================================================
local function attachProp(prop)
    if not prop or not loadModel(prop.model) then
        if prop then notify('~o~(prop indisponibil: ' .. tostring(prop.model) .. ')') end
        return
    end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local obj = CreateObject(GetHashKey(prop.model), c.x, c.y, c.z + 0.2, true, true, true)
    local bone = GetPedBoneIndex(ped, prop.bone or 28422)
    local p, r = prop.pos or vec3(0.12, 0.0, -0.02), prop.rot or vec3(0.0, 0.0, 0.0)
    AttachEntityToEntity(obj, ped, bone, p.x, p.y, p.z, r.x, r.y, r.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(GetHashKey(prop.model))
    heldProps[#heldProps + 1] = obj
end

local function clearHeldProps()
    for _, obj in ipairs(heldProps) do
        if DoesEntityExist(obj) then DetachEntity(obj, true, true); DeleteEntity(obj) end
    end
    heldProps = {}
end

-- =====================================================================
--  Cleanup
-- =====================================================================
local function clearWanted()
    if A.setWanted then
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        A.setWanted = false
    end
end

local function cleanupStepEntities()
    A.token = A.token + 1 -- invalideaza thread-urile pasului curent
    for _, e in ipairs(A.peds) do
        if DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true); DeleteEntity(e) end
    end
    for _, e in ipairs(A.vehs) do
        if DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true); DeleteEntity(e) end
    end
    for _, b in ipairs(A.blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    A.peds, A.vehs, A.blips = {}, {}, {}
    clearWanted()
end

local function cleanupQuest()
    cleanupStepEntities()
    clearHeldProps()
end

-- =====================================================================
--  Dialog chat interactiv (NUI)
-- =====================================================================
local dlg = { continue = false, choice = nil, busy = false }

RegisterNUICallback('dlg_next', function(_, cb) dlg.continue = true; cb('ok') end)
RegisterNUICallback('dlg_choice', function(data, cb) dlg.choice = tonumber(data and data.index) or 1; cb('ok') end)

local function waitContinue()
    dlg.continue = false
    while not dlg.continue do Wait(0) end
end

local function runDialogue(npc, ped)
    dlg.busy = true
    local pp = PlayerPedId()
    FreezeEntityPosition(pp, true)
    if ped and DoesEntityExist(ped) then
        TaskTurnPedToFaceEntity(ped, pp, 2000)
        TaskTurnPedToFaceEntity(pp, ped, 800)
    end
    SetNuiFocus(true, true)
    nui({ action = 'dlg_open', npc = npc.npcName or 'NPC' })

    for _, line in ipairs(npc.lines or {}) do
        if line.who == 'choice' then
            local texts = {}
            for i, o in ipairs(line.options) do texts[i] = o.text end
            nui({ action = 'dlg_choices', options = texts })
            dlg.choice = nil
            while not dlg.choice do Wait(0) end
            local opt = line.options[dlg.choice] or line.options[1]
            nui({ action = 'dlg_say', who = 'player', name = 'Tu', text = opt.text })
            waitContinue()
            if opt.reply then
                nui({ action = 'dlg_say', who = opt.reply.who or 'npc', name = (opt.reply.who == 'player') and 'Tu' or (npc.npcName or 'NPC'), text = opt.reply.text })
                waitContinue()
            end
        else
            local name = (line.who == 'player') and 'Tu' or (npc.npcName or 'NPC')
            nui({ action = 'dlg_say', who = line.who, name = name, text = line.text })
            waitContinue()
        end
    end

    nui({ action = 'dlg_close' })
    SetNuiFocus(false, false)
    FreezeEntityPosition(pp, false)
    dlg.busy = false
end

-- =====================================================================
--  Advance / monitor escape
-- =====================================================================
local function advance(tok)
    if tok ~= A.token then return end
    if A.advancing then return end
    A.advancing = true
    cleanupStepEntities()
    TriggerServerEvent('blacksilva-quests:advance', A.quest, A.step)
end

-- monitor comun de "scapare" pentru chase / policeChase
local function monitorEscape(tok, chaserPeds, def, onEscape, labelHint)
    local escapeDist = def.escapeDistance or Config.Chase.escapeDistance
    local escapeTime = def.escapeTime or Config.Chase.escapeTime
    local farSince = nil
    local lastHint = 0
    CreateThread(function()
        while tok == A.token do
            local pp = PlayerPedId()
            local pc = GetEntityCoords(pp)
            local aliveCount, minDist = 0, 99999.0
            for _, ped in ipairs(chaserPeds) do
                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    aliveCount = aliveCount + 1
                    local d = #(pc - GetEntityCoords(ped))
                    if d < minDist then minDist = d end
                end
            end

            if aliveCount == 0 then
                onEscape(true)
                return
            end

            if minDist >= escapeDist then
                if not farSince then farSince = GetGameTimer() end
                if (GetGameTimer() - farSince) >= escapeTime then
                    onEscape(false)
                    return
                end
            else
                farSince = nil
                if GetGameTimer() - lastHint > 5000 then
                    lastHint = GetGameTimer()
                    notify(labelHint or '~y~Nu te opri! Inca esti urmarit!')
                end
            end
            Wait(300)
        end
    end)
end

-- =====================================================================
--  Step handlers
-- =====================================================================
local startStep -- fwd

local function startDialogueStep(q, def, tok)
    local ped = def.npc and spawnNpc(def.npc) or nil
    local target = def.npc and def.npc.coords or nil
    CreateThread(function()
        while tok == A.token do
            if target then
                local pc = GetEntityCoords(PlayerPedId())
                local d = dist3(pc, target)
                if d <= 25.0 then drawMarker(target) end
                if d <= 2.2 and not dlg.busy then
                    helpText('Apasa ~INPUT_PICKUP~ pentru a vorbi')
                    if IsControlJustReleased(0, 38) then
                        runDialogue(def.dialogue, ped)
                        advance(tok); return
                    end
                end
                Wait(0)
            else
                runDialogue(def.dialogue, nil)
                advance(tok); return
            end
        end
    end)
end

local function startGotoStep(def, tok)
    makeBlip(def.coords, def.blip or { sprite = 1, color = 5, label = def.objective or 'Obiectiv', route = true })
    CreateThread(function()
        while tok == A.token do
            local pc = GetEntityCoords(PlayerPedId())
            local d = dist3(pc, def.coords)
            if d <= Config.Marker.drawDistance then drawMarker(def.coords) end
            local okVeh = (not def.inVehicle) or IsPedInAnyVehicle(PlayerPedId(), false)
            if d <= (def.radius or Config.Marker.radius) and okVeh then
                advance(tok); return
            end
            Wait(0)
        end
    end)
end

local function startGivePropStep(def, tok)
    attachProp(def.prop)
    notify('~g~Ai primit: ~w~' .. ((def.prop and def.prop.label) or 'obiect'))
    nui({ action = 'flash', text = '+ ' .. ((def.prop and def.prop.label) or 'obiect') })
    CreateThread(function() Wait(900); advance(tok) end)
end

local function startDeliverPropStep(def, tok)
    local target = def.coords or (def.npc and def.npc.coords)
    if def.npc then spawnNpc(def.npc) end
    makeBlip(target, def.blip or { sprite = 1, color = 2, label = def.objective or 'Livrare', route = true })
    CreateThread(function()
        while tok == A.token do
            local pc = GetEntityCoords(PlayerPedId())
            local d = dist3(pc, target)
            if d <= Config.Marker.drawDistance then drawMarker(target) end
            if d <= (def.radius or Config.Marker.radius) then
                helpText('Apasa ~INPUT_PICKUP~ pentru a preda')
                if IsControlJustReleased(0, 38) then
                    clearHeldProps()
                    notify('~g~Ai predat obiectul cu succes.')
                    advance(tok); return
                end
            end
            Wait(0)
        end
    end)
end

local function startGetVehicleStep(def, tok)
    local c = def.coords
    local veh = nil
    if loadModel(def.model) then
        veh = CreateVehicle(GetHashKey(def.model), c.x, c.y, c.z, c.w or 0.0, false, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        SetVehicleDoorsLocked(veh, 1)
        A.vehs[#A.vehs + 1] = veh
        SetModelAsNoLongerNeeded(GetHashKey(def.model))
    end
    makeBlip(c, def.blip or { sprite = 225, color = 5, label = 'Vehicul tinta', route = true })
    CreateThread(function()
        while tok == A.token do
            local pp = PlayerPedId()
            if veh and DoesEntityExist(veh) and GetVehiclePedIsIn(pp, false) == veh then
                notify('~g~Ai furat vehiculul!')
                -- vehiculul ramane al jucatorului: scoatem din lista de cleanup
                for i = #A.vehs, 1, -1 do if A.vehs[i] == veh then table.remove(A.vehs, i) end end
                SetEntityAsMissionEntity(veh, false, false)
                SetVehicleHasBeenOwnedByPlayer(veh, true)
                advance(tok); return
            end
            local pc = GetEntityCoords(pp)
            if veh and dist3(pc, GetEntityCoords(veh)) <= Config.Marker.drawDistance then drawMarker(GetEntityCoords(veh)) end
            Wait(0)
        end
    end)
end

local function startChaseStep(def, tok)
    local chasers = {}
    for _, c in ipairs(def.chasers or {}) do
        local _, ped = spawnVehChaser(c)
        if ped then chasers[#chasers + 1] = ped end
    end
    notify('~r~Esti urmarit! Scapa de ei sau elimina-i!')
    banner('Urmarire', 'Scapa de urmaritori!')
    monitorEscape(tok, chasers, def, function(allDead)
        notify(allDead and '~g~I-ai eliminat pe toti!' or '~g~Ai scapat de urmaritori!')
        advance(tok)
    end)
end

local function startPoliceChaseStep(def, tok)
    if def.wanted and def.wanted > 0 then
        SetPlayerWantedLevel(PlayerId(), def.wanted, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        A.setWanted = true
    end
    local cops = {}
    local copModels   = { 's_m_y_cop_01', 's_f_y_cop_01' }
    local copVehicles = { 'police', 'police2', 'police3' }
    for i = 1, (def.units or 3) do
        local _, ped = spawnVehChaser({
            model   = copModels[(i % #copModels) + 1],
            vehicle = copVehicles[(i % #copVehicles) + 1],
            weapon  = 'WEAPON_PISTOL',
        })
        if ped then cops[#cops + 1] = ped end
    end
    notify('~r~Politia te urmareste! Scapa de ei!')
    banner('Politia', 'Scapa de urmaritori!')
    monitorEscape(tok, cops, def, function(allDead)
        clearWanted()
        notify('~g~Ai pierdut politia!')
        advance(tok)
    end, '~b~Politia inca te vede! Continua sa conduci!')
end

local function startKillStep(def, tok)
    local targets = {}
    local n = def.count or 3
    for i = 1, n do
        local sp = def.spawn
        local ang = (math.pi * 2) * (i / n)
        local rad = (def.spread or 12.0)
        local c = vec3(sp.x + math.cos(ang) * rad, sp.y + math.sin(ang) * rad, sp.z)
        local ped = spawnHostilePed(def.model or 'g_m_y_mexgang_01', c, def.weapon or 'WEAPON_PISTOL')
        if ped then
            targets[#targets + 1] = ped
            if def.blip then makeEntityBlip(ped, def.blip) end
        end
    end
    notify(('~r~Elimina toate tintele (0/%d)'):format(n))
    CreateThread(function()
        local lastDead = -1
        while tok == A.token do
            local dead = 0
            for _, ped in ipairs(targets) do
                if not DoesEntityExist(ped) or IsEntityDead(ped) then dead = dead + 1 end
            end
            if dead ~= lastDead then
                lastDead = dead
                hudUpdate(Config.Quests[A.quest].title, ('%s (%d/%d)'):format(def.objective or 'Elimina tintele', dead, n), A.step, #Config.Quests[A.quest].steps)
            end
            if dead >= n then
                notify('~g~Toate tintele eliminate!')
                advance(tok); return
            end
            Wait(500)
        end
    end)
end

local function startHideVehicleStep(def, tok)
    makeBlip(def.coords, def.blip or { sprite = 357, color = 2, label = 'Ascunzatoare', route = true })
    CreateThread(function()
        while tok == A.token do
            local pp = PlayerPedId()
            local pc = GetEntityCoords(pp)
            local d = dist3(pc, def.coords)
            if d <= Config.Marker.drawDistance then drawMarker(def.coords) end
            if d <= (def.radius or 5.0) then
                if IsPedInAnyVehicle(pp, false) then
                    helpText('Apasa ~INPUT_PICKUP~ pentru a ascunde vehiculul')
                    if IsControlJustReleased(0, 38) then
                        local veh = GetVehiclePedIsIn(pp, false)
                        TaskLeaveVehicle(pp, veh, 0)
                        Wait(900)
                        if DoesEntityExist(veh) then SetEntityAsMissionEntity(veh, true, true); DeleteEntity(veh) end
                        notify('~g~Vehicul ascuns. Nimeni nu il va gasi.')
                        advance(tok); return
                    end
                else
                    helpText('Adu vehiculul aici')
                end
            end
            Wait(0)
        end
    end)
end

local function startSceneStep(def, tok)
    banner(def.title or 'Atentie', def.text or '')
    if def.text then notify('~y~' .. def.text) end
    CreateThread(function() Wait(def.duration or 4000); advance(tok) end)
end

startStep = function(q, idx, def)
    A.advancing = false
    hudUpdate(q.title, def.objective or q.description or '', idx, #q.steps)
    if idx == 1 then banner(q.title, q.intro or 'Misiune noua') end
    local tok = A.token
    local t = def.type
    if     t == 'dialogue'    then startDialogueStep(q, def, tok)
    elseif t == 'goto'        then startGotoStep(def, tok)
    elseif t == 'giveProp'    then startGivePropStep(def, tok)
    elseif t == 'deliverProp' then startDeliverPropStep(def, tok)
    elseif t == 'getVehicle'  then startGetVehicleStep(def, tok)
    elseif t == 'chase'       then startChaseStep(def, tok)
    elseif t == 'policeChase' then startPoliceChaseStep(def, tok)
    elseif t == 'killTargets' then startKillStep(def, tok)
    elseif t == 'hideVehicle' then startHideVehicleStep(def, tok)
    elseif t == 'scene'       then startSceneStep(def, tok)
    else
        notify('~r~Pas necunoscut: ' .. tostring(t))
        advance(tok)
    end
end

-- =====================================================================
--  Apply state (din server) - diff + start
-- =====================================================================
local function applyState(quest, step)
    if quest == A.quest and step == A.step then return end
    -- reset complet daca s-a schimbat quest-ul sau am dat inapoi (/quest set)
    if quest ~= A.quest or step < A.step then cleanupQuest() else cleanupStepEntities() end
    A.quest, A.step = quest, step

    local q = Config.Quests[quest]
    if not q then hudHide(); return end
    local def = q.steps[step]
    if not def then
        hudHide()
        banner('Felicitari!', 'Ai terminat toate misiunile disponibile.')
        return
    end
    startStep(q, step, def)
end

-- =====================================================================
--  Sync server -> client
-- =====================================================================
RegisterNetEvent('blacksilva-quests:state', function(data)
    State.quest = data.quest or 0
    State.step  = data.step or 0
    completedMap = data.completed or {}
    applyState(State.quest, State.step)
end)

RegisterNetEvent('blacksilva-quests:forceCleanup', function()
    cleanupQuest()
    A.quest, A.step = 0, 0
end)

RegisterNetEvent('blacksilva-quests:reward', function(money, xp, title)
    banner('Misiune Completa', (title or '') .. (money and (' · $' .. money) or ''))
    PlaySoundFrontend(-1, 'CHALLENGE_UNLOCKED', 'HUD_AWARDS', true)
    if money and money > 0 then notify(('~g~Recompensa: ~w~$%s'):format(money)) end
    if xp and xp > 0 then notify(('~y~+%d XP'):format(xp)) end
end)

RegisterNetEvent('blacksilva-quests:notify', function(msg) notify(msg) end)

RegisterNetEvent('esx:playerLoaded', function()
    Wait(1500)
    TriggerServerEvent('blacksilva-quests:request')
end)

CreateThread(function()
    Wait(2500)
    if ESX.IsPlayerLoaded() then TriggerServerEvent('blacksilva-quests:request') end
end)

-- =====================================================================
--  Death watch - cleanup + restart pas curent dupa respawn
-- =====================================================================
CreateThread(function()
    while true do
        Wait(500)
        if A.quest > 0 and IsEntityDead(PlayerPedId()) and not dlg.busy then
            cleanupQuest()
            local q, s = A.quest, A.step
            A.quest, A.step = 0, 0
            notify('~r~Ai esuat misiunea. Reincepe pasul curent.')
            while IsEntityDead(PlayerPedId()) do Wait(500) end
            Wait(2500)
            TriggerServerEvent('blacksilva-quests:request')
        end
    end
end)

-- =====================================================================
--  Jurnal de misiuni (F5)
-- =====================================================================
local journalOpen = false
local function buildJournalList()
    local list = {}
    for id = 1, 1000 do
        local q = Config.Quests[id]
        if not q then break end
        list[#list + 1] = { id = id, title = q.title, done = completedMap[tostring(id)] == true, current = (id == State.quest) }
    end
    return list
end

local function openJournal()
    if journalOpen or dlg.busy then return end
    journalOpen = true
    local q = Config.Quests[State.quest]
    local def = q and q.steps[State.step]
    SetNuiFocus(true, true)
    nui({
        action = 'journal', show = true,
        quest = q and {
            id = State.quest, title = q.title, desc = q.description,
            objective = def and def.objective or 'Misiune terminata',
            step = State.step, total = q and #q.steps or 0,
        } or nil,
        list = buildJournalList(),
    })
end

local function closeJournal()
    if not journalOpen then return end
    journalOpen = false
    SetNuiFocus(false, false)
    nui({ action = 'journal', show = false })
end

RegisterNUICallback('journal_close', function(_, cb) closeJournal(); cb('ok') end)
RegisterNUICallback('journal_track', function(data, cb)
    -- pune ruta GPS catre obiectivul curent
    local q = Config.Quests[State.quest]
    local def = q and q.steps[State.step]
    local c = def and (def.coords or (def.npc and def.npc.coords) or def.spawn)
    if c then SetNewWaypoint(c.x + 0.0, c.y + 0.0); notify('~y~GPS setat catre obiectiv.') end
    cb('ok')
end)

RegisterCommand('bs_quest_journal', function()
    if journalOpen then closeJournal() else openJournal() end
end, false)
RegisterKeyMapping('bs_quest_journal', 'Jurnal Misiuni', 'keyboard', Config.JournalKey)

RegisterNetEvent('blacksilva-quests:openJournal', function() openJournal() end)

-- =====================================================================
--  Cleanup la oprirea resursei
-- =====================================================================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupQuest()
    if journalOpen or dlg.busy then SetNuiFocus(false, false) end
    FreezeEntityPosition(PlayerPedId(), false)
end)
