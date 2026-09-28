--[[
	Window
	A draggable, resizable, focusable panel containing tabs, an optional menu
	bar and an optional status bar.

	    local window = Velumi:CreateWindow({
	        Title = "Velumi",
	        Size = UDim2.fromOffset(700, 480),
	        Center = true,
	    })

	Windows are independent: each has its own tabs, configuration, z-order
	and scale. Clicking a window brings it to the front and highlights its
	title bar.
]]

local Animation = require(script.Parent.Animation)
local Config = require(script.Parent.Config)
local Context = require(script.Parent.Context)
local Input = require(script.Parent.Input)
local Layout = require(script.Parent.Layout)
local Tab = require(script.Parent.Tab)
local Theme = require(script.Parent.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Components = script.Parent.Parent.Components

local Create = Utility.Create

local Window = {}
Window.__index = Window
Window.Kind = "Window"

local DEFAULT_SIZE = Vector2.new(700, 480)
local DEFAULT_MIN = Vector2.new(360, 220)
local HUGE = Vector2.new(math.huge, math.huge)
local EDGE_MARGIN = 8

local windowCount = 0

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local function toVector2(value: any, fallback: Vector2): Vector2
	if typeof(value) == "Vector2" then
		return value
	elseif typeof(value) == "UDim2" then
		local viewport = Context.GetViewportSize()
		return Vector2.new(value.X.Scale * viewport.X + value.X.Offset, value.Y.Scale * viewport.Y + value.Y.Offset)
	end
	return fallback
end

--- Squares off selected sides of a rounded frame by overlaying same-colored
--- filler frames (so only the outer window corners stay rounded).
local function squareSides(frame: GuiObject, colorSource: any, sides: { string })
	local fillers = {}
	for _, side in sides do
		local filler = Create("Frame", {
			Name = "Square" .. side,
			BorderSizePixel = 0,
			ZIndex = 0,
		})
		if side == "Bottom" then
			filler.Size = UDim2.fromScale(1, 0.5)
			filler.Position = UDim2.fromScale(0, 0.5)
		elseif side == "Top" then
			filler.Size = UDim2.fromScale(1, 0.5)
		elseif side == "Right" then
			filler.Size = UDim2.fromScale(0.5, 1)
			filler.Position = UDim2.fromScale(0.5, 0)
		elseif side == "Left" then
			filler.Size = UDim2.fromScale(0.5, 1)
		end
		Theme.Bind(filler, { BackgroundColor3 = colorSource })
		filler.Parent = frame
		table.insert(fillers, filler)
	end
	return fillers
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

function Window.new(options: { [string]: any })
	local generation = Context.Retain()
	windowCount += 1

	local self = setmetatable({}, Window)
	self._generation = generation
	local metrics = Layout.Metrics

	self.Kind = "Window"
	self.Title = options.Title or "Velumi"
	self.Tabs = {}
	self.Options = options

	self.Config = Config.new(self)
	self.Values = self.Config.Values
	self.Flags = self.Config.Flags

	self.Closed = Signal.new()
	self.Destroyed = Signal.new()
	self.VisibilityChanged = Signal.new()
	self.FocusChanged = Signal.new()
	self.TabChanged = Signal.new()
	self.ConfigChanged = self.Config.Changed

	self._maid = Maid.new()
	self._id = windowCount
	self._tabStyle = options.TabStyle == "Top" and "Top" or "Sidebar"
	self._visible = options.Visible ~= false
	self._focused = false
	self._minimized = false
	self._maximized = false
	self._destroyed = false
	self._draggable = options.Draggable ~= false
	self._resizable = options.Resizable ~= false
	self._destroyOnClose = options.DestroyOnClose == true
	self._onClose = options.OnClose
	self._userScale = options.Scale or 1
	self._autoScale = options.AutoScale ~= false
	self._fitScale = 1
	self._minSize = toVector2(options.MinSize, DEFAULT_MIN)
	self._maxSize = toVector2(options.MaxSize, HUGE)
	self._size = toVector2(options.Size, DEFAULT_SIZE)
	self._size = self:_clampSize(self._size)
	self._tabOrder = 0

	-- Root ----------------------------------------------------------------
	local root = Create("Frame", {
		Name = "Window_" .. self.Title,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(self._size.X, self._size.Y),
		Visible = self._visible,
	})
	Theme.Bind(root, {
		BackgroundColor3 = "Window",
		BackgroundTransparency = "WindowTransparency",
	})
	Layout.Corner(root, "WindowRounding")
	Layout.Stroke(root, function(t)
		return self._focused and t.Border:Lerp(t.Accent, 0.25) or t.Border
	end)
	self._stroke = root:FindFirstChildOfClass("UIStroke")

	self._uiScale = Create("UIScale", { Scale = 1, Parent = root })
	self.Root = root
	self._maid:Give(root)

	self:_buildTitleBar()
	self:_buildBody()
	self:_buildResizeGrip()

	if options.StatusBar then
		self:SetStatus(type(options.StatusBar) == "string" and options.StatusBar or "")
	end

	self:_layout()

	-- Placement -----------------------------------------------------------
	root.Parent = Context.GetLayer("Windows")
	Context.RegisterWindow(self)
	self:_updateScale()

	if options.Position then
		local position = toVector2(options.Position, Vector2.zero)
		root.Position = UDim2.fromOffset(position.X, position.Y)
	end
	if options.Center ~= false and not options.Position then
		self:Center()
	end

	-- Global hooks -------------------------------------------------------
	self._maid:Give(Context.ViewportChanged:Connect(function()
		self:_updateScale()
		if self._maximized then
			self:_applyMaximized()
		end
		self:_clampIntoView()
	end))
	self._maid:Give(Context.ScaleChanged:Connect(function()
		self:_updateScale()
	end))

	if options.ToggleKey then
		self:SetToggleKey(options.ToggleKey)
	end

	if self._visible then
		Context.Focus(self)
	end
	return self
end

function Window:_buildTitleBar()
	local metrics = Layout.Metrics
	local height = metrics.TitleHeight
	local options = self.Options

	local titleBar = Create("Frame", {
		Name = "TitleBar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = 2,
	})
	local titleColor = function(t)
		return self._focused and t.TitleBarActive or t.TitleBar
	end
	Theme.Bind(titleBar, { BackgroundColor3 = titleColor })
	Layout.Corner(titleBar, "WindowRounding")
	self._titleFillers = squareSides(titleBar, titleColor, { "Bottom" })

	self._titleLabel = Layout.Text(titleBar, {
		Name = "Title",
		Text = self.Title,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -90, 1, 0),
		ZIndex = 2,
	})

	local buttons = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 2,
		Parent = titleBar,
	})
	Layout.List(buttons, Enum.FillDirection.Horizontal, 1, {
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	self._titleButtons = buttons

	local function makeButton(name: string, order: number, draw: (Frame, any) -> (), onClick: () -> ())
		local size = height - 5
		local hovered = false
		local button = Create("TextButton", {
			Name = name,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.fromOffset(size, size),
			LayoutOrder = order,
			ZIndex = 2,
			Parent = buttons,
		})
		Theme.Bind(button, {
			BackgroundColor3 = function(t)
				if name == "Close" and hovered then
					return t.Error
				end
				return t.Hover
			end,
			BackgroundTransparency = function()
				return hovered and 0 or 1
			end,
		})
		Layout.Corner(button)

		local icon = Create("Frame", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			ZIndex = 2,
			Parent = button,
		})
		local iconColor = function(t)
			return hovered and t.Text or t.SecondaryText
		end
		draw(icon, iconColor)

		local function refresh()
			Theme.Refresh(button, true)
			for _, descendant in icon:GetDescendants() do
				Theme.Refresh(descendant, true)
			end
		end
		self._maid:Give(button.MouseEnter:Connect(function()
			hovered = true
			refresh()
		end))
		self._maid:Give(button.MouseLeave:Connect(function()
			hovered = false
			refresh()
		end))
		self._maid:Give(button.Activated:Connect(onClick))
		return button
	end

	if options.Minimizable ~= false then
		makeButton("Minimize", 1, function(icon, color)
			local line = Create("Frame", {
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(9, 1),
				Position = UDim2.fromOffset(0, 7),
				ZIndex = 2,
			})
			Theme.Bind(line, { BackgroundColor3 = color })
			line.Parent = icon
		end, function()
			if self._minimized then
				self:Restore()
			else
				self:Minimize()
			end
		end)
	end

	if options.Maximizable ~= false then
		makeButton("Maximize", 2, function(icon, color)
			local box = Create("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.fromOffset(1, 1),
				ZIndex = 2,
			})
			local stroke = Create("UIStroke", {
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
			Theme.Bind(stroke, { Color = color })
			stroke.Parent = box
			box.Parent = icon
		end, function()
			if self._maximized then
				self:Restore()
			else
				self:Maximize()
			end
		end)
	end

	if options.Closable ~= false then
		makeButton("Close", 3, function(icon, color)
			Layout.Polyline(icon, { Vector2.new(1, 1), Vector2.new(9, 9) }, 1.25, color)
			Layout.Polyline(icon, { Vector2.new(9, 1), Vector2.new(1, 9) }, 1.25, color)
		end, function()
			self:Close()
		end)
	end

	-- Dragging & double-click to collapse.
	local lastClick = 0
	self._maid:Give(titleBar.InputBegan:Connect(function(input)
		if not Input.IsPointerDown(input) then
			return
		end
		local pointer = Input.GetPointerPosition(input)
		for _, child in buttons:GetChildren() do
			if child:IsA("GuiButton") and Utility.IsPointInside(child, pointer) then
				return
			end
		end
		Context.Focus(self)

		local now = os.clock()
		if now - lastClick < 0.3 and self.Options.Minimizable ~= false then
			lastClick = 0
			if self._minimized then
				self:Restore()
			else
				self:Minimize()
			end
			return
		end
		lastClick = now

		if not self._draggable or self._maximized then
			return
		end
		local start = self.Root.Position
		Input.BeginDrag(input, {
			OnMove = function(_, delta)
				self:_setPosition(Vector2.new(start.X.Offset + delta.X, start.Y.Offset + delta.Y))
			end,
		})
	end))

	titleBar.Parent = self.Root
	self._titleBar = titleBar
end

function Window:_buildBody()
	local metrics = Layout.Metrics

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = self.Root,
	})
	self._body = body

	local pages = Create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = body,
	})
	self._pages = pages

	if self._tabStyle == "Sidebar" then
		local width = self.Options.SidebarWidth or metrics.SidebarWidth
		self._sidebarWidth = width

		local sidebar = Create("Frame", {
			Name = "Sidebar",
			BorderSizePixel = 0,
			Size = UDim2.new(0, width, 1, 0),
		})
		Theme.Bind(sidebar, { BackgroundColor3 = "Sidebar" })
		self._sidebarCorner = Layout.Corner(sidebar, "WindowRounding")
		Theme.Bind(self._sidebarCorner, {
			CornerRadius = function(t)
				return UDim.new(0, if self._statusBar then 0 else t.WindowRounding)
			end,
		})
		squareSides(sidebar, "Sidebar", { "Top", "Right" })

		local divider = Create("Frame", {
			Name = "Divider",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Parent = sidebar,
		})
		Theme.Bind(divider, { BackgroundColor3 = "Separator" })

		local list = Create("ScrollingFrame", {
			Name = "TabList",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -1, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = sidebar,
		})
		Theme.Bind(list, { ScrollBarImageColor3 = "ScrollBar" })
		Layout.Padding(list, 4, 4, 5, 5)
		Layout.List(list, Enum.FillDirection.Vertical, 1)

		sidebar.Parent = body
		self._sidebar = sidebar
		self._tabList = list
	else
		local bar = Create("Frame", {
			Name = "TabBar",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, metrics.TabHeight),
			Parent = body,
		})
		local list = Create("Frame", {
			Name = "TabList",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -1),
			Parent = bar,
		})
		Layout.Padding(list, metrics.WindowPadding, metrics.WindowPadding, 3, 0)
		Layout.List(list, Enum.FillDirection.Horizontal, 2)

		local line = Create("Frame", {
			Name = "Underline",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = bar,
		})
		Theme.Bind(line, { BackgroundColor3 = "HeaderActive" })

		self._tabBar = bar
		self._tabList = list
	end
