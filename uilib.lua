--[[
    UILibrary.lua — Pixel-perfect CS:GO-style Roblox UI Library
    Matches the reference SVG design exactly.

    LAYOUT (from SVG):
    - Window: 597×449px equivalent proportions
    - Left sidebar: ~56px wide, dark #19202F, full height
    - Top tab bar: starts at x=56, height=56px, same dark #19202F
    - Content area: right panel, bg #161D2A, with stroke border
    - Left panels (2): stacked vertically, bg #161D2A
    - Right inner panel: #242F43 background
    - Accent color: #0094FF (bright blue)
    - Separator lines: white 4% opacity

    ELEMENTS:
    - Sidebar: icon + label buttons, 60px tall each
    - Active sidebar item: left blue accent bar
    - Tab bar: text tabs, active has blue underline + glow
    - Nav arrows: < > small square buttons
    - Search bar: right side of tabbar
    - Groups: titled cards with thin border
    - Checkboxes: square with label (the reference uses square boxes)
    - Radiobuttons: circle with filled dot
    - Dropdown: full-width with chevron
    - Scrollbar: thin right-side, small thumb
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local Library = {}
Library.__index = Library

-- ─────────────────────────────────────────────────────────
-- Theme — extracted directly from SVG hex values
-- ─────────────────────────────────────────────────────────
local T = {
    -- Backgrounds
    WindowBg      = Color3.fromRGB(20,  25,  35),   -- #141923 main window
    SidebarBg     = Color3.fromRGB(25,  32,  47),   -- #19202F sidebar + topbar
    PanelBg       = Color3.fromRGB(22,  29,  42),   -- #161D2A content panels
    InnerBg       = Color3.fromRGB(36,  47,  67),   -- #242F43 inner accent areas
    InputBg       = Color3.fromRGB(20,  27,  40),   -- slightly darker than panel

    -- Accent
    Accent        = Color3.fromRGB(0,  148, 255),   -- #0094FF
    AccentDim     = Color3.fromRGB(7,  127, 201),   -- #077FC9 (from SVG text tint)
    AccentGlow    = Color3.fromRGB(0,  100, 180),

    -- Borders
    BorderFaint   = Color3.fromRGB(255, 255, 255),  -- white at 4% opacity
    BorderAccent  = Color3.fromRGB(0,  148, 255),   -- blue border

    -- Text
    TextPrimary   = Color3.fromRGB(220, 228, 255),  -- near-white
    TextSecondary = Color3.fromRGB(150, 170, 210),  -- medium
    TextDim       = Color3.fromRGB(80,  110, 160),  -- very dim
    TextAccent    = Color3.fromRGB(0,  148, 255),   -- blue accent text
    TextActive    = Color3.fromRGB(23,  85, 131),   -- #175583 dimmed active

    -- Sidebar icons
    IconActive    = Color3.fromRGB(6,  127, 201),   -- #067FC9
    IconInactive  = Color3.fromRGB(50,  75, 120),

    -- Misc
    Separator     = Color3.fromRGB(217, 217, 217),  -- #D9D9D9 at ~17% opacity
    ScrollTrack   = Color3.fromRGB(0,   0,   0),
    ScrollThumb   = Color3.fromRGB(217, 217, 217),
    CheckboxBorder= Color3.fromRGB(200, 200, 200),  -- #C8C8C8
}

-- Tween presets
local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_MED  = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ─────────────────────────────────────────────────────────
-- Utility helpers
-- ─────────────────────────────────────────────────────────
local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Corner(p, r)
    New("UICorner", {CornerRadius = UDim.new(0, r or 4)}, p)
end

local function Stroke(p, color, thickness, transparency)
    New("UIStroke", {
        Color               = color or T.BorderFaint,
        Thickness           = thickness or 1,
        Transparency        = transparency or 0.96,   -- 4% white
        ApplyStrokeMode     = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function AccentStroke(p)
    New("UIStroke", {
        Color           = T.Accent,
        Thickness       = 1,
        Transparency    = 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function Pad(p, t, r, b, l)
    New("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft   = UDim.new(0, l or 0),
    }, p)
end

local function ListLayout(p, dir, padding, halign, valign)
    return New("UIListLayout", {
        FillDirection       = dir       or Enum.FillDirection.Vertical,
        Padding             = UDim.new(0, padding or 0),
        HorizontalAlignment = halign    or Enum.HorizontalAlignment.Left,
        VerticalAlignment   = valign    or Enum.VerticalAlignment.Top,
        SortOrder           = Enum.SortOrder.LayoutOrder,
    }, p)
end

local function MakeDraggable(handle, frame)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ─────────────────────────────────────────────────────────
-- CreateWindow
-- ─────────────────────────────────────────────────────────
function Library:CreateWindow(config)
    config = config or {}
    local W        = config.Width      or 730
    local H        = config.Height     or 500
    local SIDEBAR  = config.SidebarWidth  or 90    -- icon sidebar
    local TABBAR_H = config.TabBarHeight  or 56

    local Win = {
        _cats        = {},
        _currentCat  = nil,
        _tabs        = {},       -- flat list of all tab buttons across cats
        _currentTab  = nil,
        _tabOffset   = 0,
    }

    -- ── ScreenGui ──────────────────────────────────────────
    local ScreenGui = New("ScreenGui", {
        Name           = "UILib",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, Players.LocalPlayer:WaitForChild("PlayerGui"))

    -- ── Main window ────────────────────────────────────────
    local Main = New("Frame", {
        Name             = "Main",
        Size             = UDim2.new(0, W, 0, H),
        Position         = UDim2.new(0.5, -W/2, 0.5, -H/2),
        BackgroundColor3 = T.WindowBg,
        BorderSizePixel  = 0,
    }, ScreenGui)
    Corner(Main, 4)
    Stroke(Main, T.BorderFaint, 1, 0.96)

    -- Drag handle over topbar
    local DragBar = New("Frame", {
        Size             = UDim2.new(1, 0, 0, TABBAR_H),
        BackgroundTransparency = 1,
        ZIndex           = 20,
    }, Main)
    MakeDraggable(DragBar, Main)

    -- ── Left sidebar ───────────────────────────────────────
    -- The sidebar in SVG is a rounded rect that covers left side + clips into rounded corner
    local Sidebar = New("Frame", {
        Name             = "Sidebar",
        Size             = UDim2.new(0, SIDEBAR, 1, 0),
        Position         = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = T.SidebarBg,
        BorderSizePixel  = 0,
        ZIndex           = 3,
    }, Main)
    Corner(Sidebar, 4)

    -- Right edge border line (fake, since UIStroke would show on all sides)
    New("Frame", {
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = T.BorderFaint,
        BackgroundTransparency = 0.93,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, Sidebar)

    -- Icon list inside sidebar
    local IconList = New("Frame", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex           = 4,
    }, Sidebar)
    ListLayout(IconList, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center)
    Pad(IconList, 8, 0, 8, 0)

    -- ── Top tab bar ────────────────────────────────────────
    local TabBar = New("Frame", {
        Name             = "TabBar",
        Size             = UDim2.new(1, -SIDEBAR, 0, TABBAR_H),
        Position         = UDim2.new(0, SIDEBAR, 0, 0),
        BackgroundColor3 = T.SidebarBg,
        BorderSizePixel  = 0,
        ZIndex           = 3,
        ClipsDescendants = true,
    }, Main)
    Corner(TabBar, 4)

    -- Bottom border of tabbar
    New("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = T.BorderFaint,
        BackgroundTransparency = 0.93,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, TabBar)

    -- Tab scroll clip
    local TabClip = New("Frame", {
        Size             = UDim2.new(1, -(26+8 + 26+4 + 130+8), 1, 0),
        Position         = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex           = 4,
    }, TabBar)

    local TabContainer = New("Frame", {
        Size             = UDim2.new(10, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex           = 4,
    }, TabClip)
    ListLayout(TabContainer, Enum.FillDirection.Horizontal, 0,
        Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    -- Arrow buttons  < >
    local function ArrowBtn(lbl, xFromRight)
        local btn = New("TextButton", {
            Size             = UDim2.new(0, 26, 0, 26),
            Position         = UDim2.new(1, xFromRight, 0.5, -13),
            BackgroundColor3 = T.InnerBg,
            Text             = lbl,
            TextColor3       = T.TextSecondary,
            Font             = Enum.Font.GothamBold,
            TextSize         = 12,
            BorderSizePixel  = 0,
            ZIndex           = 5,
        }, TabBar)
        Corner(btn, 3)
        Stroke(btn, T.BorderFaint, 1, 0.9)
        return btn
    end
    local BtnPrev = ArrowBtn("<", -(26+4 + 130+8+26+4))
    local BtnNext = ArrowBtn(">", -(130+8+26+4))

    -- Search bar
    local SearchFrame = New("Frame", {
        Size             = UDim2.new(0, 130, 0, 26),
        Position         = UDim2.new(1, -(130+8), 0.5, -13),
        BackgroundColor3 = T.InputBg,
        BorderSizePixel  = 0,
        ZIndex           = 5,
    }, TabBar)
    Corner(SearchFrame, 3)
    Stroke(SearchFrame, T.BorderFaint, 1, 0.9)

    New("TextBox", {
        Size             = UDim2.new(1, -26, 1, 0),
        Position         = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text             = "",
        PlaceholderText  = "Search...",
        PlaceholderColor3= T.TextDim,
        TextColor3       = T.TextPrimary,
        Font             = Enum.Font.Gotham,
        TextSize         = 11,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex           = 6,
    }, SearchFrame)

    -- Search icon glyph (magnifier)
    New("TextLabel", {
        Size             = UDim2.new(0, 22, 1, 0),
        Position         = UDim2.new(1, -22, 0, 0),
        BackgroundTransparency = 1,
        Text             = "🔍",
        TextSize         = 11,
        TextColor3       = T.TextDim,
        ZIndex           = 6,
    }, SearchFrame)

    -- Tab scroll logic
    local TAB_W = 90
    local function ScrollTabs(dir)
        Win._tabOffset = math.max(0, Win._tabOffset + dir * TAB_W)
        TweenService:Create(TabContainer, TI_FAST,
            {Position = UDim2.new(0, -Win._tabOffset, 0, 0)}):Play()
    end
    BtnPrev.Activated:Connect(function() ScrollTabs(-1) end)
    BtnNext.Activated:Connect(function() ScrollTabs(1)  end)

    -- ── Content area ───────────────────────────────────────
    -- Everything to the right of sidebar, below tabbar
    local ContentHost = New("Frame", {
        Name             = "ContentHost",
        Size             = UDim2.new(1, -SIDEBAR, 1, -TABBAR_H),
        Position         = UDim2.new(0, SIDEBAR, 0, TABBAR_H),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex           = 2,
    }, Main)

    -- ── Internal helpers ───────────────────────────────────
    local function ShowTab(tabData)
        if Win._currentTab then
            Win._currentTab._btn.TextColor3 = T.TextSecondary
            if Win._currentTab._underline then
                Win._currentTab._underline.BackgroundTransparency = 1
            end
            Win._currentTab._content.Visible = false
        end
        Win._currentTab = tabData
        tabData._btn.TextColor3 = T.TextAccent
        if tabData._underline then
            tabData._underline.BackgroundTransparency = 0
        end
        tabData._content.Visible = true
    end

    -- ── AddCategory ───────────────────────────────────────
    function Win:AddCategory(cfg)
        cfg = cfg or {}
        local name  = cfg.Name  or "Category"
        local icon  = cfg.Icon  or "●"

        local catData = { _tabs = {}, _tabBtns = {}, _name = name }

        -- Sidebar button: 90×60, contains icon (22px) + label (10px)
        local CatBtn = New("TextButton", {
            Size             = UDim2.new(0, SIDEBAR, 0, 60),
            BackgroundColor3 = T.SidebarBg,
            BackgroundTransparency = 1,
            Text             = "",
            BorderSizePixel  = 0,
            ZIndex           = 5,
        }, IconList)
        Corner(CatBtn, 5)

        -- Hover tint
        CatBtn.MouseEnter:Connect(function()
            TweenService:Create(CatBtn, TI_FAST, {BackgroundTransparency = 0.85}):Play()
        end)
        CatBtn.MouseLeave:Connect(function()
            TweenService:Create(CatBtn, TI_FAST, {BackgroundTransparency = 1}):Play()
        end)

        -- Active left accent strip (2px, rounded)
        local Strip = New("Frame", {
            Size             = UDim2.new(0, 2, 0, 28),
            Position         = UDim2.new(0, 0, 0.5, -14),
            BackgroundColor3 = T.Accent,
            BorderSizePixel  = 0,
            BackgroundTransparency = 1,
            ZIndex           = 6,
        }, CatBtn)
        Corner(Strip, 1)

        -- Icon label
        local IconLbl = New("TextLabel", {
            Size             = UDim2.new(1, 0, 0, 26),
            Position         = UDim2.new(0, 0, 0, 10),
            BackgroundTransparency = 1,
            Text             = icon,
            TextColor3       = T.IconInactive,
            Font             = Enum.Font.GothamBold,
            TextSize         = 20,
            ZIndex           = 6,
        }, CatBtn)

        -- Name label
        local NameLbl = New("TextLabel", {
            Size             = UDim2.new(1, 0, 0, 12),
            Position         = UDim2.new(0, 0, 0, 38),
            BackgroundTransparency = 1,
            Text             = name,
            TextColor3       = T.TextDim,
            Font             = Enum.Font.Gotham,
            TextSize         = 9,
            ZIndex           = 6,
        }, CatBtn)

        catData._btn   = CatBtn
        catData._icon  = IconLbl
        catData._lbl   = NameLbl
        catData._strip = Strip
        table.insert(Win._cats, catData)

        -- Activate category
        local function ActivateCat()
            -- Deactivate all categories
            for _, c in ipairs(Win._cats) do
                TweenService:Create(c._icon, TI_FAST, {TextColor3 = T.IconInactive}):Play()
                TweenService:Create(c._lbl,  TI_FAST, {TextColor3 = T.TextDim}):Play()
                c._strip.BackgroundTransparency = 1
                for _, tb in ipairs(c._tabBtns) do tb.Visible = false end
                for _, t  in ipairs(c._tabs)    do t._content.Visible = false end
            end
            -- Activate this cat
            TweenService:Create(IconLbl, TI_FAST, {TextColor3 = T.IconActive}):Play()
            TweenService:Create(NameLbl, TI_FAST, {TextColor3 = T.TextAccent}):Play()
            Strip.BackgroundTransparency = 0
            Win._currentCat  = catData
            Win._tabOffset   = 0
            TabContainer.Position = UDim2.new(0,0,0,0)
            for _, tb in ipairs(catData._tabBtns) do tb.Visible = true end
            -- Show first tab
            if #catData._tabs > 0 then
                ShowTab(catData._tabs[1])
            else
                if Win._currentTab then
                    Win._currentTab._content.Visible = false
                    Win._currentTab = nil
                end
            end
        end

        CatBtn.Activated:Connect(ActivateCat)
        if #Win._cats == 1 then ActivateCat() end  -- auto-select first

        -- ── AddTab ────────────────────────────────────────
        function catData:AddTab(tabName)
            local Tab = { _groups = {} }

            -- Tab button in topbar
            local TBtn = New("TextButton", {
                Size             = UDim2.new(0, TAB_W, 1, 0),
                BackgroundColor3 = T.SidebarBg,
                BackgroundTransparency = 1,
                Text             = tabName,
                TextColor3       = T.TextSecondary,
                Font             = Enum.Font.GothamBold,
                TextSize         = 12,
                BorderSizePixel  = 0,
                Visible          = false,
                ZIndex           = 5,
                LayoutOrder      = #catData._tabs + 1,
            }, TabContainer)

            -- Blue underline (active indicator, 1px, accent color)
            local Underline = New("Frame", {
                Size             = UDim2.new(0.75, 0, 0, 1),
                Position         = UDim2.new(0.125, 0, 1, -1),
                BackgroundColor3 = T.Accent,
                BorderSizePixel  = 0,
                BackgroundTransparency = 1,
                ZIndex           = 6,
            }, TBtn)

            -- Gradient highlight below active tab (matches SVG blue glow rect)
            local TabGlow = New("Frame", {
                Size             = UDim2.new(1, 0, 0, 40),
                Position         = UDim2.new(0, 0, 1, -40),
                BackgroundColor3 = T.Accent,
                BackgroundTransparency = 0.83,
                BorderSizePixel  = 0,
                ZIndex           = 4,
            }, TBtn)

            -- Scroll content
            local Content = New("ScrollingFrame", {
                Size                  = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency= 1,
                ScrollBarThickness    = 3,
                ScrollBarImageColor3  = T.ScrollThumb,
                ScrollBarImageTransparency = 0.56,
                BorderSizePixel       = 0,
                Visible               = false,
                ZIndex                = 2,
            }, ContentHost)

            local ContentLayout = New("UIListLayout", {
                FillDirection       = Enum.FillDirection.Horizontal,
                Wraps               = true,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment   = Enum.VerticalAlignment.Top,
                Padding             = UDim.new(0, 6),
                SortOrder           = Enum.SortOrder.LayoutOrder,
            }, Content)
            Pad(Content, 8, 6, 8, 6)

            ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                Content.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 16)
            end)

            Tab._btn       = TBtn
            Tab._underline = Underline
            Tab._glow      = TabGlow
            Tab._content   = Content

            table.insert(catData._tabs, Tab)
            table.insert(catData._tabBtns, TBtn)

            TBtn.Activated:Connect(function() ShowTab(Tab) end)

            -- ── AddGroup (card panel) ─────────────────────
            function Tab:AddGroup(groupName, groupWidth)
                local Group = {}
                groupWidth = groupWidth or 220

                -- Outer frame — auto sizes vertically
                local GFrame = New("Frame", {
                    Size             = UDim2.new(0, groupWidth, 0, 0),
                    BackgroundColor3 = T.PanelBg,
                    BorderSizePixel  = 0,
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 3,
                }, Content)
                Corner(GFrame, 4)
                Stroke(GFrame, T.BorderFaint, 1, 0.96)

                -- Group title bar (matches SVG: small text, left-aligned, accent blue)
                local GTitle = New("TextLabel", {
                    Size             = UDim2.new(1, -16, 0, 20),
                    Position         = UDim2.new(0, 8, 0, 5),
                    BackgroundTransparency = 1,
                    Text             = groupName,
                    TextColor3       = T.AccentDim,
                    Font             = Enum.Font.Gotham,
                    TextSize         = 10,
                    TextXAlignment   = Enum.TextXAlignment.Left,
                    ZIndex           = 4,
                }, GFrame)

                -- Separator below title
                New("Frame", {
                    Size             = UDim2.new(1, -16, 0, 1),
                    Position         = UDim2.new(0, 8, 0, 26),
                    BackgroundColor3 = T.Separator,
                    BackgroundTransparency = 0.83,
                    BorderSizePixel  = 0,
                    ZIndex           = 4,
                }, GFrame)

                -- Inner content frame
                local GInner = New("Frame", {
                    Size             = UDim2.new(1, 0, 1, 0),
                    Position         = UDim2.new(0, 0, 0, 28),
                    BackgroundTransparency = 1,
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 4,
                }, GFrame)
                ListLayout(GInner, Enum.FillDirection.Vertical, 0)
                Pad(GInner, 6, 8, 8, 8)

                -- ── AddCheckbox ───────────────────────────
                -- From SVG: square checkbox (rect 12×12, stroke, filled when on)
                function Group:AddCheckbox(text, default, callback)
                    local checked = default or false

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 28),
                        BackgroundTransparency = 1,
                        ZIndex           = 5,
                    }, GInner)

                    -- Square checkbox frame
                    local Box = New("Frame", {
                        Size             = UDim2.new(0, 12, 0, 12),
                        Position         = UDim2.new(0, 0, 0.5, -6),
                        BackgroundColor3 = checked and T.Accent or T.InputBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Row)
                    Corner(Box, 2)
                    local BoxStroke = New("UIStroke", {
                        Color           = checked and T.Accent or T.CheckboxBorder,
                        Thickness       = 1,
                        Transparency    = 0,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    }, Box)

                    -- Checkmark (simple ✓)
                    local Check = New("TextLabel", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "✓",
                        TextColor3       = Color3.new(1,1,1),
                        TextSize         = 9,
                        Font             = Enum.Font.GothamBold,
                        TextTransparency = checked and 0 or 1,
                        ZIndex           = 7,
                    }, Box)

                    local Lbl = New("TextLabel", {
                        Size             = UDim2.new(1, -20, 1, 0),
                        Position         = UDim2.new(0, 18, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = text,
                        TextColor3       = checked and T.TextPrimary or T.TextSecondary,
                        Font             = Enum.Font.Gotham,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, Row)

                    local Hit = New("TextButton", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "",
                        ZIndex           = 8,
                    }, Row)

                    local function Set(v)
                        checked = v
                        TweenService:Create(Box, TI_FAST, {BackgroundColor3 = v and T.Accent or T.InputBg}):Play()
                        BoxStroke.Color = v and T.Accent or T.CheckboxBorder
                        TweenService:Create(Check, TI_FAST, {TextTransparency = v and 0 or 1}):Play()
                        Lbl.TextColor3 = v and T.TextPrimary or T.TextSecondary
                        if callback then callback(v) end
                    end

                    Hit.Activated:Connect(function() Set(not checked) end)

                    local ctrl = {}
                    function ctrl:Set(v) Set(v) end
                    function ctrl:Get() return checked end
                    return ctrl
                end

                -- ── AddRadio (circle radio button) ────────
                -- From SVG: circle 6px radius, filled dot when active
                function Group:AddRadio(text, default, callback)
                    local active = default or false

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 24),
                        BackgroundTransparency = 1,
                        ZIndex           = 5,
                    }, GInner)

                    local Outer = New("Frame", {
                        Size             = UDim2.new(0, 14, 0, 14),
                        Position         = UDim2.new(0, 0, 0.5, -7),
                        BackgroundColor3 = T.InputBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Row)
                    Corner(Outer, 7)
                    local OStroke = New("UIStroke", {
                        Color           = active and T.Accent or T.CheckboxBorder,
                        Thickness       = 1,
                        Transparency    = 0,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    }, Outer)

                    local Dot = New("Frame", {
                        Size             = UDim2.new(0, 6, 0, 6),
                        Position         = UDim2.new(0.5, -3, 0.5, -3),
                        BackgroundColor3 = T.Accent,
                        BackgroundTransparency = active and 0 or 1,
                        BorderSizePixel  = 0,
                        ZIndex           = 7,
                    }, Outer)
                    Corner(Dot, 3)

                    local Lbl = New("TextLabel", {
                        Size             = UDim2.new(1, -20, 1, 0),
                        Position         = UDim2.new(0, 20, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = text,
                        TextColor3       = active and T.TextPrimary or T.TextSecondary,
                        Font             = Enum.Font.Gotham,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, Row)

                    local Hit = New("TextButton", {
                        Size = UDim2.new(1,0,1,0),
                        BackgroundTransparency = 1, Text = "",
                        ZIndex = 8,
                    }, Row)

                    local ctrl = {}
                    function ctrl:SetState(v)
                        active = v
                        TweenService:Create(Dot, TI_FAST, {BackgroundTransparency = v and 0 or 1}):Play()
                        OStroke.Color = v and T.Accent or T.CheckboxBorder
                        Lbl.TextColor3 = v and T.TextPrimary or T.TextSecondary
                        if callback then callback(v) end
                    end
                    function ctrl:Get() return active end

                    Hit.Activated:Connect(function() ctrl:SetState(not active) end)
                    return ctrl
                end

                -- ── AddRadioGroup ─────────────────────────
                function Group:AddRadioGroup(label, options, default, callback)
                    local selected = default or options[1]

                    if label and label ~= "" then
                        New("TextLabel", {
                            Size             = UDim2.new(1, 0, 0, 18),
                            BackgroundTransparency = 1,
                            Text             = label,
                            TextColor3       = T.TextSecondary,
                            Font             = Enum.Font.GothamBold,
                            TextSize         = 10,
                            TextXAlignment   = Enum.TextXAlignment.Left,
                            ZIndex           = 5,
                        }, GInner)
                    end

                    local radios = {}

                    local function SelectOpt(opt)
                        selected = opt
                        for _, r in ipairs(radios) do
                            local on = (r.value == opt)
                            TweenService:Create(r.dot, TI_FAST, {BackgroundTransparency = on and 0 or 1}):Play()
                            r.stroke.Color = on and T.Accent or T.CheckboxBorder
                            r.lbl.TextColor3 = on and T.TextPrimary or T.TextSecondary
                        end
                        if callback then callback(opt) end
                    end

                    for _, opt in ipairs(options) do
                        local on = (opt == selected)
                        local Row = New("Frame", {
                            Size = UDim2.new(1,0,0,24),
                            BackgroundTransparency = 1,
                            ZIndex = 5,
                        }, GInner)

                        local Outer = New("Frame", {
                            Size = UDim2.new(0,14,0,14),
                            Position = UDim2.new(0,0,0.5,-7),
                            BackgroundColor3 = T.InputBg,
                            BorderSizePixel = 0, ZIndex = 6,
                        }, Row)
                        Corner(Outer, 7)
                        local OStroke = New("UIStroke", {
                            Color = on and T.Accent or T.CheckboxBorder,
                            Thickness = 1, Transparency = 0,
                            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        }, Outer)

                        local Dot = New("Frame", {
                            Size = UDim2.new(0,6,0,6),
                            Position = UDim2.new(0.5,-3,0.5,-3),
                            BackgroundColor3 = T.Accent,
                            BackgroundTransparency = on and 0 or 1,
                            BorderSizePixel = 0, ZIndex = 7,
                        }, Outer)
                        Corner(Dot, 3)

                        local Lbl = New("TextLabel", {
                            Size = UDim2.new(1,-20,1,0),
                            Position = UDim2.new(0,20,0,0),
                            BackgroundTransparency = 1,
                            Text = opt,
                            TextColor3 = on and T.TextPrimary or T.TextSecondary,
                            Font = Enum.Font.Gotham, TextSize = 11,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 6,
                        }, Row)

                        local Hit = New("TextButton", {
                            Size = UDim2.new(1,0,1,0),
                            BackgroundTransparency = 1, Text = "", ZIndex = 8,
                        }, Row)

                        table.insert(radios, {value=opt, dot=Dot, stroke=OStroke, lbl=Lbl})
                        Hit.Activated:Connect(function() SelectOpt(opt) end)
                    end

                    local ctrl = {}
                    function ctrl:Set(v) SelectOpt(v) end
                    function ctrl:Get() return selected end
                    return ctrl
                end

                -- ── AddDropdown ───────────────────────────
                -- From SVG: full-width button with chevron, expands to list below
                function Group:AddDropdown(label, options, default, callback)
                    local selected = default or options[1]
                    local open = false

                    if label and label ~= "" then
                        New("TextLabel", {
                            Size             = UDim2.new(1, 0, 0, 16),
                            BackgroundTransparency = 1,
                            Text             = label,
                            TextColor3       = T.TextSecondary,
                            Font             = Enum.Font.Gotham,
                            TextSize         = 10,
                            TextXAlignment   = Enum.TextXAlignment.Left,
                            ZIndex           = 5,
                        }, GInner)
                    end

                    -- Dropdown button frame
                    local DDBtn = New("TextButton", {
                        Size             = UDim2.new(1, 0, 0, 27),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        Text             = "",
                        ZIndex           = 5,
                    }, GInner)
                    Corner(DDBtn, 4)
                    Stroke(DDBtn, T.BorderFaint, 1, 0.88)

                    local DDLbl = New("TextLabel", {
                        Size             = UDim2.new(1, -28, 1, 0),
                        Position         = UDim2.new(0, 8, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = selected,
                        TextColor3       = T.TextPrimary,
                        Font             = Enum.Font.Gotham,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, DDBtn)

                    -- Chevron (∧ / ∨)
                    local Chev = New("TextLabel", {
                        Size             = UDim2.new(0, 20, 1, 0),
                        Position         = UDim2.new(1, -22, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = "∨",
                        TextColor3       = T.TextSecondary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 10,
                        ZIndex           = 6,
                    }, DDBtn)

                    -- Dropdown list (overlays below, high ZIndex)
                    local DDList = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, #options * 26 + 4),
                        Position         = UDim2.new(0, 0, 1, 2),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        Visible          = false,
                        ZIndex           = 30,
                        ClipsDescendants = false,
                    }, DDBtn)
                    Corner(DDList, 4)
                    AccentStroke(DDList)
                    Pad(DDList, 2, 2, 2, 2)
                    ListLayout(DDList)

                    for _, opt in ipairs(options) do
                        local isActive = (opt == selected)
                        local OptBtn = New("TextButton", {
                            Size             = UDim2.new(1, 0, 0, 26),
                            BackgroundColor3 = T.InnerBg,
                            BackgroundTransparency = 1,
                            Text             = opt,
                            TextColor3       = isActive and T.TextAccent or T.TextSecondary,
                            Font             = Enum.Font.Gotham,
                            TextSize         = 11,
                            TextXAlignment   = Enum.TextXAlignment.Left,
                            BorderSizePixel  = 0,
                            ZIndex           = 31,
                        }, DDList)
                        Pad(OptBtn, 0, 0, 0, 8)
                        Corner(OptBtn, 3)

                        -- Left accent line for selected
                        local SelBar = New("Frame", {
                            Size             = UDim2.new(0, 2, 0.6, 0),
                            Position         = UDim2.new(0, 0, 0.2, 0),
                            BackgroundColor3 = T.Accent,
                            BackgroundTransparency = isActive and 0 or 1,
                            BorderSizePixel  = 0,
                            ZIndex           = 32,
                        }, OptBtn)

                        OptBtn.MouseEnter:Connect(function()
                            if opt ~= selected then
                                TweenService:Create(OptBtn, TI_FAST, {BackgroundTransparency=0}):Play()
                            end
                        end)
                        OptBtn.MouseLeave:Connect(function()
                            if opt ~= selected then
                                TweenService:Create(OptBtn, TI_FAST, {BackgroundTransparency=1}):Play()
                            end
                        end)

                        OptBtn.Activated:Connect(function()
                            selected = opt
                            DDLbl.Text = opt
                            -- Update all option states
                            for _, child in ipairs(DDList:GetChildren()) do
                                if child:IsA("TextButton") then
                                    local sel = (child.Text == opt)
                                    child.TextColor3 = sel and T.TextAccent or T.TextSecondary
                                    for _, bar in ipairs(child:GetChildren()) do
                                        if bar:IsA("Frame") then
                                            bar.BackgroundTransparency = sel and 0 or 1
                                        end
                                    end
                                end
                            end
                            open = false
                            DDList.Visible = false
                            Chev.Text = "∨"
                            if callback then callback(opt) end
                        end)
                    end

                    DDBtn.Activated:Connect(function()
                        open = not open
                        DDList.Visible = open
                        Chev.Text = open and "∧" or "∨"
                    end)

                    local ctrl = {}
                    function ctrl:Set(v)
                        selected = v; DDLbl.Text = v
                    end
                    function ctrl:Get() return selected end
                    return ctrl
                end

                -- ── AddSlider ─────────────────────────────
                function Group:AddSlider(text, min, max, default, callback)
                    min = min or 0; max = max or 100; default = default or min
                    local value = math.clamp(default, min, max)

                    local Wrap = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 42),
                        BackgroundTransparency = 1,
                        ZIndex           = 5,
                    }, GInner)

                    -- Header row
                    local Hdr = New("Frame", {
                        Size = UDim2.new(1,0,0,16),
                        BackgroundTransparency = 1, ZIndex = 6,
                    }, Wrap)

                    New("TextLabel", {
                        Size = UDim2.new(0.7,0,1,0),
                        BackgroundTransparency=1,
                        Text=text, TextColor3=T.TextSecondary,
                        Font=Enum.Font.Gotham, TextSize=11,
                        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
                    }, Hdr)

                    local ValLbl = New("TextLabel", {
                        Size = UDim2.new(0.3,0,1,0),
                        Position = UDim2.new(0.7,0,0,0),
                        BackgroundTransparency=1,
                        Text=tostring(value), TextColor3=T.TextAccent,
                        Font=Enum.Font.GothamBold, TextSize=11,
                        TextXAlignment=Enum.TextXAlignment.Right, ZIndex=6,
                    }, Hdr)

                    -- Track
                    local Track = New("Frame", {
                        Size = UDim2.new(1,0,0,3),
                        Position = UDim2.new(0,0,0,26),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel = 0, ZIndex = 6,
                    }, Wrap)
                    Corner(Track, 2)

                    local pct0 = (value-min)/(max-min)

                    local Fill = New("Frame", {
                        Size = UDim2.new(pct0,0,1,0),
                        BackgroundColor3 = T.Accent,
                        BorderSizePixel = 0, ZIndex = 7,
                    }, Track)
                    Corner(Fill, 2)

                    local Thumb = New("Frame", {
                        Size = UDim2.new(0,9,0,9),
                        AnchorPoint = Vector2.new(0.5,0.5),
                        Position = UDim2.new(pct0,0,0.5,0),
                        BackgroundColor3 = T.Accent,
                        BorderSizePixel = 0, ZIndex = 8,
                    }, Track)
                    Corner(Thumb, 5)

                    -- Hit area
                    local Hit = New("TextButton", {
                        Size = UDim2.new(1,0,0,18),
                        Position = UDim2.new(0,0,0,22),
                        BackgroundTransparency=1, Text="", ZIndex=10,
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
                            local p   = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
                            value = math.floor(min + p*(max-min) + 0.5)
                            local np = (value-min)/(max-min)
                            Fill.Size = UDim2.new(np,0,1,0)
                            Thumb.Position = UDim2.new(np,0,0.5,0)
                            ValLbl.Text = tostring(value)
                            if callback then callback(value) end
                        end
                    end)

                    local ctrl = {}
                    function ctrl:Set(v)
                        value = math.clamp(v, min, max)
                        local np = (value-min)/(max-min)
                        Fill.Size = UDim2.new(np,0,1,0)
                        Thumb.Position = UDim2.new(np,0,0.5,0)
                        ValLbl.Text = tostring(value)
                    end
                    function ctrl:Get() return value end
                    return ctrl
                end

                -- ── AddLabel ──────────────────────────────
                function Group:AddLabel(text, color)
                    New("TextLabel", {
                        Size             = UDim2.new(1, 0, 0, 20),
                        BackgroundTransparency = 1,
                        Text             = text,
                        TextColor3       = color or T.TextPrimary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 5,
                    }, GInner)
                end

                -- ── AddSeparator ──────────────────────────
                function Group:AddSeparator()
                    New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 1),
                        BackgroundColor3 = T.Separator,
                        BackgroundTransparency = 0.83,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                end

                -- ── AddInput (text box) ───────────────────
                function Group:AddInput(placeholder, default, callback)
                    local InputFrame = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = T.InputBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(InputFrame, 3)
                    Stroke(InputFrame, T.BorderFaint, 1, 0.88)

                    local TB = New("TextBox", {
                        Size             = UDim2.new(1, -10, 1, 0),
                        Position         = UDim2.new(0, 6, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = default or "",
                        PlaceholderText  = placeholder or "",
                        PlaceholderColor3= T.TextDim,
                        TextColor3       = T.TextPrimary,
                        Font             = Enum.Font.Gotham,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ClearTextOnFocus = false,
                        ZIndex           = 6,
                    }, InputFrame)

                    TB.FocusLost:Connect(function(enter)
                        if callback then callback(TB.Text, enter) end
                    end)

                    local ctrl = {}
                    function ctrl:Set(v) TB.Text = v end
                    function ctrl:Get() return TB.Text end
                    return ctrl
                end

                table.insert(Tab._groups, Group)
                return Group
            end -- AddGroup

            return Tab
        end -- AddTab

        return catData
    end -- AddCategory

    -- ── Toggle key ────────────────────────────────────────
    function Win:SetToggleKey(keyCode)
        UserInputService.InputBegan:Connect(function(inp, gp)
            if not gp and inp.KeyCode == keyCode then
                ScreenGui.Enabled = not ScreenGui.Enabled
            end
        end)
    end

    function Win:SetEnabled(v)
        ScreenGui.Enabled = v
    end

    function Win:Destroy()
        ScreenGui:Destroy()
    end

    return Win
end

return Library


--[[
═══════════════════════════════════════════════════════════
  USAGE EXAMPLE — matches the reference screenshot exactly
═══════════════════════════════════════════════════════════

local Library = require(game.ReplicatedStorage.UILibrary)

local win = Library:CreateWindow({
    Width       = 730,
    Height      = 500,
    SidebarWidth = 90,
    TabBarHeight = 56,
})

win:SetToggleKey(Enum.KeyCode.Insert)

-- ── Sidebar categories (match SVG icons) ──────────────
local ragebot  = win:AddCategory({ Name = "Ragebot",  Icon = "⊕" })
local legitbot = win:AddCategory({ Name = "Legitbot", Icon = "◎" })
local visuals  = win:AddCategory({ Name = "Visuals",  Icon = "◈" })
local misc     = win:AddCategory({ Name = "Misc",     Icon = "≡" })
local settings = win:AddCategory({ Name = "Settings", Icon = "⚙" })

-- ── Tabs ──────────────────────────────────────────────
local aimbot    = ragebot:AddTab("Aimbot")
local trigger   = ragebot:AddTab("Triggerbot")
local weapon    = ragebot:AddTab("Weapon")
local semirage  = ragebot:AddTab("Semirage")
local other     = ragebot:AddTab("Other")

-- ── Groups (two columns side by side) ─────────────────
-- Column widths should sum to content area width - padding
local soundGrp    = semirage:AddGroup("Sound",            220)
local posGrp      = semirage:AddGroup("Position Adjustment", 220)
local antiRageGrp = semirage:AddGroup("Anti-Rage",        230)

-- ── Sound group ───────────────────────────────────────
soundGrp:AddLabel("Maximum affects visible animations")

soundGrp:AddCheckbox("No more audio", false, function(v)
    print("No more audio:", v)
end)

soundGrp:AddSeparator()

soundGrp:AddLabel("Stop when aimbot fires to lower inaccuracy")

soundGrp:AddCheckbox("Auto stop", false, function(v)
    print("Auto stop:", v)
end)

-- ── Position Adjustment group ─────────────────────────
posGrp:AddLabel("Aim at enemy history positions")

posGrp:AddCheckbox("Backtracking", false, function(v)
    print("Backtracking:", v)
end)

posGrp:AddSeparator()

posGrp:AddLabel("Improve accuracy when shooting at enemy anti-aim")

posGrp:AddCheckbox("Resolver", false, function(v)
    print("Resolver:", v)
end)

-- ── Anti-Rage group ───────────────────────────────────
antiRageGrp:AddLabel("Maximum affects visible animations")

antiRageGrp:AddRadioGroup("", {"Off", "Minimum", "Direction"}, "Direction", function(v)
    print("Anti-rage mode:", v)
end)

antiRageGrp:AddSeparator()

antiRageGrp:AddLabel("Direction")

antiRageGrp:AddDropdown(
    "Choose mode for selecting direction",
    {"Auto", "Legit", "Rage", "Maximum"},
    "Auto",
    function(v)
        print("Direction mode:", v)
    end
)

antiRageGrp:AddSeparator()

antiRageGrp:AddCheckbox("Disable On Grenade", false, function(v)
    print("Disable on grenade:", v)
end)

]]
