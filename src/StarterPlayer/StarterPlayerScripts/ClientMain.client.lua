
local root        = script.Parent
local modulesPath = root:WaitForChild("ClientModules")
local controllers = root:WaitForChild("Controllers")

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

player:SetAttribute("ClientMainReady", false)

local function loadModule(container, path)
        local inst = container
        for name in string.gmatch(path, "[^/]+") do
                inst = inst:WaitForChild(name)
        end
        if not inst:IsA("ModuleScript") then
                warn(("[ClientMain] %s no es ModuleScript (es %s)"):format(path, inst.ClassName))
                return nil
        end
        local ok, res = pcall(require, inst)
        if not ok then
                warn(("[ClientMain] require %s ERROR: %s"):format(path, res))
                return nil
        end
        if type(res) ~= "table" then
                warn(("[ClientMain] %s no devolvió una tabla"):format(path))
                return nil
        end
        return res
end

local function call(mod, method, ...)
	if type(mod) ~= "table" or type(mod[method]) ~= "function" then return end
	
	local args = table.pack(...)
	local ok, err = pcall(function()
		
		return mod[method](mod, table.unpack(args, 1, args.n))
	end)
	if ok then
                print(("[ClientMain] %s.%s OK"):format(tostring(mod), method))
	else
                warn(("[ClientMain] %s.%s ERROR: %s"):format(tostring(mod), method, tostring(err)))
	end
end

local UIController         = loadModule(controllers, "UIController")         or {}
local MiningController     = loadModule(controllers, "PickFall/MiningController")     or {}
local InputController      = loadModule(controllers, "InputController")      or {} 
local ShopController       = loadModule(controllers, "Plot/ShopController")       or {}
local TPButtons            = loadModule(controllers, "Plot/TPButtons")            or {}
local PickaxeShopController = loadModule(controllers, "PickaxeShopController") or {}
local CloseButtonController= loadModule(controllers, "CloseButtonController") or {}
local PickfallController   = loadModule(controllers, "PickFall/PickfallController")   or {}
local SaleDialogController = loadModule(controllers, "SaleDialogController") or {}

local SoundManager         = loadModule(modulesPath, "SoundManager")         or {}

local function initControllers(character)
    print(("[ClientMain] Personaje disponible: %s"):format(character:GetFullName()))
    print("[ClientMain] Esperando HumanoidRootPart...")
    character:WaitForChild("HumanoidRootPart")
    print("[ClientMain] HumanoidRootPart encontrado, iniciando controladores.")

    player:SetAttribute("ClientMainReady", true)

    print("[ClientMain] Inicializando UIController.init")
    call(UIController,     "init")
    print("[ClientMain] Inicializando MiningController.start")
    call(MiningController, "start", nil, SoundManager)

    if type(InputController.init) == "function" then
        print("[ClientMain] Inicializando InputController.init")
        local ok, err = pcall(function() InputController.init() end)
        print(ok and "[ClientMain] InputController.init OK"
              or   ("[ClientMain] InputController.init ERROR: "..tostring(err)))
    else
        print("[ClientMain] InputController loaded (side-effect).")
    end

    print("[ClientMain] Inicializando ShopController.init")
    call(ShopController,       "init")
    print("[ClientMain] Inicializando TPButtons.init")
    call(TPButtons,            "init")
    print("[ClientMain] Inicializando ShopPromptController.init")
    call(PickaxeShopController, "init")
    print("[ClientMain] Inicializando CloseButtonController.init")
    call(CloseButtonController,"init")
    print("[ClientMain] Inicializando PickfallController.init")
    call(PickfallController, "init")
    print("[ClientMain] Inicializando SaleDialogController.init")
    call(SaleDialogController, "init")

    print("--- ClientMain: controllers initialized (UI, Mining, Input, ShopUI, TP, ShopPrompt, CloseButtons).")
end

local function onCharacterAdded(character)
    player:SetAttribute("ClientMainReady", false)
    initControllers(character)
end

player.CharacterAdded:Connect(onCharacterAdded)

local current = player.Character
if current then
    onCharacterAdded(current)
else
    print("[ClientMain] Esperando a que el personaje esté disponible...")
end

