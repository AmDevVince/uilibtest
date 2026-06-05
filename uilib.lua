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

    ELEMENTS (original):
    - Sidebar: icon + label buttons, 60px tall each
    - Active sidebar item: left blue accent bar
    - Tab bar: text tabs, active has blue underline + glow
    - Nav arrows: < > small square buttons
    - Search bar: right side of tabbar
    - Groups: titled cards with thin border
    - Checkboxes: square with label
    - Radiobuttons: circle with filled dot
    - Dropdown: full-width with chevron
    - Scrollbar: thin right-side, small thumb

    ADDED (ported from Orion Library, CS:GO-themed):
    - AddToggle:      Named toggle with animated colored icon box + Flag support
    - AddButton:      Clickable row with hover/press highlight
    - AddParagraph:   Title + wrapping body text, auto-sizes
    - AddBind:        Keybind picker row — click then press a key
    - AddColorpicker: Full HSV color picker (saturation field + hue bar)
    - AddSection:     Labelled sub-section inside a tab's content area
    - MakeNotification: Animated toast notification (bottom-right corner)
    - Flags system:   Global registry; Flag + Save on Toggle/Slider/Dropdown/Bind/Colorpicker
    - AddTextbox:     Improved text input with click-to-focus & auto-sizing container
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

local Library = {
    Flags       = {},   -- global flag registry  {flagName = controlObject}
    Connections = {},   -- for cleanup
}
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
    AccentDim     = Color3.fromRGB(7,  127, 201),   -- #077FC9
    AccentGlow    = Color3.fromRGB(0,  100, 180),

    -- Borders
    BorderFaint   = Color3.fromRGB(255, 255, 255),  -- white at 4% opacity
    BorderAccent  = Color3.fromRGB(0,  148, 255),

    -- Text
    TextPrimary   = Color3.fromRGB(220, 228, 255),
    TextSecondary = Color3.fromRGB(150, 170, 210),
    TextDim       = Color3.fromRGB(80,  110, 160),
    TextAccent    = Color3.fromRGB(0,  148, 255),
    TextActive    = Color3.fromRGB(23,  85, 131),

    -- Sidebar icons
    IconActive    = Color3.fromRGB(6,  127, 201),
    IconInactive  = Color3.fromRGB(50,  75, 120),

    -- Misc
    Separator     = Color3.fromRGB(217, 217, 217),
    ScrollTrack   = Color3.fromRGB(0,   0,   0),
    ScrollThumb   = Color3.fromRGB(217, 217, 217),
    CheckboxBorder= Color3.fromRGB(200, 200, 200),

    -- Toggle highlight colors (used by AddToggle; accent-tinted)
    ToggleOn      = Color3.fromRGB(0,  148, 255),   -- same as Accent
    ToggleDimBg   = Color3.fromRGB(36,  47,  67),   -- InnerBg when off
}

-- Tween presets
local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_MED  = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_SLOW = TweenInfo.new(0.3,  Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Keycodes that cannot be used as binds (same blacklist as Orion)
local BlacklistedKeys = {
    Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S,
    Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down,
    Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab,
    Enum.KeyCode.Backspace, Enum.KeyCode.Escape,
}
local WhitelistedMouse = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3,
}

local function CheckKey(tbl, key)
    for _, v in next, tbl do
        if v == key then return true end
    end
end

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
        Transparency        = transparency or 0.96,
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

