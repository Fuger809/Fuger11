-- ========= [ Fluent UI и менеджеры ] =========
local Library = loadstring(game:HttpGetAsync("https://github.com/1dontgiveaf/Fluent-Renewed/releases/download/v1.0/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/1dontgiveaf/Fluent-Renewed/refs/heads/main/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/1dontgiveaf/Fluent-Renewed/refs/heads/main/Addons/InterfaceManager.luau"))()

-- ========= [ Services / utils ] =========
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService    = game:GetService("PhysicsService")
local CoreGui           = game:GetService("CoreGui")
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

-- packets (без ошибок, если модуля нет)
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
    Size = UDim2.fromOffset(830, 525),
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

-- ========= [ ROUTE persist functions ] =========
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
        if redraw and type(redraw.dot) == "function" then
            redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
        end
    end
    return true
end

-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })
local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input",{ Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)

-- ========= [ TAB: Visuals (Gold ESP + Ghost Noclip) ] =========
Tabs.Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })

local espToggle   = Tabs.Visuals:CreateToggle("gold_esp_on",{ Title="Gold Node ESP", Default=true })
local espRange    = Tabs.Visuals:CreateSlider("gold_esp_range",{ Title="ESP Range (studs)", Min=10, Max=700, Default=120 })
local espShowDist = Tabs.Visuals:CreateToggle("gold_esp_showdist",{ Title="Show distance", Default=true })
local espBox      = Tabs.Visuals:CreateToggle("gold_esp_box",{ Title="Box highlight", Default=true })
local espLabel    = Tabs.Visuals:CreateToggle("gold_esp_label",{ Title="Billboard label", Default=true })
local noclipToggle= Tabs.Visuals:CreateToggle("noclip_on",{ Title="Noclip (through all)", Default=false })

local GOLD_COLOR = Color3.fromRGB(255,220,80)
local ESP = {}

local function getPP(m) return m and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")) end
local function safeParent(gui)
    local ok = pcall(function() gui.Parent = CoreGui end)
    if not ok then gui.Parent = plr:WaitForChild("PlayerGui") end
end
local function destroyEsp(m)
    local r=ESP[m]; if r then for _,o in pairs(r) do pcall(function() o:Destroy() end) end ESP[m]=nil end
end
local function ensureEsp(m)
    local r=ESP[m]
    if not r then
        r={}
        local hl=Instance.new("Highlight")
        hl.Name="_GOLD_HL"; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency=1; hl.OutlineColor=GOLD_COLOR; hl.OutlineTransparency=0
        hl.Adornee=m; hl.Parent=m
        local bb=Instance.new("BillboardGui")
        bb.Name="_GOLD_BB"; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(120,24); bb.StudsOffset=Vector3.new(0,3.2,0)
        bb.Adornee=getPP(m); safeParent(bb)
        local tl=Instance.new("TextLabel")
        tl.Size=UDim2.fromScale(1,1); tl.BackgroundTransparency=1; tl.Font=Enum.Font.SourceSansBold
        tl.TextSize=16; tl.TextColor3=GOLD_COLOR; tl.TextStrokeTransparency=0.5; tl.Text="GOLD"; tl.Parent=bb
        r.hl,r.bb,r.tl=hl,bb,tl; ESP[m]=r
    end
    return r
end
local function setVisible(r,useBox,useLbl)
    if r.hl then r.hl.Enabled=useBox end
    if r.bb then r.bb.Enabled=useLbl end
end
local function scanGold(out)
    local function scan(folder)
        if not folder then return end
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m.Name=="Gold Node" then table.insert(out,m) end
        end
    end
    scan(workspace:FindFirstChild("Resources"))
    scan(workspace)
end

task.spawn(function()
    while true do
        if root and espToggle.Value then
            local rng=espRange.Value; local showDst=espShowDist.Value
            local useBox=espBox.Value; local useLbl=espLabel.Value
            local all,seen={},{}

            scanGold(all)
            for _,m in ipairs(all) do
                local pp=getPP(m)
                if pp and m:IsDescendantOf(workspace) then
                    local d=(pp.Position-root.Position).Magnitude
                    if d<=rng then
                        local rec=ensureEsp(m)
                        setVisible(rec,useBox,useLbl)
                        if rec.tl then rec.tl.Text = showDst and ("GOLD ["..math.floor(d).."]") or "GOLD" end
                        seen[m]=true
                    end
                end
            end
            for m,_ in pairs(ESP) do if not seen[m] or not m:IsDescendantOf(workspace) then destroyEsp(m) end end
            task.wait(0.15)
        else
            if next(ESP) ~= nil then for m,_ in pairs(ESP) do destroyEsp(m) end end
            task.wait(0.3)
        end
    end
end)

-- Ghost Noclip
local GHOST_GROUP="Ghost_All"
local descConn, holdConn
local function ensureGroup()
    local ok,groups=pcall(function()return PhysicsService:GetCollisionGroups()end)
    if ok then
        local has=false
        for _,g in ipairs(groups) do if g.name==GHOST_GROUP then has=true end end
        if not has then pcall(function() PhysicsService:CreateCollisionGroup(GHOST_GROUP) end) end
        ok,groups=pcall(function()return PhysicsService:GetCollisionGroups()end)
        if ok then for _,g in ipairs(groups) do pcall(function() PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,g.name,false) end) end end
    end
