--[[
	ColorPicker
	A color swatch with its hex code. Clicking opens an editor popup with a
	saturation/value square, hue bar, optional transparency bar and
	RGB / HSV / Hex / transparency fields.

	    group:AddColorPicker({
	        Name = "Tint",
	        Default = Color3.fromRGB(76, 141, 255),
	        Transparency = 0,          -- enables transparency editing
	        Callback = function(color, transparency) end,
	    })

	Options
	  Default         Color3 (or "#RRGGBB")
	  Transparency    number 0..1 — include to enable the transparency bar
	  Name, Callback(color, transparency), Flag, Save, Bind, Tooltip,
	  Disabled, ContextMenu
	Value: Color3. Use GetTransparency() for the transparency.
	SetValue accepts a Color3, a hex string or { Color = c, Transparency = t }.
]]

local Context = require(script.Parent.Parent.Core.Context)
local Element = require(script.Parent.Parent.Core.Element)
local Input = require(script.Parent.Parent.Core.Input)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Animation = require(script.Parent.Parent.Core.Animation)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local ColorPicker = Element.extend("ColorPicker")
ColorPicker.Saveable = true
ColorPicker.Fill = true

-- Cursor colors are fixed (not themed): they must contrast with arbitrary
-- picked colors rather than with the UI palette.
local CURSOR_LIGHT = Color3.new(1, 1, 1)
local CURSOR_DARK = Color3.new(0, 0, 0)

local PADDING = 6
local BAR_WIDTH = 14
local AREA_HEIGHT = 150
local POPUP_WIDTH = 224

local function round(value: number): number
	return math.floor(value + 0.5)
end

function ColorPicker:_build()
	local options = self.Options
	local metrics = Layout.Metrics

	self._alphaEnabled = type(options.Transparency) == "number"
	self._transparency = self._alphaEnabled and math.clamp(options.Transparency, 0, 1) or 0
	self._h, self._s, self._v = 0, 0, 1

	if self.Default == nil then
		self.Default = Color3.new(1, 1, 1)
	end

	local labeled = self:_labeled()
	local widget = labeled.Widget

	local swatchSize = metrics.RowHeight
	local swatch = Create("Frame", {
		Name = "Swatch",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(swatchSize, swatchSize),
		Parent = widget,
	})
	Layout.Corner(swatch)
	Layout.Stroke(swatch, "Border")

	local frame = Layout.FrameBox(widget, function(t)
		if self._disabled then
			return t.Frame
		elseif self._popup then
			return t.FrameActive
		elseif self._hovered then
			return t.FrameHover
		end
		return t.Frame
	end)
	frame.Position = UDim2.fromOffset(swatchSize + 4, 0)
	frame.Size = UDim2.new(1, -(swatchSize + 4), 1, 0)
	table.insert(self._styled, frame)

	local hex = Layout.Text(frame, {
		Name = "Hex",
		Position = UDim2.fromOffset(metrics.FramePaddingX, 0),
		Size = UDim2.new(1, -metrics.FramePaddingX * 2, 1, 0),
	}, function(t)
		return self._disabled and t.DisabledText or t.Text
	end)
	table.insert(self._styled, hex)

	local hitbox = Create("TextButton", {
		Name = "Hitbox",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = widget,
	})

	self._swatch = swatch
	self._hex = hex
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

function ColorPicker:_parse(value: any): (Color3?, number?)
	if typeof(value) == "Color3" then
		return value, nil
	elseif type(value) == "string" then
		return Utility.FromHex(value), nil
	elseif type(value) == "table" then
		local color = value.Color
		if type(color) == "string" then
			color = Utility.FromHex(color)
		end
		return typeof(color) == "Color3" and color or nil, tonumber(value.Transparency)
	end
	return nil, nil
end

function ColorPicker:_apply(value: any): boolean
	local color, transparency = self:_parse(value)
	color = color or self.Value or Color3.new(1, 1, 1)

	local h, s, v = (color :: Color3):ToHSV()
	-- Keep the previous hue for greys/black so the picker doesn't jump.
	if s == 0 or v == 0 then
		h = self._h
	end
	if v == 0 then
		s = self._s
	end
	return self:_applyHSV(h, s, v, transparency)
end

--- Sets the color from HSV components (internal source of truth).
function ColorPicker:_applyHSV(h: number, s: number, v: number, transparency: number?): boolean
	self._h, self._s, self._v = math.clamp(h, 0, 1), math.clamp(s, 0, 1), math.clamp(v, 0, 1)
	local color = Color3.fromHSV(self._h, self._s, self._v)
	local previousTransparency = self._transparency
	if transparency and self._alphaEnabled then
		self._transparency = math.clamp(transparency, 0, 1)
	end
	local previous = self.Value
	local changed = previous == nil
		or Utility.ToHex(previous) ~= Utility.ToHex(color)
		or previousTransparency ~= self._transparency
	self.Value = color
	self:_updateVisuals()
	return changed
