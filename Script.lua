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
        if not ok and packets and packets.SwingTool and packets.SwingTool.send then
            pcall(function() packets.SwingTool.send(ids) end)
        end
    end

    ----------------------------------------------------------------
    -- КЕШ: следим за папками и держим лёгкий список
    ----------------------------------------------------------------
    local cache = {}  -- [instance] = {eid=<number>, getPos=<fn>, name=<string>}
    local watched, conns = {}, {}

    local function addModel(inst)
        if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then return end
        local eid = inst.GetAttribute and inst:GetAttribute("EntityID"); if not eid then return end

        local getPos
        if inst:IsA("Model") then
            local pp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
            if not pp then return end
            getPos = function() return pp.Position end
        elseif inst:IsA("BasePart") or inst:IsA("MeshPart") then
            getPos = function() return inst.Position end
        else
            return
        end

        local nm = inst.Name
        if inst.GetAttribute then
            nm = inst:GetAttribute("DisplayName") or inst:GetAttribute("Name") or nm
        end

        cache[inst] = { eid = eid, getPos = getPos, name = nm, dist = math.huge }
    end

    local function removeModel(inst)
        cache[inst] = nil
    end

    local function hookFolder(folder)
        if not folder or watched[folder] then return end
        watched[folder] = true
        for _,ch in ipairs(folder:GetChildren()) do addModel(ch) end
        conns[#conns+1] = folder.ChildAdded:Connect(addModel)
        conns[#conns+1] = folder.ChildRemoved:Connect(removeModel)
    end

    local function refreshFolders()
        hookFolder(workspace:FindFirstChild("Resources"))
        if not br_onlyRes.Value then hookFolder(workspace) end
    end
    refreshFolders()
    br_onlyRes:OnChanged(function()
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns); table.clear(watched); table.clear(cache)
        refreshFolders()
    end)

    ----------------------------------------------------------------
    -- Селектор целей
    ----------------------------------------------------------------
    local selSet, useBlack = nil, false
    local function compileSelector()
        local val = br_list.Value
        local hasAny = (type(val)=="table") and next(val) ~= nil
        if not hasAny then selSet = nil; return end
        selSet = {}
        for k,v in pairs(val) do if v then selSet[string.lower(k)] = true end end
    end
    compileSelector()
    br_list:OnChanged(compileSelector)
    br_black:OnChanged(function(v) useBlack = v end)

    ----------------------------------------------------------------
    -- Раннер
    ----------------------------------------------------------------
    task.spawn(function()
        while true do
            if br_auto.Value and root and root.Parent then
                local range   = br_range.Value
                local maxHit  = br_max.Value

                -- Собираем и частично ограничиваем кандидатов
                local candidates = {}
                local myPos = root.Position
                for inst, info in pairs(cache) do
                    if inst.Parent then
                        local pos = info.getPos()
                        local d   = (pos - myPos).Magnitude
                        if d <= range then
                            local pass = true
                            if selSet then
                                local inSel = selSet[string.lower(info.name or "")]
                                pass = (useBlack and (not inSel)) or ((not useBlack) and inSel)
                            elseif useBlack then
                                pass = true -- пустой blacklist => ломаем всё
                            end
                            if pass then
                                info.dist = d
                                candidates[#candidates+1] = info
                                if #candidates >= (maxHit * 3) then break end
                            end
                        end
                    end
                end

                if #candidates > maxHit then
                    table.sort(candidates, function(a,b) return a.dist < b.dist end)
                end

                -- первичный пакет целей
                local ids = {}
                for i = 1, math.min(maxHit, #candidates) do
                    ids[#ids+1] = candidates[i].eid
                end

                -- мульти-удар за тик
                local swings = math.max(1, math.floor(br_swings.Value))
                if #ids > 0 then
                    for s = 1, swings do
                        if br_retarget.Value and s > 1 then
                            -- быстрый ретаргет: обновим дистанции и пересоберём ids
                            myPos = root.Position
                            for j = 1, #candidates do
                                local c = candidates[j]
                                c.dist = (c.getPos() - myPos).Magnitude
                            end
                            if #candidates > 1 then
                                table.sort(candidates, function(a,b) return a.dist < b.dist end)
                            end
                            table.clear(ids)
                            for i = 1, math.min(maxHit, #candidates) do
                                ids[#ids+1] = candidates[i].eid
                            end
                        end

                        sendSwing(ids)

                        local g = br_gap.Value
                        if g > 0 then task.wait(g) end
                    end
                end

                task.wait(br_cd.Value + br_tick.Value)
            else
                task.wait(0.15)
            end
        end
    end)
end


-- ========= [ TAB: Route (плавный подъём по Y как в Movement, без автопрыжка) ] =========
Tabs.Route = Window:AddTab({ Title = "Route", Icon = "route" })

local R_gap     = Tabs.Route:CreateSlider("r_gap",     { Title="Point gap (studs)", Min=0.5, Max=8, Rounding=2, Default=2 })
local R_spd     = Tabs.Route:CreateSlider("r_spd",     { Title="Follow speed",      Min=6, Max=40, Rounding=1, Default=20 })
local R_loop    = Tabs.Route:CreateToggle("r_loop",    { Title="Loop back & forth", Default=true })
local R_click   = Tabs.Route:CreateToggle("r_click",   { Title="Add points by mouse click", Default=false })
local R_light   = Tabs.Route:CreateToggle("r_light",   { Title="Lightweight visuals", Default=true })
local R_maxDots = Tabs.Route:CreateSlider("r_maxdots", { Title="Max dots on screen", Min=50, Max=800, Rounding=0, Default=300 })

-- НОВОЕ: параметры плавного подъёма
local R_liftY   = Tabs.Route:CreateSlider("r_lifty",   { Title="Base lift above path (studs)", Min=0, Max=12, Rounding=1, Default=1.5 })
local R_yGain   = Tabs.Route:CreateSlider("r_ygain",   { Title="Vertical gain (responsiveness)", Min=0.5, Max=8, Rounding=1, Default=2.6 })
local R_yMax    = Tabs.Route:CreateSlider("r_ymax",    { Title="Max vertical speed", Min=2, Max=25, Rounding=0, Default=10 })
local R_yDamp   = Tabs.Route:CreateSlider("r_ydamp",   { Title="Smoothing (0=no, 0.9=очень плавно)", Min=0, Max=0.95, Rounding=2, Default=0.55 })

local Route = { points = {}, recording=false, running=false, _hb=nil, _jump=nil, _click=nil, _lastPos=nil, _idleT0=nil, _vy=0 }
_G.__ROUTE = Route

local routeFolder = Workspace:FindFirstChild("_ROUTE_DOTS")  or Instance.new("Folder", Workspace); routeFolder.Name="_ROUTE_DOTS"
local linesFolder = Workspace:FindFirstChild("_ROUTE_LINES") or Instance.new("Folder", Workspace); linesFolder.Name="_ROUTE_LINES"
local COL_Y=Color3.fromRGB(255,230,80); local COL_R=Color3.fromRGB(230,75,75); local COL_B=Color3.fromRGB(90,155,255); local COL_L=Color3.fromRGB(255,200,70)

local DOT_POOL, DOT_USED, DOT_QUEUE = {}, {}, {}
local function allocDot()
    local p = table.remove(DOT_POOL) or Instance.new("Part")
    p.Name="_route_dot"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
    p.Shape=Enum.PartType.Ball
    p.Material = R_light.Value and Enum.Material.SmoothPlastic or Enum.Material.Neon
    p.CastShadow = not R_light.Value
    p.Transparency = R_light.Value and 0.35 or 0.1
    p.Parent = routeFolder
    DOT_USED[p]=true; table.insert(DOT_QUEUE,p)
    local cap = (R_maxDots and R_maxDots.Value) or 300
    while #DOT_QUEUE > cap do
        local old = table.remove(DOT_QUEUE,1)
        DOT_USED[old]=nil; old.Parent=nil; table.insert(DOT_POOL, old)
    end
    return p
end
local function dot(color,pos,size)
    local p=allocDot(); p.Color=color
    local s=size or (R_light.Value and 0.45 or 0.6)
    p.Size=Vector3.new(s,s,s); p.CFrame=CFrame.new(pos + Vector3.new(0,0.12,0))
end
local function clearDots() for p,_ in pairs(DOT_USED) do DOT_USED[p]=nil; p.Parent=nil; table.insert(DOT_POOL,p) end; table.clear(DOT_QUEUE) end
local function clearLines() for _,c in ipairs(linesFolder:GetChildren()) do c:Destroy() end end
local function makeSeg(a,b)
    local seg=Instance.new("Part")
    seg.Name="_route_line"; seg.Anchored=true; seg.CanCollide=false; seg.CanQuery=false; seg.CanTouch=false
    seg.Material = R_light.Value and Enum.Material.SmoothPlastic or Enum.Material.Neon
    seg.Color=COL_L; seg.Transparency= R_light.Value and 0.45 or 0.2; seg.CastShadow = not R_light.Value
    local mid=(a+b)/2; local dir=(b-a); local dist=dir.Magnitude
    seg.Size=Vector3.new(0.12,0.12, math.max(0.05, dist))
    seg.CFrame = CFrame.lookAt(mid, b); seg.Parent=linesFolder
end
local function redrawLines()
    clearLines()
    for i=1,#Route.points-1 do makeSeg(Route.points[i].pos, Route.points[i+1].pos) end
    if R_loop.Value and #Route.points>=2 then makeSeg(Route.points[#Route.points].pos, Route.points[1].pos) end
end
Route._redraw = { clearDots=clearDots, dot=dot, clearLines=clearLines, redrawLines=redrawLines }

local function ui(msg) pcall(function() Library:Notify{ Title="Route", Content=tostring(msg), Duration=2 } end) end
local function pushPoint(pos,flags)
    local r={pos=pos}; if flags then for k,v in pairs(flags) do r[k]=v end end
    table.insert(Route.points, r)
    local col = (r.jump_start or r.jump_end) and COL_B or (r.wait and COL_R or COL_Y)
    dot(col,pos, R_light.Value and 0.45 or 0.6)
    if not Route.recording then redrawLines() end
end

-- === BV для follow (с мягкой вертикалью) ===
local ROUTE_BV_NAME="_ROUTE_BV"
local function getRouteBV() return root and root:FindFirstChild(ROUTE_BV_NAME) or nil end
local function ensureRouteBV()
    ensureChar(); if not (root and root.Parent) then return end
    local bv=getRouteBV()
    if not bv then
        bv=Instance.new("BodyVelocity"); bv.Name=ROUTE_BV_NAME
        bv.MaxForce = Vector3.new(1e9, 1e5, 1e9) -- умеренная сила по Y
        bv.Velocity = Vector3.new()
        bv.Parent   = root
    end
    return bv
end
local function stopRouteBV() local bv=getRouteBV(); if bv then bv.Velocity=Vector3.new() end end
local function killRouteBV() local bv=getRouteBV(); if bv then bv:Destroy() end end

-- клик-точки
local UIS_click = game:GetService("UserInputService")
local mouse = plr:GetMouse()
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { plr.Character }
local function worldPointFromMouse()
    local cam = workspace.CurrentCamera; if not cam then return end
    local ur = cam:ViewportPointToRay(mouse.X, mouse.Y)
    local hit = workspace:Raycast(ur.Origin, ur.Direction*5000, rayParams)
    if hit then return hit.Position end
    if mouse.Hit then return mouse.Hit.Position end
end
local function startClickAdd()
    if Route._click then Route._click:Disconnect(); Route._click=nil end
    if not R_click.Value then return end
    Route._click = mouse.Button1Down:Connect(function()
        if Route.recording or Route.running then return end
        local p = worldPointFromMouse(); if not p then return end
        if #Route.points==0 then dot(COL_Y,p, R_light.Value and 0.55 or 0.75) end
        pushPoint(p); ui(("added point #%d"):format(#Route.points))
    end)
end

-- ===== Record =====
function _ROUTE_startRecord()
    ensureChar()
    if Route.recording or Route.running then return end
    if not (hum and root and hum.Parent and root.Parent) then return end

    RouteLock(true)
    Route.recording = true
    table.clear(Route.points); clearDots(); clearLines()
    Route._lastPos = root.Position
    Route._idleT0  = nil
    pushPoint(Route._lastPos)

    if Route._jump then Route._jump:Disconnect() end
    Route._jump = hum.StateChanged:Connect(function(_,new)
        if not Route.recording then return end
        if new==Enum.HumanoidStateType.Jumping then
            pushPoint(root.Position, {jump_start=true})
        elseif new==Enum.HumanoidStateType.Landed then
            pushPoint(root.Position, {jump_end=true})
        end
    end)

    if Route._hb then Route._hb:Disconnect() end
    Route._hb = RunService.Heartbeat:Connect(function()
        if not Route.recording then return end
        local cur = root.Position

        -- idle -> WAIT
        local vel    = root.AssemblyLinearVelocity or Vector3.zero
        local planar = Vector3.new(vel.X,0,vel.Z).Magnitude
        local moving = hum.MoveDirection.Magnitude > 0.10
        local onGround = hum.FloorMaterial ~= Enum.Material.Air
        local idle   = onGround and (planar <= 0.25) and (not moving)

        if idle then
            if not Route._idleT0 then
                Route._idleT0 = tick()
                pushPoint(cur, { _pendingWait = true })
                dot(COL_R, cur, R_light.Value and 0.5 or 0.7)
            end
        else
            if Route._idleT0 then
                local dt = tick() - Route._idleT0
                Route._idleT0 = nil
                if dt >= 0.35 then
                    for i = #Route.points, 1, -1 do
                        local p = Route.points[i]
                        if p._pendingWait then p._pendingWait = nil; p.wait = dt; break end
                    end
                else
                    if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then
                        table.remove(Route.points, #Route.points); redrawLines()
                    end
                end
            end
        end

        if (cur - Route._lastPos).Magnitude >= ((R_gap and R_gap.Value) or 2) then
            pushPoint(cur); Route._lastPos = cur
        end
    end)
    ui("recording…")
end

function _ROUTE_stopRecord()
    if not Route.recording then return end
    Route.recording=false
    if Route._hb   then Route._hb:Disconnect();   Route._hb=nil end
    if Route._jump then Route._jump:Disconnect(); Route._jump=nil end

    if Route._idleT0 then
        local dt = tick() - Route._idleT0
        Route._idleT0 = nil
        if dt >= 0.35 then
            for i = #Route.points, 1, -1 do local p = Route.points[i]
                if p._pendingWait then p._pendingWait=nil; p.wait=dt; break end
            end
        else
            if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then
                table.remove(Route.points, #Route.points); redrawLines()
            end
        end
    end

    redrawLines()
    RouteLock(false)
    ui(("rec done (%d pts)"):format(#Route.points))
    pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, Route.points) end)
end

-- ===== Follow (плавный подъём) =====
local function followSeg(p1, p2)
    local bv=ensureRouteBV(); if not bv then return false end
    local speed   = (R_spd and R_spd.Value) or 20
    local stopTol = 1.05
    local ySnap   = 1.2
    local t0      = tick()

    while Route.running do
        if not (root and root.Parent) then ensureChar(); if not (root and root.Parent) then break end end
        local cur = root.Position

        -- Планарное ведение по XZ
        local planar = Vector3.new(p2.X - cur.X, 0, p2.Z - cur.Z)
        local d = planar.Magnitude
        local vPlan = (d>0 and planar.Unit or Vector3.new())*speed

        -- Плавная вертикаль: цель = высота точки + базовый лифт
        local wantY   = p2.Y + ((R_liftY and R_liftY.Value) or 0)
        local err     = wantY - cur.Y
        local targetV = math.clamp(err * ((R_yGain and R_yGain.Value) or 2.6),
                                   -((R_yMax and R_yMax.Value) or 10),
                                   ((R_yMax and R_yMax.Value) or 10))

        -- сглаживаем (инерция), 0 — без сглаживания, ближе к 1 — плавнее
        local damp    = (R_yDamp and R_yDamp.Value) or 0.55
        Route._vy     = Route._vy or 0
        Route._vy     = Route._vy + (targetV - Route._vy) * (1 - damp)

        if d <= stopTol and math.abs(cur.Y - wantY) <= ySnap then
            stopRouteBV(); return true
        end

        bv.Velocity = Vector3.new(vPlan.X, Route._vy, vPlan.Z)

        if tick()-t0>8 then return false end
        RunService.Heartbeat:Wait()
    end
    stopRouteBV(); return false
end

function _ROUTE_startFollow()
    ensureChar()
    if Route.running or Route.recording then return end
    if #Route.points<2 then ui("no route"); return end
    if not (root and root.Parent) then ui("char not ready"); return end

    RouteLock(true)
    Route.running=true
    Route._vy = 0
    ensureRouteBV().Velocity=Vector3.new()

    task.spawn(function()
        while Route.running do
            ui(R_loop.Value and "following (loop from start)" or "following")
            for i=1,#Route.points-1 do
                if not Route.running then break end
                local pt=Route.points[i]
                if pt.wait and pt.wait>0 then stopRouteBV(); task.wait(pt.wait) end
                if not followSeg(pt.pos, Route.points[i+1].pos) then Route.running=false break end
            end
            if Route.running and R_loop.Value then
                followSeg(Route.points[#Route.points].pos, Route.points[1].pos)
            else break end
        end
        stopRouteBV(); killRouteBV(); Route.running=false
        RouteLock(false)
    end)
end

function _ROUTE_stopFollow()
    if not Route.running then return end
    Route.running=false; stopRouteBV(); killRouteBV()
    Route._vy = 0
    pcall(function() if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end end)
    RouteLock(false); ui("stopped")
end

function _ROUTE_clear()
    table.clear(Route.points); clearDots(); clearLines(); stopRouteBV(); killRouteBV(); Route._vy=0; ui("cleared")
end

Tabs.Route:CreateButton({ Title="Start record", Callback=_ROUTE_startRecord })
Tabs.Route:CreateButton({ Title="Stop record",  Callback=_ROUTE_stopRecord  })
Tabs.Route:CreateButton({ Title="Start follow", Callback=_ROUTE_startFollow })
Tabs.Route:CreateButton({ Title="Stop follow",  Callback=_ROUTE_stopFollow  })
Tabs.Route:CreateButton({ Title="Clear route",  Callback=_ROUTE_clear       })
Tabs.Route:CreateButton({
    Title = "Undo last point",
    Callback = function() if #Route.points>0 then table.remove(Route.points,#Route.points); redrawLines(); ui("last point removed") end end
})
R_loop:OnChanged(redrawLines)
R_click:OnChanged(function() startClickAdd(); ui(R_click.Value and "Click-to-add: ON" or "Click-to-add: OFF") end)
startClickAdd()


-- ========= [ TAB: Auto Loot ] =========
Tabs.Loot = Window:AddTab({ Title = "Auto Loot", Icon = "package" })
local LOOT_ITEM_NAMES = {
    "Berry","Bloodfruit","Bluefruit","Lemon","Strawberry","Gold","Raw Gold","Crystal Chunk",
    "Coin","Coins","Coin Stack","Essence","Emerald","Raw Emerald","Pink Diamond",
    "Raw Pink Diamond","Void Shard","Jelly","Magnetite","Raw Magnetite","Adurite","Raw Adurite",
    "Ice Cube","Stone","Iron","Raw Iron","Steel","Hide","Leaves","Log","Wood","Pie"
}
local loot_on        = Tabs.Loot:CreateToggle("loot_on",      { Title="Auto Loot", Default=false })
local loot_range     = Tabs.Loot:CreateSlider("loot_range",   { Title="Range (studs)", Min=5, Max=150, Rounding=0, Default=40 })
local loot_batch     = Tabs.Loot:CreateSlider("loot_batch",   { Title="Max pickups / tick", Min=1, Max=50, Rounding=0, Default=12 })
local loot_cd        = Tabs.Loot:CreateSlider("loot_cd",      { Title="Tick cooldown (s)", Min=0.03, Max=0.4, Rounding=2, Default=0.08 })
local loot_chests    = Tabs.Loot:CreateToggle("loot_chests",  { Title="Also loot chests (Contents)", Default=true })
local loot_blacklist = Tabs.Loot:CreateToggle("loot_black",   { Title="Use selection as Blacklist (else Whitelist)", Default=false })
local loot_debug     = Tabs.Loot:CreateToggle("loot_debug",   { Title="Debug (F9)", Default=false })
local loot_dropdown  = Tabs.Loot:CreateDropdown("loot_items", { Title="Items (multi)", Values=LOOT_ITEM_NAMES, Multi=true, Default={ Leaves=true, Log=true } })

local function safePickup(eid) local ok = pcall(function() pickup(eid) end); if not ok and packets and packets.Pickup and packets.Pickup.send then pcall(function() packets.Pickup.send(eid) end) end end
local DROP_FOLDERS = { "Items","Drops","WorldDrops","Loot","Dropped","Resources" }
local watchedFolders, conns = {}, {}
local cache = {}
local function normalizedName(inst)
    local a; if inst.GetAttribute then a = inst:GetAttribute("ItemName") or inst:GetAttribute("Name") or inst:GetAttribute("DisplayName") end
    if typeof(a) == "string" and a ~= "" then return a end
    return inst.Name
end
local function addDrop(inst)
    if cache[inst] then return end
    local eid = inst.GetAttribute and inst:GetAttribute("EntityID"); if not eid then return end
    local name = normalizedName(inst)
    local getPos
    if inst:IsA("Model") then
        local pp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart"); if not pp then return end
        getPos = function() return pp.Position end
    elseif inst:IsA("BasePart") or inst:IsA("MeshPart") then getPos = function() return inst.Position end
    else return end
    cache[inst] = { eid = eid, name = name, getPos = getPos }
end
local function removeDrop(inst) cache[inst] = nil end
local function hookFolder(folder)
    if not folder or watchedFolders[folder] then return end
    watchedFolders[folder] = true
    for _,ch in ipairs(folder:GetChildren()) do addDrop(ch) end
    conns[#conns+1] = folder.ChildAdded:Connect(addDrop)
    conns[#conns+1] = folder.ChildRemoved:Connect(removeDrop)
end
local function hookChests()
    local dep = workspace:FindFirstChild("Deployables"); if not dep then return end
    for _,mdl in ipairs(dep:GetChildren()) do
        if mdl:IsA("Model") then
            local contents = mdl:FindFirstChild("Contents")
            if contents and not watchedFolders[contents] then hookFolder(contents) end
        end
    end
    conns[#conns+1] = dep.ChildAdded:Connect(function(mdl)
        task.defer(function()
            if mdl:IsA("Model") then local contents = mdl:FindFirstChild("Contents"); if contents then hookFolder(contents) end end
        end)
    end)
end
for _,n in ipairs(DROP_FOLDERS) do hookFolder(workspace:FindFirstChild(n)) end
hookChests()
task.spawn(function()
    while true do
        for _,n in ipairs(DROP_FOLDERS) do local f = workspace:FindFirstChild(n); if f and not watchedFolders[f] then hookFolder(f) end end
        if loot_chests.Value then hookChests() end
        task.wait(1.0)
    end
end)
local function selectedSet()
    local sel, val = {}, loot_dropdown.Value
    if typeof(val) == "table" then for k,v in pairs(val) do if v then sel[string.lower(k)] = true end end end
    return sel
end
task.spawn(function()
    while true do
        if loot_on.Value and root then
            local set = selectedSet()
            local useBlack = loot_blacklist.Value
            local range = loot_range.Value
            local maxPer = math.max(1, math.floor(loot_batch.Value))
            local candidates = {}
            for inst,info in pairs(cache) do
                if inst.Parent then
                    local isContents = false
                    if not loot_chests.Value then
                        local p = inst.Parent
                        while p and p ~= workspace do
                            if p.Name == "Contents" then isContents = true; break end
                            p = p.Parent
                        end
                    end
                    if not isContents then
                        local pos = info.getPos()
                        local d   = (pos - root.Position).Magnitude
                        if d <= range then
                            local nm   = info.name or "Unknown"
                            local pass = true
                            if next(set) ~= nil then
                                local inSel = set[string.lower(nm)] == true
                                pass = (useBlack and (not inSel)) or ((not useBlack) and inSel)
                            end
                            if pass then candidates[#candidates+1] = { eid = info.eid, dist = d, name = nm } end
                        end
                    end
                end
            end
            if #candidates > 1 then table.sort(candidates, function(a,b) return a.dist < b.dist end) end
            if loot_debug.Value then print(("[AutoLoot] candidates=%d (mode=%s, chests=%s)"):format(#candidates, useBlack and "Blacklist" or "Whitelist", tostring(loot_chests.Value))) end
            for i = 1, math.min(maxPer, #candidates) do
                safePickup(candidates[i].eid)
                if loot_debug.Value then print(("[AutoLoot] pickup #%d: %s [%.1f]"):format(i, candidates[i].name, candidates[i].dist)) end
                task.wait(0.01)
            end
            task.wait(loot_cd.Value)
        else
            task.wait(0.15)
        end
    end
end)

-- ========= [ TAB: Player — Selective NoClip ] =========
local PlayerTab = Tabs.Player or Window:AddTab({ Title = "Player", Icon = "ghost" })
local snc_on    = PlayerTab:CreateToggle("snc_on",   { Title = "Selective NoClip", Default = false })
local snc_hold  = PlayerTab:CreateToggle("snc_hold", { Title = "Hold-to-clip (key B)", Default = true })
local snc_range = PlayerTab:CreateSlider("snc_range",{ Title = "Scan range (studs)", Min=8, Max=80, Rounding=0, Default=36 })
local snc_limit = PlayerTab:CreateSlider("snc_limit",{ Title = "Max parts / tick",  Min=30, Max=300, Rounding=0, Default=160 })
local snc_tick  = PlayerTab:CreateSlider("snc_tick", { Title = "Update rate (s)",   Min=0.05, Max=0.40, Rounding=2, Default=0.18 })

local UIS = game:GetService("UserInputService")
local _heldB = false
UIS.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode==Enum.KeyCode.B then _heldB = true end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.B then _heldB = false end end)
local function isDown() return snc_on.Value or (snc_hold.Value and _heldB) end

local function getCharParts()
    local parts = {}
    local c = plr.Character
    if not c then return parts end
    for _,v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then parts[#parts+1] = v end
    end
    return parts
end

local MATERIAL_OK = {
    [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true,
    [Enum.Material.Rock] = true, [Enum.Material.Slate] = true, [Enum.Material.Basalt] = true,
    [Enum.Material.Granite] = true, [Enum.Material.Ground] = true, [Enum.Material.Grass] = true,
    [Enum.Material.Ice] = true, [Enum.Material.Cobblestone] = true, [Enum.Material.Sandstone] = true
}
local NAME_HINTS = {
    "tree","log","plank","wood","wall","fence","gate","bridge","totem","boulder","rock",
    "stone","node","ore","iron","gold","emerald","magnetite","adurite","crystal",
    "ice","cave","shelly","chest","hut","house","raft","boat"
}
local function isBoogaEnvPart(p: BasePart): boolean
    if not p or not p.Parent or not p.CanCollide then return false end
    if p:IsDescendantOf(plr.Character) then return false end
    if p.Parent:FindFirstChildOfClass("Humanoid") then return false end
    local okMat = MATERIAL_OK[p.Material] or p:IsA("MeshPart"); if not okMat then return false end
    local n = string.lower(p.Name)
    for _,kw in ipairs(NAME_HINTS) do if string.find(n, kw, 1, true) then return true end end
    if p.GetAttribute then
        local dn = tostring(p:GetAttribute("DisplayName") or p:GetAttribute("Name") or ""):lower()
        for _,kw in ipairs(NAME_HINTS) do if dn ~= "" and dn:find(kw, 1, true) then return true end end
    end
    return okMat
end

local activeNCC = {}  -- [envPart] = { [charPart] = NCC }
local function addNoCollide(envPart: BasePart)
    if not envPart or not envPart.Parent then return end
    local perChar = activeNCC[envPart]; if not perChar then perChar = {}; activeNCC[envPart] = perChar end
    for _,cp in ipairs(getCharParts()) do
        if cp and cp.Parent and not perChar[cp] then
            local ncc = Instance.new("NoCollisionConstraint")
            ncc.Part0, ncc.Part1 = cp, envPart
            ncc.Parent = cp
            perChar[cp] = ncc
        end
    end
end
local function removeNoCollideFor(envPart: BasePart)
    local perChar = activeNCC[envPart]
    if perChar then for _,ncc in pairs(perChar) do if ncc then ncc:Destroy() end end; activeNCC[envPart] = nil end
end
local function clearAllNCC() for part,_ in pairs(activeNCC) do removeNoCollideFor(part) end end
plr.CharacterAdded:Connect(function() task.defer(clearAllNCC) end)

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { plr.Character }
local function getNearBoogaParts(origin: Vector3, radius: number, maxCount: number)
    local res = {}
    local hits = workspace:GetPartBoundsInRadius(origin, radius, overlap)
    if not hits then return res end
    for _,p in ipairs(hits) do
        if p:IsA("BasePart") and p.CanCollide and isBoogaEnvPart(p) then
            res[#res+1] = p
            if #res >= maxCount then break end
        end
    end
    return res
end

task.spawn(function()
    while true do
        if isDown() and root and root.Parent then
            local near = getNearBoogaParts(root.Position, snc_range.Value, snc_limit.Value)
            local keep = {}
            for _,part in ipairs(near) do keep[part] = true; addNoCollide(part) end
            for part,_ in pairs(activeNCC) do if (not part.Parent) or (not keep[part]) then removeNoCollideFor(part) end end
            task.wait(snc_tick.Value)
        else
            clearAllNCC(); task.wait(0.15)
        end
    end
end)



-- ========= [ TAB: Movement (Slope / Auto Climb + 360°) ] =========
local UIS2 = game:GetService("UserInputService")
local LRun = game:GetService("RunService")

local MoveTab = Window:AddTab({ Title = "Movement", Icon = "mountain" })

-- базовые настройки
local mv_on        = MoveTab:CreateToggle("mv_on",        { Title = "Slope / Auto Climb (BV)", Default = false })
local mv_speed     = MoveTab:CreateSlider("mv_speed",     { Title = "Speed", Min = 8, Max = 40, Rounding = 1, Default = 20 })
local mv_boost     = MoveTab:CreateToggle("mv_boost",     { Title = "Shift = Boost (+40%)", Default = true })
local mv_jumphelp  = MoveTab:CreateToggle("mv_jumphelp",  { Title = "Auto Jump on slopes", Default = true })
local mv_sidestep  = MoveTab:CreateToggle("mv_sidestep",  { Title = "Side step if blocked", Default = true })

-- зонды/анти-застревание
local mv_probeLen  = MoveTab:CreateSlider("mv_probel",    { Title = "Wall probe length", Min = 4, Max = 12, Rounding = 1, Default = 7 })
local mv_probeH    = MoveTab:CreateSlider("mv_probeh",    { Title = "Probe height", Min = 1.5, Max = 4, Rounding = 1, Default = 2.4 })
local mv_stuckT    = MoveTab:CreateSlider("mv_stuck",     { Title = "Anti-stuck time (s)", Min = 0.2, Max = 1.2, Rounding = 2, Default = 0.6 })
local mv_sideStep  = MoveTab:CreateSlider("mv_sidest",    { Title = "Side step power", Min = 2, Max = 7, Rounding = 1, Default = 4.2 })

-- новый режим: 360° подъём (можно спиной/боком)
local mv_360       = MoveTab:CreateToggle("mv_360",       { Title = "360° climb (спиной/боком тоже)", Default = true })
local mv_360_fov   = MoveTab:CreateSlider("mv_360_fov",   { Title = "Конус (°) вокруг движения", Min = 30, Max = 360, Rounding = 0, Default = 300 })
local mv_360_rays  = MoveTab:CreateSlider("mv_360_rays",  { Title = "Кол-во лучей", Min = 4, Max = 24, Rounding = 0, Default = 12 })

-- утилиты BV
local function getRoot()
    if not root or not root.Parent then
        local c = plr.Character
        root = c and c:FindFirstChild("HumanoidRootPart") or root
    end
    return root
end
local function mv_getBV()
    local rp = getRoot()
    return rp and rp:FindFirstChild("_MV_BV") or nil
end
local function mv_ensureBV()
    local rp = getRoot(); if not rp then return end
    local bv = mv_getBV()
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "_MV_BV"
        bv.MaxForce = Vector3.new(1e9, 0, 1e9) -- движемся по XZ, прыжку не мешаем
        bv.Velocity = Vector3.new()
        bv.Parent = rp
    end
    return bv
end
local function mv_killBV()
    local bv = mv_getBV(); if bv then bv:Destroy() end
end

-- рейкасты
local rayParams_mv = RaycastParams.new()
rayParams_mv.FilterType = Enum.RaycastFilterType.Exclude
rayParams_mv.FilterDescendantsInstances = { plr.Character }

local function wallAheadXZ(dir2d)
    local rp = getRoot(); if not rp then return false end
    if dir2d.Magnitude < 1e-3 then return false end
    local origin = rp.Position + Vector3.new(0, mv_probeH.Value, 0)
    local dir3 = Vector3.new(dir2d.X, 0, dir2d.Z).Unit * mv_probeLen.Value
    local hit = workspace:Raycast(origin, dir3, rayParams_mv)
    if not hit then return false end
    -- вертикальная/крутая поверхность
    return (hit.Normal.Y or 0) < 0.6
end

local function rotate2D(v, deg)
    local a = math.rad(deg)
    local ca, sa = math.cos(a), math.sin(a)
    return Vector3.new(v.X * ca - v.Z * sa, 0, v.X * sa + v.Z * ca)
end

local function blocked360(dir2d)
    local rays = math.max(4, math.floor(mv_360_rays.Value))
    local span = math.clamp(mv_360_fov.Value, 30, 360)
    if dir2d.Magnitude < 1e-3 then
        dir2d = Vector3.new(0,0,1) -- базовый вектор, если стоим
        span = 360
    end
    local start = -span/2
    local step  = span / (rays - 1)
    for i = 0, rays - 1 do
        local d = rotate2D(dir2d.Unit, start + i * step)
        if wallAheadXZ(d) then return true end
    end
    return false
end

local function autoJump()
    if not mv_jumphelp.Value then return end
    if hum and hum.Parent then
        pcall(function()
            hum.Jump = true
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

local function trySideStep(dir2d)
    if not mv_sidestep.Value then return end
    local rp = getRoot(); local bv = mv_ensureBV(); if not (rp and bv) then return end
    local perp = Vector3.new(-dir2d.Z, 0, dir2d.X).Unit
    local power = mv_sideStep.Value * 2
    local t1 = tick()
    while mv_on.Value and tick() - t1 < 0.18 do
        bv.Velocity = perp * power
        LRun.Heartbeat:Wait()
    end
    bv.Velocity = Vector3.new()
    t1 = tick()
    while mv_on.Value and tick() - t1 < 0.18 do
        bv.Velocity = -perp * power
        LRun.Heartbeat:Wait()
    end
    bv.Velocity = Vector3.new()
end

-- основной цикл
task.spawn(function()
    local lastMoveT = tick()
    while true do
        if mv_on.Value and hum and root and hum.Parent then
            local dir = hum.MoveDirection
            local moving = dir.Magnitude > 0.05
            local speed = mv_speed.Value
            if mv_boost.Value and UIS2:IsKeyDown(Enum.KeyCode.LeftShift) then
                speed = speed * 1.4
            end

            -- 360-сканирование препятствий (подъём спиной/боком)
            if mv_360.Value then
                local scanDir = moving and dir or Vector3.new(0,0,1)
                if blocked360(scanDir) then
                    autoJump()
                    if moving then trySideStep(dir) end
                end
            else
                if moving and wallAheadXZ(dir) then
                    autoJump()
                    trySideStep(dir)
                end
            end

            -- движение
            local bv = mv_ensureBV()
            if moving then
                bv.Velocity = dir.Unit * speed
                lastMoveT = tick()
            else
                bv.Velocity = Vector3.new()
            end

            -- анти-застревание
            if tick() - lastMoveT > mv_stuckT.Value then
                local d2 = hum.MoveDirection
                if d2.Magnitude > 0.05 then trySideStep(d2.Unit) end
                lastMoveT = tick()
            end

            LRun.Heartbeat:Wait()
        else
            mv_killBV()
            task.wait(0.12)
        end
    end
end)

plr.CharacterAdded:Connect(function()
    task.defer(function()
        ensureChar()
        if not mv_on.Value then mv_killBV() end
    end)
end)
mv_on:OnChanged(function(v) if not v then mv_killBV() end end)


-- =========================
-- TAB: Follow (следовать за игроком)
-- =========================
Tabs.Follow = Window:AddTab({ Title = "Follow", Icon = "user" })
local flw_toggle = Tabs.Follow:CreateToggle("flw_on", { Title="Follow selected player", Default=false })
local flw_dist   = Tabs.Follow:CreateSlider("flw_dist", { Title="Keep distance (studs)", Min=2, Max=50, Rounding=1, Default=8 })
local flw_speed  = Tabs.Follow:CreateSlider("flw_speed",{ Title="Speed (BV)", Min=5, Max=60, Rounding=1, Default=21 })

local function getAllPlayerNames()
    local list = {} for _, p in ipairs(Players:GetPlayers()) do if p ~= plr then table.insert(list, p.Name) end end
    table.sort(list); return list
end
local flw_dd = Tabs.Follow:CreateDropdown("flw_target", { Title="Target player", Values=getAllPlayerNames(), Default="" })
Tabs.Follow:CreateButton({ Title="Refresh list", Callback=function()
    local names = getAllPlayerNames(); pcall(function() if flw_dd.SetValues then flw_dd:SetValues(names) end end)
    local cur = (flw_dd and flw_dd.Value) or ""; if #names>0 and (cur=="" or cur==nil) then pcall(function() if flw_dd.SetValue then flw_dd:SetValue(names[1]) end end) end
end })
Players.PlayerAdded:Connect(function() pcall(function() if flw_dd.SetValues then flw_dd:SetValues(getAllPlayerNames()) end end) end)
Players.PlayerRemoving:Connect(function(leaver)
    pcall(function() if flw_dd.SetValues then flw_dd:SetValues(getAllPlayerNames()) end end)
    if (flw_dd and flw_dd.Value) == leaver.Name then flw_toggle:SetValue(false) end
end)

local function FLW_getBV() return root and root:FindFirstChild("_FLW_BV") or nil end
local function FLW_ensureBV()
    if not root then return nil end
    local bv = FLW_getBV()
    if not bv then
        bv = Instance.new("BodyVelocity"); bv.Name="_FLW_BV"
        bv.MaxForce = Vector3.new(1e9, 0, 1e9) -- XZ only
        bv.Velocity = Vector3.new(); bv.Parent = root
    end
    return bv
end
local function FLW_killBV() local bv=FLW_getBV(); if bv then bv:Destroy() end end

local function getTargetRootByName(name)
    if not name or name=="" then return nil end
    local p = Players:FindFirstChild(name); if not p then return nil end
    local wf = workspace:FindFirstChild("Players")
    if wf then local wfplr = wf:FindFirstChild(name); if wfplr then local hrp = wfplr:FindFirstChild("HumanoidRootPart"); if hrp then return hrp end end end
    local ch = p.Character; return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end
plr.CharacterAdded:Connect(function() task.defer(FLW_killBV) end)

task.spawn(function()
    while true do
        if flw_toggle.Value then
            local targetName = (flw_dd and flw_dd.Value) or ""
            local keepDist   = tonumber(flw_dist.Value)  or 8
            local speed      = tonumber(flw_speed.Value) or 21
            local trg = getTargetRootByName(targetName)
            if root and trg then
                local bv = FLW_ensureBV()
                local myPos  = root.Position
                local trgPos = trg.Position
                local v = Vector3.new(trgPos.X - myPos.X, 0, trgPos.Z - myPos.Z)
                local d = v.Magnitude
                local band = 0.8
                if d > keepDist + band then
                    bv.Velocity = v.Unit * speed
                elseif d < math.max(keepDist - band, 1) then
                    bv.Velocity = Vector3.new()
                else
                    bv.Velocity = v.Unit * (speed * 0.4)
                end
            else
                local bv = FLW_getBV(); if bv then bv.Velocity = Vector3.new() end
            end
            RunService.Heartbeat:Wait()
        else
            FLW_killBV(); task.wait(0.15)
        end
    end
end)

-- ========= [ TAB: ESP — Wandering Trader (event + resilient) ] =========
local TraderTab = Window:AddTab({ Title = "Trader ESP", Icon = "store" })

local tr_enable    = TraderTab:CreateToggle("tr_esp_enable", { Title = "Enable Trader ESP", Default = true })
local tr_showbb    = TraderTab:CreateToggle("tr_show_label", { Title = "Show overhead label", Default = true })
local tr_highlight = TraderTab:CreateToggle("tr_highlight",  { Title = "Highlight model", Default = true })
local tr_maxdist   = TraderTab:CreateSlider ("tr_maxdist",   { Title = "Max distance (studs)", Min=100, Max=5000, Rounding=0, Default=2000 })
local tr_notify    = TraderTab:CreateToggle("tr_notify",     { Title = "Notify on spawn/despawn", Default = true })

-- hints
local TRADER_NAME_HINTS = { "wandering trader","wanderingtrader","trader","wanderer" }
local function textMatch(s, arr)
    s = string.lower(tostring(s or ""))
    for i=1,#arr do if string.find(s, arr[i], 1, true) then return true end end
    return false
end
local function isTraderModel(m)
    if not (m and m:IsA("Model")) then return false end
    if textMatch(m.Name, TRADER_NAME_HINTS) then return true end
    if m.GetAttribute then
        if textMatch(m:GetAttribute("DisplayName"), TRADER_NAME_HINTS) then return true end
        if textMatch(m:GetAttribute("Name"),        TRADER_NAME_HINTS) then return true end
        if textMatch(m:GetAttribute("NPCType"),     TRADER_NAME_HINTS) then return true end
    end
    -- иногда имя на дочерних объектах
    for _,ch in ipairs(m:GetChildren()) do
        if textMatch(ch.Name, TRADER_NAME_HINTS) then return true end
    end
    return false
end

-- utils
local function modelRoot(m)
    return m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end
local function prettyName(m)
    local dn
    if m.GetAttribute then dn = m:GetAttribute("DisplayName") or m:GetAttribute("Name") or m:GetAttribute("NPCType") end
    return (dn and dn~="") and tostring(dn) or "Wandering Trader"
end

-- visuals
local function makeBillboard(adornee)
    local bb = Instance.new("BillboardGui")
    bb.Name = "_ESP_TRADER_BB"; bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(180, 26)
    bb.StudsOffsetWorldSpace = Vector3.new(0,4,0)
    bb.Adornee = adornee; bb.Parent = adornee
    local tl = Instance.new("TextLabel")
    tl.BackgroundTransparency = 1; tl.Size = UDim2.fromScale(1,1)
    tl.Font = Enum.Font.GothamBold; tl.TextScaled = true
    tl.TextStrokeTransparency = 0.25; tl.TextColor3 = Color3.fromRGB(255,220,90)
    tl.Text = "Wandering Trader"; tl.Parent = bb
    return bb, tl
end
local function ensureHL(model)
    local hl = model:FindFirstChild("_ESP_TRADER_HL")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "_ESP_TRADER_HL"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 1; hl.OutlineTransparency = 0
        hl.OutlineColor = Color3.fromRGB(255,220,90)
        hl.Adornee = model; hl.Parent = model
    end
    return hl
end

-- state
local TR = { map = {}, loop = nil, addConn=nil, remConn=nil }

local function attachTrader(m)
    if TR.map[m] then return end
    local r = modelRoot(m)
    local bb, tl, hl

    -- если пока нет корневой детали — дождёмся
    if not r then
        local tmpConn
        tmpConn = m.ChildAdded:Connect(function(ch)
            if ch:IsA("BasePart") or ch.Name == "HumanoidRootPart" then
                r = modelRoot(m)
                if r and TR.map[m] and TR.map[m].bb then
                    TR.map[m].bb.Adornee = r
                end
            end
        end)
        -- создадим запись, билборд появится как только найдётся корень
        TR.map[m] = { model=m, root=nil, bb=nil, tl=nil, hl=nil, label=prettyName(m), waitConn=tmpConn, lastTxt="" }
    end

    if r then
        bb, tl = makeBillboard(r)
        hl = ensureHL(m)
        TR.map[m] = { model=m, root=r, bb=bb, tl=tl, hl=hl, label=prettyName(m), waitConn=nil, lastTxt="" }
    end

    if tr_notify.Value and Library and Library.Notify then
        Library:Notify{ Title="Trader", Content="Wandering Trader FOUND", Duration=3 }
    end
end

local function detachTrader(m)
    local rec = TR.map[m]; if not rec then return end
    if rec.waitConn then pcall(function() rec.waitConn:Disconnect() end) end
    if rec.bb then pcall(function() rec.bb:Destroy() end) end
    if rec.hl then pcall(function() rec.hl:Destroy() end) end
    TR.map[m] = nil
    if tr_notify.Value and Library and Library.Notify then
        Library:Notify{ Title="Trader", Content="Wandering Trader lost", Duration=2 }
    end
end

local function startTraderESP()
    if TR.loop then return end

    -- первичный один-раз скан (легко, но полно)
    for _,inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("Model") and isTraderModel(inst) then attachTrader(inst) end
    end

    -- глобальные вотчеры: ничего не пропустим
    TR.addConn = workspace.DescendantAdded:Connect(function(inst)
        if inst:IsA("Model") and isTraderModel(inst) then attachTrader(inst) end
    end)
    TR.remConn = workspace.DescendantRemoving:Connect(function(inst)
        if TR.map[inst] then detachTrader(inst) end
    end)

    -- лёгкий апдейт раз в 0.2с
    local acc = 0
    TR.loop = RunService.Heartbeat:Connect(function(dt)
        acc = acc + (dt or 0)
        if acc < 0.20 then return end
        acc = 0

        local enabled = tr_enable.Value
        local showBB  = tr_showbb.Value
        local showHL  = tr_highlight.Value
        local maxD    = tr_maxdist.Value

        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") or nil
        for m, rec in pairs(TR.map) do
            if not (rec.model and rec.model.Parent) then
                detachTrader(m)
            else
                -- если root появился позже — создадим визуал сейчас
                if not rec.root then
                    local nr = modelRoot(rec.model)
                    if nr then
                        local bb, tl = makeBillboard(nr)
                        local hl = ensureHL(rec.model)
                        rec.root, rec.bb, rec.tl, rec.hl = nr, bb, tl, hl
                    end
                end
                if rec.root then
                    -- дистанция/видимость
                    local inRange, txt = true, rec.label
                    if myRoot then
                        local d = (rec.root.Position - myRoot.Position).Magnitude
                        inRange = (d <= maxD)
                        txt = rec.label .. string.format(" (%.0f)", d)
                    end
                    if rec.tl and txt ~= rec.lastTxt then rec.tl.Text = txt; rec.lastTxt = txt end
                    if rec.bb then rec.bb.Enabled = enabled and showBB and inRange end
                    if rec.hl then rec.hl.Enabled = enabled and showHL and inRange end
                end
            end
        end
    end)
end

local function stopTraderESP()
    if TR.loop   then TR.loop:Disconnect(); TR.loop=nil end
    if TR.addConn then TR.addConn:Disconnect(); TR.addConn=nil end
    if TR.remConn then TR.remConn:Disconnect(); TR.remConn=nil end
    for m,_ in pairs(TR.map) do detachTrader(m) end
end

tr_enable:OnChanged(function(v) if v then startTraderESP() else stopTraderESP() end end)
if tr_enable.Value then startTraderESP() end


-- ========= [ TAB: Gold (Route JSON embed for mobile/MuMu) ] =========
Tabs.Gold = Window:AddTab({ Title = "Gold", Icon = "coins" })

----------------------------------------------------------------
-- Gold Farm: загрузка маршрута из ВШИТОГО JSON (для MuMu/мобилок)
----------------------------------------------------------------

-- ⬇⬇⬇ СЮДА ВСТАВЬ ВЕСЬ СВОЙ JSON МАРШРУТА (как есть, целиком) ⬇⬇⬇
local GF_JSON = [[[{"y":-35.0057258605957,"x":-108.06391143798828,"z":-138.6367645263672,"wait":0},{"y":-35.0057258605957,"x":-108.06391143798828,"z":-138.6367645263672,"wait":2.8921749591827394},{"y":-35.0000114440918,"x":-114.39580535888672,"z":-143.76495361328126,"wait":0},{"y":-35.10914611816406,"x":-120.60236358642578,"z":-149.06349182128907,"wait":0},{"y":-35.174652099609378,"x":-126.736328125,"z":-154.3189239501953,"wait":0},{"y":-35.01373291015625,"x":-133.11903381347657,"z":-159.79173278808595,"wait":0},{"y":-35.0000114440918,"x":-139.2494354248047,"z":-165.05136108398438,"wait":0},{"y":-34.50942611694336,"x":-143.1358642578125,"z":-168.38626098632813,"wait":1.4054183959960938},{"y":-34.77870178222656,"x":-138.75880432128907,"z":-173.2694854736328,"wait":0},{"y":-35.00001907348633,"x":-132.85084533691407,"z":-179.25177001953126,"wait":0},{"y":-34.97214126586914,"x":-127.03057098388672,"z":-185.0903778076172,"wait":0},{"y":-30.85957908630371,"x":-121.97700500488281,"z":-190.12339782714845,"wait":0},{"y":-25.764572143554689,"x":-118.83677673339844,"z":-193.28515625,"wait":1.4023454189300538},{"y":-25.121479034423829,"x":-119.68428039550781,"z":-195.31781005859376,"wait":0},{"y":-19.143545150756837,"x":-123.35350799560547,"z":-199.793212890625,"wait":0},{"y":-12.592195510864258,"x":-125.64717864990235,"z":-204.23350524902345,"wait":0},{"y":-6.9648213386535648,"x":-128.27442932128907,"z":-209.66412353515626,"wait":0},{"y":-3.5797197818756105,"x":-121.78925323486328,"z":-213.42530822753907,"wait":0},{"y":-2.604736089706421,"x":-113.83402252197266,"z":-212.68539428710938,"wait":0},{"y":-2.775747060775757,"x":-105.49630737304688,"z":-211.5811004638672,"wait":0},{"y":-2.145777702331543,"x":-97.50335693359375,"z":-210.43679809570313,"wait":0},{"y":-3.0000011920928957,"x":-89.42810821533203,"z":-209.2587432861328,"wait":0},{"y":-3.0000007152557375,"x":-81.43889617919922,"z":-208.08819580078126,"wait":0},{"y":-2.8722593784332277,"x":-73.2821044921875,"z":-206.89161682128907,"wait":0},{"y":-2.864581346511841,"x":-64.96359252929688,"z":-205.6698760986328,"wait":0},{"y":-5.999993324279785,"x":-57.38396453857422,"z":-204.5577850341797,"wait":0},{"y":-11.194684028625489,"x":-51.0391960144043,"z":-203.6243896484375,"wait":0},{"y":-16.959611892700197,"x":-45.51557922363281,"z":-202.8118133544922,"wait":0},{"y":-22.770029067993165,"x":-39.50012969970703,"z":-201.92889404296876,"wait":0},{"y":-27.447866439819337,"x":-32.827415466308597,"z":-200.95068359375,"wait":0},{"y":-31.5269775390625,"x":-25.742809295654298,"z":-199.90936279296876,"wait":0},{"y":-32.560096740722659,"x":-17.58608627319336,"z":-198.71234130859376,"wait":0},{"y":-30.199249267578126,"x":-9.762163162231446,"z":-197.5637969970703,"wait":0},{"y":-25.627742767333986,"x":-3.0400445461273195,"z":-196.5849609375,"wait":0},{"y":-18.782817840576173,"x":1.1167681217193604,"z":-195.9917449951172,"wait":0},{"y":-11.023324012756348,"x":4.9990315437316898,"z":-195.45001220703126,"wait":0},{"y":-3.3654019832611086,"x":8.627174377441407,"z":-194.90451049804688,"wait":0},{"y":-3.5502119064331056,"x":13.572165489196778,"z":-194.1670379638672,"je":true,"wait":0},{"y":-3.420570135116577,"x":16.78403663635254,"z":-193.6905059814453,"wait":0},{"y":-3.067387104034424,"x":25.005268096923829,"z":-192.46575927734376,"wait":0},{"y":-2.9983415603637697,"x":33.08295440673828,"z":-191.27940368652345,"wait":0},{"y":-3.0000007152557375,"x":41.07196807861328,"z":-190.10816955566407,"wait":0},{"y":-1.881862759590149,"x":49.06357955932617,"z":-188.93426513671876,"wait":0},{"y":3.975804328918457,"x":54.55297088623047,"z":-188.3115234375,"wait":0},{"y":10.322305679321289,"x":59.92011642456055,"z":-187.43771362304688,"wait":0},{"y":15.142446517944336,"x":66.82342529296875,"z":-186.32781982421876,"wait":0},{"y":20.799551010131837,"x":72.90801239013672,"z":-185.4522705078125,"wait":0},{"y":20.9999942779541,"x":81.0519790649414,"z":-184.17694091796876,"wait":0},{"y":20.9999942779541,"x":88.20064544677735,"z":-180.57550048828126,"wait":0},{"y":20.9999942779541,"x":93.89125061035156,"z":-174.859130859375,"wait":0},{"y":20.435489654541017,"x":98.76217651367188,"z":-168.52276611328126,"wait":0},{"y":17.145244598388673,"x":103.3895263671875,"z":-161.9059600830078,"wait":0},{"y":13.200715065002442,"x":105.21112060546875,"z":-159.21473693847657,"je":true,"wait":0},{"y":11.949600219726563,"x":107.06575012207031,"z":-156.448486328125,"wait":0},{"y":9.612100601196289,"x":111.44554901123047,"z":-149.86090087890626,"wait":0},{"y":6.151365280151367,"x":115.513916015625,"z":-143.7033233642578,"wait":0},{"y":-0.5735645294189453,"x":118.00444793701172,"z":-139.8373565673828,"wait":0},{"y":-2.6540017127990724,"x":122.51779174804688,"z":-133.05612182617188,"wait":0},{"y":-3.0000007152557375,"x":126.9671630859375,"z":-126.3145980834961,"wait":0},{"y":-3.0000007152557375,"x":131.4102325439453,"z":-119.57264709472656,"wait":0},{"y":-3.0000007152557375,"x":135.89956665039063,"z":-112.75752258300781,"wait":0},{"y":-6.7317938804626469,"x":140.11334228515626,"z":-106.35968780517578,"wait":0},{"y":-8.009437561035157,"x":144.50914001464845,"z":-99.68336486816406,"wait":0},{"y":-7.41301155090332,"x":148.90695190429688,"z":-93.00772857666016,"wait":0},{"y":-3.2090842723846437,"x":152.66018676757813,"z":-87.3082046508789,"wait":0},{"y":-3.0038981437683107,"x":157.10255432128907,"z":-80.56214141845703,"wait":0},{"y":-3.0000007152557375,"x":161.72775268554688,"z":-73.53717803955078,"wait":0},{"y":-3,"x":166.26087951660157,"z":-66.66087341308594,"wait":0},{"y":-3,"x":171.20616149902345,"z":-59.14838409423828,"wait":0},{"y":-3,"x":175.64662170410157,"z":-52.40434646606445,"wait":0},{"y":-3,"x":180.0887451171875,"z":-45.658016204833987,"wait":0},{"y":-3.0000007152557375,"x":184.54478454589845,"z":-38.89174270629883,"wait":0},{"y":-3.0054919719696047,"x":188.98760986328126,"z":-32.145973205566409,"wait":0},{"y":-3.2284648418426515,"x":193.4742431640625,"z":-25.332782745361329,"wait":0},{"y":-5.811498641967773,"x":197.7335662841797,"z":-18.865137100219728,"wait":0},{"y":-7.128543376922607,"x":202.1291046142578,"z":-12.191356658935547,"wait":0},{"y":-7.3712944984436039,"x":206.70957946777345,"z":-5.236634731292725,"wait":0},{"y":-7.270068168640137,"x":211.29002380371095,"z":1.7180296182632447,"wait":0},{"y":-3.9255690574645998,"x":215.501953125,"z":8.113595962524414,"wait":0},{"y":-3.005762815475464,"x":219.98977661132813,"z":14.929499626159668,"wait":0},{"y":-3.028350591659546,"x":224.4766387939453,"z":21.742631912231447,"wait":0},{"y":-3.053626775741577,"x":228.91900634765626,"z":28.488645553588868,"wait":0},{"y":-3.0059266090393068,"x":233.36029052734376,"z":35.23193359375,"wait":0},{"y":-3.034118413925171,"x":237.8032684326172,"z":41.9776611328125,"wait":0},{"y":-3.0000007152557375,"x":242.28968811035157,"z":48.790985107421878,"wait":0},{"y":-3.0000007152557375,"x":246.77804565429688,"z":55.60652160644531,"wait":0},{"y":-3.0000007152557375,"x":251.26644897460938,"z":62.422183990478519,"wait":0},{"y":-3.0000007152557375,"x":255.890625,"z":69.44407653808594,"wait":0},{"y":-3.1490402221679689,"x":260.3794860839844,"z":76.25904083251953,"wait":0},{"y":-3.672097682952881,"x":264.77496337890627,"z":82.93295288085938,"wait":0},{"y":-5.989034175872803,"x":269.171630859375,"z":89.6097183227539,"wait":0},{"y":-7.587728977203369,"x":273.6144714355469,"z":96.3554458618164,"wait":0},{"y":-7.528330326080322,"x":278.1007080078125,"z":103.16841125488281,"wait":0},{"y":-7.12064790725708,"x":282.4977722167969,"z":109.84442901611328,"wait":0},{"y":-7.964932441711426,"x":286.8932189941406,"z":116.51830291748047,"wait":0},{"y":-7.575207233428955,"x":291.2892150878906,"z":123.19534301757813,"wait":0},{"y":-7.54080867767334,"x":295.8235168457031,"z":130.080810546875,"wait":0},{"y":-7.163589954376221,"x":300.2643737792969,"z":136.8243865966797,"wait":0},{"y":-7.0296101570129398,"x":304.75311279296877,"z":143.63917541503907,"wait":0},{"y":-7.282549858093262,"x":309.1936340332031,"z":150.38302612304688,"wait":0},{"y":-7.532558441162109,"x":313.6345520019531,"z":157.1297607421875,"wait":0},{"y":-7.111080646514893,"x":318.2183532714844,"z":164.0897979736328,"wait":0},{"y":-8.056778907775879,"x":322.752197265625,"z":170.97508239746095,"wait":0},{"y":-8.05171012878418,"x":327.2420654296875,"z":177.7893524169922,"wait":0},{"y":-7.0002360343933109,"x":331.6826171875,"z":184.5333709716797,"wait":0},{"y":-6.999999523162842,"x":336.12579345703127,"z":191.27883911132813,"wait":0},{"y":-7.000002384185791,"x":340.70513916015627,"z":198.2301788330078,"wait":0},{"y":-7.15361213684082,"x":345.1466979980469,"z":204.9734649658203,"wait":0},{"y":-4.287123680114746,"x":349.9560852050781,"z":211.10720825195313,"wait":0},{"y":-3.272500991821289,"x":357.2558288574219,"z":214.86666870117188,"wait":0},{"y":-3.390688896179199,"x":365.09814453125,"z":217.09854125976563,"wait":0},{"y":-3.0000014305114748,"x":372.8932800292969,"z":218.86985778808595,"wait":0},{"y":-3.0000007152557375,"x":381.0392150878906,"z":220.5995330810547,"wait":0},{"y":-3.0000007152557375,"x":388.9437255859375,"z":222.24703979492188,"wait":0},{"y":-3.0000007152557375,"x":397.1799011230469,"z":223.9515380859375,"wait":0},{"y":-3.0000007152557375,"x":405.4132385253906,"z":225.6543731689453,"wait":0},{"y":-3.0000007152557375,"x":413.7311096191406,"z":227.3717041015625,"wait":0},{"y":-3,"x":421.96875,"z":229.07569885253907,"wait":0},{"y":-3,"x":430.209716796875,"z":230.77420043945313,"wait":0},{"y":-3,"x":438.2799987792969,"z":232.44049072265626,"wait":0},{"y":0.48485344648361208,"x":446.06903076171877,"z":234.36465454101563,"wait":0},{"y":7.028285503387451,"x":450.99371337890627,"z":235.2230224609375,"wait":0},{"y":11.753693580627442,"x":457.36541748046877,"z":236.4044647216797,"wait":0},{"y":11.84106159210205,"x":458.3529357910156,"z":236.59222412109376,"wait":1.4499790668487549},{"y":11.45576286315918,"x":461.7592468261719,"z":229.35191345214845,"wait":0},{"y":11.85943603515625,"x":464.84527587890627,"z":221.88729858398438,"wait":0},{"y":13.749516487121582,"x":467.9778747558594,"z":214.1746826171875,"wait":0},{"y":15.247159957885743,"x":471.00177001953127,"z":206.6843719482422,"wait":0},{"y":16.4955997467041,"x":474.04583740234377,"z":199.1160430908203,"wait":0},{"y":16.515216827392579,"x":475.1136474609375,"z":191.11631774902345,"wait":0},{"y":14.295809745788575,"x":473.49688720703127,"z":183.38296508789063,"wait":0},{"y":13.211498260498047,"x":471.04998779296877,"z":175.776611328125,"wait":0},{"y":12.299513816833496,"x":468.3323669433594,"z":168.17031860351563,"wait":0},{"y":10.92034912109375,"x":465.48150634765627,"z":160.52114868164063,"wait":0},{"y":16.069211959838868,"x":462.95599365234377,"z":153.67176818847657,"wait":0},{"y":15.745936393737793,"x":461.21044921875,"z":148.94798278808595,"wait":1.0226492881774903},{"y":16.25413703918457,"x":462.82647705078127,"z":145.49606323242188,"wait":0},{"y":14.816715240478516,"x":466.9288330078125,"z":138.5219268798828,"wait":0},{"y":9.110369682312012,"x":470.0314025878906,"z":133.38633728027345,"wait":0},{"y":2.3803634643554689,"x":472.5009460449219,"z":129.3203125,"wait":0},{"y":-1.871986985206604,"x":473.5417175292969,"z":127.6126708984375,"je":true,"wait":0},{"y":-4.148721218109131,"x":475.01513671875,"z":125.1961441040039,"wait":0},{"y":-3.5270168781280519,"x":479.4383850097656,"z":117.94802856445313,"wait":0},{"y":-7.16754674911499,"x":483.21478271484377,"z":111.7659912109375,"wait":0},{"y":-7.012042045593262,"x":487.6044616699219,"z":104.60494232177735,"wait":0},{"y":-7.735387802124023,"x":491.9388122558594,"z":97.49285888671875,"wait":0},{"y":-7.009095191955566,"x":496.1896057128906,"z":90.52693939208985,"wait":0},{"y":-7.338131904602051,"x":500.52862548828127,"z":83.42251586914063,"wait":0},{"y":-7.089003562927246,"x":504.7366638183594,"z":76.53170776367188,"wait":0},{"y":-7.530472755432129,"x":509.0763854980469,"z":69.42465209960938,"wait":0},{"y":-7.21080207824707,"x":513.2874145507813,"z":62.5319709777832,"wait":0},{"y":-7.374630928039551,"x":517.5813598632813,"z":55.49870681762695,"wait":0},{"y":-7.028688430786133,"x":522.0546264648438,"z":48.179866790771487,"wait":0},{"y":-7.338730812072754,"x":526.3099975585938,"z":41.22046661376953,"wait":0},{"y":-7.661015033721924,"x":530.6920776367188,"z":34.04130172729492,"wait":0},{"y":-7.364872455596924,"x":534.9436645507813,"z":27.078935623168947,"wait":0},{"y":-7.325905799865723,"x":539.24267578125,"z":20.045011520385743,"wait":0},{"y":-7.590291976928711,"x":543.5375366210938,"z":13.00870418548584,"wait":0},{"y":-7.11051607131958,"x":547.7920532226563,"z":6.048131465911865,"wait":0},{"y":-7.956323623657227,"x":552.3049926757813,"z":-1.3434178829193116,"wait":0},{"y":-7.168111801147461,"x":556.5588989257813,"z":-8.304039001464844,"wait":0},{"y":-7.530013084411621,"x":560.7227172851563,"z":-15.128461837768555,"wait":0},{"y":-7.343806266784668,"x":564.9774780273438,"z":-22.091819763183595,"wait":0},{"y":-7.070738792419434,"x":569.27490234375,"z":-29.123985290527345,"wait":0},{"y":-7.788933277130127,"x":573.4854736328125,"z":-36.016910552978519,"wait":0},{"y":-7.161074161529541,"x":577.6544799804688,"z":-42.83480453491211,"wait":0},{"y":-7.347146987915039,"x":581.9071044921875,"z":-49.79994201660156,"wait":0},{"y":-7.123679161071777,"x":586.1155395507813,"z":-56.6904182434082,"wait":0},{"y":-7.4687395095825199,"x":590.3278198242188,"z":-63.582576751708987,"wait":0},{"y":-7.309905529022217,"x":594.7095947265625,"z":-70.7577896118164,"wait":0},{"y":-7.364235877990723,"x":599.0936279296875,"z":-77.9359130859375,"wait":0},{"y":-7.0673322677612309,"x":603.4779052734375,"z":-85.11029815673828,"wait":0},{"y":-7.291280269622803,"x":607.6864013671875,"z":-92.00434875488281,"wait":0},{"y":-7.769351005554199,"x":611.8663940429688,"z":-98.84810638427735,"wait":0},{"y":-7.021990776062012,"x":616.092529296875,"z":-105.76074981689453,"wait":0},{"y":-5.693826198577881,"x":620.2593994140625,"z":-112.58296203613281,"wait":0},{"y":-3.0407814979553224,"x":624.2586059570313,"z":-119.13079071044922,"wait":0},{"y":-3.7966084480285646,"x":628.6192626953125,"z":-126.26834869384766,"wait":0},{"y":-3.0726563930511476,"x":632.7848510742188,"z":-133.085693359375,"wait":0},{"y":-3.8154258728027345,"x":636.9389038085938,"z":-139.89065551757813,"wait":0},{"y":-1.409656047821045,"x":641.179931640625,"z":-146.8397216796875,"wait":0},{"y":4.575130462646484,"x":644.252685546875,"z":-151.49899291992188,"wait":0},{"y":9.179071426391602,"x":647.6142578125,"z":-157.25149536132813,"wait":0},{"y":13.523193359375,"x":651.2959594726563,"z":-162.92042541503907,"wait":0},{"y":20.91107749938965,"x":653.1204833984375,"z":-165.58229064941407,"wait":0},{"y":27.63093376159668,"x":655.5924682617188,"z":-169.77786254882813,"wait":0},{"y":31.847450256347658,"x":659.0084838867188,"z":-175.75790405273438,"wait":0},{"y":32.74032211303711,"x":663.094482421875,"z":-182.64456176757813,"wait":0},{"y":32.97446823120117,"x":664.2620849609375,"z":-184.6013946533203,"wait":1.4560985565185547},{"y":32.913124084472659,"x":670.2081909179688,"z":-186.74720764160157,"wait":0},{"y":32.933223724365237,"x":678.0078125,"z":-189.15118408203126,"wait":0},{"y":30.521699905395509,"x":685.4988403320313,"z":-191.42445373535157,"wait":0},{"y":28.687511444091798,"x":693.1469116210938,"z":-193.74037170410157,"wait":0},{"y":28.329082489013673,"x":700.70849609375,"z":-196.51693725585938,"wait":0},{"y":26.664064407348634,"x":707.0687866210938,"z":-201.5331573486328,"wait":0},{"y":24.760549545288087,"x":712.569580078125,"z":-207.19415283203126,"wait":0},{"y":25.067609786987306,"x":714.5003051757813,"z":-215.27252197265626,"wait":0},{"y":30.818532943725587,"x":712.9913940429688,"z":-221.05007934570313,"wait":0},{"y":37.784576416015628,"x":712.0764770507813,"z":-225.9413604736328,"wait":0},{"y":44.21246337890625,"x":710.5833740234375,"z":-230.5003204345703,"wait":0},{"y":50.577415466308597,"x":708.62109375,"z":-235.25413513183595,"wait":0},{"y":54.82941818237305,"x":706.796875,"z":-242.2490997314453,"wait":0},{"y":55.83097839355469,"x":705.2372436523438,"z":-250.0864715576172,"wait":0},{"y":52.55326843261719,"x":703.86962890625,"z":-257.9624938964844,"wait":0},{"y":47.89691925048828,"x":702.7646484375,"z":-264.52520751953127,"wait":0},{"y":44.11769485473633,"x":701.5946044921875,"z":-271.5301513671875,"wait":0},{"y":40.75978088378906,"x":700.3897705078125,"z":-278.77471923828127,"wait":0},{"y":36.50869369506836,"x":699.2705688476563,"z":-285.50994873046877,"wait":0},{"y":35.150840759277347,"x":697.8598022460938,"z":-293.9938659667969,"wait":0},{"y":34.388671875,"x":696.5205078125,"z":-302.0576477050781,"wait":0},{"y":35.10810089111328,"x":695.1948852539063,"z":-310.0250549316406,"wait":0},{"y":40.002830505371097,"x":694.0700073242188,"z":-316.88983154296877,"wait":0},{"y":45.11918258666992,"x":693.0413818359375,"z":-323.0121765136719,"wait":0},{"y":50.75611114501953,"x":691.8460693359375,"z":-329.38909912109377,"wait":0},{"y":57.292118072509769,"x":691.1063232421875,"z":-333.9903869628906,"wait":0},{"y":59.71841049194336,"x":689.9188842773438,"z":-341.5635986328125,"wait":0},{"y":60.235408782958987,"x":688.6304931640625,"z":-349.45025634765627,"wait":0},{"y":62.48789978027344,"x":687.3013916015625,"z":-357.47308349609377,"wait":0},{"y":69.53299713134766,"x":686.70263671875,"z":-361.62860107421877,"wait":0},{"y":76.78648376464844,"x":685.8631591796875,"z":-365.83868408203127,"wait":0},{"y":82.11214447021485,"x":684.6795043945313,"z":-372.12738037109377,"wait":0},{"y":81.70955657958985,"x":683.2567749023438,"z":-380.36358642578127,"wait":0},{"y":80.1689453125,"x":682.033447265625,"z":-388.6476135253906,"wait":0},{"y":81.18669891357422,"x":681.514404296875,"z":-392.1940002441406,"wait":1.6057634353637696},{"y":79.00593566894531,"x":674.0652465820313,"z":-388.2196960449219,"wait":0},{"y":76.67778015136719,"x":666.69775390625,"z":-383.8841247558594,"wait":0},{"y":72.92474365234375,"x":660.1915893554688,"z":-379.9940490722656,"wait":0},{"y":66.10559844970703,"x":656.5462646484375,"z":-377.8095703125,"wait":0},{"y":58.30290603637695,"x":653.5452270507813,"z":-376.0091857910156,"wait":0},{"y":57.24641799926758,"x":653.2593383789063,"z":-375.8377990722656,"je":true,"wait":0},{"y":52.937713623046878,"x":648.4059448242188,"z":-372.92510986328127,"wait":0},{"y":53.128875732421878,"x":641.0759887695313,"z":-368.52520751953127,"wait":0},{"y":50.62853240966797,"x":634.1755981445313,"z":-364.7495422363281,"wait":0},{"y":45.34283447265625,"x":628.3419799804688,"z":-362.411376953125,"wait":0},{"y":39.84938049316406,"x":622.5546875,"z":-360.3320617675781,"wait":0},{"y":35.938194274902347,"x":615.6476440429688,"z":-357.9307861328125,"wait":0},{"y":30.606597900390626,"x":609.66357421875,"z":-355.8623962402344,"wait":0},{"y":25.918853759765626,"x":602.5623168945313,"z":-353.4165344238281,"wait":0},{"y":18.16544532775879,"x":598.9238891601563,"z":-352.16497802734377,"wait":0},{"y":10.062990188598633,"x":597.3026733398438,"z":-351.5994873046875,"wait":0},{"y":0.9925354719161987,"x":596.5465698242188,"z":-351.2769775390625,"wait":0},{"y":-5.672823429107666,"x":596.4554443359375,"z":-351.19281005859377,"je":true,"wait":0},{"y":-6.917685508728027,"x":598.30908203125,"z":-351.4815979003906,"wait":0},{"y":-7.110432147979736,"x":606.4177856445313,"z":-353.22723388671877,"wait":0},{"y":-7.230934143066406,"x":614.02734375,"z":-354.91552734375,"wait":1.4910707473754883},{"y":-7.23314094543457,"x":614.22021484375,"z":-355.09991455078127,"wait":0},{"y":-7.602446556091309,"x":618.4910278320313,"z":-361.9365539550781,"wait":0},{"y":-7.9715704917907719,"x":622.84912109375,"z":-369.4169921875,"wait":0},{"y":-7.757409572601318,"x":627.0532836914063,"z":-376.701416015625,"wait":0},{"y":-7.65208101272583,"x":629.1249389648438,"z":-380.29156494140627,"wait":1.4622294902801514},{"y":-7.620601177215576,"x":620.4615478515625,"z":-381.88873291015627,"wait":0},{"y":-7.18554162979126,"x":612.2880249023438,"z":-382.968994140625,"wait":0},{"y":-4.921070098876953,"x":604.6099243164063,"z":-383.94598388671877,"wait":0},{"y":-3.387490749359131,"x":596.5116577148438,"z":-384.96380615234377,"wait":0},{"y":-3.4293344020843508,"x":588.4837036132813,"z":-385.9685974121094,"wait":0},{"y":0.9356516599655151,"x":581.2945556640625,"z":-386.8675537109375,"wait":0},{"y":5.445587635040283,"x":574.630615234375,"z":-387.70062255859377,"wait":0},{"y":7.567537307739258,"x":566.7532348632813,"z":-388.75860595703127,"wait":0},{"y":10.2116060256958,"x":559.2289428710938,"z":-390.580810546875,"wait":0},{"y":10.9943208694458,"x":551.4129638671875,"z":-392.8476867675781,"wait":0},{"y":10.491096496582032,"x":543.6911010742188,"z":-395.16143798828127,"wait":0},{"y":6.5504279136657719,"x":536.9600830078125,"z":-397.1865539550781,"wait":0},{"y":2.801358699798584,"x":530.0089111328125,"z":-399.2831115722656,"wait":0},{"y":0.7467249631881714,"x":522.228759765625,"z":-401.6294250488281,"wait":0},{"y":-2.8250463008880617,"x":515.370361328125,"z":-403.69464111328127,"wait":0},{"y":-2.5795044898986818,"x":507.0318908691406,"z":-406.2091979980469,"wait":0},{"y":-3.974332809448242,"x":499.2245178222656,"z":-408.5633850097656,"wait":0},{"y":-2.7620577812194826,"x":491.4305725097656,"z":-410.9148254394531,"wait":0},{"y":-4.327113628387451,"x":483.5903015136719,"z":-413.27557373046877,"wait":0},{"y":-7.2935099601745609,"x":476.1283264160156,"z":-415.52520751953127,"wait":0},{"y":-7.33950138092041,"x":468.286865234375,"z":-417.8905334472656,"wait":0},{"y":-8.037564277648926,"x":460.4787292480469,"z":-420.244873046875,"wait":0},{"y":-7.2976460456848148,"x":452.8280944824219,"z":-422.5515441894531,"wait":0},{"y":-7.803943157196045,"x":444.8120422363281,"z":-424.9674377441406,"wait":0},{"y":-7.179257869720459,"x":436.8345642089844,"z":-427.3716735839844,"wait":0},{"y":-7.590875148773193,"x":429.1327209472656,"z":-429.6944580078125,"wait":0},{"y":-7.16456413269043,"x":421.1244812011719,"z":-432.10650634765627,"wait":0},{"y":-7.190698146820068,"x":412.7008361816406,"z":-434.6461486816406,"wait":0},{"y":-7.000518798828125,"x":405.0105285644531,"z":-436.9652404785156,"wait":0},{"y":-7.034213542938232,"x":397.2094421386719,"z":-439.3173828125,"wait":0},{"y":-7.000001907348633,"x":389.39874267578127,"z":-441.67291259765627,"wait":0},{"y":-7.21121072769165,"x":381.5845642089844,"z":-444.0273132324219,"wait":0},{"y":-7.675551891326904,"x":373.8544921875,"z":-446.3591003417969,"wait":0},{"y":-7.220145225524902,"x":366.118408203125,"z":-448.69024658203127,"wait":0},{"y":-7.886687278747559,"x":358.3871154785156,"z":-451.01971435546877,"wait":0},{"y":-7.047372341156006,"x":350.65283203125,"z":-453.3539733886719,"wait":0},{"y":-7.080526828765869,"x":342.61993408203127,"z":-455.77618408203127,"wait":0},{"y":-7.793741226196289,"x":334.7936096191406,"z":-458.1349182128906,"wait":0},{"y":-7.011049270629883,"x":326.8968200683594,"z":-460.5146789550781,"wait":0},{"y":-7.114130973815918,"x":319.1842956542969,"z":-462.8394470214844,"wait":0},{"y":-7.281739711761475,"x":311.3530578613281,"z":-465.19927978515627,"wait":0},{"y":-7.019803047180176,"x":302.98370361328127,"z":-467.7211608886719,"wait":0},{"y":-7.282322406768799,"x":295.2754211425781,"z":-470.04736328125,"wait":0},{"y":-7.998649597167969,"x":287.4546203613281,"z":-472.40740966796877,"wait":0},{"y":-7.032186508178711,"x":279.58526611328127,"z":-474.77752685546877,"wait":0},{"y":-7.124997615814209,"x":271.6929931640625,"z":-477.1578369140625,"wait":0},{"y":-7.1083903312683109,"x":263.6896667480469,"z":-479.5698547363281,"wait":0},{"y":-7.530112266540527,"x":255.98521423339845,"z":-481.89349365234377,"wait":0},{"y":-7.126552104949951,"x":248.22633361816407,"z":-484.2344665527344,"wait":0},{"y":-7.074397087097168,"x":240.20462036132813,"z":-486.65325927734377,"wait":0},{"y":-7.000560283660889,"x":232.47039794921876,"z":-488.98345947265627,"wait":0},{"y":-7.522353649139404,"x":224.739990234375,"z":-491.3154296875,"wait":0},{"y":-7.3015522956848148,"x":216.8410186767578,"z":-493.69573974609377,"wait":0},{"y":-7.258898735046387,"x":209.11073303222657,"z":-496.0262145996094,"wait":0},{"y":-7.558107376098633,"x":201.38377380371095,"z":-498.35614013671877,"wait":0},{"y":-7.002325057983398,"x":193.61676025390626,"z":-500.6972351074219,"wait":0},{"y":-7.038404941558838,"x":185.6460418701172,"z":-503.0984802246094,"wait":0},{"y":-7.591656684875488,"x":177.8854217529297,"z":-505.4389953613281,"wait":0},{"y":-7.102490425109863,"x":170.2345428466797,"z":-507.74664306640627,"wait":0},{"y":-7.0073137283325199,"x":162.30564880371095,"z":-510.13726806640627,"wait":0},{"y":-7.326370716094971,"x":154.51309204101563,"z":-512.4863891601563,"wait":0},{"y":-7.227177143096924,"x":146.67759704589845,"z":-514.8455200195313,"wait":0},{"y":-7.391300201416016,"x":138.94717407226563,"z":-517.1770629882813,"wait":0},{"y":-7.157790184020996,"x":131.2134552001953,"z":-519.5083618164063,"wait":0},{"y":-7.523771286010742,"x":123.40310668945313,"z":-521.8634643554688,"wait":0},{"y":-7.02444314956665,"x":115.67012786865235,"z":-524.1964111328125,"wait":0},{"y":-7,"x":107.92992401123047,"z":-526.52880859375,"wait":0},{"y":-7.000000476837158,"x":100.13946533203125,"z":-528.8770751953125,"wait":0},{"y":-7.039832592010498,"x":92.15013885498047,"z":-531.2841796875,"wait":0},{"y":-7.379545211791992,"x":84.49669647216797,"z":-533.5924072265625,"wait":0},{"y":-7.002558708190918,"x":76.572509765625,"z":-535.981689453125,"wait":0},{"y":-7.007366180419922,"x":68.6818618774414,"z":-538.3592529296875,"wait":0},{"y":-7.701509475708008,"x":60.868499755859378,"z":-540.7174072265625,"wait":0},{"y":-7.29200553894043,"x":53.15672302246094,"z":-543.0425415039063,"wait":0},{"y":-7.387746810913086,"x":45.47174072265625,"z":-545.3591918945313,"wait":0},{"y":-7.191561698913574,"x":37.278602600097659,"z":-547.8256225585938,"wait":0},{"y":-7.0012311935424809,"x":29.548316955566408,"z":-550.1576538085938,"wait":0},{"y":-7.419251441955566,"x":21.576053619384767,"z":-552.56298828125,"wait":0},{"y":-7.0005083084106449,"x":13.679533958435059,"z":-554.94287109375,"wait":0},{"y":-6.999999523162842,"x":5.706126689910889,"z":-557.3449096679688,"wait":0},{"y":-7,"x":-2.821469783782959,"z":-559.9188842773438,"wait":0},{"y":-6.7006611824035648,"x":-10.875372886657715,"z":-562.34326171875,"wait":0},{"y":-5.62270450592041,"x":-18.68504524230957,"z":-564.7001342773438,"wait":0},{"y":-7.001307487487793,"x":-26.3227481842041,"z":-566.99951171875,"wait":0},{"y":-7.000519752502441,"x":-33.98944854736328,"z":-569.3165283203125,"wait":0},{"y":-7.0026421546936039,"x":-41.741851806640628,"z":-571.6509399414063,"wait":0},{"y":-7.002289772033691,"x":-49.40281295776367,"z":-573.9580078125,"wait":0},{"y":-6.999999523162842,"x":-57.357662200927737,"z":-576.3563232421875,"wait":0},{"y":-7.0283002853393559,"x":-65.02650451660156,"z":-578.671142578125,"wait":0},{"y":-3.565021276473999,"x":-72.04277038574219,"z":-580.7833862304688,"wait":0},{"y":-4.155516624450684,"x":-79.79390716552735,"z":-583.1204223632813,"wait":0},{"y":-3.0242316722869875,"x":-87.56605529785156,"z":-585.461669921875,"wait":0},{"y":-3.0308339595794679,"x":-95.61537170410156,"z":-587.8905639648438,"wait":0},{"y":-3.01621413230896,"x":-103.58934020996094,"z":-590.2918701171875,"wait":0},{"y":-3.0000030994415285,"x":-111.39112854003906,"z":-592.6448974609375,"wait":0},{"y":-3.0000007152557375,"x":-119.07960510253906,"z":-594.9622802734375,"wait":0},{"y":-2.59077525138855,"x":-126.86775970458985,"z":-597.3125,"wait":0},{"y":-1.755813717842102,"x":-134.77178955078126,"z":-599.6950073242188,"wait":0},{"y":-2.123337984085083,"x":-142.54551696777345,"z":-602.038818359375,"wait":0},{"y":-2.009612798690796,"x":-150.51548767089845,"z":-604.4419555664063,"wait":0},{"y":0.7051832675933838,"x":-157.77713012695313,"z":-606.6317749023438,"wait":0},{"y":2.790698289871216,"x":-165.56680297851563,"z":-608.98046875,"wait":0},{"y":3.1155591011047365,"x":-173.51588439941407,"z":-611.3742065429688,"wait":0},{"y":3.7205758094787599,"x":-181.3619842529297,"z":-613.7427368164063,"wait":0},{"y":4.902507781982422,"x":-189.218994140625,"z":-616.1077270507813,"wait":0},{"y":5.724407196044922,"x":-196.84474182128907,"z":-618.4076538085938,"wait":0},{"y":7.396265983581543,"x":-204.75985717773438,"z":-620.69287109375,"wait":0},{"y":15.654847145080567,"x":-206.3967742919922,"z":-621.1373901367188,"wait":0},{"y":24.569238662719728,"x":-208.0517578125,"z":-621.694091796875,"wait":0},{"y":21.35697364807129,"x":-209.85789489746095,"z":-622.3070678710938,"je":true,"wait":0},{"y":20.188121795654298,"x":-209.85789489746095,"z":-622.3070678710938,"wait":1.2636466026306153},{"y":19.31083869934082,"x":-214.5227508544922,"z":-621.2655639648438,"wait":0},{"y":12.710576057434082,"x":-219.92518615722657,"z":-619.8567504882813,"wait":0},{"y":5.083705902099609,"x":-222.3416290283203,"z":-619.216796875,"wait":0},{"y":5.083705902099609,"x":-222.3416290283203,"z":-619.216796875,"je":true,"wait":0},{"y":2.42751145362854,"x":-229.9844512939453,"z":-617.1760864257813,"wait":0},{"y":0.0872860848903656,"x":-237.54234313964845,"z":-615.1513061523438,"wait":0},{"y":-1.9409257173538209,"x":-245.04493713378907,"z":-613.1320190429688,"wait":0},{"y":-2.682589530944824,"x":-252.83700561523438,"z":-611.0361938476563,"wait":0},{"y":-3.113699436187744,"x":-260.6350402832031,"z":-608.9406127929688,"wait":0},{"y":-3.4488255977630617,"x":-268.5162048339844,"z":-606.822998046875,"wait":0},{"y":-3.5567381381988527,"x":-277.11859130859377,"z":-604.5095825195313,"wait":0},{"y":-3.260840654373169,"x":-285.0001525878906,"z":-602.394287109375,"wait":0},{"y":-3.0328028202056886,"x":-292.755615234375,"z":-600.3096313476563,"wait":0},{"y":-3.0000007152557375,"x":-300.6338806152344,"z":-598.1913452148438,"wait":0},{"y":-3.0000007152557375,"x":-308.92572021484377,"z":-595.962646484375,"wait":0},{"y":-3.0000007152557375,"x":-316.685546875,"z":-593.876708984375,"wait":0},{"y":-3.0000007152557375,"x":-324.5567321777344,"z":-591.75830078125,"wait":0},{"y":-4.988672733306885,"x":-332.22625732421877,"z":-589.6973266601563,"wait":0},{"y":-7.000003814697266,"x":-339.86956787109377,"z":-587.6442260742188,"wait":0},{"y":-7.000062465667725,"x":-347.7105407714844,"z":-585.5343017578125,"wait":0},{"y":-6.053090572357178,"x":-355.65716552734377,"z":-583.396728515625,"wait":0},{"y":-3.002124547958374,"x":-363.00311279296877,"z":-581.425537109375,"wait":0},{"y":-3.0602192878723146,"x":-371.0411376953125,"z":-579.2610473632813,"wait":0},{"y":-3.4097518920898439,"x":-378.8473815917969,"z":-577.1633911132813,"wait":0},{"y":-4.438355445861816,"x":-386.64990234375,"z":-575.0643920898438,"wait":0},{"y":-6.290580749511719,"x":-394.3876037597656,"z":-574.0547485351563,"wait":0},{"y":-10.13266658782959,"x":-401.8323669433594,"z":-574.812744140625,"wait":0},{"y":-15.988511085510254,"x":-407.2892150878906,"z":-575.507568359375,"wait":0},{"y":-23.910167694091798,"x":-408.4605407714844,"z":-575.0309448242188,"wait":0},{"y":-29.715478897094728,"x":-408.58660888671877,"z":-574.4952392578125,"je":true,"wait":0},{"y":-31.230680465698243,"x":-408.7776184082031,"z":-571.0822143554688,"wait":0},{"y":-34.473602294921878,"x":-408.001708984375,"z":-563.3794555664063,"wait":0},{"y":-38.09488296508789,"x":-405.1241760253906,"z":-556.8026123046875,"wait":0},{"y":-40.729042053222659,"x":-397.53961181640627,"z":-556.6444091796875,"wait":0},{"y":-43.41329574584961,"x":-389.9273376464844,"z":-557.4844970703125,"wait":0},{"y":-43.55077362060547,"x":-381.64093017578127,"z":-558.6619262695313,"wait":0},{"y":-43.80417251586914,"x":-375.7265319824219,"z":-559.5388793945313,"wait":1.5155324935913087},{"y":-43.85457229614258,"x":-373.6593322753906,"z":-559.893798828125,"wait":0},{"y":-44.439510345458987,"x":-365.7987365722656,"z":-561.2677612304688,"wait":0},{"y":-46.55971908569336,"x":-358.17291259765627,"z":-562.6002197265625,"wait":0},{"y":-47.044559478759769,"x":-350.0523986816406,"z":-564.0216674804688,"wait":0},{"y":-47.16443634033203,"x":-341.3573303222656,"z":-565.543701171875,"wait":0},{"y":-47.32063293457031,"x":-333.20904541015627,"z":-566.9650268554688,"wait":0},{"y":-48.04740905761719,"x":-325.16986083984377,"z":-568.3717041015625,"wait":0},{"y":-48.84918975830078,"x":-317.01971435546877,"z":-569.240966796875,"wait":0},{"y":-52.480995178222659,"x":-309.8365478515625,"z":-567.3443603515625,"wait":0},{"y":-54.46361541748047,"x":-302.1413879394531,"z":-564.8971557617188,"wait":0},{"y":-56.27692794799805,"x":-294.4623107910156,"z":-562.4246215820313,"wait":0},{"y":-56.39665603637695,"x":-286.81219482421877,"z":-559.9541625976563,"wait":0},{"y":-56.78795623779297,"x":-279.04595947265627,"z":-557.4476928710938,"wait":0},{"y":-55.440040588378909,"x":-271.34454345703127,"z":-554.9605712890625,"wait":0},{"y":-55.23709487915039,"x":-263.47943115234377,"z":-552.4266967773438,"wait":0},{"y":-56.7910041809082,"x":-255.74839782714845,"z":-549.92822265625,"wait":0},{"y":-57.783958435058597,"x":-248.1215362548828,"z":-547.54638671875,"wait":0},{"y":-59.44690704345703,"x":-240.32431030273438,"z":-545.7905883789063,"wait":0},{"y":-59.57270431518555,"x":-232.4007568359375,"z":-544.2937622070313,"wait":0},{"y":-59.18153381347656,"x":-224.18907165527345,"z":-542.81787109375,"wait":0},{"y":-59.38557434082031,"x":-215.99874877929688,"z":-542.5812377929688,"wait":0},{"y":-59.155540466308597,"x":-208.07073974609376,"z":-544.163330078125,"wait":0},{"y":-57.775882720947269,"x":-200.27853393554688,"z":-545.7474975585938,"wait":0},{"y":-58.4985466003418,"x":-197.0535430908203,"z":-546.640380859375,"je":true,"wait":0},{"y":-61.59453582763672,"x":-193.11659240722657,"z":-547.7036743164063,"wait":0},{"y":-63.05666732788086,"x":-185.21534729003907,"z":-549.7715454101563,"wait":0},{"y":-63.694400787353519,"x":-177.7637939453125,"z":-552.968994140625,"wait":0},{"y":-63.08891677856445,"x":-175.1136016845703,"z":-560.556396484375,"wait":0},{"y":-63.44547653198242,"x":-173.32542419433595,"z":-568.4404296875,"wait":0},{"y":-64.56692504882813,"x":-171.9383544921875,"z":-576.323974609375,"wait":0},{"y":-63.320125579833987,"x":-173.87342834472657,"z":-584.2037963867188,"wait":0},{"y":-62.743831634521487,"x":-177.28082275390626,"z":-591.5269165039063,"wait":0},{"y":-62.123695373535159,"x":-180.9025421142578,"z":-598.8058471679688,"wait":0},{"y":-63.607295989990237,"x":-184.5108642578125,"z":-605.9811401367188,"wait":0},{"y":-63.008358001708987,"x":-188.85926818847657,"z":-612.9842529296875,"wait":0},{"y":-62.73700714111328,"x":-196.0369110107422,"z":-617.4323120117188,"wait":0},{"y":-61.469093322753909,"x":-203.38111877441407,"z":-620.917724609375,"wait":0},{"y":-61.39929962158203,"x":-210.30435180664063,"z":-624.0391845703125,"wait":1.5800633430480958},{"y":-59.83080291748047,"x":-199.6520233154297,"z":-613.8545532226563,"wait":0},{"y":-60.18386459350586,"x":-193.443603515625,"z":-608.5892944335938,"wait":0},{"y":-61.214447021484378,"x":-187.3262481689453,"z":-603.2883911132813,"wait":0},{"y":-60.93537902832031,"x":-181.34060668945313,"z":-597.3797607421875,"wait":0},{"y":-63.50018310546875,"x":-174.838623046875,"z":-593.0790405273438,"wait":0},{"y":-63.34138870239258,"x":-170.5838623046875,"z":-585.8370971679688,"wait":0},{"y":-64.15792083740235,"x":-170.47125244140626,"z":-577.7083740234375,"wait":0},{"y":-63.806026458740237,"x":-171.91050720214845,"z":-569.514404296875,"wait":0},{"y":-63.060577392578128,"x":-173.98814392089845,"z":-561.5391235351563,"wait":0},{"y":-63.68083572387695,"x":-176.21484375,"z":-553.8770751953125,"wait":0},{"y":-64.07735443115235,"x":-169.690673828125,"z":-549.0692749023438,"wait":0},{"y":-63.43544387817383,"x":-162.34396362304688,"z":-545.8935546875,"wait":0},{"y":-63.14801788330078,"x":-154.74119567871095,"z":-543.0169677734375,"wait":0},{"y":-63.44566345214844,"x":-147.05673217773438,"z":-540.2010498046875,"wait":0},{"y":-62.35673522949219,"x":-139.26747131347657,"z":-537.2861938476563,"wait":0},{"y":-57.935306549072269,"x":-134.96444702148438,"z":-532.1198120117188,"wait":0},{"y":-56.0096321105957,"x":-128.4114227294922,"z":-527.3952026367188,"wait":0},{"y":-56.91794967651367,"x":-120.91177368164063,"z":-524.6666870117188,"wait":0},{"y":-58.3989372253418,"x":-113.07735443115235,"z":-523.0932006835938,"wait":0},{"y":-59.238948822021487,"x":-105.14849090576172,"z":-522.1060180664063,"wait":0},{"y":-60.87437057495117,"x":-97.18724822998047,"z":-521.3837890625,"wait":0},{"y":-62.56792068481445,"x":-89.13645935058594,"z":-520.7664184570313,"wait":0},{"y":-64.59083557128906,"x":-81.16215515136719,"z":-520.2030029296875,"wait":0},{"y":-66.04432678222656,"x":-72.93760681152344,"z":-519.6365966796875,"wait":0},{"y":-67.11156463623047,"x":-64.79855346679688,"z":-519.0838623046875,"wait":0},{"y":-67.2824478149414,"x":-56.656436920166019,"z":-518.532470703125,"wait":0},{"y":-67.7286148071289,"x":-48.68339157104492,"z":-517.9952392578125,"wait":0},{"y":-68.05296325683594,"x":-40.656070709228519,"z":-517.1444091796875,"wait":0},{"y":-68.12335968017578,"x":-32.553077697753909,"z":-515.7949829101563,"wait":0},{"y":-69.5870361328125,"x":-24.677038192749025,"z":-513.8712158203125,"wait":0},{"y":-71.00151824951172,"x":-19.37312126159668,"z":-507.6861877441406,"wait":0},{"y":-70.33228302001953,"x":-16.783565521240236,"z":-500.133544921875,"wait":0},{"y":-70.57026672363281,"x":-14.610618591308594,"z":-492.1368103027344,"wait":0},{"y":-71.0000228881836,"x":-13.687149047851563,"z":-483.8608093261719,"wait":0},{"y":-71.31169128417969,"x":-15.609192848205567,"z":-475.7167053222656,"wait":0},{"y":-71.6668930053711,"x":-18.012691497802736,"z":-467.84808349609377,"wait":0},{"y":-71.3369140625,"x":-20.54158592224121,"z":-459.8841247558594,"wait":0},{"y":-73.69618225097656,"x":-23.089508056640626,"z":-451.9162902832031,"wait":0},{"y":-73.21489715576172,"x":-25.553680419921876,"z":-444.2276306152344,"wait":0},{"y":-73.1718978881836,"x":-28.0544376373291,"z":-436.42938232421877,"wait":0},{"y":-73.17188262939453,"x":-29.507577896118165,"z":-431.8905029296875,"wait":1.5776264667510987},{"y":-73.17188262939453,"x":-34.58697509765625,"z":-431.28106689453127,"wait":0},{"y":-73.48882293701172,"x":-42.65093994140625,"z":-430.8709716796875,"wait":0},{"y":-78.60726928710938,"x":-49.55214309692383,"z":-430.5221252441406,"wait":0},{"y":-86.67386627197266,"x":-50.939544677734378,"z":-430.29248046875,"wait":0},{"y":-96.13912200927735,"x":-50.943965911865237,"z":-430.03759765625,"wait":0},{"y":-101.31207275390625,"x":-50.61194610595703,"z":-429.9305114746094,"je":true,"wait":0},{"y":-103.00019073486328,"x":-46.91472625732422,"z":-428.9483337402344,"wait":0},{"y":-103.00841522216797,"x":-38.904476165771487,"z":-427.0115966796875,"wait":0},{"y":-103.00391387939453,"x":-31.03899574279785,"z":-425.1737976074219,"wait":0},{"y":-103.0000228881836,"x":-23.185993194580079,"z":-423.35528564453127,"wait":0},{"y":-103.0000228881836,"x":-15.024018287658692,"z":-421.46875,"wait":0},{"y":-103.0000228881836,"x":-7.176919460296631,"z":-419.65618896484377,"wait":0},{"y":-103.0000228881836,"x":0.8882570266723633,"z":-417.7955627441406,"wait":0},{"y":-103.0000228881836,"x":8.594498634338379,"z":-415.533447265625,"wait":0},{"y":-101.004638671875,"x":13.71017074584961,"z":-409.69781494140627,"wait":0},{"y":-99.20357513427735,"x":16.985872268676759,"z":-402.5000915527344,"wait":0},{"y":-99.0000228881836,"x":20.043704986572267,"z":-395.0895080566406,"wait":0},{"y":-98.96937561035156,"x":23.034772872924806,"z":-387.5896911621094,"wait":0},{"y":-99.4834976196289,"x":26.07613754272461,"z":-379.9268493652344,"wait":0},{"y":-99.01988983154297,"x":28.009092330932618,"z":-375.05426025390627,"wait":1.5508620738983155},{"y":-99.10733795166016,"x":30.640541076660158,"z":-373.33477783203127,"wait":0},{"y":-99.10966491699219,"x":37.671512603759769,"z":-369.2335205078125,"wait":0},{"y":-99.0000228881836,"x":44.96289825439453,"z":-365.046875,"wait":0},{"y":-99.00000762939453,"x":49.381080627441409,"z":-362.5165710449219,"wait":1.5842697620391846},{"y":-99.06427764892578,"x":38.255821228027347,"z":-369.57452392578127,"wait":0},{"y":-99.13245391845703,"x":31.35870933532715,"z":-373.9366760253906,"wait":0},{"y":-99.45785522460938,"x":26.046327590942384,"z":-379.9902038574219,"wait":0},{"y":-98.9970474243164,"x":23.002473831176759,"z":-387.4001159667969,"wait":0},{"y":-99.0000228881836,"x":20.526866912841798,"z":-395.09185791015627,"wait":0},{"y":-99.16875457763672,"x":18.091176986694337,"z":-403.1216125488281,"wait":0},{"y":-100.74839782714844,"x":14.997509956359864,"z":-410.5128479003906,"wait":0},{"y":-103.0008773803711,"x":7.631743431091309,"z":-412.80780029296877,"wait":0},{"y":-103.0000228881836,"x":-0.8627349138259888,"z":-413.8941345214844,"wait":0},{"y":-103.0000228881836,"x":-9.05588150024414,"z":-414.63958740234377,"wait":0},{"y":-103.0000228881836,"x":-17.114229202270509,"z":-415.3189697265625,"wait":0},{"y":-103.0000228881836,"x":-25.470237731933595,"z":-416.0111999511719,"wait":0},{"y":-103.0000228881836,"x":-33.60820007324219,"z":-416.6842956542969,"wait":0},{"y":-103.0000228881836,"x":-41.92525100708008,"z":-417.3710021972656,"wait":0},{"y":-103.0000228881836,"x":-49.9838981628418,"z":-418.0362243652344,"wait":0},{"y":-103.0000228881836,"x":-58.22035598754883,"z":-418.71722412109377,"wait":0},{"y":-103.0000228881836,"x":-66.27455139160156,"z":-419.3818359375,"wait":0},{"y":-103.0000228881836,"x":-74.49131774902344,"z":-420.0607604980469,"wait":0},{"y":-103.0000228881836,"x":-83.14464569091797,"z":-420.77484130859377,"wait":0},{"y":-103.0000228881836,"x":-91.4002456665039,"z":-421.4580383300781,"wait":0},{"y":-103.0000228881836,"x":-99.47430419921875,"z":-422.8227844238281,"wait":0},{"y":-103.00235748291016,"x":-105.55269622802735,"z":-428.21295166015627,"wait":0},{"y":-103.0000228881836,"x":-110.44831848144531,"z":-434.81573486328127,"wait":0},{"y":-103.0000228881836,"x":-115.24068450927735,"z":-441.681396484375,"wait":0},{"y":-103.0000228881836,"x":-119.8765640258789,"z":-448.4208984375,"wait":0},{"y":-103.0000228881836,"x":-124.56221771240235,"z":-455.2541198730469,"wait":0},{"y":-103.0000228881836,"x":-129.26927185058595,"z":-462.12005615234377,"wait":0},{"y":-103.0000228881836,"x":-133.93014526367188,"z":-468.9202575683594,"wait":0},{"y":-103.0000228881836,"x":-138.4999237060547,"z":-475.5857238769531,"wait":0},{"y":-103.0000228881836,"x":-143.2413330078125,"z":-482.505126953125,"wait":0},{"y":-103.0000228881836,"x":-148.06875610351563,"z":-488.9181213378906,"wait":0},{"y":-103.0000228881836,"x":-154.9096221923828,"z":-493.4083251953125,"wait":0},{"y":-103.32749938964844,"x":-162.14723205566407,"z":-496.8995666503906,"wait":0},{"y":-101.659912109375,"x":-169.12347412109376,"z":-500.65423583984377,"wait":0},{"y":-102.83323669433594,"x":-176.69021606445313,"z":-503.9764404296875,"wait":0},{"y":-103.0000228881836,"x":-184.4466552734375,"z":-506.8026123046875,"wait":0},{"y":-103.15715789794922,"x":-188.88229370117188,"z":-499.8164367675781,"wait":0},{"y":-102.99706268310547,"x":-190.73080444335938,"z":-491.3930358886719,"wait":0},{"y":-103.0000228881836,"x":-191.46121215820313,"z":-483.10028076171877,"wait":0},{"y":-103.3005599975586,"x":-191.99557495117188,"z":-474.7638244628906,"wait":0},{"y":-103.2338638305664,"x":-192.47239685058595,"z":-466.396240234375,"wait":0},{"y":-103.5468521118164,"x":-192.77992248535157,"z":-458.1611328125,"wait":0},{"y":-103.6082534790039,"x":-192.99264526367188,"z":-455.2645263671875,"wait":1.670943021774292},{"y":-103.21186828613281,"x":-192.545654296875,"z":-466.414794921875,"wait":0},{"y":-103.29425811767578,"x":-192.97286987304688,"z":-474.64422607421877,"wait":0},{"y":-103.00038146972656,"x":-193.38983154296876,"z":-482.7108154296875,"wait":0},{"y":-103.19700622558594,"x":-193.8039093017578,"z":-490.7774353027344,"wait":0},{"y":-103.28091430664063,"x":-193.9012908935547,"z":-498.77923583984377,"wait":0},{"y":-103.64444732666016,"x":-186.21670532226563,"z":-501.913330078125,"wait":0},{"y":-102.53726196289063,"x":-178.3530731201172,"z":-503.40533447265627,"wait":0},{"y":-103.00239562988281,"x":-169.97048950195313,"z":-504.47406005859377,"wait":0},{"y":-103.0000228881836,"x":-162.5163116455078,"z":-500.6137390136719,"wait":0},{"y":-103.0000228881836,"x":-156.89654541015626,"z":-494.4278869628906,"wait":0},{"y":-103.0000228881836,"x":-153.93771362304688,"z":-486.71563720703127,"wait":0},{"y":-103.0000228881836,"x":-153.49468994140626,"z":-478.416259765625,"wait":0},{"y":-103.0000228881836,"x":-153.36790466308595,"z":-470.187255859375,"wait":0},{"y":-103.0000228881836,"x":-153.2928466796875,"z":-462.0904235839844,"wait":0},{"y":-103.0000228881836,"x":-153.22650146484376,"z":-453.85040283203127,"wait":0},{"y":-103.0000228881836,"x":-153.16163635253907,"z":-445.7607116699219,"wait":0},{"y":-103.0000228881836,"x":-153.0965576171875,"z":-437.5560607910156,"wait":0},{"y":-103.0000228881836,"x":-153.03273010253907,"z":-429.2627868652344,"wait":0},{"y":-103.0000228881836,"x":-152.96986389160157,"z":-421.1844482421875,"wait":0},{"y":-103.0000228881836,"x":-152.90240478515626,"z":-412.8019714355469,"wait":0},{"y":-103.0000228881836,"x":-152.83673095703126,"z":-404.641845703125,"wait":0},{"y":-103.0000228881836,"x":-152.7737579345703,"z":-396.583251953125,"wait":0},{"y":-103.0000228881836,"x":-152.71070861816407,"z":-388.5626220703125,"wait":0},{"y":-103.0000228881836,"x":-152.64695739746095,"z":-380.40093994140627,"wait":0},{"y":-102.9763412475586,"x":-152.58270263671876,"z":-372.35791015625,"wait":0},{"y":-102.96123504638672,"x":-152.51913452148438,"z":-364.1116943359375,"wait":0},{"y":-103.0000228881836,"x":-152.4574432373047,"z":-356.0855407714844,"wait":0},{"y":-103.0000228881836,"x":-151.7234649658203,"z":-348.09832763671877,"wait":0},{"y":-103.0000228881836,"x":-144.7323760986328,"z":-343.0586242675781,"wait":0},{"y":-103.0000228881836,"x":-137.4949951171875,"z":-339.6466369628906,"wait":0},{"y":-103.0000228881836,"x":-129.92576599121095,"z":-336.30340576171877,"wait":0},{"y":-102.07798767089844,"x":-122.35196685791016,"z":-333.00286865234377,"wait":0},{"y":-100.08122253417969,"x":-115.02291107177735,"z":-329.81793212890627,"wait":0},{"y":-99.58488464355469,"x":-108.40689849853516,"z":-325.13836669921877,"wait":0},{"y":-97.39118957519531,"x":-109.59168243408203,"z":-317.53271484375,"wait":0},{"y":-95.12590789794922,"x":-111.95562744140625,"z":-310.0749816894531,"wait":0},{"y":-93.45269775390625,"x":-114.6566390991211,"z":-302.3795471191406,"wait":0},{"y":-91.68234252929688,"x":-117.3354263305664,"z":-294.9198913574219,"wait":0},{"y":-91.20999908447266,"x":-120.0572738647461,"z":-287.3755798339844,"wait":0},{"y":-90.30611419677735,"x":-122.98241424560547,"z":-279.2735900878906,"wait":0},{"y":-87.68865966796875,"x":-130.91233825683595,"z":-279.96539306640627,"wait":0},{"y":-87.36399841308594,"x":-137.0221405029297,"z":-285.572265625,"wait":0},{"y":-87.3593978881836,"x":-142.78515625,"z":-291.26251220703127,"wait":0},{"y":-87.34039306640625,"x":-148.52975463867188,"z":-297.02783203125,"wait":0},{"y":-86.61055755615235,"x":-154.39736938476563,"z":-302.93310546875,"wait":0},{"y":-83.81439208984375,"x":-159.78521728515626,"z":-308.3596496582031,"wait":0},{"y":-81.84538269042969,"x":-165.6206512451172,"z":-313.6573181152344,"wait":0},{"y":-79.65321350097656,"x":-173.07159423828126,"z":-315.6318359375,"wait":0},{"y":-79.55135345458985,"x":-181.21128845214845,"z":-316.93597412109377,"wait":0},{"y":-79.3195571899414,"x":-189.22409057617188,"z":-317.2283020019531,"wait":0},{"y":-79.05621337890625,"x":-197.513671875,"z":-315.6106262207031,"wait":0},{"y":-77.04719543457031,"x":-205.065673828125,"z":-313.6896057128906,"wait":0},{"y":-77.20759582519531,"x":-213.0179901123047,"z":-311.5703430175781,"wait":0},{"y":-78.87174224853516,"x":-220.86851501464845,"z":-309.4967041015625,"wait":0},{"y":-79.20915985107422,"x":-228.86968994140626,"z":-311.45703125,"wait":0},{"y":-79.0037612915039,"x":-235.55311584472657,"z":-316.6947937011719,"wait":0},{"y":-78.99958801269531,"x":-241.74595642089845,"z":-321.9819030761719,"wait":0},{"y":-79.00259399414063,"x":-248.39483642578126,"z":-327.7632751464844,"wait":0},{"y":-79.0000228881836,"x":-254.5823211669922,"z":-333.1620788574219,"wait":0},{"y":-79.0000228881836,"x":-260.8641052246094,"z":-338.6416015625,"wait":0},{"y":-79.0000228881836,"x":-267.05126953125,"z":-344.0413818359375,"wait":0},{"y":-79.0000228881836,"x":-273.363037109375,"z":-349.55047607421877,"wait":0},{"y":-79.0000228881836,"x":-279.6625061035156,"z":-355.0447998046875,"wait":0},{"y":-79.0000228881836,"x":-285.9393005371094,"z":-360.5213623046875,"wait":0},{"y":-79.0000228881836,"x":-292.1844482421875,"z":-365.9730224609375,"wait":0},{"y":-79.00000762939453,"x":-297.37445068359377,"z":-370.4991760253906,"wait":1.4365484714508057},{"y":-79.00000762939453,"x":-291.62774658203127,"z":-357.8793640136719,"wait":0},{"y":-79.00000762939453,"x":-288.0464172363281,"z":-350.3645935058594,"wait":0},{"y":-79.00000762939453,"x":-284.2156982421875,"z":-342.3509216308594,"wait":0},{"y":-79.00000762939453,"x":-280.6554870605469,"z":-334.9133605957031,"wait":0},{"y":-79.00000762939453,"x":-276.9012451171875,"z":-327.06927490234377,"wait":0},{"y":-79.00000762939453,"x":-273.28192138671877,"z":-319.5069885253906,"wait":0},{"y":-79.00000762939453,"x":-269.7490234375,"z":-312.1202087402344,"wait":0},{"y":-79.00000762939453,"x":-266.28155517578127,"z":-304.8718566894531,"wait":0},{"y":-79.00000762939453,"x":-262.72369384765627,"z":-297.4415283203125,"wait":0},{"y":-78.59386444091797,"x":-256.2841491699219,"z":-292.63043212890627,"wait":0},{"y":-79.0000228881836,"x":-250.3919219970703,"z":-287.1103210449219,"wait":0},{"y":-79.0000228881836,"x":-243.82357788085938,"z":-281.3385009765625,"wait":0},{"y":-79.03681945800781,"x":-237.7027130126953,"z":-276.0766296386719,"wait":0},{"y":-79.55098724365235,"x":-233.39581298828126,"z":-269.1363525390625,"wait":0},{"y":-81.29110717773438,"x":-232.73171997070313,"z":-261.06683349609377,"wait":0},{"y":-83.0021743774414,"x":-235.0763702392578,"z":-253.45005798339845,"wait":0},{"y":-83.22193145751953,"x":-238.9569854736328,"z":-246.0979766845703,"wait":0},{"y":-83.38810729980469,"x":-240.95672607421876,"z":-242.47689819335938,"wait":1.3592631816864014},{"y":-84.60821533203125,"x":-240.81396484375,"z":-238.2528076171875,"wait":0},{"y":-87.7630615234375,"x":-240.18014526367188,"z":-230.29872131347657,"wait":0},{"y":-94.97696685791016,"x":-239.91018676757813,"z":-227.0602264404297,"je":true,"wait":0},{"y":-95.88508605957031,"x":-239.8823699951172,"z":-226.72805786132813,"wait":0},{"y":-95.1406478881836,"x":-239.1945343017578,"z":-218.59918212890626,"wait":0},{"y":-95.21764373779297,"x":-238.47984313964845,"z":-210.21852111816407,"wait":0},{"y":-95.29814147949219,"x":-237.7635040283203,"z":-201.84158325195313,"wait":0},{"y":-95.41973876953125,"x":-237.06427001953126,"z":-193.66799926757813,"wait":0},{"y":-95.16014862060547,"x":-236.37071228027345,"z":-185.57467651367188,"wait":0},{"y":-95.15013885498047,"x":-235.6712646484375,"z":-177.4014129638672,"wait":0},{"y":-95.7784423828125,"x":-234.9707489013672,"z":-169.21070861816407,"wait":0},{"y":-95.50802612304688,"x":-234.2537384033203,"z":-160.8341064453125,"wait":0},{"y":-95.06207275390625,"x":-235.91075134277345,"z":-152.8211669921875,"wait":0},{"y":-95.09040069580078,"x":-240.7536163330078,"z":-146.1823272705078,"wait":0},{"y":-95.43467712402344,"x":-246.13931274414063,"z":-139.87867736816407,"wait":0},{"y":-95.35060119628906,"x":-251.40777587890626,"z":-133.85549926757813,"wait":0},{"y":-95.05113220214844,"x":-256.7920227050781,"z":-127.72476196289063,"wait":0},{"y":-95.08372497558594,"x":-262.3460998535156,"z":-121.40876770019531,"wait":0},{"y":-96.06777954101563,"x":-267.7268371582031,"z":-115.2909164428711,"wait":0},{"y":-95.56053924560547,"x":-273.3404541015625,"z":-108.9093246459961,"wait":0},{"y":-95.50126647949219,"x":-278.7353515625,"z":-102.77664184570313,"wait":0},{"y":-95.494140625,"x":-284.34521484375,"z":-96.39852905273438,"wait":0},{"y":-95.58851623535156,"x":-289.8227233886719,"z":-90.16734313964844,"wait":0},{"y":-95.10049438476563,"x":-295.2854309082031,"z":-83.95722961425781,"wait":0},{"y":-95.25189208984375,"x":-300.6796875,"z":-77.82442474365235,"wait":0},{"y":-95.53907012939453,"x":-306.2485046386719,"z":-71.4899673461914,"wait":0},{"y":-95.00977325439453,"x":-311.5279235839844,"z":-65.487548828125,"wait":0},{"y":-95.205322265625,"x":-316.9725341796875,"z":-59.34960174560547,"wait":0},{"y":-94.50775909423828,"x":-323.83258056640627,"z":-54.8558464050293,"wait":0},{"y":-91.4414291381836,"x":-331.0386657714844,"z":-52.09803771972656,"wait":0},{"y":-91.01563262939453,"x":-336.581298828125,"z":-50.15150833129883,"wait":1.588944673538208},{"y":-91.01563262939453,"x":-334.11767578125,"z":-59.783565521240237,"wait":0},{"y":-91.00910949707031,"x":-331.8623962402344,"z":-67.5396728515625,"wait":0},{"y":-91.0162124633789,"x":-329.48504638671877,"z":-75.60445404052735,"wait":0},{"y":-90.86689758300781,"x":-327.19390869140627,"z":-83.35013580322266,"wait":0},{"y":-88.68915557861328,"x":-324.9219055175781,"z":-91.01143646240235,"wait":0},{"y":-87.46976470947266,"x":-322.5797424316406,"z":-98.92567443847656,"wait":0},{"y":-85.3602523803711,"x":-320.3291320800781,"z":-106.3425521850586,"wait":0},{"y":-80.81025695800781,"x":-313.18975830078127,"z":-106.42723846435547,"wait":0},{"y":-77.2158432006836,"x":-306.255126953125,"z":-103.38365173339844,"wait":0},{"y":-75.10620880126953,"x":-299.089111328125,"z":-99.90970611572266,"wait":0},{"y":-73.88713836669922,"x":-291.94775390625,"z":-96.3560791015625,"wait":0},{"y":-71.35883331298828,"x":-284.8974914550781,"z":-92.83201599121094,"wait":0},{"y":-69.82528686523438,"x":-277.52899169921877,"z":-89.14897155761719,"wait":0},{"y":-69.84690856933594,"x":-269.9973449707031,"z":-86.18273162841797,"wait":0},{"y":-71.57597351074219,"x":-262.4790954589844,"z":-83.83684539794922,"wait":0},{"y":-71.12604522705078,"x":-254.61044311523438,"z":-81.4773178100586,"wait":0},{"y":-71.66641998291016,"x":-246.75372314453126,"z":-79.14107513427735,"wait":0},{"y":-71.6562728881836,"x":-239.0367431640625,"z":-76.85023498535156,"wait":0},{"y":-71.65625762939453,"x":-237.26670837402345,"z":-76.32398986816406,"wait":1.5718517303466797},{"y":-71.66549682617188,"x":-246.9252166748047,"z":-78.21912384033203,"wait":0},{"y":-71.1641616821289,"x":-254.92556762695313,"z":-79.82839965820313,"wait":0},{"y":-71.20623779296875,"x":-262.84417724609377,"z":-81.42240905761719,"wait":0},{"y":-70.3301010131836,"x":-270.8036193847656,"z":-82.79013061523438,"wait":0},{"y":-73.964111328125,"x":-276.643798828125,"z":-78.28082275390625,"wait":0},{"y":-81.57648468017578,"x":-279.09930419921877,"z":-74.6653823852539,"wait":0},{"y":-90.61671447753906,"x":-278.66131591796877,"z":-74.70281982421875,"wait":0},{"y":-99.28765869140625,"x":-278.06842041015627,"z":-75.07613372802735,"wait":0},{"y":-99.28765869140625,"x":-278.06842041015627,"z":-75.07613372802735,"je":true,"wait":0},{"y":-98.9645767211914,"x":-271.1318664550781,"z":-80.26033782958985,"wait":0},{"y":-98.08392333984375,"x":-264.7091979980469,"z":-85.28938293457031,"wait":0},{"y":-96.25541687011719,"x":-258.3803405761719,"z":-90.3104476928711,"wait":0},{"y":-95.49346160888672,"x":-252.1000518798828,"z":-95.31289672851563,"wait":0},{"y":-95.13741302490235,"x":-245.80117797851563,"z":-100.3310546875,"wait":0},{"y":-95.78372955322266,"x":-239.26271057128907,"z":-105.54320526123047,"wait":0},{"y":-95.3982162475586,"x":-233.00245666503907,"z":-110.53276824951172,"wait":0},{"y":-95.4618911743164,"x":-226.6862335205078,"z":-115.56742095947266,"wait":0},{"y":-96.00970458984375,"x":-218.7892608642578,"z":-117.10737609863281,"wait":0},{"y":-95.84959411621094,"x":-211.441650390625,"z":-113.36711120605469,"wait":0},{"y":-95.81422424316406,"x":-204.3310089111328,"z":-109.1684799194336,"wait":0},{"y":-95.3849105834961,"x":-197.4225616455078,"z":-104.97299194335938,"wait":0},{"y":-95.0003662109375,"x":-190.5538787841797,"z":-100.77723693847656,"wait":0},{"y":-95.56676483154297,"x":-183.65357971191407,"z":-96.5603256225586,"wait":0},{"y":-95.01188659667969,"x":-176.4329071044922,"z":-92.14485931396485,"wait":0},{"y":-95.82356262207031,"x":-169.5417938232422,"z":-87.93211364746094,"wait":0},{"y":-95.34286499023438,"x":-162.57553100585938,"z":-83.67276000976563,"wait":0},{"y":-95.32108306884766,"x":-155.71737670898438,"z":-79.47882080078125,"wait":0},{"y":-95.47438049316406,"x":-148.8396453857422,"z":-75.27346801757813,"wait":0},{"y":-95.62390899658203,"x":-141.41049194335938,"z":-70.73102569580078,"wait":0},{"y":-95.0869369506836,"x":-134.44827270507813,"z":-66.47403717041016,"wait":0},{"y":-95.12146759033203,"x":-127.4148178100586,"z":-62.17369842529297,"wait":0},{"y":-95.29737091064453,"x":-120.38385772705078,"z":-57.87479782104492,"wait":0},{"y":-95.20154571533203,"x":-113.4399185180664,"z":-53.6291618347168,"wait":0},{"y":-95.24391174316406,"x":-106.60929870605469,"z":-49.45254898071289,"wait":0},{"y":-95.1748046875,"x":-99.57574462890625,"z":-45.15232467651367,"wait":0},{"y":-95.20940399169922,"x":-92.54390716552735,"z":-40.85259246826172,"wait":0},{"y":-95.23202514648438,"x":-85.31775665283203,"z":-36.43485641479492,"wait":0},{"y":-95.00092315673828,"x":-78.2680435180664,"z":-32.12424850463867,"wait":0},{"y":-95.25447845458985,"x":-71.37073516845703,"z":-27.90684700012207,"wait":0},{"y":-95.24847412109375,"x":-64.54285430908203,"z":-23.732791900634767,"wait":0},{"y":-95.11585235595703,"x":-57.60979461669922,"z":-19.493133544921876,"wait":0},{"y":-95.13465881347656,"x":-50.610286712646487,"z":-15.213595390319825,"wait":0},{"y":-95.7011489868164,"x":-43.54233932495117,"z":-10.892990112304688,"wait":0},{"y":-95.26309967041016,"x":-36.698970794677737,"z":-6.708531856536865,"wait":0},{"y":-95.6635971069336,"x":-29.789241790771486,"z":-2.4837076663970949,"wait":0},{"y":-94.41082763671875,"x":-25.72913360595703,"z":-0.001806496293283999,"wait":1.5471832752227784},{"y":-95.25486755371094,"x":-34.787574768066409,"z":-9.007140159606934,"wait":0},{"y":-95.32012939453125,"x":-40.69121551513672,"z":-14.756710052490235,"wait":0},{"y":-95.11961364746094,"x":-46.59751892089844,"z":-20.508115768432618,"wait":0},{"y":-95.4991226196289,"x":-52.4429817199707,"z":-26.19837188720703,"wait":0},{"y":-95.46727752685547,"x":-58.46989059448242,"z":-32.06487274169922,"wait":0},{"y":-95.86622619628906,"x":-64.41999053955078,"z":-38.33735275268555,"wait":0},{"y":-95.54611206054688,"x":-68.07958221435547,"z":-45.51130676269531,"wait":0},{"y":-90.83207702636719,"x":-69.92127990722656,"z":-52.042442321777347,"wait":0},{"y":-88.67070007324219,"x":-71.13060760498047,"z":-59.93686294555664,"wait":0},{"y":-85.46156311035156,"x":-68.28465270996094,"z":-66.82933044433594,"wait":0},{"y":-81.01708221435547,"x":-62.43885803222656,"z":-70.73674011230469,"wait":0},{"y":-75.89154815673828,"x":-56.127925872802737,"z":-71.84492492675781,"wait":0},{"y":-74.21918487548828,"x":-49.4238166809082,"z":-67.68054962158203,"wait":0},{"y":-75.0000228881836,"x":-43.19775390625,"z":-62.41632843017578,"wait":0},{"y":-75.06688690185547,"x":-36.254722595214847,"z":-57.80823516845703,"wait":0},{"y":-75.01295471191406,"x":-30.30650520324707,"z":-52.1793327331543,"wait":0},{"y":-75.19525909423828,"x":-24.729110717773439,"z":-46.21562576293945,"wait":0},{"y":-75.93280029296875,"x":-19.51364517211914,"z":-39.61442565917969,"wait":0},{"y":-75.2955551147461,"x":-13.838732719421387,"z":-33.95344543457031,"wait":0},{"y":-75.05683898925781,"x":-5.454504489898682,"z":-35.88966369628906,"wait":0},{"y":-75.00959014892578,"x":2.0572946071624758,"z":-39.012489318847659,"wait":0},{"y":-75.0000228881836,"x":9.071783065795899,"z":-43.381805419921878,"wait":0},{"y":-75.0539321899414,"x":10.801355361938477,"z":-51.49696731567383,"wait":0},{"y":-75.30472564697266,"x":11.446725845336914,"z":-59.6290283203125,"wait":0},{"y":-75.1065902709961,"x":11.991899490356446,"z":-67.85926055908203,"wait":0},{"y":-76.00926208496094,"x":12.500266075134278,"z":-75.8924789428711,"wait":0},{"y":-76.04507446289063,"x":12.659834861755371,"z":-78.42720794677735,"wait":1.4772684574127198},{"y":-75.0000228881836,"x":17.300752639770509,"z":-69.25289916992188,"wait":0},{"y":-75.0000228881836,"x":20.821426391601564,"z":-61.89397430419922,"wait":0},{"y":-75.0000228881836,"x":24.288455963134767,"z":-54.59846496582031,"wait":0},{"y":-75.0000228881836,"x":27.998750686645509,"z":-46.77602767944336,"wait":0},{"y":-75.0000228881836,"x":31.458755493164064,"z":-39.47719192504883,"wait":0},{"y":-75.0000228881836,"x":34.956993103027347,"z":-32.097900390625,"wait":0},{"y":-75.0000228881836,"x":38.47318649291992,"z":-24.68043327331543,"wait":0},{"y":-75.0000228881836,"x":41.96271896362305,"z":-17.31771469116211,"wait":0},{"y":-75.0000228881836,"x":45.52302169799805,"z":-9.807963371276856,"wait":0},{"y":-75.0000228881836,"x":48.98276138305664,"z":-2.5089879035949709,"wait":0},{"y":-75.0000228881836,"x":52.58369827270508,"z":5.088653564453125,"wait":0},{"y":-75.79226684570313,"x":56.00741195678711,"z":12.312448501586914,"wait":0},{"y":-75.00025939941406,"x":62.157569885253909,"z":17.55959129333496,"wait":0},{"y":-75.0000228881836,"x":70.58848571777344,"z":19.307037353515626,"wait":0},{"y":-75.0000228881836,"x":78.62593841552735,"z":20.498252868652345,"wait":0},{"y":-75.0000228881836,"x":86.73448181152344,"z":21.593002319335939,"wait":0},{"y":-75.0000228881836,"x":94.76539611816406,"z":22.65597915649414,"wait":0},{"y":-75.0000228881836,"x":102.74687194824219,"z":23.70893096923828,"wait":0},{"y":-75.0000228881836,"x":111.29034423828125,"z":24.8348445892334,"wait":0},{"y":-75.0000228881836,"x":119.27385711669922,"z":25.886302947998048,"wait":0},{"y":-75.0000228881836,"x":127.58281707763672,"z":26.981748580932618,"wait":0},{"y":-75.0000228881836,"x":135.53225708007813,"z":28.028722763061525,"wait":0},{"y":-75.0000228881836,"x":143.5970458984375,"z":29.091856002807618,"wait":0},{"y":-75.00000762939453,"x":144.9455108642578,"z":29.269697189331056,"wait":1.5325384140014649},{"y":-75.00000762939453,"x":151.76617431640626,"z":28.582170486450197,"wait":0},{"y":-75.00000762939453,"x":159.9608154296875,"z":27.68195915222168,"wait":0},{"y":-75.00000762939453,"x":167.93524169921876,"z":26.158397674560548,"wait":0},{"y":-75.00000762939453,"x":170.85546875,"z":17.881656646728517,"wait":0},{"y":-75.00000762939453,"x":171.52731323242188,"z":9.833056449890137,"wait":0},{"y":-75.00000762939453,"x":171.99134826660157,"z":1.6606805324554444,"wait":0},{"y":-75.00000762939453,"x":172.40011596679688,"z":-6.433509826660156,"wait":0},{"y":-75.00000762939453,"x":172.79534912109376,"z":-14.456825256347657,"wait":0},{"y":-75.00000762939453,"x":173.2018280029297,"z":-22.765565872192384,"wait":0},{"y":-75.17245483398438,"x":173.61216735839845,"z":-31.139423370361329,"wait":0},{"y":-75.92736053466797,"x":174.02369689941407,"z":-39.5601806640625,"wait":0},{"y":-75.58517456054688,"x":174.43014526367188,"z":-47.853065490722659,"wait":0},{"y":-75.16510009765625,"x":174.82611083984376,"z":-55.934207916259769,"wait":0},{"y":-75.01639556884766,"x":175.22491455078126,"z":-64.08513641357422,"wait":0},{"y":-75.0156478881836,"x":174.630859375,"z":-72.32811737060547,"wait":0},{"y":-75.01580810546875,"x":171.8180694580078,"z":-79.84149932861328,"wait":0},{"y":-75.02052307128906,"x":168.56222534179688,"z":-87.25232696533203,"wait":0},{"y":-75.02300262451172,"x":165.1259002685547,"z":-94.87066650390625,"wait":0},{"y":-75.02503204345703,"x":161.66964721679688,"z":-102.49673461914063,"wait":0},{"y":-75.0156478881836,"x":158.3374481201172,"z":-109.84555053710938,"wait":0},{"y":-75.02508544921875,"x":154.99346923828126,"z":-117.21646118164063,"wait":0},{"y":-75.04359436035156,"x":151.5186767578125,"z":-124.87592315673828,"wait":0},{"y":-75.07734680175781,"x":148.14849853515626,"z":-132.30526733398438,"wait":0},{"y":-75.28207397460938,"x":143.9408721923828,"z":-139.43142700195313,"wait":0},{"y":-75.07830810546875,"x":135.7000274658203,"z":-141.3484649658203,"wait":0},{"y":-75.01316833496094,"x":127.35879516601563,"z":-141.61422729492188,"wait":0},{"y":-75.00027465820313,"x":119.28426361083985,"z":-141.6410369873047,"wait":0},{"y":-75.0548324584961,"x":111.15921020507813,"z":-140.83753967285157,"wait":0},{"y":-75.0998306274414,"x":105.6561508178711,"z":-134.71963500976563,"wait":0},{"y":-74.45967864990235,"x":101.0604248046875,"z":-127.77951049804688,"wait":0},{"y":-72.22066497802735,"x":96.52503204345703,"z":-121.45087432861328,"wait":0},{"y":-71.54167175292969,"x":91.30805206298828,"z":-114.93171691894531,"wait":0},{"y":-70.17618560791016,"x":86.04286193847656,"z":-108.50281524658203,"wait":0},{"y":-67.82273864746094,"x":81.12908172607422,"z":-102.52178192138672,"wait":0},{"y":-64.71809387207031,"x":77.52666473388672,"z":-96.00205993652344,"wait":0},{"y":-60.62605667114258,"x":75.28636169433594,"z":-89.03501892089844,"wait":0},{"y":-57.897701263427737,"x":73.19308471679688,"z":-81.4548110961914,"wait":0},{"y":-54.91436004638672,"x":71.26787567138672,"z":-74.2575912475586,"wait":0},{"y":-50.8989143371582,"x":69.42411041259766,"z":-67.3131103515625,"wait":0},{"y":-47.24289321899414,"x":64.7037582397461,"z":-61.59336471557617,"wait":0},{"y":-43.367828369140628,"x":58.05451583862305,"z":-58.82219314575195,"wait":0},{"y":-39.23350524902344,"x":51.41203308105469,"z":-56.48640823364258,"wait":0},{"y":-36.69324493408203,"x":44.15454864501953,"z":-54.156742095947269,"wait":0},{"y":-35.33768844604492,"x":36.0867919921875,"z":-55.16880798339844,"wait":0},{"y":-35.060791015625,"x":28.32188606262207,"z":-58.38996887207031,"wait":0},{"y":-35.0020866394043,"x":20.787893295288087,"z":-61.7922477722168,"wait":0},{"y":-35.0000114440918,"x":13.377726554870606,"z":-65.19942474365235,"wait":0},{"y":-35.0000114440918,"x":6.039177417755127,"z":-68.58511352539063,"wait":0},{"y":-35.14310073852539,"x":-1.4682810306549073,"z":-72.05075073242188,"wait":0},{"y":-36.4212532043457,"x":-8.781824111938477,"z":-75.42719268798828,"wait":0},{"y":-36.520652770996097,"x":-16.491052627563478,"z":-78.98625946044922,"wait":0},{"y":-35.513893127441409,"x":-23.829376220703126,"z":-82.3743896484375,"wait":0},{"y":-35.0000114440918,"x":-31.275236129760743,"z":-85.8128433227539,"wait":0},{"y":-35.071502685546878,"x":-38.725345611572269,"z":-89.25202941894531,"wait":0},{"y":-35.165122985839847,"x":-46.091575622558597,"z":-92.65276336669922,"wait":0},{"y":-35.10385513305664,"x":-53.54381561279297,"z":-96.09329223632813,"wait":0},{"y":-35.01390838623047,"x":-60.90253448486328,"z":-99.49068450927735,"wait":0},{"y":-35.200313568115237,"x":-68.38458251953125,"z":-102.94554901123047,"wait":0},{"y":-35.06224822998047,"x":-74.92207336425781,"z":-107.87227630615235,"wait":0},{"y":-35.0000114440918,"x":-81.5862045288086,"z":-113.00210571289063,"wait":0},{"y":-37.69038391113281,"x":-87.41824340820313,"z":-117.83500671386719,"wait":0},{"y":-40.799625396728519,"x":-93.15109252929688,"z":-122.78982543945313,"wait":0},{"y":-42.98895263671875,"x":-99.19387817382813,"z":-128.14971923828126,"wait":0},{"y":-38.65658187866211,"x":-104.2425537109375,"z":-132.65673828125,"wait":0},{"y":-35.005462646484378,"x":-109.74573516845703,"z":-137.69654846191407,"wait":0}]]]

-- Конвертируем JSON -> Lua-таблица точек (совместимо с твоим форматом Route)
local function GF_parseRoute(json: string)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then
        warn("[Gold Farm] Некорректный JSON маршрута")
        return nil
    end
    local out = {}
    for _, p in ipairs(data) do
        if p.x and p.y and p.z then
            table.insert(out, {
                pos        = Vector3.new(p.x, p.y, p.z),
                wait       = (p.wait and p.wait > 0) and p.wait or nil,
                jump_start = p.js or p.jump_start or nil,
                jump_end   = p.je or p.jump_end   or nil
            })
        end
    end
    return out
end

-- Перерисовка точек/линий, если твой роутер визуализирует
local function GF_redraw()
    local R = _G.__ROUTE
    if not R then return end
    if R._redraw and R._redraw.clearDots  then R._redraw.clearDots()  end
    if R._redraw and R._redraw.clearLines then R._redraw.clearLines() end
    if R._redraw and R._redraw.dot then
        for _,pp in ipairs(R.points) do
            R._redraw.dot(Color3.fromRGB(255,230,80), pp.pos, 0.6)
        end
    end
    if R._redraw and R._redraw.redrawLines then
        R._redraw.redrawLines()
    end
end

-- Основная загрузка в твою систему маршрута
local function GF_load()
    local R = _G.__ROUTE
    if not R then
        warn("[Gold Farm] __ROUTE не найден")
        return false
    end

    local pts = GF_parseRoute(GF_JSON)
    if not pts or #pts < 2 then
        pcall(function()
            Library:Notify{ Title="Gold Farm", Content="JSON пустой/битый. Вставь корректный маршрут.", Duration=4 }
        end)
        return false
    end

    table.clear(R.points)
    for _,v in ipairs(pts) do
        table.insert(R.points, v)
    end
    GF_redraw()

    pcall(function()
        Library:Notify{ Title="Gold Farm", Content=("Загружено точек: %d"):format(#R.points), Duration=3 }
    end)
    return true
end

-- Кнопки управления
Tabs.Gold:CreateButton({
    Title = "Load Gold Farm (JSON)",
    Callback = function()
        local ok = GF_load()
        if ok then
            -- Автосейв в твой автосейв-файл, если хочешь
            pcall(function()
                if Route_SaveToFile and _G.__ROUTE then
                    Route_SaveToFile("FluentScriptHub/specific-game/_route_autosave.json", _G.__ROUTE.points)
                end
            end)
        end
    end
})

Tabs.Gold:CreateButton({
    Title = "Start follow",
    Callback = function()
        if _G.__ROUTE and #_G.__ROUTE.points >= 2 then
            _ROUTE_startFollow()
        else
            pcall(function()
                Library:Notify{ Title="Gold Farm", Content="Сначала нажми Load Gold Farm.", Duration=3 }
            end)
        end
    end
})

Tabs.Gold:CreateButton({
    Title = "Stop follow",
    Callback = function()
        _ROUTE_stopFollow()
    end
})
-- ========= [ /TAB: Gold ] =========


-- ========= [ Finish / Autoload ] =========
Window:SelectTab(1)
Library:Notify{ Title="Fuger Hub", Content="Loaded: Configs + Survival + Gold + Route + Farming + Heal + Combat", Duration=6 }
pcall(function() SaveManager:LoadAutoloadConfig() end)
pcall(function()
    local ok = Route_LoadFromFile(ROUTE_AUTOSAVE, _G.__ROUTE, _G.__ROUTE._redraw)
    if ok then Library:Notify{ Title="Route", Content="Route autosave loaded", Duration=3 } end
end)