end

function Window:_buildResizeGrip()
	local hovered = false
	local grip = Create("TextButton", {
		Name = "ResizeGrip",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 5,
		Visible = self._resizable,
		Parent = self.Root,
	})
	local triangle = Create("Frame", {
		Name = "Triangle",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 5,
		Parent = grip,
	})
	Create("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.501, 0),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = triangle,
	})
	Theme.Bind(triangle, {
		BackgroundColor3 = function(t)
			return hovered and t.ResizeGripHover or t.ResizeGrip
		end,
	})

	self._maid:Give(grip.MouseEnter:Connect(function()
		hovered = true
		Theme.Refresh(triangle, true)
	end))
	self._maid:Give(grip.MouseLeave:Connect(function()
		hovered = false
		Theme.Refresh(triangle, true)
	end))
	self._maid:Give(grip.InputBegan:Connect(function(input)
		if not Input.IsPointerDown(input) or not self._resizable or self._minimized then
			return
		end
		Context.Focus(self)
		if self._maximized then
			self._maximized = false
		end
		local start = self._size
		local scale = self:GetEffectiveScale()
		hovered = true
		Theme.Refresh(triangle, true)
		Input.BeginDrag(input, {
			OnMove = function(_, delta)
				self:_applySize(start + delta / scale)
			end,
			OnEnd = function()
				hovered = false
				Theme.Refresh(triangle, true)
			end,
		})
	end))

	self._grip = grip
