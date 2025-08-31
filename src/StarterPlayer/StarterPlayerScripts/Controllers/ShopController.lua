-- Controllers/ShopController.lua
-- Maneja la tienda dentro de MainGui (abrir/cerrar y calcular costos)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeEvent = Remotes:WaitForChild("UpgradePlotEvent")

local M = {}

-- Busca descendientes por nombre (por si no son hijos directos)
local function findDesc(parent, name, timeout)
	timeout = timeout or 5
	local t0 = os.clock()
	repeat
		local inst = parent:FindFirstChild(name, true)
		if inst then return inst end
		task.wait(0.05)
	until (os.clock() - t0) >= timeout
	return nil
end

function M.init()
	local player      = Players.LocalPlayer
	local upgrades    = player:WaitForChild("Upgrades")
	local leaderstats = player:WaitForChild("leaderstats")
	local gems        = leaderstats:WaitForChild("Gems")

	local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

	-- Widgets del GUI (busca recursivo por si cambió la jerarquía)
	local shopFrame = gui:FindFirstChild("ShopFrame") or findDesc(gui, "ShopFrame")
	local openBtn   = gui:FindFirstChild("OpenShopButton") or findDesc(gui, "OpenShopButton")

	if not shopFrame or not openBtn then
		warn("[ShopController] No encontré ShopFrame u OpenShopButton en MainGui")
		return
	end

	-- Rocas
	local amountBtn   = findDesc(shopFrame, "AmountButton")
	local amountInfo  = findDesc(shopFrame, "AmountInfo")
	local rateBtn     = findDesc(shopFrame, "RateButton")
	local rateInfo    = findDesc(shopFrame, "RateInfo")
	-- Cristales
	local cAmountBtn  = findDesc(shopFrame, "CrystalAmountButton")
	local cAmountInfo = findDesc(shopFrame, "CrystalAmountInfo")
	local cRateBtn    = findDesc(shopFrame, "CrystalRateButton")
	local cRateInfo   = findDesc(shopFrame, "CrystalRateInfo")

	if not (amountBtn and amountInfo and rateBtn and rateInfo and
	        cAmountBtn and cAmountInfo and cRateBtn and cRateInfo) then
		warn("[ShopController] Faltan labels/botones dentro de ShopFrame")
		return
	end

	-- Ajusta estos valores a como los tengas en UpgradeHandler (servidor)
	local UPGRADE = {
		RockAmount        = { base = 50,  mult = 1.5, start = 5 },
		SpawnRate         = { base = 100, mult = 2.0, start = 4.0, step = 0.25, min = 0.5 },
		CrystalAmount     = { base = 150, mult = 1.6, start = 0 },
		CrystalSpawnRate  = { base = 200, mult = 1.9, start = 8.0, step = 0.5,  min = 2.0 },
	}

	local GREEN = Color3.fromRGB(40,167,69)
	local RED   = Color3.fromRGB(220,53,69)

	local function costAmount(cur, cfg)
		local steps = math.max(0, cur - cfg.start)
		return math.floor(cfg.base * (cfg.mult ^ steps))
	end

	local function costRate(cur, cfg)
		local b = (cfg.start - cur) / cfg.step
		b = math.max(0, math.floor(b + 0.5))
		return math.floor(cfg.base * (cfg.mult ^ b))
	end

	local function style(btn, ok)
		btn.Text = ok and "Mejorar" or "Insuficiente"
		btn.BackgroundColor3 = ok and GREEN or RED
		btn.AutoButtonColor = ok
		btn.Active = ok
	end

	local function update()
		-- Rocas
		local a = upgrades.RockAmount.Value
		local ac = costAmount(a, UPGRADE.RockAmount)
		amountInfo.Text = ("Nivel: %d\nCosto: %d Gemas"):format(a, ac)
		style(amountBtn, gems.Value >= ac)

		local r = upgrades.SpawnRate.Value
		local rc = costRate(r, UPGRADE.SpawnRate)
		if r <= UPGRADE.SpawnRate.min + 1e-4 then
			rateInfo.Text = ("Velocidad: MAX (%.2fs)\nCosto: --"):format(UPGRADE.SpawnRate.min)
			style(rateBtn, false); rateBtn.Text = "MAX"
		else
			rateInfo.Text = ("Velocidad: %.2fs\nCosto: %d Gemas"):format(r, rc)
			style(rateBtn, gems.Value >= rc)
		end

		-- Cristales
		local ca = upgrades.CrystalAmount.Value
		local cac = costAmount(ca, UPGRADE.CrystalAmount)
		cAmountInfo.Text = ("Nivel: %d\nCosto: %d Gemas"):format(ca, cac)
		style(cAmountBtn, gems.Value >= cac)

		local cr = upgrades.CrystalSpawnRate.Value
		local crc = costRate(cr, UPGRADE.CrystalSpawnRate)
		if cr <= UPGRADE.CrystalSpawnRate.min + 1e-4 then
			cRateInfo.Text = ("Velocidad: MAX (%.2fs)\nCosto: --"):format(UPGRADE.CrystalSpawnRate.min)
			style(cRateBtn, false); cRateBtn.Text = "MAX"
		else
			cRateInfo.Text = ("Velocidad: %.2fs\nCosto: %d Gemas"):format(cr, crc)
			style(cRateBtn, gems.Value >= crc)
		end
	end

	-- Mostrar/ocultar
	shopFrame.Visible = false
	openBtn.Activated:Connect(function()
		shopFrame.Visible = not shopFrame.Visible
		if shopFrame.Visible then update() end
	end)

	-- Botones de compra
	amountBtn.Activated:Connect(function() if amountBtn.Active then upgradeEvent:FireServer("RockAmount") end end)
	rateBtn.Activated:Connect(function()   if rateBtn.Active   then upgradeEvent:FireServer("SpawnRate") end end)
	cAmountBtn.Activated:Connect(function() if cAmountBtn.Active then upgradeEvent:FireServer("CrystalAmount") end end)
	cRateBtn.Activated:Connect(function()   if cRateBtn.Active   then upgradeEvent:FireServer("CrystalSpawnRate") end end)

	-- Recalcula cuando cambian valores
	gems.Changed:Connect(update)
	upgrades.RockAmount.Changed:Connect(update)
	upgrades.SpawnRate.Changed:Connect(update)
	upgrades.CrystalAmount.Changed:Connect(update)
	upgrades.CrystalSpawnRate.Changed:Connect(update)

	update()
	print("[ShopController] listo")
end

return M
