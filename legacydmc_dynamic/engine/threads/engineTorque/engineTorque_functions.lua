function buildEngine()
    local config = vehicleConfig[currentVehicle]
    if not config or not config.engine then
        return
    end

    local engineConfig = config.engine
    local forcedInductionConfig = config.forcedInduction

    isEngineTurboCharged = forcedInductionConfig.isTurbocharged
    turboTorqueGain = forcedInductionConfig.torqueGain

    if physicsSettings.experienceData.forceDefaultTorqueGain then
        turboTorqueGain = physicsSettings.experienceData.defaultTorqueGainAmmount
    end

    local power = engineConfig.power
    vehicleEngineGforce = power
    currentRawTorqueCurve = engineConfig.torqueCurve

    local minRpm, maxRpm, maxTorque, sortedCurve = prepareTorqueCurve(currentRawTorqueCurve)
    vehicleEngineMinRpm = minRpm
    vehicleEngineMaxRpm = maxRpm
    vehicleEngineMaxTorque = maxTorque
    vehicleEngineTorqueCurve = sortedCurve

    debugPrint("Vehicle Torque Curve Sorted!")
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", vehicleEngineGforce)
    debugPrint("Engine Power Applied!")

    engineThreadEnabled = true
    debugPrint("Starting Engine Thread!")
end

function prepareTorqueCurve(curve)
    table.sort(curve, function(a, b)
        return a.rpm < b.rpm
    end)

    local minRpm = curve[1].rpm
    local maxRpm = curve[1].rpm
    local maxTorque = 0.0

    for _, pt in ipairs(curve) do
        if pt.torque == 0 then
            pt.torque = 1
        end
        if pt.torque > maxTorque then
            maxTorque = pt.torque
        end
        if pt.rpm > maxRpm then
            maxRpm = pt.rpm
        end
        if pt.rpm < minRpm then
            minRpm = pt.rpm
        end
    end

    return minRpm, maxRpm, maxTorque, curve
end

function calcTorque(curve, maxTorque, currentRpm, minRpm, maxRpm)
    local targetRpm = math.max(1000.0, currentRpm * 7700.0)

    for i = 1, #curve do
        local pt = curve[i]
        if targetRpm <= pt.rpm then
            if i == 1 then
                return pt.torque / maxTorque
            else
                local prevPt = curve[i - 1]
                local rpmFactor = (targetRpm - prevPt.rpm) / (pt.rpm - prevPt.rpm)
                local interpTorque = prevPt.torque + (rpmFactor * (pt.torque - prevPt.torque))
                return interpTorque / maxTorque
            end
        end
    end

    return curve[#curve].torque / maxTorque
end

function clearEngineVariables()
    vehicleEngineGforce = 0
    vehicleCurrentEngineTorqueCurveFactor = 0
    shouldForceEnginePower = false
    isEngineTurboCharged = false
    currentTuningPowerMultiplier = 1.0
    forceEnginePowerMultiplier = 1.0
    vehicleEngineGforcePower = 0
    vehicleEngineTorqueCurve = {}
    vehicleEngineMaxTorque = 0
    vehicleEngineMaxRpm = 0
    vehicleEngineMinRpm = 0
end
