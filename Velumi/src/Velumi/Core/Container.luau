--[[
	Container
	The shared building API used by Groups, Sections, Child regions and Modal
	bodies. Anything that "holds controls" inherits from Container, so the
	same calls work at every level of nesting:

	    group:AddCheckbox({ Name = "Enabled" })
	    group:SameLine()
	    group:AddButton({ Name = "Reset" })

	    local child = group:BeginChild({ Name = "Log", Height = 120 })
	    group:AddLabel("appears inside the child")
	    group:EndChild()

	Layout state (same-line, indentation, disabled scopes, child stack) lives
	on the container, mirroring the "cursor" of an immediate-mode toolkit.
]]

local Element = require(script.Parent.Element)
local Layout = require(script.Parent.Layout)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Elements = script.Parent.Parent.Elements

local Container = {}
Container.__index = Container

-- Element classes, resolved once.
local Classes = {
	Button = require(Elements.Button),
	Checkbox = require(Elements.Checkbox),
	Toggle = require(Elements.Toggle),
	Slider = require(Elements.Slider),
	Dropdown = require(Elements.Dropdown),
	MultiDropdown = require(Elements.MultiDropdown),
	Input = require(Elements.Input),
	Keybind = require(Elements.Keybind),
	ColorPicker = require(Elements.ColorPicker),
	Label = require(Elements.Label),
	Paragraph = require(Elements.Paragraph),
	Separator = require(Elements.Separator),
	ProgressBar = require(Elements.ProgressBar),
	Plot = require(Elements.Plot),
}

Container.Classes = Classes

--------------------------------------------------------------------------
-- Construction (internal)
--------------------------------------------------------------------------

--- Initialises container state on `self`. `content` is the Frame rows are
--- added to; `window` may be nil (modal bodies do not save configuration).
function Container._init(self: any, content: Frame, window: any, path: string, parent: any?)
	self._content = content
	self._window = window
	self._path = path
	self._parentContainer = parent
	self._elements = {}
	self._order = 0
	self._sameLine = false
	self._lastRow = nil
	self._indent = 0
	self._disabledDepth = 0
	self._childStack = {}
	self._maid = self._maid or Maid.new()

	Layout.List(content, Enum.FillDirection.Vertical, Layout.Metrics.ItemSpacing)
end

