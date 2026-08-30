function buildChassis()
    local config = vehicleConfig[currentVehicle]
    local chassisConfig = config.chassis
    local transmissionConfig = config.transmission

    local curbWeight = chassisConfig.curbWeight or 1500.0
    local topSpeed = chassisConfig.topSpeed or (transmissionConfig.maxSpeed * 0.95)
    local defaultRatios = { -3.333, 3.333, 1.849, 1.253, 1.011, 0.918, 0.851, 0.767, 0.692 }
    local gearRatios = transmissionConfig.gearRatios or defaultRatios

    vehicleCurrentSimulatedWeight = curbWeight
    vehicleTopSpeed = topSpeed
    vehicleDragCoefficient = chassisConfig.dragCoefficient or 0.2

    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", vehicleDragCoefficient)
    debugPrint("Drag Coefficient Applied!")

    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", vehicleCurrentSimulatedWeight)
    setVehicleChassis()

    debugPrint("Applying Auto C.O.M")
    debugPrint("Chassis Built Succesfully!")
end

function clearChassisVariables()
    vehicleCurrentSimulatedWeight = 0
    vehicleTopSpeed = 200
    vehicleOrginalCom = GetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset")
    hasRestauredCom = false
end

function setVehicleCom(comVector)
    local beforeCom = GetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset")
    debugPrint("Veh C.O.M Before: " .. tostring(beforeCom))

    SetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset", comVector)
    vehicleCenterOfMassOffset = comVector

    local afterCom = GetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset")
    debugPrint("Veh C.O.M After: " .. tostring(afterCom))
end

function restaureCom()
    if vehicleOrginalCom then
        SetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset", vehicleOrginalCom)
        hasRestauredCom = true
    end
end

function getVehicleCom()
    return GetVehicleHandlingVector(vehicle, "CHandlingData", "vecCentreOfMassOffset")
end

function setVehicleChassis()
    local config = vehicleConfig[currentVehicle]
    local chassisConfig = config.chassis
    local allowAutoCom = physicsSettings.experienceData.allowAutoCom

    if not isCurrentVehicleMotorycle and chassisConfig.useAutoCom then
        if allowAutoCom then
            local frontWheelPos = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[0])
            local rearWheelPos = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[2])

            local wheelBase = math.abs(frontWheelPos.y - rearWheelPos.y)
            local bodyRoll = chassisConfig.bodyRollAmmount or 0.2
            local weightDist = chassisConfig.frontWeightDist or 0.5

            local frontRollHeight = (weightDist - 0.5) * bodyRoll
            local rearRollHeight = bodyRoll

            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fRollCentreHeightFront", frontRollHeight)
            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fRollCentreHeightRear", rearRollHeight)
        else
            debugPrint("[Warning] Auto C.O.M has been temporairly disabled.")
        end
    elseif isCurrentVehicleMotorycle then
        debugPrint("Chassis Auto C.O.M Feature currently not supported for motorcycles.")
    end
end

function getAutoComValues()
    local config = vehicleConfig[currentVehicle].chassis
    if not isCurrentVehicleMotorycle then
        local frontWheelPos = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[0])
        local rearWheelPos = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[2])
        local bodyRoll = config.bodyRollAmmount or 0.2
        local weightDist = config.frontWeightDist or 0.5

        local frontRollHeight = (weightDist - 0.5) * bodyRoll
        local rearRollHeight = bodyRoll

        return frontRollHeight, rearRollHeight
    end
    return 0.0, 0.0
end
