-- MainController.client — robusto y sin sorpresas
local root        = script.Parent
local modulesPath = root:WaitForChild("Modules")
local controllers = root:WaitForChild("Controllers")

-- Esperar a que el personaje del jugador esté listo antes de iniciar
local Players = game:GetService("Players")
local player  = Players.LocalPlayer


-- Evitar doble inicialización si existe otra copia del script
if player:GetAttribute("MainControllerReady") then
       print("[MainController] Controladores ya inicializados, omitiendo.")
       return
end

print("[MainController] Esperando a que el personaje esté disponible...")
local character = player.Character or player.CharacterAdded:Wait()
print(("[MainController] Personaje disponible: %s"):format(character:GetFullName()))
print("[MainController] Esperando HumanoidRootPart...")
character:WaitForChild("HumanoidRootPart")
print("[MainController] HumanoidRootPart encontrado, iniciando controladores.")

player:SetAttribute("MainControllerReady", true)

local function loadModule(container, name)
	local inst = container:WaitForChild(name)
	if not inst:IsA("ModuleScript") then
		warn(("[MainController] %s no es ModuleScript (es %s)"):format(name, inst.ClassName))
		return nil
	end
	local ok, res = pcall(require, inst)
	if not ok then
		warn(("[MainController] require %s ERROR: %s"):format(name, res))
		return nil
	end
	if type(res) ~= "table" then
		warn(("[MainController] %s no devolvió una tabla"):format(name))
		return nil
	end
	return res
end

local function call(mod, method, ...)
	if type(mod) ~= "table" or type(mod[method]) ~= "function" then return end
	-- Captura varargs antes de entrar al closure
	local args = table.pack(...)
	local ok, err = pcall(function()
		-- estilo ':' -> pasamos self (mod) como primer arg
		return mod[method](mod, table.unpack(args, 1, args.n))
	end)
	if ok then
		print(("[MainController] %s.%s OK"):format(tostring(mod), method))
	else
		warn(("[MainController] %s.%s ERROR: %s"):format(tostring(mod), method, tostring(err)))
	end
end

-- Controladores (todos como ModuleScript .lua)
local UIController         = loadModule(controllers, "UIController")         or {}
local MiningController     = loadModule(controllers, "MiningController")     or {}
local InputController      = loadModule(controllers, "InputController")      or {} -- side-effect
local ShopController       = loadModule(controllers, "ShopController")       or {}
local TPButtons            = loadModule(controllers, "TPButtons")            or {}
local ShopPromptController = loadModule(controllers, "ShopPromptController") or {}
local CloseButtonController= loadModule(controllers, "CloseButtonController") or {}
local SaleDialogController = loadModule(controllers, "SaleDialogController") or {}

-- Módulos
local SoundManager         = loadModule(modulesPath, "SoundManager")         or {}

-- Orden: UI -> Mining -> (Input side-effect) -> ShopUI -> TP -> ShopPrompt
print("[MainController] Inicializando UIController.init")
call(UIController,     "init")
print("[MainController] Inicializando MiningController.start")
call(MiningController, "start", nil, SoundManager)

if type(InputController.init) == "function" then
print("[MainController] Inicializando InputController.init")
local ok, err = pcall(function() InputController.init() end)
print(ok and "[MainController] InputController.init OK"
      or   ("[MainController] InputController.init ERROR: "..tostring(err)))
else
print("[MainController] InputController loaded (side-effect).")
end

print("[MainController] Inicializando ShopController.init")
call(ShopController,       "init")
print("[MainController] Inicializando TPButtons.init")
call(TPButtons,            "init")
print("[MainController] Inicializando ShopPromptController.init")
call(ShopPromptController, "init")
print("[MainController] Inicializando CloseButtonController.init")
call(CloseButtonController,"init")
print("[MainController] Inicializando SaleDialogController.init")
call(SaleDialogController, "init")

print("--- MainController: controllers initialized (UI, Mining, Input, ShopUI, TP, ShopPrompt, CloseButtons). ---")
