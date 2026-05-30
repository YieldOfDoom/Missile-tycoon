local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

LocalPlayer:WaitForChild("RocketClient", 15)
local PerformActionFunc = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("PerformAction")
local ActionEvent = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("PerformActionEvent")
local FactoryEvent = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("FactoryCreateRocket")
local StorageAction = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("FactoryStorageAction")

local function runBuy(shop, def, req)
    ActionEvent:FireServer("BuyOwnedItem", {ShopIndex = shop, DefinitionId = def, RequestId = req})
end

local function getInventorySpacesAndStorage()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    local equippedCount = 0
    if backpack then for _, item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") then equippedCount = equippedCount + 1 end end end
    if character then for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") then equippedCount = equippedCount + 1 end end end
    
    local storageId = "1_" .. tostring(LocalPlayer.UserId) .. "_storage"
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name:lower():match("storage") then
            local ownerAttr = v:GetAttribute("Owner")
            if ownerAttr == LocalPlayer.Name or ownerAttr == nil then
                local realId = v:GetAttribute("InventoryId") or v:GetAttribute("ObjectId")
                if realId then storageId = realId break end
            end
        end
    end
    return math.max(0, 12 - equippedCount), storageId
end

local function runTakeRocket(rocketKey, count, targetStorage)
    pcall(function() StorageAction:InvokeServer("Take", rocketKey, count, targetStorage) end)
end

local function runCreateRocket(rocketId)
    pcall(function() FactoryEvent:FireServer(rocketId, 1) end)
end

local httpRequest = (syn and syn.request) or (http and http_request) or request or http_request
if httpRequest then
    local success, res = pcall(function() return httpRequest({Url = "https://vozex.in/status.php", Method = "GET"}) end)
    if not success or res.StatusCode ~= 200 then 
        warn("Vozex Network Verification failed or timed out. Proceeding...")
    end
else
    warn("Executor does not support standard HTTP requests. Bypassing check...")
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Missile Tycoon Daddy 🚀 | Sid",
    LoadingTitle = "New Update 🔥🎉",
    LoadingSubtitle = "Inventory Scan Engaged",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false 
})

local MainTab = Window:CreateTab("💣 Bombard", 4483362458)
_G.MySafeZone = nil
task.spawn(function()
    task.wait(2) 
    if LocalPlayer.Character and LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5) then
        _G.MySafeZone = LocalPlayer.Character.HumanoidRootPart.Position
        Rayfield:Notify({ Title = "SYSTEM SECURED", Content = "Your Base is Locked & Protected (600 Studs).", Duration = 3 })
    end
end)

MainTab:CreateSection("Automation War")
_G.SelectedPlayer = nil
local PlayerDropdown = MainTab:CreateDropdown({
    Name = "🎯 Select Target Player", Options = {"Loading..."},
    Callback = function(Option) _G.SelectedPlayer = Players:FindFirstChild(Option[1]) end,
})

local StatusLabel = MainTab:CreateLabel("Status: 💤 Idle")
local StatsLabel = MainTab:CreateLabel("Total Destroyed: 0")

_G.TotalDestroyed = 0
local TargetedInstances = {}
local FoundRockets, FoundBuildings = {}, {}
_G.FiredRocketsTracker = {} 
_G.WarInProgress = false

