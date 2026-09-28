--[[
	A headless mock of the parts of the Roblox engine API Velumi uses.

	It is intentionally strict: setting or reading a property that the real
	class does not have raises "X is not a valid member of Y", and enum items
	are validated against known names. This catches typos and API misuse
	without opening Studio.

	Layout is approximated (scale + offset against the parent; list layouts
	and automatic sizing are not simulated), tweens complete on the next
	scheduler step, and time is virtual (see `Mock.advance`).

	Usage (see tests/run.luau):
	    local Mock = loadMock(host)
	    local env = Mock.environment()     -- globals for loaded chunks
	    local Velumi = Mock.requireTree("src/Velumi")
]]

local Mock = {}

--------------------------------------------------------------------------
-- Scheduler (virtual time)
--------------------------------------------------------------------------

local clock = 0
local deferred = {}
local timers = {}
local cancelled = setmetatable({}, { __mode = "k" })

local function resume(thread, ...)
	if cancelled[thread] then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error(debug.traceback(thread, tostring(err)), 0)
	end
end

local function toThread(fn)
	if type(fn) == "thread" then
		return fn
	end
	return coroutine.create(fn)
end

local taskLib = {}

function taskLib.spawn(fn, ...)
	local thread = toThread(fn)
	resume(thread, ...)
	return thread
end

function taskLib.defer(fn, ...)
	local thread = toThread(fn)
	table.insert(deferred, { thread = thread, args = table.pack(...) })
	return thread
end

function taskLib.delay(seconds, fn, ...)
	local thread = toThread(fn)
	table.insert(timers, { at = clock + (seconds or 0), thread = thread, args = table.pack(...) })
	return thread
end

function taskLib.wait(seconds)
	local thread = coroutine.running()
	table.insert(timers, { at = clock + (seconds or 0.03), thread = thread, args = table.pack() })
	coroutine.yield()
	return seconds or 0.03
end

function taskLib.cancel(thread)
	cancelled[thread] = true
	if coroutine.status(thread) == "suspended" then
		coroutine.close(thread)
	end
end

--- Runs deferred threads (repeatedly, until none are queued).
function Mock.flush()
	local guard = 0
	while #deferred > 0 do
		guard += 1
		assert(guard < 10000, "deferred loop")
		local queue = deferred
		deferred = {}
		for _, item in queue do
			if coroutine.status(item.thread) == "suspended" then
				resume(item.thread, table.unpack(item.args, 1, item.args.n))
			end
		end
	end
end

--- Advances virtual time, running timers that become due.
function Mock.advance(seconds)
	local target = clock + seconds
	while true do
		Mock.flush()
		table.sort(timers, function(a, b)
			return a.at < b.at
		end)
		local nextTimer = timers[1]
		if not nextTimer or nextTimer.at > target then
			break
		end
		table.remove(timers, 1)
		clock = math.max(clock, nextTimer.at)
		if coroutine.status(nextTimer.thread) == "suspended" then
			resume(nextTimer.thread, table.unpack(nextTimer.args, 1, nextTimer.args.n))
		end
	end
	clock = target
	Mock.flush()
end

function Mock.now()
	return clock
end

--------------------------------------------------------------------------
-- typeof
--------------------------------------------------------------------------

local TYPE_KEY = {}

local function mockTypeof(value)
	if type(value) == "table" then
		local mt = getmetatable(value)
		if type(mt) == "table" and rawget(mt, TYPE_KEY) then
			return rawget(mt, TYPE_KEY)
		end
	end
	return typeof(value)
end

local function valueType(name, index)
	local mt = { [TYPE_KEY] = name }
	mt.__index = index
	mt.__tostring = function()
		return name
	end
	return mt
end

--------------------------------------------------------------------------
-- Signals (RBXScriptSignal)
--------------------------------------------------------------------------

local liveConnections = 0

local ConnectionMT = valueType("RBXScriptConnection", {})
ConnectionMT.__index = function(self, key)
	if key == "Disconnect" then
		return function(conn)
			if rawget(conn, "Connected") then
				rawset(conn, "Connected", false)
				liveConnections -= 1
				local list = rawget(conn, "_list")
				local index = table.find(list, conn)
				if index then
					table.remove(list, index)
				end
			end
		end
	end
	return nil
end

local SignalMT = valueType("RBXScriptSignal", {})

local function newSignal(name)
	local signal = setmetatable({ _name = name, _handlers = {} }, SignalMT)
	return signal
end

SignalMT.__index = function(self, key)
	if key == "Connect" then
		return function(sig, fn)
			assert(type(fn) == "function", "Connect expects a function")
			local conn = setmetatable({ Connected = true, _fn = fn, _list = sig._handlers }, ConnectionMT)
			table.insert(sig._handlers, conn)
			liveConnections += 1
			return conn
		end
	elseif key == "Once" then
		return function(sig, fn)
			local conn
			conn = sig:Connect(function(...)
				conn:Disconnect()
				fn(...)
			end)
			return conn
		end
	elseif key == "Wait" then
		return function(sig)
			local thread = coroutine.running()
			sig:Once(function(...)
				taskLib.spawn(thread, ...)
			end)
			return coroutine.yield()
		end
	end
	error(`{key} is not a valid member of RBXScriptSignal`, 2)
end

local function fire(signal, ...)
	for _, conn in table.clone(signal._handlers) do
		if conn.Connected then
			taskLib.spawn(conn._fn, ...)
		end
	end
end

local function disconnectAll(signal)
	for _, conn in table.clone(signal._handlers) do
		conn:Disconnect()
	end
end

function Mock.liveConnections()
	return liveConnections
end

Mock.fire = fire

--------------------------------------------------------------------------
-- Enums
--------------------------------------------------------------------------

