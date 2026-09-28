--[[
	Input
	Centralized input handling. Velumi owns exactly three UserInputService
	connections (InputBegan / InputChanged / InputEnded) no matter how many
	windows or controls exist. Everything else subscribes to this module:

	• Drag sessions   — sliders, color pickers, window dragging and resizing
	• Key dispatch    — keybind elements and window toggle keys (O(1) lookup)
	• Key capture     — rebinding, with ContextActionService sinking keyboard
	                    input so the game doesn't react to the captured key
	• Raw listeners   — popups (outside clicks), tooltips (pointer tracking)

	Connections are reference counted: they exist only while at least one
	window, notification or modal is alive (`Retain` / `Release`).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Utility = require(script.Parent.Parent.Utilities.Utility)

local Input = {}

export type Listener = (input: InputObject, gameProcessed: boolean) -> ()

export type DragHandlers = {
	OnMove: ((position: Vector2, delta: Vector2) -> ())?,
	OnEnd: ((position: Vector2) -> ())?,
}

export type KeyTarget = {
	_keyDown: (self: any) -> (),
	_keyUp: (self: any) -> (),
}

local CAPTURE_ACTION = "VelumiKeyCapture"
local CAPTURE_PRIORITY = Enum.ContextActionPriority.High.Value + 100

local listeners: { [string]: { Listener } } = {
	Began = {},
	Changed = {},
	Ended = {},
}

local connections: { RBXScriptConnection } = {}
local retainCount = 0

local drag: {
	Input: InputObject,
	Touch: boolean,
	Start: Vector2,
	Handlers: DragHandlers,
}? = nil

local capture: ((key: string?) -> ())? = nil
local keyTargets: { [string]: { [KeyTarget]: boolean } } = {}
local heldKeys: { [string]: { KeyTarget } } = {}

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local function inputName(input: InputObject): string?
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.Unknown then
			return nil
		end
		return input.KeyCode.Name
	elseif
		inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
	then
		return inputType.Name
	elseif inputType == Enum.UserInputType.Gamepad1 and input.KeyCode ~= Enum.KeyCode.Unknown then
		return input.KeyCode.Name
	end
	return nil
end

Input.GetInputName = inputName

local function isPointerDown(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

Input.IsPointerDown = isPointerDown

local function dispatch(kind: string, input: InputObject, gameProcessed: boolean)
	local list = listeners[kind]
	if #list == 0 then
		return
	end
	for _, listener in table.clone(list) do
		local ok, err = pcall(listener, input, gameProcessed)
		if not ok then
			Utility.Warn(`Input listener error: {err}`)
		end
	end
end

--- Pointer position in Velumi's screen space (the host ScreenGui ignores
--- the GUI inset, so this matches GuiObject.AbsolutePosition).
function Input.GetPointerPosition(input: InputObject?): Vector2
	if input and input.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	return UserInputService:GetMouseLocation()
end

function Input.IsTyping(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

function Input.IsKeyDown(keyCode: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(keyCode)
end

function Input.IsCtrlDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

function Input.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

--------------------------------------------------------------------------
-- Capture
--------------------------------------------------------------------------

local function finishCapture(key: string?)
	local callback = capture
	if not callback then
		return
	end
	capture = nil
	-- Unbind on the next resumption so the CAS sink still swallows this press.
	task.defer(function()
		if capture == nil then
			ContextActionService:UnbindAction(CAPTURE_ACTION)
		end
	end)
	callback(key)
end

--- Captures the next key or mouse button (MB2/MB3). The callback receives
--- the key name, "None" when Backspace/Delete is pressed, or nil when the
--- capture was cancelled (Escape, a left click, or another capture starting).
function Input.CaptureKey(callback: (key: string?) -> ())
	if capture then
		finishCapture(nil)
	end
	capture = callback
	ContextActionService:BindActionAtPriority(CAPTURE_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, CAPTURE_PRIORITY, Enum.UserInputType.Keyboard)
end

function Input.CancelCapture()
	finishCapture(nil)
end

function Input.IsCapturing(): boolean
	return capture ~= nil
end

--------------------------------------------------------------------------
-- Key dispatch
--------------------------------------------------------------------------

--- Registers an object to receive `_keyDown` / `_keyUp` for a key name.
function Input.BindKey(name: string, target: KeyTarget)
	if name == "None" or name == "" then
		return
	end
	local set = keyTargets[name]
	if not set then
		set = {}
		keyTargets[name] = set
	end
	set[target] = true
end

function Input.UnbindKey(name: string, target: KeyTarget)
	local set = keyTargets[name]
	if set then
		set[target] = nil
		if next(set) == nil then
			keyTargets[name] = nil
		end
	end
	local held = heldKeys[name]
	if held then
		local index = table.find(held, target)
		if index then
			table.remove(held, index)
		end
	end
end

--------------------------------------------------------------------------
-- Drag sessions
--------------------------------------------------------------------------

--- Starts tracking a pointer drag from `input` (MouseButton1 or Touch).
--- `OnMove(position, deltaFromStart)` runs on every pointer move and
--- `OnEnd(position)` when the button / finger is released.
function Input.BeginDrag(input: InputObject, handlers: DragHandlers)
	if drag then
		Input.EndDrag()
	end
	local position = Input.GetPointerPosition(input)
	drag = {
		Input = input,
		Touch = input.UserInputType == Enum.UserInputType.Touch,
		Start = position,
		Handlers = handlers,
	}
	return {
		Cancel = function()
			if drag and drag.Handlers == handlers then
				drag = nil
			end
		end,
	}
end

function Input.EndDrag()
	local session = drag
	if not session then
		return
	end
	drag = nil
	if session.Handlers.OnEnd then
		local ok, err = pcall(session.Handlers.OnEnd, Input.GetPointerPosition(session.Input))
		if not ok then
			Utility.Warn(`Drag end error: {err}`)
		end
	end
end

function Input.IsDragging(): boolean
	return drag ~= nil
end

--------------------------------------------------------------------------
-- Raw listeners
--------------------------------------------------------------------------

--- Subscribes to "Began", "Changed" or "Ended". Returns an unsubscribe
--- function (Maid-compatible).
function Input.Subscribe(kind: "Began" | "Changed" | "Ended", listener: Listener): () -> ()
	local list = listeners[kind]
	assert(list, `Unknown input event "{kind}"`)
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

--------------------------------------------------------------------------
-- Core handlers
--------------------------------------------------------------------------

local function onBegan(input: InputObject, gameProcessed: boolean)
	local name = inputName(input)

	if capture then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				finishCapture(nil)
			elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				finishCapture("None")
			elseif name then
				finishCapture(name)
			end
			return
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
		then
			finishCapture(name)
			return
		elseif isPointerDown(input) then
			finishCapture(nil)
		end
	end

	dispatch("Began", input, gameProcessed)

	if name and not Input.IsTyping() then
		local set = keyTargets[name]
		if set then
			local held = heldKeys[name] or {}
			heldKeys[name] = held
			for target in table.clone(set) do
				table.insert(held, target)
				local ok, err = pcall(target._keyDown, target)
				if not ok then
					Utility.Warn(`Keybind error: {err}`)
				end
			end
		end
	end
end

local function onChanged(input: InputObject, gameProcessed: boolean)
	local session = drag
	if session then
		local matches
		if session.Touch then
			matches = input == session.Input
		else
			matches = input.UserInputType == Enum.UserInputType.MouseMovement
		end
		if matches and session.Handlers.OnMove then
			local position = Input.GetPointerPosition(input)
			local ok, err = pcall(session.Handlers.OnMove, position, position - session.Start)
			if not ok then
				Utility.Warn(`Drag error: {err}`)
			end
		end
	end

	dispatch("Changed", input, gameProcessed)
end

local function onEnded(input: InputObject, gameProcessed: boolean)
	local session = drag
	if session then
		local matches
		if session.Touch then
			matches = input == session.Input
		else
			matches = input.UserInputType == Enum.UserInputType.MouseButton1
		end
		if matches then
			Input.EndDrag()
		end
	end

	dispatch("Ended", input, gameProcessed)

	local name = inputName(input)
	local held = name and heldKeys[name]
	if held then
		heldKeys[name :: string] = nil
		for _, target in held do
			local ok, err = pcall(target._keyUp, target)
			if not ok then
				Utility.Warn(`Keybind error: {err}`)
			end
		end
	end
end

--------------------------------------------------------------------------
-- Lifetime
--------------------------------------------------------------------------

function Input.Retain()
	retainCount += 1
	if retainCount == 1 then
		table.insert(connections, UserInputService.InputBegan:Connect(onBegan))
		table.insert(connections, UserInputService.InputChanged:Connect(onChanged))
		table.insert(connections, UserInputService.InputEnded:Connect(onEnded))
	end
end

function Input.Release()
	retainCount = math.max(0, retainCount - 1)
	if retainCount == 0 then
		Input.Shutdown()
	end
end

--- Disconnects everything. Called automatically when the last consumer is
--- released, and by Velumi:Destroy().
function Input.Shutdown()
	retainCount = 0
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if capture then
		capture = nil
	end
	ContextActionService:UnbindAction(CAPTURE_ACTION)
	drag = nil
	table.clear(keyTargets)
	table.clear(heldKeys)
	for _, list in listeners do
		table.clear(list)
	end
end

function Input.IsActive(): boolean
	return retainCount > 0
end

return Input
