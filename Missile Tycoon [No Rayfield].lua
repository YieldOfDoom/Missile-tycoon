local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

task.spawn(function() LocalPlayer:WaitForChild("RocketClient", 15) end)

-- =========================================================================
-- CORE REMOTES, CONSTANTS & ARRAYS
-- =========================================================================
local Remotes = ReplicatedStorage:WaitForChild("CityBuilderRockets"):WaitForChild("Remotes")
local PerformAction = Remotes:WaitForChild("PerformAction")
local ActionEvent = Remotes:WaitForChild("PerformActionEvent")
local FactoryCreate = Remotes:WaitForChild("FactoryCreateRocket")
local StorageAction = Remotes:WaitForChild("FactoryStorageAction")
local PerformActionResult = Remotes:WaitForChild("PerformActionResult")

local LAUNCH_UUID = "65861b8c-de51-4dd8-abe7-7aa3f9d0479c"
local DECLARE_WAR_UUID = "87EBD164-5DE0-4556-B741-51F3CF159B8B"

local BUILDINGS = {
	{"Bluebird House","a6564a6d-feeb-45d3-9c00-ef6555a244ea","tier1_bluebird_house",4},
	{"Sunset Villa","f8b4e635-4158-459d-8e21-404bdd9316fe","tier1_sunset_villa",5},
	{"Corner Market","568adbf1-d72e-460b-ac9a-5f57c4e129cf","tier1_corner_market",6},
	{"Solar Income Plant","05abad36-d264-4356-8bc1-881fc2ace38a","tier2_solar_income_plant",7},
	{"Seaside Motel","0fc1557a-4873-4d3d-a1d3-9e70f18b0209","tier2_seaside_motel",8},
	{"Metro Bank","7ca869eb-ca74-4f93-86bd-c4aec5fcd5e0","tier2_metro_bank",9},
	{"Boutique Hotel","1bb784f3-9e1f-48e2-9dab-e3731126074c","tier2_boutique_hotel",10},
	{"Arcade Cash Hub","ec678825-3928-43bd-81c8-ef0b46354208","tier2_arcade_cash_hub",11},
	{"Resort Residence","ee5a372e-0164-4139-a1a7-b4e5d7a12455","tier3_resort_residence",12},
	{"Grand Hotel Tower","3c49a3dc-e69c-4e40-8f6d-dbab6af0369e","tier3_grand_hotel_tower",13},
	{"Exchange Tower","45cfef84-5254-4357-b5df-bb4655ff2d10","tier3_exchange_tower",14},
	{"Bank","32a57e2b-407b-4457-9945-e7d41764308d","bank",15},
	{"Factory (17b)","17b67359-b712-4ca2-8297-7db54e586518","factory",16},
	{"Satellite Station","25703ba8-614b-4a7a-953a-184fb0856f87","building_new1",17},
	{"Nuclear Facility","5e307c77-f6d2-489e-aaad-798ef6ea8161","building_new2",18},
}
local MILITARY = {
    {"Storage","e529ba1b-dfc8-4d44-ac38-79fdce1ad6d6","storage",2},
	{"Factory (1487)","1487835c-a009-447d-99a7-085ab1b2abf2","factory1",3},
    {"Launcher Rockets","6389a201-8b16-41d7-b770-4414a18f09e6","launcher_rockets1",19},
}
local ROCKETS = {
	{"Firefly Rocket","firefly_rocket","Rocket1"}, {"Viper Cruise","viper_cruise_rocket","Rocket2"},
	{"Hammer Ballistic","hammer_ballistic_rocket","Rocket3"}, {"Titan Strike Rocket","rocket4","Rocket4"},
	{"Crimson Strike","rocket5","Rocket5"}, {"Golden Lance","rocket6","Rocket6"},
	{"Leviathan Siege","rocket7","Rocket7"}, {"Titan Fang","rocket8","Rocket8"}, {"Shadow Viper","rocket9","Rocket9"},
}

