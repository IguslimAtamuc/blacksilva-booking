function createTimeLerp()
    local self = {
        active = false,
        startValue = 0.0,
        targetValue = 0.0,
        duration = 0.0,
        startTime = 0
    }

    function self:start(startVal, targetVal, duration)
        self.startValue = startVal
        self.targetValue = targetVal
        self.duration = duration
        self.startTime = GetGameTimer()
        self.active = true
    end

    function self:update()
        if not self.active then
            return self.targetValue, false
        end

        local elapsed = (GetGameTimer() - self.startTime) / 1000.0
        local progress = math.min(elapsed / self.duration, 1.0)
        local val = self.startValue + ((self.targetValue - self.startValue) * progress)

        if progress >= 1.0 then
            self.active = false
        end

        return val, self.active
    end

    function self:stop()
        self.active = false
        TriggerServerEvent("dynamic:syncState", vehicleNetId, 0, { false, 0, 0 })
    end

    return self
end

function clearFlywheelVariables()
end

function createTimeLerpNet()
    local self = {
        active = false,
        startValue = 0.0,
        targetValue = 0.0,
        duration = 0.0,
        startTime = 0
    }

    function self:start(startVal, duration, targetVal)
        self.startValue = startVal
        self.targetValue = targetVal
        self.duration = duration
        self.startTime = GetGameTimer()
        self.active = true
    end

    function self:update()
        if not self.active then
            return self.targetValue, false
        end

        local elapsed = (GetGameTimer() - self.startTime) / 1000.0
        local progress = math.min(elapsed / self.duration, 1.0)
        local val = self.startValue + ((self.targetValue - self.startValue) * progress)

        if progress >= 1.0 then
            self.active = false
        end

        return val, self.active
    end

    function self:stop()
        self.active = false
        TriggerServerEvent("dynamic:syncState", vehicleNetId, 0, { false, 0, 0 })
    end

    return self
end
