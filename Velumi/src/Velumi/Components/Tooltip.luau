--[[
	Tooltip
	A single, shared tooltip that appears after a short hover delay and
	follows the pointer. Elements opt in with the `Tooltip = "..."` option;
	anything else can use `Tooltip.Attach(guiObject, "text" | () -> string?, maid)`.

	Only one tooltip instance exists, and it only listens to pointer
	movement while it is visible.
]]

local Animation = require(script.Parent.Parent.Core.Animation)
local Context = require(script.Parent.Parent.Core.Context)
local Input = require(script.Parent.Parent.Core.Input)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Tooltip = {}

Tooltip.Delay = 0.45
Tooltip.MaxWidth = 280
Tooltip.Offset = Vector2.new(14, 14)

local frame: Frame? = nil
local label: TextLabel? = nil
local scaler: UIScale? = nil
local owner: GuiObject? = nil
local token: any = nil
local unsubscribe: (() -> ())? = nil

local function ensureFrame(): Frame?
	if frame and frame.Parent then
		return frame
	end
	if not Context.IsAlive() then
		return nil
	end

	local newFrame = Create("Frame", {
		Name = "Tooltip",
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Visible = false,
	})
	Theme.Bind(newFrame, { BackgroundColor3 = "Tooltip" })
	Layout.Corner(newFrame)
	Layout.Stroke(newFrame, "Border")
	Layout.Padding(newFrame, 7, 7, 4, 4)
	scaler = Create("UIScale", { Parent = newFrame })

	label = Layout.Text(newFrame, {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	Create("UISizeConstraint", {
		MaxSize = Vector2.new(Tooltip.MaxWidth, math.huge),
		Parent = label,
	})

	newFrame.Parent = Context.GetLayer("Tooltip")
	frame = newFrame
	return newFrame
end

local function place(position: Vector2)
	if not frame then
		return
	end
	local viewport = Context.GetViewportSize()
	local size = frame.AbsoluteSize
	local x = position.X + Tooltip.Offset.X
	local y = position.Y + Tooltip.Offset.Y
	if x + size.X > viewport.X then
		x = position.X - size.X - 4
	end
	if y + size.Y > viewport.Y then
		y = position.Y - size.Y - 4
	end
	frame.Position = UDim2.fromOffset(math.max(0, x), math.max(0, y))
end

--- Shows `text` at the pointer immediately.
function Tooltip.Show(text: string, position: Vector2?)
	local target = ensureFrame()
	if not target or not label then
		return
	end
	label.Text = text
	if scaler then
		scaler.Scale = Context.GlobalScale
	end
	target.Visible = true
	place(position or Input.GetPointerPosition())

	target.BackgroundTransparency = 1
	label.TextTransparency = 1
	Animation.Tween(target, { BackgroundTransparency = 0 }, Animation.Durations.Fast)
	Animation.Tween(label, { TextTransparency = 0 }, Animation.Durations.Fast)

	if not unsubscribe then
		unsubscribe = Input.Subscribe("Changed", function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				place(Input.GetPointerPosition(input))
			end
		end)
	end
end

--- Hides the tooltip and cancels any pending one.
function Tooltip.Hide()
	token = nil
	owner = nil
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	if frame and frame.Parent then
		Animation.Cancel(frame)
		frame.Visible = false
	end
end

--- Starts the hover delay for `guiObject`.
function Tooltip.Schedule(guiObject: GuiObject, getText: () -> string?)
	Tooltip.Hide()
	owner = guiObject
	local myToken = {}
	token = myToken
	task.delay(Tooltip.Delay, function()
		if token ~= myToken or owner ~= guiObject then
			return
		end
		if not Utility.IsVisibleOnScreen(guiObject) or Input.IsDragging() then
			return
		end
		local text = getText()
		if type(text) == "string" and text ~= "" then
			Tooltip.Show(text)
		end
	end)
end

--- Hides the tooltip if it belongs to `guiObject`.
function Tooltip.Cancel(guiObject: GuiObject)
	if owner == guiObject then
		Tooltip.Hide()
	end
end

--- Attaches a hover tooltip to a GuiObject. `text` may be a string or a
--- function returning the current text. Connections are given to `maid`.
function Tooltip.Attach(guiObject: GuiObject, text: string | () -> string?, maid: any)
	local getText = if type(text) == "function"
		then text
		else function()
			return text :: string
		end
	maid:Give(guiObject.MouseEnter:Connect(function()
		Tooltip.Schedule(guiObject, getText)
	end))
	maid:Give(guiObject.MouseLeave:Connect(function()
		Tooltip.Cancel(guiObject)
	end))
	maid:Give(guiObject.InputBegan:Connect(function(input)
		if Input.IsPointerDown(input) then
			Tooltip.Cancel(guiObject)
		end
	end))
	maid:Give(function()
		Tooltip.Cancel(guiObject)
	end)
end

return Tooltip
