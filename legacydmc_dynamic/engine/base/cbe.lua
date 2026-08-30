local wasInVehicle = false
local currentVehicle = 0
local currentSeat = -2
local isDriver = false

local function vehicleCheckLoop()
    while true do
        if not isDynamicPaused then
            if IsEntityDead(player) then
                local currentPed = PlayerPedId()
                if player ~= currentPed then
                    player = currentPed
                end
            end

            local pedVehicle = GetVehiclePedIsIn(player, false)
            local isInVehicle = (0 ~= pedVehicle)
            local pedSeat = -2

            if isInVehicle then
                local model = GetEntityModel(pedVehicle)
                local seatCount = GetVehicleModelNumberOfSeats(model)
                local maxSeatIndex = seatCount - 2

                for seatIndex = -1, maxSeatIndex do
                    if GetPedInVehicleSeat(pedVehicle, seatIndex) == player then
                        pedSeat = seatIndex
                        break
                    end
                end
            end

            if not wasInVehicle and isInVehicle then
                currentVehicle = pedVehicle
                currentSeat = pedSeat
                isDriver = (-1 == pedSeat)
                local vehicleNetId = VehToNet(pedVehicle)

                if isDriver then
                    TriggerEvent("dynamic:enteredVehicle", vehicleNetId, false)
                else
                    TriggerEvent("dynamic:enteredVehiclePassenger", vehicleNetId, false)
                end
            elseif wasInVehicle and not isInVehicle then
                local vehicleNetId = VehToNet(currentVehicle)

                if isDriver then
                    TriggerEvent("dynamic:leftVehicle", vehicleNetId)
                else
                    TriggerEvent("dynamic:leftVehiclePassenger", vehicleNetId)
                end

                currentVehicle = 0
                currentSeat = -2
            elseif wasInVehicle and isInVehicle then
                if pedVehicle ~= currentVehicle then
                    currentVehicle = pedVehicle
                    currentSeat = pedSeat
                    isDriver = (-1 == pedSeat)
                    local vehicleNetId = VehToNet(pedVehicle)

                    if isDriver then
                        TriggerEvent("dynamic:enteredVehicle", vehicleNetId, true)
                    else
                        TriggerEvent("dynamic:enteredVehiclePassenger", vehicleNetId, true)
                    end
                elseif pedSeat ~= currentSeat then
                    local vehicleNetId = VehToNet(pedVehicle)

                    if -1 == currentSeat then
                        TriggerEvent("dynamic:leftVehicle", vehicleNetId)
                    else
                        TriggerEvent("dynamic:leftVehiclePassenger", vehicleNetId)
                    end

                    if -1 == pedSeat then
                        TriggerEvent("dynamic:enteredVehicle", vehicleNetId, true)
                        isDriver = true
                    else
                        TriggerEvent("dynamic:enteredVehiclePassenger", vehicleNetId, true)
                        isDriver = false
                    end

                    currentSeat = pedSeat
                end
            end

            wasInVehicle = isInVehicle
        end

        Citizen.Wait(50)
    end
end

Citizen.CreateThread(vehicleCheckLoop)