-- Row hover/press highlight helper (used by Button, Toggle, Bind, Textbox, Colorpicker)
local function WireRowHover(btn, frame)
    local base = T.InnerBg
    btn.MouseEnter:Connect(function()
        TweenService:Create(frame, TI_FAST, {BackgroundColor3 =
            Color3.fromRGB(base.R*255+6, base.G*255+6, base.B*255+6)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(frame, TI_FAST, {BackgroundColor3 = base}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(frame, TI_FAST, {BackgroundColor3 =
            Color3.fromRGB(base.R*255+12, base.G*255+12, base.B*255+12)}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(frame, TI_FAST, {BackgroundColor3 =
            Color3.fromRGB(base.R*255+6, base.G*255+6, base.B*255+6)}):Play()
    end)
end

-- ─────────────────────────────────────────────────────────
-- MakeNotification  (toast, bottom-right of screen)
-- ─────────────────────────────────────────────────────────
-- Stored here so it can be called before a window exists.
local _notifGui   -- lazily created ScreenGui
local _notifHolder

local function EnsureNotifGui()
    if _notifGui and _notifGui.Parent then return end
    _notifGui = New("ScreenGui", {
        Name           = "UILibNotif",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, LocalPlayer:WaitForChild("PlayerGui"))

    _notifHolder = New("Frame", {
        Size             = UDim2.new(0, 300, 1, -25),
        Position         = UDim2.new(1, -25, 1, -25),
        AnchorPoint      = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        ZIndex           = 100,
    }, _notifGui)
    local nl = ListLayout(_notifHolder, Enum.FillDirection.Vertical, 5,
        Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
    nl.VerticalAlignment = Enum.VerticalAlignment.Bottom
end

function Library:MakeNotification(cfg)
    EnsureNotifGui()
    cfg = cfg or {}
    cfg.Name    = cfg.Name    or "Notification"
    cfg.Content = cfg.Content or ""
    cfg.Time    = cfg.Time    or 5

    spawn(function()
        -- Wrapper (for list layout)
        local Wrapper = New("Frame", {
            Size             = UDim2.new(1, 0, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex           = 100,
        }, _notifHolder)

        -- Card
        local Card = New("Frame", {
            Size             = UDim2.new(1, 0, 0, 0),
            Position         = UDim2.new(1, 20, 0, 0),   -- starts off-screen right
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.SidebarBg,
            BorderSizePixel  = 0,
            ZIndex           = 100,
        }, Wrapper)
        Corner(Card, 4)
        Stroke(Card, T.Accent, 1, 0.7)
        Pad(Card, 10, 12, 10, 12)

        local layout = ListLayout(Card, Enum.FillDirection.Vertical, 4)

        -- Title row
        local TitleRow = New("Frame", {
            Size             = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            ZIndex           = 101,
        }, Card)

        -- Blue left accent bar on card
        New("Frame", {
            Size             = UDim2.new(0, 2, 1, 0),
            BackgroundColor3 = T.Accent,
            BorderSizePixel  = 0,
            ZIndex           = 102,
        }, TitleRow)

        New("TextLabel", {
            Size             = UDim2.new(1, -8, 1, 0),
            Position         = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text             = cfg.Name,
            TextColor3       = T.TextPrimary,
            Font             = Enum.Font.GothamBold,
            TextSize         = 12,
            TextXAlignment   = Enum.TextXAlignment.Left,
            ZIndex           = 102,
        }, TitleRow)

        -- Body text
        local Body = New("TextLabel", {
            Size             = UDim2.new(1, 0, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text             = cfg.Content,
            TextColor3       = T.TextSecondary,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextWrapped      = true,
            ZIndex           = 101,
        }, Card)

        -- Slide in
        TweenService:Create(Card, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 0, 0, 0)}):Play()

        wait(cfg.Time - 0.5)

        -- Fade + slide out
        TweenService:Create(Card, TI_MED, {BackgroundTransparency = 0.7}):Play()
        TweenService:Create(Body, TI_MED, {TextTransparency = 0.6}):Play()
        wait(0.25)
        TweenService:Create(Card, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 20, 0, 0)}):Play()
        wait(0.55)
        Wrapper:Destroy()
    end)
end

-- ─────────────────────────────────────────────────────────
-- CreateWindow
-- ─────────────────────────────────────────────────────────
function Library:CreateWindow(config)
    config = config or {}
    local W        = config.Width       or 730
    local H        = config.Height      or 500
    local SIDEBAR  = config.SidebarWidth  or 90
    local TABBAR_H = config.TabBarHeight  or 56

    local Win = {
        _cats        = {},
        _currentCat  = nil,
        _tabs        = {},
        _currentTab  = nil,
        _tabOffset   = 0,
    }

    -- ── ScreenGui ──────────────────────────────────────────
    local ScreenGui = New("ScreenGui", {
        Name           = "UILib",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, LocalPlayer:WaitForChild("PlayerGui"))

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

    local DragBar = New("Frame", {
        Size             = UDim2.new(1, 0, 0, TABBAR_H),
        BackgroundTransparency = 1,
        ZIndex           = 20,
    }, Main)
    MakeDraggable(DragBar, Main)

    -- ── Left sidebar ───────────────────────────────────────
    local Sidebar = New("Frame", {
        Name             = "Sidebar",
        Size             = UDim2.new(0, SIDEBAR, 1, 0),
        Position         = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = T.SidebarBg,
        BorderSizePixel  = 0,
        ZIndex           = 3,
    }, Main)
    Corner(Sidebar, 4)

    New("Frame", {
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = T.BorderFaint,
        BackgroundTransparency = 0.93,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, Sidebar)

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

    New("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = T.BorderFaint,
        BackgroundTransparency = 0.93,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, TabBar)

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

    New("TextLabel", {
        Size             = UDim2.new(0, 22, 1, 0),
        Position         = UDim2.new(1, -22, 0, 0),
        BackgroundTransparency = 1,
        Text             = "🔍",
        TextSize         = 11,
        TextColor3       = T.TextDim,
        ZIndex           = 6,
    }, SearchFrame)

    local TAB_W = 90
    local function ScrollTabs(dir)
        Win._tabOffset = math.max(0, Win._tabOffset + dir * TAB_W)
        TweenService:Create(TabContainer, TI_FAST,
            {Position = UDim2.new(0, -Win._tabOffset, 0, 0)}):Play()
    end
    BtnPrev.Activated:Connect(function() ScrollTabs(-1) end)
    BtnNext.Activated:Connect(function() ScrollTabs(1)  end)

    -- ── Content area ───────────────────────────────────────
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

        local CatBtn = New("TextButton", {
            Size             = UDim2.new(0, SIDEBAR, 0, 60),
            BackgroundColor3 = T.SidebarBg,
            BackgroundTransparency = 1,
            Text             = "",
            BorderSizePixel  = 0,
            ZIndex           = 5,
        }, IconList)
        Corner(CatBtn, 5)

        CatBtn.MouseEnter:Connect(function()
            TweenService:Create(CatBtn, TI_FAST, {BackgroundTransparency = 0.85}):Play()
        end)
        CatBtn.MouseLeave:Connect(function()
            TweenService:Create(CatBtn, TI_FAST, {BackgroundTransparency = 1}):Play()
        end)

        local Strip = New("Frame", {
            Size             = UDim2.new(0, 2, 0, 28),
            Position         = UDim2.new(0, 0, 0.5, -14),
            BackgroundColor3 = T.Accent,
            BorderSizePixel  = 0,
            BackgroundTransparency = 1,
            ZIndex           = 6,
        }, CatBtn)
        Corner(Strip, 1)

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

        local function ActivateCat()
            for _, c in ipairs(Win._cats) do
                TweenService:Create(c._icon, TI_FAST, {TextColor3 = T.IconInactive}):Play()
                TweenService:Create(c._lbl,  TI_FAST, {TextColor3 = T.TextDim}):Play()
                c._strip.BackgroundTransparency = 1
                for _, tb in ipairs(c._tabBtns) do tb.Visible = false end
                for _, t  in ipairs(c._tabs)    do t._content.Visible = false end
            end
            TweenService:Create(IconLbl, TI_FAST, {TextColor3 = T.IconActive}):Play()
            TweenService:Create(NameLbl, TI_FAST, {TextColor3 = T.TextAccent}):Play()
            Strip.BackgroundTransparency = 0
            Win._currentCat  = catData
            Win._tabOffset   = 0
            TabContainer.Position = UDim2.new(0,0,0,0)
            for _, tb in ipairs(catData._tabBtns) do tb.Visible = true end
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
        if #Win._cats == 1 then ActivateCat() end

        -- ── AddTab ────────────────────────────────────────
        function catData:AddTab(tabName)
            local Tab = { _groups = {} }

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

            local Underline = New("Frame", {
                Size             = UDim2.new(0.75, 0, 0, 1),
                Position         = UDim2.new(0.125, 0, 1, -1),
                BackgroundColor3 = T.Accent,
                BorderSizePixel  = 0,
                BackgroundTransparency = 1,
                ZIndex           = 6,
            }, TBtn)

            New("Frame", {
                Size             = UDim2.new(1, 0, 0, 40),
                Position         = UDim2.new(0, 0, 1, -40),
                BackgroundColor3 = T.Accent,
                BackgroundTransparency = 0.83,
                BorderSizePixel  = 0,
                ZIndex           = 4,
            }, TBtn)

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
            Tab._content   = Content

            table.insert(catData._tabs, Tab)
            table.insert(catData._tabBtns, TBtn)

            TBtn.Activated:Connect(function() ShowTab(Tab) end)

            -- ── AddGroup (card panel) ─────────────────────
            function Tab:AddGroup(groupName, groupWidth)
                local Group = {}
                groupWidth = groupWidth or 220

                local GFrame = New("Frame", {
                    Size             = UDim2.new(0, groupWidth, 0, 0),
                    BackgroundColor3 = T.PanelBg,
                    BorderSizePixel  = 0,
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 3,
                }, Content)
                Corner(GFrame, 4)
                Stroke(GFrame, T.BorderFaint, 1, 0.96)

                New("TextLabel", {
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

                New("Frame", {
                    Size             = UDim2.new(1, -16, 0, 1),
                    Position         = UDim2.new(0, 8, 0, 26),
                    BackgroundColor3 = T.Separator,
                    BackgroundTransparency = 0.83,
                    BorderSizePixel  = 0,
                    ZIndex           = 4,
                }, GFrame)

                local GInner = New("Frame", {
                    Size             = UDim2.new(1, 0, 1, 0),
                    Position         = UDim2.new(0, 0, 0, 28),
                    BackgroundTransparency = 1,
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 4,
                }, GFrame)
                ListLayout(GInner, Enum.FillDirection.Vertical, 0)
                Pad(GInner, 6, 8, 8, 8)

                -- ============================================================
                -- ── AddCheckbox ──────────────────────────────────────────────
                -- ============================================================
                function Group:AddCheckbox(text, default, callback)
                    local checked = default or false

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 28),
                        BackgroundTransparency = 1,
                        ZIndex           = 5,
                    }, GInner)

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

                -- ============================================================
                -- ── AddToggle  (Orion-style: named row + animated icon box) ──
                -- ============================================================
                function Group:AddToggle(cfg2)
                    cfg2 = cfg2 or {}
                    local label    = cfg2.Name     or "Toggle"
                    local default  = cfg2.Default  or false
                    local callback = cfg2.Callback or function() end
                    local color    = cfg2.Color    or T.ToggleOn
                    local flag     = cfg2.Flag
                    local save     = cfg2.Save     or false

                    local Toggle = {Value = default, Type = "Toggle", Save = save}

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 34),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(Row, 3)
                    Stroke(Row, T.BorderFaint, 1, 0.92)

                    New("TextLabel", {
                        Size             = UDim2.new(1, -44, 1, 0),
                        Position         = UDim2.new(0, 10, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = label,
                        TextColor3       = T.TextSecondary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, Row)

                    -- Animated icon box (right side)
                    local Box = New("Frame", {
                        Size             = UDim2.new(0, 22, 0, 22),
                        Position         = UDim2.new(1, -10, 0.5, 0),
                        AnchorPoint      = Vector2.new(1, 0.5),
                        BackgroundColor3 = default and color or T.InputBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Row)
                    Corner(Box, 3)
                    local BoxStroke = New("UIStroke", {
                        Color           = default and color or T.CheckboxBorder,
                        Thickness       = 1,
                        Transparency    = default and 0.5 or 0,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        Name            = "Stroke",
                    }, Box)

                    -- Check icon inside box (scales in/out on toggle)
                    local Ico = New("TextLabel", {
                        Size             = UDim2.new(0, default and 16 or 6, 0, default and 16 or 6),
                        AnchorPoint      = Vector2.new(0.5, 0.5),
                        Position         = UDim2.new(0.5, 0, 0.5, 0),
                        BackgroundTransparency = 1,
                        Text             = "✓",
                        TextColor3       = Color3.new(1,1,1),
                        TextSize         = default and 13 or 0,
                        Font             = Enum.Font.GothamBold,
                        TextTransparency = default and 0 or 1,
                        ZIndex           = 7,
                    }, Box)

                    local Hit = New("TextButton", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "",
                        ZIndex           = 8,
                    }, Row)

                    WireRowHover(Hit, Row)

                    function Toggle:Set(v)
                        Toggle.Value = v
                        TweenService:Create(Box, TI_SLOW, {BackgroundColor3 = v and color or T.InputBg}):Play()
                        TweenService:Create(BoxStroke, TI_SLOW, {Color = v and color or T.CheckboxBorder, Transparency = v and 0.5 or 0}):Play()
                        TweenService:Create(Ico, TI_SLOW, {
                            TextTransparency = v and 0 or 1,
                            TextSize         = v and 13 or 0,
                        }):Play()
                        callback(v)
                    end

                    Hit.Activated:Connect(function()
                        Toggle:Set(not Toggle.Value)
                    end)

                    if flag then Library.Flags[flag] = Toggle end
                    return Toggle
                end

                -- ============================================================
                -- ── AddRadio ─────────────────────────────────────────────────
                -- ============================================================
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

                -- ============================================================
                -- ── AddRadioGroup ─────────────────────────────────────────────
                -- ============================================================
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

                -- ============================================================
                -- ── AddDropdown ───────────────────────────────────────────────
                -- ============================================================
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
                    function ctrl:Set(v) selected = v; DDLbl.Text = v end
                    function ctrl:Get() return selected end
                    return ctrl
                end

                -- ============================================================
                -- ── AddSlider ─────────────────────────────────────────────────
                -- ============================================================
                function Group:AddSlider(cfg2, ...)
                    -- Support both old API: AddSlider(text, min, max, default, cb)
                    -- and new table API: AddSlider({Name, Min, Max, Default, Increment, Callback, Flag, Save})
                    local text, min, max, default, callback, increment, flag, save
                    if type(cfg2) == "table" then
                        text      = cfg2.Name      or "Slider"
                        min       = cfg2.Min       or 0
                        max       = cfg2.Max       or 100
                        default   = cfg2.Default   or min
                        increment = cfg2.Increment or 1
                        callback  = cfg2.Callback  or function() end
                        flag      = cfg2.Flag
                        save      = cfg2.Save      or false
                    else
                        local args = {...}
                        text      = cfg2
                        min       = args[1] or 0
                        max       = args[2] or 100
                        default   = args[3] or min
                        callback  = args[4]
                        increment = 1
                    end
                    min     = min     or 0
                    max     = max     or 100
                    default = math.clamp(default or min, min, max)
                    local value = default

                    local Slider = {Value = value, Type = "Slider", Save = save}

                    local Wrap = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 42),
                        BackgroundTransparency = 1,
                        ZIndex           = 5,
                    }, GInner)

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

                    local function Round(n, factor)
                        factor = factor or 1
                        return math.floor(n/factor + 0.5) * factor
                    end

                    UserInputService.InputChanged:Connect(function(inp)
                        if sliding and inp.UserInputType == Enum.UserInputType.MouseMovement then
                            local abs = Track.AbsolutePosition
                            local sz  = Track.AbsoluteSize
                            local p   = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
                            value = math.clamp(Round(min + p*(max-min), increment), min, max)
                            local np = (value-min)/(max-min)
                            Fill.Size = UDim2.new(np,0,1,0)
                            Thumb.Position = UDim2.new(np,0,0.5,0)
                            ValLbl.Text = tostring(value)
                            Slider.Value = value
                            if callback then callback(value) end
                        end
                    end)

                    function Slider:Set(v)
                        value = math.clamp(Round(v, increment), min, max)
                        self.Value = value
                        local np = (value-min)/(max-min)
                        TweenService:Create(Fill, TI_FAST, {Size = UDim2.new(np,0,1,0)}):Play()
                        Thumb.Position = UDim2.new(np,0,0.5,0)
                        ValLbl.Text = tostring(value)
                        if callback then callback(value) end
                    end
                    function Slider:Get() return value end

                    if flag then Library.Flags[flag] = Slider end
                    return Slider
                end

                -- ============================================================
                -- ── AddButton  (Orion-style clickable row) ────────────────────
                -- ============================================================
                function Group:AddButton(cfg2)
                    cfg2 = cfg2 or {}
                    local label    = cfg2.Name     or "Button"
                    local callback = cfg2.Callback or function() end
                    local Button   = {}

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 32),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(Row, 3)
                    Stroke(Row, T.BorderFaint, 1, 0.92)

                    local ContentLbl = New("TextLabel", {
                        Size             = UDim2.new(1, -16, 1, 0),
                        Position         = UDim2.new(0, 10, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = label,
                        TextColor3       = T.TextPrimary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                        Name             = "Content",
                    }, Row)

                    -- Small arrow indicator on right edge
                    New("TextLabel", {
                        Size             = UDim2.new(0, 18, 1, 0),
                        Position         = UDim2.new(1, -20, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = "›",
                        TextColor3       = T.TextDim,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 14,
                        ZIndex           = 6,
                    }, Row)

                    local Hit = New("TextButton", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "",
                        ZIndex           = 7,
                    }, Row)

                    WireRowHover(Hit, Row)
                    Hit.Activated:Connect(function()
                        spawn(callback)
                    end)

                    function Button:Set(text)
                        ContentLbl.Text = text
                    end
                    return Button
                end

                -- ============================================================
                -- ── AddLabel ──────────────────────────────────────────────────
                -- ============================================================
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

                -- ============================================================
                -- ── AddParagraph  (Orion-style title + body block) ─────────────
                -- ============================================================
                function Group:AddParagraph(title, body)
                    title = title or ""
                    body  = body  or ""

                    local PFrame = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 30),
                        BackgroundColor3 = T.InputBg,
                        BorderSizePixel  = 0,
                        AutomaticSize    = Enum.AutomaticSize.Y,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(PFrame, 3)
                    Stroke(PFrame, T.BorderFaint, 1, 0.92)
                    Pad(PFrame, 6, 8, 6, 8)

                    local layout = ListLayout(PFrame, Enum.FillDirection.Vertical, 3)

                    New("TextLabel", {
                        Size             = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text             = title,
                        TextColor3       = T.TextPrimary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                        Name             = "Title",
                    }, PFrame)

                    local BodyLbl = New("TextLabel", {
                        Size             = UDim2.new(1, 0, 0, 0),
                        AutomaticSize    = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1,
                        Text             = body,
                        TextColor3       = T.TextSecondary,
                        Font             = Enum.Font.Gotham,
                        TextSize         = 10,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        TextWrapped      = true,
                        ZIndex           = 6,
                        Name             = "Content",
                    }, PFrame)

                    local pf = {}
                    function pf:Set(newBody)
                        BodyLbl.Text = newBody
                    end
                    return pf
                end

                -- ============================================================
                -- ── AddSeparator ──────────────────────────────────────────────
                -- ============================================================
                function Group:AddSeparator()
                    New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 1),
                        BackgroundColor3 = T.Separator,
                        BackgroundTransparency = 0.83,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                end

                -- ============================================================
                -- ── AddInput  (improved from original; click-to-focus) ─────────
                -- ============================================================
                function Group:AddInput(cfg2, ...)
                    -- Support old API: AddInput(placeholder, default, callback)
                    local placeholder, default, callback
                    if type(cfg2) == "table" then
                        placeholder = cfg2.Name        or cfg2.Placeholder or ""
                        default     = cfg2.Default     or ""
                        callback    = cfg2.Callback    or function() end
                    else
                        placeholder = cfg2
                        local args  = {...}
                        default     = args[1] or ""
                        callback    = args[2]
                    end

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 32),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(Row, 3)
                    Stroke(Row, T.BorderFaint, 1, 0.92)

                    New("TextLabel", {
                        Size             = UDim2.new(0.45, -8, 1, 0),
                        Position         = UDim2.new(0, 10, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = placeholder,
                        TextColor3       = T.TextSecondary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, Row)

                    -- Right-side text container (auto-sizes like Orion)
                    local TCont = New("Frame", {
                        Size             = UDim2.new(0, 60, 0, 22),
                        Position         = UDim2.new(1, -10, 0.5, 0),
                        AnchorPoint      = Vector2.new(1, 0.5),
                        BackgroundColor3 = T.InputBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Row)
                    Corner(TCont, 3)
                    Stroke(TCont, T.BorderFaint, 1, 0.88)

                    local TB = New("TextBox", {
                        Size             = UDim2.new(1, -8, 1, 0),
                        Position         = UDim2.new(0, 4, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = default or "",
                        PlaceholderText  = "...",
                        PlaceholderColor3= T.TextDim,
                        TextColor3       = T.TextPrimary,
                        Font             = Enum.Font.Gotham,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Center,
                        ClearTextOnFocus = false,
                        ZIndex           = 7,
                    }, TCont)

                    -- Auto-size container to text
                    TB:GetPropertyChangedSignal("Text"):Connect(function()
                        local newW = math.max(40, TB.TextBounds.X + 16)
                        TweenService:Create(TCont, TweenInfo.new(0.2, Enum.EasingStyle.Quint),
                            {Size = UDim2.new(0, newW, 0, 22)}):Play()
                    end)

                    -- Click anywhere on row to focus box
                    local Hit = New("TextButton", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "",
                        ZIndex           = 8,
                    }, Row)
                    Hit.MouseButton1Up:Connect(function()
                        TB:CaptureFocus()
                    end)
                    WireRowHover(Hit, Row)

                    TB.FocusLost:Connect(function(enter)
                        if callback then callback(TB.Text, enter) end
                    end)

                    local ctrl = {}
                    function ctrl:Set(v) TB.Text = v end
                    function ctrl:Get() return TB.Text end
                    return ctrl
                end

                -- ============================================================
                -- ── AddTextbox  (Orion-style alias — same as AddInput) ─────────
                -- ============================================================
                Group.AddTextbox = Group.AddInput

                -- ============================================================
                -- ── AddBind  (keybind picker) ─────────────────────────────────
                -- ============================================================
                function Group:AddBind(cfg2)
                    cfg2 = cfg2 or {}
                    local label    = cfg2.Name     or "Bind"
                    local default  = cfg2.Default  or Enum.KeyCode.Unknown
                    local hold     = cfg2.Hold     or false
                    local callback = cfg2.Callback or function() end
                    local flag     = cfg2.Flag
                    local save     = cfg2.Save     or false

                    local Bind = {Value = nil, Binding = false, Type = "Bind", Save = save}
                    local Holding = false

                    local Row = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 32),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(Row, 3)
                    Stroke(Row, T.BorderFaint, 1, 0.92)

                    New("TextLabel", {
                        Size             = UDim2.new(1, -80, 1, 0),
                        Position         = UDim2.new(0, 10, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = label,
                        TextColor3       = T.TextSecondary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, Row)

                    -- Key badge (right side, auto-sizes)
                    local Badge = New("Frame", {
                        Size             = UDim2.new(0, 36, 0, 20),
                        Position         = UDim2.new(1, -10, 0.5, 0),
                        AnchorPoint      = Vector2.new(1, 0.5),
                        BackgroundColor3 = T.InputBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Row)
                    Corner(Badge, 3)
                    Stroke(Badge, T.BorderFaint, 1, 0.88)

                    local KeyLbl = New("TextLabel", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "...",
                        TextColor3       = T.TextAccent,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 10,
                        TextXAlignment   = Enum.TextXAlignment.Center,
                        ZIndex           = 7,
                        Name             = "Value",
                    }, Badge)

                    -- Auto-size badge
                    KeyLbl:GetPropertyChangedSignal("Text"):Connect(function()
                        TweenService:Create(Badge, TweenInfo.new(0.18, Enum.EasingStyle.Quint),
                            {Size = UDim2.new(0, math.max(30, KeyLbl.TextBounds.X + 14), 0, 20)}):Play()
                    end)

                    local Hit = New("TextButton", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "",
                        ZIndex           = 8,
                    }, Row)

                    WireRowHover(Hit, Row)

                    -- Click row → enter binding mode
                    Hit.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            if Bind.Binding then return end
                            Bind.Binding = true
                            KeyLbl.Text = "..."
                            KeyLbl.TextColor3 = T.TextSecondary
                        end
                    end)

                    UserInputService.InputBegan:Connect(function(inp)
                        if UserInputService:GetFocusedTextBox() then return end
                        if (inp.KeyCode.Name == Bind.Value or
                           (inp.UserInputType and inp.UserInputType.Name == Bind.Value))
                           and not Bind.Binding then
                            if hold then
                                Holding = true
                                callback(Holding)
                            else
                                callback()
                            end
                        elseif Bind.Binding then
                            local Key
                            pcall(function()
                                if not CheckKey(BlacklistedKeys, inp.KeyCode) then
                                    Key = inp.KeyCode
                                end
                            end)
                            pcall(function()
                                if CheckKey(WhitelistedMouse, inp.UserInputType) and not Key then
                                    Key = inp.UserInputType
                                end
                            end)
                            Key = Key or default
                            Bind:Set(Key)
                        end
                    end)

                    UserInputService.InputEnded:Connect(function(inp)
                        if inp.KeyCode.Name == Bind.Value or
                           (inp.UserInputType and inp.UserInputType.Name == Bind.Value) then
                            if hold and Holding then
                                Holding = false
                                callback(Holding)
                            end
                        end
                    end)

                    function Bind:Set(key)
                        Bind.Binding = false
                        Bind.Value   = key or Bind.Value
                        Bind.Value   = (type(Bind.Value) ~= "string" and Bind.Value.Name) or Bind.Value
                        KeyLbl.Text  = Bind.Value
                        KeyLbl.TextColor3 = T.TextAccent
                    end

                    Bind:Set(default)
                    if flag then Library.Flags[flag] = Bind end
                    return Bind
                end

                -- ============================================================
                -- ── AddColorpicker  (HSV picker: saturation field + hue bar) ───
                -- ============================================================
                function Group:AddColorpicker(cfg2)
                    cfg2 = cfg2 or {}
                    local label    = cfg2.Name     or "Color"
                    local default  = cfg2.Default  or Color3.fromRGB(255, 255, 255)
                    local callback = cfg2.Callback or function() end
                    local flag     = cfg2.Flag
                    local save     = cfg2.Save     or false

                    local ColorH, ColorS, ColorV = Color3.toHSV(default)
                    local Colorpicker = {Value = default, Toggled = false, Type = "Colorpicker", Save = save}

                    -- ── Header row (always visible) ───────────────────────
                    local Header = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 30),
                        BackgroundColor3 = T.InnerBg,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(Header, 3)
                    Stroke(Header, T.BorderFaint, 1, 0.92)

                    New("TextLabel", {
                        Size             = UDim2.new(1, -44, 1, 0),
                        Position         = UDim2.new(0, 10, 0, 0),
                        BackgroundTransparency = 1,
                        Text             = label,
                        TextColor3       = T.TextSecondary,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 11,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 6,
                    }, Header)

                    -- Color preview swatch
                    local Swatch = New("Frame", {
                        Size             = UDim2.new(0, 20, 0, 20),
                        Position         = UDim2.new(1, -10, 0.5, 0),
                        AnchorPoint      = Vector2.new(1, 0.5),
                        BackgroundColor3 = default,
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Header)
                    Corner(Swatch, 3)
                    Stroke(Swatch, T.BorderFaint, 1, 0.8)

                    local Hit = New("TextButton", {
                        Size             = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text             = "",
                        ZIndex           = 7,
                    }, Header)
                    WireRowHover(Hit, Header)

                    -- ── Picker panel (expandable below header) ────────────
                    local Panel = New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 110),
                        BackgroundColor3 = T.InputBg,
                        BorderSizePixel  = 0,
                        Visible          = false,
                        ZIndex           = 5,
                    }, GInner)
                    Corner(Panel, 3)
                    Stroke(Panel, T.Accent, 1, 0.7)
                    Pad(Panel, 8, 8, 8, 8)

                    -- Saturation/Value 2D canvas
                    local SV = New("ImageLabel", {
                        Size             = UDim2.new(1, -28, 1, 0),
                        BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1),
                        BorderSizePixel  = 0,
                        Image            = "rbxassetid://4155801252",  -- white-to-transparent over black-to-transparent
                        ZIndex           = 6,
                    }, Panel)
                    Corner(SV, 3)

                    -- Hue bar (right side)
                    local HueBar = New("Frame", {
                        Size             = UDim2.new(0, 16, 1, 0),
                        Position         = UDim2.new(1, -16, 0, 0),
                        BorderSizePixel  = 0,
                        ZIndex           = 6,
                    }, Panel)
                    Corner(HueBar, 3)
                    New("UIGradient", {
                        Rotation = 270,
                        Color    = ColorSequence.new{
                            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0,   4)),
                            ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234, 255, 0)),
                            ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21,  255, 0)),
                            ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0,   255, 255)),
                            ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0,   17,  255)),
                            ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255, 0,   251)),
                            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0,   4)),
                        },
                    }, HueBar)

                    -- Hue cursor (small circle on bar)
                    local HueCursor = New("Frame", {
                        Size             = UDim2.new(1, 2, 0, 4),
                        AnchorPoint      = Vector2.new(0.5, 0.5),
                        Position         = UDim2.new(0.5, 0, 1 - ColorH),
                        BackgroundColor3 = Color3.new(1,1,1),
                        BorderSizePixel  = 0,
                        ZIndex           = 8,
                    }, HueBar)
                    Corner(HueCursor, 2)

                    -- SV cursor
                    local SVCursor = New("Frame", {
                        Size             = UDim2.new(0, 10, 0, 10),
                        AnchorPoint      = Vector2.new(0.5, 0.5),
                        Position         = UDim2.new(ColorS, 0, 1 - ColorV, 0),
                        BackgroundColor3 = Color3.new(1,1,1),
                        BorderSizePixel  = 0,
                        ZIndex           = 8,
                    }, SV)
                    Corner(SVCursor, 5)
                    Stroke(SVCursor, Color3.fromRGB(0,0,0), 1, 0.5)

                    -- Internal update
                    local function UpdateColor()
                        local col = Color3.fromHSV(ColorH, ColorS, ColorV)
                        Swatch.BackgroundColor3 = col
                        SV.BackgroundColor3     = Color3.fromHSV(ColorH, 1, 1)
                        Colorpicker.Value       = col
                        callback(col)
                    end

                    -- SV drag
                    local svDragging = false
                    SV.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            svDragging = true
                        end
                    end)
                    SV.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            svDragging = false
                        end
                    end)

                    -- Hue drag
                    local hueDragging = false
                    HueBar.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            hueDragging = true
                        end
                    end)
                    HueBar.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            hueDragging = false
                        end
                    end)

                    UserInputService.InputChanged:Connect(function(inp)
                        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                        if svDragging then
                            local mx  = math.clamp((Mouse.X - SV.AbsolutePosition.X) / SV.AbsoluteSize.X, 0, 1)
                            local my  = math.clamp((Mouse.Y - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y, 0, 1)
                            ColorS = mx
                            ColorV = 1 - my
                            SVCursor.Position = UDim2.new(mx, 0, my, 0)
                            UpdateColor()
                        elseif hueDragging then
                            local hy = math.clamp((Mouse.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
                            ColorH = 1 - hy
                            HueCursor.Position = UDim2.new(0.5, 0, hy, 0)
                            UpdateColor()
                        end
                    end)

                    -- Toggle open/close
                    Hit.Activated:Connect(function()
                        Colorpicker.Toggled = not Colorpicker.Toggled
                        Panel.Visible = Colorpicker.Toggled
                    end)

                    function Colorpicker:Set(color)
                        Colorpicker.Value = color
                        ColorH, ColorS, ColorV = Color3.toHSV(color)
                        Swatch.BackgroundColor3 = color
                        SV.BackgroundColor3     = Color3.fromHSV(ColorH, 1, 1)
                        SVCursor.Position       = UDim2.new(ColorS, 0, 1 - ColorV, 0)
                        HueCursor.Position      = UDim2.new(0.5, 0, 1 - ColorH, 0)
                        callback(color)
                    end

                    if flag then Library.Flags[flag] = Colorpicker end
                    return Colorpicker
                end

                -- ============================================================
                -- ── AddSection  (Orion-style labeled sub-section header) ────────
                -- Adds a dim label divider then returns an element table so
                -- you can add sub-elements under it.
                -- ============================================================
                function Group:AddSection(cfg2)
                    cfg2 = cfg2 or {}
                    local name = (type(cfg2) == "string") and cfg2 or (cfg2.Name or "Section")

                    -- Section header label
                    New("TextLabel", {
                        Size             = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text             = name,
                        TextColor3       = T.TextDim,
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 10,
                        TextXAlignment   = Enum.TextXAlignment.Left,
                        ZIndex           = 5,
                    }, GInner)

                    -- Thin accent line below header
                    New("Frame", {
                        Size             = UDim2.new(1, 0, 0, 1),
                        BackgroundColor3 = T.Accent,
                        BackgroundTransparency = 0.7,
                        BorderSizePixel  = 0,
                        ZIndex           = 5,
                    }, GInner)

                    -- Return a proxy so callers can add elements under this section
                    -- using the same Group API
                    return Group
                end

                table.insert(Tab._groups, Group)
                return Group
            end -- AddGroup

            -- ── AddSection at tab level (outside groups, like Orion's Container sections)
            function Tab:AddSection(cfg2)
                cfg2 = cfg2 or {}
                local name = (type(cfg2) == "string") and cfg2 or (cfg2.Name or "Section")

                -- Section frame auto-sizes; uses vertical list internally
                local SFrame = New("Frame", {
                    Size             = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 3,
                }, Content)

                local SLayout = ListLayout(SFrame, Enum.FillDirection.Vertical, 6)

                -- Section title
                New("TextLabel", {
                    Size             = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text             = name,
                    TextColor3       = T.TextDim,
                    Font             = Enum.Font.GothamBold,
                    TextSize         = 10,
                    TextXAlignment   = Enum.TextXAlignment.Left,
                    ZIndex           = 4,
                }, SFrame)

                -- Inner holder
                local Holder = New("Frame", {
                    Size             = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 4,
                }, SFrame)
                local HolderLayout = ListLayout(Holder, Enum.FillDirection.Vertical, 6)

                HolderLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    Holder.Size = UDim2.new(1, 0, 0, HolderLayout.AbsoluteContentSize.Y)
                end)

                -- Expose AddGroup on section
                local SectionObj = {}
                function SectionObj:AddGroup(groupName, groupWidth)
                    -- Create group inside the section holder
                    local fakeTab = { _groups = {}, _content = Content }
                    fakeTab._content = Holder
                    -- Re-use AddGroup logic from Tab but parent to Holder
                    return Tab:AddGroup(groupName, groupWidth)
                end
                return SectionObj
            end

            return Tab
        end -- AddTab

        return catData
    end -- AddCategory

    -- ── Window-level helpers ───────────────────────────────
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

    -- Expose MakeNotification on window handle too (convenience)
    function Win:MakeNotification(cfg)
        Library:MakeNotification(cfg)
    end

    return Win
end

return Library


--[[
═══════════════════════════════════════════════════════════
  USAGE EXAMPLE — all features demonstrated
═══════════════════════════════════════════════════════════

local Library = require(game.ReplicatedStorage.UILibrary)

local win = Library:CreateWindow({
    Width        = 730,
    Height       = 500,
    SidebarWidth = 90,
    TabBarHeight = 56,
})

win:SetToggleKey(Enum.KeyCode.Insert)

-- Toast notification
win:MakeNotification({
    Name    = "Loaded",
    Content = "UILibrary initialized successfully.",
    Time    = 4,
})

-- ── Categories + tabs ─────────────────────────────────────
local ragebot = win:AddCategory({ Name = "Ragebot",  Icon = "⊕" })
local visuals  = win:AddCategory({ Name = "Visuals",  Icon = "◈" })
local misc     = win:AddCategory({ Name = "Misc",     Icon = "≡" })

local aimTab = ragebot:AddTab("Aimbot")
local visTab = visuals:AddTab("ESP")

-- ── Groups ────────────────────────────────────────────────
local grp = aimTab:AddGroup("General", 230)

-- Checkbox
grp:AddCheckbox("Enable Aimbot", false, function(v)
    print("Aimbot:", v)
end)

-- Toggle (Orion-style)
grp:AddToggle({
    Name     = "Triggerbot",
    Default  = false,
    Color    = Color3.fromRGB(0, 148, 255),
    Flag     = "triggerbot",
    Callback = function(v) print("Triggerbot:", v) end,
})

-- Slider (table API)
grp:AddSlider({
    Name      = "FOV",
    Min       = 1,
    Max       = 180,
    Default   = 30,
    Increment = 1,
    Flag      = "fov",
    Callback  = function(v) print("FOV:", v) end,
})

-- Dropdown
grp:AddDropdown("Hitbox", {"Head","Neck","Chest","Pelvis"}, "Head", function(v)
    print("Hitbox:", v)
end)

-- RadioGroup
grp:AddRadioGroup("Priority", {"Nearest","Lowest HP","Most Visible"}, "Nearest", function(v)
    print("Priority:", v)
end)

-- Button
grp:AddButton({
    Name     = "Force Update",
    Callback = function()
        print("Update pressed")
    end,
})

-- Keybind
grp:AddBind({
    Name     = "Activate Key",
    Default  = Enum.KeyCode.X,
    Hold     = false,
    Flag     = "activateKey",
    Callback = function()
        print("Bind fired")
    end,
})

-- Text input
grp:AddInput({
    Name     = "Custom Tag",
    Default  = "",
    Callback = function(text) print("Tag:", text) end,
})

-- Color picker
grp:AddColorpicker({
    Name     = "Glow Color",
    Default  = Color3.fromRGB(0, 148, 255),
    Flag     = "glowColor",
    Callback = function(color) print("Color:", color) end,
})

-- Paragraph block
grp:AddParagraph("Note", "Aimbot targets the nearest visible enemy within FOV range.")

-- Section divider inside group
grp:AddSection("Advanced")

-- Separator
grp:AddSeparator()

grp:AddLabel("Resolver active when targeting")

-- Inspect flag
print(Library.Flags["fov"]:Get())   -- e.g. 30

]]
