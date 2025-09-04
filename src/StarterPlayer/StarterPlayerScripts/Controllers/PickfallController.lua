-- StarterPlayerScripts/Controllers/PickfallController.lua
-- v1.0: Maneja GUI y eventos remotos del minijuego Pickfall

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
local joinButton = gui:FindFirstChild("JoinButton") or gui:FindFirstChild("Inscribirse") or gui:FindFirstChildWhichIsA("TextButton")
local stateLabel = gui:FindFirstChild("StateText") or gui:FindFirstChild("StatusLabel") or gui:FindFirstChildWhichIsA("TextLabel")
local container = joinButton and joinButton.Parent or gui:FindFirstChildWhichIsA("Frame")


local joined = false


function PickfallController.init()
        if joinButton then
                joinButton.MouseButton1Click:Connect(function()
                        JoinEvent:FireServer()
                        joined = true
                        joinButton.Visible = false
                        if container then container.Visible = false end
                end)
        end

        StateEvent.OnClientEvent:Connect(function(state, data)
                if stateLabel then
                        if state == "idle" then
                                stateLabel.Text = "Evento inactivo"
                                joined = false
                                if joinButton then joinButton.Visible = true end
                        elseif state == "countdown" then
                                local t = tonumber(data) or 0
                                local m = math.floor(t/60)
                                local s = t%60
                                stateLabel.Text = string.format("Pickfall empieza en %02d:%02d!", m, s)
                                if joinButton then joinButton.Visible = not joined end
                        elseif state == "running" then
                                stateLabel.Text = "Evento en progreso"
                                if joinButton then joinButton.Visible = false end
                        end
                end
                if container then

                        container.Visible = state ~= "running"

                end
        end)

        WinnerEvent.OnClientEvent:Connect(function(name)
                if stateLabel then
                        if name and name ~= "" then
                                stateLabel.Text = name .. " ganó!"
                        else
                                stateLabel.Text = "Sin ganador"
                        end
                end
                joined = false
                if joinButton then
                        joinButton.Visible = true
                end
                if container then
                        container.Visible = true
                end
        end)
end

return PickfallController
