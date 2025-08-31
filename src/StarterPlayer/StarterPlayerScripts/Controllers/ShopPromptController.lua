-- Controllers/ShopPromptController.lua
-- Controla el ProximityPrompt de workspace.TiendaPico (texto dinámico según gemas)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local M = {}

function M.init()
  local player      = Players.LocalPlayer
  local leaderstats = player:WaitForChild("leaderstats")
  local gems        = leaderstats:WaitForChild("Gems")

  local TIENDA = workspace:WaitForChild("TiendaPico")
  local PROMPT = TIENDA:WaitForChild("ProximityPrompt")

  local PRECIO_GEMAS  = 10
  local PRECIO_ROBUX  = 10
  local isNearShop    = false
  local lastGemsValue = -1

  local function updatePromptText()
    local currentGems = gems.Value
    if currentGems == lastGemsValue then return end
    if currentGems >= PRECIO_GEMAS then
      PROMPT.ObjectText = "Pico Mejorado"
      PROMPT.ActionText = ("Comprar (%d Gemas)"):format(PRECIO_GEMAS)
    else
      PROMPT.ObjectText = "Pico Mejorado"
      PROMPT.ActionText = ("Comprar (%d Robux)"):format(PRECIO_ROBUX)
    end
    lastGemsValue = currentGems
  end

  RunService.RenderStepped:Connect(function()
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local distancia = (hrp.Position - TIENDA.Position).Magnitude
    if distancia <= (PROMPT.MaxActivationDistance or 10) then
      if not isNearShop then
        updatePromptText()
        isNearShop = true
      end
    else
      if isNearShop then
        isNearShop = false
      end
    end
  end)

  gems.Changed:Connect(function()
    if isNearShop then
      updatePromptText()
    end
  end)

  print("[ShopPromptController] listo")
end

return M
