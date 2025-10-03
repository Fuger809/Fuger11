-- ========= [ Fluent UI и менеджеры ] =========
local Library = loadstring(game:HttpGetAsync("https://github.com/1dontgiveaf/Fluent-Renewed/releases/download/v1.0/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/1dontgiveaf/Fluent-Renewed/refs/heads/main/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/1dontgiveaf/Fluent-Renewed/refs/heads/main/Addons/InterfaceManager.luau"))()

-- ========= [ Services / utils ] =========
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

local function ensureChar()
    char = plr.Character or plr.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
end
plr.CharacterAdded:Connect(function() task.defer(ensureChar) end)

-- ========= [ Packets (без ошибок, если модуля нет) ] =========
local packets do
    local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Packets")) end)
    packets = ok and mod or {}
end
local function swingtool(eids)
    if type(eids) ~= "table" then eids = { eids } end
    if packets and packets.SwingTool and packets.SwingTool.send then
        pcall(function() packets.SwingTool.send(eids) end)
    end
end
local function pickup(eid)
    if packets and packets.Pickup and packets.Pickup.send then
        pcall(function() packets.Pickup.send(eid) end)
    end
end

-- ========= [ Window / Tabs ] =========
local Window = Library:CreateWindow{
    Title = "Fuger Hub -- Booga Booga Reborn",
    SubTitle = "by Fuger XD",
    Size = UDim2.fromOffset(840, 560),
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
}
local Tabs = {}
Tabs.Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

-- менеджеры
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- ========= [ Helpers ] =========
local function sanitize(name)
    name = tostring(name or ""):gsub("[%c\\/:*?\"<>|]+",""):gsub("^%s+",""):gsub("%s+$","")
    return name == "" and "default" or name
end

-- === [ RouteLock: общий замок для Route/Follow — убирает чужие силы ] ===
_G.__ROUTE_LOCK = _G.__ROUTE_LOCK or {count = 0, active = false}
local function RouteLock(on)
    local L = _G.__ROUTE_LOCK
    if on then L.count = L.count + 1 else L.count = math.max(0, L.count - 1) end
    L.active = (L.count > 0)

    local c = Players.LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r and L.active then
        for _,o in ipairs(r:GetChildren()) do
            if o:IsA("BodyVelocity") or o:IsA("LinearVelocity")
            or o:IsA("VectorForce")  or o:IsA("BodyForce")
            or o:IsA("BodyThrust") then
                o:Destroy()
            end
        end
        local a = r:FindFirstChild("_MV_BV");    if a then a:Destroy() end
        local b = r:FindFirstChild("_ROUTE_BV"); if b then b:Destroy() end
        local c1 = r:FindFirstChild("_FLW_BV");  if c1 then c1:Destroy() end
        r.Anchored = false
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    return L.active
end

-- ========= [ ROUTE persist (save/load) ] =========
local function routePath(cfg) return "FluentScriptHub/specific-game/"..sanitize(cfg)..".route.json" end
local ROUTE_AUTOSAVE = "FluentScriptHub/specific-game/_route_autosave.json"

local function encodeRoute(points)
    local t = {}
    for i,p in ipairs(points or {}) do
        t[i] = {
            x = p.pos.X, y = p.pos.Y, z = p.pos.Z,
            wait = p.wait or 0,
            js = p.jump_start and true or nil,
            je = p.jump_end   and true or nil,
        }
    end
    return t
end
local function decodeRoute(t)
    local out = {}
    for _,r in ipairs(t or {}) do
        table.insert(out, {
            pos = Vector3.new(r.x, r.y, r.z),
            wait = (r.wait and r.wait > 0) and r.wait or nil,
            jump_start = r.js or nil,
            jump_end   = r.je or nil
        })
    end
    return out
end
function Route_SaveToFile(path, points)
    if not writefile then return false end
    local ok, json = pcall(function() return HttpService:JSONEncode(encodeRoute(points)) end)
    if not ok then return false end
    local ok2 = pcall(writefile, path, json)
    return ok2 == true or ok2 == nil
