function dynamicEnterVehicle(netId)
    while exitingVehicle do
        Citizen.Wait(0)
    end

    enteringVehicle = true
    playerPed = GetPlayerPed(PlayerId())
    vehicle = NetworkGetEntityFromNetworkId(netId)
    vehNetSyncCheck = vehicle
    globalVehicleModel = GetEntityModel(vehicle)
    vehicleNetId = netId
    seatSwapIsDriver = true

    for modelName, _ in pairs(vehicleConfig) do
        if GetHashKey(modelName) == globalVehicleModel then
            globalVehicleHasConfig = true
            globalVehicleName = modelName
            break
        end
    end

    local isDriver = (GetPedInVehicleSeat(vehicle, -1) == player)
    local useInvertedAllowlist = physicsSettings.experienceData.useInvertedAllowlistMode
    currentCarIsListed = false

    for _, modelName in ipairs(allowList) do
        if GetHashKey(modelName) == GetEntityModel(vehicle) then
            currentCarIsListed = true
            break
        end
    end

    local vehClass = GetVehicleClass(vehicle)
    local isClassValid = (vehClass <= 7) or (vehClass >= 9 and vehClass < 13) or (vehClass >= 17 and vehClass <= 22) or (vehClass == 8)
    isValidVehicle = isClassValid
    isCurrentVehicleMotorycle = IsThisModelABike(GetEntityModel(vehicle))

    local isSupported = false
    if isClassValid then
        if not currentCarIsListed and useInvertedAllowlist then
            isSupported = true
        elseif currentCarIsListed and not useInvertedAllowlist then
            isSupported = true
        end
    end

    if isSupported then
        vehicleIsSupported = true
        for modelName, _ in pairs(vehicleConfig) do
            if GetHashKey(modelName) == GetEntityModel(vehicle) then
                vehicleHasConfig = true
                currentVehicle = modelName
                break
            end
        end

        if not vehicleHasConfig then
            storeVehicleOriginalHandlingData()
            autoGenerateProfile()
            Citizen.Wait(5)
            dynamicStartVehicle()
        else
            storeVehicleOriginalHandlingData()
            dynamicStartVehicle()
        end
    else
        if (currentCarIsListed and useInvertedAllowlist) or (not currentCarIsListed and not useInvertedAllowlist) then
            print("[Warning] Dynamic is not allowed to run in this vehicle.")
        else
            print("[Warning] This vehicle Isn`t supported by Dynamic engine,")
        end
    end

    cacheGlobalVehData()
    entityStateBag = Entity(vehicle).state
    menuSpawnHack = true
    enteringVehicle = false
    bootSequenceComplete = true
end

function dynamicEnterVehiclePassenger(netId)
    while exitingVehicle do
        Citizen.Wait(0)
    end

    enteringVehicle = true
    playerPed = GetPlayerPed(PlayerId())
    vehicle = NetworkGetEntityFromNetworkId(netId)
    vehNetSyncCheck = -1337
    globalVehicleModel = GetEntityModel(vehicle)
    vehicleNetId = netId
    seatSwapIsDriver = false

    for modelName, _ in pairs(vehicleConfig) do
        if GetHashKey(modelName) == globalVehicleModel then
            globalVehicleHasConfig = true
            globalVehicleName = modelName
            break
        end
    end

    cacheGlobalVehData()
    entityStateBag = Entity(vehicle).state
    menuSpawnHack = true
    enteringVehicle = false
    bootSequenceComplete = true
end

function dynamicBootComplete()
    return bootSequenceComplete
end

function dynamicStartVehicle()
    startEcuThread()
    while not ecuLoaded do
        Citizen.Wait(0)
    end

    buildChassis()
    buildTransmission()
    buildEngine()
    startDifferentialThread()

    if physicsSettings.experienceData.useCustomSteeringInput then
        startSteeringThread()
    end

    startFlywheelThread()
    startBrakeThread()

    if hudConfig.enableHud then
        if not hudIsPaused then
            startHud()
        end
    end

    if physicsSettings.experienceData.useChaseCamByDefault then
        if not cameraIsPaused then
            startCamera()
        end
    end
end

