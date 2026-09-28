--[[
	Notification
	Compact toast notifications stacked in the bottom-right corner.

	    Velumi:Notify({
	        Title = "Saved",
	        Description = "Configuration saved successfully.",
	        Type = "Success",     -- "Info" | "Success" | "Warning" | "Error"
	        Duration = 3,         -- seconds; 0 keeps it until closed
	    })

	Returns a handle: `Close()`, `SetTitle(text)`, `SetDescription(text)`,
	`Closed` (Signal). Clicking a notification dismisses it.
]]

local Animation = require(script.Parent.Parent.Core.Animation)
local Context = require(script.Parent.Parent.Core.Context)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Notification = {}
Notification.__index = Notification

Notification.Width = 290
Notification.MaxVisible = 5
Notification.DefaultDuration = 4

local TYPE_KEYS = {
	Info = "Info",
	Success = "Success",
	Warning = "Warning",
	Error = "Error",
}

local active: { any } = {}
local stack: Frame? = nil
local stackScale: UIScale? = nil

local function ensureStack(): Frame
	if stack and stack.Parent then
		return stack
	end
	local metrics = Layout.Metrics
	local frame = Create("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, Notification.Width, 1, -24),
	})
	Layout.List(frame, Enum.FillDirection.Vertical, metrics.WindowPadding - 2, {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})
	stackScale = Create("UIScale", { Parent = frame })
	frame.Parent = Context.GetLayer("Notifications")
	stack = frame
	return frame
end

local order = 0

function Notification.new(options: { [string]: any })
	options = options or {}
	local generation = Context.Retain()

	local self = setmetatable({}, Notification)
	self._generation = generation
	local kind = TYPE_KEYS[options.Type or "Info"] or "Info"
	local duration = tonumber(options.Duration) or Notification.DefaultDuration

	self.Closed = Signal.new()
	self.Type = kind
	self._maid = Maid.new()
	self._closing = false

	local container = ensureStack()
	if stackScale then
		stackScale.Scale = Context.GlobalScale
	end
	order += 1

	-- The slot keeps the stack layout stable while the card slides.
	local slot = Create("Frame", {
		Name = "Notification",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})

	local card = Create("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(Notification.Width + 24, 0),
		Parent = slot,
	})
	Theme.Bind(card, { BackgroundColor3 = "Popup" })
	Layout.Corner(card)
	Layout.Stroke(card, "Border")

	local strip = Create("Frame", {
		Name = "Strip",
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, 0),
		Parent = card,
	})
	Theme.Bind(strip, { BackgroundColor3 = kind })

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	Layout.Padding(body, 12, 10, 7, 9)
	Layout.List(body, Enum.FillDirection.Vertical, 2)

	local title = Layout.Text(body, {
		Name = "Title",
		Text = options.Title or kind,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 1,
	})
	Theme.Bind(title, { FontFace = "FontBold" })

	local description = Layout.Text(body, {
		Name = "Description",
		Text = options.Description or options.Text or "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Visible = (options.Description or options.Text or "") ~= "",
	}, "SecondaryText")

	local timer = Create("Frame", {
		Name = "Timer",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, 0),
		Size = UDim2.new(1, -2, 0, 1),
		Parent = card,
	})
	Theme.Bind(timer, { BackgroundColor3 = kind, BackgroundTransparency = 0.3 })

	self.Root = slot
	self._card = card
	self._title = title
	self._description = description
	self._maid:Give(slot)

	self._maid:Give(card.Activated:Connect(function()
		self:Close()
	end))

	slot.Parent = container
	table.insert(active, self)

	-- Keep the stack bounded.
	while #active > Notification.MaxVisible do
		active[1]:Close()
	end

	Animation.Tween(card, { Position = UDim2.fromOffset(0, 0) }, Animation.Durations.Slow)

	if duration > 0 and duration < math.huge then
		timer.Size = UDim2.new(1, -2, 0, 1)
		Animation.Tween(timer, { Size = UDim2.new(0, 0, 0, 1) }, duration, Enum.EasingStyle.Linear)
		self._maid:Give(task.delay(duration, function()
			self:Close()
		end))
	else
		timer.Visible = false
	end

	return self
end

function Notification:SetTitle(text: string)
	self._title.Text = text
end

function Notification:SetDescription(text: string)
	self._description.Text = text
	self._description.Visible = text ~= ""
end

function Notification:Close()
	if self._closing then
		return
	end
	self._closing = true

	local index = table.find(active, self)
	if index then
		table.remove(active, index)
	end

	local slot, card = self.Root, self._card
	local function finish()
		Animation.CancelTree(slot)
		Theme.UnbindTree(slot)
		self._maid:Clean()
		self.Closed:Fire()
		self.Closed:Destroy()
		Context.Release(self._generation)
	end

	if not slot.Parent or not Animation.Enabled then
		finish()
		return
	end

	Animation.Tween(card, { Position = UDim2.fromOffset(Notification.Width + 24, 0) }, Animation.Durations.Normal)
	task.delay(Animation.Durations.Normal, function()
		if not slot.Parent then
			finish()
			return
		end
		-- Collapse the slot so the rest of the stack slides down smoothly.
		local scale = stackScale and stackScale.Scale or 1
		local height = slot.AbsoluteSize.Y / math.max(scale, 0.01)
		slot.AutomaticSize = Enum.AutomaticSize.None
		slot.Size = UDim2.new(1, 0, 0, height)
		card.Visible = false
		Animation.Tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, Animation.Durations.Normal)
		task.delay(Animation.Durations.Normal, finish)
	end)
end

--- Closes every visible notification.
function Notification.CloseAll()
	for _, notification in table.clone(active) do
		notification:Close()
	end
end

return Notification