end

--------------------------------------------------------------------------
-- Layout & geometry (internal)
--------------------------------------------------------------------------

function Window:_layout()
	local metrics = Layout.Metrics
	local top = metrics.TitleHeight
	if self._menuBar then
		self._menuBar.Root.Position = UDim2.fromOffset(0, top)
		top += metrics.MenuHeight
	end
	local bottom = self._statusBar and metrics.StatusHeight or 0

	self._body.Position = UDim2.fromOffset(0, top)
	self._body.Size = UDim2.new(1, 0, 1, -(top + bottom))

	local showTabs = not self._implicit
	if self._sidebar then
		self._sidebar.Visible = showTabs
		local offset = showTabs and self._sidebarWidth or 0
		self._pages.Position = UDim2.fromOffset(offset, 0)
		self._pages.Size = UDim2.new(1, -offset, 1, 0)
		-- Only the sidebar's bottom-left corner touches the window edge, and
		-- only while there is no status bar below it.
		Theme.Refresh(self._sidebarCorner)
	elseif self._tabBar then
		self._tabBar.Visible = showTabs
		local offset = showTabs and metrics.TabHeight or 0
		self._pages.Position = UDim2.fromOffset(0, offset)
		self._pages.Size = UDim2.new(1, 0, 1, -offset)
	end
