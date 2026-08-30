function startFlywheelThread()
    flywheelThreadEnabled = true
    debugPrint("Started Flywheel Thread!")

    Citizen.CreateThread(function()
        local lerper = createTimeLerp()

        while true do
            Citizen.Wait(0)

            if not flywheelThreadEnabled then
                debugPrint("Stopping Flywheel Thread!")
                clearFlywheelVariables()
                break
            end

            if vehicleGameCurrentRpm > 0.21 and not isClutchPressed then
                local decaySpeed = vehicleRpmDecaymentSpeed or 2.5
                lerper:start(vehicleGameCurrentRpm, 0.2, decaySpeed)

                TriggerServerEvent("dynamic:syncState", vehicleNetId, 0, { true, vehicleGameCurrentRpm, 0.2 })

                while lerper.active do
                    Citizen.Wait(0)
                    local currentRpm, isActive = lerper:update()

                    if currentRpm == 0 or isClutchPressed then
                        lerper:stop()
                        break
                    end

                    currentInterpolatedRpm = currentRpm
                    SetVehicleCurrentRpm(vehicle, currentRpm)
                end
            end
        end
    end)
end
