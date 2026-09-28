--[[
	Layout
	Metrics and building blocks shared by every visual component.

	Rows
	----
	Containers stack *rows* vertically. Each row is a horizontal list, so
	`Container:SameLine()` simply places the next element into the previous
	row instead of starting a new one. Elements are either:

	  • fixed / auto-width (buttons, checkboxes, labels) — keep their size, or
	  • fill (sliders, dropdowns, inputs) — share the remaining width through
	    a UIFlexItem, exactly like widgets sharing a line in an immediate-mode
	    toolkit.

	Primitives
	----------
	`Layout.Text`, `Layout.Corner`, `Layout.Stroke`, `Layout.Padding`,
	`Layout.List` and `Layout.Polyline` create theme-bound instances so
	components never hard-code colors, fonts or rounding.
]]

local Theme = require(script.Parent.Theme)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Layout = {}

--- Pixel metrics. Change them *before* creating windows.
Layout.Metrics = {
	RowHeight = 19, -- height of a framed widget (text + frame padding)
	ItemSpacing = 4, -- vertical gap between rows
	ItemSpacingX = 8, -- horizontal gap between same-line items
	InnerSpacing = 6, -- gap between a widget and its label
	FramePaddingX = 6,
	WindowPadding = 8,
	GroupPadding = 7,
	IndentSpacing = 14,
	TitleHeight = 21,
	MenuHeight = 20,
	TabHeight = 22,
	StatusHeight = 19,
	SidebarWidth = 132,
	ItemWidth = 0.62, -- fraction of the row a labeled widget occupies
	CheckboxSize = 15,
	ScrollBarThickness = 5,
	PopupItemHeight = 20,
	MaxPopupItems = 10,
}

--------------------------------------------------------------------------
-- Primitive builders
--------------------------------------------------------------------------

--- Creates a transparent, theme-bound TextLabel.
function Layout.Text(parent: Instance?, props: { [string]: any }?, colorKey: any?): TextLabel
	local label = Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	Theme.Bind(label, {
		TextColor3 = colorKey or "Text",
		FontFace = "Font",
		TextSize = "TextSize",
	})
	label.Parent = parent
	return label
end

--- Creates a UICorner bound to the theme's rounding (or a custom key).
function Layout.Corner(parent: Instance, key: string?): UICorner
	local corner = Instance.new("UICorner")
	local roundingKey = key or "Rounding"
	Theme.Bind(corner, {
		CornerRadius = function(t)
			return UDim.new(0, t[roundingKey] or 0)
		end,
	})
	corner.Parent = parent
	return corner
end

--- Creates a 1px UIStroke bound to a theme color (default "Border").
function Layout.Stroke(parent: Instance, colorKey: any?, transparency: number?): UIStroke
	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Transparency = transparency or 0,
	})
	Theme.Bind(stroke, { Color = colorKey or "Border" })
	stroke.Parent = parent
	return stroke
end

function Layout.Padding(parent: Instance, left: number, right: number?, top: number?, bottom: number?): UIPadding
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right or left),
		PaddingTop = UDim.new(0, top or left),
		PaddingBottom = UDim.new(0, bottom or top or left),
		Parent = parent,
	})
end

function Layout.List(
	parent: Instance,
	direction: Enum.FillDirection?,
	padding: number?,
	props: { [string]: any }?
): UIListLayout
	local list = Create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 0),
	})
	if props then
		for key, value in props do
			(list :: any)[key] = value
		end
	end
	list.Parent = parent
	return list
end

--- Makes a GuiObject share the remaining width of its row.
function Layout.Fill(guiObject: GuiObject)
	Create("UIFlexItem", {
		FlexMode = Enum.UIFlexMode.Fill,
		Parent = guiObject,
	})
end

--- Draws a polyline out of thin rotated frames inside a fixed-size box.
--- `points` are in pixels relative to the box. Used for check marks,
--- chevrons and window buttons so no image assets are required.
function Layout.Polyline(parent: Instance, points: { Vector2 }, thickness: number, colorKey: any): { Frame }
	local segments = {}
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local delta = to - from
		local length = delta.Magnitude
		local center = (from + to) / 2
		local segment = Create("Frame", {
			Name = "Segment",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(length + thickness * 0.5, thickness),
			Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		})
		Theme.Bind(segment, { BackgroundColor3 = colorKey })
		segment.Parent = parent
		table.insert(segments, segment)
	end
	return segments
