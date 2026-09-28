--[[
	Section
	A collapsible region inside any container — the equivalent of a
	collapsing header or tree node in an immediate-mode toolkit.

	    local advanced = group:AddSection({ Name = "Advanced", Open = false })
	    advanced:AddCheckbox({ Name = "Debug Mode" })

	Styles:
	  "Header" (default) — full-width tinted header bar
	  "Tree"             — compact arrow + label, content indented
]]

local Container = require(script.Parent.Container)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Section = setmetatable({}, { __index = Container })
Section.__index = Section
Section.Kind = "Section"

function Section.new(parent: any, options: { [string]: any })
	local self = setmetatable({}, Section)
	local metrics = Layout.Metrics
	local text = Utility.ParseLabel(options.Name or "Section")

	self.Kind = "Section"
	self.Name = options.Name or "Section"
	self.Text = text
	self.Toggled = Signal.new()
	self._maid = Maid.new()
	self._open = options.Open ~= false
	self._style = options.Style == "Tree" and "Tree" or "Header"
	self._hovered = false

	local root = Create("Frame", {
		Name = "Section",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Layout.Fill(root)
	Layout.List(root, Enum.FillDirection.Vertical, metrics.ItemSpacing)

	local header = Create("TextButton", {
		Name = "Header",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(1, 0, 0, metrics.RowHeight),
		LayoutOrder = 1,
		Parent = root,
	})
	local isTree = self._style == "Tree"
	Theme.Bind(header, {
		BackgroundColor3 = function(t)
			if isTree then
				return t.HeaderHover
			end
			return self._hovered and t.HeaderHover or t.Header
		end,
		BackgroundTransparency = function()
			if isTree then
				return self._hovered and 0.4 or 1
			end
			return 0
		end,
	})
	Layout.Corner(header)

	local arrowSize = metrics.RowHeight - 6
	self._arrowOpen = Layout.Chevron(header, "Down", arrowSize, "Text")
	self._arrowClosed = Layout.Chevron(header, "Right", arrowSize, "Text")
	for _, arrow in { self._arrowOpen, self._arrowClosed } do
		arrow.Position = UDim2.new(0, 3, 0.5, 0)
		arrow.AnchorPoint = Vector2.new(0, 0.5)
	end

	self._label = Layout.Text(header, {
		Name = "Title",
		Text = text,
		Position = UDim2.fromOffset(arrowSize + 7, 0),
		Size = UDim2.new(1, -(arrowSize + 10), 1, 0),
	})

	local content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = root,
	})
	if isTree then
		Layout.Padding(content, metrics.IndentSpacing, 0, 0, 0)
	else
		Layout.Padding(content, 4, 0, 0, 0)
	end

	self._header = header
	self._contentFrame = content

	Container._init(self, content, parent._window, parent._path, parent)
	Container._mount(self, parent, root)

	self._maid:Give(header.MouseEnter:Connect(function()
		self._hovered = true
		Theme.Refresh(header, true)
	end))
	self._maid:Give(header.MouseLeave:Connect(function()
		self._hovered = false
		Theme.Refresh(header, true)
	end))
	self._maid:Give(header.Activated:Connect(function()
		self:Toggle()
	end))

	self:_updateOpen()
	return self
end

function Section:_updateOpen()
	self._contentFrame.Visible = self._open
	self._arrowOpen.Visible = self._open
	self._arrowClosed.Visible = not self._open
end

function Section:SetOpen(open: boolean)
	open = open and true or false
	if self._open == open then
		return
	end
	self._open = open
	self:_updateOpen()
	self.Toggled:Fire(open)
end

function Section:IsOpen(): boolean
	return self._open
end

function Section:Toggle()
	self:SetOpen(not self._open)
end

function Section:SetText(text: string)
	self.Text = text
	self._label.Text = text
end

function Section:Destroy()
	if self._destroyed then
		return
	end
	self.Toggled:Destroy()
	Container._destroyNested(self)
end

return Section
