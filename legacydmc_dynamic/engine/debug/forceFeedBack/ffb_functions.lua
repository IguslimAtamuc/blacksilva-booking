local graphBuffer = {}
local bufferSize = 300
local graphX = 0.5
local graphY = 0.5
local graphWidth = 0.5
local graphHeight = 0.5

for i = 1, bufferSize do
    graphBuffer[i] = 0
end

function AddValueToGraphBuffer(val)
    table.remove(graphBuffer, 1)
    table.insert(graphBuffer, val)
end

function DrawDebugGraph()
    DrawRect(graphX, graphY, graphWidth, graphHeight, 0, 0, 0, 100)
    DrawRect(graphX, graphY, graphWidth, 0.002, 255, 255, 255, 120)
    DrawRect(graphX, graphY, 0.002, graphHeight, 255, 255, 255, 120)

    for i = 1, bufferSize do
        local progress = (i - 1) / (bufferSize - 1)
        local val = math.max(-1, math.min(1, graphBuffer[i]))
        local posX = graphX + (progress - 0.5) * graphWidth
        local posY = graphY - (val * (graphHeight / 2))
        local barWidth = (graphWidth / bufferSize) * 2.5
        local barHeight = graphHeight * 0.03

        DrawRect(posX, posY, barWidth, barHeight, 255, 0, 0, 220)
    end
end

function drawText(text, x, y, scale)
    scale = scale or 0.5
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(255, 0, 0, 255)
    SetTextOutline()
    SetTextDropShadow(2, 2, 0, 0, 0, 255)
    SetTextEntry("STRING")
    SetTextCentre(false)
    AddTextComponentString(text)
    DrawText(x, y)
end