-- =========================================================================
-- PLOT & STORAGE PARSING 
-- =========================================================================
local world = Workspace:WaitForChild("CityBuilderRocketsWorld", 60)
local myPlot, anchor = nil, nil
task.spawn(function()
    if world then
        for _, plot in ipairs(world:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                myPlot = plot; anchor = myPlot:FindFirstChild("Anchor"); break
            end
        end
    end
end)

local function getFactoryId()
	if not myPlot then return nil end
	local objects = myPlot:FindFirstChild("Objects")
	if not objects then return nil end
	for _,v in ipairs(objects:GetChildren()) do
		if v:GetAttribute("DefinitionId") == "factory1" then return v:GetAttribute("ObjectId") end
	end
end

local function getAllStorageIds()
	local ids = {}
	if not myPlot then return ids end
	local objects = myPlot:FindFirstChild("Objects")
	if not objects then return ids end
	for _,v in ipairs(objects:GetChildren()) do
		if v.Name == "Storage" then
			local oid = v:GetAttribute("ObjectId")
			if oid then table.insert(ids,oid) end
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

-- =========================================================================
-- VOZEX NATIVE UI LIBRARY - THE TAB ENGINE (PC + MOBILE FIXES)
-- =========================================================================
local VozexUI = {}
VozexUI.Colors = {
    Bg = Color3.fromRGB(15, 15, 15),
    Panel = Color3.fromRGB(22, 22, 22),
    PanelLight = Color3.fromRGB(30, 30, 30),
    Accent = Color3.fromRGB(255, 215, 0), -- Vozex Gold
    Text = Color3.fromRGB(240, 240, 240),
    TextDim = Color3.fromRGB(150, 150, 150)
}

function VozexUI:MakeDraggable(gui, handle)
    handle = handle or gui
    local dragging, dragInput, mousePos, framePos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; mousePos = input.Position; framePos = gui.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            local screen = gui.Parent and gui.Parent:IsA("ScreenGui") and gui.Parent.AbsoluteSize or Vector2.new(1000, 1000)
            local padding = 15
            local targetX = framePos.X.Offset + delta.X
            local targetY = framePos.Y.Offset + delta.Y
            
            local minX = padding - (gui.AbsoluteSize.X * gui.AnchorPoint.X)
            local maxX = screen.X - padding - (gui.AbsoluteSize.X * (1 - gui.AnchorPoint.X))
            local minY = padding - (gui.AbsoluteSize.Y * gui.AnchorPoint.Y)
            local maxY = screen.Y - padding - (gui.AbsoluteSize.Y * (1 - gui.AnchorPoint.Y))

            gui.Position = UDim2.new(framePos.X.Scale, math.clamp(targetX, minX, maxX), framePos.Y.Scale, math.clamp(targetY, minY, maxY))
        end
    end)
end

