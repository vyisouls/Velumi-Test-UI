# Contributing to Velumi

Thanks for helping! This guide covers how the library is put together, how to add an element, the conventions the code follows and how to test changes.

## Getting set up

Tools (install with [Rokit](https://github.com/rojo-rbx/rokit) via `rokit install`, or individually):

| Tool | Used for |
| --- | --- |
| [Rojo](https://rojo.space) | Syncing into Studio, building `Velumi.rbxm` |
| [Lune](https://lune-org.github.io/docs) | Running the headless test suite |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | Formatting |

```bash
rojo serve showcase.project.json   # live-sync library + showcase into a place
lune run tests/run                 # run the test suite
stylua src tests examples          # format
```

## Architecture

```text
src/Velumi/
├── init.luau            Public library facade (Velumi:CreateWindow, SetTheme, Notify...)
├── Core/
│   ├── Context.luau     Library-wide state: ScreenGui + layers, window registry,
│   │                    focus/z-order, popup stack, viewport, reference counting
│   ├── Input.luau       The only UserInputService connections: drags, key dispatch,
│   │                    key capture (with ContextActionService), raw listeners
│   ├── Theme.luau       Theme registry, palette derivation, instance bindings
│   ├── Animation.luau   TweenService wrapper (one tween per instance, cancellable)
│   ├── Layout.luau      Metrics and theme-bound primitive builders (rows, text,
│   │                    corners, strokes, chevrons, check marks)
│   ├── Config.luau      Per-window flag registry, serialize / load / JSON
│   ├── Window.luau      Window chrome, geometry, tabs, menus, status bar
│   ├── Tab.luau         Tab button + scrolling page with columns
│   ├── Container.luau   Shared Add* API, SameLine, Indent, Begin/EndChild, Rebuild
│   ├── Group.luau       Titled panel (a Container)
│   ├── Section.luau     Collapsing header / tree node (a Container)
│   ├── Child.luau       Scrolling child region (a Container)
│   └── Element.luau     Base class for every control
├── Elements/            One module per control, each extending Element
├── Components/          Shared overlays: Tooltip, ContextMenu, MenuBar,
│                        Notification, Modal
├── Themes/              Built-in theme definitions (core keys only)
└── Utilities/           Signal, Maid, Utility helpers, public Types
```

### Ownership and cleanup

Cleanup is the most important invariant in Velumi. **Every object owns exactly one `Maid`**, and everything it creates goes into that Maid: instances, connections, threads, tweens and child objects.

- `Window:Destroy()` destroys its tabs, which destroy their groups, which destroy their elements. Each level cleans its own Maid, cancels its tweens (`Animation.CancelTree`) and drops its theme bindings (`Theme.UnbindTree`).
- Global state is **reference counted**. Windows, notifications and modals call `Context.Retain()` / `Context.Release(generation)`. When the count reaches zero, the ScreenGui and the three global input connections are removed.
- Popups (dropdown lists, color pickers, menus) are created when opened and destroyed when closed.

The test suite checks this. After `Window:Destroy()` and `Velumi:Destroy()`, the mock engine must report **zero** live connections.

### Input

Components must not connect to `UserInputService` themselves. Use `Core/Input`:

```lua
Input.BeginDrag(input, { OnMove = function(position, delta) end, OnEnd = function() end })
Input.BindKey("F", target)            -- target:_keyDown() / target:_keyUp()
Input.CaptureKey(function(key) end)   -- next key; nil = cancelled
local unsubscribe = Input.Subscribe("Began", function(input, processed) end)
Input.GetPointerPosition(input?)      -- screen space matching AbsolutePosition
```

Per-instance events (`MouseEnter`, `Activated`, `InputBegan` on a specific GuiObject) are fine. Give their connections to your Maid.

### Theming

Never assign a color, font, text size or corner radius directly. Bind it:

```lua
Theme.Bind(instance, { BackgroundColor3 = "Frame", TextColor3 = "Text" })
self:_bind(instance, {                              -- inside an element
	BackgroundColor3 = function(t)
		return self._hovered and t.FrameHover or t.Frame
	end,
})
self:_restyle(true)                                 -- after state changes (animated)
```

The `Layout` builders (`Layout.Text`, `Layout.Corner`, `Layout.Stroke`, `Layout.FrameBox`...) bind for you. The only fixed colors in the codebase are the color picker's cursor colors, which must contrast with the picked color rather than with the theme.

### Performance rules

- No `RenderStepped` / `Heartbeat` loops. Everything is event-driven.
- Popups are built on open and destroyed on close.
- Hover and press states re-evaluate only the element's own bound instances.
- Prefer `Animation.Tween` (which cancels previous tweens per instance) over raw TweenService.

## Writing a custom element

Elements are classes created with `Element.extend`. The base class supplies the whole shared API (`SetValue`, `SetVisible`, `SetDisabled`, tooltips, context menus, flags, `Bind`, `Destroy`). A subclass implements a few hooks:

| Hook | Required | Purpose |
| --- | --- | --- |
| `_build()` | yes | Create instances and set `self.Root`. Give connections to `self._maid`. |
| `_apply(value) -> changed` | for valued elements | Normalize and display a value, set `self.Value`, and return whether it changed. |
| `_serialize()` / `_deserialize(data)` | if non-trivial | JSON-safe config form. Defaults to the raw value. |
| `_callbackArgs()` | optional | Arguments passed to `Callback` / `Changed` (default: `self.Value`). |
| `_onDisabledChanged(disabled)` | optional | Close popups, release focus... |
| `_onDestroy()` | optional | Extra cleanup before the Maid runs. |

Class fields: `Saveable = true` to join configuration, and `Fill = true` to share row width on `SameLine`.

Example, as a standalone extension:

```lua
local Velumi = require(ReplicatedStorage.Velumi)
local Element = Velumi.Element

local Stepper = Element.extend("Stepper")
Stepper.Saveable = true
Stepper.Fill = true

function Stepper:_build()
	local labeled = self:_labeled()                  -- "[ widget ] Label" layout
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.AutoButtonColor = false
	self:_bind(button, {
		BackgroundColor3 = function(t)
			return self._hovered and t.FrameHover or t.Frame
		end,
		TextColor3 = "Text",
		FontFace = "Font",
		TextSize = "TextSize",
	})
	button.Parent = labeled.Widget
	self:_track(button)                              -- hover/press state + restyle
	self._button = button
	self._maid:Give(button.Activated:Connect(function()
		if not self._disabled then
			self:SetValue(self.Value + (self.Options.Step or 1))
		end
	end))
	self.Root = labeled.Root
end

function Stepper:_apply(value)
	local number = tonumber(value) or 0
	local changed = self.Value ~= number
	self.Value = number
	self._button.Text = tostring(number)
	return changed
end

Velumi:RegisterElement("Stepper", Stepper)

group:AddStepper({ Name = "Count", Default = 0, Step = 5, Flag = "Count" })
```

To add a built-in element instead: create `src/Velumi/Elements/Name.luau`, add it to the `Classes` table and add an `AddName` method in `Core/Container.luau`, add its types to `Utilities/Types.luau`, document it in `docs/ELEMENTS.md`, show it in the showcase and cover it in `tests/suite.luau`.

## Code style

- Luau, formatted with StyLua (`stylua.toml`): tabs, 120 columns, double quotes.
- `PascalCase` for public methods and options, `_camelCase` for private fields and methods.
- Public options mirror existing names: `Name`, `Default`, `Callback`, `Flag`, `Tooltip`, `Disabled`...
- Every module starts with a short doc comment explaining its purpose and usage.
- Keep modules cohesive. Avoid splitting something into tiny files unless it is reused.
- Don't use exploit or executor APIs (`getgenv`, `gethui`, `syn.*`, `Drawing`, `hookfunction`...), `loadstring`, or filesystem access.

## Testing

`tests/mock/Roblox.luau` is a strict, headless mock of the engine APIs Velumi uses. Setting a property a class doesn't have, using an invalid enum item or assigning the wrong type raises an error, just like in Roblox. The mock also counts live connections and instances.

`tests/suite.luau` loads the real `src/` tree, simulates input (clicks, drags, typing, key presses) and asserts behavior. It also runs `examples/Showcase.client.luau` end to end.

```bash
lune run tests/run
```

When you add a feature:

1. Add a test to `tests/suite.luau` that exercises it through the public API.
2. If you use an engine API the mock doesn't know yet, add it to `tests/mock/Roblox.luau` with the real API's name and types.
3. Make sure the leak tests (`window destroy releases everything`, `showcase runs and cleans up`) still pass.

The mock does not simulate layout or rendering precisely, so check visual changes in Studio with `rojo serve showcase.project.json`.

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused; update the docs and `CHANGELOG.md` (Unreleased section).
3. Run `stylua --check src tests examples` and `lune run tests/run`.
4. Describe what changed and, for visual changes, include a screenshot.

By contributing you agree that your contributions are licensed under the MIT License.
