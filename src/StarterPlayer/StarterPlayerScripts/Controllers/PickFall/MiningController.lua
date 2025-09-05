-- StarterPlayerScripts/Controllers/MiningController.lua
-- v9.1 restored: EventBus + barra cristal + SFX + VisualFX (sin RemoteEvents)
-- plus MiningGUI for stones

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- EventBus / Topics
local Shared    = ReplicatedStorage:WaitForChild("Shared")
local EventBus  = require(Shared:WaitForChild("events"):WaitForChild("EventBus"))
local Topics    = require(Shared:WaitForChild("events"):WaitForChild("EventTopics"))

-- Visual FX + SFX
local playerScripts = script:FindFirstAncestorOfClass("PlayerScripts") or script.Parent.Parent.Parent
local VisualFX  = require(playerScripts:WaitForChild("ClientModules"):WaitForChild("VisualFX"))
local M = {}
local ClientSoundManager

local MAX_DISTANCE   = 18
local CRYSTAL_TIME   = 1.4
local STONE_COOLDOWN = 0.45

local COLOR_CAN  = Color3.fromRGB(86, 220, 130)
local COLOR_CANT = Color3.fromRGB(240, 120, 120)

-- helpers
local function hrp()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function distOK(part)
    local root = hrp()
    return (root and part) and ((root.Position - part.Position).Magnitude <= MAX_DISTANCE) or false
end

local function hasTagDeep(inst, tag)
    if CollectionService:HasTag(inst, tag) then return true end
    if inst:IsA("Model") then
        if inst.PrimaryPart and CollectionService:HasTag(inst.PrimaryPart, tag) then return true end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") and CollectionService:HasTag(d, tag) then
                return true
            end
        end
    end
    return false
end

local function focusPart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    local hit = inst:FindFirstChild("Hitbox")
    if hit and hit:IsA("BasePart") then return hit end
    return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function nodeInfoFrom(inst)
    if not inst then return nil end
    local attr = inst:GetAttribute("NodeType")
    if attr then
        if attr == "Crystal" then
            return "Crystal", focusPart(inst)
        else
            return "Stone", focusPart(inst)
        end
    end
    if inst:GetAttribute("IsMinable") then
        return "Stone", focusPart(inst)
    end
    if hasTagDeep(inst, "Crystal") then return "Crystal", focusPart(inst) end
    if hasTagDeep(inst, "Stone") then return "Stone", focusPart(inst) end
    return nil
end

local function ownsAutoMinePass()
    local v = player:FindFirstChild("OwnsAutoMinePass")
    return v and v.Value or false
end

local function autoMineEnabled()
    local v = player:FindFirstChild("AutoMineEnabled") or player:FindFirstChild("IsAutoMineActive")
    return v and v.Value or false
end

local function hasEquippedPickaxeClient()
    local ch = player.Character
    if not ch then
        warn("[MiningController] hasEquippedPickaxeClient: sin character")
        return false
    end
    if ch:FindFirstChild("PickaxeModel") then
        warn("[MiningController] hasEquippedPickaxeClient: PickaxeModel detectado")
        return true
    end
    for _, inst in ipairs(ch:GetChildren()) do
        if inst:IsA("Tool") then
            local lname = inst.Name:lower()
            warn("[MiningController] Revisando herramienta", inst.Name)
            if lname:find("pick") or lname:find("pico") or CollectionService:HasTag(inst, "Pickaxe") then
                warn("[MiningController] hasEquippedPickaxeClient: reconocida como pico", inst.Name)
                return true
            end
        end
    end
    local flag = player:FindFirstChild("PickaxeEquipped")
    local equipped = (flag and flag.Value) or false
    warn("[MiningController] hasEquippedPickaxeClient: flag PickaxeEquipped=", equipped)
    return equipped
end

local function nodeIdOf(model)
    return (model and model:GetAttribute("NodeId")) or (model and model.Name) or nil
end

-- highlight
local hl = Instance.new("Highlight")
hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hl.FillTransparency = 0.6
hl.Enabled = true
hl.Parent = player:WaitForChild("PlayerGui")

local function setHighlight(adorn, canMine)
    if adorn then
        hl.Adornee = adorn
        hl.FillColor = canMine and COLOR_CAN or COLOR_CANT
        hl.OutlineColor = canMine and COLOR_CAN or COLOR_CANT
    else
        hl.Adornee = nil
    end
end

-- Mining GUI
local playerGui    = player:WaitForChild("PlayerGui")
local GUIFolder    = playerGui:WaitForChild("PickFall")
local MiningGUI    = GUIFolder:WaitForChild("MiningGUI")
local holderFrame  = MiningGUI:WaitForChild("HolderFrame")
MiningGUI.Enabled  = false

local function updateMiningGUI(model)
    if not model then return end
    MiningGUI.Enabled = true
    holderFrame.NameLabel.Text = model.Name
    local h  = tonumber(model:GetAttribute("Health")) or 0
    local mh = tonumber(model:GetAttribute("MaxHealth")) or math.max(1, h)
    if h < 0 then h = 0 end
    holderFrame.HealthLabel.Text = tostring(h) .. " / " .. tostring(mh)
    holderFrame.BarFrame.Size = UDim2.fromScale(mh > 0 and (h / mh) or 0, 1)
end

