if devMode then
    Citizen.Wait(3000)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if isSteeringWheelEnabled then
                AddValueToGraphBuffer(currentFFBDebugVal)
                DrawDebugGraph()
            end
        end
    end)
end

