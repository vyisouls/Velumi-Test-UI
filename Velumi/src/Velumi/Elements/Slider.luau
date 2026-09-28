--[[
	Slider
	A framed slider with a grab and the value printed in the frame.
	Drag to change the value, or Ctrl+Click (double-click / double-tap on
	touch) to type an exact value.

	    group:AddSlider({
	        Name = "Volume",
	        Min = 0,
	        Max = 100,
	        Default = 50,
	        Step = 1,
	        Callback = function(value) end,
	    })

	Options
	  Min, Max, Default     numbers (Default defaults to Min)
	  Step                  snapping increment (default 1; 0 disables snapping)
	  Decimals              displayed decimals (default derived from Step)
	  Prefix, Suffix        text around the displayed value ("%", " studs")
	  Format(value)         custom display function, overrides the above
	  Name, Callback, Flag, Save, Bind, Tooltip, Disabled, ContextMenu
	Value: number.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Input = require(script.Parent.Parent.Core.Input)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Slider = Element.extend("Slider")
Slider.Saveable = true
Slider.Fill = true

local GRAB_WIDTH = 10
local GRAB_MARGIN = 2

function Slider:_build()
	local options = self.Options

	self._min = tonumber(options.Min) or 0
	self._max = tonumber(options.Max) or 100
	if self._max < self._min then
		self._min, self._max = self._max, self._min
	end
	self._step = tonumber(options.Step) or 1
	self._decimals = tonumber(options.Decimals) or Utility.DecimalsOf(self._step > 0 and self._step or nil)
	self._dragging = false
	self._editing = false

	if self.Default == nil then
		self.Default = self._min
	end

	local labeled = self:_labeled()

	local frame = Layout.FrameBox(labeled.Widget, function(t)
		if self._disabled then
			return t.Frame
		elseif self._dragging then
			return t.FrameActive
		elseif self._hovered then
			return t.FrameHover
		end
		return t.Frame
	end)
	table.insert(self._styled, frame)

	local grab = Create("Frame", {
		Name = "Grab",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, GRAB_WIDTH, 1, -GRAB_MARGIN * 2),
		Parent = frame,
	})
	Layout.Corner(grab)
	self:_bind(grab, {
		BackgroundColor3 = function(t)
			if self._disabled then
				return t.DisabledText
			end
			return self._dragging and t.SliderGrabActive or t.SliderGrab
		end,
	})

	local valueLabel = Layout.Text(frame, {
		Name = "Value",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	}, function(t)
		return self._disabled and t.DisabledText or t.Text
	end)
	table.insert(self._styled, valueLabel)

	local hitbox = Create("TextButton", {
		Name = "Hitbox",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = frame,
	})

	local editor = Create("TextBox", {
		Name = "Editor",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 4,
		Parent = frame,
	})
	Theme.Bind(editor, {
		TextColor3 = "Text",
		FontFace = "Font",
		TextSize = "TextSize",
		BackgroundColor3 = "FrameActive",
	})

	self._frame = frame
	self._grab = grab
	self._valueLabel = valueLabel
	self._editor = editor
	self.Root = labeled.Root

	self:_track(hitbox)

	local lastPress = 0
	self._maid:Give(hitbox.InputBegan:Connect(function(input)
		if self._disabled or not Input.IsPointerDown(input) then
			return
		end
		local now = os.clock()
		local doubleTap = now - lastPress < 0.3
		lastPress = now
		if Input.IsCtrlDown() or doubleTap then
			self:_beginEdit()
			return
		end
		self._dragging = true
		self:_restyle(true)
		self:_setFromPointer(Input.GetPointerPosition(input))
		Input.BeginDrag(input, {
			OnMove = function(position)
				self:_setFromPointer(position)
			end,
			OnEnd = function()
				self._dragging = false
				self:_restyle(true)
			end,
		})
	end))

	self._maid:Give(editor.FocusLost:Connect(function()
		self:_endEdit()
	end))
end

function Slider:_setFromPointer(position: Vector2)
	local frame = self._frame
	local absPosition, absSize = frame.AbsolutePosition, frame.AbsoluteSize
	local grabWidth = self._grab.AbsoluteSize.X
	local scale = grabWidth / GRAB_WIDTH
	local margin = GRAB_MARGIN * (scale == scale and scale or 1)
	local usable = absSize.X - margin * 2 - grabWidth
	if usable <= 0 then
		return
	end
	local alpha = math.clamp((position.X - absPosition.X - margin - grabWidth / 2) / usable, 0, 1)
	self:SetValue(self._min + (self._max - self._min) * alpha)
end

function Slider:_beginEdit()
	self._editing = true
	self._editor.Text = Utility.FormatNumber(self.Value, self._decimals)
	self._editor.Visible = true
	self._valueLabel.Visible = false
	self._editor:CaptureFocus()
end

function Slider:_endEdit()
	if not self._editing then
		return
	end
	self._editing = false
	local number = tonumber((string.gsub(self._editor.Text, "[^%d%.%-eE]", "")))
	self._editor.Visible = false
	self._valueLabel.Visible = true
	if number then
		self:SetValue(number)
	end
end

function Slider:_format(value: number): string
	local options = self.Options
	if type(options.Format) == "function" then
		local ok, text = pcall(options.Format, value)
		if ok and text ~= nil then
			return tostring(text)
		end
	end
	return (options.Prefix or "") .. Utility.FormatNumber(value, self._decimals) .. (options.Suffix or "")
end

function Slider:_apply(value: any): boolean
	local number = tonumber(value) or self._min
	number = Utility.Clamp(number, self._min, self._max)
	if self._step > 0 then
		number = Utility.Snap(number, self._step, self._min)
		number = Utility.Clamp(number, self._min, self._max)
	end

	local changed = self.Value ~= number
	self.Value = number

	local range = self._max - self._min
	local alpha = range > 0 and (number - self._min) / range or 0
	local travel = GRAB_WIDTH + GRAB_MARGIN * 2
	self._grab.Position = UDim2.new(alpha, GRAB_MARGIN - alpha * travel, 0.5, 0)
	self._valueLabel.Text = self:_format(number)
	return changed
end

function Slider:_deserialize(data: any)
	if type(data) == "number" then
		self:SetValue(data)
	end
end

function Slider:_onDisabledChanged(disabled: boolean)
	if disabled then
		self._dragging = false
		if self._editing then
			self._editor:ReleaseFocus()
		end
	end
end

function Slider:SetMin(min: number)
	self:SetRange(min, self._max)
end

function Slider:SetMax(max: number)
	self:SetRange(self._min, max)
end

--- Sets both bounds, re-clamping the current value.
function Slider:SetRange(min: number, max: number)
	self._min, self._max = math.min(min, max), math.max(min, max)
	local before = self.Value
	self:_apply(before)
	if self.Value ~= before then
		self:_emit()
	end
end

function Slider:SetStep(step: number)
	self._step = step
	self._decimals = tonumber(self.Options.Decimals) or Utility.DecimalsOf(step > 0 and step or nil)
	self:_apply(self.Value)
end

function Slider:GetRange(): (number, number)
	return self._min, self._max
end

return Slider
