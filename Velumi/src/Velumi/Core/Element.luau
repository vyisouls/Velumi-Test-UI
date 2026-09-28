--[[
	Element
	The base class for every control. It provides the shared public API so
	all elements behave consistently:

	    element:GetValue()            element:SetValue(value, silent?)
	    element:SetVisible(bool)      element:IsVisible()
	    element:SetDisabled(bool)     element:IsDisabled()
	    element:SetText(text)         element:SetTooltip(text?)
	    element:SetContextMenu(items?)
	    element:OnChanged(fn)         element.Changed   (Signal)
	    element:Reset()               element:Sync()
	    element:Destroy()

	Subclasses implement:
	    _build()             create instances, set self.Root (required)
	    _apply(value)        normalise + display a value, return true if changed
	    _serialize()         JSON-safe representation (saveable elements)
	    _deserialize(data)   inverse of _serialize
	and set `Saveable = true` on the class to take part in configuration.
]]

local Animation = require(script.Parent.Animation)
local Context = require(script.Parent.Context)
local Input = require(script.Parent.Input)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Components = script.Parent.Parent.Components

local Element = {}
Element.__index = Element
Element.Kind = "Element"
Element.Saveable = false
Element.Fill = false

--- Creates a subclass: `local Slider = Element.extend("Slider")`.
function Element.extend(kind: string)
	local class = setmetatable({}, { __index = Element })
	class.__index = class
	class.Kind = kind
	return class
end

--- Normalises the `Bind` option: `{ table, "key" }` or `{ Table = t, Key = k }`.
local function parseBinding(bind: any): (any, any)
	if type(bind) ~= "table" then
		return nil, nil
	end
	if bind.Table ~= nil then
		return bind.Table, bind.Key
	end
	return bind[1], bind[2]
end

--- Constructs an element of `class` inside `container`.
function Element.new(class: any, container: any, options: { [string]: any })
	local self = setmetatable({}, class)

	local text, id = Utility.ParseLabel(options.Name or options.Text or "")

	self.Kind = class.Kind
	self.Name = id
	self.Text = text
	self.Options = options
	self.Container = container
	self.Window = container and container._window or nil
	self.Changed = Signal.new()
	self.Value = nil
	self.Default = options.Default

	self._maid = Maid.new()
	self._styled = {}
	self._callback = options.Callback
	self._visible = options.Visible ~= false
	self._disabled = options.Disabled == true or (container ~= nil and (container._disabledDepth or 0) > 0)
	self._hovered = false
	self._pressed = false
	self._tooltip = options.Tooltip
	self._contextMenu = options.ContextMenu
	self._destroyed = false

	self._bindTable, self._bindKey = parseBinding(options.Bind)
	if self._bindTable ~= nil and self._bindKey ~= nil then
		local bound = self._bindTable[self._bindKey]
		if bound ~= nil then
			self.Default = bound
		end
	end

	self:_build()
	assert(self.Root, `{class.Kind} did not create a Root instance`)
	self._maid:Give(self.Root)

	if self._apply then
		self:_apply(self.Default)
	end

	if container then
		self._row = container:_place(self, class.Fill)
	end

	self.Root.Visible = self._visible
	if self._row then
		Layout.UpdateRowVisibility(self._row)
	end

	if self._tooltip then
		self:_attachTooltip()
	end
	if self._contextMenu then
		self:_attachContextMenu()
	end

	if class.Saveable and self.Window and options.Save ~= false then
		self.Window.Config:Register(self, options.Flag)
	end

	self:_restyle(false)
	return self
end

--------------------------------------------------------------------------
-- Styling helpers (internal)
--------------------------------------------------------------------------

--- Binds theme props and remembers the instance for state restyling.
function Element:_bind<T>(instance: T, props: { [string]: any }): T
	Theme.Bind(instance, props)
	table.insert(self._styled, instance)
	return instance
end

--- Re-evaluates all state-dependent theme bindings.
function Element:_restyle(animated: boolean?)
	for _, instance in self._styled do
		Theme.Refresh(instance, animated)
	end
end

--- Text color key for the element's label given its disabled state.
function Element:_textColor(t: any): Color3
	return self._disabled and t.DisabledText or t.Text
end

--- Tracks hover / press state on a GuiObject and restyles on change.
function Element:_track(guiObject: GuiObject)
	local maid = self._maid
	maid:Give(guiObject.MouseEnter:Connect(function()
		self._hovered = true
		self:_restyle(true)
	end))
	maid:Give(guiObject.MouseLeave:Connect(function()
		self._hovered = false
		self._pressed = false
		self:_restyle(true)
	end))
	maid:Give(guiObject.InputBegan:Connect(function(input)
		if Input.IsPointerDown(input) and not self._disabled then
			self._pressed = true
			self:_restyle(true)
		end
	end))
	maid:Give(guiObject.InputEnded:Connect(function(input)
		if Input.IsPointerDown(input) and self._pressed then
			self._pressed = false
			self:_restyle(true)
		end
	end))
end

--- Creates the element's label TextLabel (bound to disabled state).
function Element:_makeLabel(parent: Instance, props: { [string]: any }?): TextLabel
	local label = Layout.Text(parent, props, function(t)
		return self:_textColor(t)
	end)
	table.insert(self._styled, label)
	self._label = label
	return label
end