local ENUMS = {
	AutomaticSize = { "None", "X", "Y", "XY" },
	ApplyStrokeMode = { "Contextual", "Border" },
	ContextActionResult = { "Sink", "Pass" },
	ContextActionPriority = { "Low", "Medium", "Default", "High" },
	EasingDirection = { "In", "Out", "InOut" },
	EasingStyle = {
		"Linear",
		"Sine",
		"Back",
		"Quad",
		"Quart",
		"Quint",
		"Bounce",
		"Elastic",
		"Exponential",
		"Circular",
		"Cubic",
	},
	ElasticBehavior = { "WhenScrollable", "Always", "Never" },
	FillDirection = { "Horizontal", "Vertical" },
	Font = { "Legacy", "Arial", "SourceSans", "Gotham", "Code", "RobotoMono", "BuilderSans", "Ubuntu" },
	FontWeight = { "Thin", "ExtraLight", "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Heavy" },
	HorizontalAlignment = { "Center", "Left", "Right" },
	VerticalAlignment = { "Center", "Top", "Bottom" },
	ScrollBarInset = { "None", "ScrollBar", "Always" },
	ScrollingDirection = { "X", "Y", "XY" },
	SortOrder = { "Name", "Custom", "LayoutOrder" },
	TextTruncate = { "None", "AtEnd", "SplitWord" },
	TextXAlignment = { "Left", "Center", "Right" },
	TextYAlignment = { "Top", "Center", "Bottom" },
	UIFlexMode = { "None", "Grow", "Shrink", "Fill", "Custom" },
	UIFlexAlignment = { "None", "Fill", "SpaceAround", "SpaceBetween", "SpaceEvenly" },
	UserInputState = { "Begin", "Change", "End", "Cancel", "None" },
	UserInputType = {
		"MouseButton1",
		"MouseButton2",
		"MouseButton3",
		"MouseWheel",
		"MouseMovement",
		"Touch",
		"Keyboard",
		"Focus",
		"Accelerometer",
		"Gyro",
		"Gamepad1",
		"TextInput",
		"None",
	},
	ZIndexBehavior = { "Global", "Sibling" },
	PlaybackState = { "Begin", "Delayed", "Playing", "Paused", "Completed", "Cancelled" },
	ScreenInsets = { "None", "DeviceSafeInsets", "CoreUISafeInsets", "TopbarSafeInsets" },
	-- KeyCode is open-ended; see below.
}

local PRIORITY_VALUES = { Low = 1000, Medium = 2000, Default = 2000, High = 3000 }

local enumCache = {}
local EnumItemMT = valueType("EnumItem", {})
EnumItemMT.__index = function(self, key)
	error(`{key} is not a valid member of EnumItem`, 2)
end
EnumItemMT.__tostring = function(self)
	return `Enum.{rawget(self, "EnumType")}.{rawget(self, "Name")}`
end

local function enumItem(enumName, itemName, value)
	enumCache[enumName] = enumCache[enumName] or {}
	local item = enumCache[enumName][itemName]
	if not item then
		item = setmetatable({ Name = itemName, EnumType = enumName, Value = value or 0 }, EnumItemMT)
		enumCache[enumName][itemName] = item
	end
	return item
end

local EnumMT = valueType("Enum", {})
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local known = ENUMS[enumName]
		if not known and enumName ~= "KeyCode" then
			error(`{enumName} is not a valid Enum (mock: add it to ENUMS if real)`, 2)
		end
		return setmetatable({}, {
			__index = function(_, itemName)
				if enumName == "KeyCode" then
					return enumItem(enumName, itemName, #itemName)
				end
				local index = table.find(known, itemName)
				if not index then
					error(`{itemName} is not a valid member of Enum.{enumName}`, 2)
				end
				local value = if enumName == "ContextActionPriority" then PRIORITY_VALUES[itemName] else index - 1
				return enumItem(enumName, itemName, value)
			end,
		})
	end,
})
local _ = EnumMT

--------------------------------------------------------------------------
-- Data types
--------------------------------------------------------------------------

local Vector2 = {}
local Vector2MT = valueType("Vector2", nil)
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2MT)
end
Vector2MT.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y)
		return v2(self.X / m, self.Y / m)
	end
	error(`{key} is not a valid member of Vector2`, 2)
end
Vector2MT.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
Vector2MT.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
Vector2MT.__mul = function(a, b)
	if type(a) == "number" then
		return v2(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
Vector2MT.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
Vector2MT.__unm = function(a)
	return v2(-a.X, -a.Y)
end
Vector2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
Vector2MT.__tostring = function(a)
	return `{a.X}, {a.Y}`
end
Vector2.new = v2
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)

local UDim = {}
local UDimMT = valueType("UDim", nil)
UDimMT.__index = function(_, key)
	error(`{key} is not a valid member of UDim`, 2)
end
local function udim(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMT)
end
UDimMT.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UDimMT.__add = function(a, b)
	return udim(a.Scale + b.Scale, a.Offset + b.Offset)
end
UDim.new = udim

local UDim2 = {}
local UDim2MT = valueType("UDim2", nil)
UDim2MT.__index = function(self, key)
	if key == "Width" then
		return rawget(self, "X")
	elseif key == "Height" then
		return rawget(self, "Y")
	end
	error(`{key} is not a valid member of UDim2`, 2)
end
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UDim2MT)
end
UDim2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UDim2MT.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2MT.__sub = function(a, b)
	return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UDim2.new = function(xs, xo, ys, yo)
	if mockTypeof(xs) == "UDim" then
		return udim2(xs.Scale, xs.Offset, xo.Scale, xo.Offset)
	end
	return udim2(xs, xo, ys, yo)
end
UDim2.fromOffset = function(x, y)
	return udim2(0, x or 0, 0, y or 0)
end
UDim2.fromScale = function(x, y)
	return udim2(x or 0, 0, y or 0, 0)
