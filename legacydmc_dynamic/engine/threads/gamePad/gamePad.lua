function startGamepadThread()
    gamepadThreadEnabled = true
    debugPrint("Starting Gamepad Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not gamepadThreadEnabled then
                debugPrint("Stopping Gamepad Thread!")
                break
            end

            DisableControlAction(0, 80, true)
            DisableControlAction(0, 66, true)
            DisableControlAction(0, 67, true)
            DisableControlAction(0, 99, true)
        end
    end)
end
