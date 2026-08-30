function loadTyre(compoundName)
    local compound = tyreConfig[compoundName]
    if compound then
        debugPrint("Loaded Vehicle Tire Model!")
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveLateral", compound.lateralCurveAngle)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", compound.peakTractionG)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin", compound.peakTractionG * 0.9)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fLowSpeedTractionLossMult", 0.01)

        currentVehicleTyreData = {
            peakTractionMax = compound.peakTractionG,
            peakTractionMin = compound.peakTractionG * 0.9,
            lateralCurveAngle = compound.lateralCurveAngle,
            advancedSettings = compound.advancedSettings
        }
        currentTyreCompound = compoundName

        if not tyreThreadEnabled then
            tyreThreadEnabled = true
            debugPrint("Starting Tyre Thread!")
        end
    else
        if currentVehicleTyreData then
            debugPrint("Tire model unsupported or does not exist, no changes were made.")
        else
            debugPrint("Tire model unsupported or does not exist, handling data will be used.")
        end
    end
end

function buildTyreModel()
    local config = vehicleConfig[currentVehicle]
    if not config or not config.tyre then return end

    local tyreComp = config.tyre.tyreCompound
    local exists = tyreConfig[tyreComp] ~= nil
    local useCompound = config.tyre.useTyreCompound

    if exists then
        if useCompound then
            loadTyre(tyreComp)
        else
            debugPrint("Skipping Tyre Model Built, using handling defaults.")
            if not tyreThreadEnabled then
                tyreThreadEnabled = true
                debugPrint("Starting Tyre Thread!")
            end
        end
    else
        debugPrint("[Warning] The selected tire profile don't exist. Make sure to select a tire profile in the vehicle creation tool!")
        debugPrint("[Warning] As a safe guard, a tire profile will be generated automatically from the vehicle handling data.")

        local defaultHandlingGrip = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
        local defaultHandlingLat = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveLateral")

        local autoProfile = {
            peakTractionG = defaultHandlingGrip,
            lateralCurveAngle = defaultHandlingLat,
            advancedSettings = {
                thermalConstants = {
                    thermalMassK = 1150,
                    rollingResistanceK = 0.0204,
                    slipFrictionK = 0.01981,
                    dissipationK = 0.07,
                    speedDissipationK = 0.0001
                },
                frictionConstants = {
                    maxTemp = 165,
                    optRangeMin = 70,
                    optRangeMax = 90,
                    muCold = 0.9,
                    muOpt = 1.1,
                    muHot = 0.7
                }
            }
        }

        AutoTire = autoProfile
        tyreConfig["Auto"] = autoProfile
        config.tyre.tyreCompound = "Auto"
        loadTyre("Auto")
    end
end

function clearTyreVariables()
    currentDynamicPeakGrip = 0.0
    currentTyreCompound = nil
    currentVehicleTyreData = {}
    cacheSlipRatioValues = {}
end

function updateGrip()
    local peakMax = currentVehicleTyreData and currentVehicleTyreData.peakTractionMax or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    local peakMin = currentVehicleTyreData and currentVehicleTyreData.peakTractionMin or (peakMax * 0.9)

    local avgVel = getVectorMagnitude(vehicleEntityVelocity)
    local normalizedSpeed = clampValue(avgVel / 50.0, 0.0, 1.0)
    local gripGainCoeff = physicsSettings.tunableData.downforceGripGainCoeff or 0.0
    local downforceGrip = gripGainCoeff * (normalizedSpeed ^ 2)

    local targetPeak = peakMax + downforceGrip
    local tempSum = 0.0

    local numWheels = isCurrentVehicleMotorycle and 2 or 4
    for i = 0, numWheels - 1 do
        local wheel = vehicleWheels[i]
        if wheel then
            local tempMult = wheel.tempFricMulti or 1.0
            local matMult = wheel.materialFricMulti or 1.0
            local effectiveFriction = math.min(tempMult, matMult)
            local deltaFriction = tempMult - 1.0
            if deltaFriction > 0 then
                tempSum = tempSum + deltaFriction
            end
        end
    end

    local avgTempMult = (tempSum / numWheels) + 1.0
    local dynamicGrip = (targetPeak * avgTempMult)

    if currentDynamicPeakGrip ~= dynamicGrip then
        currentDynamicPeakGrip = dynamicGrip
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", dynamicGrip)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin", dynamicGrip * 0.9)
    end
end

function getVectorMagnitude(vec)
    return math.sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z))
end

function clampValue(val, minVal, maxVal)
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

function crossProduct(v1, v2)
    return vector3(
        (v1.y * v2.z) - (v1.z * v2.y),
        (v1.z * v2.x) - (v1.x * v2.z),
        (v1.x * v2.y) - (v1.y * v2.x)
    )
end