end

local Color3 = {}
local Color3MT = valueType("Color3", nil)
local function c3(r, g, b)
	for _, channel in { r, g, b } do
		assert(type(channel) == "number" and channel == channel, "Color3 channel must be a number")
	end
	return setmetatable({ R = r, G = g, B = b }, Color3MT)
end
Color3MT.__index = function(self, key)
	if key == "Lerp" then
		return function(a, b, t)
			assert(mockTypeof(b) == "Color3", "Color3:Lerp expects a Color3")
			return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	elseif key == "ToHSV" then
		return function(c)
			local r, g, b = c.R, c.G, c.B
			local max, min = math.max(r, g, b), math.min(r, g, b)
			local h, s, v = 0, 0, max
			local d = max - min
			s = max == 0 and 0 or d / max
			if d ~= 0 then
				if max == r then
					h = (g - b) / d + (g < b and 6 or 0)
				elseif max == g then
					h = (b - r) / d + 2
				else
					h = (r - g) / d + 4
				end
				h /= 6
			end
			return h, s, v
		end
	elseif key == "ToHex" then
		return function(c)
			return string.format("%02X%02X%02X", c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5)
		end
	end
	error(`{key} is not a valid member of Color3`, 2)
end
Color3MT.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
Color3.new = function(r, g, b)
	return c3(r or 0, g or 0, b or 0)
end
Color3.fromRGB = function(r, g, b)
	return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
