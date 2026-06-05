--[[
    UILibrary.lua — CS:GO-inspired Roblox UI Library
    
    Features:
    - Left icon sidebar with category icons
    - Top tab navigation with scroll arrows + search bar
    - Grouped settings panels (cards)
    - Toggle, Radio, Slider, Dropdown elements
    - Draggable window
    - Smooth tweens
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Library = {}
Library.__index = Library

-- ─────────────────────────────────────────
-- Theme
-- ─────────────────────────────────────────
local Theme = {
    -- Backgrounds
    WindowBg    = Color3.fromRGB(13, 17, 28),    -- deep navy
    SidebarBg   = Color3.fromRGB(10, 14, 23),    -- darker sidebar
    PanelBg     = Color3.fromRGB(18, 24, 38),    -- panel cards
    GroupBg     = Color3.fromRGB(22, 30, 48),    -- group containers
    TabBarBg    = Color3.fromRGB(13, 17, 28),

    -- Accents
    Accent      = Color3.fromRGB(0, 149, 255),   -- #0095FF bright blue
    AccentDim   = Color3.fromRGB(0, 80, 140),
    AccentGlow  = Color3.fromRGB(0, 100, 180),

    -- Borders
    Border      = Color3.fromRGB(30, 45, 75),
    BorderBright= Color3.fromRGB(0, 120, 220),

    -- Text
    TextPrimary = Color3.fromRGB(220, 230, 255),
    TextSecondary= Color3.fromRGB(100, 130, 180),
    TextDim     = Color3.fromRGB(60, 85, 130),
    TextActive  = Color3.fromRGB(0, 180, 255),

    -- Elements
    ElementBg   = Color3.fromRGB(25, 35, 58),
    ElementHover= Color3.fromRGB(30, 43, 70),
    InputBg     = Color3.fromRGB(15, 20, 35),

    -- Icons/Sidebar
    IconActive  = Color3.fromRGB(0, 149, 255),
    IconInactive= Color3.fromRGB(50, 75, 120),
}

local TI_FAST   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ─────────────────────────────────────────
-- Utility
-- ─────────────────────────────────────────
local function Create(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end

local function Corner(parent, radius)
    Create("UICorner", {CornerRadius = UDim.new(0, radius or 4)}, parent)
end

local function Stroke(parent, color, thickness)
    Create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function Padding(parent, top, right, bottom, left)
    Create("UIPadding", {
        PaddingTop    = UDim.new(0, top or 0),
        PaddingRight  = UDim.new(0, right or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft   = UDim.new(0, left or 0),
    }, parent)
end

local function MakeDraggable(handle, frame)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = inp.Position
            startPos = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- Accent line (top border highlight)
local function AccentLine(parent, height)
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, parent)
end

-- ─────────────────────────────────────────
-- Window
-- ─────────────────────────────────────────
function Library:CreateWindow(config)
    config = config or {}
    local title      = config.Title or "Menu"
    local width      = config.Width or 750
    local height     = config.Height or 500
    local sidebarW   = config.SidebarWidth or 90
    local tabbarH    = config.TabBarHeight or 44

    local Win = {
        _categories = {},
        _currentCat = nil,
        _tabs = {},
        _currentTab = nil,
        _tabOffset = 0,
    }

    -- Screen GUI
    local ScreenGui = Create("ScreenGui", {
        Name = "UILibrary",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, Players.LocalPlayer:WaitForChild("PlayerGui"))

    -- Main window frame
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, width, 0, height),
        Position = UDim2.new(0.5, -width/2, 0.5, -height/2),
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
    }, ScreenGui)
    Corner(MainFrame, 6)
    Stroke(MainFrame, Theme.Border, 1)

    -- Top accent line
    AccentLine(MainFrame, 1)

    -- Drag handle (invisible topbar)
    local DragHandle = Create("Frame", {
        Size = UDim2.new(1, 0, 0, tabbarH + 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
    }, MainFrame)
    MakeDraggable(DragHandle, MainFrame)

    -- ── LEFT SIDEBAR ──────────────────────
    local Sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, sidebarW, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.SidebarBg,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, MainFrame)
    Corner(Sidebar, 6)
    -- Right-side border only (fake it with a thin frame)
    Create("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, Sidebar)

    local SidebarLayout = Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        FillDirection = Enum.FillDirection.Vertical,
    }, Sidebar)
    Padding(Sidebar, 12, 0, 12, 0)

    -- ── TOP TAB BAR ───────────────────────
    local TabBar = Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -sidebarW, 0, tabbarH),
        Position = UDim2.new(0, sidebarW, 0, 0),
        BackgroundColor3 = Theme.TabBarBg,
        BorderSizePixel = 0,
    }, MainFrame)

    -- Bottom border of tabbar
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, TabBar)

    -- Tabs scroll container
    local TabScrollClip = Create("Frame", {
        Size = UDim2.new(1, -160, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, TabBar)

    local TabContainer = Create("Frame", {
        Size = UDim2.new(10, 0, 1, 0), -- wide, scrolled by offset
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
    }, TabScrollClip)

    local TabLayout = Create("UIListLayout", {
        Padding = UDim.new(0, 0),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, TabContainer)

    -- Arrow buttons
    local function ArrowBtn(symbol, xPos)
        local btn = Create("TextButton", {
            Size = UDim2.new(0, 26, 0, 26),
            Position = UDim2.new(1, xPos, 0.5, -13),
            BackgroundColor3 = Theme.ElementBg,
            Text = symbol,
            TextColor3 = Theme.TextSecondary,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            BorderSizePixel = 0,
        }, TabBar)
        Corner(btn, 4)
        Stroke(btn, Theme.Border)
        return btn
    end
    local BtnPrev = ArrowBtn("<", -120)
    local BtnNext = ArrowBtn(">", -90)

    -- Search bar
    local SearchFrame = Create("Frame", {
        Size = UDim2.new(0, 120, 0, 26),
        Position = UDim2.new(1, -80, 0.5, -13),
        BackgroundColor3 = Theme.InputBg,
        BorderSizePixel = 0,
    }, TabBar)
    Corner(SearchFrame, 4)
    Stroke(SearchFrame, Theme.Border)

    local SearchBox = Create("TextBox", {
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search...",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, SearchFrame)

    -- Search icon (magnifier dot)
    Create("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -22, 0, 0),
        BackgroundTransparency = 1,
        Text = "⌕",
        TextColor3 = Theme.TextDim,
        Font = Enum.Font.Gotham,
        TextSize = 16,
    }, SearchFrame)

    -- Tab scroll logic
    local TAB_WIDTH = 90
    local function ScrollTabs(dir)
        Win._tabOffset = math.max(0, Win._tabOffset + dir * TAB_WIDTH)
        TweenService:Create(TabContainer, TI_FAST, {
            Position = UDim2.new(0, -Win._tabOffset, 0, 0)
        }):Play()
    end
    BtnPrev.Activated:Connect(function() ScrollTabs(-1) end)
    BtnNext.Activated:Connect(function() ScrollTabs(1) end)

    -- ── CONTENT AREA ──────────────────────
    local ContentArea = Create("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -sidebarW - 10, 1, -tabbarH - 10),
        Position = UDim2.new(0, sidebarW + 5, 0, tabbarH + 5),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, MainFrame)

    -- ─────────────────────────────────────
    -- Internal: switch visible tab content
    local function ShowTab(tabData)
        if Win._currentTab then
            Win._currentTab._btn.TextColor3 = Theme.TextSecondary
            Win._currentTab._btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
            Win._currentTab._btn.BackgroundTransparency = 1
            if Win._currentTab._underline then
                Win._currentTab._underline.BackgroundTransparency = 1
            end
            Win._currentTab._content.Visible = false
        end
        Win._currentTab = tabData
        tabData._btn.TextColor3 = Theme.TextActive
        tabData._btn.BackgroundTransparency = 1
        if tabData._underline then
            tabData._underline.BackgroundTransparency = 0
        end
        tabData._content.Visible = true
    end

    -- ─────────────────────────────────────
    -- AddCategory (left sidebar icon button)
    function Win:AddCategory(config)
        config = config or {}
        local name    = config.Name or "Category"
        local icon    = config.Icon or "☰"  -- any unicode/text icon

        local catData = { _tabs = {}, _tabBtns = {} }

        local CatBtn = Create("TextButton", {
            Size = UDim2.new(0, 68, 0, 60),
            BackgroundColor3 = Theme.SidebarBg,
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
        }, Sidebar)
        Corner(CatBtn, 6)

        local IconLabel = Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28),
            Position = UDim2.new(0, 0, 0, 8),
            BackgroundTransparency = 1,
            Text = icon,
            TextColor3 = Theme.IconInactive,
            Font = Enum.Font.GothamBold,
            TextSize = 22,
        }, CatBtn)

        local NameLabel = Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            Position = UDim2.new(0, 0, 0, 36),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 10,
        }, CatBtn)

        -- Active indicator strip (left side)
        local ActiveStrip = Create("Frame", {
            Size = UDim2.new(0, 2, 0, 30),
            Position = UDim2.new(0, 0, 0.5, -15),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
        }, CatBtn)
        Corner(ActiveStrip, 2)

        -- Store cat data
        catData._btn  = CatBtn
        catData._icon = IconLabel
        catData._name = NameLabel
        catData._strip= ActiveStrip
        table.insert(Win._categories, catData)

        local function ActivateCategory()
            -- Deactivate all
            for _, c in ipairs(Win._categories) do
                TweenService:Create(c._icon, TI_FAST, {TextColor3 = Theme.IconInactive}):Play()
                TweenService:Create(c._name, TI_FAST, {TextColor3 = Theme.TextDim}):Play()
                c._strip.BackgroundTransparency = 1
                -- Hide all tab buttons from this category
                for _, tb in ipairs(c._tabBtns) do
                    tb.Visible = false
                end
                -- Hide all content
                for _, t in ipairs(c._tabs) do
                    t._content.Visible = false
                end
            end
            -- Activate this one
            TweenService:Create(IconLabel, TI_FAST, {TextColor3 = Theme.IconActive}):Play()
            TweenService:Create(NameLabel, TI_FAST, {TextColor3 = Theme.TextActive}):Play()
            ActiveStrip.BackgroundTransparency = 0
            Win._currentCat = catData
            Win._tabOffset = 0
            TabContainer.Position = UDim2.new(0, 0, 0, 0)
            -- Show tab buttons
            for _, tb in ipairs(catData._tabBtns) do
                tb.Visible = true
            end
            -- Show first tab
            if #catData._tabs > 0 then
                ShowTab(catData._tabs[1])
            end
        end

        CatBtn.Activated:Connect(ActivateCategory)

        -- Auto-activate first category
        if #Win._categories == 1 then
            ActivateCategory()
        end

        -- ─────────────────────────────────
        -- AddTab
        function catData:AddTab(tabName)
            local Tab = { _groups = {} }

            -- Tab button in topbar
            local TBtn = Create("TextButton", {
                Size = UDim2.new(0, TAB_WIDTH, 1, 0),
                BackgroundColor3 = Color3.fromRGB(0,0,0),
                BackgroundTransparency = 1,
                Text = tabName,
                TextColor3 = Theme.TextSecondary,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                BorderSizePixel = 0,
                Visible = false,
                LayoutOrder = #catData._tabs + 1,
            }, TabContainer)

            -- Underline accent
            local Underline = Create("Frame", {
                Size = UDim2.new(0.8, 0, 0, 2),
                Position = UDim2.new(0.1, 0, 1, -2),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                BackgroundTransparency = 1,
            }, TBtn)

            -- Content scroll
            local Content = Create("ScrollingFrame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.AccentDim,
                BorderSizePixel = 0,
                Visible = false,
            }, ContentArea)

            local ContentLayout = Create("UIListLayout", {
                Padding = UDim.new(0, 8),
                FillDirection = Enum.FillDirection.Horizontal,
                Wraps = true,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Top,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, Content)
            Padding(Content, 4, 4, 4, 4)

            -- Auto-resize canvas
            ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                Content.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 12)
            end)

            Tab._btn       = TBtn
            Tab._underline = Underline
            Tab._content   = Content

            table.insert(catData._tabs, Tab)
            table.insert(catData._tabBtns, TBtn)

            TBtn.Activated:Connect(function()
                ShowTab(Tab)
            end)

            -- ─────────────────────────────
            -- AddGroup (card container)
            function Tab:AddGroup(groupName, groupWidth)
                local Group = {}
                groupWidth = groupWidth or 220

                local GroupFrame = Create("Frame", {
                    Size = UDim2.new(0, groupWidth, 0, 0),
                    BackgroundColor3 = Theme.GroupBg,
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.Y,
                }, Content)
                Corner(GroupFrame, 5)
                Stroke(GroupFrame, Theme.Border)

                local GroupInner = Create("Frame", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                }, GroupFrame)
                Padding(GroupInner, 30, 8, 8, 8)

                local GLayout = Create("UIListLayout", {
                    Padding = UDim.new(0, 6),
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, GroupInner)

                -- Group title
                local GTitle = Create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.new(0, 8, 0, 6),
                    BackgroundTransparency = 1,
                    Text = groupName,
                    TextColor3 = Theme.TextActive,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, GroupFrame)

                -- Title underline
                Create("Frame", {
                    Size = UDim2.new(1, -16, 0, 1),
                    Position = UDim2.new(0, 8, 0, 26),
                    BackgroundColor3 = Theme.Border,
                    BorderSizePixel = 0,
                }, GroupFrame)

                -- ─────────────────────────
                -- AddToggle
                function Group:AddToggle(text, default, callback)
                    local toggled = default or false

                    local Row = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 32),
                        BackgroundTransparency = 1,
                    }, GroupInner)

                    -- Radio circle
                    local RadioOuter = Create("Frame", {
                        Size = UDim2.new(0, 16, 0, 16),
                        Position = UDim2.new(0, 0, 0.5, -8),
                        BackgroundColor3 = Theme.InputBg,
                        BorderSizePixel = 0,
                    }, Row)
                    Corner(RadioOuter, 8)
                    Stroke(RadioOuter, toggled and Theme.Accent or Theme.Border, 1)

                    local RadioDot = Create("Frame", {
                        Size = UDim2.new(0, 8, 0, 8),
                        Position = UDim2.new(0.5, -4, 0.5, -4),
                        BackgroundColor3 = Theme.Accent,
                        BackgroundTransparency = toggled and 0 or 1,
                        BorderSizePixel = 0,
                    }, RadioOuter)
                    Corner(RadioDot, 4)

                    local Lbl = Create("TextLabel", {
                        Size = UDim2.new(1, -24, 1, 0),
                        Position = UDim2.new(0, 22, 0, 0),
                        BackgroundTransparency = 1,
                        Text = text,
                        TextColor3 = toggled and Theme.TextPrimary or Theme.TextSecondary,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, Row)

                    local HitBtn = Create("TextButton", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "",
                    }, Row)

                    local function SetState(val)
                        toggled = val
                        TweenService:Create(RadioDot, TI_FAST, {BackgroundTransparency = val and 0 or 1}):Play()
                        local strokeColor = val and Theme.Accent or Theme.Border
                        -- Re-apply stroke
                        for _, c in ipairs(RadioOuter:GetChildren()) do
                            if c:IsA("UIStroke") then c.Color = strokeColor end
                        end
                        Lbl.TextColor3 = val and Theme.TextPrimary or Theme.TextSecondary
                        if callback then callback(val) end
                    end

                    HitBtn.Activated:Connect(function() SetState(not toggled) end)

                    -- Returns a controller
                    local ctrl = {}
                    function ctrl:Set(v) SetState(v) end
                    function ctrl:Get() return toggled end
                    return ctrl
                end

                -- ─────────────────────────
                -- AddRadioGroup
                function Group:AddRadioGroup(labelText, options, default, callback)
                    local selected = default or options[1]

                    local Section = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 0),
                        BackgroundTransparency = 1,
                        AutomaticSize = Enum.AutomaticSize.Y,
                    }, GroupInner)
                    local SLayout = Create("UIListLayout", {
                        Padding = UDim.new(0, 4),
                    }, Section)

                    -- Section sub-label
                    if labelText and labelText ~= "" then
                        Create("TextLabel", {
                            Size = UDim2.new(1, 0, 0, 18),
                            BackgroundTransparency = 1,
                            Text = labelText,
                            TextColor3 = Theme.TextSecondary,
                            Font = Enum.Font.Gotham,
                            TextSize = 11,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }, Section)
                    end

                    local radios = {}
                    local function SelectOption(opt)
                        selected = opt
                        for _, r in ipairs(radios) do
                            local active = (r.value == opt)
                            TweenService:Create(r.dot, TI_FAST, {BackgroundTransparency = active and 0 or 1}):Play()
                            for _, c in ipairs(r.outer:GetChildren()) do
                                if c:IsA("UIStroke") then
                                    c.Color = active and Theme.Accent or Theme.Border
                                end
                            end
                            r.label.TextColor3 = active and Theme.TextPrimary or Theme.TextSecondary
                        end
                        if callback then callback(opt) end
                    end

                    for _, opt in ipairs(options) do
                        local Row = Create("Frame", {
                            Size = UDim2.new(1, 0, 0, 24),
                            BackgroundTransparency = 1,
                        }, Section)
                        local isActive = (opt == selected)

                        local Outer = Create("Frame", {
                            Size = UDim2.new(0, 14, 0, 14),
                            Position = UDim2.new(0, 0, 0.5, -7),
                            BackgroundColor3 = Theme.InputBg,
                            BorderSizePixel = 0,
                        }, Row)
                        Corner(Outer, 7)
                        Stroke(Outer, isActive and Theme.Accent or Theme.Border)

                        local Dot = Create("Frame", {
                            Size = UDim2.new(0, 6, 0, 6),
                            Position = UDim2.new(0.5, -3, 0.5, -3),
                            BackgroundColor3 = Theme.Accent,
                            BackgroundTransparency = isActive and 0 or 1,
                            BorderSizePixel = 0,
                        }, Outer)
                        Corner(Dot, 3)

                        local Lbl = Create("TextLabel", {
                            Size = UDim2.new(1, -22, 1, 0),
                            Position = UDim2.new(0, 20, 0, 0),
                            BackgroundTransparency = 1,
                            Text = opt,
                            TextColor3 = isActive and Theme.TextPrimary or Theme.TextSecondary,
                            Font = Enum.Font.Gotham,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }, Row)

                        local Hit = Create("TextButton", {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = "",
                        }, Row)

                        local r = {value = opt, outer = Outer, dot = Dot, label = Lbl}
                        table.insert(radios, r)

                        Hit.Activated:Connect(function() SelectOption(opt) end)
                    end

                    local ctrl = {}
                    function ctrl:Set(v) SelectOption(v) end
                    function ctrl:Get() return selected end
                    return ctrl
                end

                -- ─────────────────────────
                -- AddSlider
                function Group:AddSlider(text, min, max, default, callback)
                    min = min or 0; max = max or 100; default = default or min
                    local value = default

                    local Wrap = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 44),
                        BackgroundTransparency = 1,
                    }, GroupInner)

                    local Header = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                    }, Wrap)

                    Create("TextLabel", {
                        Size = UDim2.new(0.7, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = text,
                        TextColor3 = Theme.TextSecondary,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, Header)

                    local ValLabel = Create("TextLabel", {
                        Size = UDim2.new(0.3, 0, 1, 0),
                        Position = UDim2.new(0.7, 0, 0, 0),
                        BackgroundTransparency = 1,
                        Text = tostring(value),
                        TextColor3 = Theme.TextActive,
                        Font = Enum.Font.GothamBold,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Right,
                    }, Header)

                    -- Track
                    local Track = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 4),
                        Position = UDim2.new(0, 0, 0, 28),
                        BackgroundColor3 = Theme.ElementBg,
                        BorderSizePixel = 0,
                    }, Wrap)
                    Corner(Track, 2)

                    local Fill = Create("Frame", {
                        Size = UDim2.new((value - min)/(max - min), 0, 1, 0),
                        BackgroundColor3 = Theme.Accent,
                        BorderSizePixel = 0,
                    }, Track)
                    Corner(Fill, 2)

                    -- Thumb
                    local Thumb = Create("Frame", {
                        Size = UDim2.new(0, 10, 0, 10),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new((value - min)/(max - min), 0, 0.5, 0),
                        BackgroundColor3 = Theme.Accent,
                        BorderSizePixel = 0,
                    }, Track)
                    Corner(Thumb, 5)

                    local Hit = Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 20),
                        Position = UDim2.new(0, 0, 0, 26),
                        BackgroundTransparency = 1,
                        Text = "",
                        ZIndex = 5,
                    }, Wrap)

                    local sliding = false
                    Hit.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            sliding = true
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            sliding = false
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(inp)
                        if sliding and inp.UserInputType == Enum.UserInputType.MouseMovement then
                            local abs = Track.AbsolutePosition
                            local sz  = Track.AbsoluteSize
                            local pct = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
                            value = math.floor(min + pct * (max - min) + 0.5)
                            local p = (value - min) / (max - min)
                            Fill.Size = UDim2.new(p, 0, 1, 0)
                            Thumb.Position = UDim2.new(p, 0, 0.5, 0)
                            ValLabel.Text = tostring(value)
                            if callback then callback(value) end
                        end
                    end)

                    local ctrl = {}
                    function ctrl:Set(v)
                        value = math.clamp(v, min, max)
                        local p = (value - min)/(max - min)
                        Fill.Size = UDim2.new(p, 0, 1, 0)
                        Thumb.Position = UDim2.new(p, 0, 0.5, 0)
                        ValLabel.Text = tostring(value)
                    end
                    function ctrl:Get() return value end
                    return ctrl
                end

                -- ─────────────────────────
                -- AddDropdown
                function Group:AddDropdown(labelText, options, default, callback)
                    local selected = default or options[1]
                    local open = false

                    local Wrap = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 0),
                        BackgroundTransparency = 1,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        ClipsDescendants = false,
                    }, GroupInner)

                    if labelText and labelText ~= "" then
                        Create("TextLabel", {
                            Size = UDim2.new(1, 0, 0, 16),
                            BackgroundTransparency = 1,
                            Text = labelText,
                            TextColor3 = Theme.TextSecondary,
                            Font = Enum.Font.Gotham,
                            TextSize = 11,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }, Wrap)
                    end

                    -- Dropdown button
                    local DDBtn = Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 28),
                        Position = UDim2.new(0, 0, 0, labelText and 18 or 0),
                        BackgroundColor3 = Theme.InputBg,
                        Text = "",
                        BorderSizePixel = 0,
                    }, Wrap)
                    Corner(DDBtn, 4)
                    Stroke(DDBtn, Theme.Border)

                    local DDLabel = Create("TextLabel", {
                        Size = UDim2.new(1, -30, 1, 0),
                        Position = UDim2.new(0, 8, 0, 0),
                        BackgroundTransparency = 1,
                        Text = selected,
                        TextColor3 = Theme.TextPrimary,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, DDBtn)

                    local Arrow = Create("TextLabel", {
                        Size = UDim2.new(0, 20, 1, 0),
                        Position = UDim2.new(1, -22, 0, 0),
                        BackgroundTransparency = 1,
                        Text = "∨",
                        TextColor3 = Theme.TextSecondary,
                        Font = Enum.Font.GothamBold,
                        TextSize = 11,
                    }, DDBtn)

                    -- Dropdown list (appears below)
                    local DDList = Create("Frame", {
                        Size = UDim2.new(1, 0, 0, #options * 26 + 4),
                        Position = UDim2.new(0, 0, 0, (labelText and 18 or 0) + 30),
                        BackgroundColor3 = Theme.InputBg,
                        BorderSizePixel = 0,
                        Visible = false,
                        ZIndex = 20,
                    }, Wrap)
                    Corner(DDList, 4)
                    Stroke(DDList, Theme.Accent)
                    Padding(DDList, 2, 2, 2, 2)

                    local DDListLayout = Create("UIListLayout", {
                        Padding = UDim.new(0, 0),
                    }, DDList)

                    for _, opt in ipairs(options) do
                        local OptBtn = Create("TextButton", {
                            Size = UDim2.new(1, 0, 0, 26),
                            BackgroundColor3 = Theme.InputBg,
                            BackgroundTransparency = 1,
                            Text = opt,
                            TextColor3 = (opt == selected) and Theme.TextActive or Theme.TextSecondary,
                            Font = Enum.Font.Gotham,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 21,
                        }, DDList)
                        Padding(OptBtn, 0, 0, 0, 8)
                        Corner(OptBtn, 3)

                        -- Accent line for selected
                        local SelLine = Create("Frame", {
                            Size = UDim2.new(0, 2, 0.6, 0),
                            Position = UDim2.new(0, 0, 0.2, 0),
                            BackgroundColor3 = Theme.Accent,
                            BorderSizePixel = 0,
                            BackgroundTransparency = (opt == selected) and 0 or 1,
                            ZIndex = 22,
                        }, OptBtn)

                        OptBtn.MouseEnter:Connect(function()
                            if opt ~= selected then
                                TweenService:Create(OptBtn, TI_FAST, {BackgroundTransparency = 0, BackgroundColor3 = Theme.ElementHover}):Play()
                            end
                        end)
                        OptBtn.MouseLeave:Connect(function()
                            if opt ~= selected then
                                TweenService:Create(OptBtn, TI_FAST, {BackgroundTransparency = 1}):Play()
                            end
                        end)

                        OptBtn.Activated:Connect(function()
                            selected = opt
                            DDLabel.Text = opt
                            -- Update all option labels
                            for _, child in ipairs(DDList:GetChildren()) do
                                if child:IsA("TextButton") then
                                    child.TextColor3 = (child.Text == opt) and Theme.TextActive or Theme.TextSecondary
                                    for _, line in ipairs(child:GetChildren()) do
                                        if line:IsA("Frame") then
                                            line.BackgroundTransparency = (child.Text == opt) and 0 or 1
                                        end
                                    end
                                end
                            end
                            open = false
                            DDList.Visible = false
                            Arrow.Text = "∨"
                            if callback then callback(opt) end
                        end)
                    end

                    DDBtn.Activated:Connect(function()
                        open = not open
                        DDList.Visible = open
                        Arrow.Text = open and "∧" or "∨"
                    end)

                    local ctrl = {}
                    function ctrl:Set(v) DDLabel.Text = v; selected = v end
                    function ctrl:Get() return selected end
                    return ctrl
                end

                -- ─────────────────────────
                -- AddLabel (section subheader)
                function Group:AddLabel(text)
                    Create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 20),
                        BackgroundTransparency = 1,
                        Text = text,
                        TextColor3 = Theme.TextPrimary,
                        Font = Enum.Font.GothamBold,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, GroupInner)
                end

                -- ─────────────────────────
                -- AddSeparator
                function Group:AddSeparator()
                    Create("Frame", {
                        Size = UDim2.new(1, 0, 0, 1),
                        BackgroundColor3 = Theme.Border,
                        BorderSizePixel = 0,
                    }, GroupInner)
                end

                table.insert(Tab._groups, Group)
                return Group
            end -- AddGroup

            return Tab
        end -- AddTab

        return catData
    end -- AddCategory

    -- Toggle window visibility with a key
    function Win:SetToggleKey(key)
        UserInputService.InputBegan:Connect(function(inp, processed)
            if not processed and inp.KeyCode == key then
                ScreenGui.Enabled = not ScreenGui.Enabled
            end
        end)
    end

    function Win:Destroy()
        ScreenGui:Destroy()
    end

    return Win
