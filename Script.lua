-- Fuger Hub — Booga Booga Reborn (full merged build)
-- UI: Fluent-Renewed  •  Автор: Fuger XD

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
local UIS               = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")

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

-- ========= [ ROUTE persist ] =========
local function routePath(cfg) return "FluentScriptHub/specific-game/"..sanitize(cfg)..".route.json" end
local ROUTE_AUTOSAVE = "FluentScriptHub/specific-game/_route_autosave.json"

local function encodeRoute(points)
    local t = {}
    for i,p in ipairs(points or {}) do
        t[i] = { x=p.pos.X, y=p.pos.Y, z=p.pos.Z, wait=p.wait or 0, js=p.jump_start or nil, je=p.jump_end or nil }
    end
    return t
end
local function decodeRoute(t)
    local out = {}
    for _,r in ipairs(t or {}) do
        table.insert(out, { pos=Vector3.new(r.x,r.y,r.z), wait=(r.wait and r.wait>0) and r.wait or nil, jump_start=r.js or nil, jump_end=r.je or nil })
    end
    return out
end
local function Route_SaveToFile(path, points)
    if not writefile then return false end
    local ok, json = pcall(function() return HttpService:JSONEncode(encodeRoute(points)) end)
    if not ok then return false end
    local ok2 = pcall(writefile, path, json)
    return ok2 == true or ok2 == nil
end
local function Route_LoadFromFile(path, Route, redraw)
    if not (isfile and readfile) or not isfile(path) then return false end
    local ok, json = pcall(readfile, path); if not ok then return false end
    local ok2, arr = pcall(function() return HttpService:JSONDecode(json) end); if not ok2 then return false end
    table.clear(Route.points)
    if redraw and type(redraw.clearDots) == "function" then redraw.clearDots() end
    for _,p in ipairs(decodeRoute(arr)) do
        table.insert(Route.points, p)
        if redraw and type(redraw.dot) == "function" then redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
        end
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
    Bloodfruit=94, Bluefruit=377, Lemon=99, Coconut=1, Jelly=604, Banana=606, Orange=602,
    Oddberry=32, Berry=35, Strangefruit=302, Strawberry=282, Sunfruit=128, Pumpkin=80,
    ["Prickly Pear"]=378, Apple=243, Barley=247, Cloudberry=101, Carrot=147
}
function getItemIdByName(name) local t=_G.fruittoitemid return t and t[name] or nil end
function consumeById(id)
    if not id then return false end
    if packets and packets.ConsumeItem and packets.ConsumeItem.send then pcall(function() packets.ConsumeItem.send(id) end); return true end
    if packets and packets.UseItem     and packets.UseItem.send     then pcall(function() packets.UseItem.send({itemID=id}) end); return true end
    if packets and packets.Eat         and packets.Eat.send         then pcall(function() packets.Eat.send(id) end); return true end
    if packets and packets.EatFood     and packets.EatFood.send     then pcall(function() packets.EatFood.send(id) end); return true end
    return false
end

-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })
local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input",{ Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)
Tabs.Configs:CreateButton({
    Title="Quick Save",
    Callback=function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), (_G.__ROUTE and _G.__ROUTE.points) or {})
        Route_SaveToFile(ROUTE_AUTOSAVE, (_G.__ROUTE and _G.__ROUTE.points) or {})
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title="Quick Load",
    Callback=function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        if _G.__ROUTE then
            local ok = Route_LoadFromFile(routePath(n), _G.__ROUTE, _G.__ROUTE._redraw)
            Library:Notify{ Title="Configs", Content="Loaded "..n..(ok and " +route" or " (no route file)"), Duration=3 }
        else
            Library:Notify{ Title="Configs", Content="Loaded "..n, Duration=3 }
        end
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg",{ Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)





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

-- ========= [ TAB: Heal (Auto-Heal) — ULTRA FAST, no "or" ] =========
local HealTab = Window:AddTab({ Title = "Heal", Icon = "heart" })

local heal_toggle = HealTab:CreateToggle("heal_auto", { Title = "Auto Heal", Default = false })
local heal_item   = HealTab:CreateDropdown("heal_item", {
    Title  = "Item to use",
    Values = { "Bloodfruit","Bluefruit","Berry","Strawberry","Coconut","Apple","Lemon","Orange","Banana" },
    Default = "Bloodfruit"
})

local heal_thresh = HealTab:CreateSlider("heal_thresh", { Title = "HP threshold (%)", Min = 1, Max = 100, Rounding = 0, Default = 70 })
local heal_cd     = HealTab:CreateSlider("heal_cd",     { Title = "Per-bite delay (s)", Min = 0.00, Max = 0.30, Rounding = 2, Default = 0.02 })
local heal_tick   = HealTab:CreateSlider("heal_tick",   { Title = "Check interval (s)", Min = 0.00, Max = 0.20, Rounding = 2, Default = 0.01 })
local heal_hyst   = HealTab:CreateSlider("heal_hyst",   { Title = "Extra heal margin (%)", Min = 0, Max = 30, Rounding = 0, Default = 4 })
local heal_burst  = HealTab:CreateSlider("heal_burst",  { Title = "Max items per burst", Min = 1, Max = 20, Rounding = 0, Default = 10 })

-- «ультра»: многократная отправка в один кадр (только если включено)
local heal_ultra  = HealTab:CreateToggle("heal_ultra",  { Title = "Ultra mode (multi-packet per frame)", Default = true })
local heal_ppf    = HealTab:CreateSlider("heal_ppf",    { Title = "Packets per frame (ultra)", Min = 1, Max = 6, Rounding = 0, Default = 3 })

local heal_debug  = HealTab:CreateToggle("heal_debug",  { Title = "Debug logs (F9)", Default = false })

local function readHPpct()
    if hum == nil then return 100 end
    if hum.Health == nil then return 100 end
    if hum.MaxHealth == nil then return 100 end
    if hum.MaxHealth == 0 then return 100 end
    local v = (hum.Health / hum.MaxHealth) * 100
    if v < 0 then v = 0 end
    if v > 100 then v = 100 end
    return v