end
function Route_LoadFromFile(path, Route, redraw)
    if not (isfile and readfile) or not isfile(path) then return false end
    local ok, json = pcall(readfile, path); if not ok then return false end
    local ok2, arr = pcall(function() return HttpService:JSONDecode(json) end); if not ok2 then return false end
    table.clear(Route.points)
    if redraw and redraw.clearDots then redraw.clearDots() end
    for _,p in ipairs(decodeRoute(arr)) do
        table.insert(Route.points, p)
        if redraw and redraw.dot then redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7) end
    end
    return true
end

-- ========= [ Общие инвентарь/еды ] =========
function findInventoryList()
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return nil end
    local mg = pg:FindFirstChild("MainGui");    if not mg then return nil end
    local rp = mg:FindFirstChild("RightPanel"); if not rp then return nil end
    local inv = rp:FindFirstChild("Inventory"); if not inv then return nil end
    return inv:FindFirstChild("List")
end
function getSlotByName(itemName)
    local list = findInventoryList()
    if not list then return nil end
    for _,child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemName then
            return child.LayoutOrder
        end
    end
    return nil
end
function consumeBySlot(slot)
    if not slot then return false end
    if packets and packets.UseBagItem     and packets.UseBagItem.send     then pcall(function() packets.UseBagItem.send(slot) end);     return true end
    if packets and packets.ConsumeBagItem and packets.ConsumeBagItem.send then pcall(function() packets.ConsumeBagItem.send(slot) end); return true end
    if packets and packets.ConsumeItem    and packets.ConsumeItem.send    then pcall(function() packets.ConsumeItem.send(slot) end);    return true end
    if packets and packets.UseItem        and packets.UseItem.send        then pcall(function() packets.UseItem.send(slot) end);        return true end
    return false
end
_G.fruittoitemid = _G.fruittoitemid or {
    Bloodfruit = 94, Bluefruit = 377, Lemon = 99, Coconut = 1, Jelly = 604,
    Banana = 606, Orange = 602, Oddberry = 32, Berry = 35, Strangefruit = 302,
    Strawberry = 282, Sunfruit = 128, Pumpkin = 80, ["Prickly Pear"] = 378,
    Apple = 243, Barley = 247, Cloudberry = 101, Carrot = 147
}
function getItemIdByName(name) local t=_G.fruittoitemid return t and t[name] or nil end
function consumeById(id)
    if not id then return false end
    if packets and packets.ConsumeItem and packets.ConsumeItem.send then pcall(function() packets.ConsumeItem.send(id) end); return true end
    if packets and packets.UseItem     and packets.UseItem.send     then pcall(function() packets.UseItem.send({itemID = id}) end); return true end
    if packets and packets.Eat         and packets.Eat.send         then pcall(function() packets.Eat.send(id) end); return true end
    if packets and packets.EatFood     and packets.EatFood.send     then pcall(function() packets.EatFood.send(id) end); return true end
    return false
end

-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })

local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input", { Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)

Tabs.Configs:CreateButton({
    Title = "Quick Save",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), (_G.__ROUTE and _G.__ROUTE.points) or {})
        Route_SaveToFile(ROUTE_AUTOSAVE, (_G.__ROUTE and _G.__ROUTE.points) or {})
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title = "Quick Load",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        if _G.__ROUTE then
            local ok = Route_LoadFromFile(routePath(n), _G.__ROUTE, _G.__ROUTE._redraw)
            Library:Notify{
                Title="Configs",
                Content="Loaded "..n..(ok and " +route" or " (no route file)"),
                Duration=3
            }
        else
            Library:Notify{ Title="Configs", Content="Loaded "..n, Duration=3 }
        end
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg", { Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)

