--[[
	Keybind
	Displays a key and lets the user rebind it: click, then press a key
	(or MB2 / MB3). Escape cancels, Backspace/Delete clears to "None".
	Right-click to change the activation mode.

	    group:AddKeybind({
	        Name = "Fly",
	        Default = Enum.KeyCode.F,
	        Mode = "Toggle",
	        Callback = function(active) print("fly", active) end,
	    })

	Modes
	  "Toggle"  each press flips the state (default)
	  "Hold"    active while the key is held
	  "Press"   fires Callback(true) on every press; state stays false
	  "Always"  always active; the key is ignored

	Options
	  Default           Enum.KeyCode, Enum.UserInputType (mouse) or key name
	  Mode              see above
	  Callback(active)  activation callback
	  ChangedCallback(key)  called when the key is rebound
	  Target            a Checkbox/Toggle to drive (Toggle/Hold modes)
	  LockMode          hide the right-click mode menu
	  Name, Flag, Save, Tooltip, Disabled
	Value: key name string ("F", "LeftShift", "MouseButton2", "None").
	Signals: `Changed(key)` on rebind, `Activated(active)` on activation.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Input = require(script.Parent.Parent.Core.Input)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Keybind = Element.extend("Keybind")
Keybind.Saveable = true
Keybind.Fill = true

local MODES = { "Toggle", "Hold", "Press", "Always" }

function Keybind:_build()
	local options = self.Options

	self._mode = table.find(MODES, options.Mode) and options.Mode or "Toggle"
	self._state = self._mode == "Always"
	self._capturing = false
	self._boundName = nil
	self.Activated = Signal.new()
	self._maid:Give(self.Activated)

	self.Default = Utility.KeyName(self.Default)

	local labeled = self:_labeled()

	local frame = Layout.FrameBox(labeled.Widget, function(t)
		if self._disabled then
			return t.Frame
		elseif self._capturing then
			return t.FrameActive
		elseif self._hovered then
			return t.FrameHover
		end
		return t.Frame
	end)
	table.insert(self._styled, frame)

	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = frame,
	})
	self:_bind(stroke, {
		Color = "Accent",
		Transparency = function()
			return self._capturing and 0.2 or 1
		end,
	})

	local text = Layout.Text(frame, {
		Name = "Key",
		TextXAlignment = Enum.TextXAlignment.Center,
	}, function(t)
		if self._disabled then
			return t.DisabledText
		elseif self._capturing then
			return t.Accent
		end
		return self._state and t.Text or t.SecondaryText
	end)
	table.insert(self._styled, text)

	local hitbox = Create("TextButton", {
		Name = "Hitbox",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = frame,
	})

	self._text = text
	self.Root = labeled.Root
	self:_track(hitbox)

	self._maid:Give(hitbox.Activated:Connect(function()
		if self._disabled then
			return
		end
		if self._capturing then
			Input.CancelCapture()
		else
			self:_beginCapture()
		end
	end))

	if not options.LockMode and not options.ContextMenu then
		self._contextMenu = function()
			local items = {}
			for _, mode in MODES do
				table.insert(items, {
					Name = mode,
					Checked = self._mode == mode,
					Callback = function()
						self:SetMode(mode)
					end,
				})
			end
			return items
		end
	end
end

function Keybind:_beginCapture()
	self._capturing = true
	self._text.Text = "..."
	self:_restyle(true)
	Input.CaptureKey(function(key)
		if self._destroyed then
			return
		end
		self._capturing = false
		if key then
			self:SetValue(key)
		end
		self:_updateText()
		self:_restyle(true)
	end)
end

function Keybind:_updateText()
	if not self._capturing then
		self._text.Text = Utility.KeyDisplayName(self.Value or "None")
	end
end

function Keybind:_apply(value: any): boolean
	local name = Utility.KeyName(value)
	local changed = self.Value ~= name
	self.Value = name

	if self._boundName then
		Input.UnbindKey(self._boundName, self)
		self._boundName = nil
	end
	if name ~= "None" then
		Input.BindKey(name, self)
		self._boundName = name
	end

	self:_updateText()
	return changed
end

-- Rebinding publishes the key to ChangedCallback (Callback is activation).
function Keybind:_emit()
	if self._destroyed then
		return
	end
	if self.Flag and self.Window then
		self.Window.Config:_valueChanged(self)
	end
	self.Changed:Fire(self.Value)
	Utility.SafeCall(self.Options.ChangedCallback, self.Value)
end

function Keybind:_setState(state: boolean, fire: boolean)
	local changed = self._state ~= state
	self._state = state
	if changed then
		Theme.Refresh(self._text, true)
	end
	local target = self.Options.Target
	if target and type(target.SetValue) == "function" and changed then
		target:SetValue(state)
	end
	if fire then
		self.Activated:Fire(state)
		Utility.SafeCall(self._callback, state)
	end
end

-- Called by Input.
function Keybind:_keyDown()
	if self._disabled or self._capturing or self._destroyed then
		return
	end
	local mode = self._mode
	if mode == "Toggle" then
		local target = self.Options.Target
		local current = self._state
		if target and type(target.GetValue) == "function" then
			current = target:GetValue() == true
		end
		self:_setState(not current, true)
	elseif mode == "Hold" then
		self:_setState(true, true)
	elseif mode == "Press" then
		self.Activated:Fire(true)
		Utility.SafeCall(self._callback, true)
	end
end

function Keybind:_keyUp()
	if self._destroyed then
		return
	end
	if self._mode == "Hold" and self._state then
		self:_setState(false, true)
	end
end

function Keybind:_serialize(): any
	return {
		Key = self.Value,
		Mode = self._mode,
	}
end

function Keybind:_deserialize(data: any)
	if type(data) == "table" then
		if data.Mode then
			self:SetMode(data.Mode)
		end
		self:SetValue(data.Key)
	else
		self:SetValue(data)
	end
end

--- True while the bind is active (Toggle on, Hold held, Always).
function Keybind:GetState(): boolean
	return self._state
end

function Keybind:SetMode(mode: string)
	if not table.find(MODES, mode) then
		Utility.Warn(`Unknown keybind mode "{tostring(mode)}"`)
		return
	end
	if self._mode == mode then
		return
	end
	self._mode = mode
	self:_setState(mode == "Always", false)
	if self.Flag and self.Window then
		self.Window.Config:_valueChanged(self)
	end
end

function Keybind:GetMode(): string
	return self._mode
end

function Keybind:_onDestroy()
	if self._capturing then
		Input.CancelCapture()
	end
	if self._boundName then
		Input.UnbindKey(self._boundName, self)
		self._boundName = nil
	end
end

return Keybind
