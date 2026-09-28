--[[
	Dropdown
	A combo box: a framed preview of the current value with an arrow button.
	Clicking opens a popup list above everything else.

	    group:AddDropdown({
	        Name = "Mode",
	        Values = { "Default", "Advanced", "Experimental" },
	        Default = "Default",
	        Callback = function(value) end,
	    })

	Options
	  Values        array of strings
	  Default       string (or array of strings when Multi)
	  Multi         allow several selected values (see MultiDropdown)
	  AllowNone     single mode: clicking the selected value clears it
	  Searchable    show a filter box (default: on for 12+ values)
	  Placeholder   text when nothing is selected (default "None")
	  MaxVisible    rows shown before the list scrolls (default 10)
	  Name, Callback, Flag, Save, Bind, Tooltip, Disabled, ContextMenu
	Value: string? — or { string } in Multi mode (in Values order).
]]

local Animation = require(script.Parent.Parent.Core.Animation)
local Context = require(script.Parent.Parent.Core.Context)
local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Dropdown = Element.extend("Dropdown")
Dropdown.Saveable = true
Dropdown.Fill = true

local function toStrings(values: any): { string }
	local list = {}
	if type(values) == "table" then
		for _, value in values do
			table.insert(list, tostring(value))
		end
	end
	return list
end

function Dropdown:_build()
	local options = self.Options
	local metrics = Layout.Metrics

	self._multi = options.Multi == true
	self._allowNone = options.AllowNone == true
	self._values = toStrings(options.Values)
	self._selected = {} :: { [string]: boolean }
	self._hoveredArrow = false

	if self.Default == nil and not self._multi and not self._allowNone then
		self.Default = self._values[1]
	end

	local labeled = self:_labeled()

	local frame = Layout.FrameBox(labeled.Widget, function(t)
		if self._disabled then
			return t.Frame
		elseif self._popup then
			return t.FrameActive
		elseif self._hovered then
			return t.FrameHover
		end
		return t.Frame
	end)
	table.insert(self._styled, frame)

	local arrowSize = metrics.RowHeight
	local preview = Layout.Text(frame, {
		Name = "Preview",
		Position = UDim2.fromOffset(metrics.FramePaddingX, 0),
		Size = UDim2.new(1, -(arrowSize + metrics.FramePaddingX + 2), 1, 0),
	}, function(t)
		if self._disabled then
			return t.DisabledText
		end
		return self:_hasSelection() and t.Text or t.Placeholder
	end)
	table.insert(self._styled, preview)

	local arrowBox = Create("Frame", {
		Name = "Arrow",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, arrowSize, 1, 0),
		Parent = frame,
	})
	Layout.Corner(arrowBox)
	self:_bind(arrowBox, {
		BackgroundColor3 = function(t)
			if self._disabled then
				return t.Button
			elseif self._popup then
				return t.ButtonActive
			elseif self._hovered then
				return t.ButtonHover
			end
			return t.Button
		end,
	})
	local chevron = Layout.Chevron(arrowBox, "Down", arrowSize - 6, function(t)
		return self._disabled and t.DisabledText or t.Text
	end)
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.fromScale(0.5, 0.5)
	for _, segment in chevron:GetChildren() do
		table.insert(self._styled, segment)
	end

	local hitbox = Create("TextButton", {
		Name = "Hitbox",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = frame,
	})

	self._frame = frame
	self._preview = preview
	self.Root = labeled.Root
	self:_track(hitbox)

	self._maid:Give(hitbox.Activated:Connect(function()
		if self._disabled then
			return
		end
		if self._popup then
			self:Close()
		else
			self:Open()
		end
	end))
end

--------------------------------------------------------------------------
-- Value
--------------------------------------------------------------------------

function Dropdown:_hasSelection(): boolean
	return next(self._selected) ~= nil
end

function Dropdown:_orderedSelection(): { string }
	local list = {}
	for _, value in self._values do
		if self._selected[value] then
			table.insert(list, value)
		end
	end
	return list
end

function Dropdown:_apply(value: any): boolean
	local selected = {}
	if self._multi then
		if type(value) == "table" then
			for key, item in value do
				-- Accept arrays { "A", "B" } and sets { A = true }.
				if type(key) == "number" then
					selected[tostring(item)] = true
				elseif item == true then
					selected[tostring(key)] = true
				end
			end
		elseif value ~= nil then
			selected[tostring(value)] = true
		end
	elseif value ~= nil then
		selected[tostring(value)] = true
	end

	-- Drop anything that is not an available value.
	for key in selected do
		if not table.find(self._values, key) then
			selected[key] = nil
		end
	end

	-- A single dropdown without AllowNone always keeps a valid selection:
	-- keep the current value if it still exists, else pick the first value.
	if not self._multi and not self._allowNone and next(selected) == nil and #self._values > 0 then
		local current = self.Value
		if current ~= nil and table.find(self._values, current) then
			selected[current] = true
		else
			selected[self._values[1]] = true
		end
	end

	local previous = self.Value
	self._selected = selected

	local changed
	if self._multi then
		local ordered = self:_orderedSelection()
		changed = type(previous) ~= "table" or #previous ~= #ordered
		if not changed then
			for index, item in ordered do
				if previous[index] ~= item then
					changed = true
					break
				end
			end
		end
		self.Value = ordered
	else
		local single = next(selected)
		changed = previous ~= single
		self.Value = single
	end

	self:_updatePreview()
	self:_refreshItems()
	return changed
