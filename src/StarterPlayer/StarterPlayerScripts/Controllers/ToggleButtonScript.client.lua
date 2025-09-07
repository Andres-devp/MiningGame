-- StarterPlayer/StarterPlayerScripts/Controllers/ToggleButtonScript.client.lua
-- v2.0 - Server-driven: moved out of AutoMineButton into controller

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local button = playerGui:WaitForChild("MainGui"):WaitForChild("AutoMineButton")
local gradient = button:FindFirstChildOfClass("UIGradient")

-- EventBus
local EventBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("events"):WaitForChild("EventBus"))
local Topics   = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("events"):WaitForChild("EventTopics"))

-- ⚠️ Mismo ID que en GamePassService
local AUTO_MINE_PASS_ID = 1406821381

-- ====== UI label único ======
local label = button:FindFirstChildOfClass("TextLabel")
if label then
    if button:IsA("TextButton") then button.Text = "" end
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.TextWrapped = true
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextStrokeTransparency = 0
    label.TextColor3 = Color3.new(1,1,1)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
else
    label = button :: TextButton
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextStrokeTransparency = 0
    label.TextColor3 = Color3.new(1,1,1)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
end

local COLOR_ON  = Color3.fromRGB(40, 167, 69)
local COLOR_OFF = Color3.fromRGB(220, 53, 69)
local COLOR_BUY = Color3.fromRGB(0, 123, 255)

local GRADIENT_ON  = ColorSequence.new(Color3.fromRGB(40,167,69), Color3.fromRGB(33,134,54))
local GRADIENT_OFF = ColorSequence.new(Color3.fromRGB(220,53,69), Color3.fromRGB(176,43,55))
local GRADIENT_BUY = ColorSequence.new(Color3.fromRGB(0,123,255), Color3.fromRGB(0,92,191))

-- Valores replicados (los crea el server)
local ownsAutoMinePass = player:WaitForChild("OwnsAutoMinePass")
local autoVal = player:FindFirstChild("AutoMineEnabled") or player:WaitForChild("AutoMineEnabled")

local function setText(t) label.Text = t end

local function updateButton()
    if ownsAutoMinePass.Value then
        if autoVal and autoVal.Value then
            setText("AUTO-MINADO: ON")
            button.BackgroundColor3 = COLOR_ON
            if gradient then gradient.Color = GRADIENT_ON end
        else
            setText("AUTO-MINADO: OFF")
            button.BackgroundColor3 = COLOR_OFF
            if gradient then gradient.Color = GRADIENT_OFF end
        end
    else
        setText("AUTO-MINADO")
        button.BackgroundColor3 = COLOR_BUY
        if gradient then gradient.Color = GRADIENT_BUY end
    end
end

local debounce = false
local function onActivated()
    if debounce then return end
    debounce = true
    task.delay(0.25, function() debounce = false end)

    if ownsAutoMinePass.Value then
        -- Pedimos togglear al servidor
        EventBus.sendToServer(Topics.AutoMineToggleRequest, {})
    else
        -- Solicitamos la compra (solo cliente puede mostrar prompt)
        MarketplaceService:PromptGamePassPurchase(player, AUTO_MINE_PASS_ID)
    end
end

button.Activated:Connect(onActivated)

-- Cuando finaliza un intento de compra, pedimos re-sync al server
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, success)
    if plr ~= player then return end
    if passId == AUTO_MINE_PASS_ID then
        -- El server re-verifica con UserOwnsGamePassAsync (nosotros no tocamos valores)
        EventBus.sendToServer(Topics.AutoMineSyncRequest, {})
    end
end)

-- Refresco UI ante cambios (server actualiza y replica)
ownsAutoMinePass.Changed:Connect(updateButton)
if autoVal then autoVal.Changed:Connect(updateButton) end

-- Sync inicial (por si el server aún no escribió)
EventBus.sendToServer(Topics.AutoMineSyncRequest, {})
updateButton()