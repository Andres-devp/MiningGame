-- Controllers/CloseButtonController.lua
-- Conecta botones llamados "CloseButton" para ocultar su Frame padre

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local M = {}

-- Conecta un botón específico
local function hookButton(btn: GuiButton)
    local uiScale = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back)

    local function animateButton(rotation, scale)
        TweenService:Create(btn, tweenInfo, { Rotation = rotation }):Play()
        TweenService:Create(uiScale, tweenInfo, { Scale = scale }):Play()
    end

    btn.MouseEnter:Connect(function()
        animateButton(-15, 1.1)
    end)

    btn.MouseLeave:Connect(function()
        animateButton(0, 1)
    end)

    btn.Activated:Connect(function()
        local parent = btn.Parent
        if parent and parent:IsA("GuiObject") then
            parent.Visible = false
        end
    end)
end

function M:init()
    local gui = player:WaitForChild("PlayerGui")

    -- Buscar botones existentes
    for _, inst in ipairs(gui:GetDescendants()) do
        if inst:IsA("GuiButton") and inst.Name == "CloseButton" then
            hookButton(inst)
        end
    end

    -- Escuchar nuevos botones agregados dinámicamente
    gui.DescendantAdded:Connect(function(inst)
        if inst:IsA("GuiButton") and inst.Name == "CloseButton" then
            hookButton(inst)
        end
    end)

    print("[CloseButtonController] listo")
end

return M

