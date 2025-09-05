

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeEvent = Remotes:WaitForChild("UpgradePlotEvent")
local playerScripts = script:FindFirstAncestorOfClass("PlayerScripts") or script.Parent.Parent.Parent
local SoundManager = require(playerScripts:WaitForChild("ClientModules"):WaitForChild("SoundManager"))

local M = {}
local initialized = false

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
        local player = Players.LocalPlayer
        if initialized or player:GetAttribute("ShopControllerReady") then
                return
        end
        initialized = true
        player:SetAttribute("ShopControllerReady", true)
        local upgrades    = player:WaitForChild("Upgrades")
        local leaderstats = player:WaitForChild("leaderstats")
        local gems        = leaderstats:WaitForChild("Gems")

        local playerGui = player:WaitForChild("PlayerGui")
        local gui       = playerGui:WaitForChild("MainGui")

        
        local upgradeFrame = gui:FindFirstChild("UpgradeShopFrame") or findDesc(gui, "UpgradeShopFrame")
        local robuxBtn     = gui:FindFirstChild("OpenShopButton") or findDesc(gui, "OpenShopButton")
        local robuxFrame   = gui:FindFirstChild("RobuxShopFrame") or findDesc(gui, "RobuxShopFrame")

        print("[ShopController] upgradeFrame", upgradeFrame)
        print("[ShopController] robuxBtn", robuxBtn)
        print("[ShopController] robuxFrame", robuxFrame)

        if not upgradeFrame then
                warn("[ShopController] No encontré UpgradeShopFrame en MainGui")
                return
        end

	
        local amountBtn   = findDesc(upgradeFrame, "AmountButton")
        local amountInfo  = findDesc(upgradeFrame, "AmountInfo")
        local rateBtn     = findDesc(upgradeFrame, "RateButton")
        local rateInfo    = findDesc(upgradeFrame, "RateInfo")
	
        local cAmountBtn  = findDesc(upgradeFrame, "CrystalAmountButton")
        local cAmountInfo = findDesc(upgradeFrame, "CrystalAmountInfo")
        local cRateBtn    = findDesc(upgradeFrame, "CrystalRateButton")
        local cRateInfo   = findDesc(upgradeFrame, "CrystalRateInfo")

	if not (amountBtn and amountInfo and rateBtn and rateInfo and
	        cAmountBtn and cAmountInfo and cRateBtn and cRateInfo) then
                warn("[ShopController] Faltan labels/botones dentro de UpgradeShopFrame")
                return
        end

	
        local UPGRADE = {
                RockAmount        = { base = 25,  mult = 1.3, start = 5 },
                SpawnRate         = { base = 50,  mult = 1.5, start = 4.0, step = 0.25, min = 0.5 },
                CrystalAmount     = { base = 75,  mult = 1.4, start = 0 },
                CrystalSpawnRate  = { base = 100, mult = 1.6, start = 8.0, step = 0.5,  min = 2.0 },
        }

        local GREEN = Color3.fromRGB(40,167,69)
        local RED   = Color3.fromRGB(220,53,69)

        local function playUpgradeSfx()
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local pos = root and root.Position or Vector3.new()
                SoundManager:playSound("Upgrade", pos)
        end

        local function animateButton(btn)
                local uiScale = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
                local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                TweenService:Create(uiScale, tweenInfo, { Scale = 1.1 }):Play()
                task.delay(0.15, function()
                        TweenService:Create(uiScale, tweenInfo, { Scale = 1 }):Play()
                end)
        end

        local function connectUpgrade(btn, upgradeName)
                btn.Activated:Connect(function()
                        if not btn.Active then return end
                        animateButton(btn)
                        playUpgradeSfx()
                        upgradeEvent:FireServer(upgradeName)
                end)
        end

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

        
        upgradeFrame.Visible = false
       
       local shopFolder = workspace:FindFirstChild("Shops", true)
       if not shopFolder then
               warn("[ShopController] No encontré carpeta 'Shops' en Workspace")
               return
       end

       print("[ShopController] shopFolder", shopFolder:GetFullName())

       local upShop = shopFolder:FindFirstChild("UpgradesShop", true) or shopFolder:FindFirstChild("UpgradeShop", true)
       if not upShop then
               warn("[ShopController] No encontré UpgradesShop dentro de 'Shops'")
       else
               print("[ShopController] upShop", upShop:GetFullName())
       end

       local prompt = upShop and upShop:FindFirstChild("ProximityPrompt", true)
       if prompt then
               print("[ShopController] prompt", prompt:GetFullName())
               prompt.Triggered:Connect(function()
                       upgradeFrame.Visible = not upgradeFrame.Visible
                       print("[ShopController] UpgradeShop toggled ->", upgradeFrame.Visible)
                       if upgradeFrame.Visible then update() end
               end)
       else
               warn("[ShopController] No encontré ProximityPrompt en UpgradesShop")
       end

        
        if robuxFrame then
                robuxFrame.Visible = false

                if robuxBtn then
                        print("[ShopController] robuxBtn connected", robuxBtn:GetFullName())
                        robuxBtn.Activated:Connect(function()
                                robuxFrame.Visible = not robuxFrame.Visible
                                print("[ShopController] RobuxShop toggled ->", robuxFrame.Visible)
                        end)
                else
                        warn("[ShopController] No encontré OpenShopButton")
                end

                
                local statsGui      = playerGui:FindFirstChild("PlayerStatsGui") or findDesc(playerGui, "PlayerStatsGui")
                local statsContainer = statsGui and (statsGui:FindFirstChild("Container") or findDesc(statsGui, "Container"))
                local gemsCounter   = statsContainer and (statsContainer:FindFirstChild("GemsCounter") or findDesc(statsContainer, "GemsCounter"))
                local stonesCounter = statsContainer and (statsContainer:FindFirstChild("StonesCounter") or findDesc(statsContainer, "StonesCounter"))
                local gemsBtn       = gemsCounter and (gemsCounter:FindFirstChild("ImageButton") or findDesc(gemsCounter, "ImageButton"))
                local stonesBtn     = stonesCounter and (stonesCounter:FindFirstChild("ImageButton") or findDesc(stonesCounter, "ImageButton"))

                print("[ShopController] gemsBtn", gemsBtn)
                print("[ShopController] stonesBtn", stonesBtn)

                local function openShop(source)
                        robuxFrame.Visible = true
                        print("[ShopController] RobuxShop open via", source)
                end
                if gemsBtn then
                        gemsBtn.Activated:Connect(function() openShop("gems") end)
                end
                if stonesBtn then
                        stonesBtn.Activated:Connect(function() openShop("stones") end)
                end
        end

        
        connectUpgrade(amountBtn, "RockAmount")
        connectUpgrade(rateBtn, "SpawnRate")
        connectUpgrade(cAmountBtn, "CrystalAmount")
        connectUpgrade(cRateBtn, "CrystalSpawnRate")

	
	gems.Changed:Connect(update)
	upgrades.RockAmount.Changed:Connect(update)
	upgrades.SpawnRate.Changed:Connect(update)
	upgrades.CrystalAmount.Changed:Connect(update)
	upgrades.CrystalSpawnRate.Changed:Connect(update)

	update()
	print("[ShopController] listo")
end

return M
