function engineSwap(engineName)
    if engineName == "stock" then
        buildEngine()
        return "Stock engine restored!"
    end

    if engineSwaps and engineSwaps[engineName] then
        local swapData = engineSwaps[engineName]
        vehicleEngineGforce = swapData.power or 0.25
        vehicleEngineTorqueCurve = swapData.torqueCurve or currentRawTorqueCurve

        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", vehicleEngineGforce)
        debugPrint("New Engine Power Applied!")

        if swapData.audioHash then
            SetVehicleAudioEngineHash(vehicle, GetHashKey(swapData.audioHash))
        end

        return "Engine swap applied: " .. engineName
    else
        debugPrint("[Warning] Engine Hash not found.")
        return nil
    end
end

function transmissionSwap(transData)
    if isVehicleElectric() then
        debugPrint("You can't transmission swap an electric vehicle!")
        return
    end

    if type(transData) ~= "table" then return end

    vehicleTransmissionTypeId = transData.transmissionType or 2
    vehicleGearCount = transConfig and transConfig.gearCount or 5
    vehicleShiftingTime = transData.shiftingTime or 0.2
    vehicleRpmDecaymentSpeed = transData.rpmDecaymentSpeed or 3.0

    if vehicleTransmissionTypeId == 0 or vehicleTransmissionTypeId == 1 then
        atThreadEnabled = false
        transmissionThreadEnabled = true
    else
        atThreadEnabled = true
        transmissionThreadEnabled = false
    end
end

function clearTuningVariables()
end
