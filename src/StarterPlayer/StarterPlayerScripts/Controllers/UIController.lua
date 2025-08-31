-- UIController v2.1 – Actualiza contadores (Gems / Stones) de forma robusta
-- Ubicación: StarterPlayerScripts/Controllers/UIController.lua (ModuleScript)

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local UIController = {}

-- -------- utilidades --------
local function findDescendantByName(root: Instance, targetName: string): Instance?
	if not root then return nil end
	return root:FindFirstChild(targetName, true)
end

local function fmt(n: number): string
	-- separador de miles simple (opcional)
	local s = tostring(n or 0)
	local k
	while true do
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return s
end

-- Referencias de UI/valores (se resuelven al init)
local _playerGui: PlayerGui
local _statsGui: Instance
local _container: Instance
local _gemsLabel: TextLabel
local _stonesLabel: TextLabel
local _stonesValue: IntValue
local _gemsValue: IntValue

-- -------- API --------
function UIController:update()
	if _stonesLabel and _stonesValue then
		_stonesLabel.Text = fmt(_stonesValue.Value)
	end
	if _gemsLabel and _gemsValue then
		_gemsLabel.Text = fmt(_gemsValue.Value)
	end
end

function UIController:init()
	-- 1) Valores del jugador
	local leaderstats = player:WaitForChild("leaderstats")
	_gemsValue   = leaderstats:WaitForChild("Gems") :: IntValue
	_stonesValue = player:WaitForChild("Stones")    :: IntValue

	-- 2) Construcción UI (flexible a jerarquías)
	_playerGui = player:WaitForChild("PlayerGui")

	-- Busca por nombre (soporta que muevas frames)
	_statsGui  = _playerGui:WaitForChild("PlayerStatsGui")
	_container = _statsGui:FindFirstChild("Container") or _statsGui:WaitForChild("Container")

	local gemsCounter   = _container:FindFirstChild("GemsCounter")   or _container:WaitForChild("GemsCounter")
	local stonesCounter = _container:FindFirstChild("StonesCounter") or _container:WaitForChild("StonesCounter")

	-- Dentro de cada counter, buscamos un TextLabel llamado "AmountLabel"
	_gemsLabel   = findDescendantByName(gemsCounter, "AmountLabel")   :: TextLabel
	_stonesLabel = findDescendantByName(stonesCounter, "AmountLabel") :: TextLabel

	if not _gemsLabel or not _stonesLabel then
		error("[UIController] No se encontró 'AmountLabel' dentro de GemsCounter/StonesCounter. Revisa la GUI.")
	end

	-- 3) Suscripciones
	_stonesValue.Changed:Connect(function() UIController:update() end)
	_gemsValue.Changed:Connect(function()   UIController:update() end)

	-- 4) Primer render
	UIController:update()

	print("[UIController] Ready: counters linked to player values.")
end

return UIController
