function startTuningThread()
    tuningThreadEnabled = true
    debugPrint("Started Tuning Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if not tuningThreadEnabled then
                debugPrint("Stopping Tuning Thread!")
                break
            end
        end
    end)
end