end

return Library


--[[
═══════════════════════════════════════
 USAGE EXAMPLE
═══════════════════════════════════════

local Library = require(path.to.UILibrary)

local win = Library:CreateWindow({
    Title = "Cheat Menu",
    Width = 750,
    Height = 500,
})

win:SetToggleKey(Enum.KeyCode.Insert)

-- Add sidebar categories
local ragebot = win:AddCategory({ Name = "Ragebot",  Icon = "⊕" })
local legitbot = win:AddCategory({ Name = "Legitbot", Icon = "◎" })
local visuals  = win:AddCategory({ Name = "Visuals",  Icon = "◈" })
local misc     = win:AddCategory({ Name = "Misc",     Icon = "≡" })
local settings = win:AddCategory({ Name = "Settings", Icon = "⚙" })

-- Tabs within a category
local semirage = ragebot:AddTab("Semirage")
local general  = ragebot:AddTab("General")
local accuracy = ragebot:AddTab("Accuracy")

-- Groups within a tab (side-by-side panels)
local soundGrp = semirage:AddGroup("Sound", 220)
local antiRageGrp = semirage:AddGroup("Anti-Rage", 220)

-- Elements
soundGrp:AddToggle("Maximum affects visible animations", true, function(v)
    print("Sound toggle:", v)
end)
soundGrp:AddToggle("No more audio", false, function(v) end)

soundGrp:AddSeparator()

soundGrp:AddToggle("Stop when aimbot fires to lower inaccuracy", false, function(v) end)
soundGrp:AddToggle("Auto stop", false, function(v) end)

antiRageGrp:AddLabel("Maximum affects visible animations")
antiRageGrp:AddRadioGroup("", {"Off", "Minimum", "Direction"}, "Direction", function(v)
    print("Selected:", v)
end)

antiRageGrp:AddSeparator()

antiRageGrp:AddLabel("Direction")
antiRageGrp:AddDropdown("Choose mode for selecting direction", {
    "Auto", "Legit", "Rage", "Maximum"
}, "Auto", function(v)
    print("Dropdown:", v)
end)

antiRageGrp:AddToggle("Disable On Grenade", false, function(v) end)

]]
