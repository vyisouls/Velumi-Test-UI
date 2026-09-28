# Elements

Every element supports the [shared element API](API.md#elements-shared-api): `GetValue`, `SetValue(value, silent?)`, `Reset`, `Sync`, `OnChanged`, `SetCallback`, `SetVisible`, `SetDisabled`, `SetText`, `SetTooltip`, `SetContextMenu` and `Destroy`. It also supports the shared options `Name`, `Tooltip`, `Disabled`, `Visible` and `ContextMenu`.

Elements marked **saveable** also accept `Default`, `Callback`, `Flag`, `Save` and `Bind`, and take part in [configuration](CONFIGURATION.md).

Layout conventions:

- **Framed** widgets (slider, dropdown, input, keybind, color picker, progress bar, plot) draw the widget on the left 62% of the row with the label on the right. On a `SameLine` row they share the available width.
- **Inline** widgets (button, checkbox, toggle) size themselves to their content.
- A `Name` starting with `##` hides the label and gives the widget the full row width. Anything after `##` is part of the ID but is not displayed.

---

## Button

```lua
local button = group:AddButton({
	Name = "Execute",
	Style = "Accent",
	Callback = function() print("pressed") end,
})
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Name` | `string` | `""` | Button text. |
| `Callback` | `() -> ()` | — | Runs on press. |
| `Style` | `"Default" \| "Accent" \| "Danger"` | `"Default"` | Visual style. |
| `FullWidth` | `boolean` | `false` | Stretch across the row. |
| `Width` | `number` | — | Fixed width in pixels. |
| `Confirm` | `boolean` | `false` | Require a second click within 2 seconds. |
| `ConfirmText` | `string` | `"Confirm?"` | Text while awaiting confirmation. |

Methods: `Press()`, `SetStyle(style)`, `SetText(text)`. Signal: `Pressed` (alias of `Changed`). Buttons have no value and are not saved.

## Checkbox (saveable)

```lua
group:AddCheckbox({ Name = "Enabled", Default = false, Callback = function(value) end })
```

Value: `boolean`. Method: `Toggle()`.

## Toggle (saveable)

A compact switch with the same API as Checkbox.

```lua
group:AddToggle({ Name = "Auto Save", Default = true })
```

Value: `boolean`. Method: `Toggle()`.

## Slider (saveable)

```lua
group:AddSlider({
	Name = "Volume",
	Min = 0,
	Max = 100,
	Default = 50,
	Step = 1,
	Suffix = "%",
	Callback = function(value) end,
})
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Min` / `Max` | `number` | `0` / `100` | Range. |
| `Default` | `number` | `Min` | Initial value. |
| `Step` | `number` | `1` | Snapping increment (`0` disables snapping). |
| `Decimals` | `number` | from `Step` | Displayed decimal places. |
| `Prefix` / `Suffix` | `string` | — | Text around the displayed number. |
| `Format` | `(value) -> string` | — | Custom display; overrides prefix/suffix/decimals. |

Interaction: drag the frame, or **Ctrl+Click** (double-click / double-tap on touch) to type a value.

Methods: `SetRange(min, max)`, `SetMin(n)`, `SetMax(n)`, `SetStep(n)`, `GetRange() -> (min, max)`.

Value: `number`, always clamped and snapped.

## Dropdown (saveable)

```lua
local mode = group:AddDropdown({
	Name = "Mode",
	Values = { "Default", "Advanced", "Experimental" },
	Default = "Default",
	Callback = function(value) end,
})
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Values` | `{ string }` | `{}` | Choices (non-strings are converted with `tostring`). |
| `Default` | `string` | first value | Initial selection. |
| `AllowNone` | `boolean` | `false` | Allows no selection. Clicking the selected value clears it. |
| `Searchable` | `boolean` | 12+ values | Shows a filter box in the list. |
| `Placeholder` | `string` | `"None"` | Text when nothing is selected. |
| `MaxVisible` | `number` | `10` | Rows before the list scrolls. |

Without `AllowNone`, the dropdown always has a valid selection. Unknown values passed to `SetValue` are ignored.

Methods: `SetValues(list)`, `GetValues()`, `AddValue(v)`, `RemoveValue(v)`, `IsSelected(v)`, `Open()`, `Close()`, `IsOpen()`.

Value: `string?`.

## MultiDropdown (saveable)

```lua
group:AddMultiDropdown({
	Name = "Layers",
	Values = { "Players", "NPCs", "Items" },
	Default = { "Players" },
	Callback = function(selected) print(table.concat(selected, ", ")) end,
})
```

Takes the same options and methods as Dropdown (except `AllowNone`). The list stays open while you pick.

Value: `{ string }`, the selected values in `Values` order. `SetValue` also accepts a set such as `{ Players = true }`.

## Input (saveable)

```lua
group:AddInput({
	Name = "Username",
	Placeholder = "Enter a name...",
	MaxLength = 20,
	Validate = function(text)
		return #text >= 3, "At least 3 characters"
	end,
})

group:AddInput({ Name = "Seed", Numeric = true, Min = 0, Max = 99999, Default = 42 })
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Default` | `string \| number` | `""` / `Min` | Initial value. |
| `Placeholder` | `string` | `""` | Hint while empty. |
| `Numeric` | `boolean` | `false` | Only numbers; value becomes a `number`. |
| `Min` / `Max` | `number` | — | Numeric clamping. |
| `MaxLength` | `number` | — | Maximum characters (enforced while typing). |
| `Validate` | `(value) -> (boolean, string?)` | — | Return `false` (and a message) to reject. |
| `Finished` | `boolean` | `true` | `true`: commit on Enter or focus loss. `false`: commit on every keystroke. |
| `ClearOnFocus` | `boolean` | `false` | Clear the text when focused. |

Rejected input flashes the field border in the theme's `Error` color and reverts to the last valid value. Signal: `Invalid(text, message)`. Methods: `SetPlaceholder(text)`, `Focus()`.

## Keybind (saveable)

```lua
group:AddKeybind({
	Name = "Fly",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
	Callback = function(active) end,
	ChangedCallback = function(key) end,
})
```

Click the keybind and press a key (or MB2 / MB3) to rebind it. **Escape** cancels and **Backspace/Delete** clears to `"None"`. **Right-click** opens the mode menu, unless `LockMode` is set. Keybinds are ignored while a TextBox has focus, and the captured key is sunk with ContextActionService so the game does not react to it.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Default` | `KeyCode \| UserInputType \| string` | `"None"` | Initial key. |
| `Mode` | `"Toggle" \| "Hold" \| "Press" \| "Always"` | `"Toggle"` | Activation mode. |
| `Callback` | `(active: boolean) -> ()` | — | Activation callback. |
| `ChangedCallback` | `(key: string) -> ()` | — | Called when rebound. |
| `Target` | Checkbox / Toggle | — | Drives another element (Toggle and Hold modes). |
| `LockMode` | `boolean` | `false` | Hides the mode menu. |

Modes: **Toggle** flips a state on each press. **Hold** is active while the key is held. **Press** fires `Callback(true)` on every press. **Always** is permanently active.

Value: the key name string (`"F"`, `"LeftShift"`, `"MouseButton2"`, `"None"`). Signals: `Changed(key)` on rebind, `Activated(active)`. Methods: `GetState()`, `SetMode(mode)`, `GetMode()`. Saved as `{ Key, Mode }`.

## ColorPicker (saveable)

```lua
group:AddColorPicker({
	Name = "Tint",
	Default = Color3.fromRGB(76, 141, 255),
	Transparency = 0,   -- include to enable the transparency bar
	Callback = function(color, transparency) end,
})
```

The swatch opens an editor with a saturation/value square, a hue bar, an optional transparency bar, and **R G B**, **H S V**, **Hex** and **T** (transparency) fields. Click the left half of the preview strip to revert to the color from when the editor opened.

Value: `Color3`. `SetValue` accepts a `Color3`, a `"#RRGGBB"` string, or `{ Color = c, Transparency = t }`. Methods: `GetTransparency()`, `SetTransparency(t, silent?)`, `GetHex()`, `Open()`, `Close()`, `IsOpen()`. Saved as `{ Color = "RRGGBB", Transparency = n }`.

## Label

```lua
group:AddLabel("Plain text")
group:AddLabel({ Text = "Connected", Style = "Success", Bullet = true })
```

| Option | Type | Description |
| --- | --- | --- |
| `Text` | `string` | The text. |
| `Style` | `"Default" \| "Secondary" \| "Disabled" \| "Accent" \| "Success" \| "Warning" \| "Error"` | Theme color. |
| `Color` | `Color3` | Explicit color (overrides `Style`). |
| `Bullet` | `boolean` | Leading bullet. |
| `Wrap` | `boolean` | Wrap instead of truncating. |
| `Align` | `"Left" \| "Center" \| "Right"` | Alignment. |
| `RichText` | `boolean` | Enable rich text tags. |

Methods: `SetText(text)`, `SetStyle(style)`, `SetColor(color?)`. `GetValue()` returns the text.

## Paragraph

```lua
group:AddParagraph({ Title = "About", Text = "Velumi is a compact UI library." })
```

Options: `Title`, `Text`, `RichText`. Methods: `SetTitle(text?)`, `SetText(text)`.

## Separator

```lua
group:AddSeparator()
group:AddSeparator("Advanced")   -- text on the left, rule fills the rest
```

Method: `SetText(text)`.

## ProgressBar

```lua
local bar = group:AddProgressBar({ Name = "Loading", Default = 0 })
bar:SetValue(0.75)
```

Options: `Default` (0..1), `Format(value) -> string`, `Style = "Accent" | "Success" | "Warning" | "Error"`. Value: `number` from 0 to 1. Not saved.

## Plot

```lua
local fps = group:AddPlot({ Name = "FPS", Type = "Lines", Min = 0, Max = 120 })
fps:Push(workspace:GetRealPhysicsFPS())
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Type` | `"Lines" \| "Histogram"` | `"Lines"` | Plot style. |
| `Values` | `{ number }` | — | Initial samples. |
| `Capacity` | `number` | `60` | Samples kept. |
| `Min` / `Max` | `number` | auto | Fixed scale. |
| `Height` | `number` | `56` | Pixel height. |
| `Format` | `(value) -> string` | 2 decimals | Overlay text for the latest sample. |

Methods: `Push(value)`, `SetValues(list)`, `GetValues()`, `Clear()`. `GetValue()` returns the latest sample. Not saved. Frames are pooled and reused, so pushing samples only updates existing frames.
