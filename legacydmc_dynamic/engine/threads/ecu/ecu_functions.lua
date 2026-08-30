function clearEcuVariables()
    ecuLoaded = false
    vehicleSpeed = 0
    vehicleSpeedKmh = 0
    vehicleThrottle = 0
    vehicleBrakes = 0
    vehicleSteering = 0
    isSteeringWheelEnabled = false
    steeringWheelDataThread = false
    vehicleIsFlying = false
    vehicleGameCurrentClutchEngagement = 0
    vehicleGameCurrentRpm = 0
    vehicleGlobalVelocity = vector3(0, 0, 0)
    vehicleSlipAngle = 0
    vehiclePositionDelta = {}
    vehicleTirePositionDelta = {}
    vehicleVelocityPositionDelta = {}
    vehicleTireVelocityPositionDelta = {}
    vehicleForwardVector = vector3(0, 0, 0)
    vehicleEntityVelocity = vector3(0, 0, 0)
    vehicleEntitySpeedVector = vector3(0, 0, 0)
    vehiclePosition = vector3(0, 0, 0)
    averageDrivenWheelSpeed = 0
    vehicleDriveTrainLayout = 0
    vehicleCurrentSteeringAngle = 0
    vehicleEffectiveTractionLossRatio = 0
    vehicleCurrentForcedRpm = 0
    vehicleCurrentDrivetrainForce = 0
    vehicleCurrentTrackWidth = 0
    vehicleCurrentWheelBase = 0
    vehicleCenterOfMassOffset = vector3(0, 0, 0)
    vehicleCenterOfMassHeight = 0
    vehicleCurrentGforce = { x = 0, y = 0, z = 0, total = 0 }
    vehicleCurrentTireLoad = {}
    vehicleIsElectric = false
    vehicleIsBraking = false
    vehicleSteeringLock = 0
    vehicleEngineIsOn = false
    vehicleHeading = 0
    vehicleEntityRotationalVelocity = vector3(0, 0, 0)
    vehicleBrakingForce = 0
    vehicleBrakingBias = 0.0
    vehicleMaxSuspensionCompression = 0
    vehicleMaxSuspensionExpansion = 0

    tcsAllowed = physicsSettings.assistsData.enableAssistsByDefault
    escAllowed = physicsSettings.assistsData.enableAssistsByDefault
    fakeTcsBrakes = 0
    fakeEscBrakes = 0
    tcsIntensity = 3
    isEscActive = false
    isTcsActive = false
    vehicleTcsStatusMulti = 0
    vehicleDummyBone = 0
    vehicleHandbrake = 0
    vehicleRotation = vector3(0, 0, 0)
    vehiclefDriveInertia = 0.0
    vehicleSuspensionBiasFront = 0.0
    maxFuelAmmount = 0.0

    SteeringWheelUpShift = false
    SteeringWheelDownShift = false
    leftSignalStockEnabled = false
    rightSignalStockEnabled = false
    hazardLightEnabled = false
    leftSignalArmed = false
    rightSignalArmed = false
    leftSignalStartSteering = 0.0
    rightSignalStartSteering = 0.0
    hazardButtonLastState = 0.0
    leftButtonLastState = 0.0
    rightButtonLastState = 0.0
    startUpButtonLastState = 0.0

    hShifterHasShifted = {}
    isCameraSwitchPressed = false
    currentFuelLevel = 0.0
    pastTransmissionLevel = -1
    vehicleArbForce = 0.0
    vehicleArbFrontBias = 0.0
    vehicleSuspensionForce = 0.0

    steeringWheelInput = {
        throttle = 0,
        rawSteering = 0,
        steerScale = 0,
        brakes = 0,
        clutch = 0,
        steering = 0,
        ffbSettings = {
            overallGain = 100,
            damperGain = 40,
            detailGain = 30,
            frictionGain = 10,
            gammaGain = 0.85
        }
    }

    vehicleWheel0 = createWheelState()
    vehicleWheel1 = createWheelState()
    vehicleWheel2 = createWheelState()
    vehicleWheel3 = createWheelState()

    vehicleWheels = {
        [0] = vehicleWheel0,
        [1] = vehicleWheel1,
        [2] = vehicleWheel2,
        [3] = vehicleWheel3
    }
end

