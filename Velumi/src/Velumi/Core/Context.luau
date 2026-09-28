--[[
	Context
	Library-wide runtime state shared by every window:

	• The host ScreenGui and its layers (windows, modals, popups,
	  notifications, tooltip), created lazily and destroyed when unused.
	• The window registry, focus and z-ordering.
	• The popup stack (dropdown lists, context menus, color pickers):
	  outside clicks close popups, and popups follow their anchor.
	• Viewport size tracking for auto-scaling and clamping.

	Lifetime is reference counted with Retain / Release. When the last window,
	notification and modal are gone, the ScreenGui and every global
	connection are removed.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Input = require(script.Parent.Input)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Context = {}

Context.DisplayOrder = 100
Context.Parent = nil :: Instance?
Context.GlobalScale = 1
Context.Generation = 0 -- increments on every shutdown

Context.Host = nil :: ScreenGui?
Context.Layers = {} :: { [string]: Frame }
Context.Windows = {} :: { any } -- ordered back-to-front
Context.FocusedWindow = nil :: any

Context.ViewportChanged = Signal.new() -- (size: Vector2)
Context.ScaleChanged = Signal.new() -- (scale: number)

local LAYERS = { "Windows", "Modals", "Popups", "Notifications", "Tooltip" }

local maid = Maid.new()
local retainCount = 0

export type Popup = {
	Frame: GuiObject,
	Anchor: GuiObject?,
	Level: number?,
	Close: () -> (),
	Reposition: (() -> ())?,
}

local popups: { Popup } = {}

--------------------------------------------------------------------------
-- Host
--------------------------------------------------------------------------

local function resolveParent(): Instance
	if Context.Parent then
		return Context.Parent
	end
	if RunService:IsClient() then
		local player = Players.LocalPlayer
		if player then
			return player:WaitForChild("PlayerGui")
		end
	end
	Utility.Error("No GUI parent available. Call Velumi:SetParent(instance) before creating windows.", 3)
	return nil :: any
end

local function createHost()
	local host = Instance.new("ScreenGui")
	host.Name = "Velumi"
	host.DisplayOrder = Context.DisplayOrder
	host.IgnoreGuiInset = true
	host.ResetOnSpawn = false
	host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	for index, name in LAYERS do
		local layer = Instance.new("Frame")
		layer.Name = name
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = index
		layer.Parent = host
		Context.Layers[name] = layer
	end

	host.Parent = resolveParent()
	Context.Host = host
	maid:Give(host)

	maid:Give(host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		Context.ViewportChanged:Fire(Context.GetViewportSize())
	end))

	-- Close popups when the Roblox menu opens.
	maid:Give(GuiService.MenuOpened:Connect(function()
		Context.ClosePopups()
	end))

	-- Focus windows / dismiss popups on pointer down.
	maid:Give(Input.Subscribe("Began", function(input)
		if not Input.IsPointerDown(input) and input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		local position = Input.GetPointerPosition(input)
		Context._handleOutsideClick(position)
		if Input.IsPointerDown(input) then
			Context._focusAt(position)
		end
	end))
end

--- Registers a consumer (window, notification, modal). Creates the host and
--- global input connections on first use. Returns the current generation,
--- which should be passed back to Release().
function Context.Retain(): number
	retainCount += 1
	if retainCount == 1 then
		Input.Retain()
		createHost()
	end
	return Context.Generation
end

--- Releases a consumer. When none remain, everything is torn down.
function Context.Release(generation: number?)
	if generation and generation ~= Context.Generation then
		-- The consumer outlived a full shutdown; nothing to release.
		return
	end
	retainCount = math.max(0, retainCount - 1)
	if retainCount == 0 then
		Context.Shutdown()
	end
end

function Context.Shutdown()
	retainCount = 0
	Context.Generation += 1
	Context.ClosePopups()
	maid:Clean()
	Context.Host = nil
	table.clear(Context.Layers)
	table.clear(Context.Windows)
	Context.FocusedWindow = nil
	Input.Shutdown()
end

function Context.IsAlive(): boolean
	return retainCount > 0
end

function Context.GetLayer(name: string): Frame
	local layer = Context.Layers[name]
	assert(layer, `Velumi layer "{name}" does not exist (is the library alive?)`)
	return layer
end

function Context.GetViewportSize(): Vector2
	local host = Context.Host
	if host and host.AbsoluteSize.X > 0 then
		return host.AbsoluteSize
	end
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

function Context.SetGlobalScale(scale: number)
	Context.GlobalScale = math.max(0.25, scale)
	Context.ScaleChanged:Fire(Context.GlobalScale)
end

--------------------------------------------------------------------------
-- Windows & focus
--------------------------------------------------------------------------

local function restack()
	for index, window in Context.Windows do
		window.Root.ZIndex = index
	end
end

function Context.RegisterWindow(window: any)
	table.insert(Context.Windows, window)
	restack()
end

function Context.UnregisterWindow(window: any)
	local index = table.find(Context.Windows, window)
	if index then
		table.remove(Context.Windows, index)
		restack()
	end
	if Context.FocusedWindow == window then
		Context.FocusedWindow = nil
		-- Hand focus to the next visible window, front-most first.
		for i = #Context.Windows, 1, -1 do
			if Context.Windows[i]:IsVisible() then
				Context.Focus(Context.Windows[i])
				break
			end
		end
	end
end

--- Brings a window to the front and marks it focused.
function Context.Focus(window: any)
	local index = table.find(Context.Windows, window)
	if not index then
		return
	end
	if index ~= #Context.Windows then
		table.remove(Context.Windows, index)
		table.insert(Context.Windows, window)
		restack()
	end
	local previous = Context.FocusedWindow
	if previous == window then
		return
	end
	Context.FocusedWindow = window
	if previous and previous._setFocused then
		previous:_setFocused(false)
	end
	window:_setFocused(true)
end

function Context._focusAt(position: Vector2)
	for index = #Context.Windows, 1, -1 do
		local window = Context.Windows[index]
		if window:IsVisible() and Utility.IsPointInside(window.Root, position) then
			Context.Focus(window)
			return
		end
	end
end

--------------------------------------------------------------------------
-- Popups
--------------------------------------------------------------------------

--- Opens a popup. `Level` 1 (the default) closes every other popup first;
--- higher levels stack on top (sub menus), closing popups at or above the
--- same level.
function Context.OpenPopup(popup: Popup): Popup
	local level = popup.Level or 1
	for index = #popups, 1, -1 do
		if (popups[index].Level or 1) >= level then
			local existing = table.remove(popups, index) :: Popup
			existing.Close()
		end
	end

	table.insert(popups, popup)

	-- Follow the anchor as it moves (scrolling, window dragging).
	if popup.Anchor and popup.Reposition then
		local connection = popup.Anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(popup.Reposition)
		local originalClose = popup.Close
		popup.Close = function()
			connection:Disconnect()
			originalClose()
		end
	end

	return popup
end

--- Closes a specific popup (and any popups stacked above it).
function Context.ClosePopup(popup: Popup)
	local index = table.find(popups, popup)
	if not index then
		return
	end
	for i = #popups, index, -1 do
		local existing = table.remove(popups, i) :: Popup
		existing.Close()
	end
end

--- Closes every popup at or above `fromLevel` (default: all).
function Context.ClosePopups(fromLevel: number?)
	local level = fromLevel or 1
	for index = #popups, 1, -1 do
		local popup = popups[index]
		if (popup.Level or 1) >= level then
			table.remove(popups, index)
			popup.Close()
		end
	end
end

function Context.IsPopupOpen(popup: Popup): boolean
	return table.find(popups, popup) ~= nil
end

function Context.HasPopups(): boolean
	return #popups > 0
end

function Context._handleOutsideClick(position: Vector2)
	if #popups == 0 then
		return
	end
	for _, popup in popups do
		if popup.Frame.Parent and Utility.IsPointInside(popup.Frame, position) then
			return
		end
		if popup.Anchor and Utility.IsPointInside(popup.Anchor, position) then
			-- The anchor's own handler toggles the popup.
			return
		end
	end
	Context.ClosePopups()
end

--- Positions `frame` (in the Popups layer, AnchorPoint 0,0) below `anchor`
--- — or above it when there is no room — clamped to the screen. `anchor`
--- may be a GuiObject or a screen point. `size` is the frame's on-screen
--- size (defaults to its AbsoluteSize). Returns true when placed above.
function Context.PlaceNear(frame: GuiObject, anchor: GuiObject | Vector2, gap: number?, size: Vector2?): boolean
	local viewport = Context.GetViewportSize()
	local frameSize = size or frame.AbsoluteSize
	local spacing = gap or 2
	local above = false

	local x, y
	if typeof(anchor) == "Vector2" then
		x, y = anchor.X, anchor.Y
		if y + frameSize.Y > viewport.Y then
			y = anchor.Y - frameSize.Y
		end
	else
		local anchorPosition = anchor.AbsolutePosition
		local anchorSize = anchor.AbsoluteSize
		x = anchorPosition.X
		y = anchorPosition.Y + anchorSize.Y + spacing
		if y + frameSize.Y > viewport.Y and anchorPosition.Y - frameSize.Y - spacing >= 0 then
			y = anchorPosition.Y - frameSize.Y - spacing
			above = true
		end
	end

	x = math.clamp(x, 0, math.max(0, viewport.X - frameSize.X))
	y = math.clamp(y, 0, math.max(0, viewport.Y - frameSize.Y))
	frame.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	return above
end

return Context
