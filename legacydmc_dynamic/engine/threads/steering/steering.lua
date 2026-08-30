function startSteeringThread()
    steeringThreadEnabled = true
    debugPrint("Starting Steering Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not steeringThreadEnabled then
                debugPrint("Stopping Steering Thread!")
                clearSteeringVariables()
                break
            end

            local allowAir = physicsSettings.experienceData.allowAirControl
            if not allowAir and vehicleIsFlying then
                disableSteeringControls()
            else
                disableSteeringControls()
                updateCurrentSteering()
            end
        end
    end)
end
