--[[
	Input
	A single-line text field.

	    group:AddInput({
	        Name = "Username",
	        Placeholder = "Enter a name...",
	        MaxLength = 20,
	        Validate = function(text)
	            return #text >= 3, "At least 3 characters"
	        end,
	        Callback = function(text) end,
	    })

	    group:AddInput({ Name = "Seed", Numeric = true, Min = 0, Max = 99999, Default = 42 })

	Options
	  Default        initial text (or number when Numeric)
	  Placeholder    hint shown while empty
	  Numeric        only accept numbers; Value becomes a number
	  Min, Max       numeric bounds (Numeric only)
	  MaxLength      maximum characters
	  Validate(text) return false (plus an optional message) to reject input
	  Finished       true (default): commit on Enter / focus lost;
	                 false: commit on every keystroke
	  ClearOnFocus   clear the text when the field gains focus
	  Name, Callback, Flag, Save, Bind, Tooltip, Disabled, ContextMenu
	Value: string (or number when Numeric).
	Signal: `input.Invalid` fires (text, message) when input is rejected.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local InputElement = Element.extend("Input")
InputElement.Saveable = true
InputElement.Fill = true

function InputElement:_build()
	local options = self.Options
	local metrics = Layout.Metrics

	self._numeric = options.Numeric == true
	self._maxLength = tonumber(options.MaxLength)
	self._finished = options.Finished ~= false
	self._focused = false
	self._invalid = false
	self.Invalid = Signal.new()
	self._maid:Give(self.Invalid)

	if self.Default == nil then
		self.Default = self._numeric and (tonumber(options.Min) or 0) or ""
	end

	local labeled = self:_labeled()

	local frame = Layout.FrameBox(labeled.Widget, function(t)
		if self._disabled then
			return t.Frame
		elseif self._focused then
			return t.FrameActive
		elseif self._hovered then
			return t.FrameHover
		end
		return t.Frame
	end)
	table.insert(self._styled, frame)

	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = frame,
	})
	self:_bind(stroke, {
		Color = function(t)
			return self._invalid and t.Error or t.Accent
		end,
		Transparency = function()
			if self._invalid then
				return 0
			end
			return self._focused and 0.4 or 1
		end,
	})

	local box = Create("TextBox", {
		Name = "TextBox",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = options.ClearOnFocus == true,
		PlaceholderText = options.Placeholder or "",
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(metrics.FramePaddingX, 0),
		Size = UDim2.new(1, -metrics.FramePaddingX * 2, 1, 0),
		Parent = frame,
	})
	self:_bind(box, {
		TextColor3 = function(t)
			return self._disabled and t.DisabledText or t.Text
		end,
		PlaceholderColor3 = "Placeholder",
		FontFace = "Font",
		TextSize = "TextSize",
	})

	self._frame = frame
	self._box = box
	self.Root = labeled.Root
	self:_track(frame)

	self._maid:Give(box.Focused:Connect(function()
		if self._disabled then
			box:ReleaseFocus()
			return
		end
		self._focused = true
		box.TextTruncate = Enum.TextTruncate.None
		self:_restyle(true)
	end))

	self._maid:Give(box.FocusLost:Connect(function()
		self._focused = false
		box.TextTruncate = Enum.TextTruncate.AtEnd
		self:_commit(box.Text, true)
		self:_restyle(true)
	end))

	self._maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = box.Text
		if self._maxLength and utf8.len(text) and (utf8.len(text) :: number) > self._maxLength then
			local cut = utf8.offset(text, self._maxLength + 1)
			box.Text = string.sub(text, 1, (cut or #text + 1) - 1)
			return
		end
		if self._numeric then
			local filtered = string.gsub(text, "[^%d%.%-eE]", "")
			if filtered ~= text then
				box.Text = filtered
				return
			end
		end
		if not self._finished and self._focused then
			self:_commit(text, false)
		end
	end))
end

--- Converts raw text to a value, or returns nil and an error message.
function InputElement:_parse(text: string): (any, string?)
	local options = self.Options
	local value: any = text
	if self._numeric then
		local number = tonumber(text)
		if number == nil then
			return nil, "Not a number"
		end
		local min, max = tonumber(options.Min), tonumber(options.Max)
		if min then
			number = math.max(number, min)
		end
		if max then
			number = math.min(number, max)
		end
		value = number
	end
	if type(options.Validate) == "function" then
		local ok, result, message = pcall(options.Validate, value)
		if not ok then
			Utility.Warn("Input Validate error:", result)
			return nil, "Validation error"
		end
		if result == false then
			return nil, message
		end
	end
	return value, nil
end

function InputElement:_commit(text: string, final: boolean)
	local value, message = self:_parse(text)
	if value == nil then
		if final then
			self:_flashInvalid(text, message)
			self._box.Text = self:_display(self.Value)
		end
		return
	end
	self:SetValue(value)
	if final then
		self._box.Text = self:_display(self.Value)
	end
end

function InputElement:_flashInvalid(text: string, message: string?)
	self._invalid = true
	self:_restyle(false)
	self.Invalid:Fire(text, message)
	local token = {}
	self._invalidToken = token
	self._maid.InvalidTimeout = task.delay(1.2, function()
		if self._invalidToken == token and not self._destroyed then
			self._invalid = false
			self:_restyle(true)
		end
	end)
end

function InputElement:_display(value: any): string
	if value == nil then
		return ""
	end
	return tostring(value)
end

function InputElement:_apply(value: any): boolean
	local normalized: any
	if self._numeric then
		normalized = tonumber(value) or tonumber(self.Options.Min) or 0
	else
		normalized = value == nil and "" or tostring(value)
		if self._maxLength and #normalized > self._maxLength then
			normalized = string.sub(normalized, 1, self._maxLength)
		end
	end
	local changed = self.Value ~= normalized
	self.Value = normalized
	if not self._focused and self._box then
		self._box.Text = self:_display(normalized)
	end
	return changed
end

function InputElement:_deserialize(data: any)
	self:SetValue(data)
end

function InputElement:SetPlaceholder(text: string)
	self._box.PlaceholderText = text
end

--- Focuses the text field for typing.
function InputElement:Focus()
	if not self._disabled then
		self._box:CaptureFocus()
	end
end

function InputElement:_onDisabledChanged(disabled: boolean)
	if disabled and self._focused then
		self._box:ReleaseFocus()
	end
	self._box.TextEditable = not disabled
end

return InputElement
