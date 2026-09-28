--[[
	ProgressBar
	A framed bar filled from left to right, with overlay text.

	    local bar = group:AddProgressBar({ Name = "Loading", Default = 0.25 })
	    bar:SetValue(0.8)

	Options
	  Default        0..1 (default 0)
	  Format(value)  custom overlay text (default "NN%")
	  Style          "Accent" (default) | "Success" | "Warning" | "Error"
	  Name, Tooltip, Visible, Disabled
	Value: number 0..1. Not saved in configuration.
]]

local Animation = require(script.Parent.Parent.Core.Animation)
local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local ProgressBar = Element.extend("ProgressBar")
ProgressBar.Fill = true

function ProgressBar:_build()
	local labeled = self:_labeled()
	local frame = Layout.FrameBox(labeled.Widget, "Frame")

	local fill = Create("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = frame,
	})
	Layout.Corner(fill)
	self:_bind(fill, {
		BackgroundColor3 = function(t)
			if self._disabled then
				return t.DisabledText
			end
			return t[self.Options.Style or "Accent"] or t.Accent
		end,
	})

	local text = Layout.Text(frame, {
		Name = "Overlay",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	}, function(t)
		return self._disabled and t.DisabledText or t.Text
	end)
	table.insert(self._styled, text)

	self._fill = fill
	self._text = text
	self.Root = labeled.Root
	if self.Default == nil then
		self.Default = 0
	end
end

function ProgressBar:_apply(value: any): boolean
	local number = math.clamp(tonumber(value) or 0, 0, 1)
	local changed = self.Value ~= number
	self.Value = number

	local target = UDim2.fromScale(number, 1)
	if changed and self.Root.Parent then
		Animation.Tween(self._fill, { Size = target }, Animation.Durations.Normal)
	else
		self._fill.Size = target
	end

	local format = self.Options.Format
	local label
	if type(format) == "function" then
		local ok, result = pcall(format, number)
		label = ok and tostring(result) or ""
	else
		label = string.format("%d%%", math.floor(number * 100 + 0.5))
	end
	self._text.Text = label
	return changed
end

return ProgressBar
