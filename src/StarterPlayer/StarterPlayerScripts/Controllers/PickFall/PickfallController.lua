local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local PickfallFolder = Remotes:WaitForChild("PickFall")
local JoinEvent      = PickfallFolder:WaitForChild("PickfallJoin")
local StateEvent     = PickfallFolder:WaitForChild("PickfallState")
local WinnerEvent    = PickfallFolder:WaitForChild("PickfallWinner")

local PickfallController = {}

local guiFolder = player:WaitForChild("PlayerGui"):WaitForChild("PickFall")

local gui       = guiFolder:WaitForChild("PickfallGui")
local registerFrame = gui:WaitForChild("Register")
local joinButton = registerFrame:WaitForChild("JoinButton")
local countdownLabel = registerFrame:WaitForChild("CountDown")
local selectMode = gui:WaitForChild("SelectMode")
local mode1Button = selectMode:WaitForChild("Mode1")
local mode2Button = selectMode:WaitForChild("Mode2")

local DEFAULT_JOIN_TEXT = joinButton.Text


local joined = false

local function formatTime(t)
local m = math.floor(t / 60)
local s = math.floor(t % 60)
return string.format("%02d:%02d", m, s)

end

function PickfallController.init()
selectMode.Visible = false
local function sendJoin(mode)
if joined then
return
end
JoinEvent:FireServer(mode)
joined = true
joinButton.Text = "Registrado"
joinButton.AutoButtonColor = false
joinButton.Active = false
selectMode.Visible = false
end

if joinButton then
joinButton.MouseButton1Click:Connect(function()
if joined then
return
end
selectMode.Visible = true
end)
else
warn("[PickfallController] Join button not found")
end

mode1Button.MouseButton1Click:Connect(function()
sendJoin(1)
end)
mode2Button.MouseButton1Click:Connect(function()
sendJoin(2)
end)

StateEvent.OnClientEvent:Connect(function(state, data)
if state == "idle" then
if countdownLabel then
countdownLabel.Text = "00:00"
end
joined = false
selectMode.Visible = false
if joinButton then
joinButton.Text = DEFAULT_JOIN_TEXT
joinButton.AutoButtonColor = true
joinButton.Active = true
joinButton.Visible = false
end
if registerFrame then
        registerFrame.Visible = false
end
elseif state == "countdown" then
local t = tonumber(data) or 0
if countdownLabel then
countdownLabel.Text = formatTime(t)
end
selectMode.Visible = false
if joinButton then
joinButton.Visible = true
end
if registerFrame then
        registerFrame.Visible = true
end
elseif state == "running" then
if countdownLabel then
countdownLabel.Text = "Evento en progreso"
end
selectMode.Visible = false
if joinButton then
joinButton.Visible = false
end
if registerFrame then
        registerFrame.Visible = false
end
end
end)

WinnerEvent.OnClientEvent:Connect(function(name)
if countdownLabel then
if name and name ~= "" then
countdownLabel.Text = name .. " ganó!"
else
countdownLabel.Text = "Sin ganador"
end
end
joined = false
selectMode.Visible = false
if joinButton then
joinButton.Text = DEFAULT_JOIN_TEXT
joinButton.AutoButtonColor = true
joinButton.Active = true
joinButton.Visible = true
end
if registerFrame then
        registerFrame.Visible = true
end
end)
end

return PickfallController

