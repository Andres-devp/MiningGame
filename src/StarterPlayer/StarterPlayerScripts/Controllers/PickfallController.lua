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

local guiFolder = player:WaitForChild("PlayerGui"):WaitForChild("Pickfall")
local gui       = guiFolder:WaitForChild("PickfallGui")
local joinButton = gui:FindFirstChild("JoinButton") or gui:FindFirstChild("Inscribirse") or gui:FindFirstChildWhichIsA("TextButton")
local stateLabel = gui:FindFirstChild("StateText") or gui:FindFirstChild("StatusLabel") or gui:FindFirstChildWhichIsA("TextLabel")

function PickfallController.init()
        if joinButton then
                joinButton.MouseButton1Click:Connect(function()
                        JoinEvent:FireServer()
                        joinButton.Visible = false
                end)
        end

        StateEvent.OnClientEvent:Connect(function(state, data)
                if stateLabel then
                        if state == "idle" then
                                stateLabel.Text = "Evento inactivo"
                                if joinButton then joinButton.Visible = true end
                        elseif state == "countdown" then
                                stateLabel.Text = string.format("Comienza en %ds", data or 0)
                                if joinButton then joinButton.Visible = false end
                        elseif state == "running" then
                                stateLabel.Text = "Evento en progreso"
                                if joinButton then joinButton.Visible = false end
                        end
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
                if joinButton then
                        joinButton.Visible = true
                end
        end)
end

return PickfallController
