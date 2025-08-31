-- ServerScriptService/Services/DataService.lua
-- Servicio simple para sumar recursos en valores del jugador.

local DataService = {}

local function addIntValue(parent: Instance, name: string, startValue: number)
	local v = parent:FindFirstChild(name)
	if not v then
		v = Instance.new("IntValue")
		v.Name = name
		v.Value = startValue or 0
		v.Parent = parent
	end
	return v
end

-- kind: "gems" | "stones"
function DataService.addResource(player: Player, kind: string, delta: number)
	if not player or type(delta) ~= "number" then return end
	if kind == "gems" then
		local ls = player:FindFirstChild("leaderstats") or Instance.new("Folder")
		ls.Name = "leaderstats"; ls.Parent = player
		local gems = addIntValue(ls, "Gems", 0)
		gems.Value += delta
	elseif kind == "stones" then
		local stones = player:FindFirstChild("Stones") or Instance.new("IntValue")
		stones.Name = "Stones"; stones.Parent = player
		stones.Value += delta
	end
end

return DataService