-- === [ переносимый экспорт/импорт ROUTE ] ===
do
    local function Route_ToString()
        local arr = encodeRoute((_G.__ROUTE and _G.__ROUTE.points) or {})
        local ok, json = pcall(function() return HttpService:JSONEncode(arr) end)
        return ok and json or "[]"
    end
    local function Route_FromString(str)
        if type(str) ~= "string" or str == "" then return false, "empty" end
        local ok, t = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(t) ~= "table" then return false, "bad json" end
        if not _G.__ROUTE then return false, "no route obj" end
        local points = decodeRoute(t)
        table.clear(_G.__ROUTE.points)
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.clearDots then _G.__ROUTE._redraw.clearDots() end
        for _,p in ipairs(points) do
            table.insert(_G.__ROUTE.points, p)
            if _G.__ROUTE._redraw and _G.__ROUTE._redraw.dot then
                _G.__ROUTE._redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
            end
        end
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.redrawLines then
            _G.__ROUTE._redraw.redrawLines()
        end
        return true
    end

    local routeStr = ""
    local routeInput = Tabs.Configs:AddInput("cfg_route_string", {
        Title="Route JSON (paste here to import)",
        Default="",
        Placeholder="сюда вставь длинную строку JSON маршрута"
    })
    routeInput:OnChanged(function(v) routeStr = tostring(v or "") end)

    Tabs.Configs:CreateButton({
        Title="Fill input from CURRENT route",
        Callback=function()
            local s = Route_ToString()
            routeStr = s
            routeInput:SetValue(s)
            Library:Notify{ Title="Route", Content="Input filled from current route", Duration=2 }
        end
    })
    Tabs.Configs:CreateButton({
        Title="Copy CURRENT route (JSON) to Clipboard",
        Callback=function()
            local s = Route_ToString()
            if setclipboard then
                pcall(setclipboard, s)
                Library:Notify{ Title="Route", Content="Copied to clipboard!", Duration=2 }
            else
                print("[ROUTE JSON]\n"..s)
                Library:Notify{ Title="Route", Content="setclipboard недоступен — строка в F9", Duration=4 }
            end
        end
    })
    Tabs.Configs:CreateButton({
        Title="Load route from INPUT (replace current)",
        Callback=function()
            local ok, err = Route_FromString(routeStr)
            if ok then
                Library:Notify{ Title="Route", Content="Route loaded from input", Duration=3 }
                pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, _G.__ROUTE.points) end)
            else
                Library:Notify{ Title="Route", Content="Import failed: "..tostring(err), Duration=4 }
            end
        end
    })
end

