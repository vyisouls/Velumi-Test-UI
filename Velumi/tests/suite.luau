--[[
	Velumi headless test suite.

	Runs the real library source against tests/mock/Roblox.luau, drives it
	with simulated input and checks behaviour, configuration round trips,
	theming, and — most importantly — that destroying everything leaves no
	connections or instances behind.

	Entry point: `return function(Mock, host, load) -> failures`
	Run with Lune:  lune run tests/run
]]

return function(Mock, host, load)
	local passed, failed = 0, 0
	local currentTest = ""

	local function test(name, fn)
		currentTest = name
		local ok, err = xpcall(fn, debug.traceback)
		Mock.flush()
		if ok then
			passed += 1
			print("  ok   " .. name)
		else
			failed += 1
			print("  FAIL " .. name .. "\n" .. tostring(err))
		end
	end

	local function expect(condition, message)
		if not condition then
			error((message or "expectation failed") .. " [" .. currentTest .. "]", 2)
		end
	end

	local function equal(actual, expected, message)
		if actual ~= expected then
			error(
				string.format(
					"%s: expected %s, got %s",
					message or "values differ",
					tostring(expected),
					tostring(actual)
				),
				2
			)
		end
	end

	local function findDescendant(root, predicate)
		for _, descendant in root:GetDescendants() do
			if predicate(descendant) then
				return descendant
			end
		end
		return nil
	end

	local function findNamed(root, name)
		return findDescendant(root, function(inst)
			return inst.Name == name
		end)
	end

	print("Velumi test suite")

	local baseConnections = Mock.liveConnections()
	local baseInstances = Mock.liveInstanceCount()

	local storage = Mock.Instance.new("Folder")
	storage.Name = "ReplicatedStorage"
	local module = Mock.mount("src/Velumi", "Velumi", storage)
	local Velumi = Mock.require(module)
	local Color3, Vector2, UDim2, Enum = Mock.Color3, Mock.Vector2, Mock.UDim2, Mock.Enum

	local function popupsLayer()
		return Mock.PlayerGui:FindFirstChild("Velumi"):FindFirstChild("Popups")
	end

	-----------------------------------------------------------------------
	test("library loads with expected API", function()
		for _, method in
			{
				"CreateWindow",
				"SetTheme",
				"GetTheme",
				"RegisterTheme",
				"GetThemes",
				"Notify",
				"ShowModal",
				"Confirm",
				"ShowContextMenu",
				"SetScale",
				"SetAnimationsEnabled",
				"SetParent",
				"SetMetrics",
				"RegisterElement",
				"Destroy",
			}
		do
			expect(type(Velumi[method]) == "function", "missing Velumi:" .. method)
		end
		equal(Velumi:GetTheme(), "Dark", "default theme")
		local themes = table.concat(Velumi:GetThemes(), ",")
		equal(themes, "Classic,Dark,Gray,Light,Midnight", "built-in themes")
	end)

	local window, main, general, advanced
	test("window, tab and group creation", function()
		window = Velumi:CreateWindow({
			Title = "Test",
			Size = UDim2.fromOffset(700, 480),
			Center = true,
			ToggleKey = Enum.KeyCode.RightShift,
		})
		main = window:AddTab({ Name = "Main", Columns = 2 })
		general = main:AddGroup({ Name = "General" })
		advanced = main:AddGroup({ Name = "Advanced", Side = "Right", Collapsible = true })
		local host = Mock.PlayerGui:FindFirstChild("Velumi")
		expect(host, "ScreenGui created under PlayerGui")
		expect(host.IgnoreGuiInset, "ignores inset")
		expect(window.Root.Parent == host:FindFirstChild("Windows"), "window in Windows layer")
		equal(window.SelectedTab, main, "first tab auto-selected")
		expect(main.Page.Visible, "selected page visible")
		expect(window:IsFocused(), "new window focused")
		local position = window:GetPosition()
		equal(position.X, (1280 - 700) / 2, "centered X")
	end)

	-----------------------------------------------------------------------
	local checkbox, toggle, slider, dropdown, multi, input, numeric, keybind, color
	local log = {}

	test("checkbox", function()
		checkbox = general:AddCheckbox({
			Name = "Enabled",
			Default = false,
			Tooltip = "Turns the thing on.",
			Callback = function(value)
				table.insert(log, "checkbox:" .. tostring(value))
			end,
		})
		equal(checkbox:GetValue(), false, "default")
		Mock.click(checkbox.Root)
		equal(checkbox:GetValue(), true, "click toggles")
		equal(log[#log], "checkbox:true", "callback fired")
		checkbox:SetValue(false, true)
		equal(log[#log], "checkbox:true", "silent SetValue does not fire")
		equal(checkbox:GetValue(), false, "silent value applied")
		equal(checkbox.Flag, "Main/General/Enabled", "implicit flag")
		equal(window.Values["Main/General/Enabled"], false, "values table live")
		checkbox:SetDisabled(true)
		Mock.click(checkbox.Root)
		equal(checkbox:GetValue(), false, "disabled ignores clicks")
		checkbox:SetDisabled(false)
	end)

	test("toggle + bound table", function()
		local settings = { AutoSave = true }
		toggle = general:AddToggle({ Name = "Auto Save", Bind = { settings, "AutoSave" }, Flag = "AutoSave" })
		equal(toggle:GetValue(), true, "default from bound table")
		toggle:SetValue(false)
		equal(settings.AutoSave, false, "writes back to bound table")
		settings.AutoSave = true
		toggle:Sync()
		equal(toggle:GetValue(), true, "Sync pulls from bound table")
		window:Sync()
	end)

	test("slider", function()
		local last
		slider = general:AddSlider({
			Name = "Walk Speed",
			Min = 0,
			Max = 100,
			Default = 16,
			Step = 0.5,
			Suffix = " st",
			Callback = function(value)
				last = value
			end,
		})
		equal(slider:GetValue(), 16, "default")
		slider:SetValue(33.3)
		equal(slider:GetValue(), 33.5, "snaps to step")
		equal(last, 33.5, "callback")
		slider:SetValue(500)
		equal(slider:GetValue(), 100, "clamped")
		local frame = findNamed(slider.Root, "Frame")
		local value = findNamed(slider.Root, "Value")
		equal(value.Text, "100.0 st", "formatted")
		-- drag to the far left
		local hitbox = findNamed(slider.Root, "Hitbox")
		Mock.drag(hitbox, Vector2.new(frame.AbsolutePosition.X - 50, 0))
		equal(slider:GetValue(), 0, "drag to left edge")
		slider:SetRange(10, 20)
		equal(slider:GetValue(), 10, "range re-clamps")
	end)

	test("same line, sections, child regions, indent, disabled scopes", function()
		general:AddButton({ Name = "A" })
		general:SameLine()
		local b = general:AddButton({ Name = "B" })
		local rowA = general._elements[#general._elements - 1]._row
		equal(b._row, rowA, "SameLine shares the row")

		local section = general:AddSection({ Name = "More", Open = false })
		local inner = section:AddLabel("inside section")
		expect(not section._contentFrame.Visible, "closed section hides content")
		section:Toggle()
		expect(section:IsOpen(), "section opens")
		equal(inner.Container, section, "label in section")

		local child = general:BeginChild({ Name = "Log", Height = 80, AutoScroll = true })
		local logLabel = general:AddLabel("goes into child")
		general:EndChild()
		local after = general:AddLabel("after child")
		equal(logLabel.Container, child, "BeginChild redirects Add calls")
		equal(after.Container, general, "EndChild restores target")

		general:BeginDisabled()
		local disabledButton = general:AddButton("Disabled")
		general:EndDisabled()
		expect(disabledButton:IsDisabled(), "BeginDisabled scope")

		general:Indent()
		local indented = general:AddLabel("indented")
		general:Unindent()
		expect(indented._row:FindFirstChildOfClass("UIPadding"), "indented row has padding")

		local tree = advanced:AddSection({ Name = "Tree", Style = "Tree" })
		tree:AddCheckbox({ Name = "Deep", Save = false })
	end)

	test("dropdown + multi dropdown", function()
		local last
		dropdown = general:AddDropdown({
			Name = "Mode",
			Values = { "Default", "Advanced", "Experimental" },
			Default = "Default",
			Callback = function(value)
				last = value
			end,
		})
		equal(dropdown:GetValue(), "Default", "default")
		dropdown:Open()
		Mock.flush()
		expect(dropdown:IsOpen(), "opens")
		local popup = popupsLayer():FindFirstChild("DropdownPopup")
		expect(popup, "popup parented to popup layer")
		local items = {}
		for _, d in popup:GetDescendants() do
			if d.Name == "Item" then
				table.insert(items, d)
			end
		end
		equal(#items, 3, "three items")
		Mock.click(items[2])
		equal(dropdown:GetValue(), "Advanced", "choosing selects")
		equal(last, "Advanced", "callback")
		expect(not dropdown:IsOpen(), "single select closes")
		expect(popup.Parent == nil, "popup destroyed")

		dropdown:SetValues({ "One", "Two" })
		equal(dropdown:GetValue(), "One", "SetValues falls back to first value")
		dropdown:SetValue("Nope")
		equal(dropdown:GetValue(), "One", "unknown value ignored for non-AllowNone? (keeps valid)")

		multi = general:AddMultiDropdown({
			Name = "Layers",
			Values = { "Players", "NPCs", "Items" },
			Default = { "Items", "Players" },
		})
		local value = multi:GetValue()
		equal(#value, 2, "multi default")
		equal(value[1], "Players", "ordered by Values")
		multi:Open()
		Mock.flush()
		local mpopup = popupsLayer():FindFirstChild("DropdownPopup")
		local mitems = {}
		for _, d in mpopup:GetDescendants() do
			if d.Name == "Item" then
				table.insert(mitems, d)
			end
		end
		Mock.click(mitems[2])
		equal(#multi:GetValue(), 3, "multi adds")
		expect(multi:IsOpen(), "multi stays open")
		Mock.click(mitems[1])
		equal(#multi:GetValue(), 2, "multi removes")
		-- click outside closes popups
		Mock.setMouse(5, 5)
		Mock.fire(Mock.UIS.InputBegan, Mock.input("MouseButton1"), false)
		Mock.flush()
		expect(not multi:IsOpen(), "outside click closes")
		multi:SetValue({ NPCs = true })
		equal(multi:GetValue()[1], "NPCs", "set form accepted")
	end)

	test("input (text, numeric, validation)", function()
		local invalid = 0
		input = general:AddInput({
			Name = "Username",
			Placeholder = "name",
			MaxLength = 8,
			Validate = function(text)
				return #text >= 3, "too short"
			end,
		})
		input.Invalid:Connect(function()
			invalid += 1
		end)
		local box = findDescendant(input.Root, function(d)
			return d.ClassName == "TextBox"
		end)
		Mock.type(box, "ab")
		equal(input:GetValue(), "", "rejected by Validate")
		equal(invalid, 1, "Invalid fired")
		Mock.type(box, "velumi_user_long")
		equal(input:GetValue(), "velumi_u", "MaxLength enforced")

		numeric = general:AddInput({ Name = "Seed", Numeric = true, Min = 0, Max = 100, Default = 5 })
		local nbox = findDescendant(numeric.Root, function(d)
			return d.ClassName == "TextBox"
		end)
		Mock.type(nbox, "250")
		equal(numeric:GetValue(), 100, "numeric clamped")
		equal(Mock.typeof(numeric:GetValue()), "number", "numeric value is a number")
	end)

	test("keybind capture, modes and context menu", function()
		local states = {}
		keybind = advanced:AddKeybind({
			Name = "Fly",
			Default = Enum.KeyCode.F,
			Callback = function(active)
				table.insert(states, active)
			end,
		})
		equal(keybind:GetValue(), "F", "default key")
		Mock.pressKey("F")
		equal(states[#states], true, "toggle on")
		Mock.pressKey("F")
		equal(states[#states], false, "toggle off")

		local hitbox = findNamed(keybind.Root, "Hitbox")
		Mock.click(hitbox)
		Mock.pressKey("G")
		equal(keybind:GetValue(), "G", "rebound")
		local count = #states
		Mock.pressKey("F")
		equal(#states, count, "old key no longer fires")

		Mock.click(hitbox)
		Mock.pressKey("Escape")
		equal(keybind:GetValue(), "G", "escape cancels")
		Mock.click(hitbox)
		Mock.pressKey("Backspace")
		equal(keybind:GetValue(), "None", "backspace clears")
		keybind:SetValue("H")

		keybind:SetMode("Hold")
		Mock.pressKey("H", true)
		equal(keybind:GetState(), true, "hold active")
		Mock.releaseKey("H")
		equal(keybind:GetState(), false, "hold released")

		-- Right-click opens the mode menu.
		Mock.rightClick(keybind.Root)
		local menu = popupsLayer():FindFirstChild("ContextMenu")
		expect(menu, "context menu opened")
		local toggleItem
		for _, d in menu:GetDescendants() do
			if d.Name == "Label" and d.Text == "Toggle" then
				toggleItem = d.Parent
			end
		end
		Mock.click(toggleItem)
		equal(keybind:GetMode(), "Toggle", "mode via context menu")
		expect(menu.Parent == nil, "menu closed after choice")

		-- Target: drive the checkbox.
		local target = advanced:AddKeybind({ Name = "Enable", Default = "J", Target = checkbox, Save = false })
		local before = checkbox:GetValue()
		Mock.pressKey("J")
		equal(checkbox:GetValue(), not before, "keybind drives target")
		target:Destroy()
	end)

	test("color picker", function()
		local lastColor, lastT
		color = advanced:AddColorPicker({
			Name = "Tint",
			Default = Color3.fromRGB(76, 141, 255),
			Transparency = 0.25,
			Callback = function(c, t)
				lastColor, lastT = c, t
			end,
		})
		equal(color:GetHex(), "#4C8DFF", "hex")
		equal(color:GetTransparency(), 0.25, "transparency")
		color:Open()
		local popup = popupsLayer():FindFirstChild("ColorPickerPopup")
		expect(popup, "picker popup")
		local hexField = findNamed(popup, "FieldHex")
		local box = findDescendant(hexField, function(d)
			return d.ClassName == "TextBox"
		end)
		Mock.type(box, "#FF0000")
		equal(color:GetHex(), "#FF0000", "hex field commits")
		expect(lastColor and lastT == 0.25, "callback with transparency")
		local area = findNamed(popup, "Area")
		Mock.drag(area, area.AbsolutePosition) -- top-left: saturation 0, value 1
		equal(color:GetHex(), "#FFFFFF", "SV drag")
		color:SetTransparency(0.5)
		equal(color:GetTransparency(), 0.5, "SetTransparency")
		color:Close()
		expect(popup.Parent == nil, "picker closed")
		local data = color:_serialize()
		equal(data.Color, "FFFFFF", "serialize color")
	end)

	test("labels, paragraph, separator, progress, plot", function()
		local label = general:AddLabel({ Text = "Status", Style = "Success", Bullet = true })
		label:SetText("Changed")
		equal(label:GetValue(), "Changed", "label text")
		local paragraph = general:AddParagraph({ Title = "About", Text = "Body text" })
		paragraph:SetTitle("New")
		general:AddSeparator("Advanced")
		general:AddSeparator()
		local bar = general:AddProgressBar({ Name = "Progress", Default = 0.5 })
		bar:SetValue(2)
		equal(bar:GetValue(), 1, "progress clamped")
		local plot = general:AddPlot({ Name = "FPS", Min = 0, Max = 120 })
		for i = 1, 70 do
			plot:Push(i)
		end
		equal(#plot:GetValues(), 60, "plot capacity")
		local histogram = general:AddPlot({ Name = "Hist", Type = "Histogram", Values = { 1, 2, 3 } })
		histogram:Push(4)
		equal(#histogram:GetValues(), 4, "histogram values")
	end)

	-----------------------------------------------------------------------
	test("configuration round trip", function()
		checkbox:SetValue(true)
		slider:SetValue(12)
		dropdown:SetValue("Two")
		multi:SetValue({ "Players", "Items" })
		input:SetValue("hello")
		numeric:SetValue(42)
		color:SetValue({ Color = Color3.fromRGB(10, 20, 30), Transparency = 0.1 })
		keybind:SetValue("K")

		local data = window:GetConfig()
		equal(data.Version, 1, "version")
		local json = window:ExportConfig()
		expect(type(json) == "string" and #json > 10, "export json")

		checkbox:SetValue(false)
		slider:SetValue(19)
		dropdown:SetValue("One")
		multi:SetValue({})
		input:SetValue("")
		numeric:SetValue(0)
		color:SetValue(Color3.new(1, 1, 1))
		keybind:SetValue("L")

		local applied = window:LoadConfig(data)
		expect(applied >= 8, "applied values: " .. applied)
		equal(checkbox:GetValue(), true, "checkbox restored")
		equal(slider:GetValue(), 12, "slider restored")
		equal(dropdown:GetValue(), "Two", "dropdown restored")
		equal(#multi:GetValue(), 2, "multi restored")
		equal(input:GetValue(), "hello", "input restored")
		equal(numeric:GetValue(), 42, "numeric restored")
		equal(color:GetHex(), "#0A141E", "color restored")
		equal(keybind:GetValue(), "K", "keybind restored")

		checkbox:SetValue(false)
		local count = window:ImportConfig(json)
		expect(count >= 8, "import count")
		equal(checkbox:GetValue(), true, "import restores")

		local changes = 0
		local conn = window.ConfigChanged:Connect(function()
			changes += 1
		end)
		slider:SetValue(15)
		equal(changes, 1, "ConfigChanged fires")
		conn:Disconnect()

		window:ResetConfig()
		equal(slider:GetValue(), 16, "reset to default")
		equal(window:GetFlag("AutoSave"), toggle, "GetFlag")
	end)

	test("duplicate flags are suffixed", function()
		local a = general:AddCheckbox({ Name = "Dup" })
		local b = general:AddCheckbox({ Name = "Dup" })
		equal(a.Flag, "Main/General/Dup", "first")
		equal(b.Flag, "Main/General/Dup#2", "second")
		b:Destroy()
		equal(window:GetFlag("Main/General/Dup#2"), nil, "destroy unregisters")
	end)

	-----------------------------------------------------------------------
	test("themes", function()
		local titleBar = window.Root:FindFirstChild("TitleBar")
		local dark = titleBar.BackgroundColor3
		Velumi:SetTheme("Light")
		equal(Velumi:GetTheme(), "Light", "switched")
		expect(titleBar.BackgroundColor3 ~= dark, "existing UI restyled")
		Velumi:RegisterTheme("Pink", { Accent = Color3.fromRGB(255, 100, 150) })
		Velumi:SetTheme("Pink")
		equal(Velumi:GetThemeValue("Accent"), Color3.fromRGB(255, 100, 150), "custom accent")
		expect(Velumi:GetThemeValue("Header") ~= nil, "derived keys present")
		Velumi:SetTheme({ Accent = Color3.fromRGB(0, 200, 0) })
		equal(Velumi:GetTheme(), "Custom", "table theme")
		Velumi:SetTheme("DoesNotExist")
		equal(Velumi:GetTheme(), "Custom", "unknown theme ignored")
		Velumi:SetTheme("Dark")
	end)

	test("window state: minimize, maximize, visibility, toggle key, z-order", function()
		window:Minimize()
		expect(window:IsMinimized(), "minimized")
		Mock.advance(0.5)
		window:Restore()
		expect(not window:IsMinimized(), "restored")
		window:Maximize()
		expect(window:IsMaximized(), "maximized")
		window:Restore()
		equal(window:GetSize().X, 700, "size restored")

		Mock.pressKey("RightShift")
		expect(not window:IsVisible(), "toggle key hides")
		Mock.pressKey("RightShift")
		expect(window:IsVisible(), "toggle key shows")

		local second = Velumi:CreateWindow({ Title = "Second", Size = Vector2.new(300, 200) })
		expect(second.Root.ZIndex > window.Root.ZIndex, "new window on top")
		expect(second:IsFocused() and not window:IsFocused(), "focus moved")
		window:Focus()
		expect(window.Root.ZIndex > second.Root.ZIndex, "focus brings to front")
		second:Close()
		expect(not second:IsVisible(), "close hides by default")
		second:Destroy()
		expect(second:IsDestroyed(), "destroyed")

		window:SetScale(0.8)
		equal(window.Root:FindFirstChildOfClass("UIScale").Scale, 0.8, "scale applied")
		window:SetScale(1)
		window:SetSize(Vector2.new(10, 10))
		equal(window:GetSize().X, 360, "min size enforced")
		window:SetSize(UDim2.fromOffset(700, 480))
	end)

	test("tabs: top style, implicit tab, select, hide", function()
		local topWindow = Velumi:CreateWindow({ Title = "Top", TabStyle = "Top" })
		local a = topWindow:AddTab("A")
		local b = topWindow:AddTab({ Name = "B" })
		topWindow:SelectTab("B")
		equal(topWindow.SelectedTab, b, "select by name")
		b:SetVisible(false)
		equal(topWindow.SelectedTab, a, "hiding selected tab selects another")
		topWindow:Destroy()

		local tool = Velumi:CreateWindow({ Title = "Tool", Size = Vector2.new(320, 240) })
		local group = tool:AddGroup({ Name = "Stats" })
		group:AddLabel("no tabs needed")
		equal(#tool.Tabs, 1, "implicit tab")
		expect(not tool.Root:FindFirstChild("Sidebar", true), "sidebar hidden or absent")
		tool:Destroy()
	end)

	test("menu bar and status bar", function()
		local fired = false
		window:AddMenu("File", {
			{
				Name = "Save",
				Shortcut = "Ctrl+S",
				Callback = function()
					fired = true
				end,
			},
			"-",
			{ Name = "Export", Items = { { Name = "JSON" } } },
			{ Name = "Disabled", Disabled = true },
		})
		window:SetStatus("Ready", "v1")
		local header = findNamed(window.Root, "Menu_File")
		Mock.click(header)
		local menu = popupsLayer():FindFirstChild("ContextMenu")
		expect(menu, "menu open")
		local save
		for _, d in menu:GetDescendants() do
			if d.Name == "Label" and d.Text == "Save" then
				save = d.Parent
			end
		end
		Mock.click(save)
		expect(fired, "menu item callback")
		expect(menu.Parent == nil, "menu closed")
	end)

	test("notifications", function()
		local n = Velumi:Notify({ Title = "Saved", Description = "ok", Type = "Success", Duration = 1 })
		local closed = false
		n.Closed:Connect(function()
			closed = true
		end)
		Mock.advance(2)
		expect(closed, "auto closes after duration")
		for i = 1, 8 do
			Velumi:Notify({ Title = "N" .. i, Duration = 0 })
		end
		local stack = Mock.PlayerGui:FindFirstChild("Velumi"):FindFirstChild("Notifications"):FindFirstChild("Stack")
		Mock.advance(1)
		local count = 0
		for _, child in stack:GetChildren() do
			if child.Name == "Notification" then
				count += 1
			end
		end
		equal(count, 5, "stack bounded to MaxVisible")
	end)

	test("modal and confirm", function()
		local saved
		local modal = Velumi:ShowModal({
			Title = "Rename",
			Description = "Choose a name",
			Buttons = {
				"Cancel",
				{
					Name = "Save",
					Style = "Accent",
					Callback = function(m)
						saved = m:GetValues().Name
					end,
				},
			},
			Build = function(m)
				m:AddInput({ Name = "Name", Flag = "Name", Default = "preset" })
			end,
		})
		expect(modal:IsOpen(), "open")
		local saveButton
		for _, d in modal.Root:GetDescendants() do
			if d.Name == "Button" and d.Text == "Save" then
				saveButton = d
			end
		end
		Mock.click(saveButton)
		equal(saved, "preset", "modal values")
		expect(not modal:IsOpen(), "closed")
		Mock.advance(0.5)

		local answer
		Velumi:Confirm({
			Title = "Sure?",
			Callback = function(ok)
				answer = ok
			end,
		})
		Mock.pressKey("Escape")
		Mock.advance(0.5)
		equal(answer, false, "escape answers false")
	end)

	test("tooltips", function()
		local root = checkbox.Root
		Mock.hover(root, true)
		Mock.advance(1)
		local tooltip = Mock.PlayerGui:FindFirstChild("Velumi"):FindFirstChild("Tooltip"):FindFirstChild("Tooltip")
		expect(tooltip and tooltip.Visible, "tooltip shown after delay")
		Mock.hover(root, false)
		expect(not tooltip.Visible, "tooltip hidden on leave")
	end)

	test("custom elements via RegisterElement", function()
		local Counter = Velumi.Element.extend("Counter")
		Counter.Saveable = true
		function Counter:_build()
			self.Root = Mock.Instance.new("TextButton")
			self.Root.Text = "0"
			self._maid:Give(self.Root.Activated:Connect(function()
				self:SetValue(self.Value + 1)
			end))
		end
		function Counter:_apply(value)
			local n = tonumber(value) or 0
			local changed = self.Value ~= n
			self.Value = n
			self.Root.Text = tostring(n)
			return changed
		end
		Velumi:RegisterElement("Counter", Counter)
		local counter = general:AddCounter({ Name = "Clicks", Default = 0 })
		Mock.click(counter.Root)
		equal(counter:GetValue(), 1, "custom element works")
		equal(window.Values["Main/General/Clicks"], 1, "custom element saved")
	end)

	test("CONTRIBUTING.md Stepper example", function()
		local Element = Velumi.Element
		local Stepper = Element.extend("Stepper")
		Stepper.Saveable = true
		Stepper.Fill = true

		function Stepper:_build()
			local labeled = self:_labeled()
			local button = Mock.Instance.new("TextButton")
			button.Size = UDim2.fromScale(1, 1)
			button.AutoButtonColor = false
			self:_bind(button, {
				BackgroundColor3 = function(t)
					return self._hovered and t.FrameHover or t.Frame
				end,
				TextColor3 = "Text",
				FontFace = "Font",
				TextSize = "TextSize",
			})
			button.Parent = labeled.Widget
			self:_track(button)
			self._button = button
			self._maid:Give(button.Activated:Connect(function()
				if not self._disabled then
					self:SetValue(self.Value + (self.Options.Step or 1))
				end
			end))
			self.Root = labeled.Root
		end

		function Stepper:_apply(value)
			local number = tonumber(value) or 0
			local changed = self.Value ~= number
			self.Value = number
			self._button.Text = tostring(number)
			return changed
		end

		Velumi:RegisterElement("Stepper", Stepper)
		local stepper = general:AddStepper({ Name = "Count", Default = 0, Step = 5, Flag = "Count" })
		Mock.click(stepper._button)
		equal(stepper:GetValue(), 5, "stepper steps")
		equal(window.Values.Count, 5, "stepper saved")
		Mock.hover(stepper._button, true)
		stepper:Destroy()
		equal(window:GetFlag("Count"), nil, "stepper unregistered")
	end)

	test("API smoke: every remaining public method runs", function()
		-- Library
		expect(type(Velumi:GetPalette().Accent) ~= "nil", "palette")
		Velumi:SetTooltipDelay(0.3)
		Velumi:SetDisplayOrder(50)
		equal(Mock.PlayerGui:FindFirstChild("Velumi").DisplayOrder, 50, "display order")
		Velumi:SetScale(1.1)
		equal(Velumi:GetScale(), 1.1, "global scale")
		Velumi:SetScale(1)
		Velumi:SetAnimationsEnabled(false)
		Velumi:SetAnimationsEnabled(true)
		local handle = Velumi:ShowContextMenu({ { Name = "A" }, "-", { Name = "B", Checked = true } }, Vector2.new(100, 100))
		expect(handle and handle.Frame.Parent, "context menu handle")
		handle.Close()
		Velumi:ClosePopups()
		Velumi:SetMetrics({ SidebarWidth = 140 })
		equal(Velumi.Metrics.SidebarWidth, 140, "metrics")
		Velumi:SetMetrics({ SidebarWidth = 132 })

		-- Window
		window:SetTitle("Renamed")
		window:SetMinSize(Vector2.new(300, 200))
		window:SetMaxSize(Vector2.new(1000, 800))
		window:SetResizable(false)
		window:SetResizable(true)
		window:SetDraggable(false)
		window:SetDraggable(true)
		window:SetPosition(Vector2.new(20, 30))
		equal(window:GetPosition().X, 20, "position")
		window:Center()
		local visited = 0
		window:ForEachElement(function()
			visited += 1
		end)
		expect(visited > 10, "ForEachElement visits elements")
		window:SetToggleKey(nil)
		window:SetToggleKey("RightShift")
		expect(window:GetTab("Main") == main, "GetTab")

		-- Tab / group / child
		main:ScrollToTop()
		main:SetText("Main")
		expect(main:GetGroup("General") == general, "GetGroup")
		advanced:SetCollapsed(true)
		expect(advanced:IsCollapsed(), "collapsed")
		advanced:SetCollapsed(false)
		general:SetTitle("General")
		local child = general:AddChild({ Height = 50 })
		child:AddLabel("x")
		child:ScrollToBottom()
		child:ScrollToTop()
		child:SetHeight(60)
		child:SetVisible(false)
		expect(not child:IsVisible(), "child hidden")
		child:Destroy()
		general:AddSpacing(6)

		-- Elements
		local button = general:AddButton({ Name = "Styled", Width = 80 })
		button:SetStyle("Danger")
		button:SetText("Styled!")
		button:Press()
		button:SetTooltip("tip")
		button:SetContextMenu({ { Name = "Item" } })
		local label = general:AddLabel({ Text = "c", Wrap = true, Align = "Center" })
		label:SetColor(Color3.new(1, 0, 0))
		label:SetStyle("Warning")
		dropdown:AddValue("Three")
		dropdown:RemoveValue("Three")
		expect(dropdown:IsSelected(dropdown:GetValue()), "IsSelected")
		slider:SetStep(1)
		slider:SetMin(0)
		slider:SetMax(50)
		local min, max = slider:GetRange()
		equal(max, 50, "range")
		input:SetPlaceholder("new")
		input:Focus()
		checkbox:SetCallback(function() end)
		checkbox:SetText("Enabled!")
		equal(checkbox:GetText(), "Enabled!", "GetText")
		local conn = checkbox:OnChanged(function() end)
		conn:Disconnect()
		toggle:Toggle()
		checkbox:Toggle()
		checkbox:SetVisible(false)
		expect(not checkbox:IsVisible(), "hidden")
		checkbox:SetVisible(true)
		local _ = min
	end)

	test("clear and rebuild", function()
		local dynamic = main:AddGroup({ Name = "Dynamic" })
		dynamic:Rebuild(function(g)
			for i = 1, 5 do
				g:AddCheckbox({ Name = "Item " .. i })
			end
		end)
		equal(#dynamic:GetElements(), 5, "built")
		dynamic:Rebuild(function(g)
			g:AddLabel("empty")
		end)
		equal(#dynamic:GetElements(), 1, "rebuilt")
		equal(window:GetFlag("Main/Dynamic/Item 1"), nil, "old flags unregistered")
		dynamic:Destroy()
	end)

	-----------------------------------------------------------------------
	test("window destroy releases everything", function()
		Velumi:ClearNotifications()
		window:Destroy()
		Mock.advance(2)
		expect(Mock.PlayerGui:FindFirstChild("Velumi") == nil, "host removed with last consumer")
		equal(Mock.liveConnections(), baseConnections, "no connections left")
		expect(next(Mock.CAS) == nil, "no bound actions left")
	end)

	test("showcase runs and cleans up", function()
		local playerScripts = Mock.Instance.new("Folder")
		local showcase = Mock.Instance.new("ModuleScript")
		rawset(showcase, "_path", "examples/Showcase.client.luau")
		showcase.Parent = playerScripts
		local services = Mock.services
		local originalGetService = nil
		-- Expose Velumi at ReplicatedStorage.Velumi for the showcase.
		local rs = services.ReplicatedStorage
		local source = host.readfile("examples/Showcase.client.luau")
		local env = Mock.environment(showcase)
		local rsProxy = setmetatable({}, {
			__index = function(_, key)
				if key == "Velumi" then
					return module
				elseif key == "WaitForChild" then
					return function(_, name)
						assert(name == "Velumi", "showcase waits for " .. tostring(name))
						return module
					end
				end
				return rs[key]
			end,
		})
		env.game = setmetatable({}, {
			__index = function(_, key)
				if key == "GetService" then
					return function(_, name)
						if name == "ReplicatedStorage" then
							return rsProxy
						end
						return services[name]
					end
				end
				error(key .. " is not a valid member of DataModel")
			end,
		})
		local fn = assert(host.loadchunk(source, "Showcase", env))
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread)
		assert(ok, err)
		Mock.advance(3)
		local velumiHost = Mock.PlayerGui:FindFirstChild("Velumi")
		expect(velumiHost, "showcase created UI")
		local windows = Velumi:GetWindows()
		expect(#windows >= 1, "showcase windows")

		-- Exercise every tab of the showcase.
		for _, w in windows do
			for _, tab in w.Tabs do
				w:SelectTab(tab)
				Mock.advance(0.1)
			end
		end

		Velumi:Destroy()
		Mock.advance(5)
		expect(Mock.PlayerGui:FindFirstChild("Velumi") == nil, "host removed")
		equal(Mock.liveConnections(), baseConnections, "showcase left no connections")
		local _ = originalGetService
	end)

	test("no leaked instances", function()
		Mock.advance(5)
		-- Module tree instances created by this suite are expected to remain.
		local remaining = Mock.liveInstanceCount() - baseInstances
		local moduleInstances = #module:GetDescendants() + 1 + 1 + 2
		expect(remaining <= moduleInstances + 2, "leaked instances: " .. (remaining - moduleInstances))
	end)

	if Mock.warnings and #Mock.warnings > 0 then
		print(`\n{#Mock.warnings} warning(s) emitted during the run:`)
		for index, message in Mock.warnings do
			if index > 15 then
				print("  ...")
				break
			end
			print("  " .. string.sub(message, 1, 200))
		end
	end

	print(string.format("\n%d passed, %d failed", passed, failed))
	return failed
end