Color3.fromHSV = function(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i %= 6
	if i == 0 then
		return c3(v, t, p)
	elseif i == 1 then
		return c3(q, v, p)
	elseif i == 2 then
		return c3(p, v, t)
	elseif i == 3 then
		return c3(p, q, v)
	elseif i == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end

local function simpleType(name, fields)
	local mt = valueType(name, nil)
	mt.__index = function(_, key)
		error(`{key} is not a valid member of {name}`, 2)
	end
	return function(...)
		return setmetatable(fields(...), mt)
	end
end

local ColorSequenceKeypoint =
	{ new = simpleType("ColorSequenceKeypoint", function(time, value)
		return { Time = time, Value = value }
	end) }
local NumberSequenceKeypoint =
	{ new = simpleType("NumberSequenceKeypoint", function(time, value)
		return { Time = time, Value = value }
	end) }
local ColorSequence = {
	new = simpleType("ColorSequence", function(a, b)
		if type(a) == "table" and mockTypeof(a) ~= "Color3" then
			return { Keypoints = a }
		end
		return { Keypoints = { a, b or a } }
	end),
}
local NumberSequence = {
	new = simpleType("NumberSequence", function(a, b)
		if type(a) == "table" then
			for _, keypoint in a do
				assert(mockTypeof(keypoint) == "NumberSequenceKeypoint", "NumberSequence.new expects keypoints")
			end
			return { Keypoints = a }
		end
		assert(type(a) == "number", "NumberSequence.new expects numbers or keypoints")
		return { Keypoints = { a, b or a } }
	end),
}
local TweenInfo = {
	new = simpleType("TweenInfo", function(time, style, direction)
		assert(type(time) == "number", "TweenInfo time must be a number")
		return { Time = time, EasingStyle = style, EasingDirection = direction }
	end),
}
local Font = {}
local makeFont = simpleType("Font", function(family, weight, style)
	assert(type(family) == "string", "Font family must be a string")
	return { Family = family, Weight = weight or enumItem("FontWeight", "Regular", 3), Style = style }
end)
Font.new = makeFont
Font.fromEnum = function(item)
	return makeFont("rbxasset://fonts/families/" .. item.Name .. ".json")
end

--------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------

local CLASS_PARENTS = {
	Instance = nil,
	GuiBase2d = "Instance",
	GuiObject = "GuiBase2d",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	GuiButton = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	TextLabel = "GuiObject",
	ImageLabel = "GuiObject",
	TextBox = "GuiObject",
	LayerCollector = "GuiBase2d",
	ScreenGui = "LayerCollector",
	UIComponent = "Instance",
	UIConstraint = "UIComponent",
	UILayout = "UIComponent",
	UIGridStyleLayout = "UILayout",
	UIListLayout = "UIGridStyleLayout",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIScale = "UIComponent",
	UIPadding = "UIComponent",
	UIGradient = "UIComponent",
	UIFlexItem = "UIComponent",
	UISizeConstraint = "UIConstraint",
	Tween = "Instance",
	Folder = "Instance",
	PlayerGui = "Instance",
	Player = "Instance",
	ModuleScript = "Instance",
}

local P = {}
P.Instance = { Name = "string", Parent = "any", ClassName = "readonly" }
P.GuiBase2d = {
	AbsolutePosition = "readonly",
	AbsoluteSize = "readonly",
	AbsoluteRotation = "readonly",
	AutoLocalize = "boolean",
}
P.GuiObject = {
	Active = "boolean",
	AnchorPoint = "Vector2",
	AutomaticSize = "EnumItem",
	BackgroundColor3 = "Color3",
	BackgroundTransparency = "number",
	BorderColor3 = "Color3",
	BorderSizePixel = "number",
	ClipsDescendants = "boolean",
	LayoutOrder = "number",
	Position = "UDim2",
	Rotation = "number",
	Selectable = "boolean",
	Size = "UDim2",
	Visible = "boolean",
	ZIndex = "number",
	Interactable = "boolean",
}
local TEXT_PROPS = {
	Text = "string",
	TextColor3 = "Color3",
	TextSize = "number",
	FontFace = "Font",
	TextXAlignment = "EnumItem",
	TextYAlignment = "EnumItem",
	TextTruncate = "EnumItem",
	TextWrapped = "boolean",
	TextScaled = "boolean",
	TextTransparency = "number",
	RichText = "boolean",
	TextBounds = "readonly",
	LineHeight = "number",
}
P.TextLabel = TEXT_PROPS
P.TextButton = table.clone(TEXT_PROPS)
P.TextBox = table.clone(TEXT_PROPS)
P.GuiButton = { AutoButtonColor = "boolean", Modal = "boolean", Selected = "boolean" }
P.TextBox.ClearTextOnFocus = "boolean"
P.TextBox.PlaceholderText = "string"
P.TextBox.PlaceholderColor3 = "Color3"
P.TextBox.MultiLine = "boolean"
P.TextBox.TextEditable = "boolean"
P.TextBox.CursorPosition = "number"
P.ScrollingFrame = {
	CanvasSize = "UDim2",
	CanvasPosition = "Vector2",
	AutomaticCanvasSize = "EnumItem",
	ScrollingDirection = "EnumItem",
	ScrollBarThickness = "number",
	ScrollBarImageColor3 = "Color3",
	ScrollBarImageTransparency = "number",
	VerticalScrollBarInset = "EnumItem",
	HorizontalScrollBarInset = "EnumItem",
	ElasticBehavior = "EnumItem",
	ScrollingEnabled = "boolean",
	AbsoluteCanvasSize = "readonly",
	AbsoluteWindowSize = "readonly",
}
P.LayerCollector = { Enabled = "boolean", ResetOnSpawn = "boolean", ZIndexBehavior = "EnumItem" }
P.ScreenGui = { DisplayOrder = "number", IgnoreGuiInset = "boolean", ScreenInsets = "EnumItem" }
P.UICorner = { CornerRadius = "UDim" }
P.UIStroke = {
	ApplyStrokeMode = "EnumItem",
	Color = "Color3",
	Thickness = "number",
	Transparency = "number",
	Enabled = "boolean",
}
P.UIScale = { Scale = "number" }
P.UIPadding = { PaddingLeft = "UDim", PaddingRight = "UDim", PaddingTop = "UDim", PaddingBottom = "UDim" }
P.UIGridStyleLayout = {
	FillDirection = "EnumItem",
	SortOrder = "EnumItem",
	HorizontalAlignment = "EnumItem",
	VerticalAlignment = "EnumItem",
	AbsoluteContentSize = "readonly",
}
P.UIListLayout = {
	Padding = "UDim",
	HorizontalFlex = "EnumItem",
	VerticalFlex = "EnumItem",
	ItemLineAlignment = "EnumItem",
	Wraps = "boolean",
}
P.UIGradient = {
	Color = "ColorSequence",
	Transparency = "NumberSequence",
	Rotation = "number",
	Offset = "Vector2",
	Enabled = "boolean",
}
P.UIFlexItem = { FlexMode = "EnumItem", GrowRatio = "number", ShrinkRatio = "number" }
P.UISizeConstraint = { MaxSize = "Vector2", MinSize = "Vector2" }
P.Tween = { PlaybackState = "readonly" }

local function propType(className, prop)
	local class = className
	while class do
		local props = P[class]
		if props and props[prop] then
			return props[prop]
		end
		class = CLASS_PARENTS[class]
	end
	return nil
end

local function isA(className, target)
	local class = className
	while class do
		if class == target then
			return true
		end
		class = CLASS_PARENTS[class]
	end
	return false
end

local DEFAULTS = {
	Name = "",
	Active = false,
	AnchorPoint = Vector2.zero,
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	BorderSizePixel = 1,
	ClipsDescendants = false,
	LayoutOrder = 0,
	Position = UDim2.new(0, 0, 0, 0),
	Rotation = 0,
	Size = UDim2.new(0, 0, 0, 0),
	Visible = true,
	ZIndex = 1,
	Text = "",
	TextSize = 14,
	TextTransparency = 0,
	CanvasPosition = Vector2.zero,
	Enabled = true,
	Scale = 1,
	Transparency = 0,
	Thickness = 1,
	TextEditable = true,
}

local InstanceMT = valueType("Instance", nil)
local liveInstances = setmetatable({}, { __mode = "k" })

local EVENTS = {
	GuiObject = { "MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged" },
	GuiButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" },
	TextBox = { "Focused", "FocusLost" },
	Tween = { "Completed" },
	Instance = { "Changed", "ChildAdded", "ChildRemoved", "Destroying" },
}

local function eventFor(inst, name)
	local class = inst._class
	while class do
		local list = EVENTS[class]
		if list and table.find(list, name) then
			local events = inst._events
			events[name] = events[name] or newSignal(name)
			return events[name]
		end
		class = CLASS_PARENTS[class]
	end
	return nil
end

local focusedBox = nil
local screenSize = v2(1280, 720)

local contentExtent

--- Unscaled pixel extent of an instance along an axis, used for automatic
--- sizing: offsets plus automatic content (scale components are ignored to
--- avoid parent/child cycles).
local function ownExtent(inst, axis)
	local size = inst._props.Size or UDim2.new()
	local offset = size[axis].Offset
	local auto = inst._props.AutomaticSize
	if auto and (auto.Name == axis or auto.Name == "XY") then
		offset = math.max(offset, contentExtent(inst, axis))
	end
	return offset
end

function contentExtent(inst, axis)
	local layout, padding
	for _, child in inst._children do
		if child._class == "UIListLayout" then
			layout = child
		elseif child._class == "UIPadding" then
			padding = child
		end
	end
	local total = 0
	local count = 0
	local listAxis = layout and ((layout._props.FillDirection and layout._props.FillDirection.Name) or "Vertical")
	local alongList = layout
		and ((listAxis == "Vertical" and axis == "Y") or (listAxis == "Horizontal" and axis == "X"))
	for _, child in inst._children do
		if isA(child._class, "GuiObject") and child._props.Visible ~= false then
			local extent = ownExtent(child, axis)
			if alongList then
				total += extent
				count += 1
			elseif layout then
				total = math.max(total, extent)
			else
				local position = child._props.Position or UDim2.new()
				total = math.max(total, position[axis].Offset + extent)
			end
		end
	end
	if alongList and count > 1 and layout._props.Padding then
		total += layout._props.Padding.Offset * (count - 1)
	end
	if padding then
		if axis == "Y" then
			total += (padding._props.PaddingTop and padding._props.PaddingTop.Offset or 0) + (padding._props.PaddingBottom and padding._props.PaddingBottom.Offset or 0)
		else
			total += (padding._props.PaddingLeft and padding._props.PaddingLeft.Offset or 0) + (padding._props.PaddingRight and padding._props.PaddingRight.Offset or 0)
		end
	end
	return total
end

local function absoluteSize(inst)
	if inst._class == "ScreenGui" then
		return screenSize
	end
	local parent = inst._props.Parent
	local parentSize = (parent and parent._props and isA(parent._class, "GuiBase2d")) and absoluteSize(parent)
		or screenSize
	local size = inst._props.Size or UDim2.new()
	local scale = 1
	local uiScale = nil
	for _, child in inst._children do
		if child._class == "UIScale" then
			uiScale = child
		end
	end
	if uiScale then
		scale = uiScale._props.Scale or 1
	end
	local width = parentSize.X * size.X.Scale + size.X.Offset
	local height = parentSize.Y * size.Y.Scale + size.Y.Offset
	local auto = inst._props.AutomaticSize
	if auto and auto.Name ~= "None" then
		if auto.Name == "X" or auto.Name == "XY" then
			width = math.max(width, contentExtent(inst, "X"))
		end
		if auto.Name == "Y" or auto.Name == "XY" then
			height = math.max(height, contentExtent(inst, "Y"))
		end
	end
	return v2(width * scale, height * scale)
end

local function absolutePosition(inst)
	if inst._class == "ScreenGui" then
		return Vector2.zero
	end
	local parent = inst._props.Parent
	if not (parent and parent._props and isA(parent._class, "GuiBase2d")) then
		return Vector2.zero
	end
	local parentPos, parentSize = absolutePosition(parent), absoluteSize(parent)
	local pos = inst._props.Position or UDim2.new()
	return v2(
		parentPos.X + parentSize.X * pos.X.Scale + pos.X.Offset,
		parentPos.Y + parentSize.Y * pos.Y.Scale + pos.Y.Offset
	)
end

local methods = {}

function methods.IsA(self, className)
	return isA(self._class, className)
end
function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(inst)
		for _, child in inst._children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name)
	for _, child in self._children do
		if child._props.Name == name then
			return child
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, className)
	for _, child in self._children do
		if child._class == className then
			return child
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local child = methods.FindFirstChild(self, name)
	assert(child, `WaitForChild("{name}") would hang in the mock`)
	return child
