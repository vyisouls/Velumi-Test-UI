--[[
	Tab
	A page of a window. Tabs are laid out in columns and hold Groups.

	    local main = window:AddTab({ Name = "Main", Columns = 2 })
	    local left = main:AddGroup({ Name = "General" })               -- column 1
	    local right = main:AddGroup({ Name = "Visuals", Side = "Right" }) -- column 2

	Depending on the window's `TabStyle`, the tab button appears in a left
	sidebar ("Sidebar", default) or a top tab bar ("Top").
]]

local Group = require(script.Parent.Group)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Animation = require(script.Parent.Animation)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Tab = {}
Tab.__index = Tab
Tab.Kind = "Tab"

function Tab.new(window: any, options: { [string]: any }, order: number)
	local self = setmetatable({}, Tab)
	local metrics = Layout.Metrics
	local name = options.Name or ("Tab " .. order)

	self.Kind = "Tab"
	self.Name = name
	self.Text = (Utility.ParseLabel(name))
	self.Window = window
	self.Groups = {}
	self._maid = Maid.new()
	self._selected = false
	self._hovered = false
	self._visible = options.Visible ~= false
	self._columnCount = math.max(1, math.floor(options.Columns or 1))
	self._groupOrder = 0

	-- Page ----------------------------------------------------------------
	local page = Create("ScrollingFrame", {
		Name = "Page_" .. self.Text,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = metrics.ScrollBarThickness,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Visible = false,
	})
	Theme.Bind(page, { ScrollBarImageColor3 = "ScrollBar" })

	local columnsFrame = Create("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	})
	Layout.Padding(columnsFrame, metrics.WindowPadding)
	Layout.List(columnsFrame, Enum.FillDirection.Horizontal, metrics.WindowPadding)

	local count = self._columnCount
	local gap = metrics.WindowPadding
	self._columns = {}
	for index = 1, count do
		local column = Create("Frame", {
			Name = "Column" .. index,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = columnsFrame,
		})
		Layout.List(column, Enum.FillDirection.Vertical, metrics.WindowPadding)
		self._columns[index] = column
	end

	self.Page = page
	self._maid:Give(page)
	page.Parent = window._pages

	-- Button --------------------------------------------------------------
	self:_buildButton(order)

	return self
end

function Tab:_buildButton(order: number)
	local window = self.Window
	local metrics = Layout.Metrics
	local sidebar = window._tabStyle == "Sidebar"

	local button = Create("TextButton", {
		Name = "Tab_" .. self.Text,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = order,
		Visible = self._visible,
	})

	if sidebar then
		button.Size = UDim2.new(1, 0, 0, metrics.RowHeight + 3)
	else
		button.Size = UDim2.new(0, 0, 1, 0)
		button.AutomaticSize = Enum.AutomaticSize.X
	end

	Theme.Bind(button, {
		BackgroundColor3 = function(t)
			if self._selected then
				return sidebar and t.Header or t.HeaderActive
			elseif self._hovered then
				return sidebar and t.Hover or t.HeaderHover
			end
			return sidebar and t.Sidebar or t.Button
		end,
		BackgroundTransparency = function()
			if sidebar and not self._selected and not self._hovered then
				return 1
			end
			return 0
		end,
	})
	Layout.Corner(button)

	local label = Layout.Text(button, {
		Name = "Label",
		Text = self.Text,
	}, function(t)
		return self._selected and t.Text or t.SecondaryText
	end)

	if sidebar then
		label.Position = UDim2.fromOffset(10, 0)
		label.Size = UDim2.new(1, -14, 1, 0)

		local strip = Create("Frame", {
			Name = "Indicator",
			BorderSizePixel = 0,
			Size = UDim2.new(0, 2, 1, -6),
			Position = UDim2.fromOffset(2, 3),
			Parent = button,
		})
		Theme.Bind(strip, {
			BackgroundColor3 = "Accent",
			BackgroundTransparency = function()
				return self._selected and 0 or 1
			end,
		})
		self._indicator = strip
	else
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.TextTruncate = Enum.TextTruncate.None
		Layout.Padding(button, 10, 10, 0, 0)
	end

	self._label = label
	self.Button = button
	self._maid:Give(button)

	self._maid:Give(button.MouseEnter:Connect(function()
		self._hovered = true
		self:_restyle(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hovered = false
		self:_restyle(true)
	end))
	self._maid:Give(button.Activated:Connect(function()
		self:Select()
	end))

	button.Parent = window._tabList
end

function Tab:_restyle(animated: boolean?)
	Theme.Refresh(self.Button, animated)
	Theme.Refresh(self._label, animated)
	if self._indicator then
		Theme.Refresh(self._indicator, animated)
	end
end

function Tab:_setSelected(selected: boolean)
	self._selected = selected
	self.Page.Visible = selected
	self:_restyle(false)
end

--- Adds a Group to this tab. `Side = "Right"` (or `Column = 2`) targets the
--- second column when the tab was created with `Columns = 2`.
function Tab:AddGroup(options: any): any
	local parsed = Utility.Options(options, "AddGroup")
	local columnIndex = 1
	if type(parsed.Column) == "number" then
		columnIndex = parsed.Column
	elseif parsed.Side == "Right" then
		columnIndex = 2
	end
	columnIndex = math.clamp(math.floor(columnIndex), 1, self._columnCount)

	self._groupOrder += 1
	local group = Group.new(self, self._columns[columnIndex], self._groupOrder, parsed)
	table.insert(self.Groups, group)
	return group
end

function Tab:_forgetGroup(group: any)
	local index = table.find(self.Groups, group)
	if index then
		table.remove(self.Groups, index)
	end
end

function Tab:GetGroup(name: string): any
	for _, group in self.Groups do
		if group.Name == name or group.Text == name then
			return group
		end
	end
	return nil
end

function Tab:Select()
	self.Window:SelectTab(self)
end

function Tab:IsSelected(): boolean
	return self._selected
end

function Tab:SetText(text: string)
	self.Text = text
	self._label.Text = text
end

--- Shows or hides the tab's button. Hiding the selected tab selects the
--- first visible tab instead.
function Tab:SetVisible(visible: boolean)
	self._visible = visible and true or false
	self.Button.Visible = self._visible
	if not self._visible and self._selected then
		self.Window:_selectFirstVisible(self)
	end
end

function Tab:IsVisible(): boolean
	return self._visible
end

--- Scrolls the tab page back to the top.
function Tab:ScrollToTop()
	self.Page.CanvasPosition = Vector2.zero
end

function Tab:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self.Groups, 1, -1 do
		self.Groups[index]:Destroy()
	end
	self.Window:_forgetTab(self)
	Animation.CancelTree(self.Page)
	Animation.CancelTree(self.Button)
	Theme.UnbindTree(self.Page)
	Theme.UnbindTree(self.Button)
	self._maid:Clean()
end

return Tab