function VozexUI:CreateWindow(opts)
    local isMobile = UserInputService.TouchEnabled
    local title = type(opts) == "table" and opts.Name or opts
    local sg = Instance.new("ScreenGui")
    sg.Name = "VozexNativeUI"
    sg.ResetOnSpawn = false
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Floating Toggle Icon (The Crown)
    local floatBtn = Instance.new("TextButton")
    floatBtn.Size = UDim2.new(0, 50, 0, 50)
    floatBtn.Position = UDim2.new(0.5, -25, 0, 20)
    floatBtn.BackgroundColor3 = self.Colors.Panel
    floatBtn.Text = "👑"
    floatBtn.TextSize = 24
    floatBtn.Visible = false
    floatBtn.Parent = sg
    Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
    local fStroke = Instance.new("UIStroke", floatBtn); fStroke.Color = self.Colors.Accent; fStroke.Thickness = 2
    self:MakeDraggable(floatBtn)

    -- Main UI Canvas
    local main = Instance.new("Frame")
    -- Apply automatic mobile scaling down to 80% if on a phone
    if isMobile then
        main.Size = UDim2.new(0, 520 * 0.8, 0, 360 * 0.8)
    else
        main.Size = UDim2.new(0, 520, 0, 360)
    end
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = self.Colors.Bg
    main.Active = true
    main.Parent = sg
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
    local mStroke = Instance.new("UIStroke", main); mStroke.Color = self.Colors.PanelLight; mStroke.Thickness = 1

    -- Mobile Touch Fixes
    local function refineUIElement(element)
        if element:IsA("Frame") or element:IsA("ScrollingFrame") or element:IsA("CanvasGroup") then
            element.Active = true
        elseif element:IsA("TextButton") or element:IsA("ImageButton") then
            element.Active = true
            element.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    local connection; connection = input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then connection:Disconnect() end
                    end)
                end
            end)
        end
    end
    for _, child in ipairs(main:GetDescendants()) do refineUIElement(child) end
    main.DescendantAdded:Connect(refineUIElement)

    -- Top Header
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundColor3 = self.Colors.Panel
    topBar.Parent = main
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    local tFix = Instance.new("Frame", topBar); tFix.Size = UDim2.new(1,0,0,8); tFix.Position = UDim2.new(0,0,1,-8); tFix.BackgroundColor3 = self.Colors.Panel; tFix.BorderSizePixel = 0
    self:MakeDraggable(main, topBar)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -60, 1, 0)
    titleLbl.Position = UDim2.new(0, 15, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = self.Colors.Accent
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 15
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = topBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 24, 0, 24)
    minBtn.Position = UDim2.new(1, -35, 0.5, -12)
    minBtn.BackgroundColor3 = self.Colors.PanelLight
    minBtn.Text = "➖"
    minBtn.TextColor3 = self.Colors.Text
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 12
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    minBtn.MouseButton1Click:Connect(function() main.Visible = false; floatBtn.Visible = true end)
    floatBtn.MouseButton1Click:Connect(function() floatBtn.Visible = false; main.Visible = true end)

    -- Tab Selection Menu (Left Side)
    local tabContainer = Instance.new("ScrollingFrame")
    tabContainer.Size = UDim2.new(0, 130, 1, -40)
    tabContainer.Position = UDim2.new(0, 0, 0, 40)
    tabContainer.BackgroundColor3 = self.Colors.Panel
    tabContainer.BorderSizePixel = 0
    tabContainer.ScrollBarThickness = 0
    tabContainer.Parent = main
    local tLayout = Instance.new("UIListLayout", tabContainer); tLayout.Padding = UDim.new(0, 4); tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", tabContainer).PaddingTop = UDim.new(0, 8)
    tLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() tabContainer.CanvasSize = UDim2.new(0,0,0, tLayout.AbsoluteContentSize.Y + 15) end)

    -- Content Pages (Right Side)
    local pageContainer = Instance.new("Frame")
    pageContainer.Size = UDim2.new(1, -130, 1, -40)
    pageContainer.Position = UDim2.new(0, 130, 0, 40)
    pageContainer.BackgroundTransparency = 1
    pageContainer.Parent = main

    local WindowObj = {Tabs = {}, CurrentTab = nil, Gui = sg}

    -- TAB CREATOR ENGINE
    function WindowObj:CreateTab(name)
        local tBtn = Instance.new("TextButton")
        tBtn.Size = UDim2.new(1, -14, 0, 32)
        tBtn.BackgroundColor3 = VozexUI.Colors.PanelLight
        tBtn.BackgroundTransparency = 1
        tBtn.Text = name
        tBtn.TextColor3 = VozexUI.Colors.TextDim
        tBtn.Font = Enum.Font.GothamSemibold
        tBtn.TextSize = 13
        tBtn.Parent = tabContainer
        Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 6)

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 3, 0.6, 0)
        indicator.Position = UDim2.new(0, 0, 0.2, 0)
        indicator.BackgroundColor3 = VozexUI.Colors.Accent
        indicator.BackgroundTransparency = 1
        indicator.Parent = tBtn
        Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = VozexUI.Colors.Accent
        page.Visible = false
        page.Parent = pageContainer
        
        local pLayout = Instance.new("UIListLayout", page)
        pLayout.Padding = UDim.new(0, 6)
        pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        
        local pPad = Instance.new("UIPadding", page)
        pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 10)

        pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
            page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 20) 
        end)

        if not self.CurrentTab then
            self.CurrentTab = page
            page.Visible = true
            tBtn.BackgroundTransparency = 0
            tBtn.TextColor3 = VozexUI.Colors.Text
            indicator.BackgroundTransparency = 0
        end

        tBtn.MouseButton1Click:Connect(function()
            for _, btn in ipairs(tabContainer:GetChildren()) do 
                if btn:IsA("TextButton") then 
                    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextColor3 = VozexUI.Colors.TextDim}):Play()
                    TweenService:Create(btn:FindFirstChild("Frame"), TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                end 
            end
            for _, p in ipairs(pageContainer:GetChildren()) do p.Visible = false end
            TweenService:Create(tBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0, TextColor3 = VozexUI.Colors.Text}):Play()
            TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
            page.Visible = true
        end)

        local TabObj = {}
        
        function TabObj:CreateSection(text)
            local sLbl = Instance.new("TextLabel")
            sLbl.Size = UDim2.new(1, -20, 0, 25)
            sLbl.BackgroundTransparency = 1
            sLbl.Text = text
            sLbl.TextColor3 = VozexUI.Colors.Accent
            sLbl.Font = Enum.Font.GothamBold
            sLbl.TextSize = 14
            sLbl.TextXAlignment = Enum.TextXAlignment.Left
            sLbl.Parent = page
        end

        function TabObj:CreateButton(opts)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -20, 0, 36)
            btn.BackgroundColor3 = VozexUI.Colors.Panel
            btn.Text = opts.Name
            btn.TextColor3 = VozexUI.Colors.Text
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 13
            btn.Parent = page
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            Instance.new("UIStroke", btn).Color = VozexUI.Colors.PanelLight
            
            btn.MouseButton1Click:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = VozexUI.Colors.PanelLight}):Play()
                opts.Callback()
                task.wait(0.1)
                TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = VozexUI.Colors.Panel}):Play()
            end)
        end

        function TabObj:CreateToggle(opts)
            local state = opts.CurrentValue or false
            local tgl = Instance.new("TextButton")
            tgl.Size = UDim2.new(1, -20, 0, 36)
            tgl.BackgroundColor3 = VozexUI.Colors.Panel
            tgl.Text = "   " .. opts.Name
            tgl.TextColor3 = VozexUI.Colors.Text
            tgl.Font = Enum.Font.GothamSemibold
            tgl.TextSize = 13
            tgl.TextXAlignment = Enum.TextXAlignment.Left
            tgl.Parent = page
            Instance.new("UICorner", tgl).CornerRadius = UDim.new(0, 6)
            Instance.new("UIStroke", tgl).Color = VozexUI.Colors.PanelLight

            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(0, 34, 0, 18)
            bg.Position = UDim2.new(1, -45, 0.5, -9)
            bg.BackgroundColor3 = state and VozexUI.Colors.Accent or VozexUI.Colors.Bg
            bg.Parent = tgl
            Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 14, 0, 14)
            knob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            knob.BackgroundColor3 = VozexUI.Colors.Text
            knob.Parent = bg
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

            tgl.MouseButton1Click:Connect(function()
                state = not state
                TweenService:Create(bg, TweenInfo.new(0.2), {BackgroundColor3 = state and VozexUI.Colors.Accent or VozexUI.Colors.Bg}):Play()
                TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
                opts.Callback(state)
            end)
        end

        function TabObj:CreateDropdown(opts)
            local dropBtn = Instance.new("TextButton")
            dropBtn.Size = UDim2.new(1, -20, 0, 36)
            dropBtn.BackgroundColor3 = VozexUI.Colors.Panel
            dropBtn.Text = "   " .. opts.Name .. ": " .. (opts.CurrentOption or opts.Options[1] or "")
            dropBtn.TextColor3 = VozexUI.Colors.Text
            dropBtn.Font = Enum.Font.GothamSemibold
            dropBtn.TextSize = 13
            dropBtn.TextXAlignment = Enum.TextXAlignment.Left
            dropBtn.Parent = page
            Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 6)
            Instance.new("UIStroke", dropBtn).Color = VozexUI.Colors.PanelLight

            local listFrame = Instance.new("Frame")
            listFrame.Size = UDim2.new(1, -20, 0, 0)
            listFrame.BackgroundColor3 = VozexUI.Colors.Bg
            listFrame.ClipsDescendants = true
            listFrame.Visible = false
            listFrame.Parent = page
            Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)
            local lLayout = Instance.new("UIListLayout", listFrame)

            local open = false
            local function populate(options)
                for _, c in ipairs(listFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                local h = 0
                for _, opt in ipairs(options) do
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(1, 0, 0, 30); b.BackgroundColor3 = VozexUI.Colors.Bg; b.Text = opt; b.TextColor3 = VozexUI.Colors.TextDim; b.Font = Enum.Font.Gotham; b.TextSize = 13; b.Parent = listFrame
                    b.MouseButton1Click:Connect(function()
                        dropBtn.Text = "   " .. opts.Name .. ": " .. opt
                        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, -20, 0, 0)}):Play()
                        task.wait(0.2) listFrame.Visible = false; open = false
                        opts.Callback({opt})
                    end)
                    h = h + 30
                end
                if open then listFrame.Size = UDim2.new(1, -20, 0, h) end
            end
            populate(opts.Options)

            dropBtn.MouseButton1Click:Connect(function()
                open = not open
                if open then 
                    listFrame.Visible = true 
                    TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, -20, 0, #listFrame:GetChildren() * 30 - 30)}):Play()
                else 
                    TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, -20, 0, 0)}):Play()
                    task.wait(0.2) listFrame.Visible = false 
                end
            end)
            return { Refresh = function(_, newOpts) populate(newOpts) end }
        end

        function TabObj:CreateSlider(opts)
            local val = opts.CurrentValue or opts.Range[1]
            local frm = Instance.new("Frame")
            frm.Size = UDim2.new(1, -20, 0, 50)
            frm.BackgroundColor3 = VozexUI.Colors.Panel
            frm.Parent = page
            Instance.new("UICorner", frm).CornerRadius = UDim.new(0, 6)
            Instance.new("UIStroke", frm).Color = VozexUI.Colors.PanelLight

            local lbl = Instance.new("TextLabel", frm)
            lbl.Size = UDim2.new(1, -20, 0, 20); lbl.Position = UDim2.new(0, 10, 0, 5); lbl.BackgroundTransparency = 1; lbl.Text = opts.Name .. ": " .. val; lbl.TextColor3 = VozexUI.Colors.Text; lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left

            local bgBar = Instance.new("TextButton", frm)
            bgBar.Size = UDim2.new(1, -20, 0, 8); bgBar.Position = UDim2.new(0, 10, 0, 32); bgBar.BackgroundColor3 = VozexUI.Colors.Bg; bgBar.Text = ""; bgBar.AutoButtonColor = false
            Instance.new("UICorner", bgBar).CornerRadius = UDim.new(1, 0)
            
            local fill = Instance.new("Frame", bgBar)
            fill.BackgroundColor3 = VozexUI.Colors.Accent; fill.Size = UDim2.new((val - opts.Range[1])/(opts.Range[2] - opts.Range[1]), 0, 1, 0)
            Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

            local dragging = false
            local function update(input)
                local pct = math.clamp((input.Position.X - bgBar.AbsolutePosition.X) / bgBar.AbsoluteSize.X, 0, 1)
                local rawVal = opts.Range[1] + pct * (opts.Range[2] - opts.Range[1])
                local inc = opts.Increment or 1
                val = math.floor(rawVal / inc + 0.5) * inc
                TweenService:Create(fill, TweenInfo.new(0.1), {Size = UDim2.new((val - opts.Range[1])/(opts.Range[2] - opts.Range[1]), 0, 1, 0)}):Play()
                lbl.Text = opts.Name .. ": " .. val
                opts.Callback(val)
            end
            bgBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; update(input) end end)
            UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
            UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end end)
        end

        function TabObj:CreateLabel(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -20, 0, 30); lbl.BackgroundColor3 = VozexUI.Colors.Panel; lbl.Text = "   " .. text; lbl.TextColor3 = VozexUI.Colors.TextDim; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = page
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
            return { Set = function(_, txt) lbl.Text = "   " .. txt end }
        end

        return TabObj
    end

    function WindowObj:Notify(opts)
        print("[VOZEX HUB] " .. tostring(opts.Title) .. " - " .. tostring(opts.Content))
    end

    return WindowObj
