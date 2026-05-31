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

local CBR = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes")
local PerformActionFunc = CBR:WaitForChild("PerformAction")
local ActionEvent = CBR:WaitForChild("PerformActionEvent")
local FactoryEvent = CBR:WaitForChild("FactoryCreateRocket")
local StorageAction = CBR:WaitForChild("FactoryStorageAction")

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

MissileTab:CreateSection("Auto Create & Take")
MissileTab:CreateToggle({Name = "🎲 Make Random Missile", CurrentValue = false, Callback = function(V)
    _G.RandMissile = V
    if V then task.spawn(function() while _G.RandMissile do runCreateRocket(MissileTypes[math.random(1, #MissileTypes)][2]) task.wait(0.05) end end) end
end})

MissileTab:CreateToggle({Name = "✅ Auto Take ALL Missiles", CurrentValue = false, Callback = function(V)
    _G.TakeAllM = V
    if V then task.spawn(function() while _G.TakeAllM do
        local spaces, sId = getInventorySpacesAndStorage()
        if spaces > 0 then runTakeRocket(MissileTypes[math.random(1, #MissileTypes)][3], 1, sId) end
        task.wait(0.05)
    end end) end
end})
---------------------------------------------------------------------------
-- TAB 4: THE ULTIMATE AUTO-PLACE (REMOTE MATH + EAGLE SCANNER)
---------------------------------------------------------------------------
local PlaceTab = Window:CreateTab("🔥 Auto Place")

local GridWidth = 30
local GridDepth = 30
local GridSpacing = 3.5
local GridRotation = 0 

-- Exactly matches your manual math to convert World CFrame to Tycoon LocalX/LocalZ
_G.PlotXOffset = 375 
_G.PlotZOffset = 309 

PlaceTab:CreateSection("Tycoon Plot Settings (Coordinate Fix)")
PlaceTab:CreateLabel("Subtracts world space to fire accurate LocalX/LocalZ.")
PlaceTab:CreateInput({Name = "Tycoon Base X (Default 375)", CurrentValue = "375", Flag = "PlotX", Callback = function(Text) _G.PlotXOffset = tonumber(Text) or 375 end})
PlaceTab:CreateInput({Name = "Tycoon Base Z (Default 309)", CurrentValue = "309", Flag = "PlotZ", Callback = function(Text) _G.PlotZOffset = tonumber(Text) or 309 end})

PlaceTab:CreateSection("Dynamic Grid Settings")
PlaceTab:CreateSlider({Name = "Grid Width (Left/Right)", Range = {10, 100}, Increment = 5, Suffix = " studs", CurrentValue = 30, Callback = function(V) GridWidth = V end})
PlaceTab:CreateSlider({Name = "Grid Depth (Forward)", Range = {10, 100}, Increment = 5, Suffix = " studs", CurrentValue = 30, Callback = function(V) GridDepth = V end})
PlaceTab:CreateSlider({Name = "Packing Spacing", Range = {2.5, 15}, Increment = 0.5, Suffix = " studs", CurrentValue = 3.5, Callback = function(V) GridSpacing = V end})

local ViewPart, ViewBox, ViewRender = nil, nil, nil
local function Snap(val) return math.floor(val / 0.25 + 0.5) * 0.25 end

PlaceTab:CreateToggle({
    Name = "👀 Show Glowing Selection Area",
    CurrentValue = false,
    Callback = function(Val)
        if Val then
            if ViewRender then ViewRender:Disconnect() end
            if ViewPart then ViewPart:Destroy() end

            ViewPart = Instance.new("Part")
            ViewPart.Material = Enum.Material.Neon
            ViewPart.Color = Color3.fromRGB(255, 0, 0)
            ViewPart.Transparency = 0.6 
            ViewPart.Anchored = true
            ViewPart.CanCollide = false
            ViewPart.CastShadow = false
            ViewPart.Parent = Workspace

            ViewBox = Instance.new("SelectionBox")
            ViewBox.Color3 = Color3.fromRGB(255, 255, 255) 
            ViewBox.LineThickness = 0.1
            ViewBox.Adornee = ViewPart
            ViewBox.Parent = ViewPart

            ViewRender = RunService.RenderStepped:Connect(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    ViewPart.Size = Vector3.new(GridWidth, 0.5, GridDepth)
                    local verticalOffset = (LocalPlayer.Character:FindFirstChild("LeftLeg") or LocalPlayer.Character:FindFirstChild("LeftFoot") and 3) or 2.5
                    local centerX, centerZ = Snap(hrp.Position.X), Snap(hrp.Position.Z)
                    
                    ViewPart.CFrame = CFrame.new(centerX, hrp.Position.Y - verticalOffset + 0.25, centerZ) 
                                      * CFrame.Angles(0, math.rad(GridRotation), 0)
                                      * CFrame.new(0, 0, -5 - (GridDepth/2))
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
    Name = "🚀 Deploy Grid (Eagle Scan)",
    CurrentValue = false,
    Callback = function(Value)
        _G.AutoLoopGrid = Value
        if _G.AutoLoopGrid then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then _G.AutoLoopGrid = false return end

            local GridTargets = {}
            local MaxPerRow = math.max(1, math.floor(GridWidth / GridSpacing))
            local MaxRows = math.max(1, math.floor(GridDepth / GridSpacing))
            
            local centerX, centerZ = Snap(hrp.Position.X), Snap(hrp.Position.Z)
            local baseCFrame = CFrame.new(centerX, 0, centerZ) * CFrame.Angles(0, math.rad(GridRotation), 0)

            for row = 0, MaxRows - 1 do
                for col = 0, MaxPerRow - 1 do
                    local localX = (GridWidth / 2) - (col * GridSpacing) - (GridSpacing / 2)
                    local localZ = -5 - (GridSpacing / 2) - (row * GridSpacing)
                    
                    local targetPos = baseCFrame * CFrame.new(localX, 0, localZ)
                    
                    -- Offset applied here to generate the LocalX/LocalZ required by the server payload
                    table.insert(GridTargets, {
                        LocalX = Snap(targetPos.X) - _G.PlotXOffset,
                        LocalZ = Snap(targetPos.Z) - _G.PlotZOffset
                    })
                end
            end

            task.spawn(function()
                local count = 1
                local MaxTotal = #GridTargets
                Rayfield:Notify({Title = "Deploying Grid", Content = "Placing " .. MaxTotal .. " items instantly!", Duration = 4})

                while _G.AutoLoopGrid and count <= MaxTotal do
                    local targetData = GridTargets[count]

                    -- THE EXACT INVENTORY SCAN FROM EAGLE SCRIPT
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

                    -- EXACT PAYLOAD FORMAT FROM REMOTE DUMP
                    if currentId then
                        task.spawn(function()
                            pcall(function()
                                PerformActionFunc:InvokeServer("PlaceOwnedItem", {
                                    LocalZ = targetData.LocalZ,
                                    InventoryId = currentId,
                                    Rotation = 0,
                                    LocalX = targetData.LocalX
                                })
                            end)
                        end)

                        UsedIDs[currentId] = true 
                        count = count + 1
                    end
                    task.wait(0.05) 
                end
                
                if count > MaxTotal then
                    _G.AutoLoopGrid = false
                    Rayfield:Notify({Title = "Grid Complete", Content = "All grid positions filled successfully.", Duration = 4})
                end
            end)
        else
            UsedIDs = {} 
        end
    end
})

---------------------------------------------------------------------------
-- TAB 5: TELEPORT & EXPLOITS
---------------------------------------------------------------------------
local TeleportTab = Window:CreateTab("⚡ Teleports & Exploits", 4483362458)

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
            -- Safely checks for 'leaderstats' cash or money values
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

print("Op Update Verified and Executed 🔥🔥💥💥")
