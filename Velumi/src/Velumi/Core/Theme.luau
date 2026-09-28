--[[
	Theme
	The centralized theme engine.

	• Themes are registered as *source* tables containing at least the core
	  keys (see `Theme.CoreKeys`). Every other key is derived from them, so a
	  custom theme that only changes `Accent` re-tints headers, grabs,
	  check marks and title bars automatically.

	• UI instances never hold hard-coded colors. They are *bound* to theme
	  keys with `Theme.Bind(instance, { BackgroundColor3 = "Frame" })`, or to a
	  function of the palette for state-dependent styling:

	      Theme.Bind(box, {
	          BackgroundColor3 = function(t)
	              return self._hovered and t.FrameHover or t.Frame
	          end,
	      })

	  `Theme.Refresh(box, true)` re-evaluates the binding (optionally tweened)
	  after the state changes. `Theme.Set(name)` re-applies every binding.
]]

local Animation = require(script.Parent.Animation)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Themes = script.Parent.Parent.Themes

local Theme = {}

--- Keys every theme must provide (after merging with its base theme).
Theme.CoreKeys = {
	"Background",
	"Window",
	"Child",
	"Border",
	"Text",
	"SecondaryText",
	"DisabledText",
	"Hover",
	"Active",
	"Accent",
	"Success",
	"Warning",
	"Error",
}

--- Non-color defaults shared by every theme unless overridden.
Theme.BaseDefaults = {
	Font = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
	TextSize = 13,
	Rounding = 2,
	WindowRounding = 3,
	WindowTransparency = 0,
	ModalDimTransparency = 0.45,
	ModalDim = Color3.new(0, 0, 0),
}

local WHITE = Color3.new(1, 1, 1)

--- Derived keys, evaluated in order. Later entries may use earlier ones.
Theme.Derived = {
	{
		"Frame",
		function(t)
			return t.Window:Lerp(t.Hover, 0.6)
		end,
	},
	{
		"FrameHover",
		function(t)
			return t.Hover
		end,
	},
	{
		"FrameActive",
		function(t)
			return t.Active
		end,
	},

	{
		"Button",
		function(t)
			return t.Window:Lerp(t.Active, 0.55)
		end,
	},
	{
		"ButtonHover",
		function(t)
			return t.Active:Lerp(t.Accent, 0.18)
		end,
	},
	{
		"ButtonActive",
		function(t)
			return t.Active:Lerp(t.Accent, 0.4)
		end,
	},

	{
		"Header",
		function(t)
			return t.Window:Lerp(t.Accent, 0.28)
		end,
	},
	{
		"HeaderHover",
		function(t)
			return t.Window:Lerp(t.Accent, 0.4)
		end,
	},
	{
		"HeaderActive",
		function(t)
			return t.Window:Lerp(t.Accent, 0.55)
		end,
	},

	{
		"TitleBar",
		function(t)
			return t.Background
		end,
	},
	{
		"TitleBarActive",
		function(t)
			return t.Background:Lerp(t.Accent, 0.22)
		end,
	},
	{
		"MenuBar",
		function(t)
			return t.Background:Lerp(t.Window, 0.55)
		end,
	},
	{
		"Sidebar",
		function(t)
			return t.Background:Lerp(t.Window, 0.4)
		end,
	},
	{
		"StatusBar",
		function(t)
			return t.Background
		end,
	},

	{
		"Separator",
		function(t)
			return t.Border
		end,
	},
	{
		"ScrollBar",
		function(t)
			return t.Active:Lerp(t.SecondaryText, 0.2)
		end,
	},
	{
		"Popup",
		function(t)
			return t.Background:Lerp(t.Window, 0.5)
		end,
	},
	{
		"Tooltip",
		function(t)
			return t.Popup
		end,
	},

	{
		"SliderGrab",
		function(t)
			return t.Accent
		end,
	},
	{
		"SliderGrabActive",
		function(t)
			return t.Accent:Lerp(WHITE, 0.25)
		end,
	},
	{
		"CheckMark",
		function(t)
			return t.Accent
		end,
	},
	{
		"AccentText",
		function(t)
			return Utility.ContrastText(t.Accent)
		end,
	},
	{
		"Info",
		function(t)
			return t.Accent
		end,
	},
	{
		"Placeholder",
		function(t)
			return t.DisabledText
		end,
	},
	{
		"ResizeGrip",
		function(t)
			return t.Border
		end,
	},
	{
		"ResizeGripHover",
		function(t)
			return t.Accent
		end,
	},
	{
		"Plot",
		function(t)
			return t.Accent
		end,
	},
	{
		"PlotHistogram",
		function(t)
			return t.Warning
		end,
	},

	{
		"FontBold",
		function(t)
			return Font.new(t.Font.Family, Enum.FontWeight.Bold)
		end,
	},
}

Theme.Changed = Signal.new() -- (name: string, palette)

Theme.Name = "Dark"
Theme.Palette = {} :: { [string]: any }

local sources: { [string]: { [string]: any } } = {}
local bindings: { [Instance]: { [string]: any } } = {}
local bindingCount = 0
local pruneAt = 512
local prunePending = false
local warnedKeys = {}

--------------------------------------------------------------------------
-- Palette construction
--------------------------------------------------------------------------

