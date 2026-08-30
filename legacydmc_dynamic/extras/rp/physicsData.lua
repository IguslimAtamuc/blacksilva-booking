physicsSettings ={  
    steeringData ={
        steeringRateGamepad = 6.5,
        steeringReturnRateGamepad = 8.5,
        steeringGammaGamepad = 1.33,
        steeringRateKeyboard = 7.0,
        steeringReturnRateKeyboard = 9.0,
        steeringGammaKeyboard = 1.0, 
        counterSteerRate = 0.025, 
        counterSteerMaxAngle = 15.0, 
        steeringReductionMulti = 0.85,
        allowMouseSteering = true,
        mouseSteeringSensitivity = 0.5,
        allowSteeringAssistOnMouseSteer = true,
        useAckermannSteeringCorrection = true,
    },
    assistsData = {
        enableAssistsByDefault = true,
        tcsIntensity = 3.5,
        escThresholdMultiplier = 0.66,
    },
    tunableData = {
        downforceGripGainCoeff = 0.025,
        linearDampeningCoefficient = 0.01,
        angularDampeningCoefficient = 0.02,
    },
    transmissionData = {
        simulateTransmissionLugging = true,
        enableWheelies = false
    },
    netSyncData = {
        enableDriftSync = false, 
        enableBrakeSync = true, 
        netSyncDistance = 60.0, 
    },
    experienceData = {
        isArcadeExperience = false, 
        useChaseCamByDefault = false, 
        useCustomSteeringInput = true, 
        useDynamicKeybinds = true, 
        useInvertedAllowlistMode = true, 
        allowAutoCom = false, 
        allowAirControl = false, 
        forceDefaultTorqueGain = false, 
        defaultTorqueGainAmmount = 0.1, 
        brakeHeatGeneratorMultiplier = 2.0 
    },
    upgradeData = {
        enableVanillaTuningIntegration = true, 
        enginePowerMultiplierFactor = 0.2, 
        enginePowerMultiplier = {0.25,0.5,0.75,1.0}, 
                                                    
        brakesPowerMultiplierFactor = 0.1,
        brakesPowerMultiplier = {0.33,0.66,1.0}, 
        transmissionShiftTimeMultiplier = {0.875,0.75,0.5} 
    },
    optimizationData = {
        allowChaseCamRaycast = false, 
    }
}
