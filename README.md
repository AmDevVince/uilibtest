# UI Library Documentation

## Initialization

Load the library from GitHub:

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/AmDevVince/uilibtest/refs/heads/main/uilib.lua"))()
```

---

## Window

Create the main interface and set the hide/show keybind.

```lua
local win = Library:CreateWindow({
    Width        = 730,
    Height       = 500,
    SidebarWidth = 90,
    TabBarHeight = 56,
})

win:SetToggleKey(Enum.KeyCode.Insert)
```

---

## Categories & Tabs

Categories populate the left sidebar. Tabs populate the top bar inside a category.

### Add a Category (Sidebar)

```lua
local legitbot = win:AddCategory({
    Name = "Legitbot",
    Icon = "◎"
})
```

### Add a Tab (Top Bar)

```lua
local aimbot = legitbot:AddTab("Aimbot")
```

---

## Groups

Groups hold your UI elements. Specify the width so they can stack side-by-side.

```lua
-- AddGroup(Name, Width)
local soundGrp = aimbot:AddGroup("Sound", 220)
```

---

## Elements

Attach these to any `Group` variable (e.g. `soundGrp`).

### Label & Separator

Static text and divider lines.

```lua
soundGrp:AddLabel("Maximum affects visible animations")
soundGrp:AddSeparator()
```

---

### Checkbox

A simple on/off toggle.

```lua
-- AddCheckbox(Name, DefaultState, CallbackFunction)
soundGrp:AddCheckbox("Auto stop", false, function(v)
    print("Auto stop:", v)
end)
```

---

### Radio Group

Mutually exclusive circle selectors.

```lua
-- AddRadioGroup(Title, OptionsArray, DefaultSelection, CallbackFunction)
soundGrp:AddRadioGroup(
    "",
    {"Off", "Minimum", "Direction"},
    "Direction",
    function(v)
        print("Anti-rage mode:", v)
    end
)
```

---

### Dropdown

A collapsible list.

```lua
-- AddDropdown(Title, OptionsArray, DefaultSelection, CallbackFunction)
soundGrp:AddDropdown(
    "Choose mode for selecting direction",
    {"Auto", "Legit", "Rage", "Maximum"},
    "Auto",
    function(v)
        print("Direction mode:", v)
    end
)
```
