function startDifferentialThread()
    differentialThreadEnabled = true
    debugPrint("Started Differential Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not differentialThreadEnabled then
                debugPrint("Stopping Differential thread!")
                clearDifferentialVariables()
                break
            end

            local syncEnabled = physicsSettings.netSyncData.enableDriftSync

            local rearLeftSlip = vehicleWheels[2] and vehicleWheels[2].slipAngle or 0.0
            local rearRightSlip = vehicleWheels[3] and vehicleWheels[3].slipAngle or 0.0
            local avgRearSlip = math.abs((rearLeftSlip + rearRightSlip) / 2.0)

            if avgRearSlip > 12.0 and vehicleSpeedKmh > 20.0 then
                vehicleIsCurrentlyDrifting = true
                vehicleIsSliding = true
            else
                vehicleIsCurrentlyDrifting = false
                vehicleIsSliding = false
            end

            if vehicleIsCurrentlyDrifting then
                if not networkHasSentDriftSyncRequest and syncEnabled then
                    TriggerServerEvent("dynamic:syncState", vehicleNetId, 4, { vehicleIsCurrentlyDrifting, currentInterpolatedRpm })
                    networkHasSentDriftSyncRequest = true
                end
            else
                if networkHasSentDriftSyncRequest and syncEnabled then
                    TriggerServerEvent("dynamic:syncState", vehicleNetId, 4, { vehicleIsCurrentlyDrifting, currentInterpolatedRpm })
                    networkHasSentDriftSyncRequest = false
                end
            end
        end
    end)
end