--- Builds the standard "[ widget ] Label" layout with a state-aware label.
function Element:_labeled(height: number?): Layout.Labeled
	local labeled = Layout.Labeled(self.Text, height, function(t)
		return self:_textColor(t)
	end)
	if labeled.Label then
		table.insert(self._styled, labeled.Label)
		self._label = labeled.Label
	end
	return labeled
end

--------------------------------------------------------------------------
-- Value plumbing (internal)
--------------------------------------------------------------------------

--- Arguments passed to the user callback. Subclasses may override.
function Element:_callbackArgs(): ...any
	return self.Value
end

--- Publishes the current value: config values table, bound table,
--- Changed signal and Callback.
function Element:_emit()
	if self._destroyed then
		return
	end
	if self._bindTable ~= nil and self._bindKey ~= nil then
		self._bindTable[self._bindKey] = self.Value
	end
	if self.Flag and self.Window then
		self.Window.Config:_valueChanged(self)
	end
	self.Changed:Fire(self:_callbackArgs())
	Utility.SafeCall(self._callback, self:_callbackArgs())
end

function Element:_serialize(): any
	return self.Value
end

function Element:_deserialize(data: any)
	self:SetValue(data)
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

function Element:GetValue(): any
	return self.Value
end

--- Sets the value. Fires Changed/Callback when the value actually changes,
--- unless `silent` is true.
function Element:SetValue(value: any, silent: boolean?)
	if self._destroyed or not self._apply then
		return
	end
	local changed = self:_apply(value)
	if changed and not silent then
		self:_emit()
	elseif changed and self._bindTable ~= nil and self._bindKey ~= nil then
		self._bindTable[self._bindKey] = self.Value
	end
	if changed and silent and self.Flag and self.Window then
		self.Window.Config:_valueChanged(self, true)
	end
end

--- Restores the `Default` option value.
function Element:Reset(silent: boolean?)
	self:SetValue(self.Default, silent)
end

--- Pulls the value from the table given in the `Bind` option (silently).
--- Use after changing the bound table from code.
function Element:Sync()
	if self._bindTable ~= nil and self._bindKey ~= nil then
		local value = self._bindTable[self._bindKey]
		if value ~= nil then
			self:SetValue(value, true)
		end
	end
end

function Element:OnChanged(handler: (...any) -> ())
	return self.Changed:Connect(handler)
end

function Element:SetCallback(callback: ((...any) -> ())?)
	self._callback = callback
end

function Element:SetVisible(visible: boolean)
	self._visible = visible and true or false
	if self.Root then
		self.Root.Visible = self._visible
		Layout.UpdateRowVisibility(self._row)
	end
end

function Element:IsVisible(): boolean
	return self._visible
end

function Element:SetDisabled(disabled: boolean)
	self._disabled = disabled and true or false
	self._hovered = false
	self._pressed = false
	if self._onDisabledChanged then
		self:_onDisabledChanged(self._disabled)
	end
	self:_restyle(true)
end

function Element:IsDisabled(): boolean
	return self._disabled
end

--- Changes the displayed label text.
function Element:SetText(text: string)
	self.Text = text
	if self._label then
		self._label.Text = text
	end
end

function Element:GetText(): string
	return self.Text
end

function Element:SetTooltip(text: string?)
	local hadTooltip = self._tooltip ~= nil
	self._tooltip = text
	if text and not hadTooltip then
		self:_attachTooltip()
	end
end

function Element:SetContextMenu(items: any)
	local hadMenu = self._contextMenu ~= nil
	self._contextMenu = items
	if items and not hadMenu then
		self:_attachContextMenu()
	end
end

function Element:_attachTooltip()
	if self._tooltipAttached then
		return
	end
	self._tooltipAttached = true
	local Tooltip = require(Components.Tooltip) :: any
	Tooltip.Attach(self.Root, function()
		return self._tooltip
	end, self._maid)
end

function Element:_attachContextMenu()
	if self._contextMenuAttached then
		return
	end
	self._contextMenuAttached = true
	local ContextMenu = require(Components.ContextMenu) :: any
	self._maid:Give(self.Root.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 or self._disabled then
			return
		end
		local items = self._contextMenu
		if type(items) == "function" then
			items = items(self)
		end
		if type(items) == "table" then
			ContextMenu.Open(items, Input.GetPointerPosition(input), { Scale = self:_scale() })
		end
	end))
end

--- Current UI scale of the owning window (used for popups).
function Element:_scale(): number
	if self.Window then
		return self.Window:GetEffectiveScale()
	end
	return Context.GlobalScale
end

function Element:IsDestroyed(): boolean
	return self._destroyed
end

function Element:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	if self._onDestroy then
		self:_onDestroy()
	end
	-- A destroying window drops its whole config at once.
	if self.Window and self.Flag and not self.Window._destroyed then
		self.Window.Config:Unregister(self)
	end
	if self.Container then
		self.Container:_forget(self)
	end

	if self.Root then
		Animation.CancelTree(self.Root)
		Theme.UnbindTree(self.Root)
	end

	local row = self._row
	self._maid:Clean()
	self.Changed:Destroy()
	table.clear(self._styled)

	if row and row.Parent then
		local hasItems = false
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				hasItems = true
				break
			end
		end
		if hasItems then
			Layout.UpdateRowVisibility(row)
		else
			row:Destroy()
		end
	end
end

return Element
