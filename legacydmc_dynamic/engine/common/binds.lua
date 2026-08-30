if physicsSettings.experienceData.useDynamicKeybinds then
    RegisterCommand("↑shift", function()
        if not IsPauseMenuActive() then
            if GetIsVehicleEngineRunning(vehicle) then
                upShift()
            end
        end
    end, false)

    RegisterCommand("↓shift", function()
        if not IsPauseMenuActive() then
            if GetIsVehicleEngineRunning(vehicle) then
                downShift()
            end
        end
    end, false)

    RegisterCommand("+↑clutch", function()
        if not IsPauseMenuActive() then
            if GetIsVehicleEngineRunning(vehicle) then
                if 1 == vehicleTransmissionTypeId then
                    vehicleClutchPedalRequestTime = GetGameTimer()
                    vehicleClutchPedalIsPressed = true
                end
            end
        end
    end, false)

    RegisterCommand("-↑clutch", function()
        if not IsPauseMenuActive() then
            if GetIsVehicleEngineRunning(vehicle) then
                vehicleClutchPedalRequestTime = GetGameTimer()
                vehicleClutchPedalIsPressed = false
            end
        end
    end, false)

    RegisterCommand("+↑orbit", function()
        if not IsPauseMenuActive() then
            lockOrbitCamReturn = true
        end
    end, false)

    RegisterCommand("-↑orbit", function()
        if not IsPauseMenuActive() then
            lockOrbitCamReturn = false
        end
    end, false)

    RegisterCommand("+↑nitrous", function()
        if not IsPauseMenuActive() then
            if not isNitrousActive then
                if nitrousTankTime > 0 then
                    if hasNitrous then
                        if not forceNitrous then
                            if not HasNamedPtfxAssetLoaded("veh_xs_vehicle_mods") then
                                RequestNamedPtfxAsset("veh_xs_vehicle_mods")
                            end
                            isNitrousActive = true
                            nitrousActivatedTime = GetGameTimer()

                            InitializeTrailFxForVehicle(vehicle)
                            if trailFx[vehicle] and "Full" ~= trailFx[vehicle].status then
                                StartTrailFx(vehicle)
                                trailFx[vehicle].status = "Full"
                            end

                            local soundName = vehicleIsElectric and "start_nitrous_ev" or "start_nitrous"
                            nitrousSoundId = PlayEntitySound(vehicle, soundName, "DYNAMIC_SOUNDBANK", 0, "DYNAMIC_TRANSMISSION")
                        end
                    end
                end
            else
                if not isNitrousActive then
                    if nitrousTankTime <= 0 then
                        if hasNitrous then
                            if not forceNitrous then
                                local soundName = vehicleIsElectric and "stop_nitrous_ev" or "stop_nitrous"
                                PlayEntitySound(vehicle, soundName, "DYNAMIC_SOUNDBANK", 0, "DYNAMIC_TRANSMISSION")
                            end
                        end
                    end
                end
            end
        end
    end, false)

    RegisterCommand("-↑nitrous", function()
        if not IsPauseMenuActive() then
            if isNitrousActive then
                if hasNitrous then
                    if not forceNitrous then
                        endNitrous()
                    end
                end
            end
        end
    end, false)

    RegisterKeyMapping("↑shift", "1. Upshift", "keyboard", "UP")
    RegisterKeyMapping("↓shift", "2. Downshift", "keyboard", "DOWN")
    RegisterKeyMapping("+↑clutch", "3. Clutch", "keyboard", "LMENU")
    RegisterKeyMapping("+↑orbit", "4. Lock Look-Arround Cam", "mouse_button", "MOUSE_MIDDLE")
    RegisterKeyMapping("+↑nitrous", "5. Nitrous", "keyboard", "TAB")
end

RegisterCommand("dynamicDebugVerbose", function()
    allowDebugVerbose = not allowDebugVerbose
end, false)

if devMode then
    RegisterCommand("piAvg", function()
        local count = 0
        for modelName, _ in pairs(vehicleConfig) do
            print(modelName)
            count = count + 1
        end
        print("AVG PI: " .. count)
    end, false)

    RegisterCommand("setnitrous", function(source, args, rawCommand)
        if #args ~= 2 then
            TriggerEvent("chat:addMessage", {
                color = { 255, 0, 0 },
                multiline = true,
                args = { "[Error]", "Usage: /setnitrous <tankCapacity> <powerMulti>" }
            })
            return
        end

        local capacity = tonumber(args[1])
        local powerMulti = tonumber(args[2])

        if not capacity or not powerMulti then
            TriggerEvent("chat:addMessage", {
                color = { 255, 0, 0 },
                multiline = true,
                args = { "[Error]", "Invalid arguments. Use numbers for tankCapacity (seconds) and powerMulti." }
            })
            return
        end

        setNitrous(capacity, powerMulti)
        TriggerEvent("chat:addMessage", {
            color = { 0, 255, 0 },
            multiline = true,
            args = { "[Success]", "Nitrous set with tank capacity: " .. capacity .. " seconds, power multiplier: " .. powerMulti }
        })
    end, false)

    RegisterCommand("removenitrous", function()
        removeNitrous()
    end, false)

    RegisterCommand("chargenitrous", function(source, args, rawCommand)
        if #args ~= 1 then
            TriggerEvent("chat:addMessage", {
                color = { 255, 0, 0 },
                multiline = true,
                args = { "[Error]", "Usage: /chargenitrous <tankCapacity>" }
            })
            return
        end

        local capacity = tonumber(args[1])
        chargeNitrous(capacity)
    end, false)

    RegisterCommand("tcs", function()
        tcsAllowed = not tcsAllowed
    end, false)

    RegisterCommand("esc", function()
        escAllowed = not escAllowed
    end, false)

    RegisterCommand("testNos", function()
        forceNitrous = not forceNitrous
        forceNitrousState(forceNitrous, 5.0)
    end, false)

    RegisterCommand("testTune", function()
        local setup = {
            frontTorqueDist = 0,
            gearCount = 8,
            gearRatios = { 5.25, 3.36, 2.172, 1.72, 1.316, 1.0, 0.822, 0.64 },
            gearSfxProfile = "german_dct_01",
            launchControl = {
                enabled = true,
                targetRpmRange = 0.7
            },
            maxSpeed = 411,
            rpmDecaymentSpeed = 3,
            shiftingTime = 125,
            transmissionType = 0
        }
        loadTunedSetup("stock", setup, nil, 1.0, 1.0, 1.0)
    end, false)

    RegisterCommand("car", function(source, args)
        local modelName = args[1]
        if not modelName then
            return
        end

        local attempts = 0
        RequestModel(modelName)
        while not HasModelLoaded(modelName) do
            Citizen.Wait(0)
            attempts = attempts + 1
            if attempts > 1000 then
                return
            end
        end

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)

        local veh = CreateVehicle(modelName, coords.x, coords.y, coords.z, heading, true, false)
        TaskWarpPedIntoVehicle(playerPed, veh, -1)
        SetVehicleEngineOn(veh, true, true, false)
    end, false)
end

