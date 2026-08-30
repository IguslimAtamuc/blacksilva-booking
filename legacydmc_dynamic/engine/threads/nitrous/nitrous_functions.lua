function setNitrous(tankDurationSec, powerMultiplier)
    hasNitrous = true
    local durationMs = math.max(1.0, math.abs(tankDurationSec)) * 1000.0
    nitrousTankTime = durationMs
    nitrousTankPercentRef = durationMs
    nitrousPowerMulti = math.max(1.0, math.abs(powerMultiplier))
    nitrousPercent = 1.0
end

function removeNitrous()
    hasNitrous = false
    nitrousTankTime = 0.0
    nitrousTankPercentRef = 0.0
    nitrousPowerMulti = 0.0
end

function chargeNitrous(addTimeSec)
    local addMs = addTimeSec * 1000.0
    nitrousTankTime = math.min(nitrousTankPercentRef, nitrousTankTime + addMs)
    nitrousPercent = nitrousTankTime / nitrousTankPercentRef
end

function getCurrentNitrousPercent()
    return nitrousPercent
end

function getCurrentNitrousPowerMulti()
    return nitrousPowerMulti
end

function getCurrentNitrousTankSize()
    return nitrousTankTime / 1000.0
end

function endNitrous()
    isNitrousActive = false
    SetVehicleNitroEnabled(vehicle, false)

    if hasSyncedNitrousFx then
        TriggerServerEvent("dynamic:syncState", vehicleNetId, 9, { false, globalGameTimer })
        hasSyncedNitrousFx = false
    end
    StopTrailFx(vehicle)
end

function forceNitrousState(state, powerMult)
    isNitrousActive = state
    nitrousPowerMulti = powerMult or 2.5
end

function clearNitrousVars()
    isNitrousActive = false
    hasNitrous = false
    nitrousActivatedTime = 0
    nitrousTankPercentRef = 0
    nitrousTankTime = 0
    nitrousTankTimeUsed = 0
    nitrousTankRemainingTime = 0
    nitrousPowerMulti = 2.5
    nitrousPercent = 1.0
    nitrousSoundId = 0
end

trailFxData = {}

function InitializeTrailFxForVehicle(veh)
    if not trailFxData[veh] then
        trailFxData[veh] = {
            handles = {},
            boneNames = { "taillight_l", "taillight_r" },
            status = "Empty",
            enabled = true,
            offset = vector3(0, 0, 0),
            rotation = vector3(0, 0, 0),
            color = { r = 1.0, g = 0.0, b = 0.0 },
            scale = 1.0,
            alpha = 1.0,
            evolution = 1.0
        }
    end
end

function StartTrailFx(veh)
    InitializeTrailFxForVehicle(veh)
    local fx = trailFxData[veh]
    if not fx or not fx.enabled then return end

    if #fx.handles > 0 then return end

    for _, boneName in ipairs(fx.boneNames) do
        local boneIdx = GetEntityBoneIndexByName(veh, boneName)
        if boneIdx ~= -1 then
            UseParticleFxAssetNextCall("core")
            local handle = StartParticleFxLoopedOnEntityBone("veh_light_red_trail", veh, fx.offset.x, fx.offset.y, fx.offset.z, fx.rotation.x, fx.rotation.y, fx.rotation.z, boneIdx, fx.scale, false, false, false)
            SetParticleFxLoopedEvolution(handle, "speed", fx.evolution, false)
            SetParticleFxLoopedColour(handle, fx.color.r, fx.color.g, fx.color.b, false)
            SetParticleFxLoopedAlpha(handle, fx.alpha)
            table.insert(fx.handles, handle)
        end
    end
    fx.status = "Full"
end

function StopTrailFx(veh)
    local fx = trailFxData[veh]
    if fx then
        for _, handle in ipairs(fx.handles) do
            StopParticleFxLooped(handle, false)
        end
        fx.handles = {}
        fx.status = "Empty"
    end
end

function UpdateTrailFx(veh)
    local fx = trailFxData[veh]
    if fx then
        for _, handle in ipairs(fx.handles) do
            SetParticleFxLoopedAlpha(handle, fx.alpha)
            SetParticleFxLoopedScale(handle, fx.scale)
            SetParticleFxLoopedEvolution(handle, "speed", fx.evolution, false)
        end
    end
end

function LoopTrailFx(veh)
    InitializeTrailFxForVehicle(veh)
    local fx = trailFxData[veh]
    if not fx or not fx.enabled then return end

    if fx.status == "Empty" then
        StartTrailFx(veh)
    else
        UpdateTrailFx(veh)
    end
end
