RegisterNUICallback("saveBindings", function(data, cb)
    if not data then return cb({}) end

    local bindingsData = data.bindings or {}
    SetResourceKvp("dynamic_wheel_bindings", json.encode(bindingsData))

    local devId = tonumber(data.deviceId) or -1
    SetResourceKvpInt("dynamic_wheel_deviceId", devId)

    if data.wheelConfig then
        SetResourceKvp("dynamic_wheel_steerConfig", json.encode(data.wheelConfig))
        wheelSettings.wheelConfig = data.wheelConfig
    end

    cb({})
end)

RegisterNUICallback("loadBindings", function(data, cb)
    local bindingsRaw = GetResourceKvpString("dynamic_wheel_bindings") or "{}"
    local bindings = json.decode(bindingsRaw)

    local devId = GetResourceKvpInt("dynamic_wheel_deviceId")
    if devId == -1 or not devId then
        devId = nil
    end

    local steerConfigRaw = GetResourceKvpString("dynamic_wheel_steerConfig") or "{}"
    local steerConfig = json.decode(steerConfigRaw)

    cb({
        bindings = bindings,
        deviceId = devId,
        wheelConfig = steerConfig
    })
end)

RegisterNUICallback("toggleWheel", function(data, cb)
    shouldUseSteeringWheel = not shouldUseSteeringWheel
    cb({})
end)

RegisterNUICallback("startFFB", function(data, cb)
    sendForceFeedBackData = true
    cb({})
end)

RegisterNUICallback("stopFFB", function(data, cb)
    sendForceFeedBackData = false
    cb({})
end)

RegisterNUICallback("closeMenu", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "showMenu",
        state = false
    })
    cb({})
end)

RegisterNUICallback("liveInputs", function(data, cb)
    currentWheelInputs = data.inputs or {}
    cb({})
end)

function GetInputState(inputKey)
    return currentWheelInputs[inputKey] or 0.0
end

function mapSteeringInput(rawInput, maxRotation, steerRange)
    local halfMax = maxRotation / 2.0
    local halfRange = steerRange / 2.0
    local scaledVal = rawInput * halfMax
    local clampedVal = math.max(-halfRange, math.min(halfRange, scaledVal))
    return clampedVal / halfRange
end

function getWheelSteeringScale(maxRotation, steerRange)
    return maxRotation / steerRange
end

RegisterCommand("wheelMenu", function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "showMenu",
        state = true
    })
end, false)

RegisterKeyMapping("wheelMenu", "5. Steering Wheel Menu", "keyboard", "F10")

RegisterNetEvent("onClientResourceStart")
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(2000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            if exports.legacydmc_dynamic:dynamicBootComplete() then
                startInputFeedBackThread()
            end
        end
    end
end)

RegisterNetEvent("dynamic:enteredVehicle")
AddEventHandler("dynamic:enteredVehicle", function()
    while not exports.legacydmc_dynamic:dynamicBootComplete() do
        Citizen.Wait(0)
    end
    startInputFeedBackThread()
end)

RegisterNetEvent("dynamic:leftVehicle")
AddEventHandler("dynamic:leftVehicle", function()
    inputFeedBackThread = false
end)