--- The container new items go into (the innermost open child, or self).
function Container:_target(): any
	return self._childStack[#self._childStack] or self
end

--- True when this container, or any container it is nested in, is inside a
--- BeginDisabled/EndDisabled scope.
function Container:_isDisabledScope(): boolean
	local current = self
	while current do
		if (current._disabledDepth or 0) > 0 then
			return true
		end
		current = current._parentContainer
	end
	return false
end

--- Places a GuiObject into a (new or same-line) row and returns the row.
function Container:_placeInstance(root: GuiObject): Frame
	local row = self._lastRow
	if not (self._sameLine and row and row.Parent) then
		self._order += 1
		row = Layout.NewRow(self._content, self._order, self._indent)
		self._lastRow = row
	end
	self._sameLine = false

	local count = 0
	for _, child in (row :: Frame):GetChildren() do
		if child:IsA("GuiObject") then
			count += 1
		end
	end
	root.LayoutOrder = count + 1
	root.Parent = row
	return row :: Frame
end

--- Called by Element.new.
function Container:_place(element: any, _fill: boolean?): Frame
	local row = self:_placeInstance(element.Root)
	table.insert(self._elements, element)
	return row
end

--- Called when an element or nested container is destroyed.
function Container:_forget(item: any)
	if self._clearing then
		return
	end
	local index = table.find(self._elements, item)
	if index then
		table.remove(self._elements, index)
	end
end

--- Creates an element of `class` in the current target container.
function Container:_add(class: any, options: any, context: string): any
	local target = self:_target()
	local parsed = Utility.Options(options, context)
	if parsed.Disabled == nil and target:_isDisabledScope() then
		parsed.Disabled = true
	end
	return Element.new(class, target, parsed)
end

--------------------------------------------------------------------------
-- Elements
--------------------------------------------------------------------------

function Container:AddButton(options: any): any
	return self:_add(Classes.Button, options, "AddButton")
end

function Container:AddCheckbox(options: any): any
	return self:_add(Classes.Checkbox, options, "AddCheckbox")
end

function Container:AddToggle(options: any): any
	return self:_add(Classes.Toggle, options, "AddToggle")
end

function Container:AddSlider(options: any): any
	return self:_add(Classes.Slider, options, "AddSlider")
end

function Container:AddDropdown(options: any): any
	return self:_add(Classes.Dropdown, options, "AddDropdown")
end

function Container:AddMultiDropdown(options: any): any
	return self:_add(Classes.MultiDropdown, options, "AddMultiDropdown")
end

function Container:AddInput(options: any): any
	return self:_add(Classes.Input, options, "AddInput")
end

function Container:AddKeybind(options: any): any
	return self:_add(Classes.Keybind, options, "AddKeybind")
end

function Container:AddColorPicker(options: any): any
	return self:_add(Classes.ColorPicker, options, "AddColorPicker")
end

function Container:AddLabel(options: any): any
	if type(options) == "string" then
		options = { Text = options }
	end
	return self:_add(Classes.Label, options, "AddLabel")
end

function Container:AddParagraph(options: any): any
	return self:_add(Classes.Paragraph, options, "AddParagraph")
end

function Container:AddSeparator(options: any): any
	if type(options) == "string" then
		options = { Text = options }
	end
	return self:_add(Classes.Separator, options, "AddSeparator")
end

function Container:AddProgressBar(options: any): any
	return self:_add(Classes.ProgressBar, options, "AddProgressBar")
end

function Container:AddPlot(options: any): any
	return self:_add(Classes.Plot, options, "AddPlot")
end

--------------------------------------------------------------------------
-- Nested containers
--------------------------------------------------------------------------

--- Adds a collapsible section (header + content) and returns it. The
--- section is itself a container.
function Container:AddSection(options: any): any
	local Section = require(script.Parent.Section) :: any
	local target = self:_target()
	return Section.new(target, Utility.Options(options, "AddSection"))
end

--- Adds a scrollable, bordered child region and returns it without making
--- it the current target. See BeginChild for the scoped form.
function Container:AddChild(options: any): any
	local Child = require(script.Parent.Child) :: any
	local target = self:_target()
	return Child.new(target, Utility.Options(options, "AddChild"))
end

--- Opens a child region. Until EndChild(), every Add call on this container
--- goes into the child. Returns the child (also a container).
function Container:BeginChild(options: any): any
	local child = self:AddChild(options)
	table.insert(self._childStack, child)
	return child
end

--- Closes the innermost child opened with BeginChild().
function Container:EndChild()
	if #self._childStack == 0 then
		Utility.Warn("EndChild() called without a matching BeginChild()")
		return
	end
	table.remove(self._childStack)
end

--------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------

--- Places the next item on the same line as the previous one.
function Container:SameLine()
	self:_target()._sameLine = true
	return self
end

--- Adds vertical space (default: one item spacing).
function Container:AddSpacing(pixels: number?)
	local target = self:_target()
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacing"
	spacer.BackgroundTransparency = 1
	spacer.BorderSizePixel = 0
	spacer.Size = UDim2.new(0, 0, 0, pixels or Layout.Metrics.ItemSpacing)
	target._sameLine = false
	target:_placeInstance(spacer)
	return self
end

--- Indents subsequent rows (default: IndentSpacing pixels).
function Container:Indent(pixels: number?)
	local target = self:_target()
	target._indent += pixels or Layout.Metrics.IndentSpacing
	return self
end

function Container:Unindent(pixels: number?)
	local target = self:_target()
	target._indent = math.max(0, target._indent - (pixels or Layout.Metrics.IndentSpacing))
	return self
end

--- Elements created until EndDisabled() start disabled.
function Container:BeginDisabled()
	local target = self:_target()
	target._disabledDepth += 1
	return self
end

function Container:EndDisabled()
	local target = self:_target()
	target._disabledDepth = math.max(0, target._disabledDepth - 1)
	return self
end

--------------------------------------------------------------------------
-- Dynamic content
--------------------------------------------------------------------------

--- Returns the direct items (elements and nested containers) in order.
function Container:GetElements(): { any }
	return table.clone(self._elements)
end

--- Destroys every item in this container.
function Container:Clear()
	-- Items skip their own (linear) removal from _elements while clearing.
	self._clearing = true
	for index = #self._elements, 1, -1 do
		local item = self._elements[index]
		if item and item.Destroy then
			item:Destroy()
		end
	end
	self._clearing = false
	table.clear(self._elements)
	for _, child in self._content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(self._childStack)
	self._order = 0
	self._lastRow = nil
	self._sameLine = false
	self._indent = 0
	self._disabledDepth = 0
end

--- Clears the container and rebuilds it by calling `build(self)`.
--- Handy for lists that change (players, log entries, inventory...).
function Container:Rebuild(build: (container: any) -> ())
	self:Clear()
	local ok, err = xpcall(build, debug.traceback, self)
	if not ok then
		Utility.Warn("Rebuild error:\n" .. tostring(err))
	end
end

--------------------------------------------------------------------------
-- Nested container plumbing (Sections, Child regions)
--------------------------------------------------------------------------

--- Places a nested container's root into its parent like an element.
function Container._mount(self: any, parent: any, root: GuiObject)
	self.Root = root
	self.Container = parent
	self._visible = true
	self._maid:Give(root)
	self._row = parent:_placeInstance(root)
	table.insert(parent._elements, self)
end

function Container:SetVisible(visible: boolean)
	self._visible = visible and true or false
	if self.Root then
		self.Root.Visible = self._visible
		if self._row then
			Layout.UpdateRowVisibility(self._row)
		end
	end
end

function Container:IsVisible(): boolean
	return self._visible ~= false
end

--- Destroys a nested container: its items, its instances and its row.
function Container._destroyNested(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:Clear()
	if self.Container then
		self.Container:_forget(self)
	end
	local Theme = require(script.Parent.Theme) :: any
	local Animation = require(script.Parent.Animation) :: any
	if self.Root then
		Animation.CancelTree(self.Root)
		Theme.UnbindTree(self.Root)
	end
	local row = self._row
	self._maid:Clean()
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

--------------------------------------------------------------------------
-- Extensibility
--------------------------------------------------------------------------

--- Registers a custom element class (created with `Element.extend`) and
--- exposes it as `container:Add<Name>(options)` on every container.
function Container.RegisterElement(name: string, class: any)
	assert(type(name) == "string" and name ~= "", "RegisterElement expects a name")
	assert(type(class) == "table" and class._build, "RegisterElement expects an Element class with _build")
	Classes[name] = class
	local methodName = "Add" .. name
	Container[methodName] = function(self, options)
		return self:_add(class, options, methodName)
	end
end

return Container