end

function Window:_clampSize(size: Vector2): Vector2
	local minSize, maxSize = self._minSize, self._maxSize
	return Vector2.new(
		math.clamp(size.X, minSize.X, math.max(minSize.X, maxSize.X)),
		math.clamp(size.Y, minSize.Y, math.max(minSize.Y, maxSize.Y))
	)
end

function Window:_applySize(size: Vector2)
	self._size = self:_clampSize(size)
	if not self._minimized then
		self.Root.Size = UDim2.fromOffset(self._size.X, self._size.Y)
	else
		self.Root.Size = UDim2.fromOffset(self._size.X, Layout.Metrics.TitleHeight)
	end
end

function Window:_setPosition(position: Vector2)
	local clamped = self:_clampPosition(position)
	self.Root.Position = UDim2.fromOffset(clamped.X, clamped.Y)
end

function Window:_clampPosition(position: Vector2): Vector2
	local viewport = Context.GetViewportSize()
	local scale = self:GetEffectiveScale()
	local width = self._size.X * scale
	local titleHeight = Layout.Metrics.TitleHeight * scale
	local keep = math.min(64, width)
	return Vector2.new(
		math.floor(math.clamp(position.X, keep - width, math.max(keep - width, viewport.X - keep))),
		math.floor(math.clamp(position.Y, 0, math.max(0, viewport.Y - titleHeight)))
	)
