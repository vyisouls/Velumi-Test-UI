--[[
	Paragraph
	An optional bold title followed by wrapped body text.

	    group:AddParagraph({
	        Title = "About",
	        Text = "Velumi is a compact, developer-focused UI library.",
	    })

	Options: Title, Text, RichText, Tooltip, ContextMenu, Visible.
	Methods: SetTitle(text), SetText(text).
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Paragraph = Element.extend("Paragraph")
Paragraph.Fill = true

function Paragraph:_build()
	local options = self.Options

	self.Text = tostring(options.Text or options.Description or options.Content or "")
	self.Title = options.Title

	local root = Create("Frame", {
		Name = "Paragraph",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Layout.Fill(root)
	Layout.List(root, Enum.FillDirection.Vertical, 2)
	Layout.Padding(root, 0, 0, 2, 2)

	local title = Layout.Text(root, {
		Name = "Title",
		Text = self.Title or "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 1,
		Visible = self.Title ~= nil and self.Title ~= "",
	}, function(t)
		return self._disabled and t.DisabledText or t.Text
	end)
	Theme.Bind(title, { FontFace = "FontBold" })
	table.insert(self._styled, title)

	local body = Layout.Text(root, {
		Name = "Body",
		Text = self.Text,
		RichText = options.RichText == true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
	}, function(t)
		return self._disabled and t.DisabledText or t.SecondaryText
	end)
	table.insert(self._styled, body)

	self._title = title
	self._label = body
	self.Root = root
end

function Paragraph:SetTitle(text: string?)
	self.Title = text
	self._title.Text = text or ""
	self._title.Visible = text ~= nil and text ~= ""
end

function Paragraph:GetValue(): any
	return self.Text
end

return Paragraph
