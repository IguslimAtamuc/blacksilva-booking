function startBrakeThread()
    brakeThreadEnabled = true
    local netSyncData = physicsSettings.netSyncData
    loadBrakeData()
    debugPrint("Started Brake Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(100)

            if not brakeThreadEnabled then
                debugPrint("Stopping Brake Thread!")
                clearBrakeVariables()
                break
            end

            local syncEnabled = netSyncData.enableBrakeSync
            local isBraking = vehicleIsBraking
            local frontMulti = frontBrakeMulti
            local rearMulti = rearBrakeMulti

            if networkIsBraking ~= networkShouldSyncBrakes and syncEnabled then
                TriggerServerEvent("dynamic:syncState", vehicleNetId, 3, {
                    networkIsBraking,
                    brakeTemp,
                    currentVehicle,
                    frontMulti,
                    rearMulti
                })
                networkShouldSyncBrakes = networkIsBraking
            end

            if globalGameTimer - networkUpdateTempLastRequestTime >= 100 then
                if networkIsBraking then
                    networkUpdateTempLastRequestTime = globalGameTimer
                    networkUpdateBrakeTemperature = true
                end
            else
                networkUpdateBrakeTemperature = false
            end

            if networkIsBraking and networkUpdateBrakeTemperature and syncEnabled then
                entityStateBag:set("brakeData", { brakeTemp, frontMulti, rearMulti }, true)
            end

            if brakeTemp > 300 then
                if not activeParticles[vehicle] then
                    activeParticles[vehicle] = {}
                    local fxGroup = "core"
                    local fxName = "veh_exhaust_afterburner"

                    RequestNamedPtfxAsset(fxGroup)
                    while not HasNamedPtfxAssetLoaded(fxGroup) do
                        Citizen.Wait(0)
                    end

                    if isCurrentVehicleMotorycle then
                        local bikeOffsets = vehicleConfig[currentVehicle].offsets.bikeBrakeGlow
                        local maxSeatIndex = bikeOffsets.usesDualDiskFrontBrake and 5 or 3

                        for i = 0, maxSeatIndex do
                            local sideSign = (i > 1) and 1 or -1
                            local wheelIdx = i
                            if i > 1 and i < 4 then
                                wheelIdx = wheelIdx - 2
                            end
                            if i >= 4 then
                                wheelIdx = wheelIdx - wheelIdx
                                if 4 == i then sideSign = 1 end
                                if 5 == i then sideSign = -1 end
                            end

                            local boneIdx = wheelBoneIndexes[wheelIdx]
                            if boneIdx and -1 ~= boneIdx then
                                UseParticleFxAssetNextCall(fxGroup)
                                local settings = vehicleConfig[currentVehicle].offsets.bikeBrakeGlow.brakeDiskSettings

                                local radius = (0 == wheelIdx) and settings.bikeGlowBrakeFrontRadius or settings.bikeGlowBrakeRearRadius
                                local diskWidth = (0 == wheelIdx) and settings.bikeGlowBrakeFrontDiskWidth or settings.bikeGlowBrakeRearDiskWidth
                                local diskOffset = (0 == wheelIdx) and settings.bikeGlowBrakeFrontOffset or settings.bikeGlowBrakeRearOffset
                                local diskSpacing = (i >= 4) and bikeOffsets.bikeGlowBrakeFrontSpacing or 0.0
                                local isFrontOrDual = (0 == wheelIdx or i >= 4) and 0.0 or 1.0

                                local fxHandle = StartParticleFxLoopedOnEntityBone(
                                    fxName,
                                    vehicle,
                                    (diskWidth * sideSign) + diskOffset + diskSpacing,
                                    0.0, 0.0, 0.0, 0.0, 90.0,
                                    boneIdx,
                                    radius,
                                    false, false, false
                                )

                                local multi = (wheelIdx < 1) and frontMulti or rearMulti
                                local alpha = math.min(1.0, map(brakeTemp * multi, 450, 800, 0.2, 1.0))

                                SetParticleFxLoopedAlpha(fxHandle, alpha)
                                table.insert(activeParticles[vehicle], {
                                    handle = fxHandle,
                                    wheelIndex = isFrontOrDual
                                })
                            end
                        end
                    else
                        for i = 0, 3 do
                            local boneIdx = wheelBoneIndexes[i]
                            if boneIdx and -1 ~= boneIdx then
                                UseParticleFxAssetNextCall(fxGroup)
                                local offsets = vehicleConfig[currentVehicle].offsets.carBrakeGlow

                                local fxHandle = StartParticleFxLoopedOnEntityBone(
                                    fxName,
                                    vehicle,
                                    offsets.carGlowBrakeXOffset,
                                    0.0, 0.0, 0.0, 0.0, 90.0,
                                    boneIdx,
                                    offsets.glowBrakeRadius + carBrakeRadiusInj,
                                    false, false, false
                                )

                                local multi = (i < 2) and frontMulti or rearMulti
                                local alpha = math.min(1.0, map(brakeTemp * multi, 450, 800, 0.2, 1.0))

                                SetParticleFxLoopedAlpha(fxHandle, alpha)
                                table.insert(activeParticles[vehicle], {
                                    handle = fxHandle,
                                    wheelIndex = i
                                })
                            end
                        end
                    end
                else
                    if isCurrentVehicleMotorycle then
                        for _, p in ipairs(activeParticles[vehicle]) do
                            local multi = (p.wheelIndex < 1) and frontMulti or rearMulti
                            local alpha = math.min(1.0, map(brakeTemp * multi, 450, 800, 0.2, 1.0))
                            SetParticleFxLoopedAlpha(p.handle, alpha)
                        end
                    else
                        for _, p in ipairs(activeParticles[vehicle]) do
                            local multi = (p.wheelIndex < 2) and frontMulti or rearMulti
                            local alpha = math.min(1.0, map(brakeTemp * multi, 450, 800, 0.2, 1.0))
                            SetParticleFxLoopedAlpha(p.handle, alpha)
                        end
                    end
                end
            else
                if activeParticles[vehicle] then
                    for _, p in ipairs(activeParticles[vehicle]) do
                        StopParticleFxLooped(p.handle, 0)
                    end
                    activeParticles[vehicle] = nil
                end
            end
        end
    end)
end
