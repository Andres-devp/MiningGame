-- ServerModules/LeaderstatsScript.lua
-- v2.7 - DataStore (gems, stones, upgrades, tools) + AutoMine + MÍNIMOS EN CARGA

local START_ROCK_AMOUNT        = 5
local START_CRYSTAL_AMOUNT     = 1
local START_SPAWN_RATE         = 4.0   -- s/roca (menor = mejor)
local START_CRYSTAL_SPAWN_RATE = 8.0   -- s/cristal (menor = mejor)

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LeaderstatsScript = {}

-- ⚠️ CAMBIA ESTE ID POR TU GAME PASS REAL (y usa el mismo en el cliente)
local AUTOMINE_PASS_ID  = 1406821381
local STORE_NAME        = "ACM_PlayerData_V1"

local DEFAULT_DATA = {
	gems = 0,
	stones = 0,
	upgrades = {
		RockAmount       = START_ROCK_AMOUNT,
		SpawnRate        = START_SPAWN_RATE,
		CrystalAmount    = START_CRYSTAL_AMOUNT,
		CrystalSpawnRate = START_CRYSTAL_SPAWN_RATE,
	},
	tools = { HasPickaxe = false },
}

-- ========== Utils ==========
local function deepcopy(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k, v in pairs(t) do r[k] = deepcopy(v) end
	return r
end

local function applyDefaults(dst, defs)
	for k, v in pairs(defs) do
		if type(v) == "table" then
			dst[k] = type(dst[k]) == "table" and dst[k] or {}
			applyDefaults(dst[k], v)
		else
			if dst[k] == nil then dst[k] = v end
		end
	end
end

local store = DataStoreService:GetDataStore(STORE_NAME)
local cache = {} -- [userId] = table

-- Aplica mínimos al cargar (sube el piso para TODOS los jugadores)
local function applyMinimums(data)
	-- Cantidades (más alto = mejor)
	if data.upgrades.RockAmount    < START_ROCK_AMOUNT    then data.upgrades.RockAmount    = START_ROCK_AMOUNT    end
	if data.upgrades.CrystalAmount < START_CRYSTAL_AMOUNT then data.upgrades.CrystalAmount = START_CRYSTAL_AMOUNT end

	-- Velocidades (menor = mejor)
	if data.upgrades.SpawnRate        > START_SPAWN_RATE        then data.upgrades.SpawnRate        = START_SPAWN_RATE        end
	if data.upgrades.CrystalSpawnRate > START_CRYSTAL_SPAWN_RATE then data.upgrades.CrystalSpawnRate = START_CRYSTAL_SPAWN_RATE end
end

-- ========== Carga / Guardado ==========
local function loadData(userId)
	local key = tostring(userId)
	local ok, data = pcall(function() return store:GetAsync(key) end)
	if not ok or type(data) ~= "table" then
		data = deepcopy(DEFAULT_DATA)
	else
		applyDefaults(data, DEFAULT_DATA)
	end

	applyMinimums(data)
	cache[userId] = data
	return data
end

local function saveData(userId)
	local data = cache[userId]
	if not data then return end
	local key = tostring(userId)
	pcall(function()
		store:UpdateAsync(key, function()
			return data
		end)
	end)
end

-- ========== Remotos ==========
local function ensureRemotes()
	local root = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	root.Name = "Remotes"
	root.Parent = ReplicatedStorage

	local function need(name)
		local ev = root:FindFirstChild(name)
		if not ev then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = root
		end
		return ev
	end

	return need("SyncAutoMinePass"), need("RequestToggleAutoMine")
end

local SyncAutoMinePass, RequestToggleAutoMine = ensureRemotes()

-- ========== Builders ==========
local function buildLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gems = leaderstats:FindFirstChild("Gems") or Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = data.gems
	gems.Parent = leaderstats

	gems:GetPropertyChangedSignal("Value"):Connect(function()
		local d = cache[player.UserId]; if d then d.gems = gems.Value end
	end)
end

local function buildStones(player, data)
	local stones = player:FindFirstChild("Stones") or Instance.new("IntValue")
	stones.Name = "Stones"
	stones.Value = data.stones
	stones.Parent = player

	stones:GetPropertyChangedSignal("Value"):Connect(function()
		local d = cache[player.UserId]; if d then d.stones = stones.Value end
	end)
end

local function buildUpgrades(player, data)
	local ups = player:FindFirstChild("Upgrades") or Instance.new("Folder")
	ups.Name = "Upgrades"
	ups.Parent = player

	local function ensureInt(name, val)
		local v = ups:FindFirstChild(name) or Instance.new("IntValue")
		v.Name = name; v.Value = val; v.Parent = ups
		v:GetPropertyChangedSignal("Value"):Connect(function()
			local d = cache[player.UserId]; if d then d.upgrades[name] = v.Value end
		end)
	end

	local function ensureNum(name, val)
		local v = ups:FindFirstChild(name) or Instance.new("NumberValue")
		v.Name = name; v.Value = val; v.Parent = ups
		v:GetPropertyChangedSignal("Value"):Connect(function()
			local d = cache[player.UserId]; if d then d.upgrades[name] = v.Value end
		end)
	end

	ensureInt("RockAmount",        data.upgrades.RockAmount)
	ensureNum("SpawnRate",         data.upgrades.SpawnRate)
	ensureInt("CrystalAmount",     data.upgrades.CrystalAmount)
	ensureNum("CrystalSpawnRate",  data.upgrades.CrystalSpawnRate)
end

local function buildTools(player, data)
	local tools = player:FindFirstChild("OwnedTools") or Instance.new("Folder")
	tools.Name = "OwnedTools"
	tools.Parent = player

	local pick = tools:FindFirstChild("HasPickaxe") or Instance.new("BoolValue")
	pick.Name = "HasPickaxe"
	pick.Value = data.tools.HasPickaxe
	pick.Parent = tools

	pick:GetPropertyChangedSignal("Value"):Connect(function()
		local d = cache[player.UserId]; if d then d.tools.HasPickaxe = pick.Value end
	end)
end

local function givePickaxeIfOwned(player)
	local owned = player:FindFirstChild("OwnedTools")
	local flag = owned and owned:FindFirstChild("HasPickaxe")
	if flag and flag.Value then
		local bp = player:FindFirstChild("Backpack")
		if bp and not bp:FindFirstChild("PickaxeModel") then
			local tpl = ReplicatedStorage:FindFirstChild("PickaxeModel")
			if tpl then
				local item = tpl:Clone()
				item.Name = "PickaxeModel"
				item.Parent = bp
			end
		end
	end
end

local function buildAutoMineValues(player)
	local owns = player:FindFirstChild("OwnsAutoMinePass") or Instance.new("BoolValue")
	owns.Name = "OwnsAutoMinePass"
	owns.Value = false
	owns.Parent = player

	local enabled = player:FindFirstChild("AutoMineEnabled") or Instance.new("BoolValue")
	enabled.Name = "AutoMineEnabled"
	enabled.Value = false
	enabled.Parent = player
end

local function refreshOwnership(player)
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, AUTOMINE_PASS_ID)
	if ok then
		local flag = player:FindFirstChild("OwnsAutoMinePass")
		if flag then flag.Value = owns and true or false end
	else
		warn("[AutoMine] Falló UserOwnsGamePassAsync")
	end