--- Builds a full palette from a source table: base defaults, the source
--- itself, then every derived key the source did not set explicitly.
function Theme.Derive(source: { [string]: any }): { [string]: any }
	local palette = table.clone(Theme.BaseDefaults)
	for key, value in source do
		palette[key] = value
	end

	for _, key in Theme.CoreKeys do
		if typeof(palette[key]) ~= "Color3" then
			Utility.Error(`Theme is missing core color "{key}"`, 3)
		end
	end

	for _, entry in Theme.Derived do
		local key, derive = entry[1], entry[2]
		if source[key] == nil then
			palette[key] = derive(palette)
		end
	end

	return palette
end

--- Registers (or replaces) a theme. `definition` may be partial; missing keys
--- are taken from `baseName` (default "Dark").
function Theme.Register(name: string, definition: { [string]: any }, baseName: string?)
	assert(type(name) == "string" and name ~= "", "Theme name must be a non-empty string")
	assert(type(definition) == "table", "Theme definition must be a table")

	local base = baseName or "Dark"
	local source = {}
	if name ~= base and sources[base] then
		for key, value in sources[base] do
			source[key] = value
		end
	end
	for key, value in definition do
		source[key] = value
	end

	-- Validate eagerly so errors point at the RegisterTheme call.
	Theme.Derive(source)
	sources[name] = source

	if Theme.Name == name then
		Theme.Set(name)
	end
end

function Theme.Exists(name: string): boolean
	return sources[name] ~= nil
end

function Theme.GetNames(): { string }
	local names = {}
	for name in sources do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--- Returns a copy of the source definition for a registered theme.
function Theme.GetDefinition(name: string): { [string]: any }?
	local source = sources[name]
	return source and table.clone(source)
end

--------------------------------------------------------------------------
-- Bindings
--------------------------------------------------------------------------

local function resolve(value: any): any
	if type(value) == "string" then
		local resolved = Theme.Palette[value]
		if resolved == nil and not warnedKeys[value] then
			warnedKeys[value] = true
			Utility.Warn(`Unknown theme key "{value}"`)
		end
		return resolved
	elseif type(value) == "function" then
		return value(Theme.Palette)
	end
	return value
end

Theme.Resolve = resolve

local function apply(instance: Instance, props: { [string]: any }, animated: boolean?)
	local tweenProps
	for property, source in props do
		local value = resolve(source)
		if value ~= nil then
			if animated and typeof(value) == "Color3" then
				tweenProps = tweenProps or {}
				tweenProps[property] = value
			else
				(instance :: any)[property] = value
			end
		end
	end
	if tweenProps then
		Animation.Tween(instance, tweenProps, Animation.Durations.Fast)
	end
end

local function prune()
	prunePending = false
	local count = 0
	for instance in bindings do
		if instance.Parent == nil then
			bindings[instance] = nil
		else
			count += 1
		end
	end
	bindingCount = count
	pruneAt = math.max(512, count * 2)
end

--- Binds instance properties to theme keys or palette functions and applies
--- them immediately. Calling Bind again on the same instance merges props.
function Theme.Bind<T>(instance: T, props: { [string]: any }): T
	local existing = bindings[instance :: any]
	if existing then
		for property, source in props do
			existing[property] = source
		end
	else
		bindings[instance :: any] = table.clone(props)
		bindingCount += 1
		if bindingCount >= pruneAt and not prunePending then
			-- Deferred so instances still being constructed are parented first.
			prunePending = true
			task.defer(prune)
		end
	end
	apply(instance :: any, props, false)
	return instance
end

function Theme.Unbind(instance: Instance)
	if bindings[instance] then
		bindings[instance] = nil
		bindingCount -= 1
	end
end

--- Removes the bindings of an instance and all of its descendants.
function Theme.UnbindTree(root: Instance)
	Theme.Unbind(root)
	for _, descendant in root:GetDescendants() do
		if bindings[descendant] then
			bindings[descendant] = nil
			bindingCount -= 1
		end
	end
end

--- Re-evaluates an instance's bindings (after a state change).
function Theme.Refresh(instance: Instance, animated: boolean?)
	local props = bindings[instance]
	if props then
		apply(instance, props, animated)
	end
end

--------------------------------------------------------------------------
-- Switching
--------------------------------------------------------------------------

--- Activates a registered theme by name, or a theme table (registered as
--- "Custom" on top of Dark). Every bound instance updates immediately.
function Theme.Set(theme: string | { [string]: any })
	local name: string
	if type(theme) == "table" then
		Theme.Register("Custom", theme)
		name = "Custom"
	else
		name = theme
	end

	local source = sources[name]
	if not source then
		Utility.Warn(`Theme "{tostring(name)}" is not registered. Available: {table.concat(Theme.GetNames(), ", ")}`)
		return
	end

	Theme.Name = name
	Theme.Palette = Theme.Derive(source)

	prune()
	for instance, props in bindings do
		apply(instance, props, false)
	end

	Theme.Changed:Fire(name, Theme.Palette)
end

function Theme.Get(key: string): any
	return Theme.Palette[key]
end

--------------------------------------------------------------------------
-- Built-in themes
--------------------------------------------------------------------------

for _, module in { "Dark", "Light", "Midnight", "Gray", "Classic" } do
	Theme.Register(module, require(Themes:FindFirstChild(module) :: ModuleScript), "Dark")
end

Theme.Name = "Dark"
Theme.Palette = Theme.Derive(sources.Dark)

return Theme
