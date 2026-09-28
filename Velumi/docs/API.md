# API Reference

This page documents every public API in Velumi. Element-specific options and methods are listed in [ELEMENTS.md](ELEMENTS.md).

Object hierarchy:

```text
Velumi (library)
└── Window
    ├── Menu bar ─ Menu
    ├── Status bar
    └── Tab
        └── Group ─────────── Container
            ├── Element
            ├── Section ───── Container
            └── Child ─────── Container
Modal ──────────────────────── Container
```

Method calls use `:`. Options are passed as a single table. Anywhere an options table is expected, a plain string is also accepted as `Name` (for labels and separators, as `Text`):

```lua
Main:AddGroup("General")          -- same as Main:AddGroup({ Name = "General" })
Group:AddLabel("Hello")           -- same as Group:AddLabel({ Text = "Hello" })
```

---

## Library

```lua
local Velumi = require(ReplicatedStorage.Velumi)
```

### Windows

| Method | Description |
| --- | --- |
| `Velumi:CreateWindow(options) -> Window` | Creates a window. See [Window options](#window-options). |
| `Velumi:GetWindows() -> { Window }` | All live windows, back to front. |

### Themes

| Method | Description |
| --- | --- |
| `Velumi:SetTheme(nameOrTable)` | Activates a registered theme, or a theme table (registered as `"Custom"` on top of Dark). |
| `Velumi:GetTheme() -> string` | Name of the active theme. |
| `Velumi:RegisterTheme(name, definition, base?)` | Registers or replaces a theme. Missing keys come from `base` (default `"Dark"`). |
| `Velumi:GetThemes() -> { string }` | Sorted theme names. |
| `Velumi:GetPalette() -> table` | Copy of the active palette (core, derived and style keys). |
| `Velumi:GetThemeValue(key) -> any` | One palette value, for example `"Accent"`. |
| `Velumi.ThemeChanged` | Signal `(name, palette)`. |

### Overlays

| Method | Description |
| --- | --- |
| `Velumi:Notify(options) -> Notification` | Shows a toast. See [Notifications](#notifications). |
| `Velumi:ClearNotifications()` | Dismisses every notification. |
| `Velumi:ShowModal(options) -> Modal` | Shows a modal dialog. See [Modals](#modals). |
| `Velumi:Confirm(options) -> Modal` | Yes/no dialog: `{ Title, Description, ConfirmText, CancelText, Danger, Callback(confirmed) }`. |
| `Velumi:ShowContextMenu(items, position?)` | Opens a context menu at a screen position (default: the pointer). At least one window must exist. |
| `Velumi:ClosePopups()` | Closes dropdown lists, color pickers and menus. |

### Global settings

| Method | Description |
| --- | --- |
| `Velumi:SetScale(scale)` / `GetScale()` | Global scale multiplier for all windows and overlays. |
| `Velumi:SetAnimationsEnabled(enabled)` | Turns tweening off. Properties are then applied instantly. |
| `Velumi:SetParent(instance)` | Parent of the Velumi `ScreenGui`. Default: `LocalPlayer.PlayerGui`. |
| `Velumi:SetDisplayOrder(order)` | `DisplayOrder` of the `ScreenGui` (default `100`). |
| `Velumi:SetMetrics(table)` | Overrides layout metrics before creating windows (see below). |
| `Velumi:SetTooltipDelay(seconds)` | Hover delay before tooltips appear (default `0.45`). |
| `Velumi.Metrics` | The metrics table (read it; change it with `SetMetrics`). |
| `Velumi.Version` | Library version string. |

Metrics: `RowHeight` (19), `ItemSpacing` (4), `ItemSpacingX` (8), `InnerSpacing` (6), `FramePaddingX` (6), `WindowPadding` (8), `GroupPadding` (7), `IndentSpacing` (14), `TitleHeight` (21), `MenuHeight` (20), `TabHeight` (22), `StatusHeight` (19), `SidebarWidth` (132), `ItemWidth` (0.62), `CheckboxSize` (15), `ScrollBarThickness` (5), `PopupItemHeight` (20), `MaxPopupItems` (10).

### Extensibility and teardown

| Method | Description |
| --- | --- |
| `Velumi:RegisterElement(name, class)` | Adds `container:Add<name>()` for a custom element class. See [CONTRIBUTING.md](CONTRIBUTING.md#writing-a-custom-element). |
| `Velumi.Element` | The base element class (`Velumi.Element.extend("Name")`). |
| `Velumi.Utilities` | `{ Signal, Maid, Utility }` for extensions. |
| `Velumi:Destroy()` | Destroys every window, modal, notification and popup, and disconnects every connection. Velumi can be used again afterwards. |

---

## Window

### Window options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Title` | `string` | `"Velumi"` | Title bar text. |
| `Size` | `UDim2 \| Vector2` | `700 × 480` | Unscaled size (UDim2 scale is resolved against the screen). |
| `Position` | `UDim2 \| Vector2` | — | Top-left position. Disables centering. |
| `Center` | `boolean` | `true` | Center on screen. |
| `MinSize` / `MaxSize` | `Vector2` | `360 × 220` / none | Resize limits. |
| `Visible` | `boolean` | `true` | Initial visibility. |
| `Resizable` / `Draggable` | `boolean` | `true` | Resize grip / title bar dragging. |
| `Closable` / `Minimizable` / `Maximizable` | `boolean` | `true` | Title bar buttons. |
| `DestroyOnClose` | `boolean` | `false` | Close destroys instead of hiding. |
| `OnClose` | `(window) -> ()` | — | Called when the close button is pressed. |
| `TabStyle` | `"Sidebar" \| "Top"` | `"Sidebar"` | Where tab buttons are shown. |
| `SidebarWidth` | `number` | `132` | Sidebar width in pixels. |
| `StatusBar` | `boolean \| string` | — | Creates a status bar (with initial text). |
| `ToggleKey` | `KeyCode \| string` | — | Key that shows/hides the window. |
| `Scale` | `number` | `1` | Per-window scale multiplier. |
| `AutoScale` | `boolean` | `true` | Shrink to fit small screens (never below 50%). |
| `ImplicitTab` | `TabOptions` | — | Options for the hidden tab created by `Window:AddGroup`. |

### Structure

| Method | Description |
| --- | --- |
| `Window:AddTab(options) -> Tab` | Adds a tab (`Name`, `Columns`, `Visible`, `Selected`). The first tab is selected automatically. |
| `Window:AddGroup(options) -> Group` | For tab-less windows: creates a hidden implicit tab on first use. Cannot be mixed with `AddTab`. |
| `Window:SelectTab(tabOrName)` | Selects a tab. |
| `Window:GetTab(name) -> Tab?` | Finds a tab by name. |
| `Window:AddMenu(name, items) -> Menu` | Adds a menu to the menu bar (created on first use). `items` use the [menu item format](#menu-items). |
| `Window:SetStatus(left?, right?)` | Sets status bar text (created on first use). |

### State and geometry

| Method | Description |
| --- | --- |
| `SetVisible(bool)` / `IsVisible()` / `Toggle()` | Visibility. Showing a window focuses it. |
| `Close()` | Fires `Closed`, then hides (or destroys with `DestroyOnClose`). |
| `Focus()` / `IsFocused()` | Brings the window to the front. Clicking a window does this automatically. |
| `Minimize()` / `Maximize()` / `Restore()` | Collapse to the title bar, fill the screen, undo either. Double-clicking the title bar also minimizes. |
| `IsMinimized()` / `IsMaximized()` | State queries. |
| `Center()` | Centers on screen. |
| `SetTitle(text)` | Changes the title. |
| `SetSize(size)` / `GetSize()` | Unscaled size (clamped to min/max). |
| `SetPosition(position)` / `GetPosition()` | Top-left position in pixels. |
| `SetMinSize(v2)` / `SetMaxSize(v2)` | Resize limits. |
| `SetResizable(bool)` / `SetDraggable(bool)` | Interaction toggles. |
| `SetScale(n)` / `GetScale()` | Per-window scale. |
| `GetEffectiveScale()` | Applied scale: window × global × auto-fit. |
| `SetToggleKey(key?)` | Changes or removes (`nil`) the toggle key. |

### Configuration

| Method | Description |
| --- | --- |
| `GetConfig() -> ConfigData` | `{ Version, Values = { [flag] = value } }`. |
| `LoadConfig(data) -> number` | Applies values and returns how many were applied. Also accepts a bare `{ [flag] = value }` table. |
| `ExportConfig() -> string` / `ImportConfig(json) -> number` | JSON helpers. |
| `ResetConfig()` | Resets saveable elements to their `Default`. |
| `GetFlag(flag) -> Element?` | Element registered under a flag. |
| `Window.Values` | Live `{ [flag] = value }` table (read-only by convention). |
| `Window.Flags` | `{ [flag] = element }`. |
| `ForEachElement(fn)` | Visits every element in every tab. |
| `Sync()` | Re-reads every element's `Bind` table. |

### Signals and misc

| Member | Description |
| --- | --- |
| `Closed` | Fired by `Close()`. |
| `Destroyed` | Fired once when destroyed. |
| `VisibilityChanged(visible)` | After `SetVisible`. |
| `FocusChanged(focused)` | Focus gained or lost. |
| `TabChanged(tab, previous)` | Selected tab changed. |
| `ConfigChanged(flag, value, element)` | Any saveable value changed (not fired for silent sets). |
| `Notify(options)` | Shortcut for `Velumi:Notify`. |
| `Destroy()` / `IsDestroyed()` | Tears down the window and everything it owns. |

---

## Tab

| Member | Description |
| --- | --- |
| `Tab:AddGroup(options) -> Group` | Options: `Name`, `Side = "Left" \| "Right"` or `Column = n`, `Collapsible`, `Collapsed`, `Border`. |
| `Tab:GetGroup(name) -> Group?` | Finds a group. |
| `Tab:Select()` / `IsSelected()` | Selection. |
| `Tab:SetText(text)` | Renames the tab button. |
| `Tab:SetVisible(bool)` / `IsVisible()` | Hides the tab button (selects another tab if needed). |
| `Tab:ScrollToTop()` | Scrolls the page to the top. |
| `Tab:Destroy()` | Removes the tab and its groups. |
| `Tab.Groups` | Array of groups. |

Tab options: `Name`, `Columns` (default `1`), `Visible`, `Selected`.

## Group

A group is a titled, bordered [container](#containers) in a tab column.

| Member | Description |
| --- | --- |
| `SetText(text)` / `SetTitle(text)` | Changes the title. |
| `SetCollapsed(bool)` / `IsCollapsed()` | Only for `Collapsible = true` groups. Clicking the title also toggles. |
| `SetVisible(bool)` / `IsVisible()` | Visibility. |
| `Destroy()` | Removes the group and its elements. |

## Containers

Groups, sections, child regions and modals share these methods.

### Adding elements

`AddButton`, `AddCheckbox`, `AddToggle`, `AddSlider`, `AddDropdown`, `AddMultiDropdown`, `AddInput`, `AddKeybind`, `AddColorPicker`, `AddLabel`, `AddParagraph`, `AddSeparator`, `AddProgressBar`, `AddPlot`, plus any element registered with `Velumi:RegisterElement`. See [ELEMENTS.md](ELEMENTS.md).

### Layout

| Method | Description |
| --- | --- |
| `SameLine()` | The next item joins the previous row. Fill widgets (sliders, inputs, dropdowns...) share the remaining width; buttons and checkboxes keep their size. |
| `AddSpacing(pixels?)` | Vertical gap. |
| `Indent(pixels?)` / `Unindent(pixels?)` | Indents subsequent rows (default `IndentSpacing`). |
| `BeginDisabled()` / `EndDisabled()` | Elements created in between start disabled. Scopes nest and apply to nested containers. |
| `AddSection(options) -> Section` | Collapsible region: `Name`, `Open` (default `true`), `Style = "Header" \| "Tree"`. |
| `AddChild(options) -> Child` | Scrolling region: `Name`, `Height` (default `140`), `Border`, `AutoScroll`. |
| `BeginChild(options) -> Child` / `EndChild()` | Same as `AddChild`, but every `Add*` call on this container goes into the child until `EndChild()`. |

### Dynamic content

| Method | Description |
| --- | --- |
| `GetElements() -> { any }` | Direct items, in order. |
| `Clear()` | Destroys every item. |
| `Rebuild(fn)` | `Clear()`, then `fn(container)`. Use it for lists that change. |

### Section

| Member | Description |
| --- | --- |
| `SetOpen(bool)` / `IsOpen()` / `Toggle()` | Open state. |
| `Toggled(open)` | Signal. |
| `SetText(text)` | Header text. |
| `SetVisible(bool)` / `IsVisible()` / `Destroy()` | Lifecycle. |

### Child

| Member | Description |
| --- | --- |
| `SetHeight(px)` | Region height. |
| `ScrollToTop()` / `ScrollToBottom()` | Scrolling. |
| `SetVisible(bool)` / `IsVisible()` / `Destroy()` | Lifecycle. |

---

## Elements (shared API)

Every element returned by an `Add*` call supports:

| Member | Description |
| --- | --- |
| `GetValue()` | Current value (see each element for the type). |
| `SetValue(value, silent?)` | Sets the value. `Changed` and `Callback` fire when it changes, unless `silent` is set. |
| `Reset(silent?)` | Restores `Default`. |
| `Sync()` | Silently re-reads the `Bind` table. |
| `OnChanged(fn) -> Connection` | Shorthand for `Changed:Connect`. |
| `SetCallback(fn?)` | Replaces the callback. |
| `SetVisible(bool)` / `IsVisible()` | Hidden elements take no space. |
| `SetDisabled(bool)` / `IsDisabled()` | Disabled elements are dimmed and ignore input. |
| `SetText(text)` / `GetText()` | Label text. |
| `SetTooltip(text?)` | Hover tooltip. |
| `SetContextMenu(items?)` | Right-click menu (items or a function returning items). |
| `Destroy()` / `IsDestroyed()` | Removes the element, disconnects its handlers and unregisters its flag. |
| `Changed` | Signal fired with the new value. |
| `Flag` | Config flag (saveable elements). |
| `Root` | The element's root GuiObject (for advanced customization). |

Shared options: `Name`, `Default`, `Callback`, `Flag`, `Save` (`false` to exclude from config), `Bind` (`{ table, key }` or `{ Table = t, Key = k }`), `Tooltip`, `Disabled`, `Visible`, `ContextMenu`.

---

## Notifications

```lua
local note = Velumi:Notify({
	Title = "Saved",
	Description = "Configuration saved successfully.",
	Type = "Success",   -- "Info" | "Success" | "Warning" | "Error"
	Duration = 3,       -- seconds; 0 = until closed
})
note:SetDescription("Updated text")
note:Close()
note.Closed:Connect(function() end)
```

Notifications stack in the bottom-right corner. At most five are shown; the oldest closes first. Click a notification to dismiss it.

## Modals

```lua
local modal = Velumi:ShowModal({
	Title = "New Preset",
	Description = "Optional text shown at the top.",
	Width = 340,
	Closable = true,           -- close button + Escape
	Build = function(modal)    -- the body is a container
		modal:AddInput({ Name = "Preset Name", Flag = "PresetName" })
	end,
	Buttons = {
		"Cancel",
		{ Name = "Create", Style = "Accent", Callback = function(modal)
			print(modal:GetValues().PresetName)
		end },
	},
	OnClose = function(result) end,  -- button name, or nil
})
```

| Member | Description |
| --- | --- |
| `GetValues()` | `{ [Flag or Name] = value }` for elements in the body. |
| `Close(result?)` / `IsOpen()` / `Destroy()` | Lifecycle. |
| `Closed(result)` | Signal. |

Button entries can set `Close = false` to keep the modal open after the callback. Elements inside a modal are not part of any window's configuration.

## Menu items

Menu bars, context menus and `ShowContextMenu` use the same item format:

```lua
{
	{ Name = "Save", Shortcut = "Ctrl+S", Callback = function() end },
	{ Name = "Wireframe", Checked = true, Callback = function() end },
	{ Name = "Export", Items = { { Name = "JSON" }, { Name = "Text" } } },  -- sub menu
	{ Name = "Delete", Disabled = true },
	"-",                                   -- separator (or { Separator = true })
}
```

`Window:AddMenu` returns a `Menu` with `SetItems(items)` and `Destroy()`.

## Signals and connections

Velumi signals have `Connect`, `Once`, `Wait`, `Fire`, `DisconnectAll` and `Destroy`. Handlers run on their own thread, so an erroring handler never breaks the UI. Callbacks passed in options are also run protected, and errors are printed with a traceback.

## Types

`init.luau` re-exports Luau types for annotations and autocomplete:

```lua
local Velumi = require(ReplicatedStorage.Velumi)
local window: Velumi.Window = Velumi:CreateWindow({ Title = "Tools" })
local speed: Velumi.Slider = group:AddSlider({ Name = "Speed" })
```

Available: `Window`, `WindowOptions`, `Tab`, `TabOptions`, `Group`, `GroupOptions`, `Section`, `Child`, `Container`, every element type, `ThemeDefinition`, `ConfigData`, `MenuItem`, `MenuItems`, `Notification`, `NotifyOptions`, `Modal`, `ModalOptions`, `Signal<T...>`, `Connection`.