end

local Rayfield = VozexUI 
local Window = Rayfield:CreateWindow({
    Name = "Missile Tycoon 🚀 | Vozex Hub 👑"
})

-- =========================================================================
-- TAB 1: BOMBARD / WAR
-- =========================================================================
local MainTab = Window:CreateTab("💣 Bombard")

_G.MySafeZone = nil
task.spawn(function()
    if LocalPlayer.Character and LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5) then
        _G.MySafeZone = LocalPlayer.Character.HumanoidRootPart.Position
    end
end)

MainTab:CreateSection("Target Settings")

_G.SelectedPlayer = nil
local PlayerDropdown = MainTab:CreateDropdown({
    Name = "🎯 Select Target Player", 
    Options = {"Loading..."},
    Callback = function(Opt) 
        _G.SelectedPlayer = Players:FindFirstChild(Opt[1]) 
    end,
})

_G.BombMode = "Continuous"
MainTab:CreateDropdown({
    Name = "⚙️ Bombing Mode", 
    Options = {"Continuous", "Bulk"}, 
    CurrentOption = "Continuous",
    Callback = function(Opt) 
        _G.BombMode = Opt[1] 
    end,
})

local StatusLabel = MainTab:CreateLabel("Status: 💤 Idle")
local WarStatusLabel = MainTab:CreateLabel("⚔️ War Status: Not Declared")

