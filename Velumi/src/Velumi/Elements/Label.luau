--[[
	Label
	A line of text. Accepts a plain string or an options table.

	    group:AddLabel("Plain text")
	    group:AddLabel({ Text = "Connected", Style = "Success", Bullet = true })

	Options
	  Text      the text
	  Style     "Default" | "Secondary" | "Disabled" | "Accent" |
	            "Success" | "Warning" | "Error"
	  Color     a Color3 overriding Style
	  Bullet    prefix with a bullet
	  Wrap      wrap long text onto several lines instead of truncating
	  Align     "Left" (default) | "Center" | "Right"
	  RichText  enable Roblox rich text tags
	  Tooltip, ContextMenu, Visible
	Labels have no value; GetValue() returns the text.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Label = Element.extend("Label")
Label.Fill = true

local STYLE_KEYS = {
	Default = "Text",
	Secondary = "SecondaryText",
	Disabled = "DisabledText",
	Accent = "Accent",
	Success = "Success",
	Warning = "Warning",
	Error = "Error",
}

local ALIGN = {
	Left = Enum.TextXAlignment.Left,
	Center = Enum.TextXAlignment.Center,
	Right = Enum.TextXAlignment.Right,
}

function Label:_build()
	local options = self.Options
	local metrics = Layout.Metrics

	self.Text = tostring(options.Text or options.Name or "")
	self._style = STYLE_KEYS[options.Style or "Default"] and (options.Style or "Default") or "Default"
	self._color = typeof(options.Color) == "Color3" and options.Color or nil
	local wrap = options.Wrap == true

	local root = Create("Frame", {
		Name = "Label",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, metrics.RowHeight),
	})
	if wrap then
		root.AutomaticSize = Enum.AutomaticSize.Y
		root.Size = UDim2.new(1, 0, 0, 0)
	end
	Layout.Fill(root)

	local offset = 0
	if options.Bullet then
		local bullet = Create("Frame", {
			Name = "Bullet",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(6, metrics.RowHeight / 2),
			Size = UDim2.fromOffset(4, 4),
			Parent = root,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bullet })
		self:_bind(bullet, {
			BackgroundColor3 = function(t)
				return self:_resolveColor(t)
			end,
		})
		offset = 16
	end

	local text = Layout.Text(root, {
		Name = "Text",
		Text = self.Text,
		RichText = options.RichText == true,
		TextXAlignment = ALIGN[options.Align or "Left"] or Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(offset, 0),
		Size = UDim2.new(1, -offset, if wrap then 0 else 1, 0),
	}, function(t)
		return self:_resolveColor(t)
	end)
	table.insert(self._styled, text)

	if wrap then
		text.TextWrapped = true
		text.TextTruncate = Enum.TextTruncate.None
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.TextYAlignment = Enum.TextYAlignment.Top
		Layout.Padding(text, 0, 0, 3, 3)
	end

	self._label = text
	self.Root = root
end

function Label:_resolveColor(t: any): Color3
	if self._disabled then
		return t.DisabledText
	end
	if self._color then
		return self._color
	end
	return t[STYLE_KEYS[self._style]]
end

function Label:GetValue(): any
	return self.Text
end

function Label:SetStyle(style: string)
	if STYLE_KEYS[style] then
		self._style = style
		self._color = nil
		self:_restyle(false)
	end
end

function Label:SetColor(color: Color3?)
	self._color = color
	self:_restyle(false)
end

return Label