-- ==== GOLD FULL CONFIG (flags + route с паузами) ====
do
    local GOLDCFG_NAME = "gold"
    local GOLDCFG_PATH = "FluentScriptHub/specific-game/"..GOLDCFG_NAME..".fullcfg.json"
    local GOLDCFG_AUTO = "FluentScriptHub/specific-game/_autoload_gold_full.txt"
    local ROUTE_AUTOSAVE_PATH = "FluentScriptHub/specific-game/_route_autosave.json"

    local function gold_flags_copy()
        local out, F = {}, (Library and Library.Flags) or {}
        for k,v in pairs(F) do
            local t = typeof(v)
            if t=="boolean" or t=="number" or t=="string" then out[k]=v end
        end
        return out
    end
    local function gold_flags_apply(tbl)
        if type(tbl)~="table" then return end
        local Opts = (Library and Library.Options) or {}
        local F    = (Library and Library.Flags) or {}
        for k,v in pairs(tbl) do
            local opt = Opts[k]
            if opt and opt.SetValue then pcall(function() opt:SetValue(v) end) else F[k]=v end
        end
    end

    local function gold_route_to_array()
        local arr, pts = {}, (_G.__ROUTE and _G.__ROUTE.points) or {}
        for i,p in ipairs(pts) do
            arr[i] = {
                x=p.pos.X, y=p.pos.Y, z=p.pos.Z,
                wait = (p.wait and p.wait>0) and p.wait or 0,
                js = p.jump_start or false,
                je = p.jump_end   or false
            }
        end
        return arr
    end
    local function gold_apply_route_array(arr)
        if not _G.__ROUTE then return false end
        local R = _G.__ROUTE
        local rd = R._redraw
        if rd and rd.clearDots then rd.clearDots() end
        table.clear(R.points)
        for _,r in ipairs(arr or {}) do
            local pt = { pos = Vector3.new(r.x, r.y, r.z) }
            if (tonumber(r.wait) or 0) > 0 then pt.wait = tonumber(r.wait) end
            if r.js then pt.jump_start = true end
            if r.je then pt.jump_end   = true end
            table.insert(R.points, pt)
            if rd and rd.dot then
                local col = (pt.wait and pt.wait>0) and Color3.fromRGB(230,75,75) or Color3.fromRGB(255,230,80)
                rd.dot(col, pt.pos, 0.7)
            end
        end
        if rd and rd.redrawLines then rd.redrawLines() end
        return true
    end

    local function gold_save()
        local pkg = { flags = gold_flags_copy(), route = gold_route_to_array() }
        local ok, json = pcall(function() return HttpService:JSONEncode(pkg) end)
        if not ok or not writefile then return false end
        local ok2 = pcall(writefile, GOLDCFG_PATH, json)
        -- Пишем ещё и в autosave, чтобы follow позже подхватил даже если __ROUTE ещё не создан
        pcall(function()
            local rjson = HttpService:JSONEncode(pkg.route or {})
            writefile(ROUTE_AUTOSAVE_PATH, rjson)
        end)
        return ok2 == true or ok2 == nil
    end

    local function gold_load()
        if not (isfile and readfile) or not isfile(GOLDCFG_PATH) then return false end
        local ok, json = pcall(readfile, GOLDCFG_PATH); if not ok then return false end
        local ok2, pkg = pcall(function() return HttpService:JSONDecode(json) end); if not ok2 then return false end

        if type(pkg.flags)=="table" then gold_flags_apply(pkg.flags) end

        -- 1) сразу положим маршрут в autosave (с сохранёнными wait)
        if type(pkg.route)=="table" then
            pcall(function()
                local rjson = HttpService:JSONEncode(pkg.route)
                writefile(ROUTE_AUTOSAVE_PATH, rjson)
            end)
            -- 2) если __ROUTE уже есть — применим немедленно (визуал + паузы)
            if _G.__ROUTE then
                gold_apply_route_array(pkg.route)
            end
        end
        return true
    end

    local function gold_set_autoload(on)
        if not writefile then return end
        pcall(writefile, GOLDCFG_AUTO, on and "1" or "")
    end
    local function gold_should_autoload()
        return (isfile and readfile and isfile(GOLDCFG_AUTO) and (readfile(GOLDCFG_AUTO) or "") ~= "")
    end

    -- Кнопки на вкладке Configs
    Tabs.Configs:CreateButton({
        Title = "Save GOLD cfg (flags + route)",
        Callback = function()
            local ok = gold_save()
            Library:Notify{ Title="GOLD cfg", Content = ok and "Saved" or "Save failed", Duration=3 }
        end
    })
    Tabs.Configs:CreateButton({
        Title = "Load GOLD cfg",
        Callback = function()
            local ok = gold_load()
            Library:Notify{ Title="GOLD cfg", Content = ok and "Loaded" or "Load failed / not found", Duration=3 }
        end
    })
    local gold_auto_toggle = Tabs.Configs:CreateToggle("gold_autoload", { Title="Auto load GOLD cfg", Default=true })
    gold_auto_toggle:OnChanged(function(v)
        gold_set_autoload(v)
        Library:Notify{ Title="GOLD cfg", Content = v and "Autoload ON" or "Autoload OFF", Duration=2 }
    end)

    -- === Перенос GOLD между девайсами (буфер/вставка) ===
    local importStr = ""
    local goldInput = Tabs.Configs:AddInput("gold_import_input", {
        Title       = "GOLD JSON (вставь сюда на втором устройстве)",
        Default     = "",
        Placeholder = "ПК: Save GOLD → Copy GOLD → тут вставь → Import GOLD"
    })
    goldInput:OnChanged(function(v) importStr = tostring(v or "") end)

    Tabs.Configs:CreateButton({
        Title = "Copy GOLD to Clipboard",
        Callback = function()
            if not (isfile and readfile and isfile(GOLDCFG_PATH)) then
                Library:Notify{ Title="GOLD", Content="Файл не найден. Сначала нажми Save GOLD.", Duration=3 }
                return
            end
            local ok, data = pcall(readfile, GOLDCFG_PATH)
            if not ok then
                Library:Notify{ Title="GOLD", Content="Не удалось прочитать GOLD файл", Duration=3 }
                return
            end
            if setclipboard then
                pcall(setclipboard, data)
                Library:Notify{ Title="GOLD", Content="Скопировано в буфер обмена!", Duration=3 }
            else
                print("[GOLD JSON]\n"..data)
                Library:Notify{ Title="GOLD", Content="Нет доступа к буферу — JSON в F9 консоли", Duration=4 }
            end
        end
    })

    Tabs.Configs:CreateButton({
        Title = "Import GOLD (из поля выше)",
        Callback = function()
            local raw = importStr
            if type(raw) ~= "string" or raw == "" then
                Library:Notify{ Title="GOLD", Content="Пустой ввод", Duration=3 }
                return
            end
            local ok, pkg = pcall(function() return HttpService:JSONDecode(raw) end)
            if not ok or type(pkg) ~= "table" then
                Library:Notify{ Title="GOLD", Content="Неверный JSON", Duration=3 }
                return
            end
            -- применяем флаги
            if type(pkg.flags)=="table" then gold_flags_apply(pkg.flags) end
            -- сохраняем на этом устройстве и синхроним autosave маршрута
            pcall(function() writefile(GOLDCFG_PATH, raw) end)
            pcall(function() writefile(ROUTE_AUTOSAVE_PATH, HttpService:JSONEncode(pkg.route or {})) end)
            -- если есть __ROUTE — сразу визуал и паузы
            if _G.__ROUTE and type(pkg.route)=="table" then gold_apply_route_array(pkg.route) end
            Library:Notify{ Title="GOLD", Content="Импортировано. Маршрут + паузы применены.", Duration=4 }
        end
    })

    -- Автозагрузка при старте:
    task.spawn(function()
        if not gold_should_autoload() then return end
        -- читаем пакет
        if (isfile and readfile and isfile(GOLDCFG_PATH)) then
            local ok,json = pcall(readfile, GOLDCFG_PATH)
            local ok2,pkg = ok and pcall(function() return HttpService:JSONDecode(json) end) or false, nil
            if ok2 and type(pkg)=="table" then
                gold_flags_apply(pkg.flags or {})
                -- кладём в autosave (так твой поздний автозагрузчик тоже увидит все wait)
                pcall(function() writefile(ROUTE_AUTOSAVE_PATH, HttpService:JSONEncode(pkg.route or {})) end)
                -- ждём появления __ROUTE и применяем с визуалом
                local t0 = tick()
                while not _G.__ROUTE and tick()-t0 < 10 do task.wait(0.1) end
                if _G.__ROUTE and type(pkg.route)=="table" then gold_apply_route_array(pkg.route) end
                Library:Notify{ Title="GOLD cfg", Content="Autoloaded GOLD cfg (with waits)", Duration=3 }
            end
        end
    end)
