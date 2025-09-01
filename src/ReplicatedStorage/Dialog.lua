-- ReplicatedStorage/Dialog.lua
-- Módulo de diálogo para NPCs con soporte de animación y opciones de respuesta

local Dialog = {}
Dialog.__index = Dialog

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local TICK_SOUND = Sounds:WaitForChild("tick")
local END_TICK_SOUND = Sounds:WaitForChild("tick2")

local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
local saleDialog = playerGui:WaitForChild("SaleDialog")
local DIALOG_RESPONSES_UI = saleDialog:WaitForChild("dialogResponses")

-- Constructor
function Dialog.new(npcName, npc, prompt, animation)
    local self = setmetatable({}, Dialog)
    self.npcName = npcName
    self.npc = npc
    self.dialogs = {}
    self.responses = {}
    self.dialogOption = 1
    self.npcGui = self.npc:WaitForChild("Head"):WaitForChild("gui")
    self.active = false
    self.talking = false
    self.prompt = prompt

    local template = DIALOG_RESPONSES_UI:FindFirstChild("template")
    if template then
        for i = 1, 9 do
            local newResponseButton = template:Clone()
            newResponseButton.Parent = DIALOG_RESPONSES_UI
            newResponseButton.Name = i
        end
        template:Destroy()
    end

    local eventSignal = Instance.new("BindableEvent")
    self.responded = eventSignal.Event
    self.fireResponded = eventSignal

    -- tween variables
    self.animNameText = TweenService:Create(self.npcGui.name, TweenInfo.new(.3), {TextTransparency = 1})
    self.animNameStroke = TweenService:Create(self.npcGui.name.UIStroke, TweenInfo.new(.3), {Transparency = 1})
    self.animArrowText = TweenService:Create(self.npcGui.arrow, TweenInfo.new(.3), {TextTransparency = 1})
    self.animArrowStroke = TweenService:Create(self.npcGui.arrow.UIStroke, TweenInfo.new(.3), {Transparency = 1})
    self.animDialogText = TweenService:Create(self.npcGui.dialog, TweenInfo.new(.3), {TextTransparency = 1})
    self.animDialogStroke = TweenService:Create(self.npcGui.dialog.UIStroke, TweenInfo.new(.3), {Transparency = 1})

    -- animate
    if animation then
        local newAnimation = Instance.new("Animation")
        newAnimation.AnimationId = animation
        local newAnimLoaded = npc:WaitForChild("Humanoid"):LoadAnimation(newAnimation)
        newAnimLoaded:Play()
    end

    -- Connections
    local frameCount = 0
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        frameCount += 1
        if self.talking then
            self.npcGui.StudsOffset = Vector3.new(0, 1.6, 0)
        else
            self.npcGui.StudsOffset = Vector3.new(0, math.sin(frameCount / 25) / 6 + 1.55, 0)
        end
    end)
    self.connections = {heartbeatConnection}

    return self
end

-- Add dialog to the NPC
function Dialog:addDialog(dialogText, responseOptions)
    table.insert(self.dialogs, {text = dialogText, responses = responseOptions})
end

-- Sort dialogs alphabetically or by custom function
function Dialog:sortDialogs(sortFunc)
    table.sort(self.dialogs, sortFunc or function(a, b)
        return a.text < b.text
    end)
end

-- Display the dialog when proximity prompt is triggered
function Dialog:triggerDialog(player, questionNumber)
    self:showGui()

    if #self.dialogs == 0 then
        warn("No dialogs available for NPC: " .. self.npcName)
        return
    end

    local dialogNum = questionNumber or self.dialogOption
    local dialog = self.dialogs[dialogNum]

    TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()

    task.spawn(function()
        self.talking = true
        local dialogObject = self.npcGui.dialog
        dialogObject.Visible = true
        dialogObject.Text = ""
        local currenttext = ""
        local skip = false
        local arrow = 0
        for _, letter in ipairs(string.split(dialog.text, "")) do
            currenttext = currenttext .. letter
            if letter == "<" then skip = true end
            if letter == ">" then skip = false arrow += 1 continue end
            if arrow == 2 then arrow = 0 end
            if skip then continue end
            dialogObject.Text = currenttext .. (arrow == 1 and "</font>" or "")
            TICK_SOUND:Play()
            task.wait(0.02)
        end
        dialogObject.Text = dialog.text

        -- set up responses
        local playerReponseOptions = DIALOG_RESPONSES_UI
        for i, option in playerReponseOptions:GetChildren() do
            if not option:IsA("GuiButton") then continue end
            option.Text = dialog.responses[i] or ""
            option.Visible = option.Text ~= ""
            option.Activated:Connect(function()
                self.fireResponded:Fire(i, dialogNum)
            end)
        end
    end)