end
function methods.IsDescendantOf(self, ancestor)
	local current = self._props.Parent
	while current do
		if current == ancestor then
			return true
		end
		current = current._props.Parent
	end
	return false
end
function methods.GetPropertyChangedSignal(self, prop)
	if
		prop ~= "AbsoluteSize"
		and prop ~= "AbsolutePosition"
		and prop ~= "AbsoluteCanvasSize"
		and not propType(self._class, prop)
	then
		error(`{prop} is not a valid property of {self._class}`, 2)
	end
	local key = "Changed:" .. prop
	self._events[key] = self._events[key] or newSignal(key)
	return self._events[key]
end
function methods.Destroy(self)
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
	self.Parent = nil
	rawset(self, "_parentLocked", true)
	for _, signal in self._events do
		disconnectAll(signal)
	end
	liveInstances[self] = nil
	if focusedBox == self then
		focusedBox = nil
	end
end
function methods.ClearAllChildren(self)
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
end
-- TextBox
function methods.CaptureFocus(self)
	assert(self._class == "TextBox", "CaptureFocus is only valid on TextBox")
	focusedBox = self
	fire(eventFor(self, "Focused"))
end
function methods.ReleaseFocus(self)
	assert(self._class == "TextBox", "ReleaseFocus is only valid on TextBox")
	if focusedBox == self then
		focusedBox = nil
		fire(eventFor(self, "FocusLost"), false)
	end
end
function methods.IsFocused(self)
	return focusedBox == self
end
-- Tween
function methods.Play(self)
	assert(self._class == "Tween", "Play is only valid on Tween")
	local target, goals = self._target, self._goals
	self._playing = true
	taskLib.defer(function()
		if not self._playing then
			return
		end
		self._playing = false
		if not target._destroyed then
			for key, value in goals do
				target[key] = value
			end
		end
		fire(eventFor(self, "Completed"), enumItem("PlaybackState", "Completed", 4))
	end)
end
function methods.Cancel(self)
	assert(self._class == "Tween", "Cancel is only valid on Tween")
	if self._playing then
		self._playing = false
		fire(eventFor(self, "Completed"), enumItem("PlaybackState", "Cancelled", 5))
	end
end

local VALID_METHODS = {
	Instance = {
		"IsA",
		"GetChildren",
		"GetDescendants",
		"FindFirstChild",
		"FindFirstChildOfClass",
		"WaitForChild",
		"IsDescendantOf",
		"GetPropertyChangedSignal",
		"Destroy",
		"ClearAllChildren",
	},
	TextBox = { "CaptureFocus", "ReleaseFocus", "IsFocused" },
	Tween = { "Play", "Cancel" },
}

local function hasMethod(className, name)
	local class = className
	while class do
		local list = VALID_METHODS[class]
		if list and table.find(list, name) then
			return true
		end
		class = CLASS_PARENTS[class]
	end
	return false
end

