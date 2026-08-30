function RegisterExport(name, func)
    local exportEvent = "__cfx_export_" .. GetCurrentResourceName() .. "_" .. name
    AddEventHandler(exportEvent, function(cb)
        cb(func)
    end)
end

local function registerBindsExports()
    RegisterExport("bindUpshift", bindUpshift)
    RegisterExport("bindDownshift", bindDownshift)
    RegisterExport("bindClutchIn", bindClutchIn)
    RegisterExport("bindClutchOut", bindClutchOut)
    RegisterExport("bindOrbitLockIn", bindOrbitLockIn)
    RegisterExport("bindOrbitLockOut", bindOrbitLockOut)
    RegisterExport("bindNitrousIn", bindNitrousIn)
    RegisterExport("bindNitrousOut", bindNitrousOut)
end

local function registerAntilagExports()
    RegisterExport("toggleAntilag", toggleAntilag)
    RegisterExport("getAntilag", getAntilag)
end

local function registerBrakeExports()
    RegisterExport("setBrakeTemp", setBrakeTemp)
    RegisterExport("getBrakeTemp", getBrakeTemp)
    RegisterExport("toggleBrakeDebug", toggleBrakeDebug)
    RegisterExport("debugSetBrakeFadeRadius", debugSetBrakeFadeRadius)
    RegisterExport("debugSetBrakeXoffset", debugSetBrakeXoffset)
end

local function registerDynamicExports()
    RegisterExport("getDynamicPauseStatus", getDynamicPauseStatus)
    RegisterExport("stopDynamic", stopDynamic)
    RegisterExport("startDynamic", startDynamic)
    RegisterExport("pauseDynamic", pauseDynamic)
end

local function registerCameraExports()
    RegisterExport("getCameraData", getCameraData)
    RegisterExport("getCameraAmmount", getCameraAmmount)
    RegisterExport("startCamera", startCamera)
    RegisterExport("swapCamera", swapCamera)
    RegisterExport("stopCamera", stopCamera)
    RegisterExport("pauseCamera", pauseCamera)
    RegisterExport("isCameraPaused", isCameraPaused)
    RegisterExport("setCurrentCameraPitchOffset", setCurrentCameraPitchOffset)
    RegisterExport("setCurrentCameraFovOffset", setCurrentCameraFovOffset)
    RegisterExport("setCurrentCameraSpacingOffset", setCurrentCameraSpacingOffset)
    RegisterExport("setCurrentFpvCameraSpacingOffset", setCurrentFpvCameraSpacingOffset)
    RegisterExport("toggleBikeYawCorrection", toggleBikeYawCorrection)
end

local function registerChassisExports()
    RegisterExport("getAutoComValues", getAutoComValues)
end

local function registerDriftExports()
    RegisterExport("getIsVehicleCurrentlyDrifting", getIsVehicleCurrentlyDrifting)
    RegisterExport("getIsVehicleCurrentlyDriftingThrottleLess", getIsVehicleCurrentlyDriftingThrottleLess)
end

local function registerDifferentialExports()
    RegisterExport("setFrontTorqueDist", setFrontTorqueDist)
end

local function registerNuiExports()
    RegisterExport("setNuiState", setNuiState)
    RegisterExport("pauseNui", pauseNui)
    RegisterExport("isNuiPaused", isNuiPaused)
end

local function registerNitrousExports()
    RegisterExport("setNitrous", setNitrous)
    RegisterExport("removeNitrous", removeNitrous)
    RegisterExport("chargeNitrous", chargeNitrous)
    RegisterExport("getCurrentNitrousPercent", getCurrentNitrousPercent)
    RegisterExport("getCurrentNitrousPowerMulti", getCurrentNitrousPowerMulti)
    RegisterExport("getCurrentNitrousTankSize", getCurrentNitrousTankSize)
    RegisterExport("forceNitrousState", forceNitrousState)
end

local function registerTelemetryExports()
    RegisterExport("setCurrentVehicleTcsLevel", setCurrentVehicleTcsLevel)
    RegisterExport("toggleTcs", toggleTcs)
    RegisterExport("toggleEsc", toggleEsc)
    RegisterExport("getAssists", getAssists)
    RegisterExport("getTelemetryData", getTelemetryData)
    RegisterExport("getGlobalTelemetryData", getGlobalTelemetryData)
    RegisterExport("getWheelData", getWheelData)
    RegisterExport("getVehicleData", getVehicleData)
    RegisterExport("getAvailableTyres", getAvailableTyres)
    RegisterExport("getTyreData", getTyreData)
    RegisterExport("getAvailableEngineSwaps", getAvailableEngineSwaps)
    RegisterExport("getEngineData", getEngineData)
    RegisterExport("returnFfbData", returnFfbData)
    RegisterExport("dynamicBootComplete", dynamicBootComplete)
end

local function registerPerformanceIndexExports()
    RegisterExport("getPerformanceIndex", getPerformanceIndex)
    RegisterExport("getPerformanceIndexCalibrationMetrics", getPerformanceIndexCalibrationMetrics)
end

local function registerSteeringExports()
    RegisterExport("enableSteering", enableSteering)
    RegisterExport("toggleForceMouseSteering", toggleForceMouseSteering)
    RegisterExport("getForceMouseSteeringState", getForceMouseSteeringState)
end

local function registerTransmissionExports()
    RegisterExport("getTopSpeedTable", getTopSpeedTable)
    RegisterExport("getTopSpeedTableFromTransmissionData", getTopSpeedTableFromTransmissionData)
    RegisterExport("setTransmissionMode", setTransmissionMode)
    RegisterExport("getTransmissionMode", getTransmissionMode)
    RegisterExport("forceClutchDisengage", forceClutchDisengage)
end

local function registerTuningExports()
    RegisterExport("loadTunedSetup", loadTunedSetup)
    RegisterExport("setVehicleTopspeed", setVehicleTopspeed)
end

local function registerTyreExports()
    RegisterExport("warmTyre", warmTyre)
end

AddEventHandler("onClientResourceStart", function()
    registerBindsExports()
    registerAntilagExports()
    registerBrakeExports()
    registerDynamicExports()
    registerCameraExports()
    registerChassisExports()
    registerDriftExports()
    registerDifferentialExports()
    registerTelemetryExports()
    registerNuiExports()
    registerNitrousExports()
    registerPerformanceIndexExports()
    registerSteeringExports()
    registerTransmissionExports()
    registerTuningExports()
    registerTyreExports()
end)

