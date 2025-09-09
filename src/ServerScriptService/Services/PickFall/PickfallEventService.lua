

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local PickfallFolder = Remotes:WaitForChild("PickFall")
local JoinEvent      = PickfallFolder:WaitForChild("PickfallJoin")
local StateEvent     = PickfallFolder:WaitForChild("PickfallState")
local WinnerEvent    = PickfallFolder:WaitForChild("PickfallWinner")

local MiningService = require(script.Parent.Parent:WaitForChild("MiningService"))
local NodeService   = require(script.Parent.Parent:WaitForChild("NodeService"))

local arena     = Workspace:WaitForChild("PickfallArena")
local base      = arena:WaitForChild("Base")
local oreFolder = arena:WaitForChild("OrePlatforms") -- updated name from "Ores"
local spawns    = arena:WaitForChild("Spawners")

local ROUND_INTERVAL = 300 
local COUNTDOWN      = 30
local MONEY_REWARD   = 100
local BUFF_DURATION  = 60
local BUFF_MULT      = 2

local PickfallEventService = {}

local participants = {}

local registrationOpen = false
local active = false

local currentMode = 1
local oreTouchedConnections = {}
local fallingOres = {}

local currentState, currentData = "idle", nil

local function setupOreBlocks()
  print("[PickfallEventService] Preparing ore blocks")
  for _, ore in ipairs(oreFolder:GetChildren()) do
    local nodeType = ore:GetAttribute("NodeType") or ore.Name
    if ore:GetAttribute("NodeType") == nil then
      ore:SetAttribute("NodeType", nodeType)
    end

    local mh = ore:GetAttribute("MaxHealth")
    if mh == nil then
      mh = (ore.Name == "CommonStone") and 1 or 20
      ore:SetAttribute("MaxHealth", mh)
    end

    if ore:GetAttribute("Health") == nil then
      ore:SetAttribute("Health", mh)
    end

    if ore:GetAttribute("IsMinable") == nil then
      ore:SetAttribute("IsMinable", true)
    end

    if ore:GetAttribute("Reward") == nil then
      ore:SetAttribute("Reward", 0)
    end

    if ore:GetAttribute("RequiresPickaxe") == nil then
      ore:SetAttribute("RequiresPickaxe", true)
    end

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

local function connectOreTouch(ore)
        local function startTimer()
                if fallingOres[ore] then
                        return
                end
                fallingOres[ore] = true
                local delayTime = ore:GetAttribute("MaxHealth") or 1
                task.spawn(function()
                        for i = delayTime, 1, -1 do
                                ore:SetAttribute("Health", i - 1)
                                task.wait(1)
                        end
                        if ore:IsA("Model") then
                                for _, p in ipairs(ore:GetDescendants()) do
                                        if p:IsA("BasePart") then
                                                p.Anchored = false
                                                p.CanCollide = false
                                        end
                                end
                        elseif ore:IsA("BasePart") then
                                ore.Anchored = false
                                ore.CanCollide = false
                        end
                        task.delay(5, function()
                                if ore and ore.Parent then
                                        ore:Destroy()
                                end
                        end)
                end)
        end

        local function bind(part)
                local conn = part.Touched:Connect(function(hit)
                        local plr = Players:GetPlayerFromCharacter(hit.Parent)
                        if plr then
                                startTimer()
                        end
                end)
                table.insert(oreTouchedConnections, conn)
        end

        if ore:IsA("Model") then
                for _, part in ipairs(ore:GetDescendants()) do
                        if part:IsA("BasePart") then
                                bind(part)
                        end
                end
        elseif ore:IsA("BasePart") then
                bind(ore)
        end
end

local function broadcast(state, data)
        if state ~= "countdown" then
                print("[PickfallEventService] broadcast", state, data)
        end
        currentState, currentData = state, data
        StateEvent:FireAllClients(state, data)
end

local function resetAll()
        print("[PickfallEventService] resetAll")
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
for _, conn in ipairs(oreTouchedConnections) do
conn:Disconnect()
end
oreTouchedConnections = {}
fallingOres = {}
currentMode = 1
resetOreBlocks()
print("[PickfallEventService] resetAll complete")

end

local function reward(plr)
        if not plr then return end
        print("[PickfallEventService] reward", plr.Name)
        WinnerEvent:FireAllClients(plr.Name)
        local stats = plr:FindFirstChild("leaderstats")
        local money = stats and stats:FindFirstChild("Money")
        if money then
                money.Value = money.Value + MONEY_REWARD
                print("\tMoney awarded", MONEY_REWARD)
        else
                print("\tMoney stat missing")
        end
        MiningService.ApplyMiningBuff(plr, BUFF_DURATION, BUFF_MULT)
end

local function checkWin()
        local count, last = 0, nil
        for plr in pairs(participants) do
                count = count + 1
                last = plr
        end
        print("[PickfallEventService] checkWin participants", count)
        if count <= 1 then
                active = false
                if count == 1 then
                        reward(last)
                else
                        WinnerEvent:FireAllClients("")
                        print("[PickfallEventService] No winner")
                end
                task.delay(5, function()
                        resetAll()
                        registrationOpen = true
                        broadcast("idle")
                end)
        end
end

local function eliminate(plr)
        print("[PickfallEventService] eliminate", plr and plr.Name)
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
                print("[PickfallEventService] Player fell", plr.Name)
                eliminate(plr)
        end
end)

JoinEvent.OnServerEvent:Connect(function(plr, mode)
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
participants[plr] = { startCFrame = hrp.CFrame, mode = mode or 1 }
local total = 0
        for _ in pairs(participants) do total += 1 end
        print("\tRegistered", plr.Name, "total participants", total)
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
        registrationOpen = true
        for t = COUNTDOWN, 1, -1 do
                broadcast("countdown", t)
                task.wait(1)
        end
registrationOpen = false
if not next(participants) then
print("\tNo participants after countdown")
broadcast("idle")
registrationOpen = true
return
end
local counts = {}
for _, info in pairs(participants) do
local m = info.mode or 1
counts[m] = (counts[m] or 0) + 1
end
currentMode = 1
local maxCount = 0
for m, c in pairs(counts) do
if c > maxCount then
maxCount = c
currentMode = m
end
end
print("\tSelected mode", currentMode)
print("\tTeleporting players")
teleport()
if currentMode == 2 then
for _, ore in ipairs(oreFolder:GetChildren()) do
connectOreTouch(ore)
end
end
active = true
print("\tRound active")
broadcast("running")
end

local function cycle()
        while true do

                runRound()
                while active do
                        task.wait(1)
                end
                print("[PickfallEventService] Waiting", ROUND_INTERVAL, "seconds for next round")
                task.wait(ROUND_INTERVAL)

        end
end

registrationOpen = false
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
