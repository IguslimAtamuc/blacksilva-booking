function simulateGtaTurboPressure()
    local throttle = vehicleThrottle
    local rpm = vehicleGameCurrentRpm

    if rpm < 0.25 then
        throttle = 0.1
    end

    local targetPressure = -1.0 + throttle
    if targetPressure < vehicleCurrentSimulatedTurboPressure and throttle < 1.0 then
        vehicleCurrentSimulatedTurboPressure = vehicleCurrentSimulatedTurboPressure - (0.5 * gameDeltaTime)
        if vehicleCurrentSimulatedTurboPressure < -1.0 then
            vehicleCurrentSimulatedTurboPressure = -1.0
        end
    else
        vehicleCurrentSimulatedTurboPressure = vehicleCurrentSimulatedTurboPressure + (0.5 * gameDeltaTime)
        if vehicleCurrentSimulatedTurboPressure > 1.0 then
            vehicleCurrentSimulatedTurboPressure = 1.0
        end
    end
end

function buildAntilag()
    local vehConfig = vehicleConfig[currentVehicle].forcedInduction
    antiLagEnabled = vehConfig.hasAntilag

    if vehicleIsElectric then
        antiLagEnabled = false
        return
    end

    local profile = vehConfig.antiLagProfile
    if antiLagConfig[profile] == nil then
        currentAntilagBank = "antilag_01"
    else
        currentAntilagBank = antiLagConfig[profile].audioBank
    end

    CacheSoundBank("dynamic_antilag", currentAntilagBank)
end

function simulateTurboPressure()
    local throttle = vehicleThrottle
    local rpm = vehicleGameCurrentRpm
    local dt = gameDeltaTime

    local rpmFactor = math.max(0.0, math.min(1.0, (rpm - 0.34) / (0.6 - 0.34))) ^ 4.0

    local baseBoost = -0.9
    local boostTarget = nil
    if throttle > 0.02 then
        boostTarget = baseBoost + (2.0 * throttle * rpmFactor)
    else
        boostTarget = baseBoost
    end

    local boostRate = (1.33 * rpmFactor) + 0.1
    local currentRpmValue = map(math.max(0.2, vehicleGameCurrentRpm), 0.2, 1.0, 1000, 7700)

    local thresholdRpm = (antiLagEnabled and throttle == 0) and 2500 or 0
    antiLagActive = currentRpmValue > thresholdRpm

    local targetPressure = 0
    if antiLagActive then
        local popFrequency = (currentRpmValue / 60) * 5 * (dt / 2)
        local loadFactor = math.max(0, vehicleCurrentSimulatedTurboPressure or 0) / 1.0
        local popProbability = 0.6 * loadFactor

        alsBackfireAccumulator = alsBackfireAccumulator + popFrequency

        local popCount = 0
        while alsBackfireAccumulator >= 1.0 do
            if isInLaunchControlMode then
                if boostTarget > vehicleCurrentSimulatedTurboPressure then
                    vehicleCurrentSimulatedTurboPressure = vehicleCurrentSimulatedTurboPressure + math.min(boostTarget - vehicleCurrentSimulatedTurboPressure, boostRate * 5 * dt)
                end
            end

            alsBackfireAccumulator = alsBackfireAccumulator - 1.0
            if math.random() < popProbability then
                popCount = popCount + 1
                playAntilagPop()
            end
        end

        if popCount > 0 then
            networkIsAntilagActive = true
            targetPressure = math.min(0.8, -0.2 + (popCount * 0.06 * 0.6))
        else
            networkIsAntilagActive = false
            targetPressure = math.max(-0.2 - (0.5 * dt), -0.2 + (0.6 * 0.4 * math.min(1.0, (currentRpmValue - 1000) / (7700 - 1000))))
        end

        if networkIsAntilagActive ~= networkShouldSyncAntilag then
            TriggerServerEvent("dynamic:syncState", vehicleNetId, 6, { networkIsAntilagActive, currentVehicle })
            networkShouldSyncAntilag = networkIsAntilagActive
        end

        if targetPressure > vehicleCurrentSimulatedTurboPressure then
            vehicleCurrentSimulatedTurboPressure = math.min(vehicleCurrentSimulatedTurboPressure + (1.1 * 0.6 * dt), targetPressure)
        end
        if targetPressure < vehicleCurrentSimulatedTurboPressure then
            vehicleCurrentSimulatedTurboPressure = math.max(vehicleCurrentSimulatedTurboPressure - (0.9 * 0.6 * dt), targetPressure)
        end
    else
        networkIsAntilagActive = false
        if networkIsAntilagActive ~= networkShouldSyncAntilag then
            TriggerServerEvent("dynamic:syncState", vehicleNetId, 6, { networkIsAntilagActive, currentVehicle })
            networkShouldSyncAntilag = networkIsAntilagActive
        end

        alsBackfireAccumulator = 0.0
        if boostTarget > vehicleCurrentSimulatedTurboPressure then
            vehicleCurrentSimulatedTurboPressure = vehicleCurrentSimulatedTurboPressure + math.min(boostTarget - vehicleCurrentSimulatedTurboPressure, boostRate * dt)
        else
            vehicleCurrentSimulatedTurboPressure = vehicleCurrentSimulatedTurboPressure - math.min(vehicleCurrentSimulatedTurboPressure - boostTarget, 5.0 * dt)
        end
    end

    if vehicleCurrentSimulatedTurboPressure > 1.0 then
        vehicleCurrentSimulatedTurboPressure = 1.0
    end
    if vehicleCurrentSimulatedTurboPressure < -1.0 then
        vehicleCurrentSimulatedTurboPressure = -1.0
    end

    SetVehicleTurboPressure(vehicle, vehicleCurrentSimulatedTurboPressure)
