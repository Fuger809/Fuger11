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

-- ========= [ ROUTE persist ] =========
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

-- ========= [ Общие инвентарь/еды (до Heal/Survival) ] =========
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
Tabs.Survival = Window:AddTab({ Title = "Survival", Icon = "apple" })
local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title = "Auto Eat (Hunger)", Default = false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title = "Food to eat",
    Values = {"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default = "Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title = "Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title = "Debug logs (F9)", Default = false })

local function normPct(n) if type(n)~="number" then return nil end if n<=1.5 then n=n*100 end return math.clamp(n,0,100) end
local function readHungerFromValues()
    for _,v in ipairs(plr:GetDescendants()) do
        if v.Name=="Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then return normPct(v.Value) end
    end
end
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
local function readHungerFromAttr()
    local a=plr:GetAttribute("Hunger")
    if typeof(a)=="number" then return normPct(a) end
end
local function readHungerPercent()
    return readHungerFromValues() or readHungerFromBar() or readHungerFromText() or readHungerFromAttr() or 100
end

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

-- ========= [ TAB: Route (record / play / save / click add + path lines) ] =========
Tabs.Route = Window:AddTab({ Title = "Route", Icon = "route" })
local R_gap   = Tabs.Route:CreateSlider("r_gap",  { Title = "Point gap (studs)", Min=0.5, Max=8, Rounding=2, Default=2 })
local R_spd   = Tabs.Route:CreateSlider("r_spd",  { Title = "Follow speed", Min=6, Max=40, Rounding=1, Default=20 })
local R_loop  = Tabs.Route:CreateToggle("r_loop", { Title = "Loop back & forth", Default = true })
local R_click = Tabs.Route:CreateToggle("r_click",{ Title = "Add points by mouse click", Default = false })

local Route = { points={}, recording=false, running=false,
    _hbConn=nil, _jumpConn=nil, _clickConn=nil,
    _lastPos=nil, _idleT0=nil, _lastJumpT=0, _lastLandT=0, _waitingLand=false }
_G.__ROUTE = Route

-- folders for dots and lines
local routeFolder = Workspace:FindFirstChild("_ROUTE_DOTS")  or Instance.new("Folder", Workspace)
routeFolder.Name = "_ROUTE_DOTS"
local linesFolder = Workspace:FindFirstChild("_ROUTE_LINES") or Instance.new("Folder", Workspace)
linesFolder.Name = "_ROUTE_LINES"

local COL_Y=Color3.fromRGB(255,230,80)  -- обычные точки
local COL_R=Color3.fromRGB(230,75,75)   -- ожидание
local COL_B=Color3.fromRGB(90,155,255)  -- прыжки
local COL_L=Color3.fromRGB(255,200,70)  -- линии

local function dot(color,pos,size)
    local p=Instance.new("Part")
    p.Name="_route_dot"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
    p.Shape=Enum.PartType.Ball; p.Material=Enum.Material.Neon; p.Color=color
    p.Size=Vector3.new(size or 0.7,size or 0.7,size or 0.7)
    p.CFrame=CFrame.new(pos + Vector3.new(0,0.15,0)); p.Parent=routeFolder
end
local function clearDots()
    for i,c in ipairs(routeFolder:GetChildren()) do
        if c:IsA("BasePart") and c.Name=="_route_dot" then c:Destroy() end
        if (i%250)==0 then RunService.Heartbeat:Wait() end
    end
end

-- линии-маршрута
local function clearLines()
    for _,c in ipairs(linesFolder:GetChildren()) do c:Destroy() end
end
local function makeSeg(p1, p2)
    local seg=Instance.new("Part")
    seg.Name="_route_line"; seg.Anchored=true; seg.CanCollide=false; seg.CanQuery=false; seg.CanTouch=false
    seg.Material=Enum.Material.Neon; seg.Color=COL_L; seg.Transparency=0.2
    local a=p1; local b=p2
    local mid=(a+b)/2
    local dir=(b-a)
    local dist=dir.Magnitude
    seg.Size=Vector3.new(0.15, 0.15, math.max(0.05, dist))
    seg.CFrame = CFrame.lookAt(mid, b)
    seg.Parent=linesFolder
end
local function redrawLines()
    clearLines()
    for i=1,#Route.points-1 do
        makeSeg(Route.points[i].pos, Route.points[i+1].pos)
    end
    if R_loop.Value and #Route.points>=2 then
        makeSeg(Route.points[#Route.points].pos, Route.points[1].pos)
    end
end

Route._redraw = { clearDots = clearDots, dot = dot, clearLines = clearLines, redrawLines = redrawLines }

local function ui(msg) pcall(function() Library:Notify{ Title="Route", Content=tostring(msg), Duration=2 } end) end
local function pushPoint(pos,flags)
    local r={pos=pos}
    if flags then for k,v in pairs(flags) do r[k]=v end end
    table.insert(Route.points,r)
    dot(COL_Y, pos, 0.7)
    redrawLines()
end

-- helpers
local ROUTE_BV_NAME="_ROUTE_BV"
local function getRouteBV() return root and root:FindFirstChild(ROUTE_BV_NAME) or nil end
local function ensureRouteBV()
    if not root or not root.Parent then return end
    local bv=getRouteBV()
    if not bv then
        bv=Instance.new("BodyVelocity"); bv.Name=ROUTE_BV_NAME
        bv.MaxForce=Vector3.new(1e9,0,1e9); bv.Velocity=Vector3.new(); bv.Parent=root
    end
    return bv
end
local function stopRouteBV() local bv=getRouteBV(); if bv then bv.Velocity=Vector3.new() end end
local function killRouteBV() local bv=getRouteBV(); if bv then bv:Destroy() end end

-- клик по земле -> добавить точку
local UIS = game:GetService("UserInputService")
local mouse = Players.LocalPlayer:GetMouse()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { plr.Character }

local function worldPointFromMouse()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local unitRay = cam:ViewportPointToRay(mouse.X, mouse.Y)
    local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction*5000, rayParams)
    if hit then
        return hit.Position
    end
    if mouse.Hit then return mouse.Hit.Position end
end

local function startClickAdd()
    if Route._clickConn then Route._clickConn:Disconnect(); Route._clickConn=nil end
    if not R_click.Value then return end
    Route._clickConn = mouse.Button1Down:Connect(function()
        if Route.recording or Route.running then return end
        local p = worldPointFromMouse()
        if not p then return end
        if #Route.points==0 then dot(COL_Y,p,0.9) end
        pushPoint(p)
        ui(("added point #%d"):format(#Route.points))
    end)
end

-- запись
function _ROUTE_startRecord()
    if Route.recording or Route.running then return end
    if not root or not hum then return end
    Route.recording=true; table.clear(Route.points)
    Route._idleT0=nil; Route._lastJumpT=0; Route._lastLandT=0
    Route._waitingLand=false; Route._lastPos=root.Position
    clearDots(); clearLines(); dot(COL_Y, Route._lastPos, 0.9); table.insert(Route.points, {pos=Route._lastPos})

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
                        table.remove(Route.points,#Route.points); redrawLines() end
                end
            end
        end

        local gap=(R_gap and R_gap.Value) or 2
        if (cur-Route._lastPos).Magnitude>=gap then
            pushPoint(cur); Route._lastPos=cur
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
        else if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then table.remove(Route.points,#Route.points); redrawLines() end end
    end
    if Route._hbConn then Route._hbConn:Disconnect(); Route._hbConn=nil end
    if Route._jumpConn then Route._jumpConn:Disconnect(); Route._jumpConn=nil end
    Route_SaveToFile(ROUTE_AUTOSAVE, Route.points)
    ui(("rec done (%d pts)"):format(#Route.points))
end

-- follow
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
    table.clear(Route.points); clearDots(); clearLines(); stopRouteBV(); killRouteBV(); ui("cleared")
end

-- UI buttons
Tabs.Route:CreateButton({ Title="Start record", Callback=_ROUTE_startRecord })
Tabs.Route:CreateButton({ Title="Stop record",  Callback=_ROUTE_stopRecord  })
Tabs.Route:CreateButton({ Title="Start follow", Callback=_ROUTE_startFollow })
Tabs.Route:CreateButton({ Title="Stop follow",  Callback=_ROUTE_stopFollow  })
Tabs.Route:CreateButton({ Title="Clear route",  Callback=_ROUTE_clear       })
Tabs.Route:CreateButton({
    Title = "Undo last point",
    Callback = function()
        if #Route.points>0 then
            table.remove(Route.points,#Route.points)
            redrawLines()
            ui("last point removed")
        end
    end
})
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
        local ok = Route_LoadFromFile(routePath(n), Route, Route._redraw)
        if ok then redrawLines() end
        Library:Notify{ Title="Route", Content= ok and ("Route loaded from "..n) or "No route file", Duration=3 }
    end
})
R_loop:OnChanged(redrawLines)
R_click:OnChanged(function() startClickAdd(); ui(R_click.Value and "Click-to-add: ON" or "Click-to-add: OFF") end)
startClickAdd()

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
    local plantboxes = {}
    local dep = workspace:FindFirstChild("Deployables")
    if not dep then return plantboxes end
    for _, d in ipairs(dep:GetChildren()) do
        if d:IsA("Model") and d.Name=="Plant Box" then
            local eid=d:GetAttribute("EntityID")
            local pp=d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if eid and pp then
                local dist=(pp.Position-root.Position).Magnitude
                if dist<=range then table.insert(plantboxes,{entityid=eid,deployable=d,dist=dist}) end
            end
        end
    end
    return plantboxes
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
local function safePickup(eid) local ok=pcall(function() pickup(eid) end)
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

-- авто-посадка
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
-- авто-сбор
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

-- ========= [ Farming: Area Auto Build (BV) ] =========
local BuildTab = Tabs.Farming
local AB = {
    on=false, cornerA=nil, cornerB=nil, spacing=6.04, hoverY=5, speed=21,
    stopTol=0.6, segTimeout=1.2, antiStuckTime=0.8, placeDelay=0.06,
    sideStep=4.2, sideMaxTries=4, wallProbeLen=7.0, wallProbeHeight=2.4
}
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
local rayParams = RaycastParams.new(); rayParams.FilterType=Enum.RaycastFilterType.Exclude; rayParams.FilterDescendantsInstances={plr.Character}
local function wallAhead(dir2d)
    if dir2d.Magnitude<1e-4 then return false end
    local origin=root.Position+Vector3.new(0,AB.wallProbeHeight,0)
    local dir3=Vector3.new(dir2d.X,0,dir2d.Z).Unit*AB.wallProbeLen
    local hit=workspace:Raycast(origin,dir3,rayParams); if not hit then return false end
    return (hit.Normal.Y or 0)<0.55
end
local function moveBV_to(target)
    if not AB.on or not root then return false end
    local bv=AB_ensureBV(); local t0, lastMoveT=tick(), tick(); local lastPos=root.Position; local timeCap=AB.segTimeout+6
    while AB.on do
        local rp=root.Position; local to2=Vector3.new(target.X-rp.X,0,target.Z-rp.Z); local dist=to2.Magnitude
        if dist<=AB.stopTol then bv.Velocity=Vector3.new(); return true end
        local dir=(dist>0) and to2.Unit or Vector3.new()
        if wallAhead(dir) then
            local perp=Vector3.new(-dir.Z,0,dir.X).Unit; local ok=false
            for i=1,AB.sideMaxTries do
                local rightHit=workspace:Raycast(rp+Vector3.new(0,AB.wallProbeHeight,0),(dir+perp).Unit*AB.wallProbeLen,rayParams)
                local leftHit =workspace:Raycast(rp+Vector3.new(0,AB.wallProbeHeight,0),(dir-perp).Unit*AB.wallProbeLen,rayParams)
                local sign=(not rightHit and leftHit) and 1 or ((rightHit and not leftHit) and -1 or (i%2==1 and 1 or -1))
                local t1=tick(); while AB.on and tick()-t1<0.22 do bv.Velocity=perp*(AB.sideStep*2.0*sign); RunService.Heartbeat:Wait() end
                bv.Velocity=Vector3.new(); if not wallAhead(dir) then ok=true break end
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
    local hit=workspace:Raycast(origin,Vector3.new(0,-500,0),rayParams)
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
local function safePickup(eid)
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
for _,n in ipairs(DROP_FOLDERS) do
    hookFolder(workspace:FindFirstChild(n))
end
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
        for k,v in pairs(val) do
            if v then sel[string.lower(k)] = true end
        end
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
                            if pass then
                                candidates[#candidates+1] = { eid = info.eid, dist = d, name = nm }
                            end
                        end
                    end
                end
            end
            if #candidates > 1 then
                table.sort(candidates, function(a,b) return a.dist < b.dist end)
            end
            if loot_debug.Value then
                print(("[AutoLoot] candidates=%d (mode=%s, chests=%s)")
                    :format(#candidates, useBlack and "Blacklist" or "Whitelist", tostring(loot_chests.Value)))
            end
            for i = 1, math.min(maxPer, #candidates) do
                safePickup(candidates[i].eid)
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

-- ========= [ TAB: Heal (Auto-Heal) — FAST / BURST ] =========
local HealTab = Window:AddTab({ Title = "Heal", Icon = "heart" })
local heal_toggle  = HealTab:CreateToggle("heal_auto", { Title = "Auto Heal", Default = false })
local heal_item    = HealTab:CreateDropdown("heal_item", {
    Title = "Item to use",
    Values = {"Bloodfruit","Berry","Strawberry","Coconut","Apple","Lemon","Orange","Banana"},
    Default = "Bloodfruit"
})
local heal_thresh  = HealTab:CreateSlider("heal_thresh", { Title = "HP threshold (%)", Min = 1, Max = 100, Rounding = 0, Default = 70 })
local heal_cd      = HealTab:CreateSlider("heal_cd", { Title = "Per-bite delay (s)", Min = 0.01, Max = 0.30, Rounding = 2, Default = 0.05 })
local heal_tick    = HealTab:CreateSlider("heal_tick", { Title = "Check interval (s)", Min = 0.01, Max = 0.20, Rounding = 2, Default = 0.03 })
local heal_hyst    = HealTab:CreateSlider("heal_hyst", { Title = "Extra heal margin (%)", Min = 0, Max = 30, Rounding = 0, Default = 4 })
local heal_burst   = HealTab:CreateSlider("heal_burst", { Title = "Max items per burst", Min = 1, Max = 10, Rounding = 0, Default = 4 })
local heal_debug   = HealTab:CreateToggle("heal_debug", { Title = "Debug logs (F9)", Default = false })
local function readHPpct()
    if not hum or hum.Health == nil or hum.MaxHealth == nil or hum.MaxHealth == 0 then return 100 end
    return math.clamp((hum.Health / hum.MaxHealth) * 100, 0, 100)
end
task.spawn(function()
    while true do
        if heal_toggle.Value and hum and hum.Parent then
            local hp = readHPpct()
            local thresh = heal_thresh.Value
            if hp < thresh then
                local target = math.min(100, thresh + (heal_hyst.Value or 0))
                local bites = 0
                local maxBites = math.max(1, math.floor(heal_burst.Value or 1))
                repeat
                    local it = heal_item.Value or "Bloodfruit"
                    local ok = consumeBySlot(getSlotByName(it)) or consumeById(getItemIdByName(it))
                    bites = bites + 1
                    if heal_debug.Value then
                        print(("[AutoHeal] HP=%.1f < %d :: bite %d -> %s"):format(hp, thresh, bites, ok and "USED" or "MISS"))
                    end
                    if not ok then break end
                    task.wait(heal_cd.Value)
                    hp = readHPpct()
                until hp >= target or bites >= maxBites
            end
            task.wait(heal_tick.Value)
        else
            task.wait(0.12)
        end
    end
end)

-- ========= [ TAB: Chopper (Auto Break Trees Around) — FIXED ] =========
Tabs.Chopper = Window:AddTab({ Title = "Chopper", Icon = "axe" })
local chop_on     = Tabs.Chopper:CreateToggle("chop_on",    { Title = "Auto Chop Trees (radius)", Default = false })
local chop_range  = Tabs.Chopper:CreateSlider("chop_range", { Title = "Range (studs)", Min = 6, Max = 150, Rounding = 0, Default = 40 })
local chop_max    = Tabs.Chopper:CreateSlider("chop_max",   { Title = "Max targets per swing", Min = 1, Max = 10, Rounding = 0, Default = 6 })
local chop_cd     = Tabs.Chopper:CreateSlider("chop_cd",    { Title = "Swing cooldown (s)", Min = 0.05, Max = 1.00, Rounding = 2, Default = 0.15 })
local chop_debug  = Tabs.Chopper:CreateToggle("chop_debug", { Title = "Debug prints (F9)", Default = false })
local CHOP_FOLDERS = { "Resources", "Trees", "Environment" }
local NAME_HINTS = { "tree", "pine", "palm", "oak", "birch", "log", "stump", "wood" }
local function isTreeLikeName(n)
    n = tostring(n or ""):lower()
    for _,h in ipairs(NAME_HINTS) do
        if n:find(h, 1, true) then return true end
    end
    return false
end
local function findEntityIdAnywhere(inst)
    if not inst or not inst.GetAttribute then return nil end
    local id = inst:GetAttribute("EntityID") or inst:GetAttribute("EntityId") or inst:GetAttribute("entityId")
    if id then return id end
    local p = inst.Parent
    while p and p ~= workspace do
        if p.GetAttribute then
            id = p:GetAttribute("EntityID") or p:GetAttribute("EntityId") or p:GetAttribute("entityId")
            if id then return id end
        end
        p = p.Parent
    end
    local count = 0
    for _,d in ipairs(inst:GetDescendants()) do
        count = count + 1
        if count > 50 then break end
        if d.GetAttribute then
            id = d:GetAttribute("EntityID") or d:GetAttribute("EntityId") or d:GetAttribute("entityId")
            if id then return id end
        end
    end
end
local function getModelPos(m)
    if m:IsA("Model") then
        local pp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
        if pp then return pp.Position end
        local ok, cf = pcall(function() return m:GetPivot() end)
        if ok and typeof(cf) == "CFrame" then return cf.Position end
    end
    if m:IsA("BasePart") or m:IsA("MeshPart") then
        return m.Position
    end
end
local function collectTreesAround(rp, radius)
    local list = {}
    local function considerContainer(container)
        if not container then return end
        for _,inst in ipairs(container:GetChildren()) do
            if (inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("MeshPart")) and isTreeLikeName(inst.Name) then
                local eid = findEntityIdAnywhere(inst)
                local pos = getModelPos(inst)
                if eid and pos then
                    local d = (pos - rp.Position).Magnitude
                    if d <= radius then
                        list[#list+1] = { eid = eid, dist = d }
                    end
                end
            end
            if inst:IsA("Folder") then
                for _,m in ipairs(inst:GetChildren()) do
                    if (m:IsA("Model") or m:IsA("BasePart") or m:IsA("MeshPart")) and isTreeLikeName(m.Name) then
                        local eid = findEntityIdAnywhere(m)
                        local pos = getModelPos(m)
                        if eid and pos then
                            local d = (pos - rp.Position).Magnitude
                            if d <= radius then
                                list[#list+1] = { eid = eid, dist = d }
                            end
                        end
                    end
                end
            end
        end
    end
    for _,fname in ipairs(CHOP_FOLDERS) do
        considerContainer(Workspace:FindFirstChild(fname) or workspace:FindFirstChild(fname))
    end
    considerContainer(Workspace)
    considerContainer(workspace)
    table.sort(list, function(a,b) return a.dist < b.dist end)
    return list
end
task.spawn(function()
    while true do
        if chop_on.Value and root then
            local radius     = chop_range.Value
            local maxTargets = math.max(1, math.floor(chop_max.Value))
            local cooldown   = chop_cd.Value
            local near = collectTreesAround(root, radius)
            if chop_debug.Value then
                print(("[Chopper] found %d targets within %.1f studs"):format(#near, radius))
            end
            if #near > 0 then
                local ids = {}
                for i = 1, math.min(maxTargets, #near) do
                    ids[#ids+1] = near[i].eid
                end
                swingtool(ids)
            end
            task.wait(cooldown)
        else
            task.wait(0.12)
        end
    end
end)

-- ========= [ TAB: Combat (KillAura + визуал удара) ] =========
Tabs.Combat = Window:AddTab({ Title = "Combat", Icon = "swords" })
local CA_toggle   = Tabs.Combat:CreateToggle("ca_toggle", { Title = "KillAura", Default = false })
local CA_range    = Tabs.Combat:CreateSlider("ca_range",  { Title = "Range (studs)", Min = 5, Max = 50, Rounding = 1, Default = 20 })
local CA_cd       = Tabs.Combat:CreateSlider("ca_cd",     { Title = "Swing cooldown (s)", Min = 0.05, Max = 1, Rounding = 2, Default = 0.15 })
local CA_targets  = Tabs.Combat:CreateSlider("ca_targets",{ Title = "Targets per swing", Min = 1, Max = 5, Default = 1 })
local VIS_useActivate = Tabs.Combat:CreateToggle("ca_vis_activate", { Title = "Play tool swing (Tool:Activate())", Default = true })
local VIS_useCustom   = Tabs.Combat:CreateToggle("ca_vis_custom",   { Title = "Also play custom AnimationId", Default = false })
local VIS_animIdInput = Tabs.Combat:AddInput("ca_vis_animid", { Title = "Custom AnimationId (number)", Default = "" })
local VIS_speed       = Tabs.Combat:CreateSlider("ca_vis_speed", { Title = "Custom anim speed", Min=0.5, Max=2.5, Rounding=2, Default=1.0 })
local function getEquippedTool()
    local c=plr.Character; if not c then return nil end
    for _,inst in ipairs(c:GetChildren()) do
        if inst:IsA("Tool") then return inst end
    end
end
local function ensureAnimator()
    if not char then return end
    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum_ = char:FindFirstChildOfClass("Humanoid")
        if hum_ then animator = hum_:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum_) end
    end
    return animator
end
local function playCustomAnimOnce()
    local raw = tostring(VIS_animIdInput.Value or "")
    local id = raw:match("%d+")
    if not id or id == "0" then return end
    local animator = ensureAnimator(); if not animator then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://"..id
    local track = animator:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action
    track:Play(0.05, 1, VIS_speed.Value or 1.0)
    task.delay(0.35, function()
        if track.IsPlaying then track:Stop() end
        track:Destroy()
    end)
end
local function playSwingVisual()
    if VIS_useActivate.Value then
        local tool = getEquippedTool()
        if tool then pcall(function() tool:Activate() end) end
    end
    if VIS_useCustom.Value then playCustomAnimOnce() end
end
task.spawn(function()
    while true do
        if not CA_toggle.Value or not root then task.wait(0.1) else
            local range = CA_range.Value
            local targetCount = math.floor(CA_targets.Value)
            local cooldown = CA_cd.Value
            local targets = {}
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= plr then
                    local folder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(player.Name)
                    if folder then
                        local rootpart = folder:FindFirstChild("HumanoidRootPart")
                        local entityid = folder:GetAttribute("EntityID")
                        if rootpart and entityid then
                            local dist = (rootpart.Position - root.Position).Magnitude
                            if dist <= range then
                                table.insert(targets, { eid = entityid, dist = dist })
                            end
                        end
                    end
                end
            end
            if #targets > 0 then
                table.sort(targets, function(a, b) return a.dist < b.dist end)
                local ids = {}
                for i = 1, math.min(targetCount, #targets) do ids[#ids+1] = targets[i].eid end
                swingtool(ids)
                playSwingVisual()
            end
            task.wait(cooldown)
        end
    end
end)

-- ========= [ TAB: Visuals (Full Bright) ] =========
local L = game:GetService("Lighting")
local VisualsTab = Window:AddTab({ Title = "Visuals", Icon = "sun" })
local fb_toggle     = VisualsTab:CreateToggle("fullbright_on",   { Title = "Full Bright (всегда светло)", Default = false })
local fb_keepday    = VisualsTab:CreateToggle("fullbright_day",  { Title = "Делать всегда день (ClockTime=12)", Default = true })
local fb_nofog      = VisualsTab:CreateToggle("fullbright_nofog",{ Title = "Отключить туман/атмосферу", Default = true })
local fb_shadows    = VisualsTab:CreateToggle("fullbright_shad", { Title = "Отключить тени (GlobalShadows=false)", Default = true })
local fb_bright     = VisualsTab:CreateSlider("fullbright_bri",  { Title = "Lighting.Brightness", Min = 1, Max = 6, Rounding = 1, Default = 3 })
local fb_exposure   = VisualsTab:CreateSlider("fullbright_exp",  { Title = "ExposureCompensation", Min = -1, Max = 2, Rounding = 2, Default = 0.2 })
local FB = {
    on = false,
    conn = nil,
    orig = {
        Brightness            = L.Brightness,
        ClockTime             = L.ClockTime,
        FogEnd                = L.FogEnd,
        Ambient               = L.Ambient,
        GlobalShadows         = L.GlobalShadows,
        ExposureCompensation  = L.ExposureCompensation,
    }
}
local function ensureCC()
    local cc = L:FindFirstChild("_FB_CC")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "_FB_CC"
        cc.Enabled = true
        cc.Parent = L
    end
    return cc
end
local LIGHT_AMBIENT = Color3.fromRGB(180, 180, 180)
local function killFogAndAtmo()
    L.FogEnd = 1e9
    local atmo = L:FindFirstChildOfClass("Atmosphere")
    if atmo then
        atmo.Density = 0; atmo.Offset = 0; atmo.Haze = 0; atmo.Glare = 0
    end
end
local function applyFullBrightOnce()
    L.Brightness = fb_bright.Value
    L.Ambient = LIGHT_AMBIENT
    L.ExposureCompensation = fb_exposure.Value
    if fb_keepday.Value then L.ClockTime = 12 end
    if fb_shadows.Value then L.GlobalShadows = false end
    if fb_nofog.Value then killFogAndAtmo() end
    local cc = ensureCC()
    cc.Brightness = 0.05
    cc.Contrast   = 0.02
    cc.Saturation = 0
end
local function restoreLighting()
    for k,v in pairs(FB.orig) do pcall(function() L[k] = v end) end
    local cc = L:FindFirstChild("_FB_CC"); if cc then cc:Destroy() end
end
local function startFBLoop()
    if FB.conn then FB.conn:Disconnect() FB.conn = nil end
    FB.conn = RunService.Heartbeat:Connect(function()
        if fb_toggle.Value then applyFullBrightOnce() end
    end)
end
VisualsTab:CreateButton({
    Title = "Reset Lighting (restore defaults)",
    Callback = function()
        fb_toggle:SetValue(false)
        restoreLighting()
    end
})
fb_toggle:OnChanged(function(v)
    if v then
        FB.orig.Brightness           = L.Brightness
        FB.orig.ClockTime            = L.ClockTime
        FB.orig.FogEnd               = L.FogEnd
        FB.orig.Ambient              = L.Ambient
        FB.orig.GlobalShadows        = L.GlobalShadows
        FB.orig.ExposureCompensation = L.ExposureCompensation
        applyFullBrightOnce()
    else
        restoreLighting()
    end
end)
local function liveUpdate() if fb_toggle.Value then applyFullBrightOnce() end end
fb_bright:OnChanged(liveUpdate)
fb_exposure:OnChanged(liveUpdate)
fb_keepday:OnChanged(liveUpdate)
fb_nofog:OnChanged(liveUpdate)
fb_shadows:OnChanged(liveUpdate)
startFBLoop()
plr.CharacterAdded:Connect(function() task.defer(function() if fb_toggle.Value then applyFullBrightOnce() end end) end)

-- ========= [ TAB: Movement (Slope / Auto Climb) ] =========
local UIS2 = game:GetService("UserInputService")
local LRun = game:GetService("RunService")
local MoveTab = Window:AddTab({ Title = "Movement", Icon = "mountain" })
local mv_on        = MoveTab:CreateToggle("mv_on",        { Title = "Slope / Auto Climb (BV)", Default = false })
local mv_speed     = MoveTab:CreateSlider("mv_speed",     { Title = "Speed", Min = 8, Max = 40, Rounding = 1, Default = 20 })
local mv_boost     = MoveTab:CreateToggle("mv_boost",     { Title = "Shift = Boost (+40%)", Default = true })
local mv_jumphelp  = MoveTab:CreateToggle("mv_jumphelp",  { Title = "Auto Jump on slopes", Default = true })
local mv_sidestep  = MoveTab:CreateToggle("mv_sidestep",  { Title = "Side step if blocked", Default = true })
local mv_probeLen  = MoveTab:CreateSlider("mv_probel",    { Title = "Wall probe length", Min=4, Max=12, Rounding=1, Default=7 })
local mv_probeH    = MoveTab:CreateSlider("mv_probeh",    { Title = "Probe height", Min=1.5, Max=4, Rounding=1, Default=2.4 })
local mv_stuckT    = MoveTab:CreateSlider("mv_stuck",     { Title = "Anti-stuck time (s)", Min=0.2, Max=1.2, Rounding=2, Default=0.6 })
local mv_sideStep  = MoveTab:CreateSlider("mv_sidest",    { Title = "Side step power", Min=2, Max=7, Rounding=1, Default=4.2 })

local function getRoot() local c = plr.Character return c and c:FindFirstChild("HumanoidRootPart") or nil end
local function mv_getBV() local rp = getRoot() return rp and rp:FindFirstChild("_MV_BV") or nil end
local function mv_ensureBV()
    local rp = getRoot(); if not rp then return end
    local bv = mv_getBV()
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "_MV_BV"
        bv.MaxForce = Vector3.new(1e9, 0, 1e9)
        bv.Velocity = Vector3.new()
        bv.Parent = rp
    end
    return bv
end
local function mv_killBV() local bv = mv_getBV(); if bv then bv:Destroy() end end
local rayParams_mv = RaycastParams.new(); rayParams_mv.FilterType = Enum.RaycastFilterType.Exclude; rayParams_mv.FilterDescendantsInstances = { plr.Character }
local function wallAhead(dir2d)
    local rp = getRoot(); if not rp then return false end
    if dir2d.Magnitude < 1e-3 then return false end
    local origin = rp.Position + Vector3.new(0, mv_probeH.Value, 0)
    local dir3 = Vector3.new(dir2d.X, 0, dir2d.Z).Unit * mv_probeLen.Value
    local hit = workspace:Raycast(origin, dir3, rayParams_mv)
    if not hit then return false end
    return (hit.Normal.Y or 0) < 0.6
end
local function trySideStep(dir2d)
    if not mv_sidestep.Value then return end
    local rp = getRoot(); local bv = mv_ensureBV()
    if not (rp and bv) then return end
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
local function autoJump()
    if not mv_jumphelp.Value then return end
    if hum then pcall(function() hum.Jump = true; hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end
task.spawn(function()
    local lastMoveT = tick()
    while true do
        if mv_on.Value and hum and root and hum.Parent then
            local dir = hum.MoveDirection
            local moving = dir.Magnitude > 0.05
            if moving then
                local speed = mv_speed.Value
                if mv_boost.Value and UIS2:IsKeyDown(Enum.KeyCode.LeftShift) then
                    speed = speed * 1.4
                end
                dir = dir.Unit
                local bv = mv_ensureBV()
                if wallAhead(dir) then
                    autoJump()
                    trySideStep(dir)
                end
                bv.Velocity = dir * speed
                lastMoveT = tick()
            else
                local bv = mv_getBV(); if bv then bv.Velocity = Vector3.new() end
            end
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
plr.CharacterAdded:Connect(function() task.defer(function() ensureChar(); if not mv_on.Value then mv_killBV() end end) end)
mv_on:OnChanged(function(v) if not v then mv_killBV() end end)

-- ===== Strong NoClip Tab (safe) v1.3 =====
do
    local ok, err = pcall(function()
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UIS = game:GetService("UserInputService")
        local PhysicsService = game:GetService("PhysicsService")
        local lp = Players.LocalPlayer
        local cam = workspace.CurrentCamera

        -- взять уже созданный Fluent Window, иначе поднять мини-окно
        local Library = rawget(_G, "__FUGER_LIB")
        local Window  = rawget(_G, "__FUGER_WIN")
        if not (Library and Window and Window.AddTab) then
            local function HttpGet(u) return game:HttpGet(u, true) end
            local libOK, lib = pcall(function()
                return loadstring(HttpGet("https://github.com/1dontgiveaf/Fluent-Renewed/releases/download/v1.0/Fluent.luau"))()
            end)
            if not libOK then return end
            Library = lib
            Window = Library:CreateWindow{
                Title = "Fuger Tools",
                SubTitle = "NoClip addon",
                Size = UDim2.fromOffset(480, 320),
                Theme = "Dark",
                MinimizeKey = Enum.KeyCode.LeftControl
            }
            rawset(_G, "__FUGER_LIB", Library)
            rawset(_G, "__FUGER_WIN", Window)
        end

        -- персонаж
        local char, hum, root
        local function bindChar()
            char = lp.Character or lp.CharacterAdded:Wait()
            hum  = char:WaitForChild("Humanoid")
            root = char:WaitForChild("HumanoidRootPart")
        end
        bindChar()
        lp.CharacterAdded:Connect(function() task.defer(bindChar) end)

        -- создать/настроить группу без коллизий
        local GROUP = "FUGER_NC"
        local function setupGroup()
            pcall(function()
                local groups = PhysicsService:GetCollisionGroups()
                local exists = false
                for _,g in ipairs(groups) do if g.name == GROUP then exists = true break end end
                if not exists then PhysicsService:CreateCollisionGroup(GROUP) end
                -- отключить столкновения нашей группы со всеми известными
                groups = PhysicsService:GetCollisionGroups()
                for _,g in ipairs(groups) do
                    PhysicsService:CollisionGroupSetCollidable(GROUP, g.name, false)
                    PhysicsService:CollisionGroupSetCollidable(g.name, GROUP, false)
                end
            end)
        end
        setupGroup()

        -- UI
        local Tab = Window:AddTab({ Title = "NoClip", Icon = "ghost" })
        local t_enable = Tab:CreateToggle("nc_on", { Title="Enable NoClip (toggle)", Default=false })
        local t_hold   = Tab:CreateToggle("nc_hold", { Title="Hold LeftShift (priority)", Default=false })
        local t_ghost  = Tab:CreateToggle("nc_ghost", { Title="Ghost move (WASD + Q/E)", Default=true })
        local s_spd    = Tab:CreateSlider("nc_spd", { Title="Speed", Min=6, Max=80, Default=28 })
        local s_vspd   = Tab:CreateSlider("nc_vspd", { Title="Vertical speed", Min=4, Max=50, Default=22 })
        local t_norot  = Tab:CreateToggle("nc_norot", { Title="Freeze Humanoid AutoRotate", Default=true })

        Tab:AddParagraph({Title="Hint", Content="Toggle = обычный NoClip. Hold = зажми LeftShift. Ghost — свободный полёт."})

        -- применить группу и убрать коллизии у всех частей
        local function applyNoCollision()
            if not char then return end
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                    p.CanTouch   = false
                    pcall(function() PhysicsService:SetPartCollisionGroup(p, GROUP) end)
                end
            end
            if hum then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
                hum.AutoRotate = not t_norot.Value
            end
        end

        local function clearGroup()
            if not char then return end
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    -- вернуть в Default, но не включать столкновения насильно
                    pcall(function() PhysicsService:SetPartCollisionGroup(p, "Default") end)
                end
            end
            if hum then hum.AutoRotate = true end
        end

        -- основной цикл noclip
        local stepConn
        local function runNoClip(on)
            if on then
                if stepConn then stepConn:Disconnect() end
                stepConn = RunService.Stepped:Connect(applyNoCollision)
            else
                if stepConn then stepConn:Disconnect() stepConn=nil end
                clearGroup()
            end
        end

        -- Ghost (BodyVelocity)
        local function getBV() return root and root:FindFirstChild("_NC_BV") end
        local function killBV() local b=getBV() if b then b:Destroy() end end
        local function ensureBV()
            if not root then return end
            local b=getBV()
            if not b then
                b=Instance.new("BodyVelocity")
                b.Name="_NC_BV"
                b.MaxForce=Vector3.new(1e9,1e9,1e9)
                b.Velocity=Vector3.new()
                b.Parent=root
            end
            return b
        end
        RunService.Heartbeat:Connect(function()
            if not (t_ghost.Value and root) then killBV() return end
            local b=ensureBV(); if not b then return end
            local v=Vector3.zero
            local cf=(cam and cam.CFrame) or root.CFrame
            local f=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z).Unit
            local r=Vector3.new(cf.RightVector.X,0,cf.RightVector.Z).Unit
            local sp=s_spd.Value
            if UIS:IsKeyDown(Enum.KeyCode.W) then v=v+f*sp end
            if UIS:IsKeyDown(Enum.KeyCode.S) then v=v-f*sp end
            if UIS:IsKeyDown(Enum.KeyCode.D) then v=v+r*sp end
            if UIS:IsKeyDown(Enum.KeyCode.A) then v=v-r*sp end
            local vs=s_vspd.Value
            if UIS:IsKeyDown(Enum.KeyCode.E) then v=v+Vector3.new(0,vs,0) end
            if UIS:IsKeyDown(Enum.KeyCode.Q) then v=v-Vector3.new(0,vs,0) end
            b.Velocity=v
        end)

        -- мастер-логика
        local function wantOn()
            if t_hold.Value then return UIS:IsKeyDown(Enum.KeyCode.LeftShift) end
            return t_enable.Value
        end
        local function recompute()
            setupGroup()
            runNoClip(wantOn())
            if not t_ghost.Value then killBV() end
        end
        t_enable:OnChanged(recompute)
        t_hold:OnChanged(recompute)
        t_norot:OnChanged(function(v) if hum then hum.AutoRotate = not v end end)
        t_ghost:OnChanged(function(v) if not v then killBV() end end)

        -- на всякий — горячая клавиша N для быстрого тумблера
        UIS.InputBegan:Connect(function(i,gp)
            if gp then return end
            if i.KeyCode == Enum.KeyCode.N then
                t_enable:SetValue(not t_enable.Value)
                recompute()
            end
        end)
    end)
    if not ok then warn("[Strong NoClip] "..tostring(err)) end
end
-- ===== /Strong NoClip =====


-- ========= [ Finish / Autoload ] =========
Window:SelectTab(1)
Library:Notify{ Title="Fuger Hub", Content="Loaded: Configs + Survival + Gold + Route + Farming + Heal + Combat", Duration=6 }
pcall(function() SaveManager:LoadAutoloadConfig() end)
pcall(function()
    local ok = Route_LoadFromFile(ROUTE_AUTOSAVE, Route, Route._redraw)
    if ok then Library:Notify{ Title="Route", Content="Route autosave loaded", Duration=3 } end
end)
