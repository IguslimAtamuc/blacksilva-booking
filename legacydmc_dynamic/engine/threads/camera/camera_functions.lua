function getCameraData(camIdx)
    if not cameraConfig then return nil end
    return cameraConfig[camIdx]
end

function getCameraAmmount()
    if not cameraConfig then return 0 end
    return #cameraConfig
end

function startCamera(camIdx, isFpv)
    if isFpv == nil then isFpv = false end

    if not cameraConfig then return end
    currentCameraIdx = camIdx or 1
    cameraData = cameraConfig[currentCameraIdx]

    if not cameraData then return end

    if not currentCamera or not DoesCamExist(currentCamera) then
        currentCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end

    SetCamActive(currentCamera, true)
    RenderScriptCams(true, true, 500, true, true)

    if cameraData.isFpv then
        isCurrentCameraFpv = true
        pedHeadBone = GetPedBoneIndex(playerPed, 12844)
    else
        isCurrentCameraFpv = false
    end

    cameraThreadEnabled = true
    debugPrint("Started Camera Thread!")
end

function swapCamera(camIdx)
    if not cameraConfig or not cameraConfig[camIdx] then
        debugPrint("[Warning] Invalid Camera Data, please check if the inputted id exists.")
        return
    end

    cameraData = cameraConfig[camIdx]
    currentCameraIdx = camIdx
    isOrbitCamActive = false
    stopFpvCamAnim = true

    if cameraData.isFpv then
        isCurrentCameraFpv = true
        pedHeadBone = GetPedBoneIndex(playerPed, 12844)
        SetFollowVehicleCamViewMode(4)
        SetFollowPedCamViewMode(4)
    else
        isCurrentCameraFpv = false
        SetFollowPedCamViewMode(2)
        SetFollowVehicleCamViewMode(2)
    end
end

function stopCamera(immediate)
    if currentCamera and DoesCamExist(currentCamera) then
        SetCamActive(currentCamera, false)
        DestroyCam(currentCamera, immediate or false)
        RenderScriptCams(false, true, 500, true, true)
    end

    cameraThreadEnabled = false
    isCurrentCameraFpv = false
    debugPrint("Stopped Camera Thread!")
end

function pauseCamera(state)
    cameraIsPaused = state
    if state then
        stopCamera(false)
    else
        if physicsSettings and physicsSettings.experienceData and physicsSettings.experienceData.useChaseCamByDefault then
            startCamera(currentCameraIdx or 1, false)
        end
    end
end

function isCameraPaused()
    return cameraIsPaused
end

function damp(sourceVal, targetVal, smoothing, dt)
    return sourceVal + (targetVal - sourceVal) * (1.0 - math.exp(-smoothing * dt))
end

function mappedLock(val, lockLimit)
    return (val - lockLimit) * 0.13333333333333333
end

function getHeadingPitchFixedDist(fromPos, dirVec, toPos)
    local diff = toPos - fromPos
    local dist = math.sqrt((diff.x * diff.x) + (diff.y * diff.y) + (diff.z * diff.z))
    if dist < 0.0001 then return 0.0, 0.0 end

    local headingRad = math.atan2(diff.x, diff.y)
    local pitchRad = math.asin(diff.z / dist)

    return math.deg(headingRad), math.deg(pitchRad)
end

function updateChaseCamera(camIdx)
    local config = cameraConfig[camIdx]
    if not config then return end

    local dt = GetFrameTime()
    local vehPos = GetEntityCoords(vehicle)
    local vehFwd = GetEntityForwardVector(vehicle)
    local vehUp = GetEntityUpVector(vehicle)
    local vehRight = GetEntityRightVector(vehicle)

    local speedKmh = vehicleSpeedKmh or 0.0
    local speedNorm = math.min(1.0, speedKmh / 200.0)

    local targetFov = config.baseFOV + (config.dynamicFOVGain * speedNorm)
    SetCamFov(currentCamera, targetFov)

    local chaseY = config.chaseCamYOffset or -5.5
    local chaseZ = config.chaseCamZOffset or 1.8

    local offsetPos = vehPos - (vehFwd * math.abs(chaseY)) + (vehUp * chaseZ)
    currentCameraPosition = damp(currentCameraPosition or offsetPos, offsetPos, config.cameraFollowSpeedMulti or 10.0, dt)

    SetCamCoord(currentCamera, currentCameraPosition.x, currentCameraPosition.y, currentCameraPosition.z)

    if not isOrbitCamActive then
        PointCamAtCoord(currentCamera, vehPos.x, vehPos.y, vehPos.z + 0.5)
    end
end

function updateFpvCamera(camIdx)
    local config = cameraConfig[camIdx]
    if not config then return end

    local dt = GetFrameTime()
    local headPos = GetPedBoneCoords(playerPed, 12844, 0.0, 0.0, 0.0)
    local vehFwd = GetEntityForwardVector(vehicle)

    local fov = config.baseFOV or 75.0
    SetCamFov(currentCamera, fov)

    currentCameraPosition = headPos + (vehFwd * 0.1)
    SetCamCoord(currentCamera, currentCameraPosition.x, currentCameraPosition.y, currentCameraPosition.z)

    if not isUsingGameplayAimCamera then
        local vehRot = GetEntityRotation(vehicle, 2)
        SetCamRot(currentCamera, vehRot.x, vehRot.y, vehRot.z, 2)
    end
end

function enableFpvSubmix()
    SetAudioSubmixEffectRadioFx(0, 0)
    SetAudioSubmixEffectParamInt(0, 0, GetHashKey("default"), 1)
end

function disableFpvSubmix()
    SetAudioSubmixEffectRadioFx(0, 0)
    SetAudioSubmixEffectParamInt(0, 0, GetHashKey("default"), 0)
end

function clearCameraVairables()
    currentCamera = nil
    currentCameraIdx = 1
    cameraData = {}
    isCurrentCameraFpv = false
    cameraThreadEnabled = false
    cameraIsPaused = false
    isOrbitCamActive = false
    isUsingGameplayAimCamera = false
    fpvRoofAudioMixDisable = false
end
