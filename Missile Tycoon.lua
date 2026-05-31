local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

task.spawn(function()
    LocalPlayer:WaitForChild("RocketClient", 15)
end)

-- ==========================================
-- CORE REMOTES & TYCOON PLOT SETUP
-- ==========================================
local CBR = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes")
local PerformActionFunc = CBR:WaitForChild("PerformAction")
local ActionEvent = CBR:WaitForChild("PerformActionEvent")
local FactoryEvent = CBR:WaitForChild("FactoryCreateRocket")
local StorageAction = CBR:WaitForChild("FactoryStorageAction")

-- Intercepted Logic: Finding your exact Tycoon Plot and Anchor
local world = Workspace:WaitForChild("CityBuilderRocketsWorld", 60)
local myPlot = nil
local anchor = nil

task.spawn(function()
    if world then
        for _, plot in ipairs(world:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                myPlot = plot
                anchor = myPlot:FindFirstChild("Anchor")
                break
            end
        end
    end
end)

-- ==========================================
-- INTERCEPTED HELPER FUNCTIONS (TAB 3 & 4)
-- ==========================================
local function runBuy(shop, def, req)
    pcall(function() ActionEvent:FireServer("BuyOwnedItem", {ShopIndex = shop, DefinitionId = def, RequestId = req}) end)
end

local function runCreateRocket(rocketId)
    pcall(function() FactoryEvent:FireServer(rocketId, 1) end)
end

local function getExactStorageIds()
    local ids = {}
    if not myPlot then return ids end
    local objects = myPlot:FindFirstChild("Objects")
    if not objects then return ids end
    for _, v in ipairs(objects:GetChildren()) do
        if v.Name == "Storage" then
            local oid = v:GetAttribute("ObjectId")
            if oid then table.insert(ids, oid) end
        end
    end
    return ids
end

local function isRocketSlot(slot)
    local fr = slot:FindFirstChild("Frame")
    local vpf = fr and fr:FindFirstChildOfClass("ViewportFrame")
    local wm = vpf and vpf:FindFirstChildOfClass("WorldModel")
    if not wm then return false end
    for _, c in ipairs(wm:GetChildren()) do
        if c:IsA("Model") and c.Name:lower():find("rocket") and not c.Name:lower():find("launcher") then return true end
    end
    return false
end

local function scanInventoryContainer(container, slots)
    if not container then return end
    for _, slot in ipairs(container:GetChildren()) do
        if not slot:IsA("TextButton") then continue end
        local sc = slot:FindFirstChild("StackCount")
        local n = sc and tonumber(sc.Text) or 0
        if n > 0 and isRocketSlot(slot) then table.insert(slots, {id = slot.Name, count = n}) end
    end
end

local function getRocketSlots()
    local slots = {}
    local invGui = LocalPlayer.PlayerGui:FindFirstChild("RocketInventoryGui")
    if not invGui then return slots end
    scanInventoryContainer(invGui:FindFirstChild("BottomBar"), slots)
    local ov = invGui:FindFirstChild("OverflowInventoryWindow")
    if ov then scanInventoryContainer(ov:FindFirstChild("OverflowInventoryScroll"), slots) end
    return slots
end

local function isOccupied(lx, lz)
    if not myPlot then return false end
    local objects = myPlot:FindFirstChild("Objects")
    if not objects then return false end
    for _, v in ipairs(objects:GetChildren()) do
        local ox = v:GetAttribute("LocalX")
        local oz = v:GetAttribute("LocalZ")
        if ox and oz and math.abs(ox - lx) < 1 and math.abs(oz - lz) < 1 then return true end
    end
    return false
end

-- ==========================================
-- UI SETUP
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Missile Tycoon Daddy 🚀 | Sid",
    LoadingTitle = "New Op Update 🔥🔥💥💥",
    LoadingSubtitle = "Loaded Instantly. 60FPS Verified.",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false 
})

