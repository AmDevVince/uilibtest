local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Library = {}
local Theme = {
    MainBg = Color3.fromRGB(20, 25, 35),      -- #141923
    SidebarBg = Color3.fromRGB(22, 29, 42),   -- #161D2A
    ElementBg = Color3.fromRGB(36, 47, 67),   -- #242F43
    Accent = Color3.fromRGB(6, 161, 255),     -- #06A1FF
    Text = Color3.fromRGB(255, 255, 255),
    DimText = Color3.fromRGB(150, 150, 150)
}

-- Helper to make frames draggable
local function MakeDraggable(topbar, mainFrame)
    local dragging, dragInput, dragStart, startPos
    
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function Library:CreateWindow(titleText)
    local Window = { Tabs = {}, CurrentTab = nil }
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "CustomCSGOMenu"
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 600, 0, 450)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    MainFrame.BackgroundColor3 = Theme.MainBg
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
    
    local Topbar = Instance.new("Frame")
    Topbar.Size = UDim2.new(1, 0, 0, 30)
    Topbar.BackgroundTransparency = 1
    Topbar.Parent = MainFrame
    MakeDraggable(Topbar, MainFrame)
    
    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 150, 1, 0)
    Sidebar.BackgroundColor3 = Theme.SidebarBg
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 6)
    
    local TabList = Instance.new("UIListLayout")
    TabList.Padding = UDim.new(0, 5)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.Parent = Sidebar
    Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 40)
    
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -160, 1, -20)
    ContentContainer.Position = UDim2.new(0, 155, 0, 10)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    function Window:AddTab(tabName)
        local Tab = {}
        
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(0.9, 0, 0, 35)
        TabBtn.BackgroundColor3 = Theme.MainBg
        TabBtn.Text = tabName
        TabBtn.TextColor3 = Theme.DimText
        TabBtn.Font = Enum.Font.GothamBold
        TabBtn.TextSize = 14
        TabBtn.Parent = Sidebar
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 4)
        
        local ContentScroll = Instance.new("ScrollingFrame")
        ContentScroll.Size = UDim2.new(1, 0, 1, 0)
        ContentScroll.BackgroundTransparency = 1
        ContentScroll.ScrollBarThickness = 2
        ContentScroll.Visible = false
        ContentScroll.Parent = ContentContainer
        
        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.Padding = UDim.new(0, 8)
        ContentLayout.Parent = ContentScroll
        
        TabBtn.Activated:Connect(function()
            for _, t in pairs(Window.Tabs) do
                t.Button.TextColor3 = Theme.DimText
                t.Content.Visible = false
            end
            TabBtn.TextColor3 = Theme.Accent
            ContentScroll.Visible = true
        end)
        
        if #Window.Tabs == 0 then
            TabBtn.TextColor3 = Theme.Accent
            ContentScroll.Visible = true
        end
        
        table.insert(Window.Tabs, {Button = TabBtn, Content = ContentScroll})
        
        function Tab:AddToggle(text, default, callback)
            local toggled = default or false
            
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, -10, 0, 40)
            ToggleFrame.BackgroundColor3 = Theme.ElementBg
            ToggleFrame.Parent = ContentScroll
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 4)
            
            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, -50, 1, 0)
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = text
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.Gotham
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = ToggleFrame
            
            local Indicator = Instance.new("Frame")
            Indicator.Size = UDim2.new(0, 20, 0, 20)
            Indicator.Position = UDim2.new(1, -30, 0.5, -10)
            Indicator.BackgroundColor3 = toggled and Theme.Accent or Theme.MainBg
            Indicator.Parent = ToggleFrame
            Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0) -- Circle
            
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(1, 0, 1, 0)
            Btn.BackgroundTransparency = 1
            Btn.Text = ""
            Btn.Parent = ToggleFrame
            
            Btn.Activated:Connect(function()
                toggled = not toggled
                TweenService:Create(Indicator, TweenInfo.new(0.2), {BackgroundColor3 = toggled and Theme.Accent or Theme.MainBg}):Play()
                callback(toggled)
            end)
        end
        
        return Tab
    end
    
    return Window
end

return Library
