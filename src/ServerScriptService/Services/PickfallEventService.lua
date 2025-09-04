-- ServerScriptService/Services/PickfallEventService.lua
-- v1.0: Minijuego "Pickfall" (último en pie)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local PickfallFolder = Remotes:WaitForChild("PickFall")
local JoinEvent      = PickfallFolder:WaitForChild("PickfallJoin")
local StateEvent     = PickfallFolder:WaitForChild("PickfallState")
local WinnerEvent    = PickfallFolder:WaitForChild("PickfallWinner")

local MiningService = require(script.Parent:WaitForChild("MiningService"))

local arena  = Workspace:WaitForChild("PickfallArena")
local base   = arena:WaitForChild("Base")
local spawns = arena:WaitForChild("Spawns")

local ROUND_INTERVAL = 300 -- segundos entre eventos
local COUNTDOWN      = 10
local MONEY_REWARD   = 100
local BUFF_DURATION  = 60
local BUFF_MULT      = 2

local PickfallEventService = {}

local participants: {[Player]: {startCFrame: CFrame}} = {}
local registrationOpen = false
local active = false

local function broadcast(state, data)
        StateEvent:FireAllClients(state, data)
end

local function resetAll()
        for plr, info in pairs(participants) do
                local char = plr.Character
                if char and info.startCFrame then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                                hrp.CFrame = info.startCFrame
                        end
                end
        end
        participants = {}
        active = false
        registrationOpen = false
end

local function reward(plr: Player?)
        if not plr then return end
        WinnerEvent:FireAllClients(plr.Name)
        local stats = plr:FindFirstChild("leaderstats")
        local money = stats and stats:FindFirstChild("Money")
        if money then
                money.Value += MONEY_REWARD
        end
        MiningService.ApplyMiningBuff(plr, BUFF_DURATION, BUFF_MULT)
end

local function checkWin()
        local count, last = 0, nil
        for plr in pairs(participants) do
                count += 1
                last = plr
        end
        if count <= 1 then
                active = false
                if count == 1 then
                        reward(last)
                else
                        WinnerEvent:FireAllClients("")
                end
                task.delay(5, function()
                        resetAll()
                        broadcast("idle")
                end)
        end
end

local function eliminate(plr: Player)
        participants[plr] = nil
        checkWin()
end

RunService.Heartbeat:Connect(function()
        if not active then return end
        local threshold = base.Position.Y
        local toRemove = {}
        for plr in pairs(participants) do
                local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp or hrp.Position.Y < threshold then
                        table.insert(toRemove, plr)
                end
        end
        for _, plr in ipairs(toRemove) do
                eliminate(plr)
        end
end)

JoinEvent.OnServerEvent:Connect(function(plr)
        if not registrationOpen then return end
        if participants[plr] then return end
        local char = plr.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        participants[plr] = { startCFrame = hrp.CFrame }
end)

local function teleport()
        local spawnPoints = spawns:GetChildren()
        if #spawnPoints == 0 then return end
        local idx = 1
        for plr in pairs(participants) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                        local sp = spawnPoints[idx]
                        idx = idx % #spawnPoints + 1
                        if sp:IsA("BasePart") then
                                hrp.CFrame = sp.CFrame + Vector3.new(0, 5, 0)
                        elseif sp:IsA("Attachment") then
                                hrp.CFrame = sp.WorldCFrame + Vector3.new(0, 5, 0)
                        end
                end
        end
end

local function runRound()
        if not next(participants) then
                broadcast("idle")
                registrationOpen = true
                return
        end
        broadcast("countdown", COUNTDOWN)
        registrationOpen = false
        for t = COUNTDOWN, 1, -1 do
                broadcast("countdown", t)
                task.wait(1)
        end
        teleport()
        active = true
        broadcast("running")
end

local function cycle()
        while true do
                registrationOpen = true
                broadcast("idle")
                task.wait(ROUND_INTERVAL)
                runRound()
                while active do task.wait(1) end
        end
end

task.spawn(cycle)

Players.PlayerRemoving:Connect(function(plr)
        participants[plr] = nil
end)

return PickfallEventService
