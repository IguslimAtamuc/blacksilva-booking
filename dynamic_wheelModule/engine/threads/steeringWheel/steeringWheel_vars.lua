currentWheelInputs = {}

local savedConfigRaw = GetResourceKvpString("dynamic_wheel_steerConfig") or "null"
savedWheelConfig = json.decode(savedConfigRaw) or {}

local savedBindingsRaw = GetResourceKvpString("dynamic_wheel_bindings") or "{}"
local savedDeviceId = GetResourceKvpInt("dynamic_wheel_deviceId")
if not savedDeviceId or savedDeviceId == -1 then
    savedDeviceId = nil
end

wheelSettings = {
    bindings = json.decode(savedBindingsRaw),
    deviceId = savedDeviceId,
    wheelConfig = {
        maxRotation = savedWheelConfig.maxRotation or 900,
        steerRange = savedWheelConfig.steerRange or 360,
        ffbConfig = savedWheelConfig.ffbConfig or {
            overallGain = 100,
            damperGain = 40,
            frictionGain = 10,
            detailGain = 30,
            gammaGain = 1.0
        }
    }
}

playerThrottle = 0
playerBrake = 0
playerClutch = 0
playerSteering = 0
playerUpShiftAction = 0
playerDownShiftAction = 0
playerHandBrakeAction = 0
playerRawSteering = 0
playerSteeringScale = 0
playerLeftSignalAction = 0
playerRightSignalAction = 0
playerHazardSignalAction = 0
playerHornAction = 0
playerStartUpAction = 0
playerCamSwitchAction = 0
playerGearShiftAction = {}
playerHeadLightAction = 0
playerFfbSettings = {}

inputFeedBackThread = false
sendForceFeedBackData = false
shouldUseSteeringWheel = false

