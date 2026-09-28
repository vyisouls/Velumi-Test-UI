--[[
	Button
	A compact push button sized to its text.

	    group:AddButton({
	        Name = "Execute",
	        Callback = function() print("pressed") end,
	    })

	Options
	  Name / Text   label
	  Callback      called on press
	  Style         "Default" | "Accent" | "Danger"
	  FullWidth     stretch across the row (shares width on SameLine rows)
	  Width         fixed width in pixels
	  Confirm       require a second click within 2 seconds
	  ConfirmText   text shown while awaiting confirmation (default "Confirm?")

	Buttons have no value and are not saved in configuration.
	`button.Pressed` (alias of `Changed`) fires on every press.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Button = Element.extend("Button")

function Button:_build()
	local options = self.Options
	local metrics = Layout.Metrics
	self.Pressed = self.Changed
	self._confirming = false

	local button = Create("TextButton", {
		Name = "Button",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = self.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0, 0, 0, metrics.RowHeight),
		AutomaticSize = Enum.AutomaticSize.X,
	})

	if options.FullWidth then
		button.AutomaticSize = Enum.AutomaticSize.None
		button.Size = UDim2.new(1, 0, 0, metrics.RowHeight)
		Layout.Fill(button)
	elseif type(options.Width) == "number" then
		button.AutomaticSize = Enum.AutomaticSize.None
		button.Size = UDim2.fromOffset(options.Width, metrics.RowHeight)
	end

	Layout.Padding(button, 10, 10, 0, 0)
	Layout.Corner(button)

	self:_bind(button, {
		BackgroundColor3 = function(t)
			local style = self.Options.Style
			local base, hover, active = t.Button, t.ButtonHover, t.ButtonActive
			if style == "Accent" then
				base, hover, active = t.Accent, t.Accent:Lerp(t.Text, 0.12), t.Accent:Lerp(t.Background, 0.2)
			elseif style == "Danger" then
				base, hover, active = t.Button:Lerp(t.Error, 0.35), t.Button:Lerp(t.Error, 0.55), t.Error
			end
			if self._confirming then
				return t.Button:Lerp(t.Warning, 0.45)
			elseif self._disabled then
				return base
			elseif self._pressed then
				return active
			elseif self._hovered then
				return hover
			end
			return base
		end,
		BackgroundTransparency = function()
			return self._disabled and 0.4 or 0
		end,
		TextColor3 = function(t)
			if self._disabled then
				return t.DisabledText
			elseif self.Options.Style == "Accent" then
				return t.AccentText
			end
			return t.Text
		end,
		FontFace = "Font",
		TextSize = "TextSize",
	})

	self._label = button
	self.Root = button
	self:_track(button)

	self._maid:Give(button.Activated:Connect(function()
		if self._disabled then
			return
		end
		if options.Confirm then
			if not self._confirming then
				self:_setConfirming(true)
				return
			end
			self:_setConfirming(false)
		end
		self:Press()
	end))
end

function Button:_setConfirming(confirming: boolean)
	self._confirming = confirming
	self._label.Text = confirming and (self.Options.ConfirmText or "Confirm?") or self.Text
	self:_restyle(true)
	if confirming then
		local token = {}
		self._confirmToken = token
		self._maid.ConfirmTimeout = task.delay(2, function()
			if self._confirmToken == token and not self._destroyed then
				self:_setConfirming(false)
			end
		end)
	else
		self._confirmToken = nil
	end
end

--- Runs the button's callback as if it were pressed.
function Button:Press()
	if self._destroyed then
		return
	end
	self.Changed:Fire()
	Utility.SafeCall(self._callback)
end

function Button:SetText(text: string)
	self.Text = text
	if not self._confirming then
		self._label.Text = text
	end
end

function Button:SetStyle(style: string)
	self.Options.Style = style
	self:_restyle(false)
end

-- Buttons carry no value.
function Button:GetValue(): any
	return nil
end

function Button:_callbackArgs(): ...any
	return
end

return Button