local function DeepScan()
    table.clear(FoundRockets)
    table.clear(FoundBuildings)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or not _G.SelectedPlayer then return end
    local enemyChar = _G.SelectedPlayer.Character and _G.SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    local function ScanContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
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
    if not _G.SelectedPlayer then return Rayfield:Notify({Title="Error", Content="Please select a target player first!", Duration=3}) end
    if not _G.MySafeZone then return Rayfield:Notify({Title="Wait!", Content="Base Auto-Securing...", Duration=2}) end
    if _G.WarInProgress then return end
    
    _G.WarInProgress = true
    StatusLabel:Set("Status: ⚔️ WAR (CONTINUOUS FIRING)")

    task.spawn(function()
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        while _G.WarInProgress do
            DeepScan() 
            local total = #FoundRockets
            if total > 0 and #FoundBuildings > 0 and _G.SelectedPlayer then
                local limit = isBulk and total or math.min(total, 5)
                for i = 1, limit do
                    if not _G.WarInProgress then break end
                    local t = FoundBuildings[math.random(1, #FoundBuildings)]
                    local itemData = FoundRockets[i]
                    local mId = itemData.ID
                    _G.FiredRocketsTracker[mId] = true 
                    
                    if itemData.IsTool and itemData.InstanceRef.Parent == LocalPlayer:FindFirstChild("Backpack") and humanoid then
                        humanoid:EquipTool(itemData.InstanceRef)
                        task.wait(0.02)
                    end
                    
                    task.spawn(function()
                        pcall(function() 
                            ActionEvent:FireServer("LaunchRocket", {
                                ["WarConfirmed"] = true, ["TargetZ"] = t.Pos.Z, ["ObjectId"] = mId, ["TargetX"] = t.Pos.X, ["TargetY"] = t.Pos.Y
                            }) 
                            TargetedInstances[t.Instance] = true
                        end)
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

MainTab:CreateButton({ Name = "🚀 ATTACK BULK (CONTINUOUS)", Callback = function() TriggerAttack(true) end })
MainTab:CreateButton({ Name = "🎯 ATTACK NORMAL (CONTINUOUS)", Callback = function() TriggerAttack(false) end })
MainTab:CreateButton({ Name = "🛑 STOP WAR", Callback = function() _G.WarInProgress = false StatusLabel:Set("Status: 💤 Idle") end })

Workspace.DescendantAdded:Connect(function(v)
    if v:IsA("Model") or v:IsA("BasePart") then
        local id = v.Name:match("^%d+_%d+_%d+") or v:GetAttribute("ObjectId")
        if id and _G.FiredRocketsTracker[id] then
            local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
            if part then
                local attach = Instance.new("Attachment", part)
                local smoke = Instance.new("ParticleEmitter")
                smoke.Color = ColorSequence.new(Color3.fromRGB(0, 150, 255)) 
                smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0)})
                smoke.Texture = "rbxassetid://243660364"
                smoke.EmissionDirection = Enum.NormalId.Back
                smoke.Rate = 600
                smoke.Lifetime = NumberRange.new(0.6, 1.2)
                smoke.Speed = NumberRange.new(0)
                smoke.Parent = attach
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        local list = {}
        for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(list, p.Name) end end
        if #list == 0 then list = {"Waiting for Players..."} end
        pcall(function() PlayerDropdown:Refresh(list, true) end)
        
        for inst, _ in pairs(TargetedInstances) do
            if not inst or not inst.Parent then
                _G.TotalDestroyed = _G.TotalDestroyed + 1
                TargetedInstances[inst] = nil
                StatsLabel:Set("Total Destroyed: " .. _G.TotalDestroyed)
            end
        end
    end
end)

local BuyTab = Window:CreateTab("🟢 Buy Building")

BuyTab:CreateSection("Auto Buy Settings")
BuyTab:CreateToggle({
    Name = "✅ Auto Buy All Buildings",
    CurrentValue = false,
    Callback = function(Value)
        _G.AutoBuyAll = Value
        task.spawn(function()
            while _G.AutoBuyAll do
                runBuy(4, "tier1_bluebird_house", "4ba44f86-7657-484e-a806-0d096a7d833f")
                runBuy(5, "tier1_sunset_villa", "3285b2b4-b532-46e5-a0c9-7d8d3c98f766")
                runBuy(6, "tier1_corner_market", "fa99511d-1096-4399-b5a9-b8b5f5a88366")
                runBuy(8, "tier2_seaside_motel", "2eb37bb4-945f-4261-8230-6d8e5e62c231")
                runBuy(9, "tier2_metro_bank", "611cdf19-7bda-4c06-9c86-86bebc6dfd17")
                runBuy(10, "tier2_boutique_hotel", "160dadfe-954e-4daf-abd1-1b3cf1c0d787")
                runBuy(11, "tier2_arcade_cash_hub", "cdd533cb-a81d-439d-b5cd-99a7fbd9ce0e")
                runBuy(12, "tier3_resort_residence", "d6c0688c-f6ac-49fa-8479-01e9dc479a63")
                runBuy(14, "tier3_exchange_tower", "dfe54660-b975-488e-8f38-dff692003666")
                runBuy(13, "tier3_grand_hotel_tower", "0c266ea6-e7e3-4b9a-8faa-5eeeeac68873")
                runBuy(15, "bank", "2acf3608-d959-459e-9295-e6fcd9dbefc9")
                runBuy(16, "factory", "1b2b2703-b6e3-4e2c-a726-d56829480434")
                runBuy(17, "building_new1", "07b5849a-dfcf-4054-aebd-8f71fd3922b9")
                runBuy(18, "building_new2", "eeed637e-c736-4d28-b01a-c6c0bbfa3c8a")
                task.wait(2)
            end
        end)
    end
})

local Buildings = {
    {Name = "Bluebird House", Shop = 4, Def = "tier1_bluebird_house", Req = "4ba44f86-7657-484e-a806-0d096a7d833f"},
    {Name = "Sunset Villa", Shop = 5, Def = "tier1_sunset_villa", Req = "3285b2b4-b532-46e5-a0c9-7d8d3c98f766"},
    {Name = "Corner Market", Shop = 6, Def = "tier1_corner_market", Req = "fa99511d-1096-4399-b5a9-b8b5f5a88366"},
    {Name = "Seaside Motel", Shop = 8, Def = "tier2_seaside_motel", Req = "2eb37bb4-945f-4261-8230-6d8e5e62c231"},
    {Name = "Metro Bank", Shop = 9, Def = "tier2_metro_bank", Req = "611cdf19-7bda-4c06-9c86-86bebc6dfd17"},
    {Name = "Boutique Hotel", Shop = 10, Def = "tier2_boutique_hotel", Req = "160dadfe-954e-4daf-abd1-1b3cf1c0d787"},
    {Name = "Arcade Cash Hub", Shop = 11, Def = "tier2_arcade_cash_hub", Req = "cdd533cb-a81d-439d-b5cd-99a7fbd9ce0e"},
    {Name = "Resort Residence", Shop = 12, Def = "tier3_resort_residence", Req = "d6c0688c-f6ac-49fa-8479-01e9dc479a63"},
    {Name = "Exchange Tower", Shop = 14, Def = "tier3_exchange_tower", Req = "dfe54660-b975-488e-8f38-dff692003666"},
    {Name = "Grand Hotel Tower", Shop = 13, Def = "tier3_grand_hotel_tower", Req = "0c266ea6-e7e3-4b9a-8faa-5eeeeac68873"},
    {Name = "Bank", Shop = 15, Def = "bank", Req = "2acf3608-d959-459e-9295-e6fcd9dbefc9"},
    {Name = "Factory", Shop = 16, Def = "factory", Req = "1b2b2703-b6e3-4e2c-a726-d56829480434"},
    {Name = "Satellite Station", Shop = 17, Def = "building_new1", Req = "07b5849a-dfcf-4054-aebd-8f71fd3922b9"},
    {Name = "Nuclear Facility", Shop = 18, Def = "building_new2", Req = "eeed637e-c736-4d28-b01a-c6c0bbfa3c8a"}
}

for _, b in pairs(Buildings) do
    BuyTab:CreateToggle({
        Name = b.Name, CurrentValue = false,
        Callback = function(Value)
            _G[b.Def] = Value
            if _G[b.Def] then
                task.spawn(function()
                    while _G[b.Def] do runBuy(b.Shop, b.Def, b.Req) task.wait(2) end
                end)
            end
        end
    })
end
local MilitaryTab = Window:CreateTab("🟢 Buy Military")
MilitaryTab:CreateSection("Auto Buy Settings")
MilitaryTab:CreateToggle({
    Name = "✅ Auto Buy All Military", CurrentValue = false,
    Callback = function(Value)
        _G.AutoBuyMilitary = Value
        if _G.AutoBuyMilitary then
            task.spawn(function()
                while _G.AutoBuyMilitary do
                    runBuy(19, "launcher_rockets1", "530adf75-38d5-42b1-96b1-33c4b45a19d3")
                    runBuy(3, "factory1", "9afde573-952b-4afc-8541-f41b384d97b4")
                    runBuy(2, "storage", "eb4263e8-eccd-4136-bc34-b494eef0b9d3")
                    task.wait(3)
                end
            end)
        end
    end
})

local MilitaryItems = {
    {Name = "Launcher Rockets 1", Shop = 19, Def = "launcher_rockets1", Req = "530adf75-38d5-42b1-96b1-33c4b45a19d3"},
    {Name = "Factory 1", Shop = 3, Def = "factory1", Req = "9afde573-952b-4afc-8541-f41b384d97b4"},
    {Name = "Storage", Shop = 2, Def = "storage", Req = "eb4263e8-eccd-4136-bc34-b494eef0b9d3"}
}

for _, m in pairs(MilitaryItems) do
    MilitaryTab:CreateToggle({
        Name = m.Name, CurrentValue = false,
        Callback = function(Value)
            _G[m.Def] = Value
            if _G[m.Def] then
                task.spawn(function()
                    while _G[m.Def] do runBuy(m.Shop, m.Def, m.Req) task.wait(3) end
                end)
            end
        end
    })
end

local MissileTab = Window:CreateTab("🟢 Create Missile")

local Missiles = {
    {Name = "Firefly Rocket", ID = "firefly_rocket"}, {Name = "Viper Cruise Rocket", ID = "viper_cruise_rocket"},
    {Name = "Hammer Ballistic", ID = "hammer_ballistic_rocket"}, {Name = "Titan Strike", ID = "rocket4"},
    {Name = "Crimson Strike", ID = "rocket5"}, {Name = "Golden Lance", ID = "rocket6"},
    {Name = "Leviathan Siege", ID = "rocket7"}, {Name = "Titan Fang", ID = "rocket8"}, {Name = "Shadow Viper", ID = "rocket9"}
}

MissileTab:CreateSection("Auto Create Settings")
MissileTab:CreateToggle({
    Name = "🎲 Make Random Missile", CurrentValue = false,
    Callback = function(Value)
        _G.AutoRandomMissile = Value
        if _G.AutoRandomMissile then
            task.spawn(function()
                while _G.AutoRandomMissile do
                    local randomMissile = Missiles[math.random(1, #Missiles)].ID
                    runCreateRocket(randomMissile)
                    task.wait(0.2)
                end
            end)
        end
    end
})

for _, m in ipairs(Missiles) do
    MissileTab:CreateToggle({
        Name = "Create " .. m.Name, CurrentValue = false,
        Callback = function(Value)
            local toggleKey = "Create_" .. m.ID
            _G[toggleKey] = Value
            if _G[toggleKey] then
                task.spawn(function()
                    while _G[toggleKey] do runCreateRocket(m.ID) task.wait(0.2) end
                end)
            end
        end
    })
end

local TakeTab = Window:CreateTab("🟢 Take Rocket")

local TakeMissiles = {
    {Name = "Firefly Rocket", ID = "Rocket1"}, {Name = "Viper Cruise Rocket", ID = "Rocket2"},
    {Name = "Hammer Ballistic", ID = "Rocket3"}, {Name = "Titan Strike", ID = "Rocket4"},
    {Name = "Crimson Strike", ID = "Rocket5"}, {Name = "Golden Lance", ID = "Rocket6"},
    {Name = "Leviathan Siege", ID = "rocket7"}, {Name = "Titan Fang", ID = "rocket8"}, {Name = "Shadow Viper", ID = "rocket9"}
}

TakeTab:CreateSection("Auto Take Settings")
TakeTab:CreateToggle({
    Name = "✅ Auto Take All Missiles", CurrentValue = false,
    Callback = function(Value)
        _G.AutoTakeAll = Value
        if _G.AutoTakeAll then
            task.spawn(function()
                while _G.AutoTakeAll do
                    local slots, storageId = getInventorySpacesAndStorage()
                    if slots > 0 then runTakeRocket(TakeMissiles[math.random(1, #TakeMissiles)].ID, 1, storageId) end
                    task.wait(0.2)
                end
            end)
        end
    end
})

for _, m in pairs(TakeMissiles) do
    TakeTab:CreateToggle({
        Name = "Take " .. m.Name, CurrentValue = false,
        Callback = function(Value)
            local toggleKey = "Take_" .. m.ID
            _G[toggleKey] = Value
            if _G[toggleKey] then
                task.spawn(function()
                    while _G[toggleKey] do
                        local slots, storageId = getInventorySpacesAndStorage()
                        if slots > 0 then runTakeRocket(m.ID, slots, storageId) end
                        task.wait(1.5)
                    end
                end)
            end
        end
    })
end

local PlaceTab = Window:CreateTab("🔥Auto Place Missiles")

_G.AutoLoop = false
local UsedIDs = {}

PlaceTab:CreateToggle({
    Name = "🚀 Start 20/Row Auto-Grid",
    CurrentValue = false,
    Callback = function(Value)
        _G.AutoLoop = Value
        
        if _G.AutoLoop then
            task.spawn(function()
                local count = 0
                local MaxPerRow = 20
                local StartX = 161.25
                local StartZ = -163.5
                local Spacing = 3.5

                while _G.AutoLoop do
                    pcall(function()
                        StorageAction:InvokeServer("Take", "Rocket1", 1, "1_1780132496857_307606")
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

                    if currentId then
                        local row = math.floor(count / MaxPerRow)
                        local col = count % MaxPerRow
                        
                        local targetX = StartX - (col * Spacing)
                        local targetZ = StartZ + (row * Spacing) 

                        pcall(function()
                            PerformActionFunc:InvokeServer("PlaceOwnedItem", {
                                LocalZ = targetZ,
                                InventoryId = currentId,
                                LocalX = targetX,
                                Rotation = 0
                            })
                        end)

                        UsedIDs[currentId] = true
                        count = count + 1
                    end

                    task.wait(0.2) 
                end
            end)
        else
            UsedIDs = {} 
        end
    end
})

local TeleportTab = Window:CreateTab("Teleporter ⚡")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

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

local function GetCash(plr)
    if plr and plr:FindFirstChild("leaderstats") then
        if plr.leaderstats:FindFirstChild("Cash") then return plr.leaderstats.Cash.Value end
        if plr.leaderstats:FindFirstChild("Money") then return plr.leaderstats.Money.Value end
    end
    return 0
end

local function GetBuildingsCount(plr) 
    if plr and plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Buildings") then 
        return plr.leaderstats.Buildings.Value 
    end 
    return 0 
end

TeleportTab:CreateSection("Quick Actions")
TeleportTab:CreateButton({ Name = "🔄 Teleport to New Server", Callback = function() ServerHop() end })

TeleportTab:CreateSection("Rich Player Bypass (Beta)")
_G.RichBypassEnabled, _G.RichBypassLimit = false, 500000000000
TeleportTab:CreateToggle({ Name = "🛡️ Enable Rich Player Bypass", CurrentValue = false, Callback = function(Value) _G.RichBypassEnabled = Value end })
TeleportTab:CreateSlider({
    Name = "Rich Limit (1M to 1 Trillion)", Range = {1, 1000000}, Increment = 1, Suffix = " M", CurrentValue = 500000, Flag = "RichBypassSlider", 
    Callback = function(Value) _G.RichBypassLimit = Value * 1000000 end,
})
TeleportTab:CreateInput({ Name = "Custom Bypass Value (Lock & Edit)", PlaceholderText = "Enter exact number", RemoveTextAfterFocusLost = false, Callback = function(Text) local num = tonumber(Text) if num then _G.RichBypassLimit = num end end })

TeleportTab:CreateSection("Noob Hunter & Auto War")
_G.FindNoobsEnabled, _G.FindNoobsTargetValue, _G.AutoDeclareWarOnNoob = false, 1000000, false
TeleportTab:CreateToggle({ Name = "🔍 Find Noobs", CurrentValue = false, Callback = function(Value) _G.FindNoobsEnabled = Value end })
TeleportTab:CreateInput({ Name = "Find Noobs Value (Below this)", PlaceholderText = "Enter value", RemoveTextAfterFocusLost = false, Callback = function(Text) local num = tonumber(Text) if num then _G.FindNoobsTargetValue = num end end })
TeleportTab:CreateToggle({ Name = "⚔️ Auto Declare War on Noobs (Beta)", CurrentValue = false, Callback = function(Value) _G.AutoDeclareWarOnNoob = Value end })

task.spawn(function()
    while task.wait(5) do
        local triggerHop = false
        if _G.RichBypassEnabled then
            for _, p in pairs(game:GetService("Players"):GetPlayers()) do if p ~= LocalPlayer and GetCash(p) >= _G.RichBypassLimit then triggerHop = true break end end
        end
        if _G.FindNoobsEnabled and not triggerHop then
            local foundNoob = false
            for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                if p ~= LocalPlayer then
                    if GetCash(p) <= _G.FindNoobsTargetValue and GetBuildingsCount(p) < 20 then
                        foundNoob = true
                        if _G.AutoDeclareWarOnNoob and _G.SelectedPlayer ~= p then
                            _G.SelectedPlayer = p
                        end
                        break
                    end
                end
            end
            if not foundNoob and #game:GetService("Players"):GetPlayers() > 1 then triggerHop = true end
        end
        if triggerHop then ServerHop() task.wait(10) end
    end
end)

task.spawn(function() pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("CityBuilderRockets"):WaitForChild("Remotes"):WaitForChild("ConfirmCountrySelectionEvent"):FireServer("NONE") end) end)