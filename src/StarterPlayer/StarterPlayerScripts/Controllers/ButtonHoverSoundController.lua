local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local BUTTON_NAMES = {
    "AutoMineButton",
    "OpenShopButton",
    "TPPlotButton",
    "TPShopsButton",
}

local HoverSoundController = {}
local connectedButtons = {}

local function resolveHoverTemplate()
    local function findTick(root)
        if not root then
            return nil
        end
        return root:FindFirstChild("tick2") or root:FindFirstChild("tick")
    end

    local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
    local template = findTick(soundsFolder)
    if template then
        return template
    end
    return findTick(ReplicatedStorage)
end

local hoverSoundTemplate = resolveHoverTemplate()

local function playHoverSound()
    if not hoverSoundTemplate then
        return
    end
    local sound = hoverSoundTemplate:Clone()
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 2)
end

local function connectHoverSound(button)
    if connectedButtons[button] then
        return
    end
    connectedButtons[button] = true

    button.AncestryChanged:Connect(function(_, parent)
        if not parent then
            connectedButtons[button] = nil
        end
    end)

    button.MouseEnter:Connect(playHoverSound)
end

function HoverSoundController:init()
    local player = Players.LocalPlayer
    if not player then
        return
    end
    local playerGui = player:WaitForChild("PlayerGui")
    local mainGui = playerGui:FindFirstChild("MainGui") or playerGui:WaitForChild("MainGui", 5)
    if not mainGui then
        warn("[HoverSoundController] No se encontro MainGui en PlayerGui")
        return
    end

    if not hoverSoundTemplate then
        warn("[HoverSoundController] No se encontro el sonido 'tick2' en ReplicatedStorage")
    end

    for _, name in ipairs(BUTTON_NAMES) do
        local button = mainGui:FindFirstChild(name) or mainGui:WaitForChild(name, 5)
        if button and button:IsA("GuiButton") then
            connectHoverSound(button)
        else
            warn(("[HoverSoundController] No se encontro boton %s o no es GuiButton"):format(name))
        end
    end
end

return HoverSoundController
