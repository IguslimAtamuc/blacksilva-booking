function clamp(val, minVal, maxVal)
    if val < minVal then
        return minVal
    elseif val > maxVal then
        return maxVal
    else
        return val
    end
end

function muLongitudinal(slipRatio, tireModel, load)
    local absSlip = math.abs(slipRatio)
    local nominalLoad = (tireModel and tireModel.nominalLoad) or 6572.0
    local loadRatio = math.max(0.000001, load) / nominalLoad

    local peakFric = (tireModel and tireModel.longitudinalPeakFriction) or 1.0
    local limitFric = (tireModel and tireModel.longitudinalLimitFriction) or 0.7
    local zeroLoadPeak = (tireModel and tireModel.longitudinalZeroLoadPeak) or 1.0

    local muPeak = (zeroLoadPeak * loadRatio * peakFric) + (limitFric * (1.0 - loadRatio))
    local peakSlip = (tireModel and tireModel.longitudinalPeakSlip) or 1.0
    local limitSlip = (tireModel and tireModel.longitudinalLimitSlip) or 1.0

    local mu = 0.0
    if absSlip <= peakSlip then
        local ratio = absSlip / peakSlip
        mu = muPeak * (3.0 * (ratio ^ 2) - 2.0 * (ratio ^ 3))
    else
        local ratio = math.min(1.0, (absSlip - peakSlip) / math.max(0.001, limitSlip - peakSlip))
        mu = muPeak - (ratio * (muPeak - limitFric))
    end

    if slipRatio < 0 then
        return -mu
    end
    return mu
end

function muLateral(slipAngleDeg, tireModel, load)
    local absAngle = math.abs(slipAngleDeg)
    local nominalLoad = (tireModel and tireModel.nominalLoad) or 6572.0
    local loadRatio = math.max(0.000001, load) / nominalLoad

    local peakFric = (tireModel and tireModel.lateralPeakFriction) or 1.1
    local limitFric = (tireModel and tireModel.lateralLimitFriction) or 0.575
    local zeroLoadPeak = (tireModel and tireModel.lateralZeroLoadPeak) or 1.0

    local muPeak = (zeroLoadPeak * loadRatio * peakFric) + (limitFric * (1.0 - loadRatio))
    local peakAngle = (tireModel and tireModel.lateralPeakSlip) or 12.0
    local limitAngle = (tireModel and tireModel.lateralLimitSlip) or 40.0

    local mu = 0.0
    if absAngle <= peakAngle then
        local ratio = absAngle / peakAngle
        mu = muPeak * (3.0 * (ratio ^ 2) - 2.0 * (ratio ^ 3))
    else
        local ratio = math.min(1.0, (absAngle - peakAngle) / math.max(0.001, limitAngle - peakAngle))
        mu = muPeak - (ratio * (muPeak - limitFric))
    end

    if slipAngleDeg < 0 then
        return -mu
    end
    return mu
end

function calculateTireForces(latSlip, longSlip, load, tireModel)
    local Fx = muLongitudinal(longSlip, tireModel, load) * load
    local Fy = muLateral(latSlip, tireModel, load) * load

    local maxFx = (tireModel and tireModel.longitudinalPeakFriction or 1.0) * load
    local maxFy = (tireModel and tireModel.lateralPeakFriction or 1.1) * load

    local ellipseVal = ((Fx / math.max(0.001, maxFx)) ^ 2) + ((Fy / math.max(0.001, maxFy)) ^ 2)
    if ellipseVal > 1.0 then
        local scale = 1.0 / math.sqrt(ellipseVal)
        Fx = Fx * scale
        Fy = Fy * scale
    end

    return Fx, Fy
end

function rotateVector2(vec, angleDeg)
    local rad = math.rad(angleDeg)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)

    return vector3(
        (vec.x * cosA) - (vec.y * sinA),
        (vec.x * sinA) + (vec.y * cosA),
        0.0
    )
end

function applyWheelForce(veh, fwdForce, latForce, wheelIndex)
    local fwdVec = GetEntityForwardVector(veh)
    local rightVec = GetEntityRightVector(veh)

    local steerAngle = (wheelIndex < 2) and GetVehicleSteeringAngle(veh) or 0.0
    local rotFwd = (fwdVec * math.cos(math.rad(steerAngle))) - (rightVec * math.sin(math.rad(steerAngle)))
    local rotRight = (fwdVec * math.sin(math.rad(steerAngle))) + (rightVec * math.cos(math.rad(steerAngle)))

    local forceVec = (rotFwd * fwdForce) + (rotRight * latForce)
    local wheelPos = GetWorldPositionOfEntityBone(veh, wheelBoneIndexes[wheelIndex])

    local wheelState = vehicleWheels[wheelIndex]
    local suspensionComp = wheelState and wheelState.suspensionCompression or 0

    if suspensionComp > 0 then
        ApplyForceToEntity(veh, 0, forceVec.x, forceVec.y, 0.0, wheelPos.x, wheelPos.y, wheelPos.z, 0, false, false, false, false, true)
    end
end

function residualMomentSAE(slipAngleDeg)
    return 3.0 * 0.07 * math.exp(-((slipAngleDeg ^ 2) / 2.0))
end

function drawDebugLine(startPos, dirVec, color)
    local endPos = startPos + (dirVec * 3.0)
    DrawLine(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, color.r or 255, color.g or 0, color.b or 0, 255)
end

function getWheelRotationalSpeed(speedKmh, wheelIndex)
    local speedMs = speedKmh / 3.6
    local radius = GetVehicleWheelRadius(vehicle, wheelIndex) or 0.35
    return speedMs / math.max(0.001, radius)
end

function getIsVehicleCurrentlyDrifting()
    return vehicleIsSliding
end

function getIsVehicleCurrentlyDriftingThrottleLess()
    return vehicleIsSliding
end

function clearDifferentialVariables()
    vehicleIsSliding = false
    wheelBoneIndexes = {}
    wheelRadiusIndexes = {}
    currentDriftMultiplier = 0
    currentInterpolatedRpm = 0.2
    networkHasSentDriftSyncRequest = false
    vehicleIsCurrentlyDrifting = false
end