---------------------------------------------------------------------------
-- TAB 1: BOMBARD / WAR
---------------------------------------------------------------------------
local MainTab = Window:CreateTab("💣 Bombard", 4483362458)
_G.MySafeZone = nil
task.spawn(function()
    if LocalPlayer.Character and LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5) then
        _G.MySafeZone = LocalPlayer.Character.HumanoidRootPart.Position
    end
end)

MainTab:CreateSection("Automation War")
_G.SelectedPlayer = nil
local PlayerDropdown = MainTab:CreateDropdown({
    Name = "🎯 Select Target Player", Options = {"Loading..."},
    Callback = function(Opt) _G.SelectedPlayer = Players:FindFirstChild(Opt[1]) end,
})
local StatusLabel = MainTab:CreateLabel("Status: 💤 Idle")
local StatsLabel = MainTab:CreateLabel("Total Destroyed: 0")

_G.TotalDestroyed = 0
local TargetedInstances, FoundRockets, FoundBuildings = {}, {}, {}
_G.FiredRocketsTracker = {} 
_G.WarInProgress = false

local function DeepScan()
    table.clear(FoundRockets) table.clear(FoundBuildings)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or not _G.SelectedPlayer then return end
    local enemyChar = _G.SelectedPlayer.Character and _G.SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    local function ScanContainer(cont)
        if not cont then return end
        for _, item in ipairs(cont:GetChildren()) do
            if item:IsA("Tool") then
                local id = item:GetAttribute("ObjectId") or item.Name:match("^%d+_%d+_%d+") or (item.Name:lower():match("rocket") and item.Name)
                if id then table.insert(FoundRockets, {ID = id, InstanceRef = item, IsTool = true}) end
            end
        end
    end
    ScanContainer(LocalPlayer:FindFirstChild("Backpack"))
    ScanContainer(LocalPlayer.Character)
    
    for _, v in ipairs(Workspace:GetDescendants()) do
        local isRocket = v.Name:match("^%d+_%d+_%d+") or v:GetAttribute("ObjectId")
        if isRocket and not v.Name:lower():match("part") and not v:IsDescendantOf(LocalPlayer.Character) and not v:IsDescendantOf(LocalPlayer:FindFirstChild("Backpack")) then
            local rPos = (v:IsA("BasePart") and v.Position) or (v:IsA("Model") and v:GetModelCFrame().p)
            if rPos and (rPos - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 30 then
                table.insert(FoundRockets, {ID = isRocket, InstanceRef = v, IsTool = false}) 
            end
        end
        local uuid = v:GetAttribute("InventoryId") or v:GetAttribute("ObjectId")
        if uuid and enemyChar then
            local bPos = (v:IsA("BasePart") and v.Position) or (v:IsA("Model") and v:GetModelCFrame().p)
            if bPos then
                local isSafe = false
                if v:GetAttribute("Owner") == LocalPlayer.Name or v:IsDescendantOf(LocalPlayer.Character) then isSafe = true end
                if _G.MySafeZone and (bPos - _G.MySafeZone).Magnitude <= 600 then isSafe = true end
                if not isSafe and (bPos - enemyChar.Position).Magnitude <= 600 and not v.Name:lower():match("rocket") then 
                    table.insert(FoundBuildings, {ID = uuid, Pos = bPos, Instance = v}) 
                end
            end
        end
    end
end

local function TriggerAttack(isBulk)
    if not _G.SelectedPlayer or _G.WarInProgress then return end
    _G.WarInProgress = true
    StatusLabel:Set("Status: ⚔️ WAR ACTIVE")
    task.spawn(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        while _G.WarInProgress do
            DeepScan() 
            if #FoundRockets > 0 and #FoundBuildings > 0 and _G.SelectedPlayer then
                local limit = isBulk and #FoundRockets or math.min(#FoundRockets, 5)
                for i = 1, limit do
                    if not _G.WarInProgress then break end
                    local t = FoundBuildings[math.random(1, #FoundBuildings)]
                    local mId = FoundRockets[i].ID
                    _G.FiredRocketsTracker[mId] = true 
                    if FoundRockets[i].IsTool and FoundRockets[i].InstanceRef.Parent == LocalPlayer:FindFirstChild("Backpack") and hum then
                        hum:EquipTool(FoundRockets[i].InstanceRef) task.wait(0.01)
                    end
                    task.spawn(function()
                        pcall(function() ActionEvent:FireServer("LaunchRocket", {WarConfirmed = true, TargetZ = t.Pos.Z, ObjectId = mId, TargetX = t.Pos.X, TargetY = t.Pos.Y}) TargetedInstances[t.Instance] = true end)
                    end)
                    task.wait(0.05)
                end
            else
                task.wait(0.1)
                if #FoundBuildings == 0 and _G.SelectedPlayer then _G.WarInProgress = false end
            end
        end
        StatusLabel:Set("Status: 💤 Idle")
    end)
end

MainTab:CreateButton({ Name = "🚀 ATTACK BULK", Callback = function() TriggerAttack(true) end })
MainTab:CreateButton({ Name = "🎯 ATTACK NORMAL", Callback = function() TriggerAttack(false) end })
MainTab:CreateButton({ Name = "🛑 STOP WAR", Callback = function() _G.WarInProgress = false StatusLabel:Set("Status: 💤 Idle") end })

task.spawn(function()
    while task.wait(0.5) do
        local list = {}
        for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(list, p.Name) end end
        pcall(function() PlayerDropdown:Refresh(#list > 0 and list or {"Waiting for Players..."}, true) end)
        for inst, _ in pairs(TargetedInstances) do
            if not inst or not inst.Parent then
                _G.TotalDestroyed = _G.TotalDestroyed + 1
                TargetedInstances[inst] = nil
                StatsLabel:Set("Total Destroyed: " .. _G.TotalDestroyed)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- TAB 2: BUYING AND TAKING
---------------------------------------------------------------------------
local BuyTab = Window:CreateTab("🟢 Auto Purchases")

local AllBuildings = {
    {"Bluebird House", 4, "tier1_bluebird_house"}, {"Sunset Villa", 5, "tier1_sunset_villa"},
    {"Corner Market", 6, "tier1_corner_market"}, {"Seaside Motel", 8, "tier2_seaside_motel"},
    {"Metro Bank", 9, "tier2_metro_bank"}, {"Boutique Hotel", 10, "tier2_boutique_hotel"},
    {"Arcade Cash Hub", 11, "tier2_arcade_cash_hub"}, {"Resort Residence", 12, "tier3_resort_residence"},
    {"Exchange Tower", 14, "tier3_exchange_tower"}, {"Grand Hotel Tower", 13, "tier3_grand_hotel_tower"},
    {"Bank", 15, "bank"}, {"Factory", 16, "factory"}, {"Satellite Station", 17, "building_new1"},
    {"Nuclear Facility", 18, "building_new2"}
}

local AllMilitary = {
    {"Launcher Rockets 1", 19, "launcher_rockets1"}, {"Factory 1", 3, "factory1"}, {"Storage", 2, "storage"}
}

BuyTab:CreateSection("Auto Buy Everything")
BuyTab:CreateToggle({Name = "✅ Auto Buy ALL Buildings", CurrentValue = false, Callback = function(V)
    _G.BuyAllBuilds = V
    if V then task.spawn(function() while _G.BuyAllBuilds do for _, b in ipairs(AllBuildings) do runBuy(b[2], b[3], "00000000") end task.wait(0.1) end end) end
end})

BuyTab:CreateToggle({Name = "✅ Auto Buy ALL Military", CurrentValue = false, Callback = function(V)
    _G.BuyAllMil = V
    if V then task.spawn(function() while _G.BuyAllMil do for _, m in ipairs(AllMilitary) do runBuy(m[2], m[3], "00000000") end task.wait(0.1) end end) end
end})

---------------------------------------------------------------------------
-- TAB 3: MISSILES
---------------------------------------------------------------------------
local MissileTab = Window:CreateTab("🚀 Missiles")
local MissileTypes = {
    {"Firefly Rocket", "firefly_rocket", "Rocket1"}, {"Viper Cruise", "viper_cruise_rocket", "Rocket2"},
    {"Hammer Ballistic", "hammer_ballistic_rocket", "Rocket3"}, {"Titan Strike", "rocket4", "Rocket4"},
    {"Crimson Strike", "rocket5", "Rocket5"}, {"Golden Lance", "rocket6", "rocket6"},
    {"Leviathan Siege", "rocket7", "rocket7"}, {"Titan Fang", "rocket8", "rocket8"}, {"Shadow Viper", "rocket9", "rocket9"}
}
local ROCKET_KEYS = {"Rocket1","Rocket2","Rocket3","Rocket4","Rocket5","Rocket6","Rocket7","Rocket8","Rocket9"}

MissileTab:CreateSection("Auto Create & Take")
MissileTab:CreateToggle({Name = "🎲 Make Random Missile", CurrentValue = false, Callback = function(V)
    _G.RandMissile = V
    if V then task.spawn(function() while _G.RandMissile do runCreateRocket(MissileTypes[math.random(1, #MissileTypes)][2]) task.wait(0.05) end end) end
end})

MissileTab:CreateToggle({Name = "✅ Auto Take ALL Missiles", CurrentValue = false, Callback = function(V)
    _G.TakeAllM = V
    if V then 
        task.spawn(function() 
            while _G.TakeAllM do
                local sids = getExactStorageIds()
                if #sids > 0 then
                    for _, sid in ipairs(sids) do
                        if not _G.TakeAllM then break end
                        pcall(function() StorageAction:InvokeServer("Get", nil, nil, sid) end)
                        task.wait(0.05) 
                        for _, rkey in ipairs(ROCKET_KEYS) do
                            if not _G.TakeAllM then break end
                            pcall(function() StorageAction:InvokeServer("Take", rkey, 5, sid) end)
                        end
                        task.wait(0.05) 
                    end
                else 
                    task.wait(1) 
                end
            end 
        end) 
    end
end})

---------------------------------------------------------------------------
-- TAB 4: THE ULTIMATE AUTO-PLACE (FULL INTERCEPTED LOGIC)
---------------------------------------------------------------------------
local PlaceTab = Window:CreateTab("🔥 Auto Place")

_G.COLS = 10
_G.ROWS = 10
_G.STEP = 3.5

PlaceTab:CreateSection("Grid Dimensions")
PlaceTab:CreateSlider({Name = "Grid Width (Cols)", Range = {1, 50}, Increment = 1, CurrentValue = 10, Callback = function(V) _G.COLS = V end})
PlaceTab:CreateSlider({Name = "Grid Depth (Rows)", Range = {1, 50}, Increment = 1, CurrentValue = 10, Callback = function(V) _G.ROWS = V end})
PlaceTab:CreateSlider({Name = "Grid Spacing", Range = {2, 15}, Increment = 0.5, CurrentValue = 3.5, Callback = function(V) _G.STEP = V end})

-- Intercepted Box Drawing Logic
local boxParts = {}
local function clearBox()
    for _, p in ipairs(boxParts) do pcall(function() p:Destroy() end) end
    boxParts = {}
end

local function makePart(color)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CastShadow = false
    p.Material = Enum.Material.Neon; p.Color = color
    p.Transparency = 0.1; p.Parent = Workspace
    table.insert(boxParts, p); return p
end

local function localToWorld(lx, lz)
    if not anchor then return 0, 0 end
    local wp = anchor.CFrame:PointToWorldSpace(Vector3.new(lx, 0, lz))
    return wp.X, wp.Z
end

local function getCornerInFront()
    local char = LocalPlayer.Character; if not char then return 0, 0 end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return 0, 0 end
    if not anchor then return 0, 0 end
    local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
    local dist = math.max(_G.COLS, _G.ROWS) * _G.STEP * 0.6 + 2
    local cw = hrp.Position + look * dist
    local lp = anchor.CFrame:PointToObjectSpace(cw)
    local cx = math.round(lp.X / _G.STEP) * _G.STEP
    local cz = math.round(lp.Z / _G.STEP) * _G.STEP
    return cx - _G.COLS * _G.STEP / 2, cz - _G.ROWS * _G.STEP / 2
end

local function drawBox(cLX, cLZ, color)
    clearBox()
    if not anchor then return end
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    
    local BOX_W = math.max(2, _G.COLS - 1) * _G.STEP
    local BOX_D = math.max(2, _G.ROWS - 1) * _G.STEP
    local y = hrp.Position.Y - 0.9
    local wx1, wz1 = localToWorld(cLX, cLZ)
    local wx2, wz2 = localToWorld(cLX + BOX_W, cLZ)
    local wx3, wz3 = localToWorld(cLX + BOX_W, cLZ + BOX_D)
    local wx4, wz4 = localToWorld(cLX, cLZ + BOX_D)
    
    local c1 = Vector3.new(wx1, y, wz1)
    local c2 = Vector3.new(wx2, y, wz2)
    local c3 = Vector3.new(wx3, y, wz3)
    local c4 = Vector3.new(wx4, y, wz4)
    local edges = {{c1, c2}, {c2, c3}, {c3, c4}, {c4, c1}}
    
    for _, e in ipairs(edges) do
        local a, b = e[1], e[2]
        local mid = (a + b) / 2; local len = (b - a).Magnitude
        if len < 0.05 then continue end
        local p = makePart(color)
        p.Size = Vector3.new(len, 0.3, 0.3)
        p.CFrame = CFrame.new(mid, mid + (b - a).Unit) * CFrame.Angles(0, math.pi / 2, 0)
    end
    
    local floorMid = (c1 + c3) / 2
    local floor = makePart(color); floor.Size = Vector3.new(BOX_W, 0.05, BOX_D)
    floor.Transparency = 0.78
    local _, ry, _ = anchor.CFrame:ToEulerAnglesYXZ()
    floor.CFrame = CFrame.new(floorMid) * CFrame.Angles(0, ry, 0)
end

local function generateGrid(cLX, cLZ)
    local slots = {}
    for r = 0, _G.ROWS - 1 do
        for c = 0, _G.COLS - 1 do
            table.insert(slots, {localX = cLX + c * _G.STEP, localZ = cLZ + r * _G.STEP})
        end
    end
    return slots
end

local SelectionBoxEnabled = false
PlaceTab:CreateSection("Deployment")
PlaceTab:CreateToggle({
    Name = "👀 Show Glowing Selection Area",
    CurrentValue = false,
    Callback = function(v)
        SelectionBoxEnabled = v
        if not v then clearBox() end
    end
})

RunService.RenderStepped:Connect(function()
    if not anchor then return end
    if SelectionBoxEnabled and not _G.AutoPlacing then
        local cx, cz = getCornerInFront()
        drawBox(cx, cz, Color3.fromRGB(0, 200, 255))
    end
end)

PlaceTab:CreateToggle({
    Name = "🚀 Auto Place Missiles",
    CurrentValue = false,
    Callback = function(v)
        _G.AutoPlacing = v
        if v then
            task.spawn(function()
                local rSlots = getRocketSlots()
                if #rSlots == 0 then
                    Rayfield:Notify({Title = "Inventory Empty", Content = "No rockets found in your GUI inventory!", Duration = 3})
                    _G.AutoPlacing = false
                    if not SelectionBoxEnabled then clearBox() end
                    return
                end
                
                local cLX, cLZ = getCornerInFront()
                drawBox(cLX, cLZ, Color3.fromRGB(255, 220, 0)) -- Turn Box Yellow to indicate frozen/placing
                
                local gridSlots = generateGrid(cLX, cLZ)
                local total = #gridSlots
                local nextIdx = 1

                Rayfield:Notify({Title = "Placing Grid", Content = "Using intercepted anchor offsets!", Duration = 4})

                while _G.AutoPlacing and nextIdx <= total do
                    while nextIdx <= total and isOccupied(gridSlots[nextIdx].localX, gridSlots[nextIdx].localZ) do 
                        nextIdx = nextIdx + 1 
                    end
                    if nextIdx > total then break end

                    local invSlots = getRocketSlots()
                    if #invSlots == 0 then task.wait(0.5) continue end

                    local gs = gridSlots[nextIdx]
                    local inv = invSlots[1]

                    local ok = pcall(function()
                        PerformActionFunc:InvokeServer("PlaceOwnedItem", {
                            LocalX = gs.localX,
                            LocalZ = gs.localZ,
                                     Rotation = 0,
                            InventoryId = inv.id
                        })
                    end)
                    
                    if ok then 
                        nextIdx = nextIdx + 1
                        task.wait(0.08) 
                    else 
                        task.wait(0.3) 
                    end
                end
                
                _G.AutoPlacing = false
                if not SelectionBoxEnabled then clearBox() end
                Rayfield:Notify({Title = "Grid Complete", Content = "All available grid positions filled.", Duration = 4})
            end)
        else
            if not SelectionBoxEnabled then clearBox() end
        end
    end
})

---------------------------------------------------------------------------
-- TAB 5: TELEPORT & EXPLOITS
---------------------------------------------------------------------------
local TeleportTab = Window:CreateTab("⚡ Teleports & Exploits")

local function ServerHop()
    local PlaceId = game.PlaceId 
    local servers = {}
    local req = (syn and syn.request) or (http and http_request) or request or http_request
    if req then
        local success, res = pcall(function() 
            return req({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", PlaceId), Method = "GET"}) 
        end)
        if success and res and res.Body then
            local body = HttpService:JSONDecode(res.Body)
            if body and body.data then
                for _, v in ipairs(body.data) do
                    if v.playing and v.maxPlayers and v.playing < v.maxPlayers and v.id ~= game.JobId then 
                        table.insert(servers, v.id) 
                    end
                end
            end
        end
    end
    if #servers > 0 then 
        TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], LocalPlayer) 
    else 
        TeleportService:Teleport(PlaceId, LocalPlayer) 
    end
end

TeleportTab:CreateSection("Server Actions")
TeleportTab:CreateButton({ Name = "🔄 Server Hop", Callback = function() ServerHop() end })

TeleportTab:CreateSection("Player Locators")

local function getPlayerStats()
    local topPlayer, noobPlayer = nil, nil
    local topCash, bottomCash = -1, math.huge
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local stats = p:FindFirstChild("leaderstats")
            local cash = 0
            if stats then
                local moneyObj = stats:FindFirstChild("Cash") or stats:FindFirstChild("Money") or stats:FindFirstChild("Coins")
                if moneyObj then cash = moneyObj.Value end
            end
            
            if cash > topCash then
                topCash = cash
                topPlayer = p
            end
            if cash < bottomCash then
                bottomCash = cash
                noobPlayer = p
            end
        end
    end
    return topPlayer, noobPlayer
end

TeleportTab:CreateButton({
    Name = "💰 Teleport to Richest Player",
    Callback = function()
        local richData, _ = getPlayerStats()
        if richData and richData.Character and richData.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character then
            LocalPlayer.Character:PivotTo(richData.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5))
            Rayfield:Notify({Title = "Exploits", Content = "Teleported to " .. richData.Name .. "!", Duration = 3})
        else
            Rayfield:Notify({Title = "Error", Content = "Could not find a valid player.", Duration = 3})
        end
    end
})

TeleportTab:CreateButton({
    Name = "👶 Teleport to Noob (Beta)",
    Callback = function()
        local _, noobData = getPlayerStats()
        if noobData and noobData.Character and noobData.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character then
            LocalPlayer.Character:PivotTo(noobData.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5))
            Rayfield:Notify({Title = "Exploits", Content = "Teleported to the poorest player: " .. noobData.Name, Duration = 3})
        else
            Rayfield:Notify({Title = "Error", Content = "Could not find a valid player.", Duration = 3})
        end
    end
})

task.spawn(function() 
    pcall(function() 
        game:GetService("ReplicatedStorage"):WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("ConfirmCountrySelectionEvent"):FireServer("NONE") 
    end) 
end)
