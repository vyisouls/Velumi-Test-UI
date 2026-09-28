--[[
	Modal
	A blocking dialog centered on screen over a dimmed backdrop. The body is
	a regular container, so any element can be placed inside it.

	    local modal = Velumi:ShowModal({
	        Title = "Rename",
	        Description = "Choose a new name for the preset.",
	        Buttons = {
	            { Name = "Cancel" },
	            { Name = "Save", Style = "Accent", Callback = function(modal)
	                print(modal:GetValues().Name)
	            end },
	        },
	        Build = function(modal)
	            modal:AddInput({ Name = "Name", Flag = "Name" })
	        end,
	    })

	Options
	  Title, Description
	  Width          pixels (default 340)
	  Buttons        array of strings or { Name, Style, Callback(modal), Close }
	                 (`Close = false` keeps the modal open after the callback)
	  Build(modal)   populate the body
	  Closable       show a close button and allow Escape (default true)
	  OnClose(result) called with the pressed button's name (or nil)

	Elements inside a modal are not part of any window configuration; use
	`modal:GetValues()` to read inputs given a `Flag`.
]]

local Animation = require(script.Parent.Parent.Core.Animation)
local Container = require(script.Parent.Parent.Core.Container)
local Context = require(script.Parent.Parent.Core.Context)
local Input = require(script.Parent.Parent.Core.Input)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Modal = setmetatable({}, { __index = Container })
Modal.__index = Modal
Modal.Kind = "Modal"