end

function playAntilagPop()
    if popsPlayingAmmount >= maxPopAmmountMain then
        return
    end

    SetAbilityBarVisibilityInMultiplayer(false)
    SetVehicleNitroEnabled(vehicle, true)

    local soundId = PlayEntitySound(exhaustPopAudioNode, currentAntilagBank .. "_scsnd", "dynamic_antilag", 0, currentAntilagBank)
    if soundId then
        popsPlayingAmmount = popsPlayingAmmount + 1
        local startTime = globalGameTimer

        while globalGameTimer - startTime < math.random(75, 200) do
            Citizen.Wait(0)
            SetAbilityBarVisibilityInMultiplayer(false)
        end

        SetVehicleNitroEnabled(vehicle, false)
        SetAbilityBarVisibilityInMultiplayer(false)
        table.insert(trackedSounds, soundId)
    end
end

function playAntilagPopOnEntity(entity, vehicleModelHash)
    if networkEntityPops[entity] == nil then
        networkEntityPops[entity] = {
            ammount = 0,
            soundIds = {}
        }
    end

    if networkEntityPops[entity].ammount >= maxPopAmmountNpc then
        return
    end

    local profileName = vehicleConfig[vehicleModelHash].forcedInduction.antiLagProfile
    local bankName = antiLagConfig[profileName] == nil and "antilag_01" or antiLagConfig[profileName].audioBank

    SetVehicleNitroEnabled(entity, true)
    local soundId = PlayEntitySound(entity, bankName .. "_scsnd", "dynamic_antilag", 0, bankName)

    if soundId then
        networkEntityPops[entity].ammount = networkEntityPops[entity].ammount + 1
        Citizen.Wait(math.random(75, 200))
        SetVehicleNitroEnabled(entity, false)
        table.insert(networkEntityPops[entity].soundIds, soundId)
    end
end

function ensureModelLoaded(model)
    local modelHash = type(model) == "number" and model or GetHashKey(model)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Citizen.Wait(0)
        end
    end
    return modelHash
end

function toggleAntilag()
    antiLagEnabled = not antiLagEnabled
    return antiLagEnabled
end

function getAntilag()
    return antiLagEnabled
end

function PlayBoneSound(soundName, boneIndex, bankName, param4, param5, bankSubName)
    param4 = param4 or 0
    param5 = param5 or 0

    local bankPath = ""
    if 0 ~= param4 then
        bankPath = bankPath .. param4 .. "/"
    end
    if bankSubName ~= nil then
        bankPath = bankPath .. bankSubName
    end
    bankPath = bankPath:lower()

    local isCached = false
    for _, cachedBank in pairs(currentCachedAudioBanks) do
        if cachedBank == bankPath then
            isCached = true
            break
        end
    end

    if bankSubName ~= nil then
        if bankPath ~= lastLoadedBank and not isCached then
            RequestScriptAudioBankAsync(bankPath)
            lastLoadedBank = bankPath
        end
    end

    local soundId = GetSoundId()
    local boneWorldPos = GetWorldPositionOfEntityBone(vehicle, boneIndex)

    PlaySoundFromCoord(soundId, bankName, boneWorldPos.x, boneWorldPos.y, boneWorldPos.z, param4, false, 0, false)
    ReleaseSoundId(soundId)

    return soundId
end

function clearAntilagVariables()
    alsBackfireAccumulator = alsBackfireAccumulator or 0.0
    hasFinishedPlayingSound = true
    exhaustPopAudioNode = 0
    refreshPopVfxTime = 0
    popsPlayingAmmount = 0
    maxPopAmmountMain = 9
    trackedSounds = {}
    antiLagActive = false
    antiLagEnabled = false
    currentAntilagBank = ""
end
