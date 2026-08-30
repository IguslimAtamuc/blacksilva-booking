RegisterNetEvent("onClientResourceStart")
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(2000)
        player = PlayerPedId()
        playerId = PlayerId()
    end
end)

RegisterNetEvent("dynamic:leftVehicle")
AddEventHandler("dynamic:leftVehicle", function(netId)
    if isDynamicPaused then
        return
    end
    dynamicExitVehicle(netId)
end)

RegisterNetEvent("dynamic:leftVehiclePassenger")
AddEventHandler("dynamic:leftVehiclePassenger", function(netId)
    if isDynamicPaused then
        return
    end
    dynamicExitVehiclePassenger(netId)
end)

RegisterNetEvent("dynamic:enteredVehicle")
AddEventHandler("dynamic:enteredVehicle", function(netId, isSeatChange)
    if isDynamicPaused then
        return
    end
    if isSeatChange then
        TriggerEvent("dynamic:leftVehicle", netId)
        Citizen.Wait(100)
    end
    dynamicEnterVehicle(netId)
end)

RegisterNetEvent("dynamic:enteredVehiclePassenger")
AddEventHandler("dynamic:enteredVehiclePassenger", function(netId, isSeatChange)
    if isDynamicPaused then
        return
    end
    if isSeatChange then
        TriggerEvent("dynamic:leftVehicle", netId)
        Citizen.Wait(100)
    end
    dynamicEnterVehiclePassenger(netId)
end)

collectgarbage("generational")
