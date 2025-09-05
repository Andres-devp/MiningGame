

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local PickfallFolder = Remotes:WaitForChild("PickFall")
local JoinEvent      = PickfallFolder:WaitForChild("PickfallJoin")
local StateEvent     = PickfallFolder:WaitForChild("PickfallState")
local WinnerEvent    = PickfallFolder:WaitForChild("PickfallWinner")

local MiningService = require(script.Parent.Parent:WaitForChild("MiningService"))
local NodeService   = require(script.Parent.Parent:WaitForChild("NodeService"))

local arena     = Workspace:WaitForChild("PickfallArena")
local base      = arena:WaitForChild("Base")
local oreFolder = arena:WaitForChild("Ores")
local spawns    = arena:WaitForChild("Spawners")

local ROUND_INTERVAL = 300 
local COUNTDOWN      = 10
local MONEY_REWARD   = 100
local BUFF_DURATION  = 60
local BUFF_MULT      = 2

local PickfallEventService = {}

local participants = {}

local registrationOpen = false
local active = false

local currentState, currentData = "idle", nil

local function setupOreBlocks()
  print("[PickfallEventService] Preparing ore blocks")
  for _, ore in ipairs(oreFolder:GetChildren()) do
    local nodeType = ore:GetAttribute("NodeType") or ore.Name
    ore:SetAttribute("NodeType", nodeType)
    local mh = ore:GetAttribute("MaxHealth")
    if not mh then
      mh = (ore.Name == "CommonStone") and 1 or 20
    end
    ore:SetAttribute("MaxHealth", mh)
    ore:SetAttribute("Health", ore:GetAttribute("Health") or mh)
    ore:SetAttribute("IsMinable", true)

    if ore:IsA("Model") then
      for _, part in ipairs(ore:GetDescendants()) do
        if part:IsA("BasePart") then
          part.Anchored = true
        end
      end
    elseif ore:IsA("BasePart") then
      ore.Anchored = true
    else
      print("\tWarning: unsupported ore type", ore.ClassName)
    end
  end
end

local function resetOreBlocks()
  
  setupOreBlocks()

  
  for _, ore in ipairs(oreFolder:GetChildren()) do
    if ore:IsA("Model") then
      NodeService.register(ore)
    end
  end
end

local function broadcast(state, data)
        print("[PickfallEventService] broadcast", state, data)
        currentState, currentData = state, data
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
        resetOreBlocks()

end

local function reward(plr)

        if not plr then return end
        WinnerEvent:FireAllClients(plr.Name)
        local stats = plr:FindFirstChild("leaderstats")
        local money = stats and stats:FindFirstChild("Money")
        if money then

                money.Value = money.Value + MONEY_REWARD

        end
        MiningService.ApplyMiningBuff(plr, BUFF_DURATION, BUFF_MULT)
end

local function checkWin()
        local count, last = 0, nil
        for plr in pairs(participants) do

                count = count + 1

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
                        registrationOpen = true
                        broadcast("idle")
                end)
        end
end

local function eliminate(plr)

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
        print("[PickfallEventService] JoinEvent from", plr and plr.Name, "registrationOpen=", registrationOpen)
        if not registrationOpen then
                print("\tRegistration closed")
                return
        end
        if participants[plr] then
                print("\tAlready registered")
                return
        end
        local char = plr.Character
        if not char then
                print("\tNo character")
                return
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
                print("\tNo HumanoidRootPart")
                return
        end
        participants[plr] = { startCFrame = hrp.CFrame }
        print("\tRegistered", plr.Name)
end)

local function teleport()
        local spawnPoints = spawns:GetChildren()
        if #spawnPoints == 0 then
                print("[PickfallEventService]\tNo spawn points available")
                return
        end
        local idx = 1
        for plr in pairs(participants) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                        local sp = spawnPoints[idx]
                        idx = idx % #spawnPoints + 1
                        if sp:IsA("BasePart") then
                                print("[PickfallEventService]\tTeleporting", plr.Name, "to", sp.Name)
                                hrp.CFrame = sp.CFrame + Vector3.new(0, 5, 0)
                        elseif sp:IsA("Attachment") then
                                print("[PickfallEventService]\tTeleporting", plr.Name, "to attachment", sp.Name)
                                hrp.CFrame = sp.WorldCFrame + Vector3.new(0, 5, 0)
                        else
                                print("[PickfallEventService]\tUnknown spawn type for", sp.Name)
                        end
                else
                        print("[PickfallEventService]\tCannot teleport", plr.Name)
                end
        end
end

local function runRound()
        print("[PickfallEventService] runRound invoked")
        if not next(participants) then
                print("\tNo participants")
                broadcast("idle")
                registrationOpen = true
                return
        end
        registrationOpen = true
        print("\tCountdown starting with", #participants, "participants")
        for t = COUNTDOWN, 1, -1 do
                broadcast("countdown", t)
                task.wait(1)
        end
        registrationOpen = false
        print("\tTeleporting players")
        teleport()
        active = true
        print("\tRound active")
        broadcast("running")
end

local function cycle()
        while true do
                task.wait(ROUND_INTERVAL)
                runRound()
                while active do task.wait(1) end
                registrationOpen = true
                broadcast("idle")
        end
end

registrationOpen = true
resetOreBlocks()

broadcast("idle")
task.spawn(cycle)

Players.PlayerAdded:Connect(function(plr)
        StateEvent:FireClient(plr, currentState, currentData)
end)

Players.PlayerRemoving:Connect(function(plr)
        participants[plr] = nil
end)

return PickfallEventService