function calculateSlipAngle(wheelLoad, peakGrip, slipAngle, wheelBase)
    local gravity = 9.81
    local loadPerWheel = (wheelLoad / 4.0) * gravity

    local isRearDriven = false
    if vehicleDriveTrainLayout > 0 then
        local driveBias = vehicleDriveTrainLayout / loadPerWheel
        isRearDriven = (driveBias > 0)
    end

    local halfWheelBase = wheelBase / 2.0
    local angleNorm = isRearDriven and (halfWheelBase * (isRearDriven / loadPerWheel)) or 1.1
    local maxSlipRatio = math.max(math.abs(slipAngle), angleNorm)

    local slipRatioMult = peakGrip / maxSlipRatio
    local atanAngle = math.atan(slipRatioMult)

    return atanAngle
end

function normalizeVector3(vec)
    local mag = getVectorMagnitude(vec)
    if mag < 0.000001 then
        return vector3(0, 0, 0)
    end
    return vector3(vec.x / mag, vec.y / mag, vec.z / mag)
end

function getWheelDotVelocity(wheelIndex)
    local fwdVec = GetEntityForwardVector(vehicle)
    local rightVec = GetEntityRightVector(vehicle)
    local wheelState = vehicleWheels[wheelIndex]
    if not wheelState then return 0.0, 0.0 end

    local wheelPos = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[wheelIndex])
    local vehCoords = GetEntityCoords(vehicle)
    local relativePos = wheelPos - vehCoords
    local rotVel = GetEntityRotationVelocity(vehicle)

    local angularVelocity = crossProduct(rotVel, relativePos)
    local wheelTotalVel = GetEntityVelocity(vehicle) + angularVelocity

    local steerAngle = (wheelIndex < 2) and GetVehicleSteeringAngle(vehicle) or 0.0
    local radSteer = math.rad(steerAngle)
    local cosSteer = math.cos(radSteer)
    local sinSteer = math.sin(radSteer)

    local dirFwd = (fwdVec * cosSteer) - (rightVec * sinSteer)
    local dirRight = (fwdVec * sinSteer) + (rightVec * cosSteer)

    local dotFwd = (wheelTotalVel.x * dirFwd.x) + (wheelTotalVel.y * dirFwd.y) + (wheelTotalVel.z * dirFwd.z)
    local dotRight = (wheelTotalVel.x * dirRight.x) + (wheelTotalVel.y * dirRight.y) + (wheelTotalVel.z * dirRight.z)

    return dotFwd, dotRight
end

function getTireSlipRatio(wheelIndex)
    local wheelState = vehicleWheels[wheelIndex]
    if not wheelState then return 0.0 end

    local fwdVel, rightVel = getWheelDotVelocity(wheelIndex)
    local wheelRotSpeed = GetVehicleWheelRotationSpeed(vehicle, wheelIndex)
    local wheelRadius = GetVehicleWheelRadius(vehicle, wheelIndex) or 0.35

    local linearSpeed = wheelRotSpeed * wheelRadius
    local absFwd = math.abs(fwdVel)

    local slipRatio = 0.0
    if absFwd >= 0.1 then
        slipRatio = (linearSpeed - fwdVel) / absFwd
    end

    if not cacheSlipRatioValues[wheelIndex] then
        cacheSlipRatioValues[wheelIndex] = slipRatio
    else
        local prev = cacheSlipRatioValues[wheelIndex]
        cacheSlipRatioValues[wheelIndex] = prev + 0.1 * (slipRatio - prev)
    end

    return clampValue(cacheSlipRatioValues[wheelIndex], -1.0, 3.5)
end

function calculateSlip(slipRatio, wheelIndex)
    local wheelState = vehicleWheels[wheelIndex]
    if not wheelState then return 0.0 end

    local fwdVel, rightVel = getWheelDotVelocity(wheelIndex)
    local absFwd = math.max(0.1, math.abs(fwdVel))

    local slip = (-rightVel * (wheelState.materialFricMulti or 1.0)) / absFwd
    return clampValue(slip - 1.0, -1.0, 3.5)
end

function getTireMaximumForce(wheelIndex)
    local peakMax = currentVehicleTyreData and currentVehicleTyreData.peakTractionMax or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    local peakMin = currentVehicleTyreData and currentVehicleTyreData.peakTractionMin or (peakMax * 0.9)

    local avgVel = getVectorMagnitude(vehicleEntityVelocity)
    local normalizedSpeed = clampValue(avgVel / 50.0, 0.0, 1.0)
    local gripGainCoeff = physicsSettings.tunableData.downforceGripGainCoeff or 0.0
    local downforceGrip = gripGainCoeff * (normalizedSpeed ^ 2)

    local basePeak = peakMax + downforceGrip
    local wheelState = vehicleWheels[wheelIndex]
    local tempFric = wheelState and wheelState.tempFricMulti or 1.0
    local matFric = wheelState and wheelState.materialFricMulti or 1.0

    local wheelLoad = (wheelState and wheelState.wheelLoad or 500.0) * 9.81
    local maxForce = basePeak * tempFric * matFric * wheelLoad

    local dampening = physicsSettings.tunableData.angularDampeningCoefficient or 0.0
    local dampFactor = (dampening > 0.025) and 0.885 or 0.9

    return maxForce * dampFactor
