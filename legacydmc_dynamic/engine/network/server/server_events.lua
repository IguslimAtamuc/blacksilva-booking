RegisterNetEvent("dynamic:syncState")
AddEventHandler("dynamic:syncState", function(netId, stateType, data)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        return
    end

    local entityState = Entity(entity).state

    if 0 == stateType then
        entityState.syncFlywheel = data
    elseif 1 == stateType then
        entityState.syncGear = data
    elseif 2 == stateType then
        entityState.engineSwap = data
    elseif 3 == stateType then
        entityState.syncBrake = data
    elseif 4 == stateType then
        entityState.syncDrift = data
    elseif 5 == stateType then
        entityState.syncCamera = data
    elseif 6 == stateType then
        entityState.syncAntiLagSystem = data
    elseif 7 == stateType then
        entityState.syncLaunchControl = data
    elseif 8 == stateType then
        entityState.syncAudioSfx = data
    elseif 9 == stateType then
        entityState.syncNitrousFx = data
        entityState.isUsingNitrous = data[1]
    end
end)