end

function Dropdown:_updatePreview()
	local text
	if self._multi then
		local ordered = self:_orderedSelection()
		text = #ordered > 0 and table.concat(ordered, ", ") or nil
	else
		text = self.Value
	end
	self._preview.Text = text or (self.Options.Placeholder or "None")
	Theme.Refresh(self._preview)
end

function Dropdown:GetValue(): any
	if self._multi then
		return table.clone(self.Value or {})
	end
	return self.Value
end

function Dropdown:_callbackArgs(): ...any
	return self:GetValue()
end

function Dropdown:_serialize(): any
	return self:GetValue()
end

function Dropdown:_deserialize(data: any)
	self:SetValue(data)
end

--- Selects or deselects a value from user interaction.
function Dropdown:_choose(value: string)
	if self._multi then
		local nextSelection = table.clone(self._selected)
		nextSelection[value] = not nextSelection[value] or nil
		self:SetValue(nextSelection)
	else
		if self.Value == value then
			if self._allowNone then
				self:SetValue(nil)
			end
		else
			self:SetValue(value)
		end
		self:Close()
	end
end

--- True if `value` is currently selected.
function Dropdown:IsSelected(value: string): boolean
	return self._selected[value] == true
end

--- Replaces the list of values. Selected values that no longer exist are
--- dropped (firing Changed if the selection changed).
function Dropdown:SetValues(values: { any })
	self._values = toStrings(values)
	local current = self._multi and self._selected or self.Value
	if not self._multi and current == nil and not self._allowNone then
		current = self._values[1]
	end
	local before = self:GetValue()
	self:_apply(current)
	local after = self:GetValue()
	local changed
	if self._multi then
		changed = #before ~= #after
	else
		changed = before ~= after
	end
	if changed then
		self:_emit()
	end
	if self._popup then
		self:_rebuildItems()
	end
end

function Dropdown:GetValues(): { string }
	return table.clone(self._values)
end

function Dropdown:AddValue(value: any)
	local text = tostring(value)
	if table.find(self._values, text) then
		return
	end
	local values = table.clone(self._values)
	table.insert(values, text)
	self:SetValues(values)
end

function Dropdown:RemoveValue(value: any)
	local values = table.clone(self._values)
	local index = table.find(values, tostring(value))
	if index then
		table.remove(values, index)
		self:SetValues(values)
	end
end

--------------------------------------------------------------------------
-- Popup
--------------------------------------------------------------------------

function Dropdown:IsOpen(): boolean
	return self._popup ~= nil
end