function clearEntityVariables()
    vehicle = 0
    vehicleNetId = 0
    vehNetSyncCheck = 0
    seatSwapIsDriver = false
    isValidVehicle = false
    globalVehicleName = ""
    globalVehicleModel = 0
    globalVehicleHasConfig = false

    globalVehData = {
        maxRpm = 0,
        minRpm = 0,
        maxFuelCapacity = 65
    }

    menuSpawnHack = false
    netIdPatchable = 0
    vehicleHasConfig = false
    vehicleIsSupported = false
    currentVehicle = 0
    previousVehicle = 0
    isCurrentVehicleMotorycle = false
    debug = true
    exitingVehicle = false
    enteringVehicle = false
    bootSequenceComplete = false
    globalEntityCheck = false
    entityStateBag = nil
end

function dynamicKillThreads(keepTransmission)
    transmissionThreadEnabled = false
    if not keepTransmission or not isForcingAutomaticTransmission then
        clearTransmissionVariables()
    end

    engineThreadEnabled = false
    steeringThreadEnabled = false
    ecuThreadEnabled = false
    antilagThreadEnabled = false
    flywheelThreadEnabled = false
    differentialThreadEnabled = false
    tyreThreadEnabled = false
    gamepadThreadEnabled = false
    hudThreadEnabled = false
    brakeThreadEnabled = false

    clearDriveTrainVars()
    stopCamera(false)
end

