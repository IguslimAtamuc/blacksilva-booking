function startChassisThread()
    chassisThreadEnabled = true
    debugPrint("Started Chassis Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if not chassisThreadEnabled then
                debugPrint("Stopping Chassis Thread!")
                clearChassisVariables()
                break
            end
        end
    end)
end

