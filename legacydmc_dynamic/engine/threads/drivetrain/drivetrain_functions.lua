function setWheelDrivable(wheelIndex)
    local currentFlags = GetVehicleWheelFlags(vehicle, wheelIndex)
    if not hasWheelFlag(vehicle, wheelIndex, 16) then
        local newFlags = currentFlags + 16
        SetVehicleWheelFlags(vehicle, wheelIndex, newFlags)
        wheelFlags[wheelIndex] = newFlags
    end
end

function removeWheelDrivable(wheelIndex)
    local currentFlags = GetVehicleWheelFlags(vehicle, wheelIndex)
    if hasWheelFlag(vehicle, wheelIndex, 16) then
        local newFlags = currentFlags - 16
        SetVehicleWheelFlags(vehicle, wheelIndex, newFlags)
        wheelFlags[wheelIndex] = newFlags
    end
end

function hasWheelFlag(veh, wheelIndex, flagBit)
    local flags = GetVehicleWheelFlags(veh, wheelIndex)
    return (flags & flagBit) ~= 0
end

function cacheWheelFlags()
    debugPrint("Cacheing vehicle wheel flags!")
    local maxWheels = isCurrentVehicleMotorycle and 1 or 3
    for i = 0, maxWheels do
        wheelFlags[i] = GetVehicleWheelFlags(vehicle, i)
    end
end

function buildDriveTrain(frontTorqueBias)
    local absBias = math.abs(frontTorqueBias) + 0.0
    local isBike = isCurrentVehicleMotorycle

    if 1.0 == absBias then
        if not isBike then
            setWheelDrivable(0)
            setWheelDrivable(1)
            removeWheelDrivable(2)
            removeWheelDrivable(3)
        else
            setWheelDrivable(0)
            removeWheelDrivable(1)
        end
    elseif 0.0 == absBias then
        if not isBike then
            removeWheelDrivable(0)
            removeWheelDrivable(1)
            setWheelDrivable(2)
            setWheelDrivable(3)
        else
            removeWheelDrivable(0)
            setWheelDrivable(1)
        end
    else
        if 0.5 == absBias or 0.0 == absBias then
            if not isBike then
                setWheelDrivable(0)
                setWheelDrivable(1)
                setWheelDrivable(2)
                setWheelDrivable(3)
            else
                setWheelDrivable(0)
                setWheelDrivable(1)
            end
        end
    end

    vehicleDriveTrainLayout = absBias
    currentTorqueDist = absBias
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", absBias)
end

function checkFlag(val, flag)
    return (val & flag) > 0
end

function setFrontTorqueDist(val)
    buildDriveTrain(val)
end

function clearDriveTrainVars()
    currentTorqueDist = 0.0
    wheelFlags = {}
end
