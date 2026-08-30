function startDrivetrainThread()
    drivetrainThreadEnabled = true
    debugPrint("Started Drivetrain Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if not drivetrainThreadEnabled then
                debugPrint("Stopping Drivetrain Thread!")
                clearDriveTrainVars()
                break
            end
        end
    end)
end

