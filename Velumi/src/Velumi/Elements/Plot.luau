--[[
	Plot
	A small line graph or histogram for live debugging values (frame time,
	memory, ping...).

	    local fps = group:AddPlot({ Name = "FPS", Type = "Lines", Min = 0, Max = 120 })
	    fps:Push(workspace:GetRealPhysicsFPS())

	Options
	  Type        "Lines" (default) | "Histogram"
	  Values      initial samples
	  Capacity    maximum samples kept (default 60)
	  Min, Max    fixed scale; omit for automatic scaling
	  Height      pixel height (default 56)
	  Format(v)   overlay text for the latest value (default: 2 decimals)
	  Name, Tooltip, Visible
	Not saved in configuration.
]]

local Element = require(script.Parent.Parent.Core.Element)
local Layout = require(script.Parent.Parent.Core.Layout)
local Theme = require(script.Parent.Parent.Core.Theme)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Plot = Element.extend("Plot")
Plot.Fill = true

function Plot:_build()
	local options = self.Options
	self._type = options.Type == "Histogram" and "Histogram" or "Lines"
	self._capacity = math.max(2, math.floor(tonumber(options.Capacity) or 60))
	self._samples = {}
	self._marks = {}

	local height = tonumber(options.Height) or 56
	local labeled = self:_labeled(height)
	local frame = Layout.FrameBox(labeled.Widget, "Frame")

	local canvas = Create("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		Parent = frame,
	})

	local overlay = Layout.Text(frame, {
		Name = "Overlay",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, Layout.Metrics.RowHeight - 4),
		ZIndex = 3,
	}, "SecondaryText")

	if labeled.Label then
		labeled.Label.TextYAlignment = Enum.TextYAlignment.Top
		labeled.Label.Position += UDim2.fromOffset(0, 2)
	end

	self._frame = frame
	self._canvas = canvas
	self._overlay = overlay
	self.Root = labeled.Root

	self._maid:Give(canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_render()
	end))

	if type(options.Values) == "table" then
		for _, value in options.Values do
			if type(value) == "number" then
				table.insert(self._samples, value)
			end
		end
		while #self._samples > self._capacity do
			table.remove(self._samples, 1)
		end
	end
	self:_render()
end

function Plot:_range(): (number, number)
	local options = self.Options
	local min, max = tonumber(options.Min), tonumber(options.Max)
	if min and max then
		return min, max
	end
	local low, high = math.huge, -math.huge
	for _, value in self._samples do
		low = math.min(low, value)
		high = math.max(high, value)
	end
	if low == math.huge then
		low, high = 0, 1
	end
	min = min or low
	max = max or high
	if max - min < 1e-6 then
		max = min + 1
	end
	return min, max
end

--- Ensures exactly `count` mark frames exist, reusing previous ones.
function Plot:_ensureMarks(count: number)
	local marks = self._marks
	local color = self._type == "Histogram" and "PlotHistogram" or "Plot"
	while #marks < count do
		local mark = Create("Frame", {
			Name = "Mark",
			BorderSizePixel = 0,
			Parent = self._canvas,
		})
		if self._type == "Lines" then
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
		else
			mark.AnchorPoint = Vector2.new(0, 1)
		end
		Theme.Bind(mark, { BackgroundColor3 = color })
		table.insert(marks, mark)
	end
	for index = #marks, count + 1, -1 do
		Theme.Unbind(marks[index])
		marks[index]:Destroy()
		marks[index] = nil
	end
end

function Plot:_render()
	local samples = self._samples
	local count = #samples
	local min, max = self:_range()
	local range = max - min

	local latest = samples[count]
	if latest then
		local format = self.Options.Format
		if type(format) == "function" then
			local ok, text = pcall(format, latest)
			self._overlay.Text = ok and tostring(text) or ""
		else
			self._overlay.Text = string.format("%.2f", latest)
		end
	else
		self._overlay.Text = ""
	end

	if self._type == "Histogram" then
		self:_ensureMarks(count)
		local slots = self._capacity
		for index, value in samples do
			local alpha = math.clamp((value - min) / range, 0, 1)
			local mark = self._marks[index]
			local slot = slots - count + index - 1
			mark.Position = UDim2.fromScale(slot / slots, 1)
			mark.Size = UDim2.new(1 / slots, -1, alpha, 0)
		end
		return
	end

	-- Lines: segment geometry needs the unscaled pixel size of the canvas.
	local segments = math.max(0, count - 1)
	self:_ensureMarks(segments)
	if segments == 0 then
		return
	end
	local scale = self:_scale()
	local absolute = self._canvas.AbsoluteSize / scale
	local width, height = absolute.X, absolute.Y
	if width <= 0 or height <= 0 then
		return
	end
	local step = width / (self._capacity - 1)
	local offset = (self._capacity - count) * step
	local function point(index: number): Vector2
		local alpha = math.clamp((samples[index] - min) / range, 0, 1)
		return Vector2.new(offset + (index - 1) * step, (1 - alpha) * height)
	end
	for index = 1, segments do
		local from, to = point(index), point(index + 1)
		local delta = to - from
		local center = (from + to) / 2
		local mark = self._marks[index]
		mark.Position = UDim2.fromOffset(center.X, center.Y)
		mark.Size = UDim2.fromOffset(delta.Magnitude + 1, 1.5)
		mark.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end
end

--- Appends a sample (dropping the oldest beyond Capacity).
function Plot:Push(value: number)
	if type(value) ~= "number" or value ~= value then
		return
	end
	table.insert(self._samples, value)
	if #self._samples > self._capacity then
		table.remove(self._samples, 1)
	end
	self:_render()
end

--- Replaces all samples.
function Plot:SetValues(values: { number })
	table.clear(self._samples)
	for _, value in values do
		if type(value) == "number" then
			table.insert(self._samples, value)
		end
	end
	while #self._samples > self._capacity do
		table.remove(self._samples, 1)
	end
	self:_render()
end

function Plot:GetValues(): { number }
	return table.clone(self._samples)
end

function Plot:GetValue(): any
	return self._samples[#self._samples]
end

function Plot:SetValue(value: any)
	self:Push(value)
end

function Plot:Clear()
	table.clear(self._samples)
	self:_render()
end

return Plot