function Dropdown:Open()
	if self._popup or self._disabled or not Context.IsAlive() then
		return
	end
	local metrics = Layout.Metrics
	local options = self.Options
	local maid = Maid.new()
	local scale = self:_scale()
	local width = math.max(80, self._frame.AbsoluteSize.X / scale)
	local itemHeight = metrics.PopupItemHeight
	local maxVisible = options.MaxVisible or metrics.MaxPopupItems
	local searchable = options.Searchable
	if searchable == nil then
		searchable = #self._values >= 12
	end

	local frame = Create("Frame", {
		Name = "DropdownPopup",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(width, 0),
	})
	Theme.Bind(frame, { BackgroundColor3 = "Popup" })
	Layout.Corner(frame)
	Layout.Stroke(frame, "Border")
	Create("UIScale", { Scale = scale, Parent = frame })
	maid:Give(frame)

	local top = 3
	if searchable then
		local search = Create("TextBox", {
			Name = "Search",
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			PlaceholderText = "Filter...",
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 0, metrics.RowHeight),
			Parent = frame,
		})
		Theme.Bind(search, {
			BackgroundColor3 = "Frame",
			TextColor3 = "Text",
			PlaceholderColor3 = "Placeholder",
			FontFace = "Font",
			TextSize = "TextSize",
		})
		Layout.Corner(search)
		Layout.Padding(search, metrics.FramePaddingX, metrics.FramePaddingX, 0, 0)
		maid:Give(search:GetPropertyChangedSignal("Text"):Connect(function()
			self._filter = string.lower(search.Text)
			self:_rebuildItems()
		end))
		top += metrics.RowHeight + 3
	end

	local list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -(top + 3)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = metrics.ScrollBarThickness,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = frame,
	})
	Theme.Bind(list, { ScrollBarImageColor3 = "ScrollBar" })
	Layout.Padding(list, 3, 3, 0, 0)
	Layout.List(list, Enum.FillDirection.Vertical, 0)

	self._filter = ""
	self._list = list
	self._items = {}
	self._popupMaid = maid

	local visibleRows = math.clamp(#self._values, 1, maxVisible)
	local height = top + visibleRows * itemHeight + 3
	self._popupHeight = height

	local popup
	popup = {
		Frame = frame,
		Anchor = self._frame,
		Close = function()
			self:_teardownPopup()
		end,
		Reposition = function()
			Context.PlaceNear(frame, self._frame, 2, Vector2.new(width, height) * scale)
		end,
	}
	self._popup = popup

	frame.Parent = Context.GetLayer("Popups")
	self:_rebuildItems()
	Context.OpenPopup(popup)

	local above = Context.PlaceNear(frame, self._frame, 2, Vector2.new(width, height) * scale)
	if above then
		frame.Size = UDim2.fromOffset(width, height)
	else
		Animation.Tween(frame, { Size = UDim2.fromOffset(width, height) }, Animation.Durations.Fast)
	end

	self:_restyle(true)

	-- Scroll the selected value into view.
	if not self._multi and self.Value then
		local index = table.find(self._values, self.Value)
		if index and index > maxVisible then
			list.CanvasPosition = Vector2.new(0, (index - maxVisible) * itemHeight)
		end
	end
end

function Dropdown:Close()
	local popup = self._popup
	if popup then
		Context.ClosePopup(popup)
		-- ClosePopup calls popup.Close, but be safe if it was never registered.
		if self._popup then
			self:_teardownPopup()
		end
	end
end

function Dropdown:_teardownPopup()
	local maid = self._popupMaid
	local popup = self._popup
	self._popup = nil
	self._popupMaid = nil
	self._items = nil
	self._list = nil
	if popup then
		Animation.CancelTree(popup.Frame)
		Theme.UnbindTree(popup.Frame)
	end
	if maid then
		maid:Clean()
	end
	if not self._destroyed then
		self:_restyle(true)
	end
end

function Dropdown:_rebuildItems()
	local list = self._list
	if not list then
		return
	end
	local metrics = Layout.Metrics
	local itemHeight = metrics.PopupItemHeight

	for _, item in self._items or {} do
		Theme.UnbindTree(item.Button)
		item.Maid:Clean()
	end
	self._items = {}

	local filter = self._filter or ""
	local order = 0
	for _, value in self._values do
		if filter ~= "" and not string.find(string.lower(value), filter, 1, true) then
			continue
		end
		order += 1

		local itemMaid = Maid.new()
		local item = { Value = value, Hovered = false, Maid = itemMaid }

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
			BackgroundColor3 = function(t)
				if item.Hovered then
					return t.HeaderHover
				end
				return t.Header
			end,
			BackgroundTransparency = function()
				if item.Hovered or self._selected[value] then
					return 0
				end
				return 1
			end,
		})

		local textOffset = metrics.FramePaddingX
		if self._multi then
			local check = Layout.CheckMark(button, 11, "CheckMark")
			check.AnchorPoint = Vector2.new(0, 0.5)
			check.Position = UDim2.new(0, 5, 0.5, 0)
			item.Check = check
			textOffset = 21
		end

		Layout.Text(button, {
			Name = "Label",
			Text = value,
			Position = UDim2.fromOffset(textOffset, 0),
			Size = UDim2.new(1, -(textOffset + 4), 1, 0),
		})

		item.Button = button
		itemMaid:Give(button)
		itemMaid:Give(button.MouseEnter:Connect(function()
			item.Hovered = true
			Theme.Refresh(button, false)
		end))
		itemMaid:Give(button.MouseLeave:Connect(function()
			item.Hovered = false
			Theme.Refresh(button, false)
		end))
		itemMaid:Give(button.Activated:Connect(function()
			self:_choose(value)
		end))

		button.Parent = list
		table.insert(self._items, item)
	end

	self:_refreshItems()
end

--- Updates selection visuals of open popup items without rebuilding.
function Dropdown:_refreshItems()
	if not self._items then
		return
	end
	for _, item in self._items do
		Theme.Refresh(item.Button, false)
		if item.Check then
			item.Check.Visible = self._selected[item.Value] == true
		end
	end
end

function Dropdown:_onDisabledChanged(disabled: boolean)
	if disabled then
		self:Close()
	end
end

function Dropdown:_onDestroy()
	self:Close()
end

return Dropdown