end

-- ========= [ TAB: Survival (Auto-Eat) ] =========
Tabs.Survival = Window:AddTab({ Title="Survival", Icon="apple" })
local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title="Auto Eat (Hunger)", Default=false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title="Food to eat",
    Values={"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default="Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title="Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title="Debug logs (F9)", Default=false })

local function normPct(n) if type(n)~="number" then return nil end if n<=1.5 then n=n*100 end return math.clamp(n,0,100) end
local function readHungerFromValues() for _,v in ipairs(plr:GetDescendants()) do if v.Name=="Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then return normPct(v.Value) end end end
local function readHungerFromBar()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg=pg:FindFirstChild("MainGui"); if not mg then return end
    local bars=mg:FindFirstChild("Bars"); if not bars then return end
    local hb=bars:FindFirstChild("Hunger")
    if hb and hb:IsA("Frame") and hb.Size and hb.Size.X and typeof(hb.Size.X.Scale)=="number" then
        return normPct(hb.Size.X.Scale)
    end
end
local function readHungerFromText()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _,inst in ipairs(pg:GetDescendants()) do
        if inst:IsA("TextLabel") then
            local txt=tostring(inst.Text or ""):lower()
            if txt:find("голод") or inst.Name:lower():find("hunger") or (inst.Parent and inst.Parent.Name:lower():find("hunger")) then
                local num=tonumber(txt:match("([-+]?%d+%.?%d*)"))
                if num and num>=0 and num<=100 then return num end
            end
        end
    end
end
local function readHungerFromAttr() local a=plr:GetAttribute("Hunger") if typeof(a)=="number" then return normPct(a) end end
local function readHungerPercent() return readHungerFromValues() or readHungerFromBar() or readHungerFromText() or readHungerFromAttr() or 100 end

local eatingLock=false
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ae_toggle.Value then continue end
        local target=ae_thresh.Value
        local mode=ae_mode.Value
        local cur=readHungerPercent()
        local need = (mode=="Fullness 100→0" and cur<target) or (mode=="Hunger 0→100" and cur>target)
        if need and not eatingLock then
            eatingLock=true
            task.spawn(function()
                local tries, maxTries = 0, 25
                local minDelay, band = 0.15, 0.5
                while ae_toggle.Value and tries<maxTries do
                    cur=readHungerPercent()
                    local okNow=(mode=="Fullness 100→0" and cur>=target-band) or (mode=="Hunger 0→100" and cur<=target+band)
                    if okNow then if ae_debug.Value then print(("[AutoEat] reached: %.1f / %d (%s)"):format(cur,target,mode)) end; break end
                    local food=ae_food.Value or "Bloodfruit"
                    local ate=consumeBySlot(getSlotByName(food)) or consumeById(getItemIdByName(food))
                    if ae_debug.Value then print(("[AutoEat] try=%d -> %s"):format(tries + 1, ate and "EAT" or "MISS")) end
                    tries = tries + 1; task.wait(minDelay)
                end
                eatingLock=false
            end)
        end
    end
end)