end

task.spawn(function()
    while true do
        if heal_toggle.Value and hum ~= nil and hum.Parent ~= nil then
            local hp = readHPpct()
            local thresh = heal_thresh.Value
            if hp < thresh then
                local target = thresh + heal_hyst.Value
                if target > 100 then target = 100 end

                local rounds = 0
                local maxRounds = heal_burst.Value
                if maxRounds < 1 then maxRounds = 1 end

                repeat
                    local it = heal_item.Value
                    if it == nil or it == "" then it = "Bloodfruit" end

                    -- одна «укус/использование»
                    local did = false
                    local slot = getSlotByName(it)
                    if slot ~= nil then
                        did = consumeBySlot(slot)
                    end
                    if did == false then
                        local id = getItemIdByName(it)
                        if id ~= nil then
                            did = consumeById(id)
                        end
                    end

                    -- ультра: добавочные пакеты в этот же кадр
                    if heal_ultra.Value then
                        local n = heal_ppf.Value
                        if n < 1 then n = 1 end
                        local j = 2
                        while j <= n do
                            local slot2 = getSlotByName(it)
                            local used = false
                            if slot2 ~= nil then
                                used = consumeBySlot(slot2)
                            end
                            if used == false then
                                local id2 = getItemIdByName(it)
                                if id2 ~= nil then consumeById(id2) end
                            end
                            j = j + 1
                        end
                    end

                    rounds = rounds + 1
                    if heal_debug.Value then
                        local msg = "[AutoHeal] bite "..tostring(rounds)
                        if heal_ultra.Value then msg = msg.." x"..tostring(heal_ppf.Value) end
                        print(msg)
                    end

                    -- пауза между «раундами»
                    local d = heal_cd.Value
                    if d <= 0 then
                        task.wait()
                    else
                        task.wait(d)
                    end

                    hp = readHPpct()
                until hp >= target or rounds >= maxRounds
            end

            -- интервал проверки
            local tickDelay = heal_tick.Value
            if tickDelay <= 0 then task.wait() else task.wait(tickDelay) end
        else
            task.wait(0.12)
        end
    end
end)

-- ========= [ TAB: Combat (By Name) — v2, no-Humanoid + ancestor name match ] =========
local AntsNameTab = Window:AddTab({ Title = "Combat (By Name)", Icon = "target" })

local an_on      = AntsNameTab:CreateToggle("an_on",      { Title = "Enable", Default = false })
local an_range   = AntsNameTab:CreateSlider ("an_range",  { Title = "Range (studs)", Min = 6, Max = 160, Rounding = 0, Default = 38 })
local an_targets = AntsNameTab:CreateSlider ("an_targets",{ Title = "Max targets / cycle", Min = 1, Max = 10, Rounding = 0, Default = 6 })
local an_ptcd    = AntsNameTab:CreateSlider ("an_ptcd",   { Title = "Per-target cooldown (ms)", Min = 60, Max = 220, Rounding = 0, Default = 95 })
local an_cdms    = AntsNameTab:CreateSlider ("an_cdms",   { Title = "Cycle cooldown (ms)", Min = 14, Max = 80, Rounding = 0, Default = 24 })
local an_los     = AntsNameTab:CreateToggle("an_los",     { Title = "Line-of-sight check", Default = false })
local an_exact   = AntsNameTab:CreateToggle("an_exact",   { Title = "Exact match (off = contains)", Default = false })
local an_dbg     = AntsNameTab:CreateToggle("an_dbg",     { Title = "Debug (F9)", Default = false })

-- дефолт: бьём только слуг, королеву не трогаем
local DEFAULT_NAMES = {
    ["Queen Ant's Servant"] = true,
    ["Queen Ant’s Servant"] = true,
    ["servant"] = true, -- на всякий случай (т.к. an_exact по умолчанию выключен)
}
local NAME_SET = {}
for k,_ in pairs(DEFAULT_NAMES) do NAME_SET[string.lower(k)] = true end