end

--- Like SetValue, but from HSV; fires callbacks when changed.
function ColorPicker:_setHSV(h: number, s: number, v: number, transparency: number?)
	if self:_applyHSV(h, s, v, transparency) then
		self:_emit()
	end
end

function ColorPicker:_updateVisuals()
	local color = self.Value
	self._swatch.BackgroundColor3 = color
	self._swatch.BackgroundTransparency = self._transparency
	local text = "#" .. Utility.ToHex(color)
	if self._alphaEnabled then
		text ..= string.format("  T %.2f", self._transparency)
	end
	self._hex.Text = text
	if self._popupRefresh then
		self._popupRefresh()
	end
end

function ColorPicker:_callbackArgs(): ...any
	return self.Value, self._transparency
end

function ColorPicker:_serialize(): any
	return {
		Color = Utility.ToHex(self.Value),
		Transparency = self._transparency,
	}
end

function ColorPicker:_deserialize(data: any)
	self:SetValue(data)
end

function ColorPicker:GetTransparency(): number
	return self._transparency
end

function ColorPicker:SetTransparency(transparency: number, silent: boolean?)
	if not self._alphaEnabled then
		self._alphaEnabled = true
	end
	self:SetValue({ Color = self.Value, Transparency = transparency }, silent)
end

function ColorPicker:GetHex(): string
	return "#" .. Utility.ToHex(self.Value)
end

--------------------------------------------------------------------------
-- Popup
--------------------------------------------------------------------------

function ColorPicker:IsOpen(): boolean
	return self._popup ~= nil
end

function ColorPicker:Close()
	local popup = self._popup
	if popup then
		Context.ClosePopup(popup)
		if self._popup then
			self:_teardown()
		end
	end
end

function ColorPicker:_teardown()
	local popup = self._popup
	local maid = self._popupMaid
	self._popup = nil
	self._popupMaid = nil
	self._popupRefresh = nil
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

--- Builds a small labeled numeric/text field for the popup.
local function makeField(
	parent: Instance,
	maid: any,
	x: number,
	y: number,
	width: number,
	prefix: string,
	onCommit: (string) -> ()
)
	local metrics = Layout.Metrics
	local box = Create("Frame", {
		Name = "Field" .. prefix,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, metrics.RowHeight),
		Parent = parent,
	})
	Theme.Bind(box, { BackgroundColor3 = "Frame" })
	Layout.Corner(box)

	local prefixWidth = #prefix * 8 + 6
	Layout.Text(box, {
		Name = "Prefix",
		Text = prefix,
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0, prefixWidth, 1, 0),
	}, "SecondaryText")

	local textBox = Create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(prefixWidth + 2, 0),
		Size = UDim2.new(1, -(prefixWidth + 4), 1, 0),
		Parent = box,
	})
	Theme.Bind(textBox, {
		TextColor3 = "Text",
		FontFace = "Font",
		TextSize = "TextSize",
	})
	maid:Give(textBox.FocusLost:Connect(function()
		onCommit(textBox.Text)
	end))
	return textBox
end