end
local function setGhost(p)
    if not p:IsA("BasePart") then return end
    p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    pcall(function() PhysicsService:SetPartCollisionGroup(p,GHOST_GROUP) end)
end
local function clearGhost(p)
    if not p:IsA("BasePart") then return end
    pcall(function() PhysicsService:SetPartCollisionGroup(p,"Default") end)
    p.CanCollide=true; p.CanTouch=true; p.CanQuery=true
end
local function applyGhost(c) for _,d in ipairs(c:GetDescendants()) do setGhost(d) end end
local function clearAll(c) for _,d in ipairs(c:GetDescendants()) do clearGhost(d) end end

local function enableGhost()
    ensureGroup()
    if char then applyGhost(char) end
    if descConn then descConn:Disconnect() end
    descConn = char.DescendantAdded:Connect(function(d) if noclipToggle.Value then setGhost(d) end end)
    if holdConn then holdConn:Disconnect() end
    holdConn = RunService.Stepped:Connect(function()
        if noclipToggle.Value and char and char.Parent then applyGhost(char) end
    end)
end
local function disableGhost()
    if descConn then descConn:Disconnect(); descConn=nil end
    if holdConn then holdConn:Disconnect(); holdConn=nil end
    if char then clearAll(char) end
end
noclipToggle:OnChanged(function(v) if v then enableGhost() else disableGhost() end end)
plr.CharacterAdded:Connect(function(c) task.defer(function() ensureChar(); if noclipToggle.Value then enableGhost() end end) end)

-- ========= [ TAB: Survival (Auto-Eat) ] =========
Tabs.Survival = Window:AddTab({ Title = "Survival", Icon = "apple" })

local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title = "Auto Eat (Hunger)", Default = false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title = "Food to eat",
    Values = {"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default = "Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title = "Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title = "Debug logs (F9)", Default = false })

local function normPct(n)
    if type(n) ~= "number" then return nil end
    if n <= 1.5 then n = n * 100 end
    return math.clamp(n, 0, 100)
end
local function readHungerFromValues()
    for _,v in ipairs(plr:GetDescendants()) do
        if v.Name == "Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            return normPct(v.Value)
        end
    end
end
local function readHungerFromBar()
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg = pg:FindFirstChild("MainGui");    if not mg then return end
    local bars = mg:FindFirstChild("Bars");     if not bars then return end
    local hb = bars:FindFirstChild("Hunger")
    if hb and hb:IsA("Frame") and hb.Size and hb.Size.X and typeof(hb.Size.X.Scale)=="number" then
        return normPct(hb.Size.X.Scale)
    end
end
local function readHungerFromText()
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _,inst in ipairs(pg:GetDescendants()) do
        if inst:IsA("TextLabel") then
            local txt = tostring(inst.Text or ""):lower()
            if txt:find("голод") or inst.Name:lower():find("hunger") or (inst.Parent and inst.Parent.Name:lower():find("hunger")) then
                local num = tonumber(txt:match("([-+]?%d+%.?%d*)"))
                if num and num >= 0 and num <= 100 then return num end
            end
        end
    end
end
local function readHungerFromAttr()
    local a = plr:GetAttribute("Hunger")
    if typeof(a) == "number" then return normPct(a) end
end
local function readHungerPercent()
    return readHungerFromValues()
        or readHungerFromBar()
        or readHungerFromText()
        or readHungerFromAttr()
        or 100
end

-- общая карта itemID (исп. и тут, и в Farming)
local fruittoitemid = rawget(_G,"fruittoitemid") or {
    Bloodfruit = 94, Bluefruit = 377, Lemon = 99, Coconut = 1, Jelly = 604,
    Banana = 606, Orange = 602, Oddberry = 32, Berry = 35, Strangefruit = 302,
    Strawberry = 282, Sunfruit = 128, Pumpkin = 80, ["Prickly Pear"] = 378,
    Apple = 243, Barley = 247, Cloudberry = 101, Carrot = 147
}
_G.fruittoitemid = fruittoitemid

local function findInventoryList()
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg = pg:FindFirstChild("MainGui"); if not mg then return end
    local rp = mg:FindFirstChild("RightPanel"); if not rp then return end
    local inv = rp:FindFirstChild("Inventory"); if not inv then return end
    return inv:FindFirstChild("List")
end
local function getSlotByName(itemName)
    local list = findInventoryList(); if not list then return nil end
    for _,child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemName then
            return child.LayoutOrder
        end
    end
end
local function consumeBySlot(slot)
    if not slot then return false end
    if packets.UseBagItem      and packets.UseBagItem.send      then pcall(function() packets.UseBagItem.send(slot) end)      return true end
    if packets.ConsumeBagItem  and packets.ConsumeBagItem.send  then pcall(function() packets.ConsumeBagItem.send(slot) end)  return true end
    if packets.ConsumeItem     and packets.ConsumeItem.send     then pcall(function() packets.ConsumeItem.send(slot) end)     return true end
    if packets.UseItem         and packets.UseItem.send         then pcall(function() packets.UseItem.send(slot) end)         return true end
    return false
end
local function getItemIdByName(name)
    return fruittoitemid[name]
end
local function consumeById(id)
    if not id then return false end
    if packets.ConsumeItem and packets.ConsumeItem.send then pcall(function() packets.ConsumeItem.send(id) end) return true end
    if packets.UseItem     and packets.UseItem.send     then pcall(function() packets.UseItem.send({itemID=id}) end) return true end
    if packets.Eat         and packets.Eat.send         then pcall(function() packets.Eat.send(id) end) return true end
    if packets.EatFood     and packets.EatFood.send     then pcall(function() packets.EatFood.send(id) end) return true end
    return false
end

local eatingLock=false
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ae_toggle.Value then continue end

        local target = ae_thresh.Value
        local mode   = ae_mode.Value
        local cur    = readHungerPercent()

        local need = (mode == "Fullness 100→0") and (cur < target)
                  or (mode == "Hunger 0→100")   and (cur > target)

        if need and not eatingLock then
            eatingLock = true
            task.spawn(function()
                local tries, maxTries = 0, 25
                local minDelay, band = 0.15, 0.5
                while ae_toggle.Value and tries < maxTries do
                    cur = readHungerPercent()
                    local okNow = (mode == "Fullness 100→0") and (cur >= target - band)
                               or (mode == "Hunger 0→100")   and (cur <= target + band)
                    if okNow then
                        if ae_debug.Value then print(("[AutoEat] reached: %.1f / %d (%s)"):format(cur, target, mode)) end
                        break
                    end
                    local food = ae_food.Value or "Bloodfruit"
                    local ate  = consumeBySlot(getSlotByName(food)) or consumeById(getItemIdByName(food))
                    if ae_debug.Value then print(("[AutoEat] try=%d -> %s"):format(tries+1, ate and "EAT" or "MISS")) end
                    tries += 1
                    task.wait(minDelay)
                end
                eatingLock=false
            end)
        end
    end
end)

