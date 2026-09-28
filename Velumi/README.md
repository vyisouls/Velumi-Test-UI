# Velumi

**A compact, developer-tool styled UI library for Roblox.**

Velumi gives your Roblox experiences the look and feel of a debugger or editor panel: dark charcoal surfaces, 1px borders, 2px corners, small type, dense layouts and a single accent color. You describe the UI in a few declarative calls, and Velumi takes care of theming, input, layout, configuration and cleanup.

```text
┌──────────────────────────────────────────────────────────────┐
│ Velumi                                              ─ □ ×    │
├──────────────┬───────────────────────────────────────────────┤
│ Main         │ General                                       │
│ Player       │ ───────────────────────────────────────────── │
│ Visuals      │ [✓] Enabled                                   │
│ Settings     │ [────●──────── 16.0 ───]  Walk Speed          │
│ Debug        │ [ Default           ▾ ]  Mode                 │
│              │                                               │
│              │ ▾ Advanced                                    │
│              │ [ ] Debug Mode                                │
└──────────────┴───────────────────────────────────────────────┘
```

- **Looks like a tool, not a dashboard.** Controls are flat and tightly packed, with subtle hover states and a widget on the left and its label on the right.
- **Quick to write.** Controls are created where you use them, labels double as IDs, and values can be bound directly to your own tables.
- **Built to last.** A central theme engine, a single input hub, reference-counted global state, and a Maid per object, so destroying a window disconnects everything it created.
- **Works in plain Roblox Studio.** No executor APIs, no `loadstring`, no filesystem. It works in any LocalScript.