local function setParent(self, parent)
	if rawget(self, "_parentLocked") then
		error(`The Parent property of {self._props.Name} is locked`, 3)
	end
	local old = self._props.Parent
	if old == parent then
		return
	end
	if parent ~= nil and parent._destroyed then
		error("Cannot parent to a destroyed instance", 3)
	end
	if old then
		local index = table.find(old._children, self)
		if index then
			table.remove(old._children, index)
		end
	end
	self._props.Parent = parent
	if parent then
		table.insert(parent._children, self)
	end
end

InstanceMT.__index = function(self, key)
	if type(key) == "string" and string.sub(key, 1, 1) == "_" then
		return nil
	end
	if key == "Parent" then
		return self._props.Parent
	elseif key == "ClassName" then
		return self._class
	elseif key == "AbsoluteSize" and isA(self._class, "GuiBase2d") then
		return absoluteSize(self)
	elseif key == "AbsolutePosition" and isA(self._class, "GuiBase2d") then
		return absolutePosition(self)
	elseif key == "AbsoluteCanvasSize" and self._class == "ScrollingFrame" then
		return absoluteSize(self)
	elseif key == "AbsoluteWindowSize" and self._class == "ScrollingFrame" then
		return absoluteSize(self)
	elseif key == "TextBounds" and propType(self._class, "TextBounds") then
		return v2(#(self._props.Text or "") * 7, self._props.TextSize or 14)
	elseif key == "AbsoluteContentSize" and self._class == "UIListLayout" then
		return v2(0, 0)
	end
	if methods[key] and hasMethod(self._class, key) then
		return methods[key]
	end
	local event = eventFor(self, key)
	if event then
		return event
	end
	local kind = propType(self._class, key)
	if kind then
		local value = self._props[key]
		if value == nil then
			value = DEFAULTS[key]
		end
		return value
	end
	for _, child in self._children do
		if child._props.Name == key then
			return child
		end
	end
	error(`{key} is not a valid member of {self._class} "{self._props.Name}"`, 2)
end

InstanceMT.__newindex = function(self, key, value)
	if type(key) == "string" and string.sub(key, 1, 1) == "_" then
		rawset(self, key, value)
		return
	end
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local kind = propType(self._class, key)
	if not kind then
		error(`{key} is not a valid member of {self._class} "{self._props.Name}"`, 2)
	end
	if kind == "readonly" then
		error(`Unable to assign property {key}. Property is read only`, 2)
	end
	if kind ~= "any" then
		local actual = mockTypeof(value)
		if kind == "number" and type(value) ~= "number" then
			error(`Invalid value for {self._class}.{key}: expected number, got {actual}`, 2)
		elseif kind ~= "number" and actual ~= kind then
			error(`Invalid value for {self._class}.{key}: expected {kind}, got {actual}`, 2)
		end
		if kind == "number" and value ~= value then
			error(`NaN assigned to {self._class}.{key}`, 2)
		end
	end
	local old = self._props[key]
	self._props[key] = value
	if old ~= value then
		local signal = self._events["Changed:" .. key]
		if signal then
			fire(signal)
		end
		if key == "Text" and self._class == "TextBox" then
			-- property signal already fired above
		end
	end
end

InstanceMT.__tostring = function(self)
	return self._props.Name
end

local instanceCount = 0

local function newInstance(className)
	if not CLASS_PARENTS[className] and className ~= "Instance" then
		error(`Unable to create an Instance of type "{className}" (mock)`, 2)
	end
	instanceCount += 1
	local inst = setmetatable({
		_class = className,
		_props = { Name = className },
		_children = {},
		_events = {},
	}, InstanceMT)
	liveInstances[inst] = true
	return inst
end

Mock.Instance = {
	new = function(className, parent)
		local inst = newInstance(className)
		if parent then
			inst.Parent = parent
		end
		return inst
	end,
}

function Mock.liveInstanceCount()
	local count = 0
	for inst in liveInstances do
		if not inst._destroyed then
			count += 1
		end
	end
	return count
end

--------------------------------------------------------------------------
-- Services
--------------------------------------------------------------------------

local function service(name, members)
	local svc = setmetatable({}, {
		[TYPE_KEY] = "Instance",
		__index = function(_, key)
			local member = members[key]
			if member == nil then
				error(`{key} is not a valid member of {name}`, 2)
			end
			return member
		end,
		__newindex = function(_, key, value)
			if members[key] == nil then
				error(`{key} is not a valid member of {name}`, 2)
			end
			members[key] = value
		end,
	})
	return svc
end

local function Vector3Like(v)
	return { X = v.X, Y = v.Y, Z = 0 }
end

-- InputObject
local InputObjectMT = valueType("InputObject", nil)
InputObjectMT.__index = function(_, key)
	error(`{key} is not a valid member of InputObject`, 2)
end
function Mock.input(inputType, keyCode, position)
	return setmetatable({
		UserInputType = Enum.UserInputType[inputType],
		KeyCode = Enum.KeyCode[keyCode or "Unknown"],
		UserInputState = Enum.UserInputState.Begin,
		Position = position and Vector3Like(position) or { X = 0, Y = 0, Z = 0 },
		Delta = { X = 0, Y = 0, Z = 0 },
	}, InputObjectMT)
end

local mouseLocation = v2(0, 0)
local keysDown = {}

local UIS = {
	InputBegan = newSignal("InputBegan"),
	InputChanged = newSignal("InputChanged"),
	InputEnded = newSignal("InputEnded"),
	TouchEnabled = false,
	MouseEnabled = true,
	KeyboardEnabled = true,
	GetMouseLocation = function()
		return mouseLocation
	end,
	IsKeyDown = function(_, keyCode)
		return keysDown[keyCode.Name] == true
	end,
	GetFocusedTextBox = function()
		return focusedBox
	end,
}

local boundActions = {}
local CAS = {
	BindActionAtPriority = function(_, name, fn, createButton, priority, ...)
		assert(
			type(name) == "string" and type(fn) == "function" and type(createButton) == "boolean",
			"BindActionAtPriority args"
		)
		assert(type(priority) == "number", "priority must be a number")
		assert(select("#", ...) > 0, "BindActionAtPriority needs at least one input")
		boundActions[name] = fn
	end,
	UnbindAction = function(_, name)
		boundActions[name] = nil
	end,
}

local GuiService = {
	MenuOpened = newSignal("MenuOpened"),
	GetGuiInset = function()
		return v2(0, 58), v2(0, 0)
	end,
}

local TweenService = {
	Create = function(_, target, info, goals)
		assert(mockTypeof(info) == "TweenInfo", "TweenService:Create expects TweenInfo")
		for key, value in goals do
			-- Validate the goal properties exist and are tweenable types.
			local kind = propType(target._class, key)
			assert(kind and kind ~= "readonly", `Cannot tween {target._class}.{key}`)
			local t = mockTypeof(value)
			assert(
				t == "number" or t == "Color3" or t == "UDim2" or t == "Vector2" or t == "UDim",
				`Cannot tween type {t}`
			)
		end
		local tween = newInstance("Tween")
		rawset(tween, "_target", target)
		rawset(tween, "_goals", goals)
		return tween
	end,
}

local function jsonEncode(value)
	local kind = type(value)
	if kind == "nil" then
		return "null"
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("JSONEncode: invalid number")
		end
		return string.format("%.14g", value)
	elseif kind == "string" then
		return '"' .. value:gsub('[%c"\\]', function(c)
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif kind == "table" then
		if mockTypeof(value) ~= "table" then
			error(`JSONEncode: cannot encode {mockTypeof(value)}`)
		end
		if #value > 0 or next(value) == nil then
			local parts = {}
			for _, item in value do
				table.insert(parts, jsonEncode(item))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for key, item in value do
			assert(type(key) == "string", "JSONEncode: mixed keys")
			table.insert(parts, jsonEncode(key) .. ":" .. jsonEncode(item))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("JSONEncode: cannot encode " .. kind)
end

local function jsonDecode(text)
	local pos = 1
	local function ws()
		pos = string.find(text, "[^%s]", pos) or #text + 1
	end
	local parse
	function parse()
		ws()
		local c = string.sub(text, pos, pos)
		if c == "{" then
			pos += 1
			local out = {}
			ws()
			if string.sub(text, pos, pos) == "}" then
				pos += 1
				return out
			end
			while true do
				local key = parse()
				ws()
				assert(string.sub(text, pos, pos) == ":", "expected :")
				pos += 1
				out[key] = parse()
				ws()
				local d = string.sub(text, pos, pos)
				pos += 1
				if d == "}" then
					return out
				end
				assert(d == ",", "expected ,")
			end
		elseif c == "[" then
			pos += 1
			local out = {}
			ws()
			if string.sub(text, pos, pos) == "]" then
				pos += 1
				return out
			end
			while true do
				table.insert(out, parse())
				ws()
				local d = string.sub(text, pos, pos)
				pos += 1
				if d == "]" then
					return out
				end
				assert(d == ",", "expected ,")
			end
		elseif c == '"' then
			local finish = pos + 1
			local out = {}
			while true do
				local ch = string.sub(text, finish, finish)
				if ch == '"' then
					break
				elseif ch == "\\" then
					local esc = string.sub(text, finish + 1, finish + 1)
					if esc == "u" then
						table.insert(out, utf8.char(tonumber(string.sub(text, finish + 2, finish + 5), 16)))
						finish += 6
					else
						table.insert(out, ({ n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" })[esc] or esc)
						finish += 2
					end
				else
					table.insert(out, ch)
					finish += 1
				end
			end
			pos = finish + 1
			return table.concat(out)
		elseif string.sub(text, pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif string.sub(text, pos, pos + 4) == "false" then
			pos += 5
			return false
		elseif string.sub(text, pos, pos + 3) == "null" then
			pos += 4
			return nil
		end
		local numberText = string.match(text, "^-?[%d%.eE%+%-]+", pos)
		assert(numberText, "invalid JSON at " .. pos)
		pos += #numberText
		return tonumber(numberText)
	end
	return parse()
end

local HttpService = {
	JSONEncode = function(_, value)
		return jsonEncode(value)
	end,
	JSONDecode = function(_, text)
		return jsonDecode(text)
	end,
}

local playerGui = newInstance("PlayerGui")
playerGui.Name = "PlayerGui"
local player = newInstance("Player")
player.Name = "LocalPlayer"
playerGui.Parent = player

local Players = { LocalPlayer = player }
local RunService = {
	IsClient = function()
		return true
	end,
	IsStudio = function()
		return true
	end,
	Heartbeat = newSignal("Heartbeat"),
	RenderStepped = newSignal("RenderStepped"),
}

local camera = { ViewportSize = screenSize }
local workspaceMock = service("Workspace", {
	CurrentCamera = camera,
	GetRealPhysicsFPS = function()
		return 60
	end,
})

local services = {
	UserInputService = service("UserInputService", UIS),
	ContextActionService = service("ContextActionService", CAS),
	GuiService = service("GuiService", GuiService),
	TweenService = service("TweenService", TweenService),
	HttpService = service("HttpService", HttpService),
	Players = service("Players", Players),
	RunService = service("RunService", RunService),
	Workspace = workspaceMock,
	ReplicatedStorage = service("ReplicatedStorage", {}),
}

local game = service("DataModel", {
	GetService = function(_, name)
		local svc = services[name]
		assert(svc, `Service {name} is not mocked`)
		return svc
	end,
})

Mock.UIS = UIS
Mock.CAS = boundActions
Mock.PlayerGui = playerGui
Mock.services = services

--------------------------------------------------------------------------
-- Input simulation helpers
--------------------------------------------------------------------------

function Mock.setMouse(x, y)
	mouseLocation = v2(x, y)
end

--- Simulates a key press (and release) through UserInputService.
function Mock.pressKey(keyName, hold)
	local input = Mock.input("Keyboard", keyName)
	keysDown[keyName] = true
	for _, fn in boundActions do
		fn("action", Enum.UserInputState.Begin, input)
	end
	fire(UIS.InputBegan, input, false)
	if not hold then
		keysDown[keyName] = nil
		fire(UIS.InputEnded, input, false)
	end
	Mock.flush()
	return input
end

function Mock.releaseKey(keyName)
	keysDown[keyName] = nil
	fire(UIS.InputEnded, Mock.input("Keyboard", keyName), false)
	Mock.flush()
end

--- Clicks a GuiButton: fires InputBegan/Activated/InputEnded on it.
function Mock.click(guiObject)
	local input = Mock.input("MouseButton1")
	local position = guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
	mouseLocation = position
	fire(UIS.InputBegan, input, true)
	fire(eventFor(guiObject, "InputBegan"), input)
	local activated = eventFor(guiObject, "Activated")
	if activated then
		fire(activated, input, 1)
	end
	fire(eventFor(guiObject, "InputEnded"), input)
	fire(UIS.InputEnded, input, true)
	Mock.flush()
end

function Mock.rightClick(guiObject)
	local input = Mock.input("MouseButton2")
	mouseLocation = guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
	fire(UIS.InputBegan, input, true)
	fire(eventFor(guiObject, "InputBegan"), input)
	fire(UIS.InputEnded, input, true)
	Mock.flush()
end

--- Drags from the center of `guiObject` to `to` (screen position).
function Mock.drag(guiObject, to)
	local input = Mock.input("MouseButton1")
	local from = guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
	mouseLocation = from
	fire(UIS.InputBegan, input, true)
	fire(eventFor(guiObject, "InputBegan"), input)
	mouseLocation = to
	fire(UIS.InputChanged, Mock.input("MouseMovement"), true)
	fire(eventFor(guiObject, "InputEnded"), input)
	fire(UIS.InputEnded, input, true)
	Mock.flush()
end

function Mock.hover(guiObject, inside)
	fire(eventFor(guiObject, inside == false and "MouseLeave" or "MouseEnter"))
	Mock.flush()
end

function Mock.type(textBox, text)
	textBox:CaptureFocus()
	textBox.Text = text
	textBox:ReleaseFocus()
	Mock.flush()
end

--------------------------------------------------------------------------
-- Module loading
--------------------------------------------------------------------------

local host -- { readfile, loadchunk, listdir }

local function environment(scriptObject)
	local env = setmetatable({
		script = scriptObject,
		game = game,
		workspace = workspaceMock,
		Instance = Mock.Instance,
		Enum = Enum,
		Vector2 = Vector2,
		UDim = UDim,
		UDim2 = UDim2,
		Color3 = Color3,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		TweenInfo = TweenInfo,
		Font = Font,
		typeof = mockTypeof,
		task = taskLib,
		warn = function(...)
			Mock.warnings = Mock.warnings or {}
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			table.insert(Mock.warnings, table.concat(parts, " "))
			if Mock.printWarnings then
				print("WARN:", ...)
			end
		end,
		require = nil,
	}, { __index = _G })
	env.require = function(target)
		return Mock.require(target)
	end
	return env
end

local moduleCache = {}

function Mock.require(moduleScript)
	assert(type(moduleScript) == "table" and moduleScript._class == "ModuleScript", "require expects a ModuleScript")
	local cached = moduleCache[moduleScript]
	if cached then
		assert(cached.done, "Recursive require of " .. moduleScript._path)
		return cached.value
	end
	local entry = { done = false }
	moduleCache[moduleScript] = entry
	local source = host.readfile(moduleScript._path)
	assert(source, "cannot read " .. moduleScript._path)
	local fn, err = host.loadchunk(source, moduleScript._path, environment(moduleScript))
	assert(fn, err)
	local results = table.pack(fn())
	assert(results.n == 1, `Module {moduleScript._path} did not return exactly one value`)
	entry.value = results[1]
	entry.done = true
	return entry.value
end

--- Builds a ModuleScript tree for a Rojo-style folder: `init.luau` becomes
--- the folder's ModuleScript; other `.luau` files become child modules.
function Mock.mount(path, name, parent)
	local node
	local files = host.listdir(path)
	local hasInit = table.find(files, "init.luau") ~= nil
	if hasInit then
		node = newInstance("ModuleScript")
		rawset(node, "_path", path .. "/init.luau")
	else
		node = newInstance("Folder")
	end
	node.Name = name
	for _, file in files do
		local full = path .. "/" .. file
		if file ~= "init.luau" then
			if string.sub(file, -5) == ".luau" then
				local child = newInstance("ModuleScript")
				rawset(child, "_path", full)
				child.Name = string.sub(file, 1, -6)
				child.Parent = node
			elseif not string.find(file, "%.") then
				Mock.mount(full, file, node)
			end
		end
	end
	node.Parent = parent
	return node
end

function Mock.environment(scriptObject)
	return environment(scriptObject)
end

function Mock.setHost(h)
	host = h
end

function Mock.resetCounters()
	Mock.warnings = {}
end

Mock.Enum = Enum
Mock.Vector2 = Vector2
Mock.Color3 = Color3
Mock.UDim2 = UDim2
Mock.typeof = mockTypeof

-- Allow the ModuleScript class to be recognised.
P.ModuleScript = {}
P.Folder = {}
P.PlayerGui = {}
P.Player = {}

return Mock
