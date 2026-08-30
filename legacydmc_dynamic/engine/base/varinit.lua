player = nil
playerId = nil
playerPed = nil
wasDriver = false
vehicle = 0
vehicleNetId = 0
vehNetSyncCheck = 0
globalVehicleName = ""
globalVehicleModel = 0
globalVehicleHasConfig = false

globalVehData = {
    maxRpm = 0,
    minRpm = 0,
    maxFuelCapacity = 65
}

menuSpawnHack = false
netIdPatchable = 0
vehicleHasConfig = false
vehicleIsSupported = false
currentVehicle = 0
previousVehicle = 0
isCurrentVehicleMotorycle = false
exitingVehicle = false
enteringVehicle = false
bootSequenceComplete = false
globalEntityCheck = false
entityStateBag = nil
devMode = false
isValidVehicle = false
isDynamicPaused = false
isArcadeMode = physicsSettings.experienceData.isArcadeExperience
currentCarIsListed = false
requestedThreadKill = false
allowDebugVerbose = false
propStorage = {}

vehicleOriginalGearCount = 0
vehicleOriginalPower = 0
vehicleOriginalDragCoefficient = 0
vehicleOriginalTopSpeed = 0
vehicleOriginalBrakingForce = 0
vehicleOriginalBrakingBias = 0
vehicleOriginalShiftTime = 0
vehicleOriginalMaxG = 0
vehicleOriginalMinG = 0
vehicleOriginalLatCurve = 0
vehicleOriginalLowSpeedTractionLoss = 0
vehicleOriginalWheelFlags = {}

ecuThreadEnabled = false
ecuLoaded = false
vehicleSpeed = 0
vehicleSpeedKmh = 0
vehicleThrottle = 0
vehicleBrakes = 0
vehicleSteering = 0
isSteeringWheelEnabled = false
steeringWheelDataThread = false
SteeringWheelUpShift = false
SteeringWheelDownShift = false
vehicleIsFlying = false
vehicleGameCurrentClutchEngagement = 0
vehicleGameCurrentRpm = 0

vehicleGlobalVelocity = vector3(0, 0, 0)
vehicleSlipAngle = 0
vehiclePositionDelta = {}
vehicleTirePositionDelta = {}
vehicleVelocityPositionDelta = {}
vehicleTireVelocityPositionDelta = {}
vehicleForwardVector = 0
vehicleEntityVelocity = 0
vehicleEntitySpeedVector = vector3(0, 0, 0)
vehiclePosition = 0
averageDrivenWheelSpeed = 0
vehicleDriveTrainLayout = 0
vehicleCurrentSteeringAngle = 0
vehicleEffectiveTractionLossRatio = 0
vehicleCurrentForcedRpm = 0
vehicleCurrentDrivetrainForce = 0
vehicleCurrentTrackWidth = 0
vehicleCurrentWheelBase = 0
vehicleCenterOfMassOffset = vector3(0, 0, 0)
vehicleCenterOfMassHeight = 0
vehicleCurrentGforce = 0
vehicleCurrentTireLoad = {}
vehicleIsElectric = false
vehicleIsBraking = false
vehicleSteeringLock = 0
vehicleEngineIsOn = false
vehicleHeading = 0
vehicleEntityRotationalVelocity = vector3(0, 0, 0)
vehicleBrakingForce = 0
vehicleBrakingBias = 0.0
vehicleMaxSuspensionCompression = 0
vehicleMaxSuspensionExpansion = 0

