function runNitrous()
    if hasNitrous and isNitrousActive then
        local elapsed = GetGameTimer() - nitrousActivatedTime
        nitrousTankTimeUsed = math.abs(elapsed)

        if nitrousTankTimeUsed > 0 and not hasSyncedNitrousFx then
            TriggerServerEvent("dynamic:syncState", vehicleNetId, 9, { true, globalGameTimer })
            hasSyncedNitrousFx = true
        end

        if nitrousTankTimeUsed >= nitrousTankTime then
            endNitrous()
        end

        local remaining = math.max(0, nitrousTankTime - nitrousTankTimeUsed)
        nitrousPercent = remaining / nitrousTankPercentRef

        SetVehicleNitroEnabled(vehicle, true)
        LoopTrailFx(vehicle)
    end
end
