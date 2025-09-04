-- ContextReport.server — solo diagnóstico
local function safeRequire(mod)
	local ok, res = pcall(require, mod)
	if not ok then
		return nil, ("require ERROR: %s"):format(res)
	end
	return res, nil
end

local function listKeys(tbl)
	local keys = {}
	for k,_ in pairs(tbl) do table.insert(keys, tostring(k)) end
	table.sort(keys)
	return table.concat(keys, ", ")
end

print("=== [ContextReport.server] INICIO ===")

-- ReplicatedStorage/Remotes
do
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:FindFirstChild("Remotes")
	if remotes then
		local names = {}
		for _,obj in ipairs(remotes:GetChildren()) do
			table.insert(names, ("%s(%s)"):format(obj.Name, obj.ClassName))
		end
		table.sort(names)
		print("[Remotes] -> " .. table.concat(names, " | "))
	else
		warn("[Remotes] Carpeta 'Remotes' no encontrada")
	end
end

-- PlotManager (tu versión)
do
        local PMpath = game.ServerScriptService:FindFirstChild("Modules") and game.ServerScriptService.Modules:FindFirstChild("PlotManager")
                or game.ServerScriptService:FindFirstChild("PlotManager")
	if PMpath then
		local pm, err = safeRequire(PMpath)
		if pm then
			local keys = (type(pm)=="table") and listKeys(pm) or "(módulo no devuelve tabla)"
			print("[PlotManager] Keys:", keys)
		else
			warn("[PlotManager] "..err)
		end
	else
		warn("[PlotManager] no encontrado")
	end
end

-- ServerScriptService módulos
do
	local function scanFolder(folder, label)
		local items = {}
		for _,obj in ipairs(folder:GetChildren()) do
			if obj:IsA("ModuleScript") then
				local t, e = safeRequire(obj)
				if type(t)=="table" then
					table.insert(items, ("%s: {%s}"):format(obj.Name, listKeys(t)))
				else
					table.insert(items, ("%s: (%s)"):format(obj.Name, e or "no devuelve tabla"))
				end
			end
		end
		if #items>0 then
			print(label.." -> "..table.concat(items, " || "))
		end
	end

        scanFolder(game.ServerScriptService, "[SSS]")
        local sm = game.ServerScriptService:FindFirstChild("Modules")
        if sm then scanFolder(sm, "[Modules]") end
end

-- Workspace estructura base
do
	local hub = workspace:FindFirstChild("Hub")
	local plots = workspace:FindFirstChild("Plots")
	print("[Workspace] Hub:", hub and "OK" or "FALTA", " | Plots:", plots and "OK" or "FALTA")
       if hub and hub:FindFirstChild("Shops") then
               local shopNames = {}
               for _,p in ipairs(hub.Shops:GetChildren()) do table.insert(shopNames, p.Name) end
               table.sort(shopNames); print("[Shops] -> "..table.concat(shopNames, ", "))
	end
	if plots then
		local plotNames = {}
		for _,m in ipairs(plots:GetChildren()) do
			if m:IsA("Model") then table.insert(plotNames, m.Name) end
		end
		table.sort(plotNames); print("[Plots] -> "..table.concat(plotNames, ", "))
	end
end

print("=== [ContextReport.server] FIN ===")