end

function Window:_clampIntoView()
	local position = self.Root.Position
	self:_setPosition(Vector2.new(position.X.Offset, position.Y.Offset))
end

function Window:_updateScale()
	local viewport = Context.GetViewportSize()
	if self._autoScale then
		local fitX = (viewport.X - EDGE_MARGIN * 2) / self._size.X
		local fitY = (viewport.Y - EDGE_MARGIN * 2) / self._size.Y
		self._fitScale = math.clamp(math.min(1, fitX, fitY), 0.5, 1)
	else
		self._fitScale = 1
	end
	self._uiScale.Scale = self:GetEffectiveScale()
end

function Window:_applyMaximized()
	local viewport = Context.GetViewportSize()
	local scale = self:GetEffectiveScale()
	local size = (viewport - Vector2.new(EDGE_MARGIN * 2, EDGE_MARGIN * 2)) / scale
	self._size = Vector2.new(math.max(size.X, self._minSize.X), math.max(size.Y, self._minSize.Y))
	self.Root.Size = UDim2.fromOffset(self._size.X, self._size.Y)
	self.Root.Position = UDim2.fromOffset(EDGE_MARGIN, EDGE_MARGIN)
end

function Window:_setFocused(focused: boolean)
	if self._focused == focused then
		return
	end
	self._focused = focused
	Theme.Refresh(self._titleBar, true)
	for _, filler in self._titleFillers do
		Theme.Refresh(filler, true)
	end
	if self._stroke then
		Theme.Refresh(self._stroke, true)
	end
	self.FocusChanged:Fire(focused)
end

function Window:_setChromeVisible(visible: boolean)
	self._body.Visible = visible
	self._grip.Visible = visible and self._resizable
	if self._menuBar then
		self._menuBar.Root.Visible = visible
	end
	if self._statusBar then
		self._statusBar.Visible = visible
	end
end

--------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------

--- Adds a tab. Options: Name, Columns (default 1), Visible, Selected.
function Window:AddTab(options: any): any
	if self._implicit then
		Utility.Error("AddTab cannot be used after Window:AddGroup() created an implicit tab", 2)
	end
	local parsed = Utility.Options(options, "AddTab")
	self._tabOrder += 1
	local tab = Tab.new(self, parsed, self._tabOrder)
	table.insert(self.Tabs, tab)
	if not self.SelectedTab or parsed.Selected then
		self:SelectTab(tab)
	end
	return tab
end

