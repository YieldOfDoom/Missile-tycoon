local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

LocalPlayer:WaitForChild("RocketClient", 15)
local CBR = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes")
local PerformActionFunc = CBR:WaitForChild("PerformAction")
local ActionEvent = CBR:WaitForChild("PerformActionEvent")
local FactoryEvent = CBR:WaitForChild("FactoryCreateRocket")
local StorageAction = CBR:WaitForChild("FactoryStorageAction")

-- Core Functions
local function runBuy(shop, def, req)
    pcall(function() ActionEvent:FireServer("BuyOwnedItem", {ShopIndex = shop, DefinitionId = def, RequestId = req}) end)
end

local function getInventorySpacesAndStorage()
    local backpack, char = LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character
    local equipped = 0
    if backpack then for _, i in ipairs(backpack:GetChildren()) do if i:IsA("Tool") then equipped = equipped + 1 end end end
    if char then for _, i in ipairs(char:GetChildren()) do if i:IsA("Tool") then equipped = equipped + 1 end end end
    
    local storageId = "1_" .. tostring(LocalPlayer.UserId) .. "_storage"
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name:lower():match("storage") then
            if v:GetAttribute("Owner") == LocalPlayer.Name or v:GetAttribute("Owner") == nil then
                storageId = v:GetAttribute("InventoryId") or v:GetAttribute("ObjectId") or storageId
                break
            end
        end
    end
    return math.max(0, 12 - equipped), storageId
end

local function runTakeRocket(rocketKey, count, targetStorage)
    pcall(function() StorageAction:InvokeServer("Take", rocketKey, count, targetStorage) end)
end

local function runCreateRocket(rocketId)
    pcall(function() FactoryEvent:FireServer(rocketId, 1) end)
end

-- UI Setup
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Missile Tycoon Daddy 🚀 | Sid",
    LoadingTitle = "System Restored 🔥",
    LoadingSubtitle = "Unified Script Running",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false 
})

