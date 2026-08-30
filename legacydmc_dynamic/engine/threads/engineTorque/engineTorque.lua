local enableTuning = physicsSettings.upgradeData.enableVanillaTuningIntegration
local enginePowerFactor = physicsSettings.upgradeData.enginePowerMultiplierFactor
local enginePowerList = physicsSettings.upgradeData.enginePowerMultiplier

function handleEngineTorque()
    if engineThreadEnabled then
        local rawTorque = calcTorque(vehicleEngineTorqueCurve, vehicleEngineMaxTorque, vehicleGameCurrentRpm, vehicleEngineMinRpm, vehicleEngineMaxRpm)
        vehicleCurrentEngineTorqueCurveFactor = rawTorque or 0.0

        local boostTarget = 0.0
        if isEngineTurboCharged and vehicleCurrentTurboPressure > 0.0 then
            boostTarget = vehicleCurrentTurboPressure * turboTorqueGain
        end
        local boostMulti = 1.0 + boostTarget

        local nosMulti = isNitrousActive and nitrousPowerMulti or 1.0

        local modLevel = math.min(3, GetVehicleMod(vehicle, 11))
        local modRatio = 1.0
        local powerMulti = 1.0

        if modLevel >= 0 and enableTuning then
            local modValue = GetVehicleModModifierValue(vehicle, 11, modLevel) / 100
            modRatio = 1.0 / (1.0 + (0.2 * modValue))
            powerMulti = 1.0 + (enginePowerFactor * enginePowerList[modLevel + 1])
        end

        local totalTorqueMulti = vehicleCurrentEngineTorqueCurveFactor * boostMulti * nosMulti * modRatio * powerMulti * (forceEnginePowerMultiplier or 1.0)
        SetVehicleCheatPowerIncrease(vehicle, totalTorqueMulti)
    end
end