local function namesArrayFromSet(set) local t={} for n,_ in pairs(set) do t[#t+1]=n end table.sort(t) return t end
local names_dropdown = AntsNameTab:CreateDropdown("an_names", {
    Title = "Whitelist (multi, by name)",
    Values = namesArrayFromSet(NAME_SET),
    Multi  = true,
    Default = {},
})
local newName=""
local nameInput = AntsNameTab:AddInput("an_add_input", { Title="Add name (exact or part)", Default="" })
nameInput:OnChanged(function(v) newName = tostring(v or "") end)
AntsNameTab:CreateButton({
    Title = "Add to whitelist",
    Callback = function()
        local s = (newName or ""):gsub("^%s+",""):gsub("%s+$","")
        if s ~= "" then
            NAME_SET[string.lower(s)] = true
            if names_dropdown.SetValues then names_dropdown:SetValues(namesArrayFromSet(NAME_SET)) end
            Library:Notify{ Title="By Name", Content=("Added: %s"):format(s), Duration=2 }
        end
    end
})
AntsNameTab:CreateButton({
    Title = "Clear whitelist (reset)",
    Callback = function()
        table.clear(NAME_SET)
        for k,_ in pairs(DEFAULT_NAMES) do NAME_SET[string.lower(k)] = true end
        if names_dropdown.SetValues then names_dropdown:SetValues(namesArrayFromSet(NAME_SET)) end
        Library:Notify{ Title="By Name", Content="Whitelist reset", Duration=2 }
    end
})

-- ===== helpers
local Players, RunService = game:GetService("Players"), game:GetService("RunService")
local plr = Players.LocalPlayer
local function myRoot()
    local c = plr.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local RAY = RaycastParams.new()
RAY.FilterType = Enum.RaycastFilterType.Exclude
local function hasLOS(a, b)
    if not an_los.Value then return true end
    RAY.FilterDescendantsInstances = { plr.Character }
    return workspace:Raycast(a, b - a, RAY) == nil
end

local function displayNameFromModel(m)
    if not m then return "" end
    if m.GetAttribute then
        local dn = m:GetAttribute("DisplayName") or m:GetAttribute("Name") or m:GetAttribute("NPCType")
        if dn and dn ~= "" then return tostring(dn) end
    end
    return tostring(m.Name or "")
end

local function nameMatches(str)
    local s = string.lower(tostring(str or ""))
    if s == "" then return false end
    if an_exact.Value then
        for k,_ in pairs(NAME_SET) do if s == k then return true end end
    else
        for k,_ in pairs(NAME_SET) do if s:find(k, 1, true) then return true end end
    end
    return false
end

-- подняться по предкам модели и найти ту, у которой совпадает имя/атрибуты
local function findNamedAncestorModel(m)
    local depth = 0
    local cur = m
    while cur and depth < 4 do
        if cur:IsA("Model") then
            local dn = displayNameFromModel(cur)
            if nameMatches(dn) or nameMatches(cur.Name) then
                return cur, (dn ~= "" and dn or cur.Name)
            end
        end
        cur = cur.Parent
        depth = depth + 1
    end
    return nil, nil
end

local function anyBasePart(m)
    if not m then return nil end
    return m:FindFirstChild("HumanoidRootPart")
        or m.PrimaryPart
        or m:FindFirstChildWhichIsA("BasePart")
        or (function()
            for _,d in ipairs(m:GetDescendants()) do
                if d:IsA("BasePart") then return d end
            end
        end)()
end

local function extractEID(m)
    if not m then return nil end
    if m.GetAttribute then
        local v = m:GetAttribute("EntityID") or m:GetAttribute("entityId") or m:GetAttribute("Id")
              or m:GetAttribute("Entity")   or m:GetAttribute("ServerId")
        if v then return v end
    end
    for _,d in ipairs(m:GetDescendants()) do
        if d.GetAttribute then
            local v = d:GetAttribute("EntityID") or d:GetAttribute("entityId") or d:GetAttribute("Id")
                  or d:GetAttribute("Entity")   or d:GetAttribute("ServerId")
            if v then return v end
        end
    end
    return nil
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { plr.Character }

local function collectByName(radius)
    local me = myRoot(); if not me then return {} end
    local hits = workspace:GetPartBoundsInRadius(me.Position, radius, overlap)
    if not hits or #hits == 0 then return {} end

    local out, seen = {}, {}
    for _,p in ipairs(hits) do
        if p:IsA("BasePart") and p.Parent then
            local mdl = p:FindFirstAncestorOfClass("Model")
            if mdl and not seen[mdl] then
                local named, label = findNamedAncestorModel(mdl)
                if named then
                    local part = anyBasePart(named)
                    if part and hasLOS(me.Position + Vector3.new(0,2.6,0), part.Position + Vector3.new(0,1.6,0)) then
                        seen[named] = true
                        local d = (part.Position - me.Position).Magnitude
                        out[#out+1] = {
                            model = named,
                            root  = part,
                            dist  = d,
                            name  = label or displayNameFromModel(named) or named.Name,
                            eid   = extractEID(named)
                        }
                    end
                end
            end
        end
    end
    table.sort(out, function(a,b) return a.dist < b.dist end)
    return out
end

-- дедуп ТОЛЬКО по модели (ID плавающий)
local lastHit = {}
local function pick(list, cap)
    local now = tick()
    local gap = (an_ptcd.Value or 95)/1000
    local out = {}
    for i=1,#list do
        local key = list[i].model
        if (now - (lastHit[key] or 0)) >= gap then
            out[#out+1] = list[i]
            if #out >= cap then break end
        end
    end
    if #out == 0 then
        for i=1, math.min(cap, #list) do out[#out+1] = list[i] end
    end
    return out
end

local function safeSwing(targets)
    if #targets == 0 then return end
    local ids = {}
    for i=1,#targets do if targets[i].eid ~= nil then ids[#ids+1] = targets[i].eid end end
    local sent = false
    if #ids > 0 then
        sent = pcall(function() swingtool(ids) end)
        if an_dbg.Value then print(("-- [ByName] by ID x%d -> %s"):format(#ids, sent and "OK" or "ERR")) end
    end
    if not sent then
        local insts = {}
        for i=1,#targets do insts[#insts+1] = targets[i].model end
        local ok2 = pcall(function() swingtool(insts) end)
        if an_dbg.Value then print(("-- [ByName] by INST x%d -> %s"):format(#insts, ok2 and "OK" or "ERR")) end
    end
    local t = tick()
    for i=1,#targets do lastHit[targets[i].model] = t end
end

task.spawn(function()
    while true do
        if an_on.Value then
            local near = collectByName(an_range.Value)
            if #near == 0 then
                if an_dbg.Value then print("-- [ByName] no targets") end
            else
                local picked = pick(near, math.max(1, math.floor(an_targets.Value)))
                if an_dbg.Value then
                    local a = picked[1]
                    print(string.format("-- [ByName] '%s' d=%.1f eid=%s", a.name, a.dist, tostring(a.eid)))
                end
                safeSwing(picked)
            end
            task.wait((an_cdms.Value or 24)/1000)
        else
            task.wait(0.15)
        end
    end
end)

-- пресеты
AntsNameTab:CreateButton({
    Title = "Preset: Servants only",
    Callback = function()
        an_on:SetValue(true)
        an_exact:SetValue(false) -- contains "servant"
        an_range:SetValue(40)
        an_targets:SetValue(6)
        an_ptcd:SetValue(90)
        an_cdms:SetValue(22)
        an_los:SetValue(false)
        table.clear(NAME_SET); NAME_SET["servant"]=true
        if names_dropdown.SetValues then names_dropdown:SetValues(namesArrayFromSet(NAME_SET)) end
    end
})
AntsNameTab:CreateButton({
    Title = "Preset: Exact 'Queen Ant’s Servant'",
    Callback = function()
        an_on:SetValue(true)
        an_exact:SetValue(true)
        table.clear(NAME_SET)
        NAME_SET[string.lower("Queen Ant's Servant")] = true
        NAME_SET[string.lower("Queen Ant’s Servant")] = true
        if names_dropdown.SetValues then names_dropdown:SetValues(namesArrayFromSet(NAME_SET)) end
        an_range:SetValue(38)
        an_targets:SetValue(6)
        an_ptcd:SetValue(95)
        an_cdms:SetValue(24)
        an_los:SetValue(false)
    end
})


-- ========= [ TAB: Farming (посадка/сбор + BV + Area Auto Build) ] =========
Tabs.Farming = Window:AddTab({ Title = "Farming", Icon = "shovel" })
local planttoggle     = Tabs.Farming:CreateToggle("planttoggle",    { Title = "Auto Plant (nearby Plant Boxes)", Default = false })
local plantrange      = Tabs.Farming:CreateSlider("plantrange",     { Title = "Plant range (studs)", Min = 8, Max = 150, Rounding = 0, Default = 30 })
local plantdelay      = Tabs.Farming:CreateSlider("plantdelay",     { Title = "Plant delay (s)", Min = 0.01, Max = 0.25, Rounding = 2, Default = 0.03 })
local fruitdropdownUI = Tabs.Farming:CreateDropdown("fruitdropdown",{ Title = "Seed / Fruit", Values = {
    "Bloodfruit","Bluefruit","Lemon","Coconut","Jelly","Banana","Orange","Oddberry",
    "Berry","Strangefruit","Strawberry","Sunfruit","Pumpkin","Prickly Pear","Apple",
    "Barley","Cloudberry","Carrot"
}, Default = "Bloodfruit" })
local harvesttoggle   = Tabs.Farming:CreateToggle("harvesttoggle",  { Title = "Auto Harvest (bushes)", Default = false })
local harvestrange    = Tabs.Farming:CreateSlider("harvestrange",   { Title = "Harvest range (studs)", Min = 8, Max = 150, Rounding = 0, Default = 30 })
local tweenrange      = Tabs.Farming:CreateSlider("tweenrange",     { Title = "Follow range (studs)", Min = 10, Max = 300, Rounding = 0, Default = 120 })
local tweenplantboxtoggle = Tabs.Farming:CreateToggle("tweenplantboxtoggle", { Title = "Move to nearest empty Plant Box (BV)", Default = false })
local tweenbushtoggle     = Tabs.Farming:CreateToggle("tweenbushtoggle",     { Title = "Move to nearest Fruit Bush (BV)", Default = false })

local plantedboxes = {}
local function plant(entityid, itemID)
    if packets and packets.InteractStructure and packets.InteractStructure.send then
        pcall(function() packets.InteractStructure.send({ entityID = entityid, itemID = itemID }) end)
        plantedboxes[entityid] = true
    end
end
local function getpbs(range)
    if not root or not root.Parent then return {} end
    local t = {}
    local dep = workspace:FindFirstChild("Deployables")
    if not dep then return t end
    for _, d in ipairs(dep:GetChildren()) do
        if d:IsA("Model") and d.Name=="Plant Box" then
            local eid=d:GetAttribute("EntityID")
            local pp=d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if eid and pp then
                local dist=(pp.Position-root.Position).Magnitude
                if dist<=range then table.insert(t,{entityid=eid,deployable=d,dist=dist}) end
            end
        end
    end
    return t
end
local function getbushes(range, fruitname)
    if not root or not root.Parent then return {} end
    local bushes={}
    for _,model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:find(fruitname) then
            local pp=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if pp then
                local d=(pp.Position-root.Position).Magnitude
                if d<=range then
                    local eid=model:GetAttribute("EntityID")
                    if eid then table.insert(bushes,{entityid=eid,model=model,dist=d}) end
                end
            end
        end
    end
    return bushes
end
local function safePickup(eid)
    local ok=pcall(function() pickup(eid) end)
    if not ok and packets and packets.Pickup and packets.Pickup.send then pcall(function() packets.Pickup.send(eid) end) end
end

-- BV move helpers
local RS = RunService
local function ensureRoot() local ch=plr.Character return ch and ch:FindFirstChild("HumanoidRootPart") or nil end
local function makeBV(rootPart)
    local old=rootPart:FindFirstChildOfClass("BodyVelocity"); if old then old:Destroy() end
    local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(1e9,0,1e9); bv.Velocity=Vector3.new(); bv.Parent=rootPart; return bv
end
local BV_STOP_TOL, BV_SPEED, BV_MAXSEG = 0.8, 21, 6
local function moveBV_toPos(targetPos)
    local rp=ensureRoot(); if not rp then return false end
    local bv=makeBV(rp); local t0=tick()
    while rp.Parent do
        local cur=rp.Position
        local vec=Vector3.new(targetPos.X-cur.X,0,targetPos.Z-cur.Z)
        local d=vec.Magnitude
        if d<=BV_STOP_TOL then bv.Velocity=Vector3.new(); break end
        if tick()-t0>BV_MAXSEG then break end
        bv.Velocity=(d>0 and vec.Unit or Vector3.new())*BV_SPEED
        RS.Heartbeat:Wait()
    end
    if bv then bv:Destroy() end
    return true
end
local function tweenplantbox(range)
    while tweenplantboxtoggle.Value do
        local plantboxes=getpbs(range)
        table.sort(plantboxes,function(a,b) return a.dist<b.dist end)
        for _,box in ipairs(plantboxes) do
            if not box.deployable:FindFirstChild("Seed") then
                local pp=box.deployable.PrimaryPart or box.deployable:FindFirstChildWhichIsA("BasePart")
                if pp then moveBV_toPos(pp.Position) end
                break
            end
        end
        task.wait(0.05)
    end
end
local function tweenpbs(range, fruitname)
    while tweenbushtoggle.Value do
        local bushes=getbushes(range,fruitname)
        table.sort(bushes,function(a,b) return a.dist<b.dist end)
        if #bushes>0 then
            local bp=bushes[1].model.PrimaryPart or bushes[1].model:FindFirstChildWhichIsA("BasePart")
            if bp then moveBV_toPos(bp.Position) end
        else
            local plantboxes=getpbs(range)
            table.sort(plantboxes,function(a,b) return a.dist<b.dist end)
            for _,box in ipairs(plantboxes) do
                if not box.deployable:FindFirstChild("Seed") then
                    local pp=box.deployable.PrimaryPart or box.deployable:FindFirstChildWhichIsA("BasePart")
                    if pp then moveBV_toPos(pp.Position) end
                    break
                end
            end
        end
        task.wait(0.05)
    end
end

-- авто-посадка (ускорено батчами)
local PLANT_BATCH, PLANT_GAP = 25, 0.02
task.spawn(function()
    while true do
        if planttoggle.Value and root and root.Parent then
            local range=tonumber(plantrange.Value) or 30
            local delay=tonumber(plantdelay.Value) or 0.03
            local itemID=_G.fruittoitemid[fruitdropdownUI.Value] or 94
            local plantboxes=getpbs(range)
            table.sort(plantboxes,function(a,b) return a.dist<b.dist end)
            local planted=0
            for _,box in ipairs(plantboxes) do
                if not box.deployable:FindFirstChild("Seed") then
                    plant(box.entityid,itemID); planted = planted + 1
                    if planted%PLANT_BATCH==0 then task.wait(PLANT_GAP) end
                else plantedboxes[box.entityid]=true end
            end
            task.wait(delay)
        else task.wait(0.1) end
    end
end)

-- авто-сбор (батчи)
local HARVEST_BATCH, HARVEST_GAP = 20, 0.02
task.spawn(function()
    while true do
        if harvesttoggle.Value and root and root.Parent then
            local harvRange=tonumber(harvestrange.Value) or 30
            local selected=fruitdropdownUI.Value
            local bushes=getbushes(harvRange,selected)
            table.sort(bushes,function(a,b) return a.dist<b.dist end)
            local picked=0
            for _,b in ipairs(bushes) do
                safePickup(b.entityid); picked = picked + 1
                if picked%HARVEST_BATCH==0 then task.wait(HARVEST_GAP) end
            end
            task.wait(0.05)
        else task.wait(0.1) end
    end
end)
-- раннеры BV
task.spawn(function() while true do if not tweenplantboxtoggle.Value then task.wait(0.1) else tweenplantbox(tonumber(tweenrange.Value) or 250) end end end)
task.spawn(function() while true do if not tweenbushtoggle.Value   then task.wait(0.1) else tweenpbs(tonumber(tweenrange.Value) or 20, fruitdropdownUI.Value) end end end)

-- ========= [ Farming: Area Auto Build (BV) + визуал зона ] =========
local BuildTab = Tabs.Farming
local AB = { on=false, cornerA=nil, cornerB=nil, spacing=6.04, hoverY=5, speed=21,
    stopTol=0.6, segTimeout=1.2, antiStuckTime=0.8, placeDelay=0.06,
    sideStep=4.2, sideMaxTries=4, wallProbeLen=7.0, wallProbeHeight=2.4 }
local AB_VIS_FOLDER = Workspace:FindFirstChild("_AB_VIS") or Instance.new("Folder", Workspace); AB_VIS_FOLDER.Name="_AB_VIS"
local AB_zonePart, AB_zoneBox
local function AB_clearVisual() if AB_zoneBox then AB_zoneBox:Destroy() AB_zoneBox=nil end if AB_zonePart then AB_zonePart:Destroy() AB_zonePart=nil end end
local function AB_snap(v,s) return math.floor(v/s+0.5)*s end
local function AB_updateVisual()
    AB_clearVisual(); if not (AB.cornerA and AB.cornerB) then return end
    local a,b=AB.cornerA,AB.cornerB; local step=AB.spacing
    local xmin=AB_snap(math.min(a.X,b.X),step); local xmax=AB_snap(math.max(a.X,b.X),step)
    local zmin=AB_snap(math.min(a.Z,b.Z),step); local zmax=AB_snap(math.max(a.Z,b.Z),step)
    local sizeX=math.max(step,math.abs(xmax-xmin)+step); local sizeZ=math.max(step,math.abs(zmax-zmin)+step)
    local y=(root and root.Position.Y or (a.Y+b.Y)/2)+0.15; local cf=CFrame.new((xmin+xmax)/2,y,(zmin+zmax)/2)
    AB_zonePart=Instance.new("Part"); AB_zonePart.Name="_AB_ZONE"; AB_zonePart.Anchored=true; AB_zonePart.CanCollide=false; AB_zonePart.CanTouch=false; AB_zonePart.CanQuery=false
    AB_zonePart.Material=Enum.Material.ForceField; AB_zonePart.Color=Color3.fromRGB(255,220,80); AB_zonePart.Transparency=0.8
    AB_zonePart.Size=Vector3.new(sizeX,0.2,sizeZ); AB_zonePart.CFrame=cf; AB_zonePart.Parent=AB_VIS_FOLDER
    AB_zoneBox=Instance.new("SelectionBox"); AB_zoneBox.LineThickness=0.03; AB_zoneBox.Color3=Color3.fromRGB(255,220,80); AB_zoneBox.SurfaceTransparency=1
    AB_zoneBox.Adornee=AB_zonePart; AB_zoneBox.Parent=AB_VIS_FOLDER
end
plr.CharacterAdded:Connect(function() task.defer(function() ensureChar(); AB_updateVisual() end) end)
local ab_toggle  = BuildTab:CreateToggle("ab_area_on",{ Title="Auto Build (BV) — Area", Default=false })
local ab_spacing = BuildTab:CreateSlider("ab_area_spacing",{ Title="Spacing (studs)", Min=5.6, Max=7.2, Rounding=2, Default=6.04 })
local ab_speed   = BuildTab:CreateSlider("ab_area_speed",{ Title="Speed (BV)", Min=10, Max=60, Rounding=1, Default=21 })
BuildTab:CreateButton({ Title="Set Corner A (here)", Callback=function() if root then AB.cornerA=root.Position; AB_updateVisual() end end })
BuildTab:CreateButton({ Title="Set Corner B (here)", Callback=function() if root then AB.cornerB=root.Position; AB_updateVisual() end end })
BuildTab:CreateButton({ Title="Clear Area (A & B)",  Callback=function() AB.cornerA,AB.cornerB=nil,nil; AB_clearVisual() end })
ab_spacing:OnChanged(function(v) AB.spacing=v; AB_updateVisual() end)
ab_toggle:OnChanged(function(v) AB.on=v; if not v then local bv=root and root:FindFirstChild("_AB_BV"); if bv then bv:Destroy() end end end)
ab_speed:OnChanged(function(v) AB.speed=v end)

local function AB_getBV() if not root then return nil end return root:FindFirstChild("_AB_BV") end
local function AB_ensureBV()
    local bv=AB_getBV()
    if not bv then bv=Instance.new("BodyVelocity"); bv.Name="_AB_BV"; bv.MaxForce=Vector3.new(1e9,0,1e9); bv.Velocity=Vector3.new(); bv.Parent=root end
    return bv
end
local rayParamsAB = RaycastParams.new(); rayParamsAB.FilterType=Enum.RaycastFilterType.Exclude; rayParamsAB.FilterDescendantsInstances={plr.Character}
local function wallAheadAB(dir2d)
    if dir2d.Magnitude<1e-4 then return false end
    local origin=root.Position+Vector3.new(0,AB.wallProbeHeight,0)
    local dir3=Vector3.new(dir2d.X,0,dir2d.Z).Unit*AB.wallProbeLen
    local hit=workspace:Raycast(origin,dir3,rayParamsAB); if not hit then return false end
    return (hit.Normal.Y or 0)<0.55
end
local function moveBV_to(target)
    if not AB.on or not root then return false end
    local bv=AB_ensureBV(); local t0, lastMoveT=tick(), tick(); local lastPos=root.Position; local timeCap=AB.segTimeout+6
    while AB.on do
        local rp=root.Position; local to2=Vector3.new(target.X-rp.X,0,target.Z-rp.Z); local dist=to2.Magnitude
        if dist<=AB.stopTol then bv.Velocity=Vector3.new(); return true end
        local dir=(dist>0) and to2.Unit or Vector3.new()
        if wallAheadAB(dir) then
            local perp=Vector3.new(-dir.Z,0,dir.X).Unit; local ok=false
            for i=1,AB.sideMaxTries do
                local rightHit=workspace:Raycast(rp+Vector3.new(0,AB.wallProbeHeight,0),(dir+perp).Unit*AB.wallProbeLen,rayParamsAB)
                local leftHit =workspace:Raycast(rp+Vector3.new(0,AB.wallProbeHeight,0),(dir-perp).Unit*AB.wallProbeLen,rayParamsAB)
                local sign=(not rightHit and leftHit) and 1 or ((rightHit and not leftHit) and -1 or (i%2==1 and 1 or -1))
                local t1=tick(); while AB.on and tick()-t1<0.22 do bv.Velocity=perp*(AB.sideStep*2.0*sign); RunService.Heartbeat:Wait() end
                bv.Velocity=Vector3.new(); if not wallAheadAB(dir) then ok=true break end
            end
            if not ok then bv.Velocity=Vector3.new(); return false end
        end
        bv.Velocity=dir*AB.speed
        local moved=(rp-lastPos).Magnitude; if moved>0.15 then lastMoveT=tick(); lastPos=rp end
        if (tick()-lastMoveT)>AB.antiStuckTime then
            local perp=Vector3.new(-dir.Z,0,dir.X).Unit
            local t1=tick(); while AB.on and tick()-t1<0.2 do bv.Velocity=perp*(AB.sideStep*2); RunService.Heartbeat:Wait() end
            bv.Velocity=Vector3.new(); t1=tick(); while AB.on and tick()-t1<0.2 do bv.Velocity=-perp*(AB.sideStep*2); RunService.Heartbeat:Wait() end
            bv.Velocity=Vector3.new(); lastMoveT=tick()
        end
        if (tick()-t0)>timeCap then bv.Velocity=Vector3.new(); return false end
        RunService.Heartbeat:Wait()
    end
    return false
end
local function groundYAt(x,z)
    local origin=Vector3.new(x,(root.Position.Y+50),z)
    local hit=workspace:Raycast(origin,Vector3.new(0,-500,0),rayParamsAB)
    if hit then return hit.Position.Y-0.1 end
    return root.Position.Y-3
end
local function spotOccupied(pos,r) r=r or (AB.spacing*0.45)
    local dep=workspace:FindFirstChild("Deployables"); if not dep then return false end
    for _,d in ipairs(dep:GetChildren()) do
        if d:IsA("Model") and d.Name=="Plant Box" then
            local p=d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if p and (p.Position-pos).Magnitude<=r then return true end
        end
    end
    return false
end
local function placePlantBoxAt(pos)
    if packets and packets.PlaceStructure and packets.PlaceStructure.send then
        pcall(function() packets.PlaceStructure.send{ buildingName="Plant Box", yrot=45, vec=pos, isMobile=false } end)
        return true
    end; return false
end
local function buildCellsFromArea()
    if not (AB.cornerA and AB.cornerB) then return {} end
    local a,b=AB.cornerA,AB.cornerB; local xmin,xmax=math.min(a.X,b.X),math.max(a.X,b.X); local zmin,zmax=math.min(a.Z,b.Z),math.max(a.Z,b.Z)
    local step=AB.spacing; local function snap(v,s) return math.floor(v/s+0.5)*s end
    xmin,xmax=snap(xmin,step),snap(xmax,step); zmin,zmax=snap(zmin,step),snap(zmax,step)
    local cells, row={},0
    for z=zmin,zmax,step do
        local xs,xe,dx; if (row%2==0) then xs,xe,dx=xmin,xmax,step else xs,xe,dx=xmax,xmin,-step end
        for x=xs,xe,dx do table.insert(cells, Vector3.new(x, groundYAt(x,z), z)) end
        row = row + 1
    end
    return cells
end
task.spawn(function()
    while true do
        if AB.on and AB.cornerA and AB.cornerB and root then
            local cells=buildCellsFromArea()
            for _,p in ipairs(cells) do
                if not AB.on then break end
                local fly=Vector3.new(p.X, root.Position.Y, p.Z)
                local ok1=moveBV_to(fly); if not ok1 then continue end
                if not spotOccupied(p) then placePlantBoxAt(p); task.wait(AB.placeDelay) end
            end
            local bv=AB_getBV(); if bv then bv:Destroy() end
        else
            local bv=AB_getBV(); if bv then bv:Destroy() end
            task.wait(0.15)
        end
    end
end)

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
local loot_dropdown  = Tabs.Loot:CreateDropdown("loot_items", {
    Title  = "Items (multi)",
    Values = LOOT_ITEM_NAMES,
    Multi  = true,
    Default = { Leaves = true, Log = true }
})
local function safePickup2(eid)
    local ok = pcall(function() pickup(eid) end)
    if not ok and packets and packets.Pickup and packets.Pickup.send then
        pcall(function() packets.Pickup.send(eid) end)
    end
end
local DROP_FOLDERS = { "Items","Drops","WorldDrops","Loot","Dropped","Resources" }
local watchedFolders, conns = {}, {}
local cache = {}
local function normalizedName(inst)
    local a
    if inst.GetAttribute then
        a = inst:GetAttribute("ItemName") or inst:GetAttribute("Name") or inst:GetAttribute("DisplayName")
    end
    if typeof(a) == "string" and a ~= "" then return a end
    return inst.Name
end
local function addDrop(inst)
    if cache[inst] then return end
    local eid = inst.GetAttribute and inst:GetAttribute("EntityID")
    if not eid then return end
    local name = normalizedName(inst)
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
    local dep = workspace:FindFirstChild("Deployables")
    if not dep then return end
    for _,mdl in ipairs(dep:GetChildren()) do
        if mdl:IsA("Model") then
            local contents = mdl:FindFirstChild("Contents")
            if contents and not watchedFolders[contents] then
                hookFolder(contents)
            end
        end
    end
    conns[#conns+1] = dep.ChildAdded:Connect(function(mdl)
        task.defer(function()
            if mdl:IsA("Model") then
                local contents = mdl:FindFirstChild("Contents")
                if contents then hookFolder(contents) end
            end
        end)
    end)
end
for _,n in ipairs(DROP_FOLDERS) do hookFolder(workspace:FindFirstChild(n)) end
hookChests()
task.spawn(function()
    while true do
        for _,n in ipairs(DROP_FOLDERS) do
            local f = workspace:FindFirstChild(n)
            if f and not watchedFolders[f] then hookFolder(f) end
        end
        if loot_chests.Value then hookChests() end
        task.wait(1.0)
    end
end)
local function selectedSet()
    local sel, val = {}, loot_dropdown.Value
    if typeof(val) == "table" then
        for k,v in pairs(val) do if v then sel[string.lower(k)] = true end end
    end
    return sel
end
task.spawn(function()
    while true do
        if loot_on.Value and root then
            local set       = selectedSet()
            local useBlack  = loot_blacklist.Value
            local range     = loot_range.Value
            local maxPer    = math.max(1, math.floor(loot_batch.Value))
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
            if loot_debug.Value then
                print(("[AutoLoot] candidates=%d (mode=%s, chests=%s)")
                    :format(#candidates, useBlack and "Blacklist" or "Whitelist", tostring(loot_chests.Value)))
            end
            for i = 1, math.min(maxPer, #candidates) do
                safePickup2(candidates[i].eid)
                if loot_debug.Value then
                    print(("[AutoLoot] pickup #%d: %s [%.1f]"):format(i, candidates[i].name, candidates[i].dist))
                end
                task.wait(0.01)
            end
            task.wait(loot_cd.Value)
        else
            task.wait(0.15)
        end
    end
end)





-- ========= [ TAB: ESP — God Set ] =========
Tabs.ESP = Window:AddTab({ Title = "ESP (God Set)", Icon = "eye" })

local esp_enable      = Tabs.ESP:CreateToggle("god_esp_enable",    { Title = "Enable ESP", Default = true })
local esp_maxdist     = Tabs.ESP:CreateSlider("god_esp_maxdist",    { Title = "Max distance (studs)", Min=100, Max=3000, Rounding=0, Default=1200 })
local esp_showlabel   = Tabs.ESP:CreateToggle("god_esp_showlabel",  { Title = "Show label over head", Default = true })
local esp_highlight   = Tabs.ESP:CreateToggle("god_esp_highlight",  { Title = "Highlight only if Full Set (3/3)", Default = true })
local esp_only_full   = Tabs.ESP:CreateToggle("god_esp_onlyfull",   { Title = "Show ONLY players with Full Set (3/3)", Default = false })

-- цвета
local COLOR_OK  = Color3.fromRGB(90,255,120)   -- 3/3
local COLOR_LO  = Color3.fromRGB(255,210,80)   -- 1–2/3
local COLOR_NO  = Color3.fromRGB(255,90,90)    -- 0/3

-- имена частей сета
local GOD_MATCH = {
    halo  = { "God Halo", "Halo" },
    chest = { "God Chestplate", "Chestplate", "God Armor", "Armor" },
    legs  = { "God Legs", "Legs", "Greaves" },
}
local function nameMatch(n, list)
    n = string.lower(tostring(n or ""))
    for _,v in ipairs(list) do
        if n:find(string.lower(v), 1, true) then return true end
    end
end

local function countGodPieces(model)
    -- считаем наличие трёх кусков (по именам в потомках модели персонажа)
    local bits = {halo=false, chest=false, legs=false}
    for _,d in ipairs(model:GetDescendants()) do
        local nm = d.Name
        if not bits.halo  and nameMatch(nm, GOD_MATCH.halo)  then bits.halo  = true end
        if not bits.chest and nameMatch(nm, GOD_MATCH.chest) then bits.chest = true end
        if not bits.legs  and nameMatch(nm, GOD_MATCH.legs)  then bits.legs  = true end
    end
    local c = (bits.halo and 1 or 0) + (bits.chest and 1 or 0) + (bits.legs and 1 or 0)
    return c
end

-- иногда модель игрока лежит в workspace.Players/Имя
local function getCharModel(p)
    local wf = workspace:FindFirstChild("Players")
    if wf then
        local m = wf:FindFirstChild(p.Name)
        if m and m:IsA("Model") then return m end
    end
    return p.Character
end

local GOD_ESP = { map = {}, loop = nil, addConn=nil, remConn=nil }

local function makeBoard(adornee)
    local bb = Instance.new("BillboardGui")
    bb.Name = "_ESP_GODSET_BB"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(150, 22)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
    bb.Adornee = adornee
    bb.Parent = adornee

    local tl = Instance.new("TextLabel")
    tl.BackgroundTransparency = 1
    tl.Size = UDim2.fromScale(1,1)
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.TextStrokeTransparency = 0.25
    tl.Text = "God Set 0/3"
    tl.Parent = bb

    return bb, tl
end

local function ensureHL(model)
    local hl = model:FindFirstChild("_ESP_GODSET_HL")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "_ESP_GODSET_HL"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 1
        hl.OutlineTransparency = 0
        hl.Adornee = model
        hl.Parent = model
    end
    return hl
end

local function attachPlayer(p)
    if p == Players.LocalPlayer then return end
    local m = getCharModel(p)
    if not (m and m.Parent) then return end
    local hrp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local bb, tl = makeBoard(hrp)
    local hl = ensureHL(m)

    GOD_ESP.map[p] = { model=m, root=hrp, bb=bb, tl=tl, hl=hl }
end

local function detachPlayer(p)
    local rec = GOD_ESP.map[p]; if not rec then return end
    if rec.bb then pcall(function() rec.bb:Destroy() end) end
    if rec.hl then pcall(function() rec.hl:Destroy() end) end
    GOD_ESP.map[p] = nil
end

local function startGodESP()
    if GOD_ESP.loop then return end
    -- подключаем уже присутствующих
    for _,p in ipairs(Players:GetPlayers()) do if p ~= Players.LocalPlayer then attachPlayer(p) end end
    -- хук на вход/выход
    GOD_ESP.addConn = Players.PlayerAdded:Connect(function(p) task.defer(function() attachPlayer(p) end) end)
    GOD_ESP.remConn = Players.PlayerRemoving:Connect(detachPlayer)

    GOD_ESP.loop = RunService.Heartbeat:Connect(function()
        if not esp_enable.Value then
            -- скрываем всё, но держим объекты — чтобы не спамить созданием/удалением
            for _,rec in pairs(GOD_ESP.map) do
                if rec.bb then rec.bb.Enabled = false end
                if rec.hl then rec.hl.Enabled = false end
            end
            return
        end

        local myRoot = (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) or nil
        for p,rec in pairs(GOD_ESP.map) do
            if not (rec.model and rec.model.Parent and rec.root and rec.root.Parent) then
                -- переподцепляем (после респавна/телепорта)
                detachPlayer(p)
                attachPlayer(p)
                rec = GOD_ESP.map[p]
                if not rec then
                    -- игрок мог уже уйти
                end
            end

            if rec then
                local inDist = true
                if myRoot then
                    local d = (rec.root.Position - myRoot.Position).Magnitude
                    inDist = (d <= esp_maxdist.Value)
                end

                local cnt = countGodPieces(rec.model)
                local col = (cnt >= 3 and COLOR_OK) or (cnt >= 1 and COLOR_LO) or COLOR_NO

                -- фильтр "только фулл"
                local visibleByFilter = (not esp_only_full.Value) or (cnt >= 3)

                if rec.tl then
                    rec.tl.Text = string.format("God Set %d/3", cnt)
                    rec.tl.TextColor3 = col
                end

                if rec.bb then
                    rec.bb.Enabled = esp_showlabel.Value and inDist and visibleByFilter
                end

                if rec.hl then
                    rec.hl.OutlineColor = col
                    rec.hl.Enabled = (cnt >= 3 and esp_highlight.Value and inDist)
                end
            end
        end
    end)
end

local function stopGodESP()
    if GOD_ESP.loop then GOD_ESP.loop:Disconnect() GOD_ESP.loop = nil end
    if GOD_ESP.addConn then GOD_ESP.addConn:Disconnect() GOD_ESP.addConn=nil end
    if GOD_ESP.remConn then GOD_ESP.remConn:Disconnect() GOD_ESP.remConn=nil end
    for p,_ in pairs(GOD_ESP.map) do
        detachPlayer(p)
    end
end

-- управление из UI
esp_enable:OnChanged(function(v)
    if v then startGodESP() else stopGodESP() end
end)

-- автозапуск, если включено по умолчанию
if esp_enable.Value then startGodESP() end


-- ========= [ Finish / Autoload ] =========
Window:SelectTab(1)
Library:Notify{ Title="Fuger Hub", Content="Loaded: Configs + Survival + Gold + Route + Farming + Heal + Loot + Player + Visuals + Movement", Duration=6 }
pcall(function() SaveManager:LoadAutoloadConfig() end)
pcall(function()
    local ok = Route_LoadFromFile(ROUTE_AUTOSAVE, _G.__ROUTE, _G.__ROUTE._redraw)
    if ok then Library:Notify{ Title="Route", Content="Route autosave loaded", Duration=3 } end
end)  можешь улутшить посадку ягод? и чтоб без лагов былои что бне флагало
