--[[
	Velumi — a compact, developer-tool styled UI library for Roblox.
	https://github.com/zqoc/Velumi · MIT License

	    local Velumi = require(ReplicatedStorage.Velumi)

	    local window = Velumi:CreateWindow({ Title = "Velumi" })
	    local main = window:AddTab({ Name = "Main" })
	    local general = main:AddGroup({ Name = "General" })

	    general:AddCheckbox({
	        Name = "Enabled",
	        Default = false,
	        Callback = function(value) print(value) end,
	    })

	Library layout
	  Core/        runtime: context, input, theme engine, windows, containers
	  Elements/    one module per control, all built on Core/Element
	  Components/  shared overlays: notifications, tooltips, modals, menus
	  Themes/      built-in theme definitions
	  Utilities/   Signal, Maid, helpers and public types
]]

local Core = script.Core
local Components = script.Components
local Utilities = script.Utilities

local Animation = require(Core.Animation)
local Container = require(Core.Container)
local Context = require(Core.Context)
local Element = require(Core.Element)
local Input = require(Core.Input)
local Layout = require(Core.Layout)
local Theme = require(Core.Theme)
local Window = require(Core.Window)

local ContextMenu = require(Components.ContextMenu)
local Modal = require(Components.Modal)
local Notification = require(Components.Notification)
local Tooltip = require(Components.Tooltip)

local Maid = require(Utilities.Maid)
local Signal = require(Utilities.Signal)
local Types = require(Utilities.Types)
local Utility = require(Utilities.Utility)

-- Re-exported types: `local w: Velumi.Window`
export type Window = Types.Window
export type WindowOptions = Types.WindowOptions
export type Tab = Types.Tab
export type TabOptions = Types.TabOptions
export type Group = Types.Group
export type GroupOptions = Types.GroupOptions
export type Section = Types.Section
export type Child = Types.Child
export type Container = Types.Container
export type Button = Types.Button
export type Checkbox = Types.Checkbox
export type Toggle = Types.Toggle
export type Slider = Types.Slider
export type Dropdown = Types.Dropdown
export type MultiDropdown = Types.MultiDropdown
export type Input = Types.Input
export type Keybind = Types.Keybind
export type ColorPicker = Types.ColorPicker
export type Label = Types.Label
export type Paragraph = Types.Paragraph
export type Separator = Types.Separator
export type ProgressBar = Types.ProgressBar
export type Plot = Types.Plot
export type ThemeDefinition = Types.ThemeDefinition
export type ConfigData = Types.ConfigData
export type MenuItem = Types.MenuItem
export type MenuItems = Types.MenuItems
export type Notification = Types.Notification
export type NotifyOptions = Types.NotifyOptions
export type Modal = Types.Modal
export type ModalOptions = Types.ModalOptions
export type Signal<T...> = Types.Signal<T...>
export type Connection = Types.Connection

local Velumi = {}

Velumi.Version = "1.0.0"

--- Pixel metrics (row height, spacing, sidebar width...). Change them with
--- Velumi:SetMetrics() before creating windows.
Velumi.Metrics = Layout.Metrics

--- Fires (themeName, palette) whenever the theme changes.
Velumi.ThemeChanged = Theme.Changed

--- Building blocks for custom elements and extensions.
Velumi.Element = Element
Velumi.Utilities = {
	Signal = Signal,
	Maid = Maid,
	Utility = Utility,
}

local openModals: { any } = {}

--------------------------------------------------------------------------
-- Windows
--------------------------------------------------------------------------

--- Creates a window. See WindowOptions for every option.
function Velumi:CreateWindow(options: Types.WindowOptions?): Types.Window
	local window = Window.new(Utility.Options(options, "CreateWindow"))
	return (window :: any) :: Types.Window
end

--- All live windows, back to front.
function Velumi:GetWindows(): { Types.Window }
	return table.clone(Context.Windows) :: any
end

--------------------------------------------------------------------------
-- Themes
--------------------------------------------------------------------------

--- Switches the active theme for every window. Accepts a registered theme
--- name ("Dark", "Light", "Midnight", "Gray", "Classic", or your own) or a
--- theme table (applied on top of Dark).
function Velumi:SetTheme(theme: string | Types.ThemeDefinition)
	Theme.Set(theme :: any)
end

--- Name of the active theme.
function Velumi:GetTheme(): string
	return Theme.Name
end

--- Registers a theme. Missing keys come from `base` (default "Dark"), and
--- derived colors (headers, grabs, title bars...) are recomputed from your
--- colors. Re-registering the active theme updates the UI immediately.
function Velumi:RegisterTheme(name: string, definition: Types.ThemeDefinition, base: string?)
	Theme.Register(name, definition :: any, base)
end

--- Sorted names of every registered theme.
function Velumi:GetThemes(): { string }
	return Theme.GetNames()
end

