--[[
	Toggle
	A compact, square-cornered switch followed by its label. Same API and
	value type as Checkbox; use whichever reads better for the setting.

	    group:AddToggle({
	        Name = "Auto Save",
	        Default = true,
	        Callback = function(value) end,
	    })

	Options: Name, Default (boolean), Callback(value), Flag, Save, Bind,
	         Tooltip, Disabled, ContextMenu.
	Value: boolean.
]]

local Animation = require(script.Parent.Parent.Core.Animation)
local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Toggle = Element.extend("Toggle")
Toggle.Saveable = true

local TRACK_WIDTH = 26
local KNOB_INSET = 2

function Toggle:_build()
	local metrics = Layout.Metrics
	local trackHeight = metrics.CheckboxSize - 2
	local knobSize = trackHeight - KNOB_INSET * 2

	local root = Create("TextButton", {
		Name = "Toggle",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(0, 0, 0, metrics.RowHeight),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Layout.List(root, Enum.FillDirection.Horizontal, metrics.InnerSpacing, {
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local track = Create("Frame", {
		Name = "Track",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(TRACK_WIDTH, trackHeight),
		LayoutOrder = 1,
		Parent = root,
	})
	Layout.Corner(track)
	self:_bind(track, {
		BackgroundColor3 = function(t)
			if self.Value then
				if self._disabled then
					return t.Frame:Lerp(t.Accent, 0.35)
				end
				return self._hovered and t.Accent:Lerp(t.Text, 0.1) or t.Accent
			end
			if self._disabled then
				return t.Frame
			end
			return self._hovered and t.FrameHover or t.Frame
		end,
	})

	local knob = Create("Frame", {
		Name = "Knob",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(knobSize, knobSize),
		Position = UDim2.new(0, KNOB_INSET, 0.5, 0),
		Parent = track,
	})
	Layout.Corner(knob)
	self:_bind(knob, {
		BackgroundColor3 = function(t)
			if self._disabled then
				return t.DisabledText
			end
			return self.Value and t.AccentText or t.SecondaryText
		end,
	})

	if self.Text ~= "" then
		self:_makeLabel(root, {
			Name = "Label",
			Text = self.Text,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.None,
			LayoutOrder = 2,
		})
	end

	self._knob = knob
	self._knobTravel = TRACK_WIDTH - knobSize - KNOB_INSET * 2
	self.Root = root
	self:_track(root)

	self._maid:Give(root.Activated:Connect(function()
		if not self._disabled then
			self:SetValue(not self.Value)
		end
	end))
end

function Toggle:_apply(value: any): boolean
	local normalized = value == true
	local changed = self.Value ~= normalized
	self.Value = normalized

	local target = UDim2.new(0, KNOB_INSET + (normalized and self._knobTravel or 0), 0.5, 0)
	if changed and self.Root and self.Root.Parent then
		Animation.Tween(self._knob, { Position = target }, Animation.Durations.Normal)
	else
		self._knob.Position = target
	end
	if changed then
		self:_restyle(true)
	end
	return changed
end

function Toggle:_deserialize(data: any)
	self:SetValue(data == true)
end

function Toggle:Toggle()
	self:SetValue(not self.Value)
end

return Toggle
