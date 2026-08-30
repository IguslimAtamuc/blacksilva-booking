let currentGear;
let currentUnit;
let currentMaxRpm;
let redZoneStart;
let isInRedzone = false;
let hasHiddenRedzoneBar = false;
let isMotorcycle;
let tireOptRangeMin;
let tireOptRangeMax;
let tireHeatRange;
let isTcsShow;
let isEscShow;
let isNosBarShow;
let rpmTickQuery;
let speedQuery;
let speedUnitQuery;
let gearQuery;
let progressBarQuery;
let nitrousBarQuery;
let nitrousBarBgQuery;
let redzoneBarQuery;
let tireGridQuery;
let tireOutlineQuery;
let tireHeat1Query;
let tireHeat2Query;
let tireHeat3Query;
let tireHeat4Query;
let circleQuery;
let tcsBoxQuery;
let tcsOutlineQuery;
let tcsTextQuery;
let escBoxQuery;
let escOutlineQuery;
let escTextQuery;
let fuelWidgetQuery, fuelBarFillQuery;

function cacheQuerys() {
    rpmTickQuery = document.querySelector('.rpm-ticks');
    speedQuery = document.querySelector('.circle-content .speed');
    speedUnitQuery = document.querySelector('.circle-content .unit');
    gearQuery = document.querySelector('.circle-content .gear');
    progressBarQuery = document.querySelector('.bar-progress');
    nitrousBarQuery = document.querySelector('.bar-nitrous');
    nitrousBarBgQuery = document.querySelector('.bar-nitrous-bg');
    redzoneBarQuery = document.querySelector('.bar-progress-redzone');
    circleQuery = document.querySelector('.circle');
    tireGridQuery = document.querySelector('.tire-grid');
    tireOutlineQuery = document.querySelector('.tire-outline');
    tireHeat1Query = document.querySelector('.tire-1 .tire-heat');
    tireHeat2Query = document.querySelector('.tire-2 .tire-heat');
    tireHeat3Query = document.querySelector('.tire-3 .tire-heat');
    tireHeat4Query = document.querySelector('.tire-4 .tire-heat');
    tcsBoxQuery = document.querySelector('.circle-content .tcs-box');
    tcsOutlineQuery = document.querySelector('.tcs-outline');
    tcsTextQuery = document.querySelector('.tcs-box text');
    escBoxQuery = document.querySelector('.circle-content .esc-box');
    escOutlineQuery = document.querySelector('.esc-outline');
    escTextQuery = document.querySelector('.esc-box text');
    fuelWidgetQuery = document.getElementById('fuelWidget');
    fuelBarFillQuery = document.getElementById('fuelBarFill');
}

function setPosition(selector, xPercent, yPercent) {
    const element = document.querySelector(selector);
    if (element) {
        element.style.left = `${xPercent * 100}%`;
        element.style.top = `${yPercent * 100}%`;
    }
}

function setSize(selector, sizeVmin) {
    const element = document.querySelector(selector);
    if (element) {
        element.style.width = `${sizeVmin}vmin`;
        element.style.height = `${sizeVmin}vmin`;
    }
}