end

function getTireMaximumLatForceN(wheelIndex)
    local peakMax = currentVehicleTyreData and currentVehicleTyreData.peakTractionMax or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    local wheelState = vehicleWheels[wheelIndex]
    local tempFric = wheelState and wheelState.tempFricMulti or 1.0
    local matFric = wheelState and wheelState.materialFricMulti or 1.0
    local wheelLoad = (wheelState and wheelState.wheelLoad or 500.0) * 9.81

    return peakMax * tempFric * matFric * wheelLoad * 0.925
end

function getTireCurrentForce(wheelIndex)
    local wheelState = vehicleWheels[wheelIndex]
    if not wheelState then return 0.0 end

    local load = (wheelState.wheelLoad or 500.0) * 9.81
    local slipRatio = wheelState.slipRatio or 0.0
    local slipAngle = wheelState.slipAngle or 0.0

    local longForce = slipRatio * load * 2.5
    local latForce = math.atan(slipAngle) * 0.4 * load * 2.5

    return math.sqrt((longForce * longForce) + (latForce * latForce))
end

function getTireLateralForce(wheelIndex)
    local wheelState = vehicleWheels[wheelIndex]
    if not wheelState then return 0.0 end

    local load = (wheelState.wheelLoad or 500.0) * 9.81
    local slipAngle = wheelState.slipAngle or 0.0
    return math.atan(slipAngle) * 0.4 * load * 2.5
end

function getTireLongitudinalForce(wheelIndex)
    local wheelState = vehicleWheels[wheelIndex]
    if not wheelState then return 0.0 end

    local load = (wheelState.wheelLoad or 500.0) * 9.81
    local slipRatio = wheelState.slipRatio or 0.0
    local clampedRatio = clampValue(slipRatio, -5.625, 5.625)

    return clampedRatio * load * 2.5
end

function getClampedTireForces(latForce, longForce)
    local maxForce = getTireMaximumForce(0)
    local totalForce = math.sqrt((latForce * latForce) + (longForce * longForce))

    if totalForce > maxForce and totalForce > 0.000001 then
        local ratio = maxForce / totalForce
        return latForce * ratio, longForce * ratio
    end

    return latForce, longForce
end

function updateTireTemperature(wheelIndex)
    local frictionConsts = {
        maxTemp = 165,
        optRangeMin = 70,
        optRangeMax = 90,
        muCold = 0.9,
        muOpt = 1.025,
        muHot = 0.7
    }

    local thermalConsts = {
        thermalMassK = 1127,
        rollingResistanceK = 0.01938,
        slipFrictionK = 0.0208005,
        dissipationK = 0.0707,
        speedDissipationK = 0.0001
    }

    if currentVehicleTyreData and currentVehicleTyreData.advancedSettings then
        local adv = currentVehicleTyreData.advancedSettings
        frictionConsts = adv.frictionConstants or frictionConsts
        thermalConsts = adv.thermalConstants or thermalConsts
    end

    local wheel = vehicleWheels[wheelIndex]
    if not wheel then return end

    if not wheel.temperature or wheel.temperature ~= wheel.temperature then
        wheel.temperature = 25.0
    end

    local fwdVel, rightVel = getWheelDotVelocity(wheelIndex)
    local totalWheelSpeed = math.sqrt((fwdVel * fwdVel) + (rightVel * rightVel))
    local slipVel = math.abs(getTireSlipRatio(wheelIndex) * totalWheelSpeed)

    local load = (wheel.wheelLoad or 500.0) * 9.81
    local workFriction = (totalWheelSpeed * thermalConsts.rollingResistanceK) + (slipVel * thermalConsts.slipFrictionK * load)
    local heatGeneration = workFriction / thermalConsts.thermalMassK

    local tempDiff = wheel.temperature - 25.0
    local cooling = (tempDiff * thermalConsts.dissipationK) + (tempDiff * totalWheelSpeed * thermalConsts.speedDissipationK)

    wheel.temperature = clampValue(wheel.temperature + heatGeneration - cooling, 25.0, frictionConsts.maxTemp)

    local currentTemp = wheel.temperature
    local tempMultiplier = 1.0

    if currentTemp < frictionConsts.optRangeMin then
        local ratio = (currentTemp - 25.0) / (frictionConsts.optRangeMin - 25.0)
        tempMultiplier = frictionConsts.muCold + (ratio * (frictionConsts.muOpt - frictionConsts.muCold))
    elseif currentTemp <= frictionConsts.optRangeMax then
        tempMultiplier = frictionConsts.muOpt
    else
        local ratio = (currentTemp - frictionConsts.optRangeMax) / (frictionConsts.maxTemp - frictionConsts.optRangeMax)
        tempMultiplier = frictionConsts.muOpt - (ratio * (frictionConsts.muOpt - frictionConsts.muHot))
    end

    wheel.tempFricMulti = tempMultiplier
end
