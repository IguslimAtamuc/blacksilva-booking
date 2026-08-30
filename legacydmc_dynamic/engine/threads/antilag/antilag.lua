function createPopAudioNode(veh, modelName, entityTable)
    if not DoesEntityExist(veh) then
        return nil
    end

    if entityTable and entityTable[veh] then
        if DoesEntityExist(entityTable[veh]) then
            DeleteEntity(entityTable[veh])
        end
    end

    local bonePos = nil
    if vehicleExhaustBone ~= -1 then
        bonePos = GetWorldPositionOfEntityBone(veh, vehicleExhaustBone)
    else
        bonePos = GetEntityCoords(veh)
    end

    local localOffset = GetOffsetFromEntityGivenWorldCoords(veh, bonePos.x, bonePos.y, bonePos.z)
    local shellModel = ensureModelLoaded(modelName or "w_pi_flaregun_shell")

    local obj = CreateObjectNoOffset(shellModel, bonePos.x, bonePos.y, bonePos.z, false, false, false)
    SetEntityCollision(obj, false, true)
    SetEntityInvincible(obj, true)
    SetEntityAlpha(obj, 0, true)

    AttachEntityToEntity(obj, veh, -1, 0.0, localOffset.y, localOffset.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

    if entityTable then
        entityTable[veh] = obj
    end

    return obj
end

function startAntilagThread()
    antilagThreadEnabled = true
    debugPrint("Starting Antilag Thread!")
    buildAntilag()

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            if not antilagThreadEnabled then
                debugPrint("Stopping Antilag Thread!")
                clearAntilagVariables()
                break
            end

            if globalGameTimer - refreshPopVfxTime >= 5000 then
                RequestNamedPtfxAsset("veh_xs_vehicle_mods")
                refreshPopVfxTime = globalGameTimer
            end

            for i = #trackedSounds, 1, -1 do
                if HasSoundFinished(trackedSounds[i]) then
                    popsPlayingAmmount = popsPlayingAmmount - 1
                    table.remove(trackedSounds, i)
                end
            end

            simulateTurboPressure()
        end
    end)
end