--- Adds a group directly to a tab-less window. The first call creates an
--- implicit, hidden tab so small tool windows don't need tabs at all.
function Window:AddGroup(options: any): any
	if not self._implicit then
		if #self.Tabs > 0 then
			Utility.Error("Window:AddGroup() is only for tab-less windows; use tab:AddGroup()", 2)
		end
		local parsed = Utility.Options(self.Options.ImplicitTab, "ImplicitTab")
		parsed.Name = parsed.Name or "Main"
		self._tabOrder += 1
		local tab = Tab.new(self, parsed, self._tabOrder)
		table.insert(self.Tabs, tab)
		self._implicit = tab
		self:SelectTab(tab)
		self:_layout()
	end
	return self._implicit:AddGroup(options)
end

function Window:SelectTab(tabOrName: any)
	local tab = tabOrName
	if type(tabOrName) == "string" then
		tab = self:GetTab(tabOrName)
	end
	if not tab or not table.find(self.Tabs, tab) then
		Utility.Warn(`SelectTab: unknown tab {tostring(tabOrName)}`)
		return
	end
	if self.SelectedTab == tab then
		return
	end
	local previous = self.SelectedTab
	self.SelectedTab = tab
	if previous then
		previous:_setSelected(false)
	end
	tab:_setSelected(true)
	Context.ClosePopups()
	self.TabChanged:Fire(tab, previous)
end

function Window:GetTab(name: string): any
	for _, tab in self.Tabs do
		if tab.Name == name or tab.Text == name then
			return tab
		end
	end
	return nil
end

function Window:_selectFirstVisible(except: any?)
	for _, tab in self.Tabs do
		if tab ~= except and tab:IsVisible() then
			self:SelectTab(tab)
			return
		end
	end
end

function Window:_forgetTab(tab: any)
	local index = table.find(self.Tabs, tab)
	if index then
		table.remove(self.Tabs, index)
	end
	if self.SelectedTab == tab then
		self.SelectedTab = nil
		if not self._destroyed then
			self:_selectFirstVisible(tab)
		end
	end
	if self._implicit == tab then
		self._implicit = nil
	end
end

--------------------------------------------------------------------------
-- Menu bar & status bar
--------------------------------------------------------------------------

--- Adds a menu to the window's menu bar (created on first use).
--- `items` uses the context-menu item format.
function Window:AddMenu(name: string, items: { any }): any
	if not self._menuBar then
		local MenuBar = require(Components.MenuBar) :: any
		self._menuBar = MenuBar.new(self)
		self._menuBar.Root.Parent = self.Root
		self:_layout()
	end
	return self._menuBar:AddMenu(name, items)
end

--- Sets the status bar text (left, and optionally right-aligned). The status
--- bar is created on first use.
function Window:SetStatus(left: string?, right: string?)
	local metrics = Layout.Metrics
	if not self._statusBar then
		local bar = Create("Frame", {
			Name = "StatusBar",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, metrics.StatusHeight),
			ZIndex = 2,
		})
		Theme.Bind(bar, { BackgroundColor3 = "StatusBar" })
		Layout.Corner(bar, "WindowRounding")
		squareSides(bar, "StatusBar", { "Top" })

		local line = Create("Frame", {
			Name = "Divider",
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 2,
			Parent = bar,
		})
		Theme.Bind(line, { BackgroundColor3 = "Separator" })

		self._statusLeft = Layout.Text(bar, {
			Name = "Left",
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0.6, -8, 1, 0),
			ZIndex = 2,
		}, "SecondaryText")
		self._statusRight = Layout.Text(bar, {
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -18, 0, 0),
			Size = UDim2.new(0.4, -18, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
		}, "SecondaryText")

		bar.Parent = self.Root
		self._statusBar = bar
		self:_layout()
	end
	if left ~= nil then
		self._statusLeft.Text = left
	end
	if right ~= nil then
		self._statusRight.Text = right
	end
end

--------------------------------------------------------------------------
-- Visibility, focus & geometry (public)
--------------------------------------------------------------------------