end

-- ========== Remote handlers ==========
SyncAutoMinePass.OnServerEvent:Connect(function(player)
	refreshOwnership(player)
end)

RequestToggleAutoMine.OnServerEvent:Connect(function(player)
	local owns = player:FindFirstChild("OwnsAutoMinePass")
	local en   = player:FindFirstChild("AutoMineEnabled")
	if owns and en and owns.Value then
		en.Value = not en.Value
	else
		warn("[AutoMine] Toggle denegado (no posee pase).")
	end
end)

-- ========== API ==========
function LeaderstatsScript:init()
	Players.PlayerAdded:Connect(function(player)
		local data = loadData(player.UserId)

		buildLeaderstats(player, data)
		buildStones(player, data)
		buildUpgrades(player, data)
		buildTools(player, data)
		buildAutoMineValues(player)
		refreshOwnership(player)

		player.CharacterAdded:Connect(function()
			givePickaxeIfOwned(player)
		end)
		task.defer(function() givePickaxeIfOwned(player) end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		saveData(player.UserId)
		cache[player.UserId] = nil
	end)

	-- Autosave periódico
	task.spawn(function()
		while true do
			task.wait(60)
			for _, pl in ipairs(Players:GetPlayers()) do
				saveData(pl.UserId)
			end
		end
	end)

	game:BindToClose(function()
		for _, pl in ipairs(Players:GetPlayers()) do
			saveData(pl.UserId)
		end
	end)

	print("[LeaderstatsScript] DataStore listo (gems, stones, upgrades, tools, automine).")
end

return LeaderstatsScript