function generateSpeedometer(maxRPM, startAngle = 33.75, endAngle = 326.25) {
    const svgNamespace = "http://www.w3.org/2000/svg";
    const rpmTicks = rpmTickQuery;
    if (!rpmTicks) return;

    startAngle += 180; // offset to 6 o'clock
    endAngle += 180;

    rpmTicks.innerHTML = ''; // Clear existing ticks

    const segments = maxRPM + 1;
    const degreesPerSegment = (endAngle - startAngle) / maxRPM;

    // Get SVG size dynamically from the viewBox
    const viewBox = rpmTicks.ownerSVGElement.viewBox.baseVal;
    const svgSize = Math.min(viewBox.width, viewBox.height);

    const center = svgSize / 2;
    const radius = svgSize * 0.4725; // 47.25% of SVG size
    const tickSize = radius * 0.1;  // Major tick size
    const textOffset = radius * 0.175; // Distance for numbers from the center
    const fontSize = svgSize * 0.05; 

    for (let i = 0; i <= maxRPM; i++) {
        const angle = startAngle + i * degreesPerSegment;
        const angleRad = ((angle - 90) * Math.PI) / 180;

        // Tick positions
        const tickX1 = center + radius * Math.cos(angleRad);
        const tickY1 = center + radius * Math.sin(angleRad);
        const tickX2 = center + (radius - tickSize) * Math.cos(angleRad);
        const tickY2 = center + (radius - tickSize) * Math.sin(angleRad);

        const tick = document.createElementNS(svgNamespace, 'line');
        tick.setAttribute('x1', tickX1);
        tick.setAttribute('y1', tickY1);
        tick.setAttribute('x2', tickX2);
        tick.setAttribute('y2', tickY2);
        tick.setAttribute('stroke', "rgba(225,225,225,1.0)");
        tick.setAttribute('stroke-width', svgSize * 0.005); // scales with size
        rpmTicks.appendChild(tick);

        // Number positions
        const textX = center + (radius - textOffset) * Math.cos(angleRad);
        const textY = center + (radius - textOffset) * Math.sin(angleRad);

        const number = document.createElementNS(svgNamespace, 'text');
        number.setAttribute('x', textX);
        number.setAttribute('y', textY);
        number.setAttribute('font-size', `${fontSize}px`);
        number.setAttribute('text-anchor', 'middle');
        number.setAttribute('dominant-baseline', 'middle');
        number.setAttribute('fill', "rgba(185,185,185,1.0)");

        // Keep text upright
        number.setAttribute('transform', `rotate(0, ${textX}, ${textY})`);

        number.textContent = i.toString();
        rpmTicks.appendChild(number);
    }
}

function setSpeed(speed) {
    const speedElement = speedQuery;
    if (speedElement) {
        speedElement.textContent = speed;
    }
}

function setSpeedUnit(unit) {
    const unitElement = speedUnitQuery;
    if (unitElement) {
        unitElement.textContent = unit;
    }
}

function setGear(gear) {
    const gearElement = gearQuery;
    if (gearElement) {
        gearElement.textContent = gear > 0 ? gear : "R";
    }
}

function setStaticBar(selector, startAngle = 33.75, endAngle = 326.25) {
    const circle = document.querySelector(selector);
    if (!circle) {
        console.warn(`Element '${selector}' not found!`);
        return;
    }

    const radius = circle.r.baseVal.value;
    const circumference = 2 * Math.PI * radius;

    // Calculate stroke offset to align perfectly
    const angleRange = (endAngle - startAngle) / 360;
    const offset = circumference * (1 - angleRange);

    // Apply stroke properties
    circle.style.strokeDasharray = circumference;
    circle.style.strokeDashoffset = offset;

    // Rotate to align the start correctly
    circle.style.transform = `rotate(${startAngle + 90}deg)`;
    circle.style.transformOrigin = '50% 50%';
}

function setRedlineBar(selector, startAngle = 280, endAngle = 326.25) {
    const circle = document.querySelector(selector);
    if (!circle) {
        console.warn(`Element '${selector}' not found!`);
        return;
    }

    const radius = circle.r.baseVal.value;
    const circumference = 2 * Math.PI * radius;

    // Calculate stroke offset
    const angleRange = (endAngle - startAngle) / 360;
    const offset = circumference * (1 - angleRange);

    // Apply stroke properties
    circle.style.strokeDasharray = circumference;
    circle.style.strokeDashoffset = offset;

    // Rotate to align properly
    circle.style.transform = `rotate(${startAngle + 90}deg)`;
    circle.style.transformOrigin = '50% 50%';
}

function setNitrousBar(selector, startAngle = 33.75, endAngle = 326.25) {
    const circle = document.querySelector(selector);
    if (!circle) {
        console.warn(`Element '${selector}' not found!`);
        return;
    }

    const radius = circle.r.baseVal.value;
    const circumference = 2 * Math.PI * radius;

    // Calculate stroke offset to align perfectly
    const angleRange = (endAngle - startAngle) / 360;
    const offset = circumference * (1 - angleRange);

    // Apply stroke properties
    circle.style.strokeDasharray = circumference;
    circle.style.strokeDashoffset = offset;

    // Rotate to align the start correctly
    circle.style.transform = `rotate(${startAngle + 90}deg)`;
    circle.style.transformOrigin = '50% 50%';
}