---

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [API overview](#api-overview)
- [Elements](#elements)
- [Themes](#themes)
- [Configuration](#configuration)
- [Examples](#examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Features

| Area | What you get |
| --- | --- |
| Windows | Dragging, resizing, minimize / maximize / restore, close, focus and z-ordering, centering, scale, min/max size, toggle key, multiple independent windows |
| Navigation | Tabs as a left sidebar or a top tab bar, multi-column tabs, groups, collapsible groups, tab-less tool windows |
| Elements | Button, Checkbox, Toggle, Slider, Dropdown, MultiDropdown, Input, Keybind, ColorPicker, Label, Paragraph, Separator, ProgressBar, Plot |
| Layout | `SameLine`, collapsing headers and tree nodes, scrollable child regions (`BeginChild`/`EndChild`), `Indent`, `BeginDisabled`, `AddSpacing`, `Rebuild` for dynamic lists |
| Overlays | Menu bars, status bars, context menus with sub menus, tooltips, stacked notifications, modal dialogs, confirm dialogs |
| Themes | Five built-in themes, custom themes from as little as one color, live switching, derived palette |
| Configuration | Automatic flags, `GetConfig` / `LoadConfig`, JSON export/import, reset, bound tables, live `Values` table |
| Engineering | Luau types for autocomplete, one set of global input connections, no per-frame loops, leak-checked teardown, headless test suite |

## Installation

Velumi is a single folder of ModuleScripts: `src/Velumi`. Put it in `ReplicatedStorage` and name it `Velumi`.

### Option 1: model file

Download `Velumi.rbxm` from the [releases page](https://github.com/zqoc/Velumi/releases), drag it into Studio and move it into `ReplicatedStorage`.

### Option 2: Rojo

```bash
git clone https://github.com/zqoc/Velumi
cd Velumi
rojo build -o Velumi.rbxm            # a model you can insert
# or sync the library + showcase into a place:
rojo serve showcase.project.json
```

`default.project.json` builds the library by itself. `showcase.project.json` maps the library to `ReplicatedStorage.Velumi` and the showcase to `StarterPlayerScripts`.

### Option 3: Wally

```toml
[dependencies]
Velumi = "zqoc/velumi@1.0.0"
```

## Quick start

Add a **LocalScript** to `StarterPlayerScripts`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Velumi = require(ReplicatedStorage:WaitForChild("Velumi"))

local Window = Velumi:CreateWindow({
	Title = "Velumi",
	Size = UDim2.fromOffset(700, 480),
	Center = true,
	ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab({ Name = "Main" })
local General = Main:AddGroup({ Name = "General" })

General:AddCheckbox({
	Name = "Enabled",
	Default = false,
	Callback = function(value)
		print("Enabled:", value)
	end,
})

General:AddSlider({
	Name = "Walk Speed",
	Min = 0,
	Max = 100,
	Default = 16,
	Step = 1,
	Callback = function(value)
		local character = game.Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end,
})

General:AddDropdown({
	Name = "Mode",
	Values = { "Default", "Advanced", "Experimental" },
	Default = "Default",
})

Velumi:Notify({ Title = "Ready", Description = "Press RightShift to toggle.", Type = "Success" })
```

### Bind values to your own tables

To skip callbacks, pass `Bind`. The control writes into your table whenever it changes:

```lua
local Settings = { Enabled = true, FieldOfView = 70 }

General:AddCheckbox({ Name = "Enabled", Bind = { Settings, "Enabled" } })
General:AddSlider({ Name = "FOV", Min = 40, Max = 120, Bind = { Settings, "FieldOfView" } })

-- Settings.Enabled / Settings.FieldOfView are always current.
-- If you change Settings in code, call Window:Sync() to refresh the UI.
```

### Tab-less tool windows

```lua
local Inspector = Velumi:CreateWindow({ Title = "Inspector", Size = Vector2.new(320, 260) })
local Props = Inspector:AddGroup({ Name = "Properties" })   -- no tabs needed
Props:AddInput({ Name = "Name", Default = "Part" })
```

## API overview

Every object follows the same pattern: the library creates **windows**, windows hold **tabs**, tabs hold **groups**, and groups (along with sections, child regions and modal bodies) are **containers** that hold **elements**.

```lua
Velumi:CreateWindow(options)       --> Window
Window:AddTab(options)             --> Tab
Tab:AddGroup(options)              --> Group (a container)
Group:AddToggle(options)           --> Toggle (an element)
```

Every element shares one API:

```lua
local Toggle = General:AddToggle({ Name = "Enabled", Default = false })

Toggle:SetValue(true)          -- fires Changed + Callback when the value changes
Toggle:SetValue(false, true)   -- silent: no Changed / Callback
Toggle:GetValue()
Toggle:SetVisible(false)
Toggle:SetDisabled(true)
Toggle:SetText("Renamed")
Toggle:SetTooltip("Explains what this option does.")
Toggle:OnChanged(function(value) end)
Toggle:Reset()                 -- back to Default
Toggle:Destroy()
```

Common element options include `Name`, `Default`, `Callback`, `Flag`, `Save`, `Bind`, `Tooltip`, `Disabled`, `Visible` and `ContextMenu`.

Layout helpers work on every container:

```lua
Group:AddButton({ Name = "Apply" })
Group:SameLine()                              -- next item joins the previous row
Group:AddButton({ Name = "Revert" })

local Advanced = Group:AddSection({ Name = "Advanced", Open = false })   -- collapsing header
Advanced:AddCheckbox({ Name = "Debug Mode" })

Group:BeginChild({ Name = "Log", Height = 120, AutoScroll = true })      -- scrolling region
Group:AddLabel("[00:01] Connected")                                      -- goes into the child
Group:EndChild()

Group:BeginDisabled()
Group:AddSlider({ Name = "Locked", Min = 0, Max = 1 })
Group:EndDisabled()
```

Labels double as IDs. Text after `##` is hidden, and a name that starts with `##` gives the widget the full row width:

```lua
Group:AddSlider({ Name = "##x", Min = 0, Max = 1 })   -- no visible label
```

The full reference is in [docs/API.md](docs/API.md).

## Elements

| Element | Value | Highlights |
| --- | --- | --- |
| `AddButton` | — | `Style = "Accent" \| "Danger"`, `Confirm`, `FullWidth` |
| `AddCheckbox` | `boolean` | Square check box |
| `AddToggle` | `boolean` | Compact switch |
| `AddSlider` | `number` | `Min`, `Max`, `Step`, `Suffix`, `Format`, Ctrl+Click to type |
| `AddDropdown` | `string?` | `Values`, `Searchable`, `AllowNone` |
| `AddMultiDropdown` | `{ string }` | Stays open while picking |
| `AddInput` | `string \| number` | `Numeric`, `MaxLength`, `Validate`, `Finished = false` for live updates |
| `AddKeybind` | key name | Rebinding, `Toggle` / `Hold` / `Press` / `Always` modes, `Target` |
| `AddColorPicker` | `Color3` | SV square, hue, transparency, RGB / HSV / Hex fields |
| `AddLabel` | text | `Style`, `Bullet`, `Wrap` |
| `AddParagraph` | text | Title and wrapped body |
| `AddSeparator` | — | Optional inline text |
| `AddProgressBar` | `0..1` | `Format`, `Style` |
| `AddPlot` | samples | `"Lines"` or `"Histogram"`, `Push(value)` |

See [docs/ELEMENTS.md](docs/ELEMENTS.md) for every option and method.

## Themes

```lua
Velumi:SetTheme("Light")   -- Dark (default), Light, Midnight, Gray, Classic

Velumi:RegisterTheme("Sakura", {
	Accent = Color3.fromRGB(255, 100, 150),
})
Velumi:SetTheme("Sakura")  -- headers, grabs, check marks and title bars follow the accent
```

Every color comes from the theme; nothing is hard-coded. Changing the theme restyles existing windows right away. See [docs/THEMES.md](docs/THEMES.md).

## Configuration

Saveable elements register under a **flag**. You can set it explicitly with `Flag = "WalkSpeed"`; otherwise it is generated as `"Tab/Group/Name"`.

```lua
local data = Window:GetConfig()        -- plain, JSON-safe table
Window:LoadConfig(data)                -- applies values, fires callbacks

local json = Window:ExportConfig()     -- string
Window:ImportConfig(json)

Window:ResetConfig()                   -- every element back to Default
print(Window.Values.WalkSpeed)         -- live values by flag
```

Velumi never touches the filesystem. To persist a config, send it to the server and save it in a DataStore. See [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## Examples

[`examples/Showcase.client.luau`](examples/Showcase.client.luau) is a complete demo window with **Main, Controls, Layout, Themes, Configuration and Debug** tabs. It covers every element, same-line layouts, child regions, sections, tooltips, context menus, menus, notifications, modals, multiple windows, theme switching, scaling, configuration and live plots.

```bash
rojo serve showcase.project.json   # then press Play in Studio
```

## Testing

The repository includes a headless test suite. It runs the real library source against a strict mock of the Roblox API. The mock rejects unknown properties, invalid enum items and wrong property types, and it counts live connections.

```bash
lune run tests/run
```

The suite drives every element through simulated input and covers configuration round trips, theming, windows, menus, modals and notifications. It also runs the entire showcase. Finally, it verifies that `Window:Destroy()` and `Velumi:Destroy()` leave no connections or instances behind.

## Contributing

Contributions are welcome. [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) explains the architecture, how to add an element, the code style and the test workflow.

## License

[MIT](LICENSE) © ZQ Interactive
