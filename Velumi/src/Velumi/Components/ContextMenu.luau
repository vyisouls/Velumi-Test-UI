--[[
	ContextMenu
	Compact popup menus with shortcuts, check marks, separators, disabled
	items and nested sub menus. Used by right-click menus, window menu bars
	and `Velumi:ShowContextMenu`.

	Item format
	    { Name = "Save", Shortcut = "Ctrl+S", Callback = function() end }
	    { Name = "Wireframe", Checked = true, Callback = ... }
	    { Name = "Export", Items = { ...sub menu... } }
	    { Name = "Delete", Disabled = true }
	    { Separator = true }   -- or the string "-"

	    ContextMenu.Open(items, position, { Scale = 1 })
]]

local Context = require(script.Parent.Parent.Core.Context)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Animation = require(script.Parent.Parent.Core.Animation)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local ContextMenu = {}

export type Item = {
	Name: string?,
	Callback: (() -> ())?,
	Shortcut: string?,
	Checked: boolean?,
	Disabled: boolean?,
	Items: { Item }?,
	Separator: boolean?,
}

export type OpenOptions = {
	Scale: number?,
	Level: number?,
	Anchor: GuiObject?,
	OnClose: (() -> ())?,
	MinWidth: number?,
}

local CHAR_WIDTH = 7.8 -- approximate advance of the default monospace font

local function isSeparator(item: any): boolean
	return item == "-" or (type(item) == "table" and item.Separator == true)
end

local function measureWidth(items: { any }, minWidth: number): number
	local widest = 0
	for _, item in items do
		if not isSeparator(item) and type(item) == "table" then
			local chars = #(item.Name or "") + (item.Shortcut and #item.Shortcut + 3 or 0)
			widest = math.max(widest, chars)
		end
	end
	return math.clamp(math.floor(widest * CHAR_WIDTH) + 52, minWidth, 360)
end

--- Opens a menu at a screen position (or below a GuiObject) and returns a
--- handle with `Close()`.
function ContextMenu.Open(items: { any }, position: Vector2 | GuiObject, options: OpenOptions?)
	local settings = options or {}
	if not Context.IsAlive() then
		return nil
	end

	local metrics = Layout.Metrics
	local level = settings.Level or 1
	local scale = settings.Scale or Context.GlobalScale
	local itemHeight = metrics.PopupItemHeight
	local width = measureWidth(items, settings.MinWidth or 140)
	local maid = Maid.new()
	local handle = { Level = level }

	local frame = Create("Frame", {
		Name = "ContextMenu",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Theme.Bind(frame, { BackgroundColor3 = "Popup" })
	Layout.Corner(frame)
	Layout.Stroke(frame, "Border")
	Layout.Padding(frame, 3, 3, 3, 3)
	Layout.List(frame, Enum.FillDirection.Vertical, 0)
	Create("UIScale", { Scale = scale, Parent = frame })
	maid:Give(frame)

	local height = 6
	local submenuOwner = nil

	for order, item in items do
		if isSeparator(item) then
			local separator = Create("Frame", {
				Name = "Separator",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 7),
				LayoutOrder = order,
				Parent = frame,
			})
			local line = Create("Frame", {
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.new(1, -8, 0, 1),
				Parent = separator,
			})
			Theme.Bind(line, { BackgroundColor3 = "Separator" })
			height += 7
			continue
		end
		if type(item) ~= "table" then
			continue
		end

		local disabled = item.Disabled == true
		local hasSub = type(item.Items) == "table"
		local hovered = false

		local button = Create("TextButton", {
			Name = "Item",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.new(1, 0, 0, itemHeight),
			LayoutOrder = order,
		})
		Layout.Corner(button)
		Theme.Bind(button, {
			BackgroundColor3 = "HeaderHover",
			BackgroundTransparency = function()
				return (hovered and not disabled) and 0 or 1
			end,
		})

		local textColor = function(t)
			return disabled and t.DisabledText or t.Text
		end

		if item.Checked then
			local check = Layout.CheckMark(button, 11, disabled and "DisabledText" or "CheckMark")
			check.AnchorPoint = Vector2.new(0, 0.5)
			check.Position = UDim2.new(0, 5, 0.5, 0)
		end

		Layout.Text(button, {
			Name = "Label",
			Text = item.Name or "",
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -40, 1, 0),
		}, textColor)

		if item.Shortcut then
			Layout.Text(button, {
				Name = "Shortcut",
				Text = item.Shortcut,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
			}, disabled and "DisabledText" or "SecondaryText")
		end

		if hasSub then
			local chevron = Layout.Chevron(button, "Right", 11, textColor)
			chevron.AnchorPoint = Vector2.new(1, 0.5)
			chevron.Position = UDim2.new(1, -4, 0.5, 0)
		end

		local function openSub()
			if submenuOwner == button then
				return
			end
			submenuOwner = button
			local anchorPosition = button.AbsolutePosition
			local anchorSize = button.AbsoluteSize
			local sub = ContextMenu.Open(
				item.Items :: { any },
				Vector2.new(anchorPosition.X + anchorSize.X + 4, anchorPosition.Y - 3),
				{
					Scale = scale,
					Level = level + 1,
					OnClose = function()
						if submenuOwner == button then
							submenuOwner = nil
						end
					end,
				}
			)
			-- Flip to the left if there is no room on the right.
			if sub and sub.Frame then
				local viewport = Context.GetViewportSize()
				local subWidth = sub.Frame.AbsoluteSize.X
				if anchorPosition.X + anchorSize.X + 4 + subWidth > viewport.X then
					local x = frame.AbsolutePosition.X - subWidth - 2
					sub.Frame.Position = UDim2.fromOffset(math.max(0, x), sub.Frame.Position.Y.Offset)
				end
			end
		end

		maid:Give(button.MouseEnter:Connect(function()
			hovered = true
			Theme.Refresh(button, false)
			if hasSub and not disabled then
				openSub()
			elseif submenuOwner then
				submenuOwner = nil
				Context.ClosePopups(level + 1)
			end
		end))
		maid:Give(button.MouseLeave:Connect(function()
			hovered = false
			Theme.Refresh(button, false)
		end))
		maid:Give(button.Activated:Connect(function()
			if disabled then
				return
			end
			if hasSub then
				openSub()
				return
			end
			Context.ClosePopups()
			Utility.SafeCall(item.Callback)
		end))

		button.Parent = frame
		height += itemHeight
	end

	handle.Frame = frame
	handle.Close = function()
		Context.ClosePopup(handle.Popup)
	end

	handle.Popup = Context.OpenPopup({
		Frame = frame,
		Anchor = settings.Anchor,
		Level = level,
		Close = function()
			Animation.CancelTree(frame)
			Theme.UnbindTree(frame)
			maid:Clean()
			Utility.SafeCall(settings.OnClose)
		end,
		Reposition = if typeof(position) == "Instance"
			then function()
				Context.PlaceNear(frame, position :: GuiObject, 1, Vector2.new(width, height) * scale)
			end
			else nil,
	})

	frame.Parent = Context.GetLayer("Popups")
	Context.PlaceNear(frame, position, 1, Vector2.new(width, height) * scale)
	return handle
end

--- Closes every open menu and popup.
function ContextMenu.CloseAll()
	Context.ClosePopups()
end

return ContextMenu
