local frontMassConstant = 2500
local rearMassConstant = 333
local ambientTemp = 525
local maxBrakeTemp = 800
local minBrakeEffectiveness = 0.5
local coolingFactor = 1.0 / (maxBrakeTemp - ambientTemp)
local enableTuning = physicsSettings.upgradeData.enableVanillaTuningIntegration
local brakesPowerFactor = physicsSettings.upgradeData.brakesPowerMultiplierFactor
local brakesPowerList = physicsSettings.upgradeData.brakesPowerMultiplier

function UpdateBrakeSystem()
    local modLevel = math.min(2, GetVehicleMod(vehicle, 12))
    local modRatio = 1.0
    local powerMulti = 1.0

    if modLevel >= 0 then
        if enableTuning then
            local modValue = GetVehicleModModifierValue(vehicle, 12, modLevel) / 100
            modRatio = 1.0 / (1.0 + (0.1 * modValue))
            powerMulti = 1.0 + (brakesPowerFactor * brakesPowerList[modLevel + 1])
        end
    end

    if lastBrakeStage ~= modLevel then
        if enableTuning then
            lastBrakeStage = modLevel
            local brakeForce = vehicleConfig[currentVehicle].brakes.brakeForce + 0.0
            local peakG = tireConfig[vehicleConfig[currentVehicle].tyre.tyreCompound].peakTractionG

            vehicleBrakingForce = brakeForce * modRatio * powerMulti
            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", vehicleBrakingForce)
            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fHandBrakeForce", (peakG / 4) * 0.85)
        end
    end

    local baseTemp = 25
    local throttle = vehicleBrakes
    local speed = vehicleSpeed
    local mass = vehicleCurrentSimulatedWeight
    local brakeForce = vehicleBrakingForce
    local heatGenMulti = physicsSettings.experienceData.brakeHeatGeneratorMultiplier
    local chassisConfig = vehicleConfig[currentVehicle].chassis
    local gravity = 9.81

    local totalWork = mass * brakeForce * throttle * gravity
    local heatGenerated = 0.0

    if throttle > 0.0 then
        heatGenerated = totalWork * heatGenMulti * speed * gameDeltaTime
    end

    local weightDistFront = chassisConfig.frontWeightDist
    if isCurrentVehicleMotorcycle then
        weightDistFront = 0.5
    end

    local frontWheelLoad = 0.0
    local rearWheelLoad = 0.0

    if isCurrentVehicleMotorcycle then
        frontWheelLoad = vehicleWheels[2].wheelLoad
        rearWheelLoad = vehicleWheels[1].wheelLoad
    else
        frontWheelLoad = vehicleWheels[1].wheelLoad + vehicleWheels[2].wheelLoad
        rearWheelLoad = vehicleWheels[3].wheelLoad + vehicleWheels[4].wheelLoad
    end

    local totalLoad = frontWheelLoad + rearWheelLoad
    local dynamicWeightDistFront = weightDistFront
    local dynamicWeightDistRear = 1.0 - weightDistFront

    if totalLoad > 0.0 then
        dynamicWeightDistFront = frontWheelLoad / totalLoad
        dynamicWeightDistRear = rearWheelLoad / totalLoad
    end

    local frontHeatShare = 0.0
    local rearHeatShare = 0.0

    if throttle > 0.0 then
        frontHeatShare = heatGenerated * dynamicWeightDistFront
        rearHeatShare = heatGenerated * dynamicWeightDistRear
    end

    local frontCapacity = frontMassConstant * weightDistFront
    local rearCapacity = frontMassConstant * (1.0 - weightDistFront)
    local frontCoolingCoeff = rearMassConstant * weightDistFront
    local rearCoolingCoeff = rearMassConstant * (1.0 - weightDistFront)

    local deltaTempFront = math.max(0, brakeTempFront - baseTemp)
    local frontCooling = (frontCoolingCoeff + (0.0001 * speed)) * deltaTempFront * gameDeltaTime
    local frontRadCooling = (0.000002 * (deltaTempFront ^ 2)) * gameDeltaTime
    local frontHeatLoss = (frontCooling + frontRadCooling) * 0.9

    brakeTempFront = brakeTempFront + ((frontHeatShare * 2) - frontHeatLoss) / frontCapacity
    if brakeTempFront < baseTemp then
        brakeTempFront = baseTemp
    end

    local deltaTempRear = math.max(0, brakeTempRear - baseTemp)
    local rearCooling = (rearCoolingCoeff + (0.0001 * speed)) * deltaTempRear * gameDeltaTime
    local rearRadCooling = (0.000002 * (deltaTempRear ^ 2)) * gameDeltaTime
    local rearHeatLoss = (rearCooling + rearRadCooling) * 0.9

    brakeTempRear = brakeTempRear + ((rearHeatShare * 2) - rearHeatLoss) / rearCapacity
    if brakeTempRear < baseTemp then
        brakeTempRear = baseTemp
    end

    local avgTemp = (brakeTempFront * weightDistFront) + (brakeTempRear * (1.0 - weightDistFront))

    if avgTemp < ambientTemp then
        brakeEffectiveness = 1.0
    elseif avgTemp < maxBrakeTemp then
        local factor = (avgTemp - ambientTemp) / (maxBrakeTemp - ambientTemp)
        brakeEffectiveness = 1.0 - (factor * (1.0 - minBrakeEffectiveness))
    else
        brakeEffectiveness = minBrakeEffectiveness
    end

    local activeDeltaFront = math.max(0, brakeTempFront - baseTemp)
    local activeDeltaRear = math.max(0, brakeTempRear - baseTemp)

    local frontHeatTotal = frontCapacity * activeDeltaFront
    local rearHeatTotal = rearCapacity * activeDeltaRear
    local totalHeat = frontHeatTotal + rearHeatTotal

    local calcFrontMulti = weightDistFront
    local calcRearMulti = 1.0 - weightDistFront

    if totalHeat > 0.0 then
        calcFrontMulti = frontHeatTotal / totalHeat
        calcRearMulti = rearHeatTotal / totalHeat
    end

    brakeTemp = (brakeTempFront + brakeTempRear) / 2
    if debugBrakeTemp then
        brakeTemp = 5000
    end

    frontBrakeMulti = calcFrontMulti
    rearBrakeMulti = calcRearMulti