function createWheelState()
    return {
        speed = 0,
        tractionVector = 0,
        wheelLoad = 0,
        slipAngle = 0,
        slipRatio = 0,
        temperature = 25,
        tempFricMulti = 1,
        materialFricMulti = 1,
        currentMaterialId = 0,
        position = vector3(0, 0, 0),
        fwdVec = vector3(0, 0, 0),
        velocityVector = vector3(0, 0, 0),
        rotationalForce = 0.0,
        fakeTcsBrakes = 0,
        suspensionCompression = 0,
        suspensionTravelDistance = 0,
        lastNormalizedSuspension = 0
    }
end

function round(val, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(val * mult + 0.5) / mult
end

function patchVehicleWheelies()
    local config = vehicleConfig[currentVehicle]
    if not config or not config.transmissionData then return end

    local enableWheelies = config.transmissionData.enableWheelies
    local speedKmh = vehicleSpeedKmh or 0.0

    if speedKmh > 65.0 then
        if currentVehicleGear == 1 and enableWheelies then
            Citizen.CreateThread(function()
                local t = 0.0
                while t < 1.0 do
                    Citizen.Wait(0)
                    t = t + (GetFrameTime() / 0.25)
                    local applyT = math.floor(t * 100.0) / 100.0
                    SetControlNormal(0, 71, applyT)
                end
            end)
        end
    end
end

function getVehicleWeightDist()
    local fwdBias = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront")
    return round(fwdBias * 100.0, 1), round((1.0 - fwdBias) * 100.0, 1)
end

function cacheWheelBones()
    local rightFrontBone = isCurrentVehicleMotorycle and "wheel_lr" or "wheel_rf"
    local leftFront = GetEntityBoneIndexByName(vehicle, "wheel_lf")
    local rightFront = GetEntityBoneIndexByName(vehicle, rightFrontBone)
    local leftRear = 0
    local rightRear = 0

    if GetVehicleNumberOfWheels(vehicle) > 2 then
        leftRear = GetEntityBoneIndexByName(vehicle, "wheel_lr") or 0
    end
    if GetVehicleNumberOfWheels(vehicle) > 2 then
        rightRear = GetEntityBoneIndexByName(vehicle, "wheel_rr") or 0
    end

    wheelBoneIndexes = {
        [0] = leftFront,
        [1] = rightFront,
        [2] = leftRear,
        [3] = rightRear
    }

    vehicleExhaustBone = GetEntityBoneIndexByName(vehicle, "exhaust")
    debugPrint("Cached Wheel Bones & Radius!")
end

function calculateYawRate(heading, dt)
    local prevH = previousHeading or heading
    local diff = heading - prevH

    local pi = math.pi
    diff = (diff + pi) % (2.0 * pi) - pi

    previousHeading = heading
    return diff / math.max(0.001, dt)
end

function cacheVehicleInfo()
    vehicleDummyBone = GetEntityBoneIndexByName(vehicle, "chassis_dummy")
    vehicleDriveTrainLayout = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront")
    vehicleSuspensionBiasFront = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionBiasFront")
    vehicleCenterOfMassOffset = GetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset")
    vehicleOrginalCom = vehicleCenterOfMassOffset
    vehicleSteeringLock = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSteeringLock")
    vehicleMaxSuspensionCompression = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionUpperLimit")
    vehicleMaxSuspensionExpansion = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionLowerLimit")
    vehiclefDriveInertia = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia")
    vehicleArbForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fAntiRollBarForce")
    vehicleArbFrontBias = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fAntiRollBarBiasFront")
    vehicleSuspensionForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce")
    maxFuelAmmount = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fPetrolTankVolume")

    if vehicleCenterOfMassHeight > 1.0 then
        debugPrint("[Warning] The vehicle's center of mass height exceeds 1.0 meter. Capped at 0.5 meter.")
        vehicleCenterOfMassHeight = 0.5
    end

    vehicleIsElectric = isVehicleElectric()
end

function isVehicleElectric()
    local config = vehicleConfig[currentVehicle]
    if config and config.engine and config.engine.isElectric then
        return true
    end
    return false
end

function patchEvForcedInduction()
    local config = vehicleConfig[currentVehicle]
    if config and isVehicleElectric() then
        if config.forcedInduction then
            config.forcedInduction.torqueGain = -1.0
            config.forcedInduction.hasAntilag = false
            config.forcedInduction.isTurbocharged = false
        end
    end
end

function getTotalDriveTrainPower()
    local frontPwr = (vehicleWheels[0].speed + vehicleWheels[1].speed) / 2.0
    local rearPwr = (vehicleWheels[2].speed + vehicleWheels[3].speed) / 2.0
    return frontPwr + rearPwr
end

function getCurrentAirResistance()
    local dragCoeff = currentVehicleTyreData and currentVehicleTyreData.dragCoefficient or 0.3
    local frontalArea = 2.2
    local airDensity = 1.225
    local speed = vehicleSpeed or 0.0

    return 0.5 * airDensity * dragCoeff * frontalArea * (speed ^ 2)
end

function getSlipAngle(wheelIndex)
    local fwdVel, rightVel = getWheelDotVelocity(wheelIndex)
    if math.abs(fwdVel) < 0.5 then
        return 0.0
    end
    local angleRad = math.atan(rightVel / fwdVel)
    return math.deg(angleRad)
end

function getTractionLossRatio()
    local totalTraction = 0.0
    local totalLoad = 0.0

    for i = 0, 3 do
        local wheel = vehicleWheels[i]
        if wheel then
            totalTraction = totalTraction + (wheel.tractionVector or 0.0)
            totalLoad = totalLoad + (wheel.wheelLoad or 0.0)
        end
    end

    if totalLoad <= 0 then return 1.0 end
    return math.min(1.0, math.max(0.0, totalTraction / totalLoad))
end

function getAvgTractionVector(wheelIndex)
    local frontTraction = (vehicleWheels[0].tractionVector + vehicleWheels[1].tractionVector) / 2.0
    local rearTraction = (vehicleWheels[2].tractionVector + vehicleWheels[3].tractionVector) / 2.0
    return (frontTraction + rearTraction) / 2.0
end

function getAccelerationWithCentripetal(wheelIndex)
    local vel = GetEntityVelocity(vehicle)
    local prevVel = vehicleVelocityPositionDelta[wheelIndex] or vel
    vehicleVelocityPositionDelta[wheelIndex] = vel

    local dt = gameDeltaTime or 0.0167
    local accel = (vel - prevVel) / math.max(0.001, dt)
    return { vec = accel, x = accel.x, y = accel.y, z = accel.z }
end

function getTotalGForce()
    local velAcc = GetEntitySpeedVector(vehicle)
    local gX = velAcc.x / 9.81
    local gY = velAcc.y / 9.81
    local gZ = velAcc.z / 9.81
    local gTotal = math.sqrt((gX * gX) + (gY * gY) + (gZ * gZ))

    return { x = gX, y = gY, z = gZ, total = gTotal }
end

function GetForwardVectorFromHeading(heading)
    local rad = math.rad(heading)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

function dot(v1, v2)
    return (v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z)
end

function setVehicleConstants()
    debugPrint("Setting Dynamic Vehicle Constants")
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDownforceModifier", 0.0)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", 1.0)

    if physicsSettings.tunableData then
        local linDamp = physicsSettings.tunableData.linearDampeningCoefficient or 0.0
        local angDamp = physicsSettings.tunableData.angularDampeningCoefficient or 0.0
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSteeringLock", vehicleSteeringLock)
    end

    vehicleCurrentTcsLevel = physicsSettings.assistsData.tcsIntensity or 3