-- Progreso cristal
local function setCrystalProgress(model, ratio)
    local gui = model and model:FindFirstChild("ProgresoGui", true)
    if not (gui and gui:IsA("BillboardGui")) then return end
    if not gui.Adornee then gui.Adornee = model end
    gui.Enabled = true

    local fondo = gui:FindFirstChild("BarraFondo")
    if not (fondo and fondo:IsA("Frame")) then return end
    fondo.ClipsDescendants = true

    local barra = fondo:FindFirstChild("Barra") or fondo:FindFirstChildWhichIsA("Frame")
    if not barra or barra == fondo then
        barra = Instance.new("Frame")
        barra.Name = "Barra"
        barra.BorderSizePixel = 0
        barra.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
        barra.AnchorPoint = Vector2.new(0, 0.5)
        barra.Position = UDim2.fromScale(0, 0.5)
        barra.Size = UDim2.fromScale(0, 1)
        barra.Parent = fondo
    end
    barra.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

local function clearCrystalProgress(model)
    local gui = model and model:FindFirstChild("ProgresoGui", true)
    if not (gui and gui:IsA("BillboardGui")) then return end
    local fondo = gui:FindFirstChild("BarraFondo")
    if not (fondo and fondo:IsA("Frame")) then return end
    local barra = fondo:FindFirstChild("Barra")
    if barra then barra.Size = UDim2.fromScale(0, 1) end
    gui.Enabled = false
end

-- input sostenido para cristal
local isMouseDown = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isMouseDown = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isMouseDown = false
    end
end)

-- estado
local pendingModel   = nil
local currentCrystal = nil
local miningActive   = false
local crystalStart   = 0
local lastStoneAuto  = 0
local currentStone   = nil

-- === EventBus: feedback server → cliente ===
EventBus.registerClient(Topics.MiningFeedback, function(payload)
    if not payload then return end
    local kind = payload.kind
    local pos  = payload.position

    if kind == "crystal" then
        if currentCrystal then clearCrystalProgress(currentCrystal) end
        currentCrystal, miningActive, pendingModel = nil, false, nil

        if ClientSoundManager and pos then
            ClientSoundManager:playSound("CrystalSound", pos, 1)
        end
        if pos then
            VisualFX.crystalBurst(pos)
        end
    else
        if ClientSoundManager and pos then
            ClientSoundManager:playComboSound("BreakSound", pos)
        end
        if pos then
            VisualFX.impactDust(pos)
        end
        if currentStone and not currentStone.Parent then
            MiningGUI.Enabled = false
            currentStone = nil
        end
    end
end)

EventBus.registerClient(Topics.MiningCrystalAck, function(payload)
    local ok = payload and payload.ok
    if not pendingModel then return end
    if ok then
        currentCrystal = pendingModel
        crystalStart   = time()
        miningActive   = true
    else
        clearCrystalProgress(pendingModel)
        currentCrystal, miningActive = nil, false
    end
    pendingModel = nil
end)

function M:start(_, SoundManager)
    ClientSoundManager = SoundManager

    RunService.RenderStepped:Connect(function()
        local target = mouse.Target
        local model  = target and (target:FindFirstAncestorOfClass("Model") or target) or nil
        local nodeType, focus = nodeInfoFrom(model)

        if nodeType == "Stone" then
            local inDist  = focus and distOK(focus)
            local canMine = inDist
            setHighlight(model, canMine)
            if not canMine and model then
                warn("[MiningController] Piedra fuera de rango", model.Name, "inDist=", inDist)
            end
            if canMine then
                warn("[MiningController] Piedra lista para minar", model.Name)
                currentStone = model
                updateMiningGUI(model)
            else
                MiningGUI.Enabled = false
                currentStone = nil
            end

            if canMine and autoMineEnabled() and (time() - lastStoneAuto) > STONE_COOLDOWN then
                lastStoneAuto = time()
                local id = nodeIdOf(model)
                if id then
                    warn("[MiningController] Enviando MiningRequest", model.Name, id)
                    EventBus.sendToServer(Topics.MiningRequest, { node = model, nodeId = id, toolTier = 1 })
                end
            end

        elseif nodeType == "Crystal" then
            MiningGUI.Enabled = false
            currentStone = nil

            local hasPick = hasEquippedPickaxeClient()
            local inDist  = focus and distOK(focus)
            local canMine = hasPick and inDist
            warn("[MiningController] Cristal check hasPick=", hasPick, "inDist=", inDist, model and model.Name)
            setHighlight(model, canMine)

            local hoverAllowed  = ownsAutoMinePass() and autoMineEnabled()
            local shouldContinue = canMine and (hoverAllowed or isMouseDown)

            if shouldContinue and not pendingModel and not miningActive then
                pendingModel = model
                local id = nodeIdOf(model)
                if id then
                    warn("[MiningController] Enviando MiningCrystalStart", model.Name, id)
                    EventBus.sendToServer(Topics.MiningCrystalStart, { node = model, nodeId = id })
                end
            end

            if miningActive and currentCrystal == model then
                local ratio = (time() - crystalStart) / CRYSTAL_TIME
                setCrystalProgress(model, ratio)
            end

            if (not shouldContinue) and (pendingModel or miningActive) then
                warn("[MiningController] MiningCrystalStop")
                EventBus.sendToServer(Topics.MiningCrystalStop, {})
                if currentCrystal then clearCrystalProgress(currentCrystal) end
                currentCrystal, miningActive, pendingModel = nil, false, nil
            end

        else
            setHighlight(nil, false)
            if pendingModel or miningActive then
                EventBus.sendToServer(Topics.MiningCrystalStop, {})
                if currentCrystal then clearCrystalProgress(currentCrystal) end
                currentCrystal, miningActive, pendingModel = nil, false, nil
            end
            MiningGUI.Enabled = false
            currentStone = nil
        end
    end)
end

return M

