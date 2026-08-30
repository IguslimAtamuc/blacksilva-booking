local enableTuning = physicsSettings.upgradeData.enableVanillaTuningIntegration
local powerFactor = physicsSettings.upgradeData.enginePowerMultiplierFactor
local powerList = physicsSettings.upgradeData.enginePowerMultiplier
local brakeFactor = physicsSettings.upgradeData.brakesPowerMultiplierFactor
local brakeList = physicsSettings.upgradeData.brakesPowerMultiplier
local shiftTimeFactor = physicsSettings.upgradeData.transmissionShiftTimeMultiplier

function getAirResistanceAtSpeedG(speedMs, dragCoeff, mass)
    local frontalArea = 2.2
    local airDensity = 1.225
    local dragForceN = 0.5 * airDensity * (dragCoeff or 0.3) * frontalArea * (speedMs ^ 2)
    local massKg = mass or 1500.0
    return dragForceN / (massKg * 9.81)
end

function computePerformanceIndex(vehData)
    local tracks = {
        { StraightLengthMeters = 900, CornerRadiusMeters = 20, CornerAngleDegrees = 450 },
        { StraightLengthMeters = 300, CornerRadiusMeters = 160, CornerAngleDegrees = 20 },
        { StraightLengthMeters = 300, CornerRadiusMeters = 200, CornerAngleDegrees = 50 },
        { StraightLengthMeters = 300, CornerRadiusMeters = 120, CornerAngleDegrees = 60 },
        { StraightLengthMeters = 300, CornerRadiusMeters = 90, CornerAngleDegrees = 70 },
        { StraightLengthMeters = 900, CornerRadiusMeters = 60, CornerAngleDegrees = 120 }
    }

    local gravity = 9.81
    local accelG = vehData.accelG or 0.5
    if vehData.turbo and vehData.turbo.isTurbocharged then
        local gain = 1.0 + (vehData.turbo.torqueGain or 0.0)
        accelG = accelG * gain
    end

    local brakingG = vehData.brakingG or 0.5
    local peakGripG = vehData.peakGripG or 1.2
    local dragCoeff = vehData.dragCoeff or 0.3

    local downforceGripGain = (physicsSettings.tunableData.downforceGripGainCoeff or 0.0) * 4.0 * peakGripG
    local effectiveGripG = peakGripG + downforceGripGain

    local driveType = vehData.driveType or "AWD"
    local driveMultipliers = {
        FWD = { cornering = 0.95, straight = 0.98, lapTimeScale = 1.02 },
        RWD = { cornering = 1.00, straight = 1.00, lapTimeScale = 1.00 },
        AWD = { cornering = 1.05, straight = 1.02, lapTimeScale = 0.97 }
    }

    local driveStats = driveMultipliers[driveType] or driveMultipliers["AWD"]
    local corneringMult = driveStats.cornering
    local straightMult = driveStats.straight
    local lapScale = driveStats.lapTimeScale

    local gearTopSpeedsKmh = vehData.gearTopSpeedsKmh or { 60, 100, 150, 200, 250 }
    local gearRatios = vehData.gearRatios or { 3.333, 1.849, 1.253, 1.011, 0.918 }

    local gearTable = {}
    local maxGears = math.min(#gearTopSpeedsKmh, #gearRatios)
    for i = 1, maxGears do
        local topSpeedKmh = gearTopSpeedsKmh[i] or 200
        local ratio = gearRatios[i] or 1.0
        if topSpeedKmh > 0 and ratio > 0 then
            table.insert(gearTable, {
                redlineSpeedMPS = topSpeedKmh / 3.6,
                ratio = ratio
            })
        end
    end

    if #gearTable == 0 then
        table.insert(gearTable, { redlineSpeedMPS = 999999, ratio = 1.0 })
    end

    table.sort(gearTable, function(a, b)
        return a.redlineSpeedMPS < b.redlineSpeedMPS
    end)

    local totalLapTime = 0.0

    for _, track in ipairs(tracks) do
        local straightLen = track.StraightLengthMeters or 0
        local cornerRadius = track.CornerRadiusMeters or 0
        local cornerAngle = track.CornerAngleDegrees or 0

        local maxCornerSpeedMPS = 999999.0
        if cornerRadius > 0 and cornerAngle > 0 then
            local radAngle = math.rad(cornerAngle)
            maxCornerSpeedMPS = math.sqrt(effectiveGripG * corneringMult * gravity * cornerRadius)
        end

        local straightTime = 0.0
        if straightLen > 0 then
            local speedMPS = maxCornerSpeedMPS
            local dist = 0.0
            local dt = 0.05

            while dist < straightLen do
                local currentGearIdx = 1
                for idx, gear in ipairs(gearTable) do
                    if speedMPS <= gear.redlineSpeedMPS then
                        currentGearIdx = idx
                        break
                    end
                end

                local activeRatio = gearTable[currentGearIdx].ratio
                local driveAccelG = accelG * activeRatio * straightMult
                local dragG = getAirResistanceAtSpeedG(speedMPS, dragCoeff, vehData.mass or 1500)
                local netAccelG = math.max(0.0, driveAccelG - dragG)

                speedMPS = speedMPS + (netAccelG * gravity * dt)
                dist = dist + (speedMPS * dt)
                straightTime = straightTime + dt

                if netAccelG <= 0.0001 then
                    straightTime = straightTime + ((straightLen - dist) / math.max(1.0, speedMPS))
                    break
                end
            end
        end

        local cornerTime = 0.0
        if cornerRadius > 0 and cornerAngle > 0 then
            local radAngle = math.rad(cornerAngle)
            local cornerArcLen = cornerRadius * radAngle
            cornerTime = cornerArcLen / math.max(1.0, maxCornerSpeedMPS)
        end

        totalLapTime = totalLapTime + straightTime + cornerTime
    end

    local finalLapTime = totalLapTime * lapScale
    local piIndex = math.floor((3000.0 / math.max(10.0, finalLapTime)) * 100.0 + 0.5)
    return math.max(100, piIndex)
end

function computeGearboxPower(vehData)
    local accelG = vehData.accelG or 0.5
    if vehData.turbo and vehData.turbo.isTurbocharged then
        local gain = 1.0 + (vehData.turbo.torqueGain or 0.0)
        accelG = accelG * gain
    end

    local gearRatios = vehData.gearRatios or { 3.333, 1.849, 1.253, 1.011, 0.918 }
    local gearTopSpeedsKmh = vehData.gearTopSpeedsKmh or { 60, 100, 150, 200, 250 }
    local dragCoeff = vehData.dragCoeff or 0.3
    local totalPower = 0.0

    local numGears = math.min(#gearRatios, #gearTopSpeedsKmh)
    for i = 1, numGears do
        local ratio = gearRatios[i] or 1.0
        local topSpeedKmh = gearTopSpeedsKmh[i] or 200
        local powerAtGear = accelG * ratio * (topSpeedKmh / 100.0)
        totalPower = totalPower + powerAtGear
    end

    return totalPower / math.max(1, numGears)
end

function compute0to100(vehData)
    local accelG = vehData.accelG or 0.5
    if vehData.turbo and vehData.turbo.isTurbocharged then
        local gain = 1.0 + (vehData.turbo.torqueGain or 0.0)
        accelG = accelG * gain
    end

    local gearTopSpeedsKmh = vehData.gearTopSpeedsKmh or { 60, 100, 150, 200, 250 }
    local gearRatios = vehData.gearRatios or { 3.333, 1.849, 1.253, 1.011, 0.918 }
    local dragCoeff = vehData.dragCoeff or 0.3
    local mass = vehData.mass or 1500.0

    local speedKmh = 0.0
    local timeSec = 0.0
    local dt = 0.01

    local currentGearIdx = 1
    local numGears = math.min(#gearTopSpeedsKmh, #gearRatios)

    while speedKmh < 100.0 and timeSec < 30.0 do
        if currentGearIdx <= numGears and speedKmh >= gearTopSpeedsKmh[currentGearIdx] then
            currentGearIdx = currentGearIdx + 1
            timeSec = timeSec + (vehData.shiftTimeMs or 200) / 1000.0
        end

        local ratio = (currentGearIdx <= numGears) and gearRatios[currentGearIdx] or 1.0
        local driveAccelG = accelG * ratio
        local dragG = getAirResistanceAtSpeedG(speedKmh / 3.6, dragCoeff, mass)
        local netAccelG = math.max(0.01, driveAccelG - dragG)

        local deltaSpeedKmh = netAccelG * 9.81 * dt * 3.6
        speedKmh = speedKmh + deltaSpeedKmh
        timeSec = timeSec + dt
    end

    return timeSec
end

function computeTopSpeedHigh(vehData)
    local accelG = vehData.accelG or 0.5
    if vehData.turbo and vehData.turbo.isTurbocharged then
        local gain = 1.0 + (vehData.turbo.torqueGain or 0.0)
        accelG = accelG * gain
    end

    local gearTopSpeedsKmh = vehData.gearTopSpeedsKmh or { 60, 100, 150, 200, 250 }
    local gearRatios = vehData.gearRatios or { 3.333, 1.849, 1.253, 1.011, 0.918 }
    local dragCoeff = vehData.dragCoeff or 0.3
    local mass = vehData.mass or 1500.0

    local speedKmh = 0.0
    local dt = 0.1
    local currentGearIdx = 1
    local numGears = math.min(#gearTopSpeedsKmh, #gearRatios)

    while speedKmh < 500.0 do
        if currentGearIdx < numGears and speedKmh >= gearTopSpeedsKmh[currentGearIdx] then
            currentGearIdx = currentGearIdx + 1
        end

        local ratio = gearRatios[currentGearIdx] or 1.0
        local driveAccelG = accelG * ratio
        local dragG = getAirResistanceAtSpeedG(speedKmh / 3.6, dragCoeff, mass)
        local netAccelG = driveAccelG - dragG

        if netAccelG <= 0.001 then
            break
        end

        speedKmh = speedKmh + (netAccelG * 9.81 * dt * 3.6)
    end

    local maxConfiguredSpeed = gearTopSpeedsKmh[#gearTopSpeedsKmh] or 250.0
    return math.min(speedKmh, maxConfiguredSpeed)
end

function simulateBraking160To0(vehData)
    local brakingG = vehData.brakingG or 0.5
    local peakGripG = vehData.peakGripG or 1.2
    local dragCoeff = vehData.dragCoeff or 0.3
    local mass = vehData.mass or 1500.0

    if brakingG <= 0 then
        debugPrint("[Warning] Brake force for this vehicle is 0, canceled tests to avoid dead loops!")
        return { distance = 0, time = 0, finalSpeed = 0 }
    end

    local downforceGripGain = (physicsSettings.tunableData.downforceGripGainCoeff or 0.0) * 4.0 * peakGripG
    local effectiveBrakingG = math.min(peakGripG, brakingG + downforceGripGain)

    local speedMs = 160.0 / 3.6
    local dt = 0.01
    local totalDist = 0.0
    local totalTime = 0.0

    while speedMs > 0 and totalTime < 60.0 do
        local dragG = getAirResistanceAtSpeedG(speedMs, dragCoeff, mass)
        local decelG = effectiveBrakingG + dragG

        local deltaSpeed = decelG * 9.81 * dt
        speedMs = math.max(0.0, speedMs - deltaSpeed)
        totalDist = totalDist + (speedMs * dt)
        totalTime = totalTime + dt
    end

    return {
        distance = totalDist,
        time = totalTime,
        finalSpeed = 0
    }
end

function clearPerformanceIndexVariables()
end