tcsAllowed = physicsSettings.assistsData.enableAssistsByDefault
escAllowed = physicsSettings.assistsData.enableAssistsByDefault
fakeTcsBrakes = 0
fakeEscBrakes = 0
vehicleCurrentTcsLevel = 0
isEscActive = false
isTcsActive = false
vehicleTcsStatusMulti = 0
vehicleDummyBone = 0
vehicleHandbrake = 0
vehicleRotation = 0
vehiclefDriveInertia = 0.0
vehicleSuspensionBiasFront = 0.0
vehicleArbForce = 0.0
vehicleArbFrontBias = 0.0
vehicleSuspensionForce = 0.0
maxFuelAmmount = 0.0
lastSteeringInput = 0
filteredSteeringVelocity = 0.0
currentFFBDebugVal = 0
currentFuelLevel = 0.0
vehicleCurrentTurboPressure = 0.0
vehicleCurrentSimulatedTurboPressure = 0.0
vehicleExhaustBone = 0
exhaustBonePos = vector3(0, 0, 0)
globalGameTimer = 0

leftSignalStockEnabled = false
rightSignalStockEnabled = false
hazardLightEnabled = false
leftSignalArmed = false
rightSignalArmed = false
leftSignalStartSteering = 0.0
rightSignalStartSteering = 0.0
hazardButtonLastState = 0.0
leftButtonLastState = 0.0
rightButtonLastState = 0.0
startUpButtonLastState = 0.0
hShifterHasShifted = { false, false, false, false, false, false, false, false, false }
isCameraSwitchPressed = false
pastTransmissionLevel = -1

steeringWheelInput = {
    throttle = 0,
    rawSteering = 0,
    steerScale = 0,
    brakes = 0,
    clutch = 0,
    steering = 0,
    ffbSettings = {
        overallGain = 100,
        damperGain = 40,
        detailGain = 30,
        frictionGain = 10,
        gammaGain = 0.85
    }
}

local function createWheelData()
    return {
        speed = 0,
        tractionVector = 0,
        wheelLoad = 0,
        slipAngle = 0,
        slipRatio = 0,
        temperature = 0,
        tempFricMulti = 0,
        materialFricMulti = 0,
        currentMaterialId = 0,
        position = vector3(0, 0, 0),
        fwdVec = vector3(0, 0, 0),
        velocityVector = vector3(0, 0, 0),
        rotationalForce = 0.0,
        fakeTcsBrakes = 0,
        suspensionCompression = 0,
        suspensionTravelDistance = 0,
        lastNormalizedSuspension = 0,
        lastWheelGripMultiplier = 0.0,
        wheelCurrentGripMultiplier = 0.0
    }
end

vehicleWheel0 = createWheelData()
vehicleWheel1 = createWheelData()
vehicleWheel2 = createWheelData()
vehicleWheel3 = createWheelData()
vehicleWheels = { vehicleWheel0, vehicleWheel1, vehicleWheel2, vehicleWheel3 }

engineThreadEnabled = false
vehicleEngineGforce = 0
vehicleCurrentEngineTorqueCurveFactor = 0
shouldForceEnginePower = false
isEngineTurboCharged = false
turboTorqueGain = 0
currentRawTorqueCurve = {}
currentTuningPowerMultiplier = 1.0
forceEnginePowerMultiplier = 1.0
vehicleEngineGforcePower = 0
vehicleEngineTorqueCurve = 0
vehicleEngineMaxTorque = 0
vehicleEngineMaxRpm = 0
vehicleEngineMinRpm = 0

transmissionThreadEnabled = false
atThreadEnabled = false
currentVehicleGear = 0
vehicleGearCount = 0
vehicleGearRatios = {}
vehicleGearMaxSpeed = {}
vehicleTransmissionTypeId = 0
vehicleTransmissionMaxSpeed = 0
vehicleShiftingTime = 0
vehicleRpmDecaymentSpeed = 0
vehicleCurrentClutchEngagement = 1.0
vehicleIsCurrentlyShifting = false
vehicleShouldCutThrottle = false
vehicleShouldThrottleBlip = true
vehicleShouldLockTransmission = false
vehicleShouldConsiderInertialResistance = false
vehicleInertialResistanceFactor = 0.0
vehicleIsLugging = false
vehicleLuggingFactor = 0.0
vehicleLuggingPenaltyFactor = 0.0
lastSteeringWheelClutchValue = 1.0
vehicleAllowLaunchControl = false
vehicleLaunchControlRpm = 0.0
isInLaunchControlMode = false
disabledTcsAction = false
isForcingAutomaticTransmission = false
shouldTakeClutchControl = true
shiftActionIsUsingClutch = false
stopLimiterPopsPatch = false
useInvertedThrottleControl = true
invertThrottleControls = false
invertedThrottleControlSteerBias = 0.0
vehicleClutchPedalIsPressed = false
vehicleClutchPedalRequestTime = 0
vehicleClutchState = 0
manualAnimLerpTime = 0.0
isPlayingManualAnim = false