end

function Dialog:showGui()
    turnProximityPromptsOn(false)

    self.animNameText:Play()
    self.animNameStroke:Play()
    self.animArrowText:Play()
    self.animArrowStroke:Play()

    self.animDialogText:Cancel()
    self.animDialogStroke:Cancel()

    self.npcGui.dialog.TextTransparency = 0
    self.npcGui.dialog.UIStroke.Transparency = 0

    coroutine.wrap(function()
        task.wait(0.3)
        if self.npcGui.name.TextTransparency ~= 1 then return end
        self.npcGui.name.Visible = false
        self.npcGui.arrow.Visible = false
    end)()
end

function Dialog:hideGui(exitQuip)
    self.active = false
    self.talking = true
    turnProximityPromptsOn(true)
    self.talking = false

    TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()

    local playerReponseOptions = DIALOG_RESPONSES_UI
    for _, option in ipairs(playerReponseOptions:GetChildren()) do
        if option:IsA("GuiButton") then
            option.Visible = false
        end
    end

    local dialogObject = self.npcGui.dialog
    if exitQuip then
        dialogObject.TextTransparency = 0
        dialogObject.UIStroke.Transparency = 0
        self.npcGui.name.TextTransparency = 1
        self.npcGui.name.UIStroke.Transparency = 1
        self.npcGui.arrow.TextTransparency = 1
        self.npcGui.arrow.UIStroke.Transparency = 1
        local currenttext = ""
        dialogObject.Text = ""
        dialogObject.Visible = true
        local skip = false
        local arrow = 0
        for _, letter in ipairs(string.split(exitQuip, "")) do
            if dialogObject.Text ~= currenttext and skip == 0 then break end
            currenttext = currenttext .. letter
            if letter == "<" then skip = true end
            if letter == ">" then skip = false arrow += 1 continue end
            if arrow == 2 then arrow = 0 end
            if skip then continue end
            dialogObject.Text = currenttext .. (arrow == 1 and "</font>" or "")
            TICK_SOUND:Play()
            task.wait(0.02)
        end
        dialogObject.Text = exitQuip
    end

    task.spawn(function()
        if exitQuip then
            task.wait(2)
            if dialogObject.Text ~= exitQuip then return end
        end

        if self.npcGui.name.TextTransparency ~= 1 then
            self.animNameText:Cancel()
            self.animNameStroke:Cancel()
            self.animArrowText:Cancel()
            self.animArrowStroke:Cancel()
        end
        self.npcGui.name.TextTransparency = 0
        self.npcGui.name.UIStroke.Transparency = 0
        self.npcGui.arrow.TextTransparency = 0
        self.npcGui.arrow.UIStroke.Transparency = 0
        self.npcGui.name.Visible = true
        self.npcGui.arrow.Visible = true

        self.animDialogText:Play()
        self.animDialogStroke:Play()
        turnProximityPromptsOn(true)
    end)
end

function Dialog:nextOption()
    self.dialogOption += 1
    if #self.dialogs < self.dialogOption then
        warn("No next dialog option for, " .. self.npcName)
        self.dialogOption -= 1
    end
    return self.dialogOption
end

function turnProximityPromptsOn(yes)
    for _, prompt in CollectionService:GetTagged("NPCprompt") do
        if prompt:IsA("ProximityPrompt") then
            prompt.Enabled = yes
        end
    end
end

return Dialog

