local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local Library = {}
Library.__index = Library

local T = {
    WindowBg      = Color3.fromRGB(20, 25, 35),   -- #141923
    SidebarBg     = Color3.fromRGB(25, 32, 47),   -- #19202F
    PanelBg       = Color3.fromRGB(22, 29, 42),   -- #161D2A
    InnerBg       = Color3.fromRGB(36, 47, 67),   -- #242F43
    Accent        = Color3.fromRGB(0, 148, 255),  -- #0094FF
    TextPrimary   = Color3.fromRGB(220, 228, 255),
    TextSecondary = Color3.fromRGB(150, 170, 210),
    TextDim       = Color3.fromRGB(80, 110, 160),
    BorderFaint   = Color3.fromRGB(255, 255, 255),
}

local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Stroke(p, color, trans)
    New("UIStroke", {Color = color or T.BorderFaint, Thickness = 1, Transparency = trans or 0.96, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p)
end

function Library:CreateWindow(config)
    local W, H, SIDEBAR, TABBAR_H = 730, 500, 90, 56
    local Win = { _cats = {}, _currentCat = nil }

    local ScreenGui = New("ScreenGui", {Name = "UILib", ResetOnSpawn = false}, Players.LocalPlayer:WaitForChild("PlayerGui"))
    
    local Main = New("Frame", {Size = UDim2.new(0, W, 0, H), Position = UDim2.new(0.5, -W/2, 0.5, -H/2), BackgroundColor3 = T.WindowBg, BorderSizePixel = 0}, ScreenGui)
    New("UICorner", {CornerRadius = UDim.new(0, 4)}, Main)
    Stroke(Main, T.BorderFaint, 0.96)

    local DragBar = New("Frame", {Size = UDim2.new(1, 0, 0, TABBAR_H), BackgroundTransparency = 1, ZIndex = 20}, Main)
    -- Add basic drag logic here

    local Sidebar = New("Frame", {Size = UDim2.new(0, SIDEBAR, 1, 0), BackgroundColor3 = T.SidebarBg, BorderSizePixel = 0}, Main)
    New("UICorner", {CornerRadius = UDim.new(0, 4)}, Sidebar)
    local IconList = New("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1}, Sidebar)
    New("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center}, IconList)
    New("UIPadding", {PaddingTop = UDim.new(0, 10)}, IconList)

    local TabBar = New("Frame", {Size = UDim2.new(1, -SIDEBAR, 0, TABBAR_H), Position = UDim2.new(0, SIDEBAR, 0, 0), BackgroundColor3 = T.SidebarBg, BorderSizePixel = 0}, Main)
    local TabContainer = New("Frame", {Size = UDim2.new(1, -180, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1}, TabBar)
    New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center}, TabContainer)

    local ContentHost = New("Frame", {Size = UDim2.new(1, -SIDEBAR, 1, -TABBAR_H), Position = UDim2.new(0, SIDEBAR, 0, TABBAR_H), BackgroundTransparency = 1}, Main)

    function Win:AddCategory(name, iconId)
        local cat = { _tabs = {} }
        
        -- Hexagon button
        local CatBtn = New("ImageButton", {Size = UDim2.new(0, 60, 0, 60), BackgroundTransparency = 1, Image = iconId or "", ImageColor3 = T.TextDim}, IconList)
        local NameLbl = New("TextLabel", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -10), BackgroundTransparency = 1, Text = name, TextColor3 = T.TextDim, Font = Enum.Font.Gotham, TextSize = 10}, CatBtn)
        local Strip = New("Frame", {Size = UDim2.new(0, 2, 0, 28), Position = UDim2.new(0, 0, 0.5, -14), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0}, CatBtn)

        CatBtn.Activated:Connect(function()
            for _, c in ipairs(Win._cats) do
                c.CatBtn.ImageColor3 = T.TextDim
                c.NameLbl.TextColor3 = T.TextDim
                c.Strip.BackgroundTransparency = 1
                for _, t in ipairs(c._tabs) do t._btn.Visible = false; t._content.Visible = false end
            end
            CatBtn.ImageColor3 = T.Accent
            NameLbl.TextColor3 = T.Accent
            Strip.BackgroundTransparency = 0
            for _, t in ipairs(cat._tabs) do t._btn.Visible = true end
            if #cat._tabs > 0 then cat._tabs._btn.TextColor3 = T.Accent; cat._tabs._content.Visible = true end
        end)

        cat.CatBtn = CatBtn; cat.NameLbl = NameLbl; cat.Strip = Strip
        table.insert(Win._cats, cat)

        function cat:AddTab(tabName)
            local Tab = {}
            Tab._btn = New("TextButton", {Size = UDim2.new(0, 80, 1, 0), BackgroundTransparency = 1, Text = tabName, TextColor3 = T.TextSecondary, Font = Enum.Font.GothamBold, TextSize = 13, Visible = false}, TabContainer)
            local Underline = New("Frame", {Size = UDim2.new(0.8, 0, 0, 2), Position = UDim2.new(0.1, 0, 1, -2), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0}, Tab._btn)
            
            Tab._content = New("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, Visible = false}, ContentHost)
            New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 10)}, Tab._content)
            New("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10)}, Tab._content)

            Tab._btn.Activated:Connect(function()
                for _, t in ipairs(cat._tabs) do t._btn.TextColor3 = T.TextSecondary; t._btn:FindFirstChildOfClass("Frame").BackgroundTransparency = 1; t._content.Visible = false end
                Tab._btn.TextColor3 = T.Accent
                Underline.BackgroundTransparency = 0
                Tab._content.Visible = true
            end)
            
            table.insert(cat._tabs, Tab)

            function Tab:AddGroup(groupName, width)
                local Group = {}
                local GFrame = New("Frame", {Size = UDim2.new(0, width or 230, 0, 0), BackgroundColor3 = T.PanelBg, AutomaticSize = Enum.AutomaticSize.Y}, Tab._content)
                New("UICorner", {CornerRadius = UDim.new(0, 4)}, GFrame)
                Stroke(GFrame, T.BorderFaint, 0.96)
                
                New("TextLabel", {Size = UDim2.new(1, -16, 0, 20), Position = UDim2.new(0, 8, 0, 5), BackgroundTransparency = 1, Text = groupName, TextColor3 = T.TextDim, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, GFrame)
                local GInner = New("Frame", {Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 25), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y}, GFrame)
                New("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 2)}, GInner)
                New("UIPadding", {PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, GInner)

                -- Single Toggles (Circles)
                function Group:AddToggle(text, default, cb)
                    local Row = New("TextButton", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = ""}, GInner)
                    local Circle = New("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 0, 0.5, -7), BackgroundColor3 = T.InputBg}, Row)
                    New("UICorner", {CornerRadius = UDim.new(1, 0)}, Circle)
                    local CStroke = New("UIStroke", {Color = T.BorderFaint, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, Circle)
                    local Dot = New("Frame", {Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0.5, -3, 0.5, -3), BackgroundColor3 = T.Accent, BackgroundTransparency = default and 0 or 1}, Circle)
                    New("UICorner", {CornerRadius = UDim.new(1, 0)}, Dot)
                    local Lbl = New("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 22, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = default and T.Accent or T.TextSecondary, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, Row)

                    local state = default
                    Row.Activated:Connect(function()
                        state = not state
                        Dot.BackgroundTransparency = state and 0 or 1
                        CStroke.Color = state and T.Accent or T.BorderFaint
                        Lbl.TextColor3 = state and T.Accent or T.TextSecondary
                        if cb then cb(state) end
                    end)
                end

                -- Radio Group (Squares)
                function Group:AddRadioGroup(options, default, cb)
                    local selected = default
                    local radios = {}
                    for _, opt in ipairs(options) do
                        local Row = New("TextButton", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = ""}, GInner)
                        local Square = New("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 0, 0.5, -7), BackgroundColor3 = T.InputBg}, Row)
                        New("UICorner", {CornerRadius = UDim.new(0, 2)}, Square)
                        local SStroke = New("UIStroke", {Color = T.BorderFaint, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, Square)
                        local Fill = New("Frame", {Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2), BackgroundColor3 = T.Accent, BackgroundTransparency = (opt == selected) and 0 or 1}, Square)
                        local Lbl = New("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 22, 0, 0), BackgroundTransparency = 1, Text = opt, TextColor3 = (opt == selected) and T.Accent or T.TextSecondary, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, Row)
                        
                        table.insert(radios, {opt = opt, fill = Fill, stroke = SStroke, lbl = Lbl})
                        Row.Activated:Connect(function()
                            selected = opt
                            for _, r in ipairs(radios) do
                                local on = (r.opt == selected)
                                r.fill.BackgroundTransparency = on and 0 or 1
                                r.stroke.Color = on and T.Accent or T.BorderFaint
                                r.lbl.TextColor3 = on and T.Accent or T.TextSecondary
                            end
                            if cb then cb(opt) end
                        end)
                    end
                end

                -- Dropdown and other elements remain the same from the previous code block...
                return Group
            end
            return Tab
        end
        return cat
    end
    return Win
end

return Library
