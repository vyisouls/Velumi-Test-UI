--[[
	Group
	A titled, bordered panel inside a tab column. Groups are the main place
	controls live:

	    local general = tab:AddGroup({ Name = "General" })
	    general:AddCheckbox({ Name = "Enabled" })

	Options: Name, Side ("Left" | "Right") or Column (number),
	         Collapsible (click the title to fold), Collapsed, Border.
]]

local Container = require(script.Parent.Container)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Animation = require(script.Parent.Animation)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Group = setmetatable({}, { __index = Container })
Group.__index = Group
Group.Kind = "Group"

function Group.new(tab: any, column: Frame, order: number, options: { [string]: any })
	local self = setmetatable({}, Group)
	local metrics = Layout.Metrics
	local name = options.Name or "Group"
	local text = Utility.ParseLabel(name)

	self.Kind = "Group"
	self.Name = name
	self.Text = text
	self.Tab = tab
	self.Window = tab.Window
	self._maid = Maid.new()
	self._visible = true
	self._collapsible = options.Collapsible == true
	self._collapsed = self._collapsible and options.Collapsed == true
	self._hovered = false

	local root = Create("Frame", {
		Name = "Group_" .. text,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Theme.Bind(root, { BackgroundColor3 = "Child" })
	Layout.Corner(root)
	if options.Border ~= false then
		Layout.Stroke(root, "Border")
	end
	Layout.List(root, Enum.FillDirection.Vertical, 0)

	local header = Create("TextButton", {
		Name = "Header",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(1, 0, 0, metrics.RowHeight + 4),
		LayoutOrder = 1,
		Parent = root,
	})
	Theme.Bind(header, {
		BackgroundColor3 = "Hover",
		BackgroundTransparency = function()
			return (self._collapsible and self._hovered) and 0.5 or 1
		end,
	})

	local titleOffset = metrics.GroupPadding
	if self._collapsible then
		local arrowSize = metrics.RowHeight - 6
		self._arrowOpen = Layout.Chevron(header, "Down", arrowSize, "SecondaryText")
		self._arrowClosed = Layout.Chevron(header, "Right", arrowSize, "SecondaryText")
		for _, arrow in { self._arrowOpen, self._arrowClosed } do
			arrow.AnchorPoint = Vector2.new(0, 0.5)
			arrow.Position = UDim2.new(0, metrics.GroupPadding - 2, 0.5, 0)
		end
		titleOffset += arrowSize + 2
	end

	self._title = Layout.Text(header, {
		Name = "Title",
		Text = text,
		Position = UDim2.fromOffset(titleOffset, 0),
		Size = UDim2.new(1, -(titleOffset + metrics.GroupPadding), 1, 0),
	})
	Theme.Bind(self._title, { FontFace = "FontBold" })

	local divider = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = root,
	})
	Theme.Bind(divider, { BackgroundColor3 = "Separator" })
	self._divider = divider

	local content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = root,
	})
	Layout.Padding(content, metrics.GroupPadding, metrics.GroupPadding, metrics.GroupPadding, metrics.GroupPadding)
	self._contentFrame = content

	self.Root = root
	self._maid:Give(root)

	Container._init(self, content, tab.Window, `{tab.Name}/{name}`, nil)

	if self._collapsible then
		self._maid:Give(header.MouseEnter:Connect(function()
			self._hovered = true
			Theme.Refresh(header, true)
		end))
		self._maid:Give(header.MouseLeave:Connect(function()
			self._hovered = false
			Theme.Refresh(header, true)
		end))
		self._maid:Give(header.Activated:Connect(function()
			self:SetCollapsed(not self._collapsed)
		end))
	end

	self:_updateCollapsed()
	root.Parent = column
	return self
end

function Group:_updateCollapsed()
	local open = not self._collapsed
	self._contentFrame.Visible = open
	self._divider.Visible = open
	if self._arrowOpen then
		self._arrowOpen.Visible = open
		self._arrowClosed.Visible = not open
	end
end

function Group:SetCollapsed(collapsed: boolean)
	if not self._collapsible then
		return
	end
	self._collapsed = collapsed and true or false
	self:_updateCollapsed()
end

function Group:IsCollapsed(): boolean
	return self._collapsed
end

function Group:SetText(text: string)
	self.Text = text
	self._title.Text = text
end

Group.SetTitle = Group.SetText

function Group:SetVisible(visible: boolean)
	self._visible = visible and true or false
	self.Root.Visible = self._visible
end

function Group:IsVisible(): boolean
	return self._visible
end

function Group:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:Clear()
	if self.Tab then
		self.Tab:_forgetGroup(self)
	end
	Animation.CancelTree(self.Root)
	Theme.UnbindTree(self.Root)
	self._maid:Clean()
end

return Group