function setProgressBar(selector, progress, startAngle = 33.75, endAngle = 326.25) {
    let usedCachedQuery;

    switch (selector) {
        case '.bar-progress':
            usedCachedQuery = progressBarQuery;
            break;
        case '.bar-progress-redzone':
            usedCachedQuery = redzoneBarQuery;
            break;
        case '.bar-nitrous':
            usedCachedQuery = nitrousBarQuery;
            break;
    }
    const circle = usedCachedQuery;
    if (!circle) {
        console.warn(`Element '${selector}' not found!`);
        return;
    }

    const radius = circle.r.baseVal.value;
    const circumference = 2 * Math.PI * radius;

    const angleRange = (endAngle - startAngle) / 360;
    const progressOffset = circumference * (1 - (progress / 100) * angleRange);

    // Apply stroke properties
    circle.style.strokeDasharray = circumference;
    circle.style.strokeDashoffset = progressOffset;

    // Rotate to align the start
    circle.style.transform = `rotate(${startAngle + 90}deg)`;
    circle.style.transformOrigin = '50% 50%';
}

function mapClamped(value, inMin, inMax, outMin, outMax) {
    const mappedValue = (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
    return Math.min(Math.max(mappedValue, outMin), outMax);
}

function mapCommon(value, inMin, inMax, outMin, outMax) {
    const mappedValue = (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
    return mappedValue;
}

function startSpeedometer(xPos, yPos, scale, maxRPM) {
    // Convert percentage scale (0-100) to decimal (0-1)
    const scaleMultiplier = scale / 100;
    setPosition('.circle', xPos, yPos);
    const baseSize = 20; // Base size in vmin
    const scaledSize = baseSize * scaleMultiplier;
    setSize('.circle', scaledSize);

    currentMaxRpm = maxRPM;
    const rpm = Math.round((maxRPM / 1000)) + 1;
    setStaticBar('.bar-bg', 33.75, 326.25);
    setNitrousBar('.bar-nitrous-bg', 89.5, 180.5);
    const degreesPerSegment = 292.5 / (rpm + 1);
    redZoneStart = 290.25 - degreesPerSegment;
    setRedlineBar('.bar-bg-redline', redZoneStart, 326.25);
    generateSpeedometer(rpm, 33.75, 326.25);
}



function updateSpeedometer(rpm, speed, speedUnit, gear,nitrousPercent) {
    if (currentUnit !== speedUnit) {
        setSpeedUnit(speedUnit);
    }
    if (currentGear !== gear) {
        const usedGear = (gear > 0) ? gear : "R";
        setGear(usedGear);
    }

    const rpmTrack = Math.max(0, mapClamped(rpm, 0.2, 1.0, 1000, currentMaxRpm));
    const maxRpmHud = (Math.round((currentMaxRpm / 1000)) + 1) * 1000;
    const progress = mapClamped(rpmTrack, 1000, maxRpmHud, 11, 100);
    const redZoneProgress = (((redZoneStart - 33.75 + 360) % 360) / ((326.25 - 33.75 + 360) % 360)) * 100;

    if (progress < redZoneProgress) {
        setProgressBar('.bar-progress', progress, 33.75, 326.25);
        isInRedzone = false;
        if (!isInRedzone && !hasHiddenRedzoneBar) {
            document.querySelector('.bar-progress-redzone').style.display = 'none';
            const gearElement = document.querySelector('.circle-content .gear');
            if (gearElement) gearElement.style.color = 'white';
            hasHiddenRedzoneBar = true;
        }
    } else {
        isInRedzone = true;
        if (isInRedzone && hasHiddenRedzoneBar) {
            setProgressBar('.bar-progress', redZoneProgress, 33.75, 326.25);
            document.querySelector('.bar-progress-redzone').style.display = 'block';
            const gearElement = document.querySelector('.circle-content .gear');
            if (gearElement) gearElement.style.color = 'rgba(255, 0, 0, 1.0)';
            hasHiddenRedzoneBar = false;
        }
        setProgressBar('.bar-progress-redzone', progress, 33.75, 326.25);
    }
    
    setProgressBar('.bar-nitrous', (nitrousPercent*100), 90, 180);

    let usedSpeed = (speedUnit === "mph") ? Math.round(speed * 2.23694) : Math.round(speed * 3.6);
    setSpeed(usedSpeed);
}

function setGridScale(scalePercent) {
    const grid = tireGridQuery;
    if (grid) {
        grid.style.transform = `translate(-50%, -50%) scale(${scalePercent})`;
    }
}

function setGridPosition(posX, posY) {
    const grid = tireGridQuery;
    if (grid) {
        grid.style.top = `${posY * 100}%`;
        grid.style.left = `${posX * 100}%`;
    }
}

function setTireHeat(selector, temperature) {
    let usedCachedQueryTire;

    switch (selector) {
        case '.tire-1 .tire-heat':
            usedCachedQueryTire = tireHeat1Query;
            break;
        case '.tire-2 .tire-heat':
            usedCachedQueryTire = tireHeat2Query;
            break;
        case '.tire-3 .tire-heat':
            usedCachedQueryTire = tireHeat3Query;
            break;
        case '.tire-4 .tire-heat':
            usedCachedQueryTire = tireHeat4Query;
            break;
    }

    const tireHeat = usedCachedQueryTire;
    const tireOutline = tireOutlineQuery;

    // Adjust Tire Heat Dimensions Based on Outline Stroke Width
    const strokeWidth = parseFloat(window.getComputedStyle(tireOutline).strokeWidth);
    const inset = strokeWidth / 2;

    tireHeat.setAttribute('x', 10 + inset);
    tireHeat.setAttribute('y', 10 + inset);
    tireHeat.setAttribute('width', 180 - inset * 2);
    tireHeat.setAttribute('height', 380 - inset * 2);
    tireHeat.setAttribute('rx', 40 - inset);
    tireHeat.setAttribute('ry', 40 - inset);

    // Temperature to Color and Opacity Mapping
    let hue, opacity;

    if (temperature <= 25) {
        hue = 240; // Blue
        opacity = 0.5;
    } else if (temperature > 25 && temperature <= tireOptRangeMin) {
        hue = lerp(temperature, 25, 70, 240, 120); // Blue → Green
        opacity = lerp(temperature, 25, 70, 0.5, 0.5);
    } else if (temperature > tireOptRangeMin && temperature <= tireOptRangeMax) {
        hue = 120; // Stable Green
        opacity = 0.5;
    } else if (temperature > tireOptRangeMax && temperature <= tireHeatRange) {
        hue = lerp(temperature, 90, 160, 120, 0); // Green → Red
        opacity = lerp(temperature, 90, 160, 0.5, 0.5);
    } else {
        hue = 0; // Hot Red
        opacity = 0.5;
    }

    const color = `hsla(${hue}, 100%, 50%, ${opacity})`;
    tireHeat.style.fill = color;
}

function lerp(value, inMin, inMax, outMin, outMax) {
    return ((value - inMin) / (inMax - inMin)) * (outMax - outMin) + outMin;
}

function startTireGrid(optMin, optMax, heat, xPos, yPos, scale) {
    // Convert percentage scale (0-100) to decimal (0-1) for tire grid
    const scaleMultiplier = scale / 100;
    setGridScale(scaleMultiplier);
    setGridPosition(xPos, yPos);
    tireOptRangeMin = optMin;
    tireOptRangeMax = optMax;
    tireHeatRange = heat;
}

function handleHideShow(speedoHide, tireHide, fuelHide) {
    const speedoElement = circleQuery;
    const tireGridElement = tireGridQuery;
    const fuelElement = fuelWidgetQuery;

    if (speedoElement) {
        speedoElement.style.visibility = speedoHide ? 'visible' : 'hidden';
        if (speedoHide == false) {
            handleNitrous(false);
        }
        
    }

    if (tireGridElement) {
        tireGridElement.style.visibility = tireHide ? 'visible' : 'hidden';
    }

    if (fuelElement) {
        fuelElement.style.visibility = fuelHide ? 'visible' : 'hidden';
    }
}

function handleAssists(tcsActive, escActive, tcsAllowed, escAllowed) {
    const tcsBox = tcsBoxQuery;
    const escBox = escBoxQuery;
    const tcsOutline = tcsOutlineQuery;
    const escOutline = escOutlineQuery;
    const tcsText = tcsTextQuery;
    const escText = escTextQuery;

    if (escAllowed !== isEscShow) {
        isEscShow = escAllowed;
        if (escBox) escBox.style.visibility = isEscShow ? 'visible' : 'hidden';
    }
    if (tcsAllowed !== isTcsShow) {
        isTcsShow = tcsAllowed;
        if (tcsBox) tcsBox.style.visibility = isTcsShow ? 'visible' : 'hidden';
    }

    if (isTcsShow && !isEscShow) {
        if (tcsBox) tcsBox.style.left = '50.0%';
    } else if (isEscShow && !isTcsShow) {
        if (escBox) escBox.style.left = '50.0%';
    } else if (isEscShow && isTcsShow) {
        if (escBox && escBox.style.left === '50%') {
            escBox.style.left = '40.625%';
        } else if (tcsBox && tcsBox.style.left === '50%') {
            tcsBox.style.left = '59.375%';
        }
    }

    const tscColor = tcsActive ? 'white' : 'rgba(255, 255, 255, 0.1)';
    const escColor = escActive ? 'white' : 'rgba(255, 255, 255, 0.1)';
    const currentTscColor = tcsOutline ? tcsOutline.style.stroke : '';
    const currentEscColor = escOutline ? escOutline.style.stroke : '';

    if (tcsOutline && tscColor !== currentTscColor) {
        tcsOutline.style.stroke = tscColor;
        if (tcsText) tcsText.style.fill = tscColor;
    }
    if (escOutline && escColor !== currentEscColor) {
        escOutline.style.stroke = escColor;
        if (escText) escText.style.fill = escColor;
    }
}

function handleNitrous(nitrousAllowed) {
    const nosProgress = nitrousBarQuery;
    const nosProgressBg = nitrousBarBgQuery;

    if (nitrousAllowed !== isNosBarShow) {
        isNosBarShow = nitrousAllowed;
        if (nosProgress) nosProgress.style.visibility = isNosBarShow ? 'visible' : 'hidden';
        if (nosProgressBg) nosProgressBg.style.visibility = isNosBarShow ? 'visible' : 'hidden';
    }
}

function setMotorcycleMode(isMotorcycle) {
    if (!tireGridQuery) return;
  
    if (isMotorcycle) {
      tireGridQuery.classList.add('motorcycle');
  
      // Hide rear tires
      document.querySelector('.tire-3')?.parentElement?.classList.add('hidden');
      document.querySelector('.tire-4')?.parentElement?.classList.add('hidden');
    } else {
      tireGridQuery.classList.remove('motorcycle');
  
      // Show all tires again
      document.querySelector('.tire-3')?.parentElement?.classList.remove('hidden');
      document.querySelector('.tire-4')?.parentElement?.classList.remove('hidden');
    }
  }

// Set fuel bar position (% of screen)
function setFuelWidgetPosition(xPercent, yPercent) {
    if (!fuelWidgetQuery) return;
    fuelWidgetQuery.style.left = `${xPercent*100}%`;
    fuelWidgetQuery.style.top = `${yPercent*100}%`;
}

// Set overall fuel widget scale
function setFuelWidgetScale(scale) {
    if (!fuelWidgetQuery) return;
    fuelWidgetQuery.style.transform = `scale(${scale})`;
}

// Set fuel level (0.0–1.0)
function updateFuelLevel(level) {
    if (!fuelBarFillQuery) return;
    const clamped = Math.max(0, Math.min(1, level));
    fuelBarFillQuery.style.height = `${clamped * 100}%`;
}

function startFuelWidget(xPos, yPos, scale) {
    setFuelWidgetPosition(xPos,yPos);
    setFuelWidgetScale(scale); 
}

  
cacheQuerys();

window.addEventListener('message', function(event) {
    const data = event.data;
    const action = data.action;

    switch (action) {
        case 'start':
            startSpeedometer(data.xPosSpeedo, data.yPosSpeedo, data.scaleSpeedo, data.maxRpm);
            startTireGrid(data.tireOptMin, data.tireOptMax, data.tireHeat, data.xPosTire, data.yPosTire, data.scaleTire);
            startFuelWidget(data.xPosFuel, data.yPosFuel, data.scaleFuel)
            setMotorcycleMode(data.isMotorcycle);
            break;
        case 'update':
            updateSpeedometer(data.rpm, data.speedMs, data.speedUnit, data.gear,data.nitrousAmmount);
            updateFuelLevel(data.fuelLevel)
            handleAssists(data.tcs, data.esc, data.tcsAllow, data.escAllow);
            handleNitrous(data.canUseNitrous);
            if (data.isMotorcycle == 1 ) {
                setTireHeat('.tire-1 .tire-heat', data.frTemp);
                setTireHeat('.tire-2 .tire-heat', data.flTemp);
            } else {
                setTireHeat('.tire-1 .tire-heat', data.flTemp);
                setTireHeat('.tire-2 .tire-heat', data.frTemp);
                setTireHeat('.tire-3 .tire-heat', data.rlTemp);
                setTireHeat('.tire-4 .tire-heat', data.rrTemp);
            }
            break;
        case 'hideshow':
            handleHideShow(data.speedoShow, data.tireShow, data.fuelShow);
            break;
    }
});