function Modal.new(options: { [string]: any })
	options = options or {}
	local generation = Context.Retain()
	local metrics = Layout.Metrics

	local self = setmetatable({}, Modal)
	self.Kind = "Modal"
	self.Title = options.Title or "Dialog"
	self.Closed = Signal.new()
	self._generation = generation
	self._maid = Maid.new()
	self._closed = false
	self._closable = options.Closable ~= false
	self._onClose = options.OnClose

	local width = tonumber(options.Width) or 340

	-- Backdrop (captures clicks so nothing behind the modal is usable).
	local backdrop = Create("TextButton", {
		Name = "Modal",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	Theme.Bind(backdrop, { BackgroundColor3 = "ModalDim" })
	self._maid:Give(backdrop)

	local box = Create("Frame", {
		Name = "Dialog",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Parent = backdrop,
	})
	Theme.Bind(box, { BackgroundColor3 = "Window" })
	Layout.Corner(box, "WindowRounding")
	Layout.Stroke(box, "Border")
	Layout.List(box, Enum.FillDirection.Vertical, 0)
	local scaler = Create("UIScale", { Scale = Context.GlobalScale * 0.97, Parent = box })

	-- Title bar
	local titleBar = Create("Frame", {
		Name = "TitleBar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, metrics.TitleHeight),
		LayoutOrder = 1,
		Parent = box,
	})
	Theme.Bind(titleBar, { BackgroundColor3 = "TitleBarActive" })
	Layout.Corner(titleBar, "WindowRounding")
	local filler = Create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		ZIndex = 0,
		Parent = titleBar,
	})
	Theme.Bind(filler, { BackgroundColor3 = "TitleBarActive" })
	Layout.Text(titleBar, {
		Name = "Title",
		Text = self.Title,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -40, 1, 0),
	})

	if self._closable then
		local closeHovered = false
		local close = Create("TextButton", {
			Name = "Close",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -3, 0.5, 0),
			Size = UDim2.fromOffset(metrics.TitleHeight - 5, metrics.TitleHeight - 5),
			Parent = titleBar,
		})
		Layout.Corner(close)
		Theme.Bind(close, {
			BackgroundColor3 = "Error",
			BackgroundTransparency = function()
				return closeHovered and 0 or 1
			end,
		})
		local icon = Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			Parent = close,
		})
		Layout.Polyline(icon, { Vector2.new(1, 1), Vector2.new(9, 9) }, 1.25, "Text")
		Layout.Polyline(icon, { Vector2.new(9, 1), Vector2.new(1, 9) }, 1.25, "Text")
		self._maid:Give(close.MouseEnter:Connect(function()
			closeHovered = true
			Theme.Refresh(close, true)
		end))
		self._maid:Give(close.MouseLeave:Connect(function()
			closeHovered = false
			Theme.Refresh(close, true)
		end))
		self._maid:Give(close.Activated:Connect(function()
			self:Close(nil)
		end))
	end

	-- Body
	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = box,
	})
	Layout.Padding(
		body,
		metrics.WindowPadding + 2,
		metrics.WindowPadding + 2,
		metrics.WindowPadding + 2,
		metrics.WindowPadding
	)

	Container._init(self, body, nil, "Modal", nil)

	if options.Description then
		self:AddParagraph({ Text = options.Description })
	end
	if type(options.Build) == "function" then
		local ok, err = xpcall(options.Build, debug.traceback, self)
		if not ok then
			Utility.Warn("Modal Build error:\n" .. tostring(err))
		end
	end

	-- Footer buttons
	local buttons = options.Buttons
	if buttons == nil then
		buttons = { "OK" }
	end
	if #buttons > 0 then
		local footerFrame = Create("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,
			Parent = box,
		})
		Layout.Padding(footerFrame, metrics.WindowPadding + 2, metrics.WindowPadding + 2, 2, metrics.WindowPadding + 2)

		local footer = setmetatable({}, { __index = Container })
		Container._init(footer, footerFrame, nil, "Modal/Footer", nil)
		self.Footer = footer

		for index, definition in buttons do
			local spec = if type(definition) == "string" then { Name = definition } else definition
			if index > 1 then
				footer:SameLine()
			end
			footer:AddButton({
				Name = spec.Name or "OK",
				Style = spec.Style,
				Width = spec.Width,
				Callback = function()
					Utility.SafeCall(spec.Callback, self)
					if spec.Close ~= false then
						self:Close(spec.Name)
					end
				end,
			})
		end
		if footer._lastRow then
			local list = footer._lastRow:FindFirstChildOfClass("UIListLayout")
			if list then
				list.HorizontalAlignment = Enum.HorizontalAlignment.Right
			end
		end
	end

	if self._closable then
		self._maid:Give(Input.Subscribe("Began", function(input)
			if input.KeyCode == Enum.KeyCode.Escape and not Input.IsCapturing() then
				self:Close(nil)
			end
		end))
	end

	self.Root = backdrop
	self._box = box
	self._scaler = scaler

	Context.ClosePopups()
	backdrop.Parent = Context.GetLayer("Modals")
	Animation.Tween(backdrop, {
		BackgroundTransparency = Theme.Get("ModalDimTransparency") or 0.45,
	}, Animation.Durations.Normal)
	Animation.Tween(scaler, { Scale = Context.GlobalScale }, Animation.Durations.Normal)

	return self
end

--- Values of every flagged element in the body: `{ [Flag or Name] = value }`.
function Modal:GetValues(): { [string]: any }
	local values = {}
	local function visit(container)
		for _, item in container._elements do
			if item._elements then
				visit(item)
			elseif item.Options and item.GetValue then
				local key = item.Options.Flag or item.Name
				if key and key ~= "" then
					values[key] = item:GetValue()
				end
			end
		end
	end
	visit(self)
	return values
end

--- Closes the modal. `result` is passed to OnClose and Closed.
function Modal:Close(result: string?)
	if self._closed then
		return
	end
	self._closed = true
	Context.ClosePopups()

	self:Clear()
	if self.Footer then
		self.Footer:Clear()
	end

	Utility.SafeCall(self._onClose, result)
	self.Closed:Fire(result)

	local backdrop = self.Root
	local function finish()
		Animation.CancelTree(backdrop)
		Theme.UnbindTree(backdrop)
		self._maid:Clean()
		self.Closed:Destroy()
		Context.Release(self._generation)
	end
	if backdrop.Parent and Animation.Enabled then
		self._box.Visible = false
		Animation.Tween(backdrop, { BackgroundTransparency = 1 }, Animation.Durations.Fast)
		task.delay(Animation.Durations.Fast, finish)
	else
		finish()
	end
end

Modal.Destroy = Modal.Close

function Modal:IsOpen(): boolean
	return not self._closed
end

return Modal