function ColorPicker:Open()
	if self._popup or self._disabled or not Context.IsAlive() then
		return
	end
	local metrics = Layout.Metrics
	local maid = Maid.new()
	local scale = self:_scale()
	local alpha = self._alphaEnabled
	local originalColor, originalTransparency = self.Value, self._transparency

	local barsWidth = BAR_WIDTH + PADDING + (alpha and (BAR_WIDTH + PADDING) or 0)
	local areaWidth = POPUP_WIDTH - PADDING * 2 - barsWidth
	local rowY = PADDING + AREA_HEIGHT + PADDING
	local rowStep = metrics.RowHeight + 4
	local height = rowY + 16 + 6 + rowStep * 3 + PADDING - 4

	local frame = Create("Frame", {
		Name = "ColorPickerPopup",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(POPUP_WIDTH, height),
	})
	Theme.Bind(frame, { BackgroundColor3 = "Popup" })
	Layout.Corner(frame)
	Layout.Stroke(frame, "Border")
	Create("UIScale", { Scale = scale, Parent = frame })
	maid:Give(frame)

	-- Saturation / value area ----------------------------------------------
	local area = Create("TextButton", {
		Name = "Area",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Position = UDim2.fromOffset(PADDING, PADDING),
		Size = UDim2.fromOffset(areaWidth, AREA_HEIGHT),
		Parent = frame,
	})
	local white = Create("Frame", {
		Name = "Saturation",
		BackgroundColor3 = CURSOR_LIGHT,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = area,
	})
	Create("UIGradient", {
		Transparency = NumberSequence.new(0, 1),
		Parent = white,
	})
	local black = Create("Frame", {
		Name = "Value",
		BackgroundColor3 = CURSOR_DARK,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = area,
	})
	Create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0),
		Parent = black,
	})
	local areaCursor = Create("Frame", {
		Name = "Cursor",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		ZIndex = 3,
		Parent = area,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = areaCursor })
	Create("UIStroke", { Color = CURSOR_LIGHT, Thickness = 1.5, Parent = areaCursor })

	-- Hue bar --------------------------------------------------------------
	local hueKeypoints = {}
	for index = 0, 6 do
		table.insert(hueKeypoints, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV((index / 6) % 1, 1, 1)))
	end
	local hueBar = Create("TextButton", {
		Name = "Hue",
		AutoButtonColor = false,
		BackgroundColor3 = CURSOR_LIGHT,
		BorderSizePixel = 0,
		Text = "",
		Position = UDim2.fromOffset(PADDING + areaWidth + PADDING, PADDING),
		Size = UDim2.fromOffset(BAR_WIDTH, AREA_HEIGHT),
		Parent = frame,
	})
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(hueKeypoints),
		Parent = hueBar,
	})
	local hueCursor = Create("Frame", {
		Name = "Cursor",
		BackgroundColor3 = CURSOR_LIGHT,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 2),
		ZIndex = 2,
		Parent = hueBar,
	})
	Create("UIStroke", { Color = CURSOR_DARK, Thickness = 1, Parent = hueCursor })

	-- Transparency bar -----------------------------------------------------
	local alphaBar, alphaFill, alphaCursor
	if alpha then
		alphaBar = Create("TextButton", {
			Name = "Transparency",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			Position = UDim2.fromOffset(PADDING + areaWidth + PADDING + BAR_WIDTH + PADDING, PADDING),
			Size = UDim2.fromOffset(BAR_WIDTH, AREA_HEIGHT),
			Parent = frame,
		})
		Theme.Bind(alphaBar, { BackgroundColor3 = "Frame" })
		alphaFill = Create("Frame", {
			Name = "Fill",
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = alphaBar,
		})
		Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0, 1),
			Parent = alphaFill,
		})
		alphaCursor = Create("Frame", {
			Name = "Cursor",
			BackgroundColor3 = CURSOR_LIGHT,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 4, 0, 2),
			ZIndex = 2,
			Parent = alphaBar,
		})
		Create("UIStroke", { Color = CURSOR_DARK, Thickness = 1, Parent = alphaCursor })
	end

	-- Preview: original | current -----------------------------------------
	local previewWidth = (POPUP_WIDTH - PADDING * 2) / 2
	local original = Create("TextButton", {
		Name = "Original",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		BackgroundColor3 = originalColor,
		BackgroundTransparency = originalTransparency,
		Position = UDim2.fromOffset(PADDING, rowY),
		Size = UDim2.fromOffset(previewWidth, 16),
		Parent = frame,
	})
	local current = Create("Frame", {
		Name = "Current",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PADDING + previewWidth, rowY),
		Size = UDim2.fromOffset(previewWidth, 16),
		Parent = frame,
	})
	maid:Give(original.Activated:Connect(function()
		self:SetValue({ Color = originalColor, Transparency = originalTransparency })
	end))

	-- Fields ---------------------------------------------------------------
	local fieldY = rowY + 16 + 6
	local fieldGap = 4
	local innerWidth = POPUP_WIDTH - PADDING * 2
	local third = (innerWidth - fieldGap * 2) / 3

	local function numberCommit(apply: (number) -> ())
		return function(text: string)
			local number = tonumber(text)
			if number then
				apply(number)
			else
				self._popupRefresh()
			end
		end
	end

	local rgbSetter = function(channel: string)
		return numberCommit(function(number)
			local color = self.Value
			local r, g, b = round(color.R * 255), round(color.G * 255), round(color.B * 255)
			number = math.clamp(round(number), 0, 255)
			if channel == "R" then
				r = number
			elseif channel == "G" then
				g = number
			else
				b = number
			end
			self:SetValue(Color3.fromRGB(r, g, b))
		end)
	end

	local fieldR = makeField(frame, maid, PADDING, fieldY, third, "R", rgbSetter("R"))
	local fieldG = makeField(frame, maid, PADDING + third + fieldGap, fieldY, third, "G", rgbSetter("G"))
	local fieldB = makeField(frame, maid, PADDING + (third + fieldGap) * 2, fieldY, third, "B", rgbSetter("B"))

	fieldY += rowStep
	local fieldH = makeField(
		frame,
		maid,
		PADDING,
		fieldY,
		third,
		"H",
		numberCommit(function(number)
			self:_setHSV((math.clamp(number, 0, 360) / 360) % 1, self._s, self._v)
		end)
	)
	local fieldS = makeField(
		frame,
		maid,
		PADDING + third + fieldGap,
		fieldY,
		third,
		"S",
		numberCommit(function(number)
			self:_setHSV(self._h, math.clamp(number, 0, 100) / 100, self._v)
		end)
	)
	local fieldV = makeField(
		frame,
		maid,
		PADDING + (third + fieldGap) * 2,
		fieldY,
		third,
		"V",
		numberCommit(function(number)
			self:_setHSV(self._h, self._s, math.clamp(number, 0, 100) / 100)
		end)
	)

	fieldY += rowStep
	local hexWidth = alpha and (third * 2 + fieldGap) or innerWidth
	local fieldHex = makeField(frame, maid, PADDING, fieldY, hexWidth, "Hex", function(text)
		local color = Utility.FromHex(text)
		if color then
			self:SetValue(color)
		else
			self._popupRefresh()
		end
	end)
	local fieldT
	if alpha then
		fieldT = makeField(
			frame,
			maid,
			PADDING + (third + fieldGap) * 2,
			fieldY,
			third,
			"T",
			numberCommit(function(number)
				self:SetTransparency(math.clamp(number, 0, 1))
			end)
		)
	end

	-- Refresh --------------------------------------------------------------
	local function setField(box: TextBox, text: string)
		if not box:IsFocused() then
			box.Text = text
		end
	end

	self._popupRefresh = function()
		local color = self.Value
		area.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
		areaCursor.Position = UDim2.fromScale(self._s, 1 - self._v)
		areaCursor:FindFirstChildOfClass("UIStroke").Color = self._v > 0.55 and self._s < 0.45 and CURSOR_DARK
			or CURSOR_LIGHT
		hueCursor.Position = UDim2.fromScale(0.5, self._h)
		current.BackgroundColor3 = color
		current.BackgroundTransparency = self._transparency
		if alpha then
			alphaFill.BackgroundColor3 = color
			alphaCursor.Position = UDim2.fromScale(0.5, self._transparency)
			setField(fieldT, string.format("%.2f", self._transparency))
		end
		setField(fieldR, tostring(round(color.R * 255)))
		setField(fieldG, tostring(round(color.G * 255)))
		setField(fieldB, tostring(round(color.B * 255)))
		setField(fieldH, tostring(round(self._h * 360)))
		setField(fieldS, tostring(round(self._s * 100)))
		setField(fieldV, tostring(round(self._v * 100)))
		setField(fieldHex, "#" .. Utility.ToHex(color))
	end

	-- Dragging ---------------------------------------------------------------
	local function ratio(guiObject: GuiObject, position: Vector2): Vector2
		local absPosition, absSize = guiObject.AbsolutePosition, guiObject.AbsoluteSize
		return Vector2.new(
			math.clamp((position.X - absPosition.X) / math.max(1, absSize.X), 0, 1),
			math.clamp((position.Y - absPosition.Y) / math.max(1, absSize.Y), 0, 1)
		)
	end

	local function dragOn(guiObject: GuiObject, update: (Vector2) -> ())
		maid:Give(guiObject.InputBegan:Connect(function(input)
			if not Input.IsPointerDown(input) then
				return
			end
			update(ratio(guiObject, Input.GetPointerPosition(input)))
			Input.BeginDrag(input, {
				OnMove = function(position)
					if self._popup then
						update(ratio(guiObject, position))
					end
				end,
			})
		end))
	end

	dragOn(area, function(r)
		self:_setHSV(self._h, r.X, 1 - r.Y)
	end)
	dragOn(hueBar, function(r)
		self:_setHSV(math.min(r.Y, 0.9999), self._s, self._v)
	end)
	if alphaBar then
		dragOn(alphaBar, function(r)
			self:_setHSV(self._h, self._s, self._v, r.Y)
		end)
	end

	-- Open -----------------------------------------------------------------
	local popup = {
		Frame = frame,
		Anchor = self._swatch.Parent :: GuiObject,
		Close = function()
			self:_teardown()
		end,
		Reposition = function()
			Context.PlaceNear(frame, self._swatch.Parent :: GuiObject, 2, Vector2.new(POPUP_WIDTH, height) * scale)
		end,
	}
	self._popup = popup
	self._popupMaid = maid

	frame.Parent = Context.GetLayer("Popups")
	self._popupRefresh()
	Context.OpenPopup(popup)
	popup.Reposition()
	self:_restyle(true)
end

function ColorPicker:_onDisabledChanged(disabled: boolean)
	if disabled then
		self:Close()
	end
end

function ColorPicker:_onDestroy()
	self:Close()
end

return ColorPicker
