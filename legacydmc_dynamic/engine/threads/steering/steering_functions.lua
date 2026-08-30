function deg2rad(deg)
    return deg * (math.pi / 180.0)
end

function sgn(val)
    if val < 0 then return -1 end
    if val > 0 then return 1 end
    return 0
end

function normalizeVector(vec)
    local len = math.sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z))
    if len < 0.000001 then
        return vector3(0, 0, 0)
    end
    return vector3(vec.x / len, vec.y / len, vec.z / len)
end

function calculateSteeringReduction()
    local reduction = 1.0
    local speedKmh = vehicleSpeedKmh or 0.0

    if speedKmh > 3.0 then
        local expFactor = math.pow(0.9, math.abs(speedKmh) - 7.2)
        local baseReduction = 0.15 + expFactor
        if baseReduction ~= 0 then
            baseReduction = math.floor(baseReduction * 1000.0) / 1000.0
        end
        if baseReduction > 1.0 then
            baseReduction = 1.0
        end
        reduction = baseReduction
    end

    local mult = physicsSettings.steeringData.steeringReductionMulti or 0.5
    local finalReduction = 1.0 + ((reduction - 1.0) * mult)
    return finalReduction
end

function calculateSteeringHeading(maxAngle, currentHeading, targetHeading)
    local headingDiff = math.abs(currentHeading - targetHeading)
    local threshold = 3.0

    if headingDiff > threshold then
        local angleRad = math.atan2(vehicleForwardVector.y, vehicleForwardVector.x) - (math.pi / 2.0)
        if angleRad > (math.pi / 2.0) then
            angleRad = angleRad - math.pi
        elseif angleRad < -(math.pi / 2.0) then
            angleRad = angleRad + math.pi
        end

        local counterSteerRate = physicsSettings.steeringData.counterSteerRate or 1.0
        local counterAngle = angleRad * counterSteerRate
        local counterMax = physicsSettings.steeringData.counterSteerMaxAngle or 35.0

        counterAngle = clampValue(counterAngle, -counterMax, counterMax)
        return counterAngle
    else
        local directSteer = currentHeading - targetHeading
        return clampValue(directSteer * maxAngle, -maxAngle, maxAngle)
    end
end

function cacheDisableControlsRequirements()
    local model = GetEntityModel(vehicle)
    currentVehicleModel = model
    isVehicleAmphibious = isCurrentVehicleAmphibious(model)
    isVehicleABike = IsThisModelABike(model)
    isVehicle2Wheeler = isVehicleABike or IsThisModelABicycle(model)

    vehicleHasFork = GetEntityBoneIndexByName(vehicle, "forks") ~= -1
    vehicleHasTow = GetEntityBoneIndexByName(vehicle, "tow_arm") ~= -1
    vehicleHasScoop = GetEntityBoneIndexByName(vehicle, "scoop") ~= -1
    vehicleHasFrame1 = GetEntityBoneIndexByName(vehicle, "frame_1") ~= -1
    vehicleHasFrame2 = GetEntityBoneIndexByName(vehicle, "frame_2") ~= -1
end

function isCurrentVehicleAmphibious(modelHash)
    return modelHash == 886810209 or IsThisModelAnAmphibiousCar(modelHash) or IsThisModelAnAmphibiousQuadbike(modelHash)
end

function disableSteeringControls()
    DisableControlAction(0, 59, true) 
    DisableControlAction(0, 60, true) 
    DisableControlAction(0, 63, true) 
    DisableControlAction(0, 64, true) 

    if not isVehicleAmphibious and not vehicleHasFork and not vehicleHasTow and not vehicleHasScoop and not vehicleHasFrame1 and not vehicleHasFrame2 then
        DisableControlAction(0, 278, true)
        DisableControlAction(0, 279, true)
    end
end

function getAckermannCorrectedInput(steerInput, maxAngle, wheelBase, trackWidth)
    if steerInput == 0 or not physicsSettings.steeringData.useAckermannSteeringCorrection then
        return steerInput
    end

    local dir = sgn(steerInput)
    local absInput = math.abs(steerInput)
    local steerAngleDeg = absInput * maxAngle

    local radAngle = math.rad(steerAngleDeg)
    local tanAngle = math.tan(radAngle)
    if tanAngle == 0 then return steerInput end

    local turnRadius = wheelBase / tanAngle
    local innerAngleRad = math.atan(wheelBase / (turnRadius - (trackWidth / 2.0)))
    local outerAngleRad = math.atan(wheelBase / (turnRadius + (trackWidth / 2.0)))

    local avgAngleDeg = math.deg((innerAngleRad + outerAngleRad) / 2.0)
    local correctedInput = math.min(1.0, avgAngleDeg / maxAngle) * dir

    return correctedInput
