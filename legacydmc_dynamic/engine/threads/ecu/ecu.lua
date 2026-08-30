11function startEcuThread()
    ecuThreadEnabled = true
    debugPrint("Starting ECU Thread!")

    Citizen.CreateThread(function()
        while true do
            if not DoesEntityExist(vehicle) then
                debugPrint("Stopping Ecu Thread!")
                clearEcuVariables()
                debugPrint("Stopping Engine Thread!")
                engineThreadEnabled = false
                debugPrint("Stopping Tyre Thread!")
                tyreThreadEnabled = false
                debugPrint("Clearing Chassis!")
                clearChassisVariables()
                debugPrint("Clearing Nitrous!")
                clearNitrousVariables()
                break
            end

            Citizen.Wait(0)
            globalEntityCheck = DoesEntityExist(vehicle)

            if DoesEntityExist(vehicle) then
                gameDeltaTime = GetFrameTime()
                globalGameTimer = GetGameTimer()
                vehiclePosition = GetEntityCoords(vehicle)
                vehicleForwardVector = GetEntityForwardVector(vehicle)
                vehicleEntitySpeedVector = GetEntitySpeedVector(vehicle)
                vehicleEngineIsOn = GetIsVehicleEngineRunning(vehicle)
                vehicleHeading = GetEntityHeadingFromEulers(vehicle)
                vehicleSpeed = GetEntitySpeed(vehicle)
                vehicleSpeedKmh = vehicleSpeed * 3.6
                vehicleEntityVelocity = GetEntityVelocity(vehicle)
                vehicleEntityRotationalVelocity = GetEntityRotationVelocity(vehicle)

                vehicleThrottle = GetVehicleThrottleOffset(vehicle)
                vehicleBrakes = GetControlNormal(0, 72)
                vehicleSteering = GetVehicleSteeringAngle(vehicle)
                vehicleIsBraking = IsDisabledControlPressed(0, 72)
                vehicleHandbrake = IsDisabledControlPressed(0, 76)
                vehicleIsFlying = not IsVehicleOnAllWheels(vehicle)
                vehicleGameCurrentClutchEngagement = GetVehicleClutch(vehicle)
                vehicleRotation = GetEntityRotation(vehicle, 2)
                vehicleGameCurrentRpm = GetVehicleCurrentRpm(vehicle)
                vehicleCurrentTurboPressure = GetVehicleTurboPressure(vehicle)
                averageDrivenWheelSpeed = getAverageDrivenWheelSpeed()
                currentVehicleGear = GetVehicleCurrentGear(vehicle)

                vehicleCurrentGforce = getTotalGForce()
                vehicleEffectiveTractionLossRatio = getTractionLossRatio()

                local numWheels = isCurrentVehicleMotorycle and 2 or 4
                for i = 0, numWheels - 1 do
                    local wheel = vehicleWheels[i]
                    if wheel then
                        local fwdSpeed, rightSpeed = getWheelDotVelocity(i)
                        wheel.speed = fwdSpeed
                        wheel.slipRatio = getTireSlipRatio(i)
                        wheel.slipAngle = getSlipAngle(i)
                        wheel.wheelLoad = GetVehicleWheelTireColliderOpacity(vehicle, i) or 500.0
                        wheel.position = GetWorldPositionOfEntityBone(vehicle, wheelBoneIndexes[i])
                        wheel.fwdVec = GetEntityForwardVector(vehicle)
                        wheel.suspensionCompression = GetVehicleWheelSuspensionCompression(vehicle, i) or 0.0
                        wheel.currentMaterialId = GetVehicleWheelSurfaceMaterial(vehicle, i)
                        wheel.materialFricMulti = GetVehicleWheelTractionVectorLength(vehicle, i) or 1.0

                        updateTireTemperature(i)
                    end
                end

                ecuLoaded = true
            end
        end
    end)
end