end

function fakeEcuDefaultData()
    gameDeltaTime = 0.0167
    vehiclePosition = GetEntityCoords(vehicle)
    vehicleForwardVector = GetEntityForwardVector(vehicle)
    vehicleEntitySpeedVector = GetEntitySpeedVector(vehicle)
    vehicleEngineIsOn = false
    vehicleSpeed = 0.0
    vehicleSpeedKmh = 0.0
    vehicleEntityVelocity = vector3(0, 0, 0)
    vehicleThrottle = 0.0
    vehicleBrakes = 0.0
    vehicleSteering = 0
    vehicleIsBraking = false
    vehicleIsFlying = false
    vehicleGameCurrentClutchEngagement = 1.0
    vehicleGameCurrentRpm = 0.2
    averageDrivenWheelSpeed = 0
    vehicleSlipAngle = 0
    vehicleGlobalVelocity = vector3(0, 0, 0)
    vehicleCurrentSteeringAngle = 0.0
    vehicleCurrentGforce = { x = 0.0, y = 0.0, z = 0.0, total = 0.0 }
    vehicleEffectiveTractionLossRatio = 0.0
    vehicleIsInBurnout = false
    vehicleCurrentTireLoad = { [1] = 0.0 }
    currentVehicleGear = 1.0
    currentFuelLevel = 1.0
end

function getWheelSuspensionVelocity(wheelIndex)
    local wheel = vehicleWheels[wheelIndex]
    if not wheel then return 0.0 end
    return wheel.suspensionTravelDistance or 0.0
end
