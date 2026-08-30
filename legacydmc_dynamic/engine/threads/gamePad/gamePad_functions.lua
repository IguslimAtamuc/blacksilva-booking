smoothSuspension = 0.0
smoothTractionRate = 0.0
lastCompression = {}

function smoothFilter(current, target, rate)
    return current + ((target - current) * rate)
end

function getDrivetrainTractionLossRatio()
    local totalTraction = 0.0
    local totalLoad = 0.0

    for i = 0, 3 do
        local wheel = vehicleWheels[i]
        if wheel then
            totalTraction = totalTraction + (wheel.tractionVector or 0.0)
            totalLoad = totalLoad + (wheel.wheelLoad or 0.0)
        end
    end

    if totalLoad < 1.5 then
        return 0.0
    end

    return totalTraction / totalLoad
end

function getSmoothedTractionRatio(reset)
    local rawRatio = getDrivetrainTractionLossRatio()
    if reset then
        smoothTractionRate = 0.0
    end
    smoothTractionRate = smoothFilter(smoothTractionRate, rawRatio, 0.1)
    return smoothTractionRate
end

function getSmoothedSuspensionVibration()
    local deltaSum = 0.0

    for i = 0, 3 do
        local wheel = vehicleWheels[i]
        if wheel and wheel.suspensionCompression then
            local currentComp = wheel.suspensionCompression
            local prevComp = lastCompression[i] or currentComp
            local diff = currentComp - prevComp

            if diff > 0.0001 then
                deltaSum = deltaSum + diff
            end
            lastCompression[i] = currentComp
        end
    end

    local norm = math.min(1.0, deltaSum * 5.0) ^ 0.3
    smoothSuspension = smoothFilter(smoothSuspension, norm, 0.2)
    return smoothSuspension
end

function useImprovedFeedback()
    local suspensionVal = getSmoothedSuspensionVibration()
    local tractionVal = getSmoothedTractionRatio(false)

    local intensity = math.min(1.0, (tractionVal ^ 0.9))
    local roundedIntensity = math.floor(intensity + 0.5)

    if GetGameTimer() - lastVibrationTime >= 100 then
        lastVibrationTime = GetGameTimer()
        SendNUIMessage({
            action = "vibrate",
            amountRight = roundedIntensity,
            amountLeft = roundedIntensity
        })
    end
end
