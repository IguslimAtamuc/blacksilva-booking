function RegisterExport(exportName, handlerFn)
    local resourceName = GetCurrentResourceName()
    local eventName = string.format("__cfx_export_%s_%s", resourceName, exportName)
    AddEventHandler(eventName, function(cb)
        cb(handlerFn)
    end)
end

function getPlayerWheelData()
    return {
        throttle = playerThrottle,
        brakes = playerBrake,
        clutch = playerClutch,
        steering = playerSteering,
        upShift = playerUpShiftAction,
        downShift = playerDownShiftAction,
        handBrake = playerHandBrakeAction,
        rawSteering = playerRawSteering,
        steerScale = playerSteeringScale,
        leftSignal = playerLeftSignalAction,
        rightSignal = playerRightSignalAction,
        hazardSignal = playerHazardSignalAction,
        hornSignal = playerHornAction,
        startUpSignal = playerStartUpAction,
        camSignal = playerCamSwitchAction,
        gearSignal = playerGearShiftAction,
        headLightSignal = playerHeadLightAction,
        ffbSettings = playerFfbSettings
    }
end

function isSteeringWheelEnabled()
    return inputFeedBackThread and shouldUseSteeringWheel
end

RegisterExport("getPlayerWheelData", getPlayerWheelData)
RegisterExport("isSteeringWheelEnabled", isSteeringWheelEnabled)

