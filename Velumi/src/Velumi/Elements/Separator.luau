--[[
	Separator
	A thin horizontal rule, optionally with text on the left:

	    group:AddSeparator()
	    group:AddSeparator("Advanced")      -- "Advanced ─────────────"

	Options: Text, Visible.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Separator = Element.extend("Separator")
Separator.Fill = true

function Separator:_build()
	local metrics = Layout.Metrics
	local text = tostring(self.Options.Text or "")
	self.Text = text

	local hasText = text ~= ""
	local root = Create("Frame", {
		Name = "Separator",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, hasText and metrics.RowHeight or 5),
	})
	Layout.Fill(root)

	local line = Create("Frame", {
		Name = "Line",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = root,
	})
	self:_bind(line, { BackgroundColor3 = "Separator" })

	if hasText then
		local label = self:_makeLabel(root, {
			Name = "Label",
			Text = text,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextTruncate = Enum.TextTruncate.None,
		})
		self._maid:Give(label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_layoutLine()
		end))
		self._textLabel = label
	end

	self._line = line
	self.Root = root
	self:_layoutLine()
end

function Separator:_layoutLine()
	local label = self._textLabel
	if not label or label.Text == "" then
		self._line.Position = UDim2.fromScale(0, 0.5)
		self._line.Size = UDim2.new(1, 0, 0, 1)
		return
	end
	-- TextBounds is unscaled, so it's safe inside a UIScale.
	local width = label.TextBounds.X + Layout.Metrics.InnerSpacing
	self._line.Position = UDim2.new(0, width, 0.5, 0)
	self._line.Size = UDim2.new(1, -width, 0, 1)
end

function Separator:SetText(text: string)
	self.Text = text
	if self._textLabel then
		self._textLabel.Text = text
		self:_layoutLine()
	end
end

function Separator:GetValue(): any
	return self.Text
end

return Separator
