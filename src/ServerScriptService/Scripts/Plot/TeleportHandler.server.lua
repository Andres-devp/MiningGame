
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local plotsFolder = workspace:WaitForChild("Plots")

local shops = workspace:FindFirstChild("Shops", true)
if not shops then
       warn("[TeleportHandler] No encontré carpeta 'Shops' en Workspace")
       return
end

print("[TeleportHandler] shops", shops:GetFullName())

local toPlot = Remotes:WaitForChild("TeleportToPlot")
local toShop = Remotes:WaitForChild("TeleportToShop")

local function getPlayerPlotModel(plr)
	
	local pn = plr:FindFirstChild("PlotName")
	if pn and pn.Value ~= "" then
		local mdl = plotsFolder:FindFirstChild(pn.Value)
		if mdl then return mdl end
	end
	
        local ok, PM = pcall(function()
                return require(game.ServerScriptService.ServerModules:WaitForChild("Plot"):WaitForChild("PlotManager"))
        end)
	if ok and PM and PM.plotsData then
		for _, data in pairs(PM.plotsData) do
			if data.owner == plr.UserId then
				return data.model
			end
		end
	end
	return nil
end

local function pivotCharacter(char, cf)
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3))
	if hrp and cf then
		hrp.CFrame = cf + Vector3.new(0, 3, 0)
	end
end

toPlot.OnServerEvent:Connect(function(plr)
	local model = getPlayerPlotModel(plr)
	if not model then return end
	
	local tp = model:FindFirstChild("TeleportPoint") or model:FindFirstChild("Spawn")
	if not tp then return end
	local char = plr.Character or plr.CharacterAdded:Wait()
	pivotCharacter(char, tp.CFrame)
end)

toShop.OnServerEvent:Connect(function(plr, shopName)
       shopName = tostring(shopName or "")
       local shop = shops:FindFirstChild(shopName, true)
       if not shop then
               warn("[TeleportHandler] No encontré tienda", shopName)
               return
       end
       print("[TeleportHandler] TeleportToShop", plr.Name, "->", shop:GetFullName())
       local char = plr.Character or plr.CharacterAdded:Wait()
       pivotCharacter(char, shop.CFrame)
end)
