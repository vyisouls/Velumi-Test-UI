--[[
	Checkbox
	The classic square check box followed by its label.

	    group:AddCheckbox({
	        Name = "Enabled",
	        Default = false,
	        Callback = function(value) print(value) end,
	    })

	Options: Name, Default (boolean), Callback(value), Flag, Save, Bind,
	         Tooltip, Disabled, ContextMenu.
	Value: boolean.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Checkbox = Element.extend("Checkbox")
Checkbox.Saveable = true

function Checkbox:_build()
	local metrics = Layout.Metrics
	local boxSize = metrics.CheckboxSize

	local root = Create("TextButton", {
		Name = "Checkbox",
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

	local box = Create("Frame", {
		Name = "Box",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(boxSize, boxSize),
		LayoutOrder = 1,
		Parent = root,
	})
	Layout.Corner(box)
	self:_bind(box, {
		BackgroundColor3 = function(t)
			if self._disabled then
				return t.Frame
			elseif self._pressed then
				return t.FrameActive
			elseif self._hovered then
				return t.FrameHover
			end
			return t.Frame
		end,
	})

	local check = Layout.CheckMark(box, boxSize, function(t)
		return self._disabled and t.DisabledText or t.CheckMark
	end)
	for _, segment in check:GetChildren() do
		table.insert(self._styled, segment)
	end
	self._check = check

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

	self.Root = root
	self:_track(root)

	self._maid:Give(root.Activated:Connect(function()
		if not self._disabled then
			self:SetValue(not self.Value)
		end
	end))
end

function Checkbox:_apply(value: any): boolean
	local normalized = value == true
	local changed = self.Value ~= normalized
	self.Value = normalized
	self._check.Visible = normalized
	return changed
end

function Checkbox:_deserialize(data: any)
	self:SetValue(data == true)
end

--- Flips the value.
function Checkbox:Toggle()
	self:SetValue(not self.Value)
end

return Checkbox