local FoundRockets, FoundBuildings = {}, {}
_G.WarInProgress = false
_G.WarDeclared = false

local function DeclareWar(targetPlayer)
    if not targetPlayer then 
        return false 
    end
    
    local args = {
        DECLARE_WAR_UUID,
        true,
        targetPlayer.UserId
    }
    
    local success = pcall(function()
        PerformActionResult:FireServer(unpack(args))
    end)
    
    if success then
        _G.WarDeclared = true
        WarStatusLabel:Set("⚔️ War Status: DECLARED against " .. targetPlayer.Name)
        Window:Notify({Title = "⚔️ WAR DECLARED", Content = "War declared against: " .. targetPlayer.Name})
        return true
    else
        Window:Notify({Title = "❌ Failed", Content = "Could not declare war"})
        return false
    end
end

local function DeepScan()
    table.clear(FoundRockets) 
    table.clear(FoundBuildings)
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or not _G.SelectedPlayer then 
        return 
    end
    
    local function ScanContainer(cont)
        if not cont then return end
        for _, item in ipairs(cont:GetChildren()) do
            if item:IsA("Tool") then
                local id = item:GetAttribute("ObjectId") or item.Name:match("^%d+_%d+_%d+") or (item.Name:lower():match("rocket") and item.Name)
                if id then 
                    table.insert(FoundRockets, {ID = id, InstanceRef = item, IsTool = true}) 
                end
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
    end

    if world then
        for _, plot in ipairs(world:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == _G.SelectedPlayer.UserId then
                local objects = plot:FindFirstChild("Objects")
                if objects then
                    for _, obj in ipairs(objects:GetChildren()) do
                        local defId = obj:GetAttribute("DefinitionId")
                        
                        local isMilitary = (defId == "storage" or defId == "factory1" or defId == "launcher_rockets1")
                        
                        local isEnemyRocket = false
                        for _, r in ipairs(ROCKETS) do
                            if defId == r[2] or defId == r[3] or string.find(string.lower(obj.Name), "rocket") then
                                isEnemyRocket = true
                                break
                            end
                        end
                        
                        if defId and not isMilitary and not isEnemyRocket then
                            
                            local isKnownBuilding = false
                            for _, b in ipairs(BUILDINGS) do 
                                if b[3] == defId then 
                                    isKnownBuilding = true
                                    break 
                                end 
                            end
                            
                            if isKnownBuilding then
                                local uuid = obj:GetAttribute("ObjectId") or obj:GetAttribute("InventoryId")
                                local bPos = (obj:IsA("BasePart") and obj.Position) or (obj:IsA("Model") and obj:GetModelCFrame().p)
                                if uuid and bPos then 
                                    table.insert(FoundBuildings, {ID = uuid, Pos = bPos, Instance = obj}) 
                                end
                            end
                        end
                    end
                end
                break
            end
        end
    end
end

local function TriggerWar()
    if not _G.SelectedPlayer or _G.WarInProgress then return end
    
    local warDeclared = DeclareWar(_G.SelectedPlayer)
    if not warDeclared then
        Window:Notify({Title = "❌ Failed", Content = "Could not declare war, aborting"})
        return
    end
    
    -- Give the server 1.5s to fully process the war state
    task.wait(1.5)
    
    _G.WarInProgress = true
    StatusLabel:Set("Status: ⚔️ WAR ACTIVE")
    
    task.spawn(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        
        while _G.WarInProgress do
            DeepScan() 
            
            if #FoundRockets > 0 and #FoundBuildings > 0 and _G.SelectedPlayer then
                local limit = (_G.BombMode == "Bulk") and #FoundRockets or math.min(#FoundRockets, 5)
                
                for i = 1, limit do
                    if not _G.WarInProgress then break end
                    task.wait(0.2)
                    
                    local t = FoundBuildings[math.random(1, #FoundBuildings)]
                    local mId = FoundRockets[i].ID
                    
                    if FoundRockets[i].IsTool and FoundRockets[i].InstanceRef.Parent == LocalPlayer:FindFirstChild("Backpack") and hum then
                        hum:EquipTool(FoundRockets[i].InstanceRef) 
                        task.wait(0.01)
                    end
                    
                    local ok, err = pcall(function() 
                        ActionEvent:FireServer(LAUNCH_UUID, "LaunchRocket", {
                            WarConfirmed = true, 
                            TargetZ = t.Pos.Z, 
                            ObjectId = mId, 
                            TargetX = t.Pos.X, 
                            TargetY = t.Pos.Y 
                        }) 
                    end)
                    
                    if not ok then warn("[Bombard Error]: " .. tostring(err)) end
                    
                    if _G.BombMode == "Continuous" then 
                        task.wait(0.2) 
                    else 
                        task.wait() 
                    end
                end
                
                if _G.BombMode == "Bulk" then 
                    task.wait(0.2) 
                end
            else
                task.wait(0.1)
                if #FoundBuildings == 0 and _G.SelectedPlayer then 
                    _G.WarInProgress = false
                    WarStatusLabel:Set("⚔️ War Status: ENDED - Victory!")
                    Window:Notify({Title = "🏆 VICTORY", Content = "Target has no buildings left!"})
                end
            end
        end
        StatusLabel:Set("Status: 💤 Idle")
    end)
end

MainTab:CreateButton({ 
    Name = "🚀 START AUTO WAR", 
    Callback = function() TriggerWar() end 
})

MainTab:CreateButton({ 
    Name = "🛑 STOP WAR", 
    Callback = function() 
        _G.WarInProgress = false 
        StatusLabel:Set("Status: 💤 Idle") 
    end 
})

task.spawn(function()
    while task.wait(2) do
        local list = {}
        for _, p in pairs(Players:GetPlayers()) do 
            if p ~= LocalPlayer then 
                table.insert(list, p.Name) 
            end 
        end
        pcall(function() PlayerDropdown:Refresh(list) end)
    end
end)

-- =========================================================================
-- TAB 2: BUILDINGS
-- =========================================================================
local BuyTab = Window:CreateTab("🏗️ Buildings")
BuyTab:CreateSection("Auto Buy All Mode")

_G.BuyAllBuildings = false
BuyTab:CreateToggle({
    Name = "✅ Auto Buy ALL Buildings", 
    CurrentValue = false, 
    Callback = function(V)
        _G.BuyAllBuildings = V
        if V then
            task.spawn(function()
                while _G.BuyAllBuildings do
                    for _, item in ipairs(BUILDINGS) do
                        if not _G.BuyAllBuildings then break end
                        pcall(function() 
                            ActionEvent:FireServer(item[2], "BuyOwnedItem", { 
                                ShopIndex = item[4], 
                                DefinitionId = item[3], 
                                RequestId = HttpService:GenerateGUID(false) 
                            }) 
                        end)
                        task.wait(0.2)
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
})

BuyTab:CreateSection("Individual Buildings")
for _, bldg in ipairs(BUILDINGS) do
    _G["BuyBldg_" .. bldg[1]] = false
    BuyTab:CreateToggle({
        Name = "Auto Buy: " .. bldg[1], 
        CurrentValue = false, 
        Callback = function(V)
            _G["BuyBldg_" .. bldg[1]] = V
            if V then 
                task.spawn(function() 
                    while _G["BuyBldg_" .. bldg[1]] do 
                        pcall(function() 
                            ActionEvent:FireServer(bldg[2], "BuyOwnedItem", { 
                                ShopIndex = bldg[4], 
                                DefinitionId = bldg[3], 
                                RequestId = HttpService:GenerateGUID(false) 
                            }) 
                        end) 
                        task.wait(1) 
                    end 
                end) 
            end
        end
    })
end

-- =========================================================================
-- TAB 3: MILITARY
-- =========================================================================
local MilitaryTab = Window:CreateTab("⚔️ Military")
MilitaryTab:CreateSection("Auto Buy All Mode")

_G.BuyAllMilitary = false
MilitaryTab:CreateToggle({
    Name = "✅ Auto Buy ALL Military", 
    CurrentValue = false, 
    Callback = function(V)
        _G.BuyAllMilitary = V
        if V then
            task.spawn(function()
                while _G.BuyAllMilitary do
                    for _, item in ipairs(MILITARY) do
                        if not _G.BuyAllMilitary then break end
                        pcall(function() 
                            ActionEvent:FireServer(item[2], "BuyOwnedItem", { 
                                ShopIndex = item[4], 
                                DefinitionId = item[3], 
                                RequestId = HttpService:GenerateGUID(false) 
                            }) 
                        end)
                        task.wait(0.2)
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
})

MilitaryTab:CreateSection("Individual Military")
for _, mil in ipairs(MILITARY) do
    _G["BuyMil_" .. mil[1]] = false
    MilitaryTab:CreateToggle({
        Name = "Auto Buy: " .. mil[1], 
        CurrentValue = false, 
        Callback = function(V)
            _G["BuyMil_" .. mil[1]] = V
            if V then 
                task.spawn(function() 
                    while _G["BuyMil_" .. mil[1]] do 
                        pcall(function() 
                            ActionEvent:FireServer(mil[2], "BuyOwnedItem", { 
                                ShopIndex = mil[4], 
                                DefinitionId = mil[3], 
                                RequestId = HttpService:GenerateGUID(false) 
                            }) 
                        end) 
                        task.wait(1) 
                    end 
                end) 
            end
        end
    })
end

-- =========================================================================
-- TAB 4: MISSILES
-- =========================================================================
local MissileTab = Window:CreateTab("🚀 Missiles")

MissileTab:CreateSection("Auto Create Missiles")

_G.CraftRandom = false
MissileTab:CreateToggle({
    Name = "🎲 Auto Create Random Missile", 
    CurrentValue = false, 
    Callback = function(V)
        _G.CraftRandom = V
        if V then
            task.spawn(function()
                while _G.CraftRandom do
                    local fid = getFactoryId()
                    if fid then 
                        local randTarget = ROCKETS[math.random(1, #ROCKETS)][2] 
                        pcall(function() 
                            FactoryCreate:FireServer(randTarget, 5, fid) 
                        end) 
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
})

for _, rock in ipairs(ROCKETS) do
    _G["Craft_" .. rock[1]] = false
    MissileTab:CreateToggle({
        Name = "Auto Create: " .. rock[1], 
        CurrentValue = false, 
        Callback = function(V)
            _G["Craft_" .. rock[1]] = V
            if V then 
                task.spawn(function() 
                    while _G["Craft_" .. rock[1]] do 
                        local fid = getFactoryId()
                        if fid then 
                            pcall(function() 
                                FactoryCreate:FireServer(rock[2], 5, fid) 
                            end) 
                        end 
                        task.wait(0.5) 
                    end 
                end) 
            end
        end
    })
end

MissileTab:CreateSection("Auto Take Missiles")
_G.TakeAllMissiles = false
MissileTab:CreateToggle({
    Name = "✅ Auto Take ALL Missiles", 
    CurrentValue = false, 
    Callback = function(V)
        _G.TakeAllMissiles = V
        if V then
            task.spawn(function()
                while _G.TakeAllMissiles do
                    local sids = getAllStorageIds()
                    if #sids > 0 then
                        for _, sid in ipairs(sids) do
                            if not _G.TakeAllMissiles then break end
                            pcall(function() StorageAction:InvokeServer("Get", nil, nil, sid) end) 
                            task.wait(0.1)
                            for _, r in ipairs(ROCKETS) do
                                if not _G.TakeAllMissiles then break end
                                pcall(function() StorageAction:InvokeServer("Take", r[3], 5, sid) end)
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
})

for _, rock in ipairs(ROCKETS) do
    _G["Take_" .. rock[1]] = false
    MissileTab:CreateToggle({
        Name = "Auto Take: " .. rock[1], 
        CurrentValue = false, 
        Callback = function(V)
            _G["Take_" .. rock[1]] = V
            if V then 
                task.spawn(function() 
                    while _G["Take_" .. rock[1]] do 
                        local sids = getAllStorageIds()
                        if #sids > 0 then 
                            for _, sid in ipairs(sids) do 
                                pcall(function() StorageAction:InvokeServer("Get", nil, nil, sid) end) 
                                task.wait(0.1) 
                                pcall(function() StorageAction:InvokeServer("Take", rock[3], 5, sid) end) 
                            end 
                        end 
                        task.wait(0.5) 
                    end 
                end) 
            end
        end
    })
end

-- =========================================================================
-- TAB 5: AUTO PLACE
-- =========================================================================
local PlaceTab = Window:CreateTab("🔥 Auto Place")

_G.COLS = 10
_G.ROWS = 10
_G.STEP = 3.5

PlaceTab:CreateSection("Grid Dimensions")
PlaceTab:CreateSlider({
    Name = "Grid Width (Cols)", Range = {1, 50}, Increment = 1, CurrentValue = 10, 
    Callback = function(V) _G.COLS = V end
})
PlaceTab:CreateSlider({
    Name = "Grid Depth (Rows)", Range = {1, 50}, Increment = 1, CurrentValue = 10, 
    Callback = function(V) _G.ROWS = V end
})
PlaceTab:CreateSlider({
    Name = "Grid Spacing", Range = {2, 15}, Increment = 0.5, CurrentValue = 3.5, 
    Callback = function(V) _G.STEP = V end
})

local boxParts = {}

local function clearBox() 
    for _, p in ipairs(boxParts) do 
        pcall(function() p:Destroy() end) 
    end 
    boxParts = {} 
end

local function makePart(color) 
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Transparency = 0.1
    p.Parent = Workspace
    table.insert(boxParts, p)
    return p 
end

local function localToWorld(lx, lz) 
    if not anchor then return 0, 0 end 
    local wp = anchor.CFrame:PointToWorldSpace(Vector3.new(lx, 0, lz))
    return wp.X, wp.Z 
end

local function getCornerInFront() 
    local char = LocalPlayer.Character
    if not char then return 0, 0 end 
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, 0 end 
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
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
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
        local mid = (a + b) / 2
        local len = (b - a).Magnitude
        if len < 0.05 then continue end
        local p = makePart(color)
        p.Size = Vector3.new(len, 0.3, 0.3)
        p.CFrame = CFrame.new(mid, mid + (b - a).Unit) * CFrame.Angles(0, math.pi / 2, 0) 
    end
    
    local floorMid = (c1 + c3) / 2
    local floor = makePart(color)
    floor.Size = Vector3.new(BOX_W, 0.05, BOX_D)
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
                    Window:Notify({Title = "Inventory Empty", Content = "No rockets found!"}) 
                    _G.AutoPlacing = false
                    if not SelectionBoxEnabled then clearBox() end 
                    return 
                end
                
                local cLX, cLZ = getCornerInFront() 
                drawBox(cLX, cLZ, Color3.fromRGB(255, 220, 0))
                
                local gridSlots = generateGrid(cLX, cLZ) 
                local total = #gridSlots 
                local nextIdx = 1
                
                Window:Notify({Title = "Placing Grid", Content = "Auto Place Activated!"})
                
                while _G.AutoPlacing and nextIdx <= total do
                    while nextIdx <= total and isOccupied(gridSlots[nextIdx].localX, gridSlots[nextIdx].localZ) do 
                        nextIdx = nextIdx + 1 
                    end
                    
                    if nextIdx > total then break end
                    
                    local invSlots = getRocketSlots()
                    if #invSlots == 0 then 
                        task.wait(0.5) 
                        continue 
                    end
                    
                    local gs = gridSlots[nextIdx]
                    local inv = invSlots[1]
                    
                    local ok, err = pcall(function() 
                        return PerformAction:InvokeServer("PlaceOwnedItem", { 
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
                        warn("[AutoPlace Error]: " .. tostring(err))
                        task.wait(0.3) 
                    end
                end
                
                _G.AutoPlacing = false
                if not SelectionBoxEnabled then clearBox() end
                Window:Notify({Title = "Grid Complete", Content = "Done."})
            end)
        else
            if not SelectionBoxEnabled then clearBox() end
        end
    end
})

-- =========================================================================
-- TAB 6: TELEPORTS & EXPLOITS
-- =========================================================================
local TeleportTab = Window:CreateTab("⚡ Teleports")

local function ServerHop()
    local PlaceId = game.PlaceId 
    local servers = {} 
    local req = (syn and syn.request) or (http and http_request) or request or http_request
    
    if req then
        local success, res = pcall(function() 
            return req({
                Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", PlaceId), 
                Method = "GET"
            }) 
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
TeleportTab:CreateButton({ 
    Name = "🔄 Server Hop", 
    Callback = function() ServerHop() end 
})

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
        else 
            Window:Notify({Title = "Error", Content = "Could not find a valid player."}) 
        end
    end
})

TeleportTab:CreateButton({
    Name = "👶 Teleport to Noob", 
    Callback = function()
        local _, noobData = getPlayerStats()
        if noobData and noobData.Character and noobData.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character then 
            LocalPlayer.Character:PivotTo(noobData.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)) 
        else 
            Window:Notify({Title = "Error", Content = "Could not find a valid player."}) 
        end
    end
})

task.spawn(function() 
    pcall(function() 
        Remotes:WaitForChild("ConfirmCountrySelectionEvent"):FireServer("NONE") 
    end) 
end)