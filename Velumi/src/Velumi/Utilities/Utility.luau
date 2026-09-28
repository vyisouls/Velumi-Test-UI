--[[
	Utility
	Small, stateless helpers shared across the library.
]]

local Utility = {}

Utility.Prefix = "[Velumi]"

--------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------

function Utility.Warn(...: any)
	warn(Utility.Prefix, ...)
end

function Utility.Error(message: string, level: number?)
	error(`{Utility.Prefix} {message}`, (level or 1) + 1)
end

--- Runs a user callback on its own thread. Errors are reported with a
--- traceback instead of propagating into (and breaking) the library.
function Utility.SafeCall(callback: ((...any) -> ...any)?, ...: any)
	if type(callback) ~= "function" then
		return
	end
	task.spawn(function(...)
		local ok, err = xpcall(callback, debug.traceback, ...)
		if not ok then
			Utility.Warn("Callback error:\n" .. tostring(err))
		end
	end, ...)
end

--------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------

--- Creates an instance, applies properties (Parent last) and parents
--- children. `Utility.Create("Frame", { Size = ... }, { child1, child2 })`
function Utility.Create(className: string, properties: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil

	if properties then
		for property, value in properties do
			if property == "Parent" then
				parent = value
			else
				(instance :: any)[property] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

--- True when a screen-space point lies inside a GuiObject's bounds.
function Utility.IsPointInside(guiObject: GuiObject, point: Vector2): boolean
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

--- True if the GuiObject and all of its GuiObject ancestors are visible.
function Utility.IsVisibleOnScreen(guiObject: Instance?): boolean
	local current = guiObject
	while current do
		if current:IsA("GuiObject") then
			if not current.Visible then
				return false
			end
		elseif current:IsA("LayerCollector") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end

--------------------------------------------------------------------------
-- Tables
--------------------------------------------------------------------------

function Utility.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[Utility.DeepCopy(key)] = Utility.DeepCopy(item)
	end
	return (copy :: any) :: T
end

--- Returns a new table: `defaults` overlaid with `overrides`.
function Utility.Merge(defaults: { [any]: any }, overrides: { [any]: any }?): { [any]: any }
	local result = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			result[key] = value
		end
	end
	return result
end

--- Normalises the options argument of `AddX` calls. Accepts a table, a plain
--- string (treated as `Name`) or nil.
function Utility.Options(options: any, context: string): { [string]: any }
	if options == nil then
		return {}
	elseif type(options) == "string" then
		return { Name = options }
	elseif type(options) == "table" then
		return options
	end
	Utility.Error(`{context} expects an options table, got {typeof(options)}`, 3)
	return {}
end

--------------------------------------------------------------------------
-- Math
--------------------------------------------------------------------------

function Utility.Clamp(value: number, min: number, max: number): number
	if min > max then
		min, max = max, min
	end
	return math.clamp(value, min, max)
end

--- Rounds `value` to the nearest multiple of `step`, relative to `origin`.
function Utility.Snap(value: number, step: number?, origin: number?): number
	if not step or step <= 0 then
		return value
	end
	local base = origin or 0
	local snapped = base + math.floor((value - base) / step + 0.5) * step
	-- Remove floating point noise such as 0.30000000000000004.
	local decimals = Utility.DecimalsOf(step)
	local factor = 10 ^ decimals
	return math.floor(snapped * factor + 0.5) / factor
end

--- Number of decimal places needed to represent `step` (0.25 -> 2).
function Utility.DecimalsOf(step: number?): number
	if not step or step <= 0 then
		return 3
	end
	local text = string.format("%.6f", step):gsub("0+$", "")
	local dot = string.find(text, ".", 1, true)
	if not dot then
		return 0
	end
	return #text - dot
end

function Utility.FormatNumber(value: number, decimals: number): string
	if decimals <= 0 then
		return string.format("%d", math.floor(value + 0.5))
	end
	return string.format(`%.{decimals}f`, value)
end

--------------------------------------------------------------------------
-- Strings
--------------------------------------------------------------------------

--- Splits an ImGui-style label into its displayed text and its identifier.
--- "Speed##player" -> ("Speed", "Speed##player"); "##hidden" -> ("", "##hidden")
function Utility.ParseLabel(label: string?): (string, string)
	local text = label or ""
	local marker = string.find(text, "##", 1, true)
	if marker then
		return string.sub(text, 1, marker - 1), text
	end
	return text, text
end

--------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------

function Utility.ToHex(color: Color3): string
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Utility.FromHex(hex: string): Color3?
	if type(hex) ~= "string" then
		return nil
	end
	local clean = string.gsub(hex, "^#", "")
	if #clean == 3 then
		clean = string.gsub(clean, ".", "%0%0")
	end
	if #clean ~= 6 or string.find(clean, "[^%x]") then
		return nil
	end
	local r = tonumber(string.sub(clean, 1, 2), 16)
	local g = tonumber(string.sub(clean, 3, 4), 16)
	local b = tonumber(string.sub(clean, 5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

--- Relative luminance (0..1) following the sRGB definition.
function Utility.Luminance(color: Color3): number
	local function channel(value: number): number
		if value <= 0.03928 then
			return value / 12.92
		end
		return ((value + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

--- Picks black or white text for the best contrast on `background`.
function Utility.ContrastText(background: Color3): Color3
	if Utility.Luminance(background) > 0.36 then
		return Color3.fromRGB(16, 16, 16)
	end
	return Color3.fromRGB(245, 245, 245)
end

--------------------------------------------------------------------------
-- Input names
--------------------------------------------------------------------------

local SHORT_KEY_NAMES = {
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	LeftSuper = "LSuper",
	RightSuper = "RSuper",
	MouseButton1 = "MB1",
	MouseButton2 = "MB2",
	MouseButton3 = "MB3",
	Return = "Enter",
	Backspace = "Back",
	Insert = "Ins",
	Delete = "Del",
	PageUp = "PgUp",
	PageDown = "PgDn",
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

--- Normalises a key to its enum name. Accepts an Enum.KeyCode,
--- an Enum.UserInputType (mouse buttons) or a string.
function Utility.KeyName(key: any): string
	if key == nil then
		return "None"
	end
	if typeof(key) == "EnumItem" then
		return key.Name
	end
	if type(key) == "string" and key ~= "" then
		return key
	end
	return "None"
end

--- Short, human-readable key label for display ("LeftShift" -> "LShift").
function Utility.KeyDisplayName(name: string): string
	return SHORT_KEY_NAMES[name] or name
end

return Utility