function dynamicExitVehicle(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then
        return
    end

    while enteringVehicle do
        Citizen.Wait(0)
    end

    exitingVehicle = true
    local hadConfig = vehicleHasConfig

    clearEntityVariables()
    previousVehicle = NetworkGetEntityFromNetworkId(netId)
    menuSpawnHack = false

    dynamicKillThreads(hadConfig)
    resetPastVehicle(previousVehicle)
    handleHideShow(false, false, false)
    SetVehicleControlsInverted(previousVehicle, false)
    exitingVehicle = false
end

function dynamicExitVehiclePassenger(netId)
    while enteringVehicle do
        Citizen.Wait(0)
    end

    exitingVehicle = true
    clearEntityVariables()
    previousVehicle = NetworkGetEntityFromNetworkId(netId)
    menuSpawnHack = false
    exitingVehicle = false
end

function storeVehicleOriginalHandlingData()
    vehicleOriginalGearCount = GetVehicleHandlingInt(vehicle, "CHandlingData", "nInitialDriveGears")
    vehicleOriginalPower = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    vehicleOriginalDragCoefficient = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff")
    vehicleOriginalTopSpeed = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel") * 1.3333333333333333
    vehicleOriginalShiftTime = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleUpShift")
    vehicleOriginalMaxG = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    vehicleOriginalMinG = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin")
    vehicleOriginalLatCurve = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveLateral")
    vehicleOriginalLowSpeedTractionLoss = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fLowSpeedTractionLossMult")
    vehicleOriginalBrakingForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
    vehicleOriginalBrakingBias = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeBiasFront")

    local maxWheels = IsThisModelABike(GetEntityModel(vehicle)) and 1 or 3
    for i = 0, maxWheels do
        vehicleOriginalWheelFlags[i] = GetVehicleWheelFlags(vehicle, i)
    end

    if vehicleOriginalGearCount < 1 then
        vehicleOriginalGearCount = 7
    end

    debugPrint("Stored Vehicle Handling Data!")
end

function getDragCoeff(topSpeed, mass, gearRatios, power, torqueCurve, vehicleMass)
    local lastRatio = gearRatios[#gearRatios]
    local powerRatio = power * lastRatio
    local isMatched = false
    local gearIndex = 0
    local speedLimits = {}

    for i = 1, #gearRatios do
        local ratio = gearRatios[i]
        local speedLimit = math.floor((powerRatio / ratio) + 0.5)
        table.insert(speedLimits, speedLimit)
    end

    for idx, speedLimit in ipairs(speedLimits) do
        if topSpeed <= speedLimit then
            gearIndex = idx
            isMatched = true
            break
        end
    end

    if not isMatched then
        gearIndex = #speedLimits
    end

    local currentRatioLimit = speedLimits[gearIndex]
    local ratioScale = topSpeed / currentRatioLimit
    local curve1, curve2, curve3, curve4 = prepareTorqueCurve(torqueCurve)
    local calculatedTorque = calcTorque(curve1, curve2, ratioScale, curve3, curve4)

    local speedMs = topSpeed / 3.6
    local dragCoeff = 0.0
    local engineForce = power * calculatedTorque * gearRatios[gearIndex]
    local dragForce = (0.6115 * dragCoeff * 2.2 * speedMs * speedMs) / vehicleMass / 9.81

    while engineForce > dragForce do
        dragCoeff = dragCoeff + 0.0001
        dragForce = (0.6115 * dragCoeff * 2.2 * speedMs * speedMs / vehicleMass) / 9.81
        if dragCoeff > 15.0 then
            break
        end
    end

    return dragCoeff
end

function getLimitedRatioTable(gearCount)
    local defaultRatios = { -3.333, 3.333, 1.849, 1.253, 1.011, 0.918, 0.851, 0.767, 0.692, 0.622 }
    local result = {}
    local maxCount = math.min(gearCount, #defaultRatios)

    for i = 1, maxCount do
        table.insert(result, defaultRatios[i])
    end
    return result
end

function patchEvForcedInduction()
    if isVehicleElectric then
    end
end

function autoGenerateProfile()
    print("This vehicle does not have a profile, automatically generating one based on handling stats...")

    local torqueCurve = {}
    local samplePoints = {
        { rpm = 1000.0, torque = 360.0 }, { rpm = 1100.0, torque = 360.0 }, { rpm = 1200.0, torque = 360.0 },
        { rpm = 1300.0, torque = 360.0 }, { rpm = 1400.0, torque = 360.0 }, { rpm = 1500.0, torque = 360.0 },
        { rpm = 1600.0, torque = 360.0 }, { rpm = 1700.0, torque = 360.0 }, { rpm = 1800.0, torque = 360.0 },
        { rpm = 1900.0, torque = 360.0 }, { rpm = 2000.0, torque = 360.0 }, { rpm = 2100.0, torque = 360.0 },
        { rpm = 2200.0, torque = 360.0 }, { rpm = 2300.0, torque = 360.0 }, { rpm = 2400.0, torque = 360.0 },
        { rpm = 2500.0, torque = 360.0 }, { rpm = 2600.0, torque = 360.0 }, { rpm = 2700.0, torque = 360.0 },
        { rpm = 2800.0, torque = 360.0 }, { rpm = 2900.0, torque = 360.0 }, { rpm = 3000.0, torque = 360.0 },
        { rpm = 3100.0, torque = 360.0 }, { rpm = 3200.0, torque = 360.0 }, { rpm = 3300.0, torque = 360.0 },
        { rpm = 3400.0, torque = 360.0 }, { rpm = 3500.0, torque = 360.0 }, { rpm = 3600.0, torque = 360.0 },
        { rpm = 3700.0, torque = 360.0 }, { rpm = 3800.0, torque = 360.0 }, { rpm = 3900.0, torque = 360.0 },
        { rpm = 4000.0, torque = 358.1 }, { rpm = 4100.0, torque = 349.4 }, { rpm = 4200.0, torque = 341.0 },
        { rpm = 4300.0, torque = 333.1 }, { rpm = 4400.0, torque = 325.5 }, { rpm = 4500.0, torque = 318.3 },
        { rpm = 4600.0, torque = 311.4 }, { rpm = 4700.0, torque = 304.8 }, { rpm = 4800.0, torque = 298.4 },
        { rpm = 4900.0, torque = 292.3 }, { rpm = 5000.0, torque = 286.5 }, { rpm = 5100.0, torque = 280.9 },
        { rpm = 5200.0, torque = 275.5 }, { rpm = 5300.0, torque = 270.3 }, { rpm = 5400.0, torque = 265.3 },
        { rpm = 5500.0, torque = 260.4 }, { rpm = 5600.0, torque = 255.8 }, { rpm = 5700.0, torque = 251.3 },
        { rpm = 5800.0, torque = 247.0 }, { rpm = 5900.0, torque = 242.8 }, { rpm = 6000.0, torque = 238.7 },
        { rpm = 6100.0, torque = 234.8 }, { rpm = 6200.0, torque = 231.0 }, { rpm = 6300.0, torque = 227.4 },
        { rpm = 6400.0, torque = 223.8 }, { rpm = 6500.0, torque = 220.4 }, { rpm = 6600.0, torque = 217.0 },
        { rpm = 6700.0, torque = 213.8 }, { rpm = 6800.0, torque = 210.6 }, { rpm = 6900.0, torque = 207.6 },
        { rpm = 7000.0, torque = 204.6 }, { rpm = 7100.0, torque = 201.7 }, { rpm = 7200.0, torque = 198.9 },
        { rpm = 7300.0, torque = 196.2 }, { rpm = 7400.0, torque = 193.6 }, { rpm = 7500.0, torque = 191.0 },
        { rpm = 7600.0, torque = 188.5 }, { rpm = 7700.0, torque = 186.0 }, { rpm = 7800.0, torque = 183.6 },
        { rpm = 7900.0, torque = 181.3 }, { rpm = 8000.0, torque = 179.0 }, { rpm = 8100.0, torque = 176.8 },
        { rpm = 8200.0, torque = 174.7 }, { rpm = 8300.0, torque = 172.6 }, { rpm = 8400.0, torque = 170.5 },
        { rpm = 8500.0, torque = 168.5 }, { rpm = 8600.0, torque = 166.6 }, { rpm = 8700.0, torque = 164.6 },
        { rpm = 8800.0, torque = 162.8 }, { rpm = 8900.0, torque = 160.9 }, { rpm = 9000.0, torque = 159.2 }
    }

    for idx, p in ipairs(samplePoints) do
        torqueCurve[idx] = p
    end

    local evCurve = {}
    local evSamplePoints = {
        { rpm = 1000.0, torque = 242.2 }, { rpm = 1100.0, torque = 275.2 }, { rpm = 1200.0, torque = 302.8 },
        { rpm = 1300.0, torque = 326.1 }, { rpm = 1400.0, torque = 346.0 }, { rpm = 1500.0, torque = 363.3 },
        { rpm = 1600.0, torque = 378.5 }, { rpm = 1700.0, torque = 391.8 }, { rpm = 1800.0, torque = 403.7 },
        { rpm = 1900.0, torque = 414.3 }, { rpm = 2000.0, torque = 423.9 }, { rpm = 2100.0, torque = 432.5 },
        { rpm = 2200.0, torque = 440.4 }, { rpm = 2300.0, torque = 447.6 }, { rpm = 2400.0, torque = 454.2 },
        { rpm = 2500.0, torque = 460.2 }, { rpm = 2600.0, torque = 465.8 }, { rpm = 2700.0, torque = 471.0 },
        { rpm = 2800.0, torque = 475.8 }, { rpm = 2900.0, torque = 480.3 }, { rpm = 3000.0, torque = 484.4 },
        { rpm = 3100.0, torque = 488.3 }, { rpm = 3200.0, torque = 492.0 }, { rpm = 3300.0, torque = 491.9 },
        { rpm = 3400.0, torque = 491.7 }, { rpm = 3500.0, torque = 491.2 }, { rpm = 3600.0, torque = 490.7 },
        { rpm = 3700.0, torque = 489.9 }, { rpm = 3800.0, torque = 489.0 }, { rpm = 3900.0, torque = 487.9 },
        { rpm = 4000.0, torque = 486.7 }, { rpm = 4100.0, torque = 485.2 }, { rpm = 4200.0, torque = 483.7 },
        { rpm = 4300.0, torque = 481.9 }, { rpm = 4400.0, torque = 480.0 }, { rpm = 4500.0, torque = 477.9 },
        { rpm = 4600.0, torque = 475.6 }, { rpm = 4700.0, torque = 473.2 }, { rpm = 4800.0, torque = 470.6 },
        { rpm = 4900.0, torque = 467.9 }, { rpm = 5000.0, torque = 465.0 }, { rpm = 5100.0, torque = 461.9 },
        { rpm = 5200.0, torque = 458.6 }, { rpm = 5300.0, torque = 455.2 }, { rpm = 5400.0, torque = 451.6 },
        { rpm = 5500.0, torque = 447.8 }, { rpm = 5600.0, torque = 443.9 }, { rpm = 5700.0, torque = 439.8 },
        { rpm = 5800.0, torque = 435.6 }, { rpm = 5900.0, torque = 431.1 }, { rpm = 6000.0, torque = 426.6 },
        { rpm = 6100.0, torque = 421.8 }, { rpm = 6200.0, torque = 416.9 }, { rpm = 6300.0, torque = 411.8 },
        { rpm = 6400.0, torque = 406.5 }, { rpm = 6500.0, torque = 401.1 }, { rpm = 6600.0, torque = 395.0 },
        { rpm = 6700.0, torque = 389.1 }, { rpm = 6800.0, torque = 383.4 }, { rpm = 6900.0, torque = 377.8 },
        { rpm = 7000.0, torque = 370.5 }, { rpm = 7100.0, torque = 360.5 }, { rpm = 7200.0, torque = 347.9 },
        { rpm = 7300.0, torque = 332.7 }
    }

    for idx, p in ipairs(evSamplePoints) do
        evCurve[idx] = p
    end

    local driveForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    local vehMass = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass")
    local isEV = isVehicleElectric()
    local transType = isEV and 3 or 2
    local activeCurve = isEV and evCurve or torqueCurve

    local drag = getDragCoeff(vehicleOriginalTopSpeed * 0.75, vehicleOriginalTopSpeed, getLimitedRatioTable(vehicleOriginalGearCount), driveForce, activeCurve, vehMass)

    AutoProfiler = {
        chassis = {
            curbWeight = vehMass,
            dragCoefficient = drag,
            bodyRollAmmount = 0.2,
            frontWeightDist = 0.5,
            topSpeed = vehicleOriginalTopSpeed,
            vehicleUseAutoCom = true
        },
        engine = {
            power = driveForce,
            ptwRatio = driveForce / vehMass,
            torqueCurve = activeCurve
        },
        forcedInduction = {
            antiLagProfile = "Default",
            hasAntilag = false,
            isTurbocharged = false,
            torqueGain = 0.1
        },
        transmission = {
            gearCount = vehicleOriginalGearCount,
            gearRatios = { 3.333, 1.849, 1.253, 1.011, 0.918, 0.851, 0.767, 0.692, 0.622 },
            maxSpeed = vehicleOriginalTopSpeed,
            launchControl = {
                enabled = false,
                targetRpmRange = 0.65
            },
            shiftingTime = 1.0 / GetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleUpShift"),
            rpmDecaymentSpeed = 2.5,
            frontTorqueDist = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront"),
            transmissionType = transType
        },
        brakes = {
            brakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
        },
        tyre = {
            useTyreCompound = true,
            tyreCompound = "Auto"
        },
        offsets = {
            camera = {
                chaseCamYOffset = 0,
                chaseCamZOffset = 0.0,
                fpvCamYOffset = 0,
                fpvCamZOffset = 0
            },
            carBrakeGlow = {
                glowBrakeRadius = 0.0,
                carGlowBrakeXOffset = 0.0
            },
            bikeBrakeGlow = {
                usesDualDiskFrontBrake = false,
                bikeGlowBrakeFrontSpacing = 0.0,
                brakeDiskSettings = {
                    bikeGlowBrakeFrontRadius = 0.0,
                    bikeGlowBrakeFrontOffset = 0.0,
                    bikeGlowBrakeFrontDiskWidth = 0.0,
                    bikeGlowBrakeRearRadius = 0.0,
                    bikeGlowBrakeRearOffset = 0.0,
                    bikeGlowBrakeRearDiskWidth = 0.0
                }
            },
            animation = {
                shiftingAnimId = 0
            }
        }
    }

    vehicleConfig["AutoProfiler"] = AutoProfiler
    tireConfig["Auto"] = {
        peakTractionG = vehicleOriginalMaxG,
        lateralCurveAngle = vehicleOriginalLatCurve,
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
    currentVehicle = "AutoProfiler"
end

function resetPastVehicle(veh)
    local isPlayerInVeh = (GetVehiclePedIsIn(player, false) == veh)
    if DoesEntityExist(veh) and not isPlayerInVeh then
        if isValidVehicle then
            local gearCount = vehicleOriginalGearCount
            local ratioTable = defaultGearRatioTable[gearCount + 1]
            local ratios = {}
            local maxSpeedList = {}
            local shiftTime = vehicleOriginalShiftTime

            for i = 0, gearCount do
                table.insert(ratios, ratioTable[i + 1])
            end

            local maxRatio = ratios[#ratios]
            local topSpeed = vehicleOriginalTopSpeed * maxRatio

            for _, r in pairs(ratios) do
                table.insert(maxSpeedList, math.round(topSpeed / r))
            end

            local calculatedMaxVel = (maxSpeedList[#maxSpeedList] * ratios[#ratios]) / 1.2

            SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveMaxFlatVel", calculatedMaxVel)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleUpShift", shiftTime)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fClutchChangeRateScaleDownShift", shiftTime)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDragCoeff", vehicleOriginalDragCoefficient)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveForce", vehicleOriginalPower)
            SetVehicleHandlingFloat(veh, "CHandlingData", "nInitialDriveGears", gearCount)

            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 125 do
                Citizen.Wait(0)
                SetVehicleEnginePowerMultiplier(veh, 0.39)
            end

            SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveLateral", vehicleOriginalLatCurve)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveMax", vehicleOriginalMaxG)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveMin", vehicleOriginalMinG)
            SetVehicleHandlingFloat(veh, "CHandlingData", "fLowSpeedTractionLossMult", vehicleOriginalLowSpeedTractionLoss)
            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", vehicleOriginalBrakingForce)
            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeBiasFront", vehicleOriginalBrakingBias)

            for i = 0, gearCount do
                SetVehicleGearRatio(veh, i, ratios[i + 1] + 0.0)
                Citizen.Wait(0)
            end

            SetVehicleHighGear(veh, gearCount)
            ForceUseAudioGameObject(veh, GetEntityModel(veh))

            local maxWheels = IsThisModelABike(GetEntityModel(vehicle)) and 1 or 3
            for i = 0, maxWheels do
                SetVehicleWheelFlags(veh, i, vehicleOriginalWheelFlags[i])
            end

            debugPrint("Past Vehicle was reseted!")
        end
    else
        if not isPlayerInVeh then
            if isValidVehicle then
                debugPrint("Past Vehicle wasn't reseted as it did not existed.")
            end
        end
        return
    end
end

function stopDynamic(netId)
    dynamicExitVehicle(netId)
end

function killDynamic()
    clearEntityVariables()
    menuSpawnHack = false
    dynamicKillThreads(false)
    handleHideShow(false, false, false)
end

function startDynamic(netId)
    dynamicEnterVehicle(netId)
end

function getVehicleNameFromModel(modelHash)
    for modelName, _ in pairs(vehicleConfig) do
        if GetHashKey(modelName) == modelHash then
            return modelName
        end
    end
    return -1
end

function pauseDynamic(shouldPause, netId, pauseCam, pauseNuiState)
    if pauseCam then
        pauseCamera(shouldPause)
    end
    if pauseNuiState then
        pauseNui(shouldPause)
    end

    if shouldPause then
        local ped = PlayerPedId()
        if 0 ~= netId then
            if IsPedInAnyVehicle(ped, false) then
                local currentVeh = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(currentVeh, -1) == ped then
                    dynamicExitVehicle(netId)
                else
                    dynamicExitVehiclePassenger(netId)
                end
            else
                print("Player is not in a vehicle.")
            end
        end
        isDynamicPaused = true
    else
        isDynamicPaused = false
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local currentVeh = GetVehiclePedIsIn(ped, false)
            local isDriver = (GetPedInVehicleSeat(currentVeh, -1) == ped)
            Citizen.Wait(150)

            if isDriver then
                dynamicExitVehicle(netId)
                Citizen.Wait(150)
                dynamicEnterVehicle(netId)
            else
                dynamicExitVehiclePassenger(netId)
                Citizen.Wait(150)
                dynamicEnterVehiclePassenger(netId)
            end
        end
    end
end

function getDynamicPauseStatus()
    if isDynamicPaused == false then
        return false
    elseif isDynamicPaused == true then
        return true
    else
        return false
    end
end
