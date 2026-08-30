local activeFlywheelSync = {}
local activeDriftSync = {}
local activeAudioEngine = {}
local netSyncDistance = physicsSettings.netSyncData.netSyncDistance

function cacheEntityWheelIndex(veh)
    local rightFrontBone = "wheel_rf"
    if IsThisModelABike(GetEntityModel(veh)) then
        rightFrontBone = "wheel_lr"
    end

    local leftFront = GetEntityBoneIndexByName(veh, "wheel_lf")
    local rightFront = GetEntityBoneIndexByName(veh, rightFrontBone)
    local leftRear = 0
    local rightRear = 0

    if GetVehicleNumberOfWheels(veh) > 2 then
        leftRear = GetEntityBoneIndexByName(veh, "wheel_lr") or 0
    end

    if GetVehicleNumberOfWheels(veh) > 2 then
        rightRear = GetEntityBoneIndexByName(veh, "wheel_rr") or 0
    end

    cachedWheelIndex[veh] = {
        [0] = leftFront,
        [1] = rightFront,
        [2] = leftRear,
        [3] = rightRear
    }
end

AddStateBagChangeHandler("syncBrake", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        cachedWheelIndex[entity] = nil
        activeBrakeThreads[entity] = nil
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local isBraking = value[1]
    local vehicleHash = value[3]

    if not cachedWheelIndex[entity] then
        cacheEntityWheelIndex(entity)
    end

    if isBraking then
        activeBrakeThreads[entity] = {
            vehicleHash = vehicleHash,
            active = true
        }
    else
        activeBrakeThreads[entity] = nil
        SetVehicleBrakeLights(entity, false)

        if activeParticles[entity] then
            local alpha = 1.0
            while alpha > 0 do
                alpha = alpha - 0.05
                for _, particle in ipairs(activeParticles[entity]) do
                    SetParticleFxLoopedAlpha(particle.handle, math.max(alpha, 0.0))
                end
                Citizen.Wait(50)
            end

            for _, particle in ipairs(activeParticles[entity]) do
                StopParticleFxLooped(particle.handle, 0)
            end
            activeParticles[entity] = nil
        end
    end
end)

AddStateBagChangeHandler("syncLaunchControl", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local isLaunchControlActive = value[1]
    local vehicleHash = value[2]
    local config = vehicleConfig[vehicleHash]

    if config ~= nil then
        local targetRpmRange = config.transmission.launchControl.targetRpmRange
        if isLaunchControlActive then
            if activeLaunchControlThreads[entity] == nil then
                activeLaunchControlThreads[entity] = {
                    active = false,
                    rpmData = targetRpmRange
                }
            end
            activeLaunchControlThreads[entity].active = true
            activeLaunchControlThreads[entity].rpmData = targetRpmRange
        else
            activeLaunchControlThreads[entity] = nil
        end
    end
end)

AddStateBagChangeHandler("syncAntiLagSystem", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local isAntiLagActive = value[1]
    local vehicleHash = value[2]

    if isAntiLagActive then
        if activeAntiLagThreads[entity] == nil then
            activeAntiLagThreads[entity] = {
                active = false,
                vehicleHash = vehicleHash
            }
        end
        activeAntiLagThreads[entity].active = true
        activeAntiLagThreads[entity].vehicleHash = vehicleHash

        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 150 do
            Citizen.Wait(0)
            EnableVehicleExhaustPops(vehicle, false)
        end
    else
        activeAntiLagThreads[entity] = nil
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 150 do
            Citizen.Wait(0)
            EnableVehicleExhaustPops(vehicle, true)
        end
    end
end)

AddStateBagChangeHandler("syncFlywheel", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        activeFlywheelSync[entity] = false
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local isActive = value[1]
    local startRpm = value[2]
    local targetRpm = value[3]

    if not isActive then
        activeFlywheelSync[entity] = false
        return
    else
        activeFlywheelSync[entity] = true
    end

    CreateThread(function()
        local lerper = createTimeLerpNet()
        lerper:start(startRpm, 0.2, targetRpm)

        while lerper.active do
            if not DoesEntityExist(entity) then
                break
            end
            if true ~= activeFlywheelSync[entity] then
                break
            end

            local currentRpm = lerper:update()
            SetVehicleCurrentRpm(entity, currentRpm)
            Citizen.Wait(0)
        end

        activeFlywheelSync[entity] = false
    end)
end)