currentCachedAudioBanks = {}
lastLoadedBank = nil
lastPlayedRandom = {}
rpmAboveStartTime = nil
vehicleForceClutchDisengage = false
activeLaunchControlThreads = {}
currentGearSfxBank = ""
useGearSfx = false
isGearSfxPlaying = false
lastGear = 0
isDoingEDrift = false
clutchEDriftState = 0.0
isInArcadeDriftMode = false
lastTransmissionLevel = -1
differentialThreadEnabled = false
wheelBoneIndexes = {}
wheelRadiusIndexes = {}

materialData = {
    [0] = { key = 0.0 },
    [1] = { key = 0.0 },
    [2] = { key = 0.0 },
    [3] = { name = "CONCRETE_DUSTY", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [4] = { name = "TARMAC", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [5] = { name = "TARMAC_PAINTED", group = "HARD_TERRAIN", friction = 0.9, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [6] = { name = "TARMAC_POTHOLE", group = "HARD_TERRAIN", friction = 0.9, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [7] = { drag = 3.333 },
    [8] = { drag = 3.333 },
    [9] = { drag = 3.333 },
    [10] = { drag = 3.333 },
    [11] = { name = "STONE", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [12] = { name = "COBBLESTONE", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.13, topSpeedMulti = 1.0, dominantFrequency = 20.0 },
    [13] = { name = "BRICK", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 20.0 },
    [14] = { name = "MARBLE", group = "HARD_TERRAIN", friction = 0.9, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [15] = { name = "PAVING_SLAB", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [16] = { name = "SANDSTONE_SOLID", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 16.0 },
    [17] = { name = "SANDSTONE_BRITTLE", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 16.0 },
    [18] = { name = "SAND_LOOSE", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.115, wetGrip = -0.05, topSpeedMulti = 0.7, dominantFrequency = 16.0 },
    [19] = { name = "SAND_COMPACT", group = "LOOSE_TERRAIN", friction = 0.8, drag = 0.08, wetGrip = 0.05, topSpeedMulti = 0.7, dominantFrequency = 16.0 },
    [20] = { name = "SAND_WET", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.13, wetGrip = 0.05, topSpeedMulti = 0.6, dominantFrequency = 16.0 },
    [21] = { name = "SAND_TRACK", group = "LOOSE_TERRAIN", friction = 0.9, drag = 0.06, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 16.0 },
    [22] = { name = "SAND_UNDERWATER", group = "LOOSE_TERRAIN", friction = 0.9, drag = 0.06, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 0.0 },
    [23] = { name = "SAND_DRY_DEEP", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.115, wetGrip = -0.05, topSpeedMulti = 0.7, dominantFrequency = 16.0 },
    [24] = { name = "SAND_WET_DEEP", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.13, wetGrip = 0.05, topSpeedMulti = 0.6, dominantFrequency = 16.0 },
    [25] = { name = "ICE", group = "LOOSE_TERRAIN", friction = 0.45, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 0.0 },
    [26] = { name = "ICE_TARMAC", group = "HARD_TERRAIN", friction = 0.65, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 0.0 },
    [27] = { name = "SNOW_LOOSE", group = "LOOSE_TERRAIN", friction = 0.4, drag = 0.06, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 20.0 },
    [28] = { name = "SNOW_COMPACT", group = "LOOSE_TERRAIN", friction = 0.65, drag = 0.02, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 20.0 },
    [29] = { name = "SNOW_DEEP", group = "LOOSE_TERRAIN", friction = 0.4, drag = 0.15, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 20.0 },
    [30] = { name = "SNOW_TARMAC", group = "HARD_TERRAIN", friction = 1.0, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 20.0 },
    [31] = { name = "GRAVEL_SMALL", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.04, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 12.0 },
    [32] = { name = "GRAVEL_LARGE", group = "LOOSE_TERRAIN", friction = 0.85, drag = 0.06, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 12.0 },
    [33] = { name = "GRAVEL_DEEP", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.04, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 12.0 },
    [34] = { name = "GRAVEL_TRAIN_TRACK", group = "LOOSE_TERRAIN", friction = 0.75, drag = 0.04, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 12.0 },
    [35] = { name = "DIRT_TRACK", group = "LOOSE_TERRAIN", friction = 0.9, drag = 0.03, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 14.0 },
    [36] = { name = "MUD_HARD", group = "LOOSE_TERRAIN", friction = 0.9, drag = 0.02, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 14.0 },
    [37] = { name = "MUD_POTHOLE", group = "LOOSE_TERRAIN", friction = 0.9, drag = 0.05, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 14.0 },
    [38] = { name = "MUD_SOFT", group = "LOOSE_TERRAIN", friction = 0.7, drag = 0.07, wetGrip = -0.1, topSpeedMulti = 0.6, dominantFrequency = 14.0 },
    [39] = { name = "MUD_UNDERWATER", group = "LOOSE_TERRAIN", friction = 0.7, drag = 0.06, wetGrip = -0.1, topSpeedMulti = 0.8, dominantFrequency = 14.0 },
    [40] = { name = "MUD_DEEP", group = "LOOSE_TERRAIN", friction = 0.7, drag = 0.1, wetGrip = -0.1, topSpeedMulti = 0.6, dominantFrequency = 14.0 },
    [41] = { name = "MARSH", group = "LOOSE_TERRAIN", friction = 0.7, drag = 0.07, wetGrip = -0.1, topSpeedMulti = 0.6, dominantFrequency = 14.0 },
    [78] = { name = "RUMBLE_STRIP", group = "WOODS", friction = 0.8, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 18.0 },
    [79] = { name = "WOOD_HIGH_DENSITY", group = "WOODS", friction = 0.8, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 18.0 },
    [80] = { name = "WOOD_LATTICE", group = "WOODS", friction = 0.8, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 18.0 },
    [81] = { name = "CERAMIC", group = "MANMADE", friction = 0.9, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [82] = { name = "ROOF_TILE", group = "MANMADE", friction = 0.9, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [83] = { name = "ROOF_FELT", group = "MANMADE", friction = 0.8, drag = 0.0, wetGrip = 0.0, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [84] = { name = "FIBREGLASS", group = "MANMADE", friction = 0.9, drag = 0.0, wetGrip = -0.12, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [85] = { name = "TARPAULIN", group = "MANMADE", friction = 0.8, drag = 0.0, wetGrip = -0.12, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [86] = { name = "PLASTIC", group = "MANMADE", friction = 0.8, drag = 0.0, wetGrip = -0.12, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [87] = { name = "PLASTIC_HOLLOW", group = "MANMADE", friction = 0.85, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [88] = { name = "PLASTIC_HIGH_DENSITY", group = "MANMADE", friction = 0.8, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [89] = { name = "PLASTIC_CLEAR", group = "MANMADE", friction = 0.8, drag = 0.0, wetGrip = -0.12, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [90] = { name = "PLASTIC_HOLLOW_CLEAR", group = "MANMADE", friction = 0.85, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [91] = { name = "PLASTIC_HIGH_DENSITY_CLE", group = "MANMADE", friction = 0.8, drag = 0.0, wetGrip = -0.15, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
    [92] = { name = "FIBREGLASS_HOLLOW", group = "MANMADE", friction = 0.9, drag = 0.0, wetGrip = -0.1, topSpeedMulti = 1.0, dominantFrequency = 0.0 },
}

