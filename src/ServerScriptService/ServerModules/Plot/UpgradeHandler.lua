
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeHandler = {}

function UpgradeHandler:init()
        
        local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage

        local upgradeEvent = remotes:FindFirstChild("UpgradePlotEvent")
        if not upgradeEvent then
                upgradeEvent = Instance.new("RemoteEvent")
                upgradeEvent.Name = "UpgradePlotEvent"
                upgradeEvent.Parent = remotes
        end

	
        local UPGRADE = {
                RockAmount = { base = 25,  mult = 1.3, start = 5 },    
                SpawnRate  = { base = 50,  mult = 1.5, start = 4.0, step = 0.25, min = 0.5 }, 
                CrystalAmount    = { base = 75,  mult = 1.4, start = 0 },    
                CrystalSpawnRate = { base = 100, mult = 1.6, start = 8.0, step = 0.5,  min = 2.0 }, 
        }

	local function ensureUps(plr)
		local ups = plr:FindFirstChild("Upgrades")
		if ups then return ups end
		ups = Instance.new("Folder"); ups.Name="Upgrades"; ups.Parent=plr
		local function int(n,v) local x=Instance.new("IntValue"); x.Name=n; x.Value=v; x.Parent=ups end
		local function num(n,v) local x=Instance.new("NumberValue"); x.Name=n; x.Value=v; x.Parent=ups end
		int("RockAmount", UPGRADE.RockAmount.start)
		num("SpawnRate",  UPGRADE.SpawnRate.start)
		int("CrystalAmount", UPGRADE.CrystalAmount.start)
		num("CrystalSpawnRate", UPGRADE.CrystalSpawnRate.start)
		return ups
	end

	Players.PlayerAdded:Connect(ensureUps)
	for _,p in ipairs(Players:GetPlayers()) do ensureUps(p) end

	upgradeEvent.OnServerEvent:Connect(function(player, name)
		local cfg = UPGRADE[name]; if not cfg then return end
		local ups = player:FindFirstChild("Upgrades"); if not ups then return end
		local val = ups:FindFirstChild(name); if not val then return end
		local ls = player:FindFirstChild("leaderstats"); local gems = ls and ls:FindFirstChild("Gems"); if not gems then return end

		local cost
		if name=="RockAmount" or name=="CrystalAmount" then
			local steps = math.max(0, val.Value - cfg.start)
			cost = math.floor(cfg.base * (cfg.mult ^ steps))
		else
			local bought = (cfg.start - val.Value) / cfg.step
			bought = math.max(0, math.floor(bought + 0.5))
			cost = math.floor(cfg.base * (cfg.mult ^ bought))
		end
		if gems.Value < cost then return end

		gems.Value -= cost
		if name=="RockAmount" or name=="CrystalAmount" then
			val.Value += 1
		else
			val.Value = math.max(cfg.min, val.Value - cfg.step)
		end
	end)

	print("[UpgradeHandler] Inicializado (Rocas + Cristales).")
end

return UpgradeHandler
