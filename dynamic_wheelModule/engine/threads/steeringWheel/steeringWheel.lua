function startInputFeedBackThread()
    inputFeedBackThread = true
    print("Starting Wheel Input Thread!")

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not inputFeedBackThread then
                print("Stopping Wheel Input Thread!")
                break
            end

            if shouldUseSteeringWheel then
                SendNUIMessage({ type = "getLiveInputs" })

                playerThrottle = GetInputState("throttle")
                playerBrake = GetInputState("brake")
                playerClutch = GetInputState("clutch")

                local rawSteer = GetInputState("steering")
                local maxRot = wheelSettings.wheelConfig and wheelSettings.wheelConfig.maxRotation or 900
                local steerRange = wheelSettings.wheelConfig and wheelSettings.wheelConfig.steerRange or 360

                playerSteering = mapSteeringInput(rawSteer, maxRot, steerRange)
                playerRawSteering = rawSteer
                playerSteeringScale = getWheelSteeringScale(maxRot, steerRange)

                playerUpShiftAction = GetInputState("upshift")
                playerDownShiftAction = GetInputState("downshift")
                playerHandBrakeAction = GetInputState("handbrake")
                playerLeftSignalAction = GetInputState("lightLeft")
                playerRightSignalAction = GetInputState("lightRight")
                playerHazardSignalAction = GetInputState("lightHazard")
                playerHornAction = GetInputState("actHorn")
                playerStartUpAction = GetInputState("actStartup")
                playerCamSwitchAction = GetInputState("camSwitch")

                for i = 1, 10 do
                    playerGearShiftAction[i] = GetInputState("gear" .. tostring(i - 1))
                end

                playerHeadLightAction = GetInputState("headlightSwitch")
                playerFfbSettings = wheelSettings.wheelConfig and wheelSettings.wheelConfig.ffbConfig or {}
            end

            if sendForceFeedBackData then
                local ffbData = exports.legacydmc_dynamic:returnFfbData()
                SendNUIMessage({
                    action = "wheelData",
                    payload = ffbData
                })
            end
        end
    end)
end

