Citizen.CreateThread(function()
    debugPrint("Starting MP Sync Thread!")
    local trackedVehicles = {}

    while true do
        Citizen.Wait(0)

        for veh, _ in pairs(activeAntiLagThreads) do
            trackedVehicles[veh] = true
        end

        for veh, _ in pairs(activeBrakeThreads) do
            trackedVehicles[veh] = true
        end

        for veh, _ in pairs(activeLaunchControlThreads) do
            trackedVehicles[veh] = true
        end

        for veh, _ in pairs(activeNitrousThreads) do
            trackedVehicles[veh] = true
        end

        for veh, _ in pairs(trackedVehicles) do
            if not DoesEntityExist(veh) then
                if activeAntiLagThreads[veh] then
                    activeAntiLagThreads[veh] = nil
                end

                if activeBrakeThreads[veh] then
                    activeBrakeThreads[veh] = nil
                    SetVehicleBrakeLights(veh, false)
                end

                if activeLaunchControlThreads[veh] then
                    activeLaunchControlThreads[veh] = nil
                end

                if activeNitrousThreads[veh] then
                    activeNitrousThreads[veh] = nil
                end
            else
                local antiLagData = activeAntiLagThreads[veh]
                if antiLagData then
                    if antiLagData.active then
                        networkSyncAntilag(veh, antiLagData.vehicleHash)
                    end
                end

                local brakeData = activeBrakeThreads[veh]
                if brakeData then
                    if brakeData.active then
                        local entityState = Entity(veh).state
                        local syncBrake = entityState.syncBrake
                        local netBrakeData = entityState.brakeData

                        if not syncBrake or not netBrakeData then
                            activeBrakeThreads[veh] = nil
                            SetVehicleBrakeLights(veh, false)
                        else
                            local isBraking = syncBrake[1]
                            local brakeTempFront = netBrakeData[1]
                            local brakeTempRear = netBrakeData[2]
                            local brakeTemp = netBrakeData[3]

                            SetVehicleBrakeLights(veh, isBraking)
                            if not isBraking then
                                activeBrakeThreads[veh] = nil
                                SetVehicleBrakeLights(veh, false)
                            else
                                if brakeTempFront > 450 then
                                    HandleRemoteBrakeParticles(veh, brakeData.vehicleHash, brakeTempFront, brakeTempRear, brakeTemp)
                                end
                            end
                        end
                    else
                        activeBrakeThreads[veh] = nil
                        SetVehicleBrakeLights(veh, false)
                    end
                end

                local launchControlData = activeLaunchControlThreads[veh]
                if launchControlData then
                    if launchControlData.active then
                        SetVehicleCurrentRpm(veh, launchControlData.rpmData)
                    else
                        activeLaunchControlThreads[veh] = nil
                    end
                end

                local nitrousData = activeNitrousThreads[veh]
                if nitrousData then
                    if nitrousData.active then
                        SetVehicleNitroEnabled(veh, true)
                        LoopTrailFx(veh)
                    else
                        SetVehicleNitroEnabled(veh, false)
                        if trailFx[veh] then
                            trailFx[veh].alpha = 0.0
                            StopTrailFx(veh)
                            trailFx[veh].status = "Empty"
                        end
                        activeNitrousThreads[veh] = nil
                    end
                end
            end
        end
    end
end)

function networkSyncAntilag(entity, vehicleHash)
    playAntilagPopOnEntity(entity, vehicleHash)

    if networkEntityPops[entity] and networkEntityPops[entity].soundIds then
        local soundIds = networkEntityPops[entity].soundIds
        for i = #soundIds, 1, -1 do
            local soundId = soundIds[i]
            if HasSoundFinished(soundId) then
                table.remove(soundIds, i)
                networkEntityPops[entity].ammount = networkEntityPops[entity].ammount - 1
            end
        end
    end
end