function Window:SetVisible(visible: boolean)
	visible = visible and true or false
	if self._visible == visible then
		return
	end
	self._visible = visible
	self.Root.Visible = visible
	if visible then
		Context.Focus(self)
		-- Subtle appearance: settle from 97% scale.
		local target = self:GetEffectiveScale()
		self._uiScale.Scale = target * 0.97
		Animation.Tween(self._uiScale, { Scale = target }, Animation.Durations.Normal)
	else
		Context.ClosePopups()
		local Tooltip = require(Components.Tooltip) :: any
		Tooltip.Hide()
		if self._focused then
			self:_setFocused(false)
			Context.FocusedWindow = nil
		end
	end
	self.VisibilityChanged:Fire(visible)
end

function Window:IsVisible(): boolean
	return self._visible and not self._destroyed
end

function Window:Toggle()
	self:SetVisible(not self._visible)
end

--- Hides the window (or destroys it with `DestroyOnClose = true`) and fires
--- `Closed`.
function Window:Close()
	Utility.SafeCall(self._onClose, self)
	self.Closed:Fire()
	if self._destroyOnClose then
		self:Destroy()
	else
		self:SetVisible(false)
	end
end

function Window:Focus()
	if self._visible then
		Context.Focus(self)
	end
end

function Window:IsFocused(): boolean
	return self._focused
end

--- Collapses the window to its title bar.
function Window:Minimize()
	if self._minimized then
		return
	end
	self._minimized = true
	Context.ClosePopups()
	self:_setChromeVisible(false)
	Animation.Tween(self.Root, {
		Size = UDim2.fromOffset(self._size.X, Layout.Metrics.TitleHeight),
	}, Animation.Durations.Normal)
end

--- Expands the window to fill the screen (respecting the edge margin).
function Window:Maximize()
	if self._maximized then
		return
	end
	if self._minimized then
		self._minimized = false
		self:_setChromeVisible(true)
	end
	self._restoreRect = {
		Position = self.Root.Position,
		Size = self._size,
	}
	self._maximized = true
	self:_applyMaximized()
end

--- Undoes Minimize() and/or Maximize().
function Window:Restore()
	if self._minimized then
		self._minimized = false
		self:_setChromeVisible(true)
		Animation.Tween(self.Root, {
			Size = UDim2.fromOffset(self._size.X, self._size.Y),
		}, Animation.Durations.Normal)
		return
	end
	if self._maximized then
		self._maximized = false
		local rect = self._restoreRect
		if rect then
			self._size = rect.Size
			self.Root.Size = UDim2.fromOffset(rect.Size.X, rect.Size.Y)
			self.Root.Position = rect.Position
			self:_clampIntoView()
		end
	end
end

function Window:IsMinimized(): boolean
	return self._minimized
end

function Window:IsMaximized(): boolean
	return self._maximized
end

function Window:Center()
	local viewport = Context.GetViewportSize()
	local scale = self:GetEffectiveScale()
	local size = self._size * scale
	if self._minimized then
		size = Vector2.new(size.X, Layout.Metrics.TitleHeight * scale)
	end
	self:_setPosition((viewport - size) / 2)
end

function Window:SetTitle(title: string)
	self.Title = title
	self._titleLabel.Text = title
	self.Root.Name = "Window_" .. title
end

--- Sets the unscaled window size (UDim2 offsets or Vector2).
function Window:SetSize(size: UDim2 | Vector2)
	self._maximized = false
	self:_applySize(toVector2(size, self._size))
	self:_updateScale()
end

function Window:GetSize(): Vector2
	return self._size
end

function Window:SetPosition(position: UDim2 | Vector2)
	self:_setPosition(toVector2(position, Vector2.zero))
end

function Window:GetPosition(): Vector2
	local position = self.Root.Position
	return Vector2.new(position.X.Offset, position.Y.Offset)
end

function Window:SetMinSize(size: Vector2)
	self._minSize = size
	self:_applySize(self._size)
end

function Window:SetMaxSize(size: Vector2)
	self._maxSize = size
	self:_applySize(self._size)
