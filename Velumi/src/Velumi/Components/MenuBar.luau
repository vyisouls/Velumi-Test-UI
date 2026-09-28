--[[
	MenuBar
	The strip of menus under a window's title bar, created on the first
	`Window:AddMenu(name, items)` call.

	    window:AddMenu("File", {
	        { Name = "Save Config", Shortcut = "Ctrl+S", Callback = save },
	        "-",
	        { Name = "Close", Callback = function() window:Close() end },
	    })

	While a menu is open, hovering another header switches to it.
]]

local ContextMenu = require(script.Parent.ContextMenu)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local MenuBar = {}
MenuBar.__index = MenuBar

local Menu = {}
Menu.__index = Menu

function MenuBar.new(window: any)
	local self = setmetatable({}, MenuBar)
	local metrics = Layout.Metrics

	self.Window = window
	self.Menus = {}
	self._maid = Maid.new()
	self._openMenu = nil

	local root = Create("Frame", {
		Name = "MenuBar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, metrics.MenuHeight),
		ZIndex = 2,
	})
	Theme.Bind(root, { BackgroundColor3 = "MenuBar" })

	local list = Create("Frame", {
		Name = "Menus",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -1),
		ZIndex = 2,
		Parent = root,
	})
	Layout.Padding(list, 4, 4, 1, 1)
	Layout.List(list, Enum.FillDirection.Horizontal, 0)

	local line = Create("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 2,
		Parent = root,
	})
	Theme.Bind(line, { BackgroundColor3 = "Separator" })

	self.Root = root
	self._list = list
	self._maid:Give(root)
	return self
end

function MenuBar:AddMenu(name: string, items: { any })
	local menu = setmetatable({}, Menu)
	menu.Name = name
	menu.Items = items or {}
	menu.Bar = self
	menu._hovered = false
	menu._maid = Maid.new()

	local header = Create("TextButton", {
		Name = "Menu_" .. name,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = #self.Menus + 1,
		ZIndex = 2,
	})
	Layout.Corner(header)
	Layout.Padding(header, 8, 8, 0, 0)
	Theme.Bind(header, {
		BackgroundColor3 = function(t)
			return self._openMenu == menu and t.HeaderActive or t.HeaderHover
		end,
		BackgroundTransparency = function()
			return (self._openMenu == menu or menu._hovered) and 0 or 1
		end,
	})
	Layout.Text(header, {
		Name = "Label",
		Text = name,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 2,
	})

	menu.Header = header
	menu._maid:Give(header)

	menu._maid:Give(header.MouseEnter:Connect(function()
		menu._hovered = true
		Theme.Refresh(header, true)
		if self._openMenu and self._openMenu ~= menu then
			self:_open(menu)
		end
	end))
	menu._maid:Give(header.MouseLeave:Connect(function()
		menu._hovered = false
		Theme.Refresh(header, true)
	end))
	menu._maid:Give(header.Activated:Connect(function()
		if self._openMenu == menu then
			self:_close()
		else
			self:_open(menu)
		end
	end))

	header.Parent = self._list
	table.insert(self.Menus, menu)
	return menu
end

function MenuBar:_refreshHeaders()
	for _, menu in self.Menus do
		Theme.Refresh(menu.Header, true)
	end
end

function MenuBar:_open(menu: any)
	local previous = self._openMenu
	self._openMenu = menu
	local handle
	handle = ContextMenu.Open(menu.Items, menu.Header, {
		Scale = self.Window:GetEffectiveScale(),
		Anchor = menu.Header,
		OnClose = function()
			if self._openMenu == menu and self._handle == handle then
				self._openMenu = nil
				self._handle = nil
				self:_refreshHeaders()
			end
		end,
	})
	self._handle = handle
	if previous ~= menu then
		self:_refreshHeaders()
	end
end

function MenuBar:_close()
	local handle = self._handle
	self._openMenu = nil
	self._handle = nil
	if handle then
		handle.Close()
	end
	self:_refreshHeaders()
end

function MenuBar:Destroy()
	self:_close()
	for _, menu in table.clone(self.Menus) do
		menu:Destroy()
	end
	Theme.UnbindTree(self.Root)
	self._maid:Clean()
end

--- Replaces the menu's items (takes effect the next time it opens).
function Menu:SetItems(items: { any })
	self.Items = items
end

function Menu:Destroy()
	local bar = self.Bar
	if bar._openMenu == self then
		bar:_close()
	end
	local index = table.find(bar.Menus, self)
	if index then
		table.remove(bar.Menus, index)
	end
	Theme.UnbindTree(self.Header)
	self._maid:Clean()
end

return MenuBar