end

--- A small chevron icon ("Down", "Right", "Up", "Left") in a size×size box.
function Layout.Chevron(parent: Instance, direction: string, size: number, colorKey: any): Frame
	local box = Create("Frame", {
		Name = "Chevron",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	})
	local a, b = size * 0.28, size * 0.72
	local mid = size * 0.5
	local depth = size * 0.2
	local points
	if direction == "Down" then
		points = { Vector2.new(a, mid - depth), Vector2.new(mid, mid + depth), Vector2.new(b, mid - depth) }
	elseif direction == "Up" then
		points = { Vector2.new(a, mid + depth), Vector2.new(mid, mid - depth), Vector2.new(b, mid + depth) }
	elseif direction == "Left" then
		points = { Vector2.new(mid + depth, a), Vector2.new(mid - depth, mid), Vector2.new(mid + depth, b) }
	else
		points = { Vector2.new(mid - depth, a), Vector2.new(mid + depth, mid), Vector2.new(mid - depth, b) }
	end
	Layout.Polyline(box, points, 1.5, colorKey)
	box.Parent = parent
	return box
end

--- A check mark drawn inside a size×size box.
function Layout.CheckMark(parent: Instance, size: number, colorKey: any): Frame
	local box = Create("Frame", {
		Name = "CheckMark",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	})
	local s = size / 15
	Layout.Polyline(box, {
		Vector2.new(3.2 * s, 7.6 * s),
		Vector2.new(6.1 * s, 10.5 * s),
		Vector2.new(11.8 * s, 4.4 * s),
	}, math.max(1.5, 2 * s), colorKey)
	box.Parent = parent
	return box
end

--------------------------------------------------------------------------
-- Rows & labeled widgets
--------------------------------------------------------------------------

--- Creates a new horizontal row inside a container's content frame.
function Layout.NewRow(content: Instance, order: number, indent: number): Frame
	local row = Create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Layout.List(row, Enum.FillDirection.Horizontal, Layout.Metrics.ItemSpacingX, {
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	if indent > 0 then
		Layout.Padding(row, indent, 0, 0, 0)
	end
	row.Parent = content
	return row
end

--- Shows a row only while at least one of its elements is visible, so
--- hidden elements don't leave gaps.
function Layout.UpdateRowVisibility(row: Instance?)
	if not row or not row:IsA("GuiObject") then
		return
	end
	local visible = false
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			visible = true
			break
		end
	end
	row.Visible = visible
end

export type Labeled = {
	Root: Frame,
	Widget: Frame,
	Label: TextLabel?,
}

--- Builds the standard "[ widget ] Label" arrangement: the widget occupies
--- `ItemWidth` of the row and the label sits to its right. A label of ""
--- (for example from "##id") gives the widget the full width.
function Layout.Labeled(text: string, height: number?, labelColor: any?): Labeled
	local metrics = Layout.Metrics
	local rowHeight = height or metrics.RowHeight

	local root = Create("Frame", {
		Name = "Labeled",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, rowHeight),
	})
	Layout.Fill(root)

	local widget = Create("Frame", {
		Name = "Widget",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})

	local label = nil
	if text ~= "" then
		widget.Size = UDim2.new(metrics.ItemWidth, 0, 1, 0)
		label = Layout.Text(root, {
			Name = "Label",
			Text = text,
			Position = UDim2.new(metrics.ItemWidth, metrics.InnerSpacing, 0, 0),
			Size = UDim2.new(1 - metrics.ItemWidth, -metrics.InnerSpacing, 1, 0),
		}, labelColor)
	end

	return {
		Root = root,
		Widget = widget,
		Label = label,
	}
end

--- Creates a framed box (widget background) with rounding.
function Layout.FrameBox(parent: Instance?, colorSource: any?): Frame
	local frame = Create("Frame", {
		Name = "Frame",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	})
	Theme.Bind(frame, { BackgroundColor3 = colorSource or "Frame" })
	Layout.Corner(frame)
	frame.Parent = parent
	return frame
end

return Layout
