function startHud()
    debugPrint("Starting Hud!")

    local frictionConsts = {
        maxTemp = 165,
        optRangeMin = 70,
        optRangeMax = 90,
        muCold = 0.9,
        muOpt = 1.025,
        muHot = 0.7
    }

    if tireConfig and tireConfig["Auto"] and tireConfig["Auto"].advancedSettings then
        frictionConsts = tireConfig["Auto"].advancedSettings.frictionConstants or frictionConsts
    end

    SendNUIMessage({
        action = "start",
        maxRpm = vehicleEngineMaxRpm or 7700,
        xPosSpeedo = hudConfig.speedometer.xPos,
        yPosSpeedo = hudConfig.speedometer.yPos,
        scaleSpeedo = hudConfig.speedometer.scale,
        xPosTire = hudConfig.tireHeat.xPos,
        yPosTire = hudConfig.tireHeat.yPos,
        scaleTire = hudConfig.tireHeat.scale,
        tireOptMin = frictionConsts.optRangeMin,
        tireOptMax = frictionConsts.optRangeMax,
        tireHeat = frictionConsts.maxTemp,
        isMotorcycle = isCurrentVehicleMotorycle,
        xPosFuel = hudConfig.fuel.xPos,
        yPosFuel = hudConfig.fuel.yPos,
        scaleFuel = hudConfig.fuel.scale / 100,
        canUseNitrous = hasNitrousInstalled or false,
        nitrousAmmount = nitrousPercent or 0
    })

    handleHideShow(hudConfig.speedometer.enabled, hudConfig.tireHeat.enabled, hudConfig.fuel.enabled)
    startHudThread()
end

function handleHideShow(speedoShow, tireShow, fuelShow)
    SendNUIMessage({
        action = "hideshow",
        speedoShow = speedoShow,
        tireShow = tireShow,
        fuelShow = fuelShow
    })
end

function setNuiState(speedoShow, tireShow, fuelShow)
    handleHideShow(speedoShow, tireShow, fuelShow)
end

function pauseNui(shouldPause)
    if shouldPause then
        handleHideShow(false, false, false)
        hudThreadEnabled = false
        hudIsPaused = true
    else
        hudIsPaused = false
        startHud()
    end
end

function isNuiPaused()
    return hudIsPaused
end