AddStateBagChangeHandler("syncGear", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local currentGear = value[1]
    local nextGear = value[2]
    local maxFlatVel = value[3]
    local totalGears = value[4]
    local isShifting = value[5]

    if DoesEntityExist(entity) then
        if isShifting then
            SetVehicleHandlingFloat(entity, "CHandlingData", "nInitialDriveGears", totalGears + 0.0)
            SetVehicleHighGear(entity, totalGears)
            SetVehicleHandlingFloat(entity, "CHandlingData", "fInitialDriveMaxFlatVel", maxFlatVel + 0.0)

            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 200 do
                Citizen.Wait(0)
                SetVehicleEnginePowerMultiplier(entity, 0.51)
            end
        else
            SetVehicleHandlingFloat(entity, "CHandlingData", "nInitialDriveGears", 1.0)
            SetVehicleHandlingFloat(entity, "CHandlingData", "fInitialDriveMaxFlatVel", maxFlatVel + 0.0)
            SetVehicleHighGear(entity, currentGear > 0 and 1 or 0)
        end

        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 200 do
            Citizen.Wait(0)
            SetVehicleEnginePowerMultiplier(entity, 0.51)
        end
    end
end)

AddStateBagChangeHandler("syncDrift", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        activeDriftSync[entity] = false
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local isDrifting = value[1]
    local targetRpm = value[2] or 0.2
    local stateBag = Entity(entity).state

    if isDrifting then
        if not activeDriftSync[entity] then
            activeDriftSync[entity] = true
            CreateThread(function()
                local currentRpm = GetVehicleCurrentRpm(entity)
                while true do
                    local driftData = stateBag.syncDrift
                    if not DoesEntityExist(entity) then
                        break
                    end
                    if not (activeDriftSync[entity] and driftData) then
                        break
                    end
                    if not driftData[1] then
                        break
                    end

                    local rpmDelta = (1.0 - currentRpm) * 0.07
                    currentRpm = currentRpm + rpmDelta
                    currentRpm = math.clamp(currentRpm, 0.2, 1.0)

                    SetVehicleCurrentRpm(entity, currentRpm)
                    Citizen.Wait(0)
                end
                activeDriftSync[entity] = nil
            end)
        end
    else
        if activeDriftSync[entity] then
            activeDriftSync[entity] = false
        end
    end
end)

AddStateBagChangeHandler("engineSwap", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    local startTime = GetGameTimer()

    while true do
        if entity and DoesEntityExist(entity) then
            break
        end
        if GetGameTimer() - startTime >= 3000 then
            break
        end
        Citizen.Wait(0)
        entity = GetEntityFromStateBagName(bagName)
    end

    if not entity or not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        activeAudioEngine[entity] = nil
        return
    end

    if entity == vehicle then
        return
    end

    local isSwapped = value[1]
    local audioBank = value[2]

    if activeAudioEngine[entity] ~= audioBank then
        ForceUseAudioGameObject(entity, audioBank)
        activeAudioEngine[entity] = audioBank
    end
end)

AddStateBagChangeHandler("syncCamera", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    motionBlurTracked[entity] = false
end)

AddStateBagChangeHandler("syncAudioSfx", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local soundName = value[1]
    local bankName = value[2]
    local categoryName = value[3]

    if DoesEntityExist(entity) then
        CacheSoundBank(bankName, categoryName)
        PlayEntitySound(entity, soundName, bankName, 0, categoryName)

        Citizen.SetTimeout(5000, function()
            releaseAudioBank(bankName, categoryName)
        end)
    end
end)

AddStateBagChangeHandler("syncNitrousFx", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return
    end

    local camCoord = GetFinalRenderedCamCoord()
    local entityCoords = GetEntityCoords(entity)
    if #(camCoord - entityCoords) > netSyncDistance then
        return
    end

    if entity == vehNetSyncCheck then
        return
    end

    local isActive = value[1]

    if isActive then
        if not HasNamedPtfxAssetLoaded("veh_xs_vehicle_mods") then
            RequestNamedPtfxAsset("veh_xs_vehicle_mods")
        end

        InitializeTrailFxForVehicle(entity)
        if trailFx[entity] and "Full" ~= trailFx[entity].status then
            StartTrailFx(entity)
            trailFx[entity].status = "Full"
        end

        activeNitrousThreads[entity] = { active = true }
    else
        SetVehicleNitroEnabled(entity, false)
        if trailFx[entity] then
            trailFx[entity].alpha = 0.0
            StopTrailFx(entity)
            trailFx[entity].status = "Empty"
        end
        activeNitrousThreads[entity] = nil
    end
end)

