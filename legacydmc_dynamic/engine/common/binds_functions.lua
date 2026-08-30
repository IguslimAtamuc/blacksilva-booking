function bindUpshift()
    if not IsPauseMenuActive() then
        if GetIsVehicleEngineRunning(vehicle) then
            upShift()
        end
    end
end

function bindDownshift()
    if not IsPauseMenuActive() then
        if GetIsVehicleEngineRunning(vehicle) then
            downShift()
        end
    end
end

function bindClutchIn()
    if not IsPauseMenuActive() then
        if GetIsVehicleEngineRunning(vehicle) then
            if 1 == vehicleTransmissionTypeId then
                vehicleClutchPedalRequestTime = GetGameTimer()
                vehicleClutchPedalIsPressed = true
            end
        end
    end
end

function bindClutchOut()
    if not IsPauseMenuActive() then
        if GetIsVehicleEngineRunning(vehicle) then
            vehicleClutchPedalRequestTime = GetGameTimer()
            vehicleClutchPedalIsPressed = false
        end
    end
end

function bindOrbitLockIn()
    if not IsPauseMenuActive() then
        lockOrbitCamReturn = true
    end
end

function bindOrbitLockOut()
    if not IsPauseMenuActive() then
        lockOrbitCamReturn = false
    end
end

function bindNitrousIn()
    if not IsPauseMenuActive() then
        if not isNitrousActive then
            if nitrousTankTime > 0 then
                if hasNitrous then
                    if not forceNitrous then
                        RequestNamedPtfxAsset("veh_xs_vehicle_mods")
                        isNitrousActive = true
                        nitrousActivatedTime = GetGameTimer()

                        InitializeTrailFxForVehicle(vehicle)
                        LoopTrailFx(vehicle)

                        if trailFx[vehicle] and "Full" ~= trailFx[vehicle].status then
                            StartTrailFx(vehicle)
                            trailFx[vehicle].status = "Full"
                        end

                        local soundName = vehicleIsElectric and "start_nitrous_ev" or "start_nitrous"
                        nitrousSoundId = PlayEntitySound(vehicle, soundName, "DYNAMIC_SOUNDBANK", 0, "DYNAMIC_TRANSMISSION")
                    end
                end
            end
        else
            if not isNitrousActive then
                if nitrousTankTime <= 0 then
                    if hasNitrous then
                        if not forceNitrous then
                            local soundName = vehicleIsElectric and "stop_nitrous_ev" or "stop_nitrous"
                            PlayEntitySound(vehicle, soundName, "DYNAMIC_SOUNDBANK", 0, "DYNAMIC_TRANSMISSION")
                        end
                    end
                end
            end
        end
    end
end

function bindNitrousOut()
    if not IsPauseMenuActive() then
        if isNitrousActive then
            if hasNitrous then
                if not forceNitrous then
                    endNitrous()
                end
            end
        end
    end
end

function debugPrint(...)
    if not allowDebugVerbose then
        return
    end

    local args = { ... }
    for i = 1, #args do
        args[i] = tostring(args[i])
    end

    print("[Debug] " .. table.concat(args, " "))
end

