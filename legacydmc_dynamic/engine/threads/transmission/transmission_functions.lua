function buildTransmission()
    local config = vehicleConfig[currentVehicle]
    if not config or not config.transmission then return end

    local transConfig = config.transmission
    local transType = transConfig.transmissionType or 2

    if transType < 0 or transType > 3 then
        transType = 2
        debugPrint("[Warning] Unsuported Transmission ID Inputed, Automatic has been loaded by default.")
    end

    vehicleTransmissionTypeId = transType
    vehicleGearCount = transConfig.gearCount or #transConfig.gearRatios

    currentCachedAudioBanks = {}
    local numRatios = #transConfig.gearRatios
    for i = 1, numRatios do
        local ratio = transConfig.gearRatios[i]
        if transType == 3 then
            ratio = 0.9
        end
        table.insert(currentCachedAudioBanks, ratio)
    end

    local revRatio = -transConfig.gearRatios[1]
    table.insert(currentCachedAudioBanks, 1, revRatio)

    vehicleTransmissionMaxSpeed = transConfig.maxSpeed or 200.0
    local maxFlatVel = vehicleTransmissionMaxSpeed * currentCachedAudioBanks[#currentCachedAudioBanks]

    gearTopSpeedsKmh = {}
    for idx, ratio in ipairs(currentCachedAudioBanks) do
        local speedKmh = math.floor((maxFlatVel / ratio) + 0.5)
        table.insert(gearTopSpeedsKmh, speedKmh)
    end

    vehicleShiftingTime = math.max(0.05, transConfig.shiftingTime or 0.2)
    vehicleRpmDecaymentSpeed = math.min(5.0, math.max(1.75, transConfig.rpmDecaymentSpeed or 3.0))

    if transConfig.launchControl then
        vehicleAllowLaunchControl = transConfig.launchControl.enabled or false
        vehicleLaunchControlRpm = transConfig.launchControl.targetRpmRange or 0.6
    else
        vehicleAllowLaunchControl = false
        vehicleLaunchControlRpm = 0.0
    end

    currentTorqueDist = math.abs(transConfig.frontTorqueDist or 0.0)

    if vehicleTransmissionTypeId == 0 or vehicleTransmissionTypeId == 1 then
        atThreadEnabled = false
        transmissionThreadEnabled = true
        startTransmissionThread()
    else
        atThreadEnabled = true
        transmissionThreadEnabled = false
        startAtRevLimiterThread()
    end
end

function getRequestedAccelerationForLaunch()
    local topSpeedMps = (vehicleTransmissionMaxSpeed or 200.0) / 3.6
    local gravity = 9.81
    local launchTimeSec = 0.08

    local lastRatio = currentCachedAudioBanks[#currentCachedAudioBanks] or 1.0
    local accelG = (topSpeedMps / lastRatio) * gravity

    local isInclined = GetEntityPitch(vehicle)
    local inclineG = gravity * math.sin(math.rad(isInclined))
    local totalReqG = (launchTimeSec * gravity) + accelG + inclineG

    return totalReqG / gravity
end

function getTopSpeedTableFromTransmissionData(transData)
    local transType = transData.transmissionType or 2
    local ratios = transData.gearRatios or { 3.333, 1.849, 1.253, 1.011, 0.918 }
    local maxSpeed = transData.maxSpeed or 200.0

    local gearRatios = {}
    for idx, r in ipairs(ratios) do
        local effectiveR = (transType == 3) and 0.9 or r
        table.insert(gearRatios, effectiveR)
    end

    table.insert(gearRatios, 1, -ratios[1])
    local maxFlatVel = maxSpeed * gearRatios[#gearRatios]

    local topSpeeds = {}
    for idx, r in ipairs(gearRatios) do
        local spd = math.floor((maxFlatVel / r) + 0.5)
        table.insert(topSpeeds, spd)
    end

    return topSpeeds
end

function getTopSpeedTable(vehicleHash)
    local vehConfig = vehicleConfig[vehicleHash]
    if not vehConfig or not vehConfig.transmission then return nil end

    return getTopSpeedTableFromTransmissionData(vehConfig.transmission)
end

function getAverageDrivenWheelSpeed()
    if vehicleTransmissionTypeId == 0 then
        return (vehicleWheels[2].speed + vehicleWheels[3].speed) / 2.0
    elseif vehicleTransmissionTypeId == 1 then
        return (vehicleWheels[0].speed + vehicleWheels[1].speed) / 2.0
    elseif vehicleTransmissionTypeId > 0 and vehicleTransmissionTypeId < 1 then
        return (vehicleWheels[0].speed + vehicleWheels[1].speed + vehicleWheels[2].speed + vehicleWheels[3].speed) / 4.0
    else
        return vehicleWheels[1].speed
    end
end

function setupAutomaticTransmission()
    local maxSpeed = vehicleTransmissionMaxSpeed or 200.0
    local lastRatio = currentCachedAudioBanks[#currentCachedAudioBanks] or 1.0
    local maxFlatVel = (maxSpeed * lastRatio) / 1.2

    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", maxFlatVel)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleUpShift", maxSpeed / (vehicleShiftingTime * 1000.0))
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleDownShift", maxSpeed / (vehicleShiftingTime * 1000.0))

    local startTime = GetGameTimer()
    while (GetGameTimer() - startTime) < 125 do
        Citizen.Wait(0)
        SetVehicleCurrentRpm(vehicle, 0.39)
    end

    for i = 0, vehicleGearCount do
        local ratio = currentCachedAudioBanks[i + 1] or 3.333
        SetVehicleHighGear(vehicle, i)
        SetVehicleCurrentGear(vehicle, i)
        Citizen.Wait(0)
    end

    TriggerServerEvent("dynamic:syncState", vehicleNetId, 3, { maxFlatVel, vehicleShiftingTime, currentCachedAudioBanks })
end

function swapToAutomaticTransmission()
    currentVehicleGear = 1
    buildTransmission()
    setupAutomaticTransmission()
    isForcingAutomaticTransmission = true
end

function swapToManualTransmission()
    buildTransmission()
    debugPrint("Transmission thread will start...")
    atThreadEnabled = false
    transmissionThreadEnabled = true
    startTransmissionThread()
end

function shiftGear(targetGear)
    currentVehicleGear = targetGear
    local ratio = currentCachedAudioBanks[currentVehicleGear + 1] or 1.0
    local maxSpeed = vehicleTransmissionMaxSpeed or 200.0
    local maxFlatVel = math.floor((maxSpeed * ratio) / 1.2)

    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", maxFlatVel + 0.0)
    SetVehicleHighGear(vehicle, currentVehicleGear)
    SetVehicleCurrentGear(vehicle, currentVehicleGear)

    TriggerServerEvent("dynamic:syncState", vehicleNetId, 3, { currentVehicleGear, maxFlatVel, ratio })

    local startTime = GetGameTimer()
    vehicleIsCurrentlyShifting = true
    while (GetGameTimer() - startTime) < 125 do
        Citizen.Wait(0)
        SetVehicleCurrentRpm(vehicle, 0.51)
    end
    vehicleIsCurrentlyShifting = false
end

function getSmartRandom()
    local sfxPool = { "1", "2", "3" }
    local available = {}

    for _, sfx in ipairs(sfxPool) do
        if sfx ~= lastPlayedSfx then
            table.insert(available, sfx)
        end
    end

    if #available == 0 then
        available = sfxPool
    end

    local picked = available[math.random(#available)]
    lastPlayedSfx = picked
    return picked
end

function handleGearShiftSound(isUpShift)
    if not useGearSfx or currentGearSfxBank == "" then return end

    local sfxNum = getSmartRandom()
    local soundName = (isUpShift and "paddle_up_" or "paddle_down_") .. sfxNum

    PlaySoundFromEntity(-1, soundName, vehicle, "DYNAMIC_SOUNDBANK", true, 0)
    TriggerServerEvent("dynamic:syncState", vehicleNetId, 5, { soundName, "DYNAMIC_SOUNDBANK" })
end

function buildGearShiftProfile()
    local config = vehicleConfig[currentVehicle]
    if not config or not config.transmission then return end

    local sfxProfile = config.transmission.gearSfxProfile
    if not sfxProfile or sfxProfile == "None" or sfxProfile == "none" then
        currentGearSfxBank = ""
        useGearSfx = false
        return
    end

    currentGearSfxBank = gearShiftProfiles[sfxProfile] and gearShiftProfiles[sfxProfile].audioBank or ""
    useGearSfx = (currentGearSfxBank ~= "")

    if useGearSfx then
        RequestScriptAudioBank("dynamic_gearshift", false)
    end
end

function playGearShiftProfile(isUpShift)
    if not useGearSfx or isGearSfxPlaying then return end

    local profile = gearShiftProfiles[currentGearSfxBank]
    if not profile then return end

    local soundData = isUpShift and profile.upShiftSound or profile.downShiftSound
    if not soundData then return end

    if vehicleGameCurrentRpm >= soundData.rpmTreshold and vehicleThrottle >= soundData.throttleTreshold and vehicleSpeedKmh >= soundData.speedTreshold then
        local soundName = soundData.soundName .. "_scsnd"
        PlaySoundFromEntity(-1, soundName, vehicle, "dynamic_gearshift", true, 0)
        TriggerServerEvent("dynamic:syncState", vehicleNetId, 6, { soundName, "dynamic_gearshift" })

        Citizen.CreateThread(function()
            isGearSfxPlaying = true
            while HasSoundFinished(-1) == false do
                Citizen.Wait(0)
            end
            isGearSfxPlaying = false
        end)
    end
end

function handleUpShiftAnim()
    if isUsingMouseSteer then return end

    local config = vehicleConfig[currentVehicle]
    local animId = config and config.offsets and config.offsets.animation and config.offsets.animation.shiftingAnimId or 0

    if animId == 4 then return end

    local animDict = "dynamic@fpv"
    local animList = { "paddle_up", "shift_up", "shift_up_lhd" }
    local animName = animList[animId + 1] or "paddle_up"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(0)
    end

    isPlayingManualAnim = true
    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, -1, 49, 0.0, false, false, false)

    Citizen.CreateThread(function()
        while GetEntityAnimCurrentTime(PlayerPedId(), animDict, animName) < 0.99 do
            Citizen.Wait(0)
        end
        isPlayingManualAnim = false
        manualAnimLerpTime = 0.0
    end)
end

function clearTransmissionVariables()
    currentVehicleGear = 1
    vehicleGearCount = 5
    vehicleTransmissionMaxSpeed = 200.0
    vehicleShiftingTime = 0.2
    vehicleRpmDecaymentSpeed = 3.0
    vehicleAllowLaunchControl = false
    vehicleLaunchControlRpm = 0.6
    isInLaunchControlMode = false
    isForcingAutomaticTransmission = false
end