end

function Window:SetResizable(resizable: boolean)
	self._resizable = resizable and true or false
	self._grip.Visible = self._resizable and not self._minimized
end

function Window:SetDraggable(draggable: boolean)
	self._draggable = draggable and true or false
end

--- Sets this window's scale multiplier (combined with the global scale and
--- auto-fit scale).
function Window:SetScale(scale: number)
	self._userScale = math.max(0.25, scale)
	self:_updateScale()
	self:_clampIntoView()
end

function Window:GetScale(): number
	return self._userScale
end

--- The scale actually applied: user × global × auto-fit.
function Window:GetEffectiveScale(): number
	return self._userScale * Context.GlobalScale * self._fitScale
end

--- Binds a key that toggles the window's visibility (nil to remove).
function Window:SetToggleKey(key: any)
	if self._toggleKeyName then
		Input.UnbindKey(self._toggleKeyName, self._toggleTarget)
	end
	local name = Utility.KeyName(key)
	self._toggleKeyName = name ~= "None" and name or nil
	if self._toggleKeyName then
		self._toggleTarget = self._toggleTarget
			or {
				_keyDown = function()
					if not Input.IsCapturing() then
						self:Toggle()
					end
				end,
				_keyUp = function() end,
			}
		Input.BindKey(self._toggleKeyName, self._toggleTarget)
	end
end

--------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------

--- Returns every saveable value as plain, JSON-safe data.
function Window:GetConfig(): any
	return self.Config:Serialize()
end

--- Applies data from GetConfig(). Returns the number of values applied.
function Window:LoadConfig(data: any): number
	return self.Config:Load(data)
end

function Window:ExportConfig(): string
	return self.Config:Export()
end

function Window:ImportConfig(json: string): number
	return self.Config:Import(json)
end

function Window:ResetConfig()
	self.Config:Reset()
end

--- Returns the element registered under `flag`.
function Window:GetFlag(flag: string): any
	return self.Config.Flags[flag]
end

--- Calls `callback(element)` for every element in the window.
function Window:ForEachElement(callback: (any) -> ())
	local function visit(container)
		for _, item in container._elements do
			if item._elements then
				visit(item)
			else
				callback(item)
			end
		end
	end
	for _, tab in self.Tabs do
		for _, group in tab.Groups do
			visit(group)
		end
	end
end

--- Pulls values from every element's `Bind` table (after you changed the
--- bound tables from code).
function Window:Sync()
	self:ForEachElement(function(element)
		element:Sync()
	end)
end

--------------------------------------------------------------------------
-- Misc
--------------------------------------------------------------------------

--- Shortcut for Velumi:Notify(options).
function Window:Notify(options: any): any
	local Notification = require(Components.Notification) :: any
	return Notification.new(options)
end

function Window:IsDestroyed(): boolean
	return self._destroyed
end

--- Destroys the window and everything it owns: tabs, groups, elements,
--- popups, keybinds, tweens, theme bindings, signals and connections.
function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	Context.ClosePopups()
	local Tooltip = require(Components.Tooltip) :: any
	Tooltip.Hide()

	for index = #self.Tabs, 1, -1 do
		self.Tabs[index]:Destroy()
	end
	if self._menuBar then
		self._menuBar:Destroy()
		self._menuBar = nil
	end
	if self._toggleKeyName then
		Input.UnbindKey(self._toggleKeyName, self._toggleTarget)
		self._toggleKeyName = nil
	end

	Animation.CancelTree(self.Root)
	Theme.UnbindTree(self.Root)
	self._maid:Clean()

	Context.UnregisterWindow(self)

	self.Destroyed:Fire()
	for _, signal in { self.Closed, self.Destroyed, self.VisibilityChanged, self.FocusChanged, self.TabChanged } do
		signal:Destroy()
	end
	self.Config:Destroy()

	Context.Release(self._generation)
end

return Window