-- ========= [ TAB: Gold (Radius) ] =========
do
    local GoldTab = Window:AddTab({ Title = "Gold (Radius)", Icon = "hammer" })
    local gold_auto = GoldTab:CreateToggle("gold_r_auto",  { Title = "Auto Break Gold (Radius)", Default = false })
    local gold_range= GoldTab:CreateSlider("gold_r_range", { Title = "Range (studs)", Min = 5, Max = 100, Rounding = 0, Default = 35 })
    local gold_max  = GoldTab:CreateSlider("gold_r_max",   { Title = "Max targets per swing", Min = 1, Max = 10, Rounding = 0, Default = 6 })
    local gold_cd   = GoldTab:CreateSlider("gold_r_cd",    { Title = "Swing cooldown (s)", Min = 0.05, Max = 1.0, Rounding = 2, Default = 0.15 })

    local function collectGoldAround(rp, radius)
        local list = {}
        local function scan(folder)
            if not folder then return end
            for _,inst in ipairs(folder:GetChildren()) do
                if inst:IsA("Model") and inst.Name == "Gold Node" then
                    local eid = inst:GetAttribute("EntityID")
                    local pp  = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
                    if eid and pp then
                        local d = (pp.Position - rp.Position).Magnitude
                        if d <= radius then table.insert(list, {eid=eid, dist=d}) end
                    end
                end
            end
        end
        scan(workspace:FindFirstChild("Resources"))
        scan(workspace)
        table.sort(list, function(a,b) return a.dist < b.dist end)
        return list
    end

    task.spawn(function()
        while true do
            if gold_auto.Value and root then
                local radius     = gold_range.Value
                local maxTargets = math.floor(gold_max.Value)
                local cooldown   = gold_cd.Value
                local near = collectGoldAround(root, radius)
                if #near > 0 then
                    local ids = {}
                    for i=1, math.min(maxTargets, #near) do ids[#ids+1] = near[i].eid end
                    swingtool(ids)
                end
                task.wait(cooldown)
            else
                task.wait(0.12)
            end
        end
    end)
end

-- ========= [ TAB: Route (record / play / save) ] =========
Tabs.Route = Window:AddTab({ Title = "Route", Icon = "route" })
local R_gap  = Tabs.Route:CreateSlider("r_gap", { Title = "Point gap (studs)", Min=0.5, Max=8, Rounding=2, Default=2 })
local R_spd  = Tabs.Route:CreateSlider("r_spd", { Title = "Follow speed", Min=6, Max=40, Rounding=1, Default=20 })
local R_loop = Tabs.Route:CreateToggle("r_loop", { Title = "Loop back & forth", Default = true })

local Route = { points={}, recording=false, running=false, _hbConn=nil, _jumpConn=nil,
    _lastPos=nil, _idleT0=nil, _lastJumpT=0, _lastLandT=0, _waitingLand=false }

local routeFolder = Workspace:FindFirstChild("_ROUTE_DOTS") or Instance.new("Folder", Workspace)
routeFolder.Name = "_ROUTE_DOTS"
local COL_Y=Color3.fromRGB(255,230,80)
local COL_R=Color3.fromRGB(230,75,75)
local COL_B=Color3.fromRGB(90,155,255)

local function dot(color,pos,size)
    local p=Instance.new("Part")
    p.Name="_route_dot"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
    p.Shape=Enum.PartType.Ball; p.Material=Enum.Material.Neon; p.Color=color
    p.Size=Vector3.new(size or 0.7,size or 0.7,size or 0.7)
    p.CFrame=CFrame.new(pos + Vector3.new(0,0.15,0)); p.Parent=routeFolder
end
local function clearDots()
    local ch=routeFolder:GetChildren()
    for i=1,#ch do local c=ch[i]; if c:IsA("BasePart") and c.Name=="_route_dot" then c:Destroy() end
        if (i%250)==0 then RunService.Heartbeat:Wait() end end
end
local function ui(msg) pcall(function() Library:Notify{ Title="Route", Content=tostring(msg), Duration=2 } end) end
local function pushPoint(pos,flags) local r={pos=pos}; if flags then for k,v in pairs(flags) do r[k]=v end end; table.insert(Route.points,r) end

local ROUTE_BV_NAME="_ROUTE_BV"
local function getRouteBV() return root and root:FindFirstChild(ROUTE_BV_NAME) or nil end
local function ensureRouteBV()
    if not root or not root.Parent then return end
    local bv=getRouteBV()
    if not bv then bv=Instance.new("BodyVelocity"); bv.Name=ROUTE_BV_NAME; bv.MaxForce=Vector3.new(1e9,0,1e9); bv.Velocity=Vector3.new(); bv.Parent=root end
    return bv
end
local function stopRouteBV() local bv=getRouteBV(); if bv then bv.Velocity=Vector3.new() end end
local function killRouteBV() local bv=getRouteBV(); if bv then bv:Destroy() end end

function _ROUTE_startRecord()
    if Route.recording or Route.running then return end
    if not root or not hum then return end
    Route.recording=true; table.clear(Route.points)
    Route._idleT0=nil; Route._lastJumpT=0; Route._lastLandT=0
    Route._waitingLand=false; Route._lastPos=root.Position
    clearDots(); dot(COL_Y, Route._lastPos, 0.9); pushPoint(Route._lastPos)

    if Route._jumpConn then Route._jumpConn:Disconnect() end
    Route._jumpConn = hum.StateChanged:Connect(function(_,new)
        local now=tick(); if not Route.recording then return end
        if new==Enum.HumanoidStateType.Jumping then
            if now-Route._lastJumpT>0.15 then
                Route._lastJumpT=now; Route._waitingLand=true
                local pos=root.Position; pushPoint(pos,{jump_start=true}); dot(COL_B,pos,0.75)
            end
        elseif new==Enum.HumanoidStateType.Landed then
            if Route._waitingLand and (now-Route._lastLandT>0.10) then
                Route._waitingLand=false; Route._lastLandT=now
                local pos=root.Position; pushPoint(pos,{jump_end=true}); dot(COL_B,pos,0.75)
            end
        end
    end)

    if Route._hbConn then Route._hbConn:Disconnect() end
    Route._hbConn = RunService.Heartbeat:Connect(function()
        if not Route.recording then return end
        local cur=root.Position
        local vel=root.AssemblyLinearVelocity
        local planar=(vel and Vector3.new(vel.X,0,vel.Z).Magnitude) or 0
        local move=hum.MoveDirection.Magnitude
        local onGround=hum.FloorMaterial ~= Enum.Material.Air
        local idle=onGround and (planar<=0.25) and (move<0.10)

        if idle then
            if not Route._idleT0 then
                Route._idleT0=tick(); dot(COL_R,cur,0.85); pushPoint(cur,{wait=0,_pendingWait=true})
            end
        else
            if Route._idleT0 then
                local dt=tick()-Route._idleT0; Route._idleT0=nil
                if dt>=0.35 then
                    for i=#Route.points,1,-1 do local p=Route.points[i]
                        if p._pendingWait then p._pendingWait=nil; p.wait=dt; break end end
                else
                    if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then
                        table.remove(Route.points,#Route.points) end
                end
            end
        end

        local gap=(R_gap and R_gap.Value) or 2
        if (cur-Route._lastPos).Magnitude>=gap then
            pushPoint(cur); dot(COL_Y,cur,0.7); Route._lastPos=cur
        end
    end)
    ui("recording…")
end

function _ROUTE_stopRecord()
    if not Route.recording then return end
    Route.recording=false
    if Route._idleT0 then
        local dt=tick()-Route._idleT0; Route._idleT0=nil
        if dt>=0.35 then for i=#Route.points,1,-1 do local p=Route.points[i]
            if p._pendingWait then p._pendingWait=nil; p.wait=dt; break end end
        else if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then table.remove(Route.points,#Route.points) end end
    end
    if Route._hbConn then Route._hbConn:Disconnect(); Route._hbConn=nil end
    if Route._jumpConn then Route._jumpConn:Disconnect(); Route._jumpConn=nil end
    Route_SaveToFile(ROUTE_AUTOSAVE, Route.points)
    ui(("rec done (%d pts)"):format(#Route.points))
end

local function followSeg(p1,p2)
    local bv=ensureRouteBV(); if not bv then return false end
    local speed=(R_spd and R_spd.Value) or 20
    local stopTol=1.05
    local t0=tick()
    while Route.running do
        local cur=root.Position
        local vec=Vector3.new(p2.X-cur.X,0,p2.Z-cur.Z)
        local d=vec.Magnitude
        if d<=stopTol then stopRouteBV(); return true end
        bv.Velocity=(d>0 and vec.Unit or Vector3.new())*speed
        if tick()-t0>6 then return false end
        RunService.Heartbeat:Wait()
    end
    stopRouteBV(); return false
end

local function followForward()
    for i=1,#Route.points-1 do
        if not Route.running then return false end
        local pt=Route.points[i]
        if pt.jump_start then hum.Jump=true; pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end); task.wait(0.03) end
        if pt.wait and pt.wait>0 then stopRouteBV(); task.wait(pt.wait) end
        local nxt=Route.points[i+1]
        if not followSeg(pt.pos, nxt.pos) then return false end
    end
    local last=Route.points[#Route.points]
    if last and last.wait and last.wait>0 then stopRouteBV(); task.wait(last.wait) end
    return true
end

function _ROUTE_startFollow()
    if Route.running or Route.recording then return end
    if #Route.points<2 then ui("no route"); return end
    Route.running=true; ensureRouteBV().Velocity=Vector3.new()
    task.spawn(function()
        while Route.running do
            ui(R_loop.Value and "following (loop from start)" or "following")
            if not followForward() then break end
            if not Route.running or not R_loop.Value then break end
            followSeg(Route.points[#Route.points].pos, Route.points[1].pos)
        end
        stopRouteBV(); killRouteBV(); Route.running=false
    end)
end

function _ROUTE_stopFollow()
    if not Route.running then return end
    Route.running=false; stopRouteBV(); killRouteBV()
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    ui("stopped")
end

function _ROUTE_clear()
    table.clear(Route.points); clearDots(); stopRouteBV(); killRouteBV(); ui("cleared")
end

Tabs.Route:CreateButton({ Title="Start record", Callback=_ROUTE_startRecord })
Tabs.Route:CreateButton({ Title="Stop record",  Callback=_ROUTE_stopRecord  })
Tabs.Route:CreateButton({ Title="Start follow", Callback=_ROUTE_startFollow })
Tabs.Route:CreateButton({ Title="Stop follow",  Callback=_ROUTE_stopFollow  })
Tabs.Route:CreateButton({ Title="Clear route",  Callback=_ROUTE_clear       })

Tabs.Route:CreateButton({
    Title = "Save route (current cfg)",
    Callback = function()
        local n = sanitize(cfgName)
        Route_SaveToFile(routePath(n), Route.points)
        Library:Notify{ Title="Route", Content="Route saved to "..n, Duration=3 }
    end
})
Tabs.Route:CreateButton({
    Title = "Load route (current cfg)",
    Callback = function()
        local n = sanitize(cfgName)
        local ok = Route_LoadFromFile(routePath(n), Route, { clearDots = clearDots, dot = dot })
        Library:Notify{ Title="Route", Content= ok and ("Route loaded from "..n) or "No route file", Duration=3 }
    end
})

-- ========= [ TAB: Farming (посадка/сбор + BV + Area Auto Build) ] =========
Tabs.Farming = Window:AddTab({ Title = "Farming", Icon = "shovel" })

-- UI: посадка/сбор
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

-- UI: движение к целям (BV)
local tweenrange      = Tabs.Farming:CreateSlider("tweenrange",     { Title = "Follow range (studs)", Min = 10, Max = 300, Rounding = 0, Default = 120 })
local tweenplantboxtoggle = Tabs.Farming:CreateToggle("tweenplantboxtoggle", { Title = "Move to nearest empty Plant Box (BV)", Default = false })
local tweenbushtoggle     = Tabs.Farming:CreateToggle("tweenbushtoggle",     { Title = "Move to nearest Fruit Bush (BV)", Default = false })

-- посадка/сбор helpers
local plantedboxes = {}

local function plant(entityid, itemID)
    if packets and packets.InteractStructure and packets.InteractStructure.send then
        pcall(function()
            packets.InteractStructure.send({ entityID = entityid, itemID = itemID })
        end)
        plantedboxes[entityid] = true
    end
end

local function getpbs(range)
    if not root or not root.Parent then return {} end
    local plantboxes = {}
    local dep = workspace:FindFirstChild("Deployables")
    if not dep then return plantboxes end
    for _, deployable in ipairs(dep:GetChildren()) do
        if deployable:IsA("Model") and deployable.Name == "Plant Box" then
            local eid = deployable:GetAttribute("EntityID")
            local pp  = deployable.PrimaryPart or deployable:FindFirstChildWhichIsA("BasePart")
            if eid and pp then
                local d = (pp.Position - root.Position).Magnitude
                if d <= range then
                    table.insert(plantboxes, { entityid = eid, deployable = deployable, dist = d })
                end
            end
        end
    end
    return plantboxes
end

local function getbushes(range, fruitname)
    if not root or not root.Parent then return {} end
    local bushes = {}
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:find(fruitname) then
            local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if pp then
                local d = (pp.Position - root.Position).Magnitude
                if d <= range then
                    local eid = model:GetAttribute("EntityID")
                    if eid then
                        table.insert(bushes, { entityid = eid, model = model, dist = d })
                    end
                end
            end
        end
    end
    return bushes
end

local function safePickup(eid)
    local ok = pcall(function() pickup(eid) end)
    if not ok and packets and packets.Pickup and packets.Pickup.send then
        pcall(function() packets.Pickup.send(eid) end)
    end
end

-- === ДВИЖЕНИЕ ЧЕРЕЗ BV (вместо Tween) ===
local RS = game:GetService("RunService")
local BV_SPEED    = 21
local BV_STOP_TOL = 0.8
local BV_MAXSEG   = 6

local function ensureRoot()
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end

local function makeBV(rootPart)
    local old = rootPart:FindFirstChildOfClass("BodyVelocity")
    if old then old:Destroy() end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 0, 1e9) -- XZ
    bv.Velocity = Vector3.new()
    bv.Parent = rootPart
    return bv
end

local function moveBV_toPos(targetPos)
    local rp = ensureRoot()
    if not rp then return false end
    local bv = makeBV(rp)
    local t0 = tick()
    while rp.Parent do
        local cur = rp.Position
        local vec = Vector3.new(targetPos.X - cur.X, 0, targetPos.Z - cur.Z)
        local d   = vec.Magnitude
        if d <= BV_STOP_TOL then
            bv.Velocity = Vector3.new()
            break
        end
        if tick() - t0 > BV_MAXSEG then
            break
        end
        bv.Velocity = (d > 0 and vec.Unit or Vector3.new()) * BV_SPEED
        RS.Heartbeat:Wait()
    end
    if bv then bv:Destroy() end
    return true
end

local function tween(targetCFrame)
    moveBV_toPos(targetCFrame.Position)
end

local function tweenplantbox(range)
    while tweenplantboxtoggle.Value do
        local plantboxes = getpbs(range)
        table.sort(plantboxes, function(a, b) return a.dist < b.dist end)
        for _, box in ipairs(plantboxes) do
            if not box.deployable:FindFirstChild("Seed") then
                local pp = box.deployable.PrimaryPart or box.deployable:FindFirstChildWhichIsA("BasePart")
                if pp then moveBV_toPos(pp.Position) end
                break
            end
        end
        task.wait(0.05)
    end
end

local function tweenpbs(range, fruitname)
    while tweenbushtoggle.Value do
        local bushes = getbushes(range, fruitname)
        table.sort(bushes, function(a, b) return a.dist < b.dist end)
        if #bushes > 0 then
            local bp = bushes[1].model.PrimaryPart or bushes[1].model:FindFirstChildWhichIsA("BasePart")
            if bp then moveBV_toPos(bp.Position) end
        else
            local plantboxes = getpbs(range)
            table.sort(plantboxes, function(a, b) return a.dist < b.dist end)
            for _, box in ipairs(plantboxes) do
                if not box.deployable:FindFirstChild("Seed") then
                    local pp = box.deployable.PrimaryPart or box.deployable:FindFirstChildWhichIsA("BasePart")
                    if pp then moveBV_toPos(pp.Position) end
                    break
                end
            end
        end
        task.wait(0.05)
    end
end

-- ⚡ посадка
local PLANT_BATCH, PLANT_GAP = 25, 0.02
task.spawn(function()
    while true do
        if planttoggle.Value then
            if not root or not root.Parent then task.wait(0.1) else
                local range   = tonumber(plantrange.Value) or 30
                local delay   = tonumber(plantdelay.Value) or 0.03
                local itemID  = fruittoitemid[fruitdropdownUI.Value] or 94

                local plantboxes = getpbs(range)
                table.sort(plantboxes, function(a, b) return a.dist < b.dist end)

                local planted = 0
                for _, box in ipairs(plantboxes) do
                    if not box.deployable:FindFirstChild("Seed") then
                        plant(box.entityid, itemID)
                        planted += 1
                        if planted % PLANT_BATCH == 0 then task.wait(PLANT_GAP) end
                    else
                        plantedboxes[box.entityid] = true
                    end
                end
                task.wait(delay)
            end
        else
            task.wait(0.1)
        end
    end
end)

-- ✅ авто-сбор
local HARVEST_BATCH, HARVEST_GAP = 20, 0.02
task.spawn(function()
    while true do
        if harvesttoggle.Value then
            if not root or not root.Parent then task.wait(0.1) else
                local harvRange  = tonumber(harvestrange.Value) or 30
                local selected   = fruitdropdownUI.Value
                local bushes     = getbushes(harvRange, selected)
                table.sort(bushes, function(a, b) return a.dist < b.dist end)

                local picked = 0
                for _, bush in ipairs(bushes) do
                    safePickup(bush.entityid)
                    picked += 1
                    if picked % HARVEST_BATCH == 0 then task.wait(HARVEST_GAP) end
                end
                task.wait(0.05)
            end
        else
            task.wait(0.1)
        end
    end
end)

-- Раннеры BV «твитов»
task.spawn(function()
    while true do
        if not tweenplantboxtoggle.Value then
            task.wait(0.1)
        else
            local range = tonumber(tweenrange.Value) or 250
            tweenplantbox(range)
        end
    end
end)
task.spawn(function()
    while true do
        if not tweenbushtoggle.Value then
            task.wait(0.1)
        else
            local range = tonumber(tweenrange.Value) or 20
            local selectedfruit = fruitdropdownUI.Value
            tweenpbs(range, selectedfruit)
        end
    end
end)

-- ========= [ Farming: Area Auto Build (BV) ] =========
local BuildTab = Tabs.Farming

local AB = {
    on = false,
    cornerA = nil,
    cornerB = nil,
    spacing = 6.04,
    hoverY  = 5,
    speed   = 21,
    stopTol = 0.6,
    segTimeout = 1.2,
    antiStuckTime = 0.8,
    placeDelay = 0.06,
    sideStep = 4.2,
    sideMaxTries = 4,
    wallProbeLen = 7.0,
    wallProbeHeight = 2.4,
}

local ab_toggle  = BuildTab:CreateToggle("ab_area_on",       { Title="Auto Build (BV) — Area", Default=false })
local ab_spacing = BuildTab:CreateSlider("ab_area_spacing",  { Title="Spacing (studs)", Min=5.6, Max=7.2, Rounding=2, Default=6.04 })
local ab_speed   = BuildTab:CreateSlider("ab_area_speed",    { Title="Speed (BV)", Min=10, Max=60, Rounding=1, Default=21 })
BuildTab:CreateButton({ Title="Set Corner A (here)", Callback=function() if root then AB.cornerA = root.Position; print("[AB] A =", AB.cornerA) end end })
BuildTab:CreateButton({ Title="Set Corner B (here)", Callback=function() if root then AB.cornerB = root.Position; print("[AB] B =", AB.cornerB) end end })
BuildTab:CreateButton({ Title="Clear Area (A & B)",  Callback=function() AB.cornerA, AB.cornerB = nil, nil end })

ab_toggle:OnChanged(function(v) AB.on = v; if not v then AB_killBV() end end)
ab_spacing:OnChanged(function(v) AB.spacing = v end)
ab_speed:OnChanged(function(v) AB.speed = v end)

local function AB_getBV()
    if not root then return nil end
    return root:FindFirstChild("_AB_BV")
end
local function AB_ensureBV()
    local bv = AB_getBV()
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "_AB_BV"
        bv.MaxForce = Vector3.new(1e9, 0, 1e9)
        bv.Velocity = Vector3.new()
        bv.Parent = root
    end
    return bv
end
function AB_killBV()
    local bv = AB_getBV()
    if bv then bv:Destroy() end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {plr.Character}

local function wallAhead(dir2d)
    if dir2d.Magnitude < 1e-4 then return false end
    local origin = root.Position + Vector3.new(0, AB.wallProbeHeight, 0)
    local dir3   = Vector3.new(dir2d.X, 0, dir2d.Z).Unit * AB.wallProbeLen
    local hit = workspace:Raycast(origin, dir3, rayParams)
    if not hit then return false end
    return (hit.Normal.Y or 0) < 0.55
end

local function moveBV_to(target)
    if not AB.on or not root then return false end
    local bv = AB_ensureBV()
    local t0, lastMoveT = tick(), tick()
    local lastPos = root.Position
    local timeCap = AB.segTimeout + 6

    while AB.on do
        local rp = root.Position
        local to2 = Vector3.new(target.X - rp.X, 0, target.Z - rp.Z)
        local dist = to2.Magnitude
        if dist <= AB.stopTol then
            bv.Velocity = Vector3.new()
            return true
        end
        local dir = (dist > 0) and to2.Unit or Vector3.new()

        if wallAhead(dir) then
            local perp = Vector3.new(-dir.Z, 0, dir.X).Unit
            local ok = false
            for i=1, AB.sideMaxTries do
                local rightHit = workspace:Raycast(rp + Vector3.new(0,AB.wallProbeHeight,0), (dir + perp).Unit*AB.wallProbeLen, rayParams)
                local leftHit  = workspace:Raycast(rp + Vector3.new(0,AB.wallProbeHeight,0), (dir - perp).Unit*AB.wallProbeLen, rayParams)
                local sign = (not rightHit and leftHit) and 1 or ((rightHit and not leftHit) and -1 or (i%2==1 and 1 or -1))

                local t1 = tick()
                while AB.on and tick()-t1 < 0.22 do
                    bv.Velocity = perp * (AB.sideStep * 2.0 * sign)
                    RunService.Heartbeat:Wait()
                end
                bv.Velocity = Vector3.new()
                if not wallAhead(dir) then ok = true break end
            end
            if not ok then bv.Velocity = Vector3.new(); return false end
        end

        bv.Velocity = dir * AB.speed

        local moved = (rp - lastPos).Magnitude
        if moved > 0.15 then lastMoveT = tick(); lastPos = rp end
        if (tick() - lastMoveT) > AB.antiStuckTime then
            local perp = Vector3.new(-dir.Z,0,dir.X).Unit
            local t1 = tick()
            while AB.on and tick()-t1 < 0.2 do bv.Velocity = perp * (AB.sideStep*2); RunService.Heartbeat:Wait() end
            bv.Velocity = Vector3.new()
            t1 = tick()
            while AB.on and tick()-t1 < 0.2 do bv.Velocity = -perp * (AB.sideStep*2); RunService.Heartbeat:Wait() end
            bv.Velocity = Vector3.new()
            lastMoveT = tick()
        end

        if (tick() - t0) > timeCap then
            bv.Velocity = Vector3.new(); return false
        end
        RunService.Heartbeat:Wait()
    end
    return false
end

local function groundYAt(x, z)
    local origin = Vector3.new(x, (root.Position.Y + 50), z)
    local hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), rayParams)
    if hit then return hit.Position.Y - 0.1 end
    return root.Position.Y - 3
end

local function spotOccupied(pos, r)
    r = r or (AB.spacing * 0.45)
    local dep = workspace:FindFirstChild("Deployables")
    if not dep then return false end
    for _,d in ipairs(dep:GetChildren()) do
        if d:IsA("Model") and d.Name == "Plant Box" then
            local p = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if p and (p.Position - pos).Magnitude <= r then
                return true
            end
        end
    end
    return false
end

local function placePlantBoxAt(pos)
    if packets and packets.PlaceStructure and packets.PlaceStructure.send then
        pcall(function()
            packets.PlaceStructure.send{
                buildingName = "Plant Box",
                yrot = 45,
                vec = pos,
                isMobile = false
            }
        end)
        return true
    end
    return false
end

local function buildCellsFromArea()
    if not (AB.cornerA and AB.cornerB) then return {} end
    local a, b = AB.cornerA, AB.cornerB
    local xmin, xmax = math.min(a.X,b.X), math.max(a.X,b.X)
    local zmin, zmax = math.min(a.Z,b.Z), math.max(a.Z,b.Z)
    local step = AB.spacing

    local function snap(v, s) return math.floor(v/s + 0.5)*s end
    xmin, xmax = snap(xmin, step), snap(xmax, step)
    zmin, zmax = snap(zmin, step), snap(zmax, step)

    local cells, row = {}, 0
    for z = zmin, zmax, step do
        local xs, xe, dx
        if (row % 2 == 0) then xs, xe, dx = xmin, xmax, step else xs, xe, dx = xmax, xmin, -step end
        for x = xs, xe, dx do
            table.insert(cells, Vector3.new(x, groundYAt(x,z), z))
        end
        row += 1
    end
    return cells
end

task.spawn(function()
    while true do
        if AB.on and AB.cornerA and AB.cornerB and root then
            local cells = buildCellsFromArea()
            for _, p in ipairs(cells) do
                if not AB.on then break end
                local fly = Vector3.new(p.X, root.Position.Y, p.Z)
                local ok1 = moveBV_to(fly)
                if not ok1 then continue end
                if not spotOccupied(p) then
                    placePlantBoxAt(p)
                    task.wait(AB.placeDelay)
                end
            end
            AB_killBV()
        else
            AB_killBV()
            task.wait(0.15)
        end
    end
end)

-- ========= [ Configs buttons bind Route save/load ] =========
Tabs.Configs:CreateButton({
    Title="Quick Save",
    Callback=function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), Route.points)
        Route_SaveToFile(ROUTE_AUTOSAVE, Route.points)
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title="Quick Load",
    Callback=function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        local ok = Route_LoadFromFile(routePath(n), Route, { clearDots = clearDots, dot = dot })
        Library:Notify{ Title="Configs", Content="Loaded "..n..(ok and " +route" or " (no route file)"), Duration=3 }
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg",{ Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)

-- ========= [ Finish / Autoload ] =========
Window:SelectTab(1)
Library:Notify{ Title="Fuger Hub", Content="Loaded: Configs + Visuals + Survival + Gold + Route + Farming", Duration=6 }
pcall(function() SaveManager:LoadAutoloadConfig() end)

pcall(function()
    local ok = Route_LoadFromFile(ROUTE_AUTOSAVE, Route, { clearDots = clearDots, dot = dot })
    if ok then Library:Notify{ Title="Route", Content="Route autosave loaded", Duration=3 } end
end)
