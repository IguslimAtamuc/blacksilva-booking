tireConfig = { 
    ['Common'] = {
        peakTractionG = 2.0,
        lateralCurveAngle = 15.0,
        advancedSettings = {
            thermalConstants = {
                thermalMassK = 1127, 
                rollingResistanceK = 0.01938,
                slipFrictionK = 0.0208005, 
                dissipationK = 0.0707,
                speedDissipationK = 0.0001, 
            },
            frictionConstants = {
                maxTemp = 165,
                optRangeMin = 70, 
                optRangeMax = 90,
                muCold = 1.0, 
                muOpt = 1.025,
                muHot = 1.0, 
            }
        }
    },
    ['Street'] = {
        peakTractionG = 2.1,
        lateralCurveAngle = 14.0,
        advancedSettings = {
            thermalConstants = {
                thermalMassK = 1150, 
                rollingResistanceK = 0.01938, 
                slipFrictionK = 0.0208005, 
                dissipationK = 0.0707, 
                speedDissipationK = 0.0001, 
            },
            frictionConstants = {
                maxTemp = 165, 
                optRangeMin = 70, 
                optRangeMax = 90, 
                muCold = 1.0, 
                muOpt = 1.025, 
                muHot = 1.0, 
            }
        }
    },    
    ['Sport'] = {
        peakTractionG = 2.2,
        lateralCurveAngle = 13.3,
        advancedSettings = {
            thermalConstants = {
                thermalMassK = 1127, 
                rollingResistanceK = 0.01938,
                slipFrictionK = 0.0208005, 
                dissipationK = 0.0707,
                speedDissipationK = 0.0001, 
            },
            frictionConstants = {
                maxTemp = 165,
                optRangeMin = 70, 
                optRangeMax = 90,
                muCold = 0.9, 
                muOpt = 1.025,
                muHot = 0.7, 
            }
        }
    },
    ['Race'] = {
        peakTractionG = 2.4,
        lateralCurveAngle = 13.0,
        advancedSettings = {
            thermalConstants = {
                thermalMassK = 1127, 
                rollingResistanceK = 0.01938,
                slipFrictionK = 0.0208005, 
                dissipationK = 0.0707,
                speedDissipationK = 0.0001, 
            },
            frictionConstants = {
                maxTemp = 165,
                optRangeMin = 70, 
                optRangeMax = 90,
                muCold = 1.0, 
                muOpt = 1.025,
                muHot = 1.0, 
            }
        }
    },
    ['SemiSlick'] = {
        peakTractionG = 2.65,
        lateralCurveAngle = 12.635,
        advancedSettings = {
            thermalConstants = {
                thermalMassK = 1127, 
                rollingResistanceK = 0.01938,
                slipFrictionK = 0.0208005, 
                dissipationK = 0.0707,
                speedDissipationK = 0.0001, 
            },
            frictionConstants = {
                maxTemp = 165,
                optRangeMin = 70, 
                optRangeMax = 90,
                muCold = 1.0, 
                muOpt = 1.025,
                muHot = 1.0,  
            }
        }
    },
    ['Slick'] = {
        peakTractionG = 2.8,
        lateralCurveAngle = 10.3075,
        advancedSettings = {
            thermalConstants = {
                thermalMassK = 1127, 
                rollingResistanceK = 0.01938,
                slipFrictionK = 0.0208005, 
                dissipationK = 0.0707,
                speedDissipationK = 0.0001, 
            },
            frictionConstants = {
                maxTemp = 165,
                optRangeMin = 70, 
                optRangeMax = 90,
                muCold = 1.0, 
                muOpt = 1.025,
                muHot = 1.0, 
            }
        }
    },
}

