# Themes

Velumi has one centralized theme engine. No UI instance holds a hard-coded color. Every color, font, text size and corner radius is *bound* to a theme key, so switching themes restyles every open window instantly.

```lua
Velumi:SetTheme("Light")
```

## Built-in themes

| Name | Description |
| --- | --- |
| `Dark` | Default. Charcoal surfaces, blue accent. |
| `Light` | Bright surfaces for well-lit screens. |
| `Midnight` | Blue-black surfaces, violet accent. |
| `Gray` | Lighter neutral gray, teal accent. |
| `Classic` | Navy title bars and blue-tinted frames, like a traditional immediate-mode toolkit. |

## Core keys

A theme needs only these thirteen colors (the Dark values are shown):

```lua
{
	Background = Color3.fromRGB(23, 23, 23),    -- title bars, status bar, darkest surfaces
	Window = Color3.fromRGB(30, 30, 30),        -- window body
	Child = Color3.fromRGB(25, 25, 25),         -- groups, child regions

	Border = Color3.fromRGB(52, 52, 52),

	Text = Color3.fromRGB(230, 230, 230),
	SecondaryText = Color3.fromRGB(160, 160, 160),
	DisabledText = Color3.fromRGB(100, 100, 100),

	Hover = Color3.fromRGB(42, 42, 42),
	Active = Color3.fromRGB(51, 51, 51),

	Accent = Color3.fromRGB(76, 141, 255),

	Success = Color3.fromRGB(85, 181, 106),
	Warning = Color3.fromRGB(217, 164, 65),
	Error = Color3.fromRGB(224, 82, 82),
}
```

## Derived keys

Every other key is computed from the core keys unless your theme sets it explicitly. Because of this, a theme that only changes `Accent` still re-tints headers, grabs, check marks and the focused title bar.

| Key | Derived from | Used by |
| --- | --- | --- |
| `Frame`, `FrameHover`, `FrameActive` | `Window` → `Hover`, `Hover`, `Active` | Widget backgrounds (slider, input, dropdown, checkbox box) |
| `Button`, `ButtonHover`, `ButtonActive` | `Window`/`Active` blended toward `Accent` | Buttons, arrow boxes |
| `Header`, `HeaderHover`, `HeaderActive` | `Window` blended toward `Accent` | Selected tabs, section headers, list selection, menus |
| `TitleBar`, `TitleBarActive` | `Background`, `Background` → `Accent` | Title bars (active = focused window) |
| `MenuBar`, `Sidebar`, `StatusBar` | `Background` / `Window` | Window chrome |
| `Separator` | `Border` | Rules and dividers |
| `ScrollBar` | `Active` → `SecondaryText` | Scroll bars |
| `Popup`, `Tooltip` | `Background` → `Window` | Dropdown lists, menus, notifications, tooltips |
| `SliderGrab`, `SliderGrabActive` | `Accent` | Slider grab |
| `CheckMark` | `Accent` | Check marks |
| `AccentText` | contrast of `Accent` | Text on accent backgrounds |
| `Info` | `Accent` | Info notifications |
| `Placeholder` | `DisabledText` | Placeholder text |
| `ResizeGrip`, `ResizeGripHover` | `Border`, `Accent` | Window resize grip |
| `Plot`, `PlotHistogram` | `Accent`, `Warning` | Plots |
| `FontBold` | `Font` | Group titles, notification titles |

## Style keys

These non-color keys are part of the theme too:

| Key | Default | Description |
| --- | --- | --- |
| `Font` | `Font.new("rbxasset://fonts/families/RobotoMono.json")` | UI font. |
| `TextSize` | `13` | Text size. |
| `Rounding` | `2` | Corner radius of widgets (keep it in the 0–3 range). |
| `WindowRounding` | `3` | Corner radius of windows and dialogs. |
| `WindowTransparency` | `0` | Window background transparency. |
| `ModalDim`, `ModalDimTransparency` | black, `0.45` | Backdrop behind modals. |

## Custom themes

```lua
-- Only the accent: everything else comes from Dark, derived keys follow the accent.
Velumi:RegisterTheme("Sakura", {
	Accent = Color3.fromRGB(255, 100, 150),
})

-- Based on another theme.
Velumi:RegisterTheme("Paper", {
	Accent = Color3.fromRGB(200, 90, 40),
	Rounding = 0,
}, "Light")

-- A full theme with a different font.
Velumi:RegisterTheme("Terminal", {
	Background = Color3.fromRGB(8, 10, 8),
	Window = Color3.fromRGB(12, 16, 12),
	Child = Color3.fromRGB(10, 13, 10),
	Border = Color3.fromRGB(30, 60, 30),
	Text = Color3.fromRGB(170, 255, 170),
	SecondaryText = Color3.fromRGB(100, 170, 100),
	DisabledText = Color3.fromRGB(60, 90, 60),
	Hover = Color3.fromRGB(20, 34, 20),
	Active = Color3.fromRGB(26, 46, 26),
	Accent = Color3.fromRGB(80, 255, 120),
	Success = Color3.fromRGB(80, 255, 120),
	Warning = Color3.fromRGB(255, 220, 80),
	Error = Color3.fromRGB(255, 90, 90),
	Font = Font.fromEnum(Enum.Font.Code),
})

Velumi:SetTheme("Sakura")
```

A theme table can also be applied directly. It is registered as `"Custom"` on top of Dark:

```lua
Velumi:SetTheme({ Accent = Color3.fromRGB(0, 200, 120) })
```

If you register a theme under the name of the active theme, the UI updates immediately. This makes live accent pickers easy:

```lua
group:AddColorPicker({
	Name = "Accent",
	Default = Color3.fromRGB(76, 141, 255),
	Callback = function(color)
		Velumi:RegisterTheme("User", { Accent = color })
		Velumi:SetTheme("User")
	end,
})
```

## Reading the palette

```lua
Velumi:GetTheme()                 --> "Dark"
Velumi:GetThemes()                --> { "Classic", "Dark", "Gray", "Light", "Midnight" }
Velumi:GetThemeValue("Accent")    --> Color3
Velumi:GetPalette()               --> copy of every key

Velumi.ThemeChanged:Connect(function(name, palette)
	print("theme is now", name)
end)
```

## Theming your own instances

Custom elements should bind their instances instead of assigning colors directly (see [CONTRIBUTING.md](CONTRIBUTING.md)):

```lua
-- inside an element's _build()
self:_bind(frame, {
	BackgroundColor3 = function(t)
		return self._hovered and t.FrameHover or t.Frame
	end,
	BackgroundTransparency = "WindowTransparency",
})
```

String values name a palette key. Functions receive the palette and are re-evaluated on theme changes and on `self:_restyle()`.
