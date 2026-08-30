function startCameraThread()
    cameraThreadEnabled = true
    cameraData = cameraConfig[currentCameraIdx]

    Citizen.CreateThread(function()
        while true do
            local isLookAroundPressed = false
            if gamepadThreadEnabled then
                if IsControlPressed(0, 68) then
                    isLookAroundPressed = true
                end
            end
            if not isLookAroundPressed then
                isLookAroundPressed = not gamepadThreadEnabled and IsControlPressed(0, 25)
            end

            Citizen.Wait(0)

            if not cameraThreadEnabled then
                debugPrint("Stopping Camera Thread!")
                clearCameraVairables()
                break
            end

            stopFpvCamAnim = not vehicleEngineIsOn
            DisableControlAction(0, 0, true)

            if IsDisabledControlJustReleased(0, 0) and not isLookAroundPressed then
                if currentCameraIdx < #cameraConfig then
                    currentCameraIdx = currentCameraIdx + 1
                else
                    currentCameraIdx = 1
                end
                cameraData = cameraConfig[currentCameraIdx]
                swapCamera(currentCameraIdx)
            end

            for entity, isTracked in pairs(motionBlurTracked) do
                if DoesEntityExist(entity) then
                    if not isTracked then
                        SetEntityMotionBlur(entity, false)
                        motionBlurTracked[entity] = true
                    end
                else
                    motionBlurTracked[entity] = nil
                end
            end

            SetPedResetFlag(playerPed, 435, true)

            if cameraData.isFpv then
                SetFollowVehicleCamViewMode(4)
                SetFollowPedCamViewMode(4)

                if isLookAroundPressed then
                    if not isUsingGameplayAimCamera then
                        isUsingGameplayAimCamera = true
                        RenderScriptCams(false, true, 444, false, true)
                        SetGameplayCamRelativeHeading(pcCamHeading)
                        local relPitch = isOrbitCamActive and pcCamPitch or 0.0
                        SetGameplayCamRelativePitch(relPitch, 1.0)
                    end
                elseif not isLookAroundPressed then
                    if isUsingGameplayAimCamera then
                        isUsingGameplayAimCamera = false
                        RenderScriptCams(true, true, 444, false, true)
                        pcCamHeading, pcCamPitch = getHeadingPitchFixedDist(vehiclePosition, vehicleForwardVector, currentCameraPosition)
                        pcCamHeading = ((GetGameplayCamRelativeHeading() % 360) + 360) % 360
                    end
                end

                updateFpvCamera(currentCameraIdx)

                local roofState = GetConvertibleRoofState(vehicle)
                local isRoofOpen = (1 == roofState or 2 == roofState or 6 == roofState)
                local isExposed = isRoofOpen or (not isCurrentVehicleMotorycle and fpvIsLookingBackwards)

                if isExposed then
                    if not fpvRoofAudioMixDisable then
                        fpvRoofAudioMixDisable = true
                        disableFpvSubmix()
                    end
                else
                    if fpvRoofAudioMixDisable then
                        fpvRoofAudioMixDisable = false
                        enableFpvSubmix()
                    end
                end
            else
                if 4 == GetFollowVehicleCamViewMode() then
                    SetFollowPedCamViewMode(2)
                    SetFollowVehicleCamViewMode(2)
                end

                if isLookAroundPressed then
                    if not isUsingGameplayAimCamera then
                        isUsingGameplayAimCamera = true
                        SetFollowPedCamViewMode(2)
                        SetFollowVehicleCamViewMode(2)
                        RenderScriptCams(false, true, 444, false, true)
                        SetGameplayCamRelativeHeading(pcCamHeading)
                        local relPitch = isOrbitCamActive and pcCamPitch or 0.0
                        SetGameplayCamRelativePitch(relPitch, 1.0)
                    end
                elseif not isLookAroundPressed then
                    if isUsingGameplayAimCamera then
                        isUsingGameplayAimCamera = false
                        RenderScriptCams(true, true, 444, false, true)
                        SetFollowPedCamViewMode(2)
                        SetFollowVehicleCamViewMode(2)
                        pcCamHeading, pcCamPitch = getHeadingPitchFixedDist(vehiclePosition, vehicleForwardVector, currentCameraPosition)
                        pcCamHeading = ((GetGameplayCamRelativeHeading() % 360) + 360) % 360
                    end
                end

                updateChaseCamera(currentCameraIdx)
            end
        end
    end)
end
