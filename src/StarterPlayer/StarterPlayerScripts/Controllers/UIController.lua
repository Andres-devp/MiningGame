

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local UIController = {}

local function findDescendantByName(root: Instance, targetName: string): Instance?
	if not root then return nil end
	return root:FindFirstChild(targetName, true)
end

local function fmt(n: number): string
	
	local s = tostring(n or 0)
	local k
	while true do
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return s
end

local _playerGui: PlayerGui
local _statsGui: Instance
local _container: Instance
local _gemsLabel: TextLabel
local _stonesLabel: TextLabel
local _stonesValue: IntValue
local _gemsValue: IntValue

function UIController:update()
	if _stonesLabel and _stonesValue then
		_stonesLabel.Text = fmt(_stonesValue.Value)
	end
	if _gemsLabel and _gemsValue then
		_gemsLabel.Text = fmt(_gemsValue.Value)
	end
end

function UIController:init()
	
	local leaderstats = player:WaitForChild("leaderstats")
	_gemsValue   = leaderstats:WaitForChild("Gems") :: IntValue
	_stonesValue = player:WaitForChild("Stones")    :: IntValue

	
	_playerGui = player:WaitForChild("PlayerGui")

	
	_statsGui  = _playerGui:WaitForChild("PlayerStatsGui")
	_container = _statsGui:FindFirstChild("Container") or _statsGui:WaitForChild("Container")

	local gemsCounter   = _container:FindFirstChild("GemsCounter")   or _container:WaitForChild("GemsCounter")
	local stonesCounter = _container:FindFirstChild("StonesCounter") or _container:WaitForChild("StonesCounter")

	
	_gemsLabel   = findDescendantByName(gemsCounter, "AmountLabel")   :: TextLabel
	_stonesLabel = findDescendantByName(stonesCounter, "AmountLabel") :: TextLabel

	if not _gemsLabel or not _stonesLabel then
		error("[UIController] No se encontró 'AmountLabel' dentro de GemsCounter/StonesCounter. Revisa la GUI.")
	end

	
	_stonesValue.Changed:Connect(function() UIController:update() end)
	_gemsValue.Changed:Connect(function()   UIController:update() end)

	
	UIController:update()

	print("[UIController] Ready: counters linked to player values.")
end

return UIController
