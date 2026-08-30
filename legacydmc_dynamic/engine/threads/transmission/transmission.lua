local enableTuning = physicsSettings.upgradeData.enableVanillaTuningIntegration
local shiftTimeMulti = physicsSettings.upgradeData.transmissionShiftTimeMultiplier

function startTransmissionThread()
    transmissionThreadEnabled = true
    debugPrint("Starting Transmission Thread!")

    RequestScriptAudioBank("DYNAMIC_SOUNDBANK", "DYNAMIC_TRANSMISSION")
    isForcingAutomaticTransmission = false

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not transmissionThreadEnabled then
                debugPrint("Stopping Transmission Thread!")
                break
            end

            if isForcingAutomaticTransmission then
                debugPrint("Forcing Auto transmission, disabling transmission thread!")
                transmissionThreadEnabled = false
                break
            end

            local isManual = (vehicleTransmissionTypeId == 0)

            if isManual then
                if IsControlJustPressed(0, 168) then 
                    if currentVehicleGear < vehicleGearCount then
                        shiftGear(currentVehicleGear + 1)
                        handleUpShiftAnim()
                        handleGearShiftSound(true)
                        playGearShiftProfile(true)
                    end
                elseif IsControlJustPressed(0, 169) then 
                    if currentVehicleGear > 0 then
                        shiftGear(currentVehicleGear - 1)
                        handleGearShiftSound(false)
                        playGearShiftProfile(false)
                    end
                end
            end

            if vehicleAllowLaunchControl and vehicleThrottle > 0.9 and vehicleBrakes > 0.8 and vehicleSpeedKmh < 5.0 then
                if not isInLaunchControlMode then
                    isInLaunchControlMode = true
                    TriggerServerEvent("dynamic:syncState", vehicleNetId, 7, { true, currentVehicleGear })
                end
                SetVehicleCurrentRpm(vehicle, vehicleLaunchControlRpm)
            else
                if isInLaunchControlMode then
                    isInLaunchControlMode = false
                    TriggerServerEvent("dynamic:syncState", vehicleNetId, 7, { false, currentVehicleGear })
                end
            end
        end
    end)
end

function startAtRevLimiterThread()
    debugPrint("Starting AT thread!")
    atThreadEnabled = true

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not atThreadEnabled then
                debugPrint("Stopping AT thread!")
                break
            end

            local rpm = GetVehicleCurrentRpm(vehicle)
            if rpm >= 0.98 and vehicleThrottle > 0.8 then
                if currentVehicleGear < vehicleGearCount and not vehicleIsCurrentlyShifting then
                    shiftGear(currentVehicleGear + 1)
                end
            elseif rpm <= 0.35 and vehicleSpeedKmh < 10.0 and currentVehicleGear > 1 then
                shiftGear(currentVehicleGear - 1)
            end
        end
    end)
end