end

function updateCurrentSteering()
    if not allowSteering then return end

    local now = GetGameTimer()
    local dt = (now - (lastTickTime or now)) / 1000.0
    lastTickTime = now

    local steerRate = isGamepad and (physicsSettings.steeringData.steeringRateGamepad or 5.0) or (physicsSettings.steeringData.steeringRateKeyboard or 10.0)
    local returnRate = isGamepad and (physicsSettings.steeringData.steeringReturnRateGamepad or 10.0) or (physicsSettings.steeringData.steeringReturnRateKeyboard or 15.0)
    local gamma = isGamepad and (physicsSettings.steeringData.steeringGammaGamepad or 1.0) or (physicsSettings.steeringData.steeringGammaKeyboard or 1.0)

    if isUsingMouseSteer then
        gamma = steeringWheelInput.ffbSettings.gammaGain or 0.85
    end

    local rawInput = updateSteeringWithMouse() or GetControlNormal(0, 59)
    local ackermannInput = getAckermannCorrectedInput(rawInput, vehicleSteeringLock or 35.0, vehicleCurrentWheelBase or 2.5, vehicleCurrentTrackWidth or 1.5)

    local targetSteer = 0.0
    if ackermannInput < 0.0 then
        targetSteer = -math.pow(-ackermannInput, gamma)
    else
        targetSteer = math.pow(ackermannInput, gamma)
    end

    local reduction = calculateSteeringReduction()
    if not physicsSettings.steeringData.allowMouseSteering and isUsingMouseSteer then
        reduction = 1.0
    end

    local rate = (math.abs(targetSteer) > math.abs(currentSteering)) and steerRate or returnRate
    local step = 1.0 - math.exp(-rate * dt)
    currentSteering = currentSteering + ((targetSteer - currentSteering) * step)

    local assistSteer = currentSteering
    if isUsingMouseSteer and physicsSettings.steeringData.allowSteeringAssistOnMouseSteer then
        assistSteer = currentSteering * reduction
    end

    vehicleCurrentSteeringAngle = assistSteer * (vehicleSteeringLock or 35.0)
    animPatchSteerValue = math.floor((vehicleCurrentSteeringAngle / (vehicleSteeringLock or 35.0)) * 100.0 + 0.5)

    local bias = clampValue(vehicleCurrentSteeringAngle / (vehicleSteeringLock or 35.0), -1.0, 1.0)
    smoothedSteering = smoothedSteering + ((bias - smoothedSteering) * 0.2)
    SetVehicleSteerBias(vehicle, smoothedSteering)
end

function updateSteeringWithMouse()
    if not forceMouseSteering or not physicsSettings.steeringData.allowMouseSteering then
        return nil
    end

    local mouseX = GetDisabledControlNormal(0, 1) or 0.0
    if mouseX ~= 0.0 then
        local sens = physicsSettings.steeringData.mouseSteeringSensitivity or 1.0
        mouseXTravel = clampValue(mouseXTravel + (mouseX * sens), -1.0, 1.0)
        return mouseXTravel
    end

    return nil
end

function clearSteeringVariables()
    currentVehicleModel = 0
    isVehicleAmphibious = false
    vehicleHasFork = false
    vehicleHasTow = false
    vehicleHasScoop = false
    vehicleHasFrame1 = false
    vehicleHasFrame2 = false
    isVehicleABike = false
    isVehicle2Wheeler = false
    isUsingMouseSteer = false
    hasDisabledDriveBy = false
    animPatchSteerValue = 0.0
    currentSteering = 0.0
    lastTickTime = 0
    mouseXTravel = 0.0
    lastReduction = 1.0
    mouseInputThisTick = false
    smoothedSteering = 0.0
    allowSteering = true
end

function enableSteering(state)
    allowSteering = state
end

function toggleForceMouseSteering()
    forceMouseSteering = not forceMouseSteering
end

function getForceMouseSteeringState()
    return forceMouseSteering
end