---------------------------------------------------------------------------
-- TAB 1: BOMBARD / WAR
---------------------------------------------------------------------------
local MainTab = Window:CreateTab("💣 Bombard", 4483362458)
_G.MySafeZone = nil
task.spawn(function()
    task.wait(2) 
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
                        hum:EquipTool(FoundRockets[i].InstanceRef) task.wait(0.02)
                    end
                    task.spawn(function()
                        pcall(function() ActionEvent:FireServer("LaunchRocket", {WarConfirmed = true, TargetZ = t.Pos.Z, ObjectId = mId, TargetX = t.Pos.X, TargetY = t.Pos.Y}) TargetedInstances[t.Instance] = true end)
                    end)
                    task.wait(0.15) 
                end
            else
                task.wait(0.5)
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
    while task.wait(1) do
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
-- TAB 2: BUYING AND TAKING (FIXED SCOPE)
---------------------------------------------------------------------------
local BuyTab = Window:CreateTab("🟢 Auto Purchases")

-- Format: {Name, ShopIndex, DefinitionId, RequestId}
local AllBuildings = {
    {"Bluebird House", 4, "tier1_bluebird_house", "4ba44f86-7657-484e-a806-0d096a7d833f"},
    {"Sunset Villa", 5, "tier1_sunset_villa", "3285b2b4-b532-46e5-a0c9-7d8d3c98f766"},
    {"Corner Market", 6, "tier1_corner_market", "fa99511d-1096-4399-b5a9-b8b5f5a88366"},
    {"Seaside Motel", 8, "tier2_seaside_motel", "2eb37bb4-945f-4261-8230-6d8e5e62c231"},
    {"Metro Bank", 9, "tier2_metro_bank", "611cdf19-7bda-4c06-9c86-86bebc6dfd17"},
    {"Boutique Hotel", 10, "tier2_boutique_hotel", "160dadfe-954e-4daf-abd1-1b3cf1c0d787"},
    {"Arcade Cash Hub", 11, "tier2_arcade_cash_hub", "cdd533cb-a81d-439d-b5cd-99a7fbd9ce0e"},
    {"Resort Residence", 12, "tier3_resort_residence", "d6c0688c-f6ac-49fa-8479-01e9dc479a63"},
    {"Exchange Tower", 14, "tier3_exchange_tower", "dfe54660-b975-488e-8f38-dff692003666"},
    {"Grand Hotel Tower", 13, "tier3_grand_hotel_tower", "0c266ea6-e7e3-4b9a-8faa-5eeeeac68873"},
    {"Bank", 15, "bank", "2acf3608-d959-459e-9295-e6fcd9dbefc9"},
    {"Factory", 16, "factory", "1b2b2703-b6e3-4e2c-a726-d56829480434"},
    {"Satellite Station", 17, "building_new1", "07b5849a-dfcf-4054-aebd-8f71fd3922b9"},
    {"Nuclear Facility", 18, "building_new2", "eeed637e-c736-4d28-b01a-c6c0bbfa3c8a"}
}

local AllMilitary = {
    {"Launcher Rockets 1", 19, "launcher_rockets1", "530adf75-38d5-42b1-96b1-33c4b45a19d3"},
    {"Factory 1", 3, "factory1", "9afde573-952b-4afc-8541-f41b384d97b4"},
    {"Storage", 2, "storage", "eb4263e8-eccd-4136-bc34-b494eef0b9d3"}
}

BuyTab:CreateSection("Auto Buy Everything")
BuyTab:CreateToggle({Name = "✅ Auto Buy ALL Buildings", CurrentValue = false, Callback = function(V)
    _G.BuyAllBuilds = V
    if V then task.spawn(function() while _G.BuyAllBuilds do for _, b in ipairs(AllBuildings) do runBuy(b[2], b[3], b[4]) end task.wait(2) end end) end
end})

BuyTab:CreateToggle({Name = "✅ Auto Buy ALL Military", CurrentValue = false, Callback = function(V)
    _G.BuyAllMil = V
    if V then task.spawn(function() while _G.BuyAllMil do for _, m in ipairs(AllMilitary) do runBuy(m[2], m[3], m[4]) end task.wait(2) end end) end
end})

BuyTab:CreateSection("Individual Military")
for _, m in ipairs(AllMilitary) do
    BuyTab:CreateToggle({Name = "Buy " .. m[1], CurrentValue = false, Callback = function(V)
        _G["Buy_"..m[3]] = V
        if V then task.spawn(function() while _G["Buy_"..m[3]] do runBuy(m[2], m[3], m[4]) task.wait(2.5) end end) end
    end})
end

BuyTab:CreateSection("Individual Buildings")
for _, b in ipairs(AllBuildings) do
    BuyTab:CreateToggle({Name = "Buy " .. b[1], CurrentValue = false, Callback = function(V)
        _G["Buy_"..b[3]] = V
        if V then task.spawn(function() while _G["Buy_"..b[3]] do runBuy(b[2], b[3], b[4]) task.wait(2.5) end end) end
    end})
end

---------------------------------------------------------------------------
-- TAB 3: MISSILES (CREATE & TAKE)
---------------------------------------------------------------------------
local MissileTab = Window:CreateTab("🚀 Missiles")

local MissileTypes = {
    {"Firefly Rocket", "firefly_rocket", "Rocket1"}, {"Viper Cruise", "viper_cruise_rocket", "Rocket2"},
    {"Hammer Ballistic", "hammer_ballistic_rocket", "Rocket3"}, {"Titan Strike", "rocket4", "Rocket4"},
    {"Crimson Strike", "rocket5", "Rocket5"}, {"Golden Lance", "rocket6", "rocket6"},
    {"Leviathan Siege", "rocket7", "rocket7"}, {"Titan Fang", "rocket8", "rocket8"}, {"Shadow Viper", "rocket9", "rocket9"}
}

MissileTab:CreateSection("Auto Create Factory")
MissileTab:CreateToggle({Name = "🎲 Make Random Missile", CurrentValue = false, Callback = function(V)
    _G.RandMissile = V
    if V then task.spawn(function() while _G.RandMissile do runCreateRocket(MissileTypes[math.random(1, #MissileTypes)][2]) task.wait(0.2) end end) end
end})

for _, m in ipairs(MissileTypes) do
    MissileTab:CreateToggle({Name = "Create " .. m[1], CurrentValue = false, Callback = function(V)
        _G["Make_"..m[2]] = V
        if V then task.spawn(function() while _G["Make_"..m[2]] do runCreateRocket(m[2]) task.wait(0.2) end end) end
    end})
end

MissileTab:CreateSection("Auto Take Storage")
MissileTab:CreateToggle({Name = "✅ Auto Take ALL Missiles", CurrentValue = false, Callback = function(V)
    _G.TakeAllM = V
    if V then task.spawn(function() while _G.TakeAllM do
        local spaces, sId = getInventorySpacesAndStorage()
        if spaces > 0 then runTakeRocket(MissileTypes[math.random(1, #MissileTypes)][3], 1, sId) end
        task.wait(0.2)
    end end) end
end})

for _, m in ipairs(MissileTypes) do
    MissileTab:CreateToggle({Name = "Take " .. m[1], CurrentValue = false, Callback = function(V)
        _G["Take_"..m[3]] = V
        if V then task.spawn(function() while _G["Take_"..m[3]] do
            local spaces, sId = getInventorySpacesAndStorage()
            if spaces > 0 then runTakeRocket(m[3], spaces, sId) end
            task.wait(1.5)
        end end) end
    end})
end

---------------------------------------------------------------------------
-- TAB 4: GLOWING AUTO-PLACE GRID
---------------------------------------------------------------------------
local PlaceTab = Window:CreateTab("🔥 Auto Place")

local GridWidth = 30
local GridDepth = 30
local GridSpacing = 3.5

PlaceTab:CreateSection("Dynamic Grid Size (Follows You)")
PlaceTab:CreateSlider({Name = "Grid Width (Left/Right)", Range = {10, 100}, Increment = 5, Suffix = " studs", CurrentValue = 30, Callback = function(V) GridWidth = V end})
PlaceTab:CreateSlider({Name = "Grid Depth (Forward)", Range = {10, 100}, Increment = 5, Suffix = " studs", CurrentValue = 30, Callback = function(V) GridDepth = V end})
PlaceTab:CreateSlider({Name = "Packing Spacing", Range = {2.5, 15}, Increment = 0.5, Suffix = " studs", CurrentValue = 3.5, Callback = function(V) GridSpacing = V end})

local ViewPart, ViewBox, ViewRender = nil, nil, nil

PlaceTab:CreateToggle({
    Name = "👀 Show Glowing Selection Area",
    CurrentValue = false,
    Callback = function(Val)
        if Val then
            if ViewRender then ViewRender:Disconnect() end
            if ViewPart then ViewPart:Destroy() end

            -- GLOWING NEON BOX CONFIGURATION
            ViewPart = Instance.new("Part")
            ViewPart.Material = Enum.Material.Neon
            ViewPart.Color = Color3.fromRGB(255, 0, 0)
            ViewPart.Transparency = 0.6 -- Bright but slightly see-through
            ViewPart.Anchored = true
            ViewPart.CanCollide = false
            ViewPart.CastShadow = false
            ViewPart.Parent = Workspace

            ViewBox = Instance.new("SelectionBox")
            ViewBox.Color3 = Color3.fromRGB(255, 255, 255) -- White edge outline to pop
            ViewBox.LineThickness = 0.1
            ViewBox.Adornee = ViewPart
            ViewBox.Parent = ViewPart

            -- DYNAMICALLY FOLLOWS PLAYER POSITION & ROTATION
            ViewRender = RunService.RenderStepped:Connect(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- Size of the box
                    ViewPart.Size = Vector3.new(GridWidth, 0.5, GridDepth)
                    
                    -- Puts the box exactly in front of the player, matching their rotation
                    -- Down Y by half char height so it rests on floor. Forward Z by half depth + 5 studs gap.
                    local verticalOffset = (LocalPlayer.Character:FindFirstChild("LeftLeg") or LocalPlayer.Character:FindFirstChild("LeftFoot") and 3) or 2.5
                    local localOffset = CFrame.new(0, -verticalOffset + 0.25, -(GridDepth/2) - 5)
                    
                    -- To lock orientation flat to ground even if player looks up/down
                    local flatCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
                    ViewPart.CFrame = flatCFrame * localOffset
                end
            end)
        else
            if ViewRender then ViewRender:Disconnect() ViewRender = nil end
            if ViewPart then ViewPart:Destroy() ViewPart = nil end
        end
    end
})

_G.AutoLoopGrid = false
local UsedIDs = {}

PlaceTab:CreateToggle({
    Name = "🚀 Start Following Auto-Grid",
    CurrentValue = false,
    Callback = function(Value)
        _G.AutoLoopGrid = Value
        if _G.AutoLoopGrid then
            task.spawn(function()
                local count = 0
                while _G.AutoLoopGrid do
                    -- Keeps pulling items out to keep hand full
                    pcall(function()
                        local _, sId = getInventorySpacesAndStorage()
                        StorageAction:InvokeServer("Take", "Rocket1", 1, sId)
                    end)
                    task.wait(0.1) 

                    local currentId = nil
                    for _, obj in pairs(getgc(true)) do
                        if type(obj) == "table" and rawget(obj, "InventoryId") then
                            local foundId = obj.InventoryId
                            if type(foundId) == "string" and not UsedIDs[foundId] then
                                currentId = foundId
                                break
                            end
                        end
                    end

                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if currentId and hrp then
                        local MaxPerRow = math.max(1, math.floor(GridWidth / GridSpacing))
                        local row = math.floor(count / MaxPerRow)
                        local col = count % MaxPerRow
                        
                        -- Calculates placement inside the local moving box
                        local localX = (GridWidth/2) - (col * GridSpacing) - (GridSpacing/2)
                        local localZ = -5 - (GridSpacing/2) - (row * GridSpacing) 
                        
                        -- Converts that local math into exact world coordinate targeting
                        local flatCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
                        local worldTarget = flatCFrame * CFrame.new(localX, 0, localZ)

                        -- Limits depth so it doesn't build forever out of the box
                        if math.abs(localZ) <= (GridDepth + 5) then
                            pcall(function()
                                PerformActionFunc:InvokeServer("PlaceOwnedItem", {
                                    LocalZ = worldTarget.Z,
                                    InventoryId = currentId,
                                    LocalX = worldTarget.X,
                                    Rotation = 0
                                })
                            end)
                            UsedIDs[currentId] = true
                            count = count + 1
                        else
                            -- Reset grid count if they walk to keep building endlessly
                            count = 0 
                        end
                    end
                    task.wait(0.15) 
                end
            end)
        else
            UsedIDs = {} 
        end
    end
})

-----------------------------------------
---------------------------------------------------------------------------
-- TAB 5: TELEPORT & EXPLOITS
---------------------------------------------------------------------------
local TeleportTab = Window:CreateTab("⚡ Teleporter", 4483362458)

local function ServerHop()
    local PlaceId = game.PlaceId local servers = {}
    local req = (syn and syn.request) or (http and http_request) or request or http_request
    if req then
        local success, res = pcall(function() return req({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", PlaceId), Method = "GET"}) end)
        if success and res and res.Body then
            local body = HttpService:JSONDecode(res.Body)
            if body and body.data then
                for _, v in ipairs(body.data) do
                    if v.playing and v.maxPlayers and v.playing < v.maxPlayers and v.id ~= game.JobId then table.insert(servers, v.id) end
                end
            end
        end
    end
    if #servers > 0 then TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], LocalPlayer) else TeleportService:Teleport(PlaceId, LocalPlayer) end
end

TeleportTab:CreateSection("Server Actions")
TeleportTab:CreateButton({ Name = "🔄 Server Hop", Callback = function() ServerHop() end })

task.spawn(function() pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("ConfirmCountrySelectionEvent"):FireServer("NONE") end) end)

print("Missile Tycoon Fully Restored & Linked!")