-- ========= [ TAB: Break (Radius) — v2 (cached, low-lag, multi-swing) ] =========
do
    local BreakTab = Window:AddTab({ Title = "Break (Radius)", Icon = "hammer" })

    local br_auto     = BreakTab:CreateToggle("br_auto",     { Title = "Auto Break (cached)", Default = false })
    local br_range    = BreakTab:CreateSlider("br_range",    { Title = "Range (studs)", Min = 5, Max = 150, Rounding = 0, Default = 35 })
    local br_max      = BreakTab:CreateSlider("br_max",      { Title = "Max targets per swing", Min = 1, Max = 15, Rounding = 0, Default = 8 })
    local br_cd       = BreakTab:CreateSlider("br_cd",       { Title = "Swing cooldown (s)", Min = 0.05, Max = 1.00, Rounding = 2, Default = 0.15 })
    local br_tick     = BreakTab:CreateSlider("br_tick",     { Title = "Scan interval (s)", Min = 0.03, Max = 0.40, Rounding = 2, Default = 0.10 })
    local br_onlyRes  = BreakTab:CreateToggle("br_onlyres",  { Title = "Scan only workspace.Resources", Default = true })

    -- Новые — мульти-удар
    local br_swings   = BreakTab:CreateSlider("br_swings",   { Title = "Swings per tick", Min = 1, Max = 4, Rounding = 0, Default = 2 })
    local br_gap      = BreakTab:CreateSlider("br_gap",      { Title = "Gap between swings (s)", Min = 0.00, Max = 0.20, Rounding = 2, Default = 0.04 })
    local br_retarget = BreakTab:CreateToggle("br_retarget", { Title = "Retarget each swing", Default = false })

    local KNOWN_TARGETS = {
        "Gold Node","Iron Node","Stone Node","Ice Node","Crystal Node",
        "Adurite Node","Magnetite Node","Emerald Node","Pink Diamond Node","Void Stone",
        "Tree","Big Tree","Bush","Boulder","Totem","Chest","Ancient Chest",
        "Shelly","Rock","Log Pile","Leaf Pile","Coal Node"
    }
    local br_black   = BreakTab:CreateToggle("br_black",  { Title = "Use selection as Blacklist (else Whitelist/All)", Default = false })
    local br_list    = BreakTab:CreateDropdown("br_list", { Title = "Targets (multi, optional)", Values = KNOWN_TARGETS, Multi = true, Default = {} })

    -- быстрый вызов свинга
    local function sendSwing(ids)
        if type(ids) ~= "table" then ids = { ids } end
        local ok = false
        if typeof(swingtool) == "function" then ok = pcall(function() swingtool(ids) end) end
        if not ok and packets and packets.SwingTool and packets.SwingTool.send
