

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
local container = gui:WaitForChild("Frame")
local joinButton = container:WaitForChild("JoinButton")
local countdownLabel = container:WaitForChild("CountDown")

local DEFAULT_JOIN_TEXT = joinButton.Text


local joined = false

local function formatTime(t)
        local m = math.floor(t/60)
        local s = math.floor(t%60)
        return string.format("%02d:%02d", m, s)

end

function PickfallController.init()
       print("[PickfallController] init")
       if joinButton then
               joinButton.MouseButton1Click:Connect(function()
                       if joined then return end
                       print("[PickfallController] Join button clicked")
                       JoinEvent:FireServer()
                       joined = true
                       joinButton.Text = "Registrado"
                       joinButton.AutoButtonColor = false
                       joinButton.Active = false
               end)
       else
               print("[PickfallController] Join button not found")
       end

       StateEvent.OnClientEvent:Connect(function(state, data)
               print("[PickfallController] StateEvent", state, data)
               if state == "idle" then

                       if countdownLabel then
                               countdownLabel.Text = "00:00"
                       end
                       joined = false
                       if joinButton then
                               joinButton.Text = DEFAULT_JOIN_TEXT
                               joinButton.AutoButtonColor = true
                               joinButton.Active = true
                               joinButton.Visible = true
                       end
               elseif state == "countdown" then
                       local t = tonumber(data) or 0
                       if countdownLabel then
                               countdownLabel.Text = formatTime(t)
                       end
                       if joinButton then joinButton.Visible = true end
               elseif state == "running" then

                       if countdownLabel then
                               countdownLabel.Text = "Evento en progreso"
                       end
                       if joinButton then joinButton.Visible = false end
               end
               if container then
                       container.Visible = state ~= "running"
               end
       end)

       WinnerEvent.OnClientEvent:Connect(function(name)
               print("[PickfallController] WinnerEvent", name)

               if countdownLabel then
                       if name and name ~= "" then
                               countdownLabel.Text = name .. " ganó!"
                       else
                               countdownLabel.Text = "Sin ganador"
                       end
               end
               joined = false
               if joinButton then
                       joinButton.Text = DEFAULT_JOIN_TEXT
                       joinButton.AutoButtonColor = true
                       joinButton.Active = true
                       joinButton.Visible = true
               end
               if container then
                       container.Visible = true
               end
       end)

end

return PickfallController
