--[[
	Child
	A fixed-height, bordered, independently scrolling region — useful for
	logs, long lists and inspectors inside a group.

	    local log = group:BeginChild({ Name = "Log", Height = 140, AutoScroll = true })
	    group:AddLabel("Server started")   -- goes into the child
	    group:EndChild()

	Options: Height (px, default 140), Border (default true),
	         AutoScroll (stick to the bottom while content grows).
]]

local Container = require(script.Parent.Container)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Create = Utility.Create

local Child = setmetatable({}, { __index = Container })
Child.__index = Child
Child.Kind = "Child"

function Child.new(parent: any, options: { [string]: any })
	local self = setmetatable({}, Child)
	local metrics = Layout.Metrics

	self.Kind = "Child"
	self.Name = options.Name or "Child"
	self._maid = Maid.new()
	self._height = options.Height or 140
	self._autoScroll = options.AutoScroll == true

	local root = Create("Frame", {
		Name = "Child",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, self._height),
	})
	Theme.Bind(root, { BackgroundColor3 = "Child" })
	Layout.Fill(root)
	Layout.Corner(root)
	if options.Border ~= false then
		Layout.Stroke(root, "Border")
	end

	local scroller = Create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = metrics.ScrollBarThickness,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = root,
	})
	Theme.Bind(scroller, { ScrollBarImageColor3 = "ScrollBar" })

	local content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroller,
	})
	Layout.Padding(content, 6, 6, 5, 5)

	self._scroller = scroller
	self._contentFrame = content

	Container._init(self, content, parent._window, parent._path, parent)
	Container._mount(self, parent, root)

	if self._autoScroll then
		local atBottom = true
		self._maid:Give(scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local maxY = scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y
			atBottom = scroller.CanvasPosition.Y >= maxY - 4
		end))
		self._maid:Give(scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			if atBottom then
				self:ScrollToBottom()
			end
		end))
	end

	return self
end

function Child:SetHeight(height: number)
	self._height = height
	self.Root.Size = UDim2.new(1, 0, 0, height)
end

function Child:ScrollToTop()
	self._scroller.CanvasPosition = Vector2.zero
end

function Child:ScrollToBottom()
	local scroller = self._scroller
	scroller.CanvasPosition = Vector2.new(0, math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y))
end

function Child:Destroy()
	Container._destroyNested(self)
end

return Child
