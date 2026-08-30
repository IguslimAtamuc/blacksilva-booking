CreateThread(function()
    while true do
        for netId, stateData in pairs(vehicleEngineState) do
            local entity = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(entity) then
                local entityState = Entity(entity).state
                local currentSwap = entityState.engineSwap
                local expectedSwap = stateData

                local currentSwapVal = currentSwap and currentSwap[1] or nil
                local expectedSwapVal = expectedSwap and expectedSwap[1] or nil

                if currentSwapVal ~= expectedSwapVal then
                    entityState.engineSwap = expectedSwap
                    print("[EngineSync] Reapplied engineSwap state for vehicle:", netId)
                end
            else
                vehicleEngineState[netId] = nil
                print("[EngineSync] Cleaned up engine state for destroyed vehicle:", netId)
            end
        end

        Citizen.Wait(5000)
    end
end)

