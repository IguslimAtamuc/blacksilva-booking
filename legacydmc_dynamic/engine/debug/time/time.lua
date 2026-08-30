local speedCheckpoints = { 100, 160, 200, 250, 300 }
local timerStartTime = nil
local recordedTimes = {}
local isMeasuring = false
local isTimeTestEnabled = false

function kmh(speedMs)
    return speedMs * 3.6
end

if devMode then
    RegisterCommand("timeTest", function()
        isTimeTestEnabled = not isTimeTestEnabled
        if isTimeTestEnabled then
            print("^2[ACCEL]^0 Acceleration timer ^2enabled^0. Come to a stop and go full throttle.")
        else
            print("^1[ACCEL]^0 Acceleration timer ^1disabled^0. Resetting.")
            isMeasuring = false
            timerStartTime = nil
            recordedTimes = {}
        end
    end, false)

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped, false) then
                if isTimeTestEnabled then
                    local currentKmh = kmh(vehicleSpeed)

                    if currentKmh < 1.0 then
                        if isMeasuring then
                            print("^3[ACCEL]^0 Vehicle stopped. Timer reset.")
                        end
                        isMeasuring = false
                        timerStartTime = nil
                        recordedTimes = {}
                    else
                        if not isMeasuring then
                            isMeasuring = true
                            timerStartTime = GetGameTimer()
                            print("^2[ACCEL]^0 Measuring acceleration...")
                        end
                    end

                    if isMeasuring then
                        for _, checkpoint in ipairs(speedCheckpoints) do
                            if checkpoint <= currentKmh then
                                if recordedTimes[checkpoint] == nil then
                                    local elapsedTime = (GetGameTimer() - timerStartTime) / 1000.0
                                    recordedTimes[checkpoint] = elapsedTime
                                    print(string.format("^6[ACCEL]^0 0-%d km/h: %.2f seconds", checkpoint, elapsedTime))
                                end
                            end
                        end
                    end
                end
            else
                isMeasuring = false
                timerStartTime = nil
                recordedTimes = {}
            end
        end
    end)
end

