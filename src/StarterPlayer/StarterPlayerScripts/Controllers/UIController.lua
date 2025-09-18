

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
local _gemsLabel: TextLabel
local _cashLabel: TextLabel
local _cashValue: IntValue
local _gemsValue: IntValue

function UIController:update()
	if _cashLabel and _cashValue then
		_cashLabel.Text = fmt(_cashValue.Value)
	end
	if _gemsLabel and _gemsValue then
		_gemsLabel.Text = fmt(_gemsValue.Value)
	end
end

local function resolveCashValue(leaderstats: Instance): IntValue
	local value = player:FindFirstChild("Cash")
	if not value and leaderstats then
		value = leaderstats:FindFirstChild("Cash")
	end
	if not value then
		value = player:FindFirstChild("Stones")
	end
	if value then
		return value :: IntValue
	end
	return player:WaitForChild("Stones") :: IntValue
end

function UIController:init()
	
	local leaderstats = player:WaitForChild("leaderstats")
	_gemsValue = leaderstats:WaitForChild("Gems") :: IntValue
	_cashValue = resolveCashValue(leaderstats)

	
	_playerGui = player:WaitForChild("PlayerGui")
	_statsGui  = _playerGui:WaitForChild("PlayerStatsGui")

	local gemsCounter = _statsGui:FindFirstChild("GemsCounter")
	if not gemsCounter then
		gemsCounter = findDescendantByName(_statsGui, "GemsCounter")
	end

	local cashCounter = _statsGui:FindFirstChild("CashCounter")
	if not cashCounter then
		cashCounter = _statsGui:FindFirstChild("StonesCounter") or findDescendantByName(_statsGui, "CashCounter") or findDescendantByName(_statsGui, "StonesCounter")
	end

	_gemsLabel = findDescendantByName(gemsCounter, "AmountLabel") :: TextLabel
	_cashLabel = findDescendantByName(cashCounter, "AmountLabel") :: TextLabel

	if not _gemsLabel or not _cashLabel then
		error("[UIController] No se encontro 'AmountLabel' dentro de GemsCounter/CashCounter. Revisa la GUI.")
	end

	
	_cashValue.Changed:Connect(function() UIController:update() end)
	_gemsValue.Changed:Connect(function() UIController:update() end)

	
	UIController:update()

	print("[UIController] Ready: counters linked to player values.")
end

return UIController

