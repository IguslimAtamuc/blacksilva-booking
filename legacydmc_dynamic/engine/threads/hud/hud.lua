function startHudThread()
    hudThreadEnabled = true

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(hudConfig.refreshRate or 50)

            if not hudThreadEnabled then
                debugPrint("Stopping Hud Thread!")
                break
            end

            local fuelRatio = 1.0
            if maxFuelAmmount and maxFuelAmmount > 0 then
                fuelRatio = GetVehicleFuelLevel(vehicle) / maxFuelAmmount
            end
            currentFuelLevel = fuelRatio

            local speedUnit = hudConfig.showSpeedInMPH and "mph" or "km/h"
            local flTemp = vehicleWheels[0] and vehicleWheels[0].temperature or 25
            local frTemp = vehicleWheels[1] and vehicleWheels[1].temperature or 25
            local rlTemp = vehicleWheels[2] and vehicleWheels[2].temperature or 25
            local rrTemp = vehicleWheels[3] and vehicleWheels[3].temperature or 25

            SendNUIMessage({
                action = "update",
                rpm = vehicleGameCurrentRpm or 0,
                gear = currentVehicleGear or 1,
                speedMs = vehicleSpeed or 0,
                fuelLevel = currentFuelLevel,
                speedUnit = speedUnit,
                flTemp = flTemp,
                frTemp = frTemp,
                rlTemp = rlTemp,
                rrTemp = rrTemp,
                tcs = isTcsActive,
                esc = isEscActive,
                tcsAllow = tcsAllowed,
                escAllow = escAllowed,
                isMotorcycle = isCurrentVehicleMotorycle,
                canUseNitrous = hasNitrousInstalled,
                nitrousAmmount = nitrousPercent or 0
            })
        end
    end)
end