end

function loadBrakeData()
    local brakeConfig = vehicleConfig[currentVehicle].brakes
    local peakG = tireConfig[vehicleConfig[currentVehicle].tyre.tyreCompound].peakTractionG

    vehicleBrakingForce = brakeConfig.brakeForce + 0.0
    vehicleBrakingBias = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeBiasFront")

    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", vehicleBrakingForce)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fHandBrakeForce", (peakG / 4) * 0.85)

    debugPrint("Loaded Brake Data!")
end

function clearBrakeVariables()
    if activeParticles[previousVehicle] then
        for _, p in ipairs(activeParticles[previousVehicle]) do
            StopParticleFxLooped(p.handle, 0)
        end
        activeParticles[previousVehicle] = nil
    end

    brakeTempFront = 25
    brakeTempRear = 25
    brakeTemp = 25
    frontBrakeMulti = 0.5
    rearBrakeMulti = 0.5
    brakeEffectiveness = 1.0
    debugBrakeTemp = false
    activeParticles = {}
    networkIsBraking = false
    networkShouldSyncBrakes = false
    networkUpdateBrakeTemperature = false
    networkUpdateTempLastRequestTime = 0
end

function HandleRemoteBrakeParticles(entity, modelHash, tempFront, tempRear, totalTemp)
    local isBike = IsThisModelABike(GetEntityModel(entity))

    if not activeParticles[entity] then
        activeParticles[entity] = {}
        local fxGroup = "core"
        local fxName = "veh_exhaust_afterburner"
        local wheelIndices = cachedWheelIndex[entity]

        if not HasNamedPtfxAssetLoaded(fxGroup) do
            RequestNamedPtfxAsset(fxGroup)
            while not HasNamedPtfxAssetLoaded(fxGroup) do
                Citizen.Wait(0)
            end
        end

        if isBike then
            local offsets = vehicleConfig[modelHash].offsets.bikeBrakeGlow
            local maxSeatIndex = offsets.usesDualDiskFrontBrake and 5 or 3

            for i = 0, maxSeatIndex do
                local sideSign = (i > 1) and 1 or -1
                local wheelIdx = i
                if i > 1 and i < 4 then wheelIdx = wheelIdx - 2 end
                if i >= 4 then
                    wheelIdx = wheelIdx - wheelIdx
                    if 4 == i then sideSign = 1 end
                    if 5 == i then sideSign = -1 end
                end

                local boneIdx = wheelIndices[wheelIdx]
                if boneIdx and -1 ~= boneIdx then
                    UseParticleFxAssetNextCall(fxGroup)
                    local settings = vehicleConfig[modelHash].offsets.bikeBrakeGlow.brakeDiskSettings

                    local radius = (0 == wheelIdx) and settings.bikeGlowBrakeFrontRadius or settings.bikeGlowBrakeRearRadius
                    local diskWidth = (0 == wheelIdx) and settings.bikeGlowBrakeFrontDiskWidth or settings.bikeGlowBrakeRearDiskWidth
                    local diskOffset = (0 == wheelIdx) and settings.bikeGlowBrakeFrontOffset or settings.bikeGlowBrakeRearOffset
                    local diskSpacing = (i >= 4) and offsets.bikeGlowBrakeFrontSpacing or 0.0
                    local isFrontOrDual = (0 == wheelIdx or i >= 4) and 0.0 or 1.0

                    local fxHandle = StartParticleFxLoopedOnEntityBone(
                        fxName,
                        entity,
                        (diskWidth * sideSign) + diskOffset + diskSpacing,
                        0.0, 0.0, 0.0, 0.0, 90.0,
                        boneIdx,
                        radius,
                        false, false, false
                    )

                    local multi = (wheelIdx < 1) and tempFront or tempRear
                    local alpha = math.min(1.0, map(totalTemp * multi, 450, 800, 0.2, 1.0))

                    SetParticleFxLoopedAlpha(fxHandle, alpha)
                    table.insert(activeParticles[entity], {
                        handle = fxHandle,
                        wheelIndex = isFrontOrDual
                    })
                end
            end
        else
            for i = 0, 3 do
                local boneIdx = wheelIndices[i]
                if boneIdx and -1 ~= boneIdx then
                    UseParticleFxAssetNextCall(fxGroup)
                    local offsets = vehicleConfig[currentVehicle].offsets.carBrakeGlow

                    local fxHandle = StartParticleFxLoopedOnEntityBone(
                        fxName,
                        entity,
                        offsets.carGlowBrakeXOffset,
                        0.0, 0.0, 0.0, 0.0, 90.0,
                        boneIdx,
                        offsets.glowBrakeRadius,
                        false, false, false
                    )

                    local multi = (i < 2) and tempFront or tempRear
                    local alpha = math.min(1.0, map(totalTemp * multi, 450, 800, 0.2, 1.0))

                    SetParticleFxLoopedAlpha(fxHandle, alpha)
                    table.insert(activeParticles[entity], {
                        handle = fxHandle,
                        wheelIndex = i
                    })
                end
            end
        end
    else
        if isBike then
            for _, p in ipairs(activeParticles[entity]) do
                local multi = (p.wheelIndex < 1) and tempFront or tempRear
                local alpha = math.min(1.0, map(totalTemp * multi, 450, 800, 0.2, 1.0))
                SetParticleFxLoopedAlpha(p.handle, alpha)
            end
        else
            for _, p in ipairs(activeParticles[entity]) do
                local multi = (p.wheelIndex < 2) and tempFront or tempRear
                local alpha = math.min(1.0, map(totalTemp * multi, 450, 800, 0.2, 1.0))
                SetParticleFxLoopedAlpha(p.handle, alpha)
            end
        end
    end
end

function getBrakeTemp()
    return brakeTemp
end

function setBrakeTemp(val)
    brakeTemp = val
end

function toggleBrakeDebug()
    debugBrakeTemp = not debugBrakeTemp
    if not debugBrakeTemp then
        brakeTemp = 25
    end
    return debugBrakeTemp
end

function debugSetBrakeFadeRadius(scale)
    if not isCurrentVehicleMotorycle then
        if activeParticles[vehicle] then
            for _, p in ipairs(activeParticles[vehicle]) do
                SetParticleFxLoopedScale(p.handle, scale)
            end
        end
    end
end

function debugSetBrakeXoffset(offset)
    if not isCurrentVehicleMotorycle then
        if activeParticles[vehicle] then
            for _, p in ipairs(activeParticles[vehicle]) do
                SetParticleFxLoopedOffsets(p.handle, offset, 0.0, 0.0, 0.0, 0.0, 90.0)
            end
        end
    end
end
