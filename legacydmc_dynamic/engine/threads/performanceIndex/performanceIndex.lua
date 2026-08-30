function startPerformanceIndexThread()
    performanceIndexThreadEnabled = true
    debugPrint("Started Performance Index Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if not performanceIndexThreadEnabled then
                debugPrint("Stopping Performance Index Thread!")
                break
            end
        end
    end)
end

