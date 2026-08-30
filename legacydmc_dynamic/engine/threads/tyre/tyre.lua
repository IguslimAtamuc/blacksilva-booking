function updateTyre()
    if tyreThreadEnabled then
        if isCurrentVehicleMotorycle then
            updateGrip(0)
            updateGrip(1)
        else
            updateGrip(0)
            updateGrip(1)
            updateGrip(2)
            updateGrip(3)
        end
    end
end

function calculatePacejkaForces(wheelIndex, wheelLoad, slipAngleDeg, slipRatio)
    local B_long, C_long, D_long, E_long = 10.0, 1.9, 1.0, 0.97
    local B_lat, C_lat, D_lat, E_lat = 12.0, 1.6, 1.0, 0.95

    local normalLoad = wheelLoad * 9.81
    local loadRatio = normalLoad / 4000.0

    local longForce = 0.0
    if slipRatio then
        local peakD = D_long * normalLoad
        local S = slipRatio * B_long
        local atanS = math.atan(S)
        local sinAtan = math.sin(C_long * math.atan(S - (E_long * (S - atanS))))
        longForce = peakD * sinAtan
    end

    local latForce = 0.0
    if slipAngleDeg then
        local radAngle = math.rad(slipAngleDeg)
        local peakD = D_lat * normalLoad
        local S = radAngle * B_lat
        local atanS = math.atan(S)
        local sinAtan = math.sin(C_lat * math.atan(S - (E_lat * (S - atanS))))
        latForce = peakD * sinAtan
    end

    return longForce, latForce
end

function applyForceAtTyre(wheelIndex, longForce, latForce, isFrontWheel)
    local fwdVec = GetEntityForwardVector(vehicle)
    local rightVec = GetEntityRightVector(vehicle)
    local upVec = GetEntityUpVector(vehicle)

    local steerAngle = (isFrontWheel < 2) and GetVehicleSteeringAngle(vehicle) or 0.0
    local radSteer = math.rad(steerAngle)
    local cosSteer = math.cos(radSteer)
    local sinSteer = math.sin(radSteer)

    local dirFwd = (fwdVec * cosSteer) - (rightVec * sinSteer)
    local dirRight = (fwdVec * sinSteer) + (rightVec * cosSteer)

    local totalForceVector = (dirFwd * longForce) + (dirRight * latForce)
    local wheelPos = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[isFrontWheel])

    local wheelState = vehicleWheels[isFrontWheel]
    local suspensionComp = wheelState and wheelState.suspensionCompression or 0

    if suspensionComp > 0 then
        ApplyForceToEntity(vehicle, 0, totalForceVector.x, totalForceVector.y, totalForceVector.z, wheelPos.x, wheelPos.y, wheelPos.z, 0, false, true, false, false, true)
    end
end
