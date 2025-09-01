-- Modules/TextScaler.lua
-- Ajusta dinámicamente el tamaño del texto según la resolución de pantalla

local TextScaler = {}

local referenceResolution = Vector2.new(1920, 1080)
local referenceTextSize = 30

function TextScaler.attach(textLabel, screenGui)
    screenGui = screenGui or textLabel:FindFirstAncestorWhichIsA("ScreenGui")
    if not screenGui then return end

    local function updateTextSize()
        local currentSize = screenGui.AbsoluteSize
        local scaleFactor = math.min(currentSize.X / referenceResolution.X, currentSize.Y / referenceResolution.Y)
        local newTextSize = math.max(9, referenceTextSize * scaleFactor)
        textLabel.TextSize = newTextSize
    end

    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTextSize)
    updateTextSize()
end

return TextScaler