--- A copy of the active palette (all core, derived and style keys).
function Velumi:GetPalette(): { [string]: any }
	return table.clone(Theme.Palette)
end

--- Reads one value from the active palette ("Accent", "Frame", "TextSize"...).
function Velumi:GetThemeValue(key: string): any
	return Theme.Get(key)
end

--------------------------------------------------------------------------
-- Overlays
--------------------------------------------------------------------------

--- Shows a notification in the bottom-right corner.
function Velumi:Notify(options: Types.NotifyOptions | string): Types.Notification
	local parsed = if type(options) == "string" then { Title = options } else options
	return Notification.new(parsed :: any) :: any
end

--- Dismisses every visible notification.
function Velumi:ClearNotifications()
	Notification.CloseAll()
end

--- Shows a modal dialog. Its body is a container, so any element works in it.
function Velumi:ShowModal(options: Types.ModalOptions): Types.Modal
	local modal = Modal.new(options :: any)
	table.insert(openModals, modal)
	modal.Closed:Once(function()
		local index = table.find(openModals, modal)
		if index then
			table.remove(openModals, index)
		end
	end)
	return modal :: any
end

--- A yes/no dialog. `Callback(confirmed)` runs once with the answer.
function Velumi:Confirm(options: Types.ConfirmOptions): Types.Modal
	local answered = false
	local function answer(value: boolean)
		if not answered then
			answered = true
			Utility.SafeCall(options.Callback, value)
		end
	end
	return self:ShowModal({
		Title = options.Title or "Confirm",
		Description = options.Description,
		Buttons = {
			{ Name = options.CancelText or "Cancel" },
			{
				Name = options.ConfirmText or "Confirm",
				Style = if options.Danger then "Danger" else "Accent",
				Callback = function()
					answer(true)
				end,
			},
		},
		OnClose = function()
			answer(false)
		end,
	})
end

--- Opens a context menu at a screen position (default: the pointer).
function Velumi:ShowContextMenu(items: Types.MenuItems, position: Vector2?): Types.ContextMenuHandle?
	if not Context.IsAlive() then
		Utility.Warn("ShowContextMenu requires at least one window")
		return nil
	end
	return ContextMenu.Open(items, position or Input.GetPointerPosition(), {}) :: any
end

--- Closes every open popup (dropdown lists, color pickers, menus).
function Velumi:ClosePopups()
	Context.ClosePopups()
end

--------------------------------------------------------------------------
-- Global settings
--------------------------------------------------------------------------

--- Global UI scale multiplier applied to every window and overlay.
function Velumi:SetScale(scale: number)
	Context.SetGlobalScale(scale)
end

function Velumi:GetScale(): number
	return Context.GlobalScale
end

--- Turns all tweening on or off (off assigns properties instantly).
function Velumi:SetAnimationsEnabled(enabled: boolean)
	Animation.Enabled = enabled and true or false
	if not Animation.Enabled then
		Animation.CancelAll()
	end
end

--- Sets the instance the Velumi ScreenGui is parented to. Defaults to the
--- local player's PlayerGui. Call before creating windows (or it is moved).
function Velumi:SetParent(parent: Instance)
	Context.Parent = parent
	if Context.Host then
		Context.Host.Parent = parent
	end
end

--- DisplayOrder of the Velumi ScreenGui (default 100).
function Velumi:SetDisplayOrder(order: number)
	Context.DisplayOrder = order
	if Context.Host then
		Context.Host.DisplayOrder = order
	end
end

--- Overrides layout metrics (row height, spacing, sidebar width...).
--- Affects windows created afterwards.
function Velumi:SetMetrics(metrics: { [string]: number })
	for key, value in metrics do
		if Layout.Metrics[key] == nil then
			Utility.Warn(`Unknown metric "{key}"`)
		else
			Layout.Metrics[key] = value
		end
	end
end

--- Tooltip hover delay in seconds (default 0.45).
function Velumi:SetTooltipDelay(seconds: number)
	Tooltip.Delay = math.max(0, seconds)
end

--------------------------------------------------------------------------
-- Extensibility
--------------------------------------------------------------------------

--- Registers a custom element class (created with `Velumi.Element.extend`)
--- as `container:Add<Name>(options)`.
function Velumi:RegisterElement(name: string, class: any)
	Container.RegisterElement(name, class)
end

--------------------------------------------------------------------------
-- Teardown
--------------------------------------------------------------------------

--- Destroys every window, notification, modal and popup, and disconnects
--- every connection Velumi made. The library can be used again afterwards.
function Velumi:Destroy()
	Tooltip.Hide()
	Context.ClosePopups()
	for _, modal in table.clone(openModals) do
		modal:Close()
	end
	table.clear(openModals)
	for index = #Context.Windows, 1, -1 do
		local window = Context.Windows[index]
		if window then
			window:Destroy()
		end
	end
	Notification.CloseAll()
	Animation.CancelAll()
	Context.Shutdown()
end

return Velumi
