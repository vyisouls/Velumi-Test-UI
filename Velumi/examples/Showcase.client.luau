--[[
	Velumi Showcase
	A demo/debug window in the spirit of an immediate-mode "demo window":
	every element, layout helper, theme and configuration feature in one place.

	Setup: put the Velumi ModuleScript in ReplicatedStorage and this
	LocalScript in StarterPlayer > StarterPlayerScripts, then press Play.
	(With Rojo, `rojo serve showcase.project.json` does both.)

	Press RightShift to hide / show the window.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Velumi = require(ReplicatedStorage:WaitForChild("Velumi"))

local window = Velumi:CreateWindow({
	Title = "Velumi Showcase",
	Size = UDim2.fromOffset(720, 500),
	Center = true,
	ToggleKey = Enum.KeyCode.RightShift,
	StatusBar = "Ready",
})

local alive = true
local themeConnection
window.Destroyed:Connect(function()
	alive = false
	if themeConnection then
		themeConnection:Disconnect()
	end
end)

--------------------------------------------------------------------------
-- Menu bar
--------------------------------------------------------------------------

local savedConfig = nil

window:AddMenu("File", {
	{
		Name = "Save Config",
		Shortcut = "Ctrl+S",
		Callback = function()
			savedConfig = window:GetConfig()
			Velumi:Notify({ Title = "Saved", Description = "Configuration saved to memory.", Type = "Success" })
		end,
	},
	{
		Name = "Load Config",
		Callback = function()
			if savedConfig then
				local count = window:LoadConfig(savedConfig)
				Velumi:Notify({ Title = "Loaded", Description = `{count} values applied.` })
			else
				Velumi:Notify({ Title = "Nothing saved", Description = "Save a configuration first.", Type = "Warning" })
			end
		end,
	},
	"-",
	{
		Name = "Reset All",
		Callback = function()
			window:ResetConfig()
		end,
	},
	"-",
	{
		Name = "Close",
		Shortcut = "RShift",
		Callback = function()
			window:Close()
		end,
	},
})

local themeItems = {}
for _, name in Velumi:GetThemes() do
	table.insert(themeItems, {
		Name = name,
		Callback = function()
			Velumi:SetTheme(name)
		end,
	})
end

window:AddMenu("View", {
	{ Name = "Theme", Items = themeItems },
	{
		Name = "Scale",
		Items = {
			{
				Name = "75%",
				Callback = function()
					Velumi:SetScale(0.75)
				end,
			},
			{
				Name = "100%",
				Callback = function()
					Velumi:SetScale(1)
				end,
			},
			{
				Name = "125%",
				Callback = function()
					Velumi:SetScale(1.25)
				end,
			},
		},
	},
	"-",
	{
		Name = "Minimize",
		Callback = function()
			window:Minimize()
		end,
	},
	{
		Name = "Maximize",
		Callback = function()
			window:Maximize()
		end,
	},
	{
		Name = "Restore",
		Callback = function()
			window:Restore()
		end,
	},
})

window:AddMenu("Help", {
	{
		Name = "About Velumi",
		Callback = function()
			Velumi:ShowModal({
				Title = "About Velumi",
				Description = `Velumi {Velumi.Version} — a compact, developer-tool styled UI library for Roblox. MIT licensed.`,
				Buttons = { "Close" },
			})
		end,
	},
})

--------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------

local mainTab = window:AddTab({ Name = "Main" })

local welcome = mainTab:AddGroup({ Name = "Welcome" })
welcome:AddParagraph({
	Title = "Velumi Showcase",
	Text = "Every control, layout helper, theme and configuration feature lives in these tabs. "
		.. "Hover controls for tooltips, right-click keybinds for their mode menu, and Ctrl+Click a slider to type a value.",
})
welcome:AddButton({
	Name = "Info",
	Callback = function()
		Velumi:Notify({ Title = "Info", Description = "Something happened.", Type = "Info" })
	end,
})
welcome:SameLine()
welcome:AddButton({
	Name = "Success",
	Callback = function()
		Velumi:Notify({ Title = "Success", Description = "It worked.", Type = "Success" })
	end,
})
welcome:SameLine()
welcome:AddButton({
	Name = "Warning",
	Callback = function()
		Velumi:Notify({ Title = "Warning", Description = "Careful now.", Type = "Warning" })
	end,
})
welcome:SameLine()
welcome:AddButton({
	Name = "Error",
	Callback = function()
		Velumi:Notify({ Title = "Error", Description = "Something failed.", Type = "Error", Duration = 5 })
	end,
})

local general = mainTab:AddGroup({ Name = "General" })

general:AddCheckbox({
	Name = "Enabled",
	Default = true,
	Flag = "Enabled",
	Tooltip = "Master switch for the example features.",
	Callback = function(value)
		window:SetStatus(value and "Enabled" or "Disabled")
	end,
})

general:AddSlider({
	Name = "Walk Speed",
	Min = 0,
	Max = 100,
	Default = 16,
	Step = 0.5,
	Flag = "WalkSpeed",
	Tooltip = "Ctrl+Click to type an exact value.",
})

general:AddDropdown({
	Name = "Mode",
	Values = { "Default", "Advanced", "Experimental" },
	Default = "Default",
	Flag = "Mode",
})

local advanced = mainTab:AddGroup({ Name = "Advanced", Collapsible = true })
advanced:AddCheckbox({ Name = "Debug Mode", Flag = "DebugMode" })
advanced:AddCheckbox({ Name = "Verbose Logging", Flag = "Verbose" })

--------------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------------

local controlsTab = window:AddTab({ Name = "Controls", Columns = 2 })

-- Buttons ---------------------------------------------------------------
local buttons = controlsTab:AddGroup({ Name = "Buttons" })
local clicks = 0
local clickLabel
buttons:AddButton({
	Name = "Click Me",
	Callback = function()
		clicks += 1
		clickLabel:SetText(`Clicked {clicks} time(s)`)
	end,
})
buttons:SameLine()
buttons:AddButton({ Name = "Accent", Style = "Accent" })
buttons:SameLine()
buttons:AddButton({
	Name = "Delete",
	Style = "Danger",
	Confirm = true,
	Tooltip = "Requires a second click within two seconds.",
	Callback = function()
		Velumi:Notify({ Title = "Deleted", Description = "Confirmed deletion.", Type = "Error" })
	end,
})
clickLabel = buttons:AddLabel({ Text = "Clicked 0 time(s)", Style = "Secondary" })
buttons:AddButton({ Name = "Full Width", FullWidth = true })

-- Booleans --------------------------------------------------------------
local booleans = controlsTab:AddGroup({ Name = "Booleans" })
booleans:AddCheckbox({ Name = "Checkbox", Default = true, Flag = "Checkbox" })
local flyToggle = booleans:AddToggle({ Name = "Fly (toggle)", Flag = "Fly" })
booleans:AddCheckbox({ Name = "Disabled checkbox", Default = true, Disabled = true, Save = false })
booleans:AddCheckbox({ Name = "One", Flag = "One" })
booleans:SameLine()
booleans:AddCheckbox({ Name = "Two", Flag = "Two" })
booleans:SameLine()
booleans:AddCheckbox({ Name = "Three", Flag = "Three" })

-- Sliders ---------------------------------------------------------------
local sliders = controlsTab:AddGroup({ Name = "Sliders" })
sliders:AddSlider({ Name = "Integer", Min = 0, Max = 10, Default = 3, Flag = "SliderInt" })
sliders:AddSlider({ Name = "Float", Min = 0, Max = 1, Default = 0.25, Step = 0.01, Flag = "SliderFloat" })
sliders:AddSlider({ Name = "Volume", Min = 0, Max = 100, Default = 70, Suffix = "%", Flag = "Volume" })
sliders:AddSlider({
	Name = "Angle",
	Min = -180,
	Max = 180,
	Default = 0,
	Flag = "Angle",
	Format = function(value)
		return string.format("%d deg", value)
	end,
})

-- Dropdowns -------------------------------------------------------------
local dropdowns = controlsTab:AddGroup({ Name = "Dropdowns", Side = "Right" })
dropdowns:AddDropdown({
	Name = "Quality",
	Values = { "Low", "Medium", "High", "Ultra" },
	Default = "High",
	Flag = "Quality",
})
dropdowns:AddMultiDropdown({
	Name = "Layers",
	Values = { "Players", "NPCs", "Items", "Vehicles" },
	Default = { "Players" },
	Flag = "Layers",
	Tooltip = "Pick any number of values.",
})
local parts = {}
for index = 1, 40 do
	table.insert(parts, string.format("Part_%02d", index))
end
dropdowns:AddDropdown({
	Name = "Searchable",
	Values = parts,
	Searchable = true,
	Flag = "Part",
})
dropdowns:AddDropdown({
	Name = "Optional",
	Values = { "Alpha", "Beta" },
	AllowNone = true,
	Placeholder = "(none)",
	Flag = "Optional",
})

-- Inputs ----------------------------------------------------------------
local inputs = controlsTab:AddGroup({ Name = "Inputs", Side = "Right" })
inputs:AddInput({ Name = "Name", Placeholder = "Your name...", MaxLength = 20, Flag = "Name" })
inputs:AddInput({ Name = "Seed", Numeric = true, Min = 0, Max = 999999, Default = 1337, Flag = "Seed" })
inputs:AddInput({
	Name = "Tag",
	Placeholder = "3-8 letters",
	Flag = "Tag",
	Tooltip = "Rejected input flashes red.",
	Validate = function(text)
		return #text == 0 or (#text >= 3 and #text <= 8 and string.match(text, "^%a+$") ~= nil), "3-8 letters"
	end,
})
local liveEcho
inputs:AddInput({
	Name = "Live",
	Placeholder = "updates per keystroke",
	Finished = false,
	Save = false,
	Callback = function(text)
		liveEcho:SetText("Echo: " .. text)
	end,
})
liveEcho = inputs:AddLabel({ Text = "Echo: ", Style = "Secondary" })

-- Keybinds --------------------------------------------------------------
local keybinds = controlsTab:AddGroup({ Name = "Keybinds", Side = "Right" })
keybinds:AddKeybind({
	Name = "Toggle Fly",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
	Target = flyToggle,
	Flag = "FlyKey",
	Tooltip = "Drives the Fly toggle. Right-click for modes.",
})
keybinds:AddKeybind({
	Name = "Sprint (hold)",
	Default = Enum.KeyCode.LeftShift,
	Mode = "Hold",
	Flag = "SprintKey",
	Callback = function(active)
		window:SetStatus(active and "Sprinting" or "Ready")
	end,
})
keybinds:AddKeybind({
	Name = "Screenshot",
	Default = "P",
	Mode = "Press",
	Flag = "ScreenshotKey",
	Callback = function()
		Velumi:Notify({ Title = "Pressed", Description = "Press-mode keybind fired." })
	end,
})

-- Colors ----------------------------------------------------------------
local colors = controlsTab:AddGroup({ Name = "Colors" })
colors:AddColorPicker({ Name = "Primary", Default = Color3.fromRGB(76, 141, 255), Flag = "Primary" })
colors:AddColorPicker({
	Name = "Overlay",
	Default = Color3.fromRGB(224, 82, 82),
	Transparency = 0.35,
	Flag = "Overlay",
	Tooltip = "Includes a transparency bar.",
})

--------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------

local layoutTab = window:AddTab({ Name = "Layout", Columns = 2 })

local sameLine = layoutTab:AddGroup({ Name = "Same Line" })
sameLine:AddLabel({ Text = "Buttons share a row:", Style = "Secondary" })
sameLine:AddButton({ Name = "One" })
sameLine:SameLine()
sameLine:AddButton({ Name = "Two" })
sameLine:SameLine()
sameLine:AddButton({ Name = "Three" })
sameLine:AddLabel({ Text = "Fill widgets split the width:", Style = "Secondary" })
sameLine:AddSlider({ Name = "##x", Min = 0, Max = 1, Step = 0.01, Default = 0.2, Save = false })
sameLine:SameLine()
sameLine:AddSlider({ Name = "##y", Min = 0, Max = 1, Step = 0.01, Default = 0.8, Save = false })
sameLine:AddCheckbox({ Name = "Label", Save = false })
sameLine:SameLine()
sameLine:AddInput({ Name = "##inline", Placeholder = "inline input", Save = false })

sameLine:AddSeparator("Indentation")
sameLine:AddLabel("Level 0")
sameLine:Indent()
sameLine:AddLabel({ Text = "Level 1", Bullet = true })
sameLine:Indent()
sameLine:AddLabel({ Text = "Level 2", Bullet = true })
sameLine:Unindent()
sameLine:Unindent()

sameLine:AddSeparator("Disabled scope")
sameLine:BeginDisabled()
sameLine:AddCheckbox({ Name = "Disabled", Save = false })
sameLine:AddSlider({ Name = "Disabled", Min = 0, Max = 10, Default = 5, Save = false })
sameLine:EndDisabled()

local sections = layoutTab:AddGroup({ Name = "Sections" })
local header = sections:AddSection({ Name = "Collapsing Header" })
header:AddLabel("Content inside a collapsing header.")
header:AddCheckbox({ Name = "Nested option", Save = false })
local tree = sections:AddSection({ Name = "Tree Node", Style = "Tree", Open = false })
tree:AddLabel("Tree nodes indent their content.")
local subTree = tree:AddSection({ Name = "Child Node", Style = "Tree" })
subTree:AddLabel({ Text = "Deeply nested", Style = "Accent" })

local children = layoutTab:AddGroup({ Name = "Child Regions", Side = "Right" })
children:AddLabel({ Text = "A scrolling child with auto-scroll:", Style = "Secondary" })
local logRegion = children:BeginChild({ Name = "Log", Height = 110, AutoScroll = true })
children:AddLabel({ Text = "[00:00] Log started", Style = "Secondary" })
children:EndChild()
local lineCount = 0
children:AddButton({
	Name = "Add Line",
	Callback = function()
		lineCount += 1
		logRegion:AddLabel({ Text = string.format("[%05d] Event #%d", lineCount, lineCount) })
	end,
})
children:SameLine()
children:AddButton({
	Name = "Clear",
	Callback = function()
		logRegion:Clear()
		lineCount = 0
	end,
})

local dynamic = layoutTab:AddGroup({ Name = "Dynamic Content", Side = "Right" })
local list = dynamic:AddChild({ Name = "Items", Height = 90 })
local function renderList(count)
	list:Rebuild(function(container)
		for index = 1, count do
			container:AddLabel({ Text = `Item {index}`, Bullet = true })
		end
		if count == 0 then
			container:AddLabel({ Text = "(empty)", Style = "Disabled" })
		end
	end)
end
dynamic:AddSlider({
	Name = "Count",
	Min = 0,
	Max = 12,
	Default = 4,
	Save = false,
	Callback = renderList,
})
renderList(4)

--------------------------------------------------------------------------
-- Themes
--------------------------------------------------------------------------

local themesTab = window:AddTab({ Name = "Themes", Columns = 2 })

local themePicker = themesTab:AddGroup({ Name = "Theme" })
local themeDropdown = themePicker:AddDropdown({
	Name = "Theme",
	Values = Velumi:GetThemes(),
	Default = Velumi:GetTheme(),
	Save = false,
	Callback = function(name)
		if name then
			Velumi:SetTheme(name)
		end
	end,
})
themeConnection = Velumi.ThemeChanged:Connect(function(name)
	if alive and themeDropdown:GetValue() ~= name then
		if not table.find(themeDropdown:GetValues(), name) then
			themeDropdown:SetValues(Velumi:GetThemes())
		end
		themeDropdown:SetValue(name, true)
	end
end)

themePicker:AddColorPicker({
	Name = "Custom Accent",
	Default = Color3.fromRGB(255, 100, 150),
	Save = false,
	Tooltip = "Registers a theme with this accent; headers, grabs and title bars follow.",
	Callback = function(color)
		Velumi:RegisterTheme("Custom Accent", { Accent = color })
		Velumi:SetTheme("Custom Accent")
	end,
})
themePicker:AddParagraph({
	Text = "Themes only define a handful of core colors. Frames, headers, title bars and grabs are derived automatically.",
})

local display = themesTab:AddGroup({ Name = "Display", Side = "Right" })
display:AddSlider({
	Name = "UI Scale",
	Min = 0.6,
	Max = 1.5,
	Step = 0.05,
	Default = 1,
	Save = false,
	Callback = function(value)
		Velumi:SetScale(value)
	end,
})
display:AddCheckbox({
	Name = "Animations",
	Default = true,
	Save = false,
	Callback = function(value)
		Velumi:SetAnimationsEnabled(value)
	end,
})

local windows = themesTab:AddGroup({ Name = "Windows & Dialogs", Side = "Right" })
local extraWindow = nil
windows:AddButton({
	Name = "Open Inspector",
	Tooltip = "A second, independent tab-less window.",
	Callback = function()
		if extraWindow and not extraWindow:IsDestroyed() then
			extraWindow:SetVisible(true)
			extraWindow:Focus()
			return
		end
		extraWindow = Velumi:CreateWindow({
			Title = "Inspector",
			Size = Vector2.new(320, 260),
			Position = Vector2.new(60, 60),
			Center = false,
			Maximizable = false,
			DestroyOnClose = true,
		})
		local props = extraWindow:AddGroup({ Name = "Properties" })
		props:AddInput({ Name = "Name", Default = "Part", Save = false })
		props:AddSlider({ Name = "Transparency", Min = 0, Max = 1, Step = 0.05, Save = false })
		props:AddCheckbox({ Name = "Anchored", Default = true, Save = false })
		props:AddColorPicker({ Name = "Color", Default = Color3.fromRGB(163, 162, 165), Save = false })
	end,
})
windows:AddButton({
	Name = "Show Modal",
	Callback = function()
		Velumi:ShowModal({
			Title = "New Preset",
			Description = "Modal bodies are containers; any element works here.",
			Build = function(modal)
				modal:AddInput({ Name = "Preset Name", Flag = "PresetName", Default = "My Preset" })
				modal:AddCheckbox({ Name = "Set as default", Flag = "SetDefault" })
			end,
			Buttons = {
				"Cancel",
				{
					Name = "Create",
					Style = "Accent",
					Callback = function(modal)
						local values = modal:GetValues()
						Velumi:Notify({
							Title = "Created",
							Description = `Preset "{values.PresetName}"`,
							Type = "Success",
						})
					end,
				},
			},
		})
	end,
})
windows:AddButton({
	Name = "Confirm Dialog",
	Callback = function()
		Velumi:Confirm({
			Title = "Reset settings?",
			Description = "Every control goes back to its default value.",
			ConfirmText = "Reset",
			Danger = true,
			Callback = function(confirmed)
				if confirmed then
					window:ResetConfig()
				end
			end,
		})
	end,
})
windows:AddLabel({
	Text = "Right-click me for a context menu",
	Style = "Accent",
	ContextMenu = {
		{ Name = "Copy", Shortcut = "Ctrl+C", Callback = function() end },
		{ Name = "Paste", Shortcut = "Ctrl+V", Disabled = true },
		"-",
		{ Name = "More", Items = { { Name = "Nested A" }, { Name = "Nested B", Checked = true } } },
	},
})

--------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------

local configTab = window:AddTab({ Name = "Configuration", Columns = 2 })

local configActions = configTab:AddGroup({ Name = "Actions" })
configActions:AddParagraph({
	Text = "Every saveable control has a flag. GetConfig() returns plain JSON-safe data you can keep in memory, send to the server, or store in a DataStore.",
})
local jsonBox
configActions:AddButton({
	Name = "Save",
	Style = "Accent",
	Callback = function()
		savedConfig = window:GetConfig()
		Velumi:Notify({
			Title = "Saved",
			Description = "Configuration saved to memory.",
			Type = "Success",
			Duration = 2,
		})
	end,
})
configActions:SameLine()
configActions:AddButton({
	Name = "Load",
	Callback = function()
		if savedConfig then
			window:LoadConfig(savedConfig)
		end
	end,
})
configActions:SameLine()
configActions:AddButton({
	Name = "Reset",
	Callback = function()
		window:ResetConfig()
	end,
})
configActions:AddSeparator("JSON")
jsonBox = configActions:AddInput({ Name = "##json", Placeholder = "Exported JSON appears here", Save = false })
configActions:AddButton({
	Name = "Export",
	Callback = function()
		jsonBox:SetValue(window:ExportConfig(), true)
	end,
})
configActions:SameLine()
configActions:AddButton({
	Name = "Import",
	Callback = function()
		local count = window:ImportConfig(jsonBox:GetValue())
		Velumi:Notify({ Title = "Imported", Description = `{count} values applied.` })
	end,
})

local configState = configTab:AddGroup({ Name = "Live Values", Side = "Right" })
local changeCount = 0
local changeLabel = configState:AddLabel({ Text = "Changes: 0", Style = "Secondary" })
local lastChange = configState:AddLabel({ Text = "Last: -", Style = "Secondary" })
window.ConfigChanged:Connect(function(flag, value)
	changeCount += 1
	changeLabel:SetText(`Changes: {changeCount}`)
	lastChange:SetText(`Last: {flag} = {tostring(value)}`)
end)
local flagView = configState:AddChild({ Name = "Flags", Height = 180 })
configState:AddButton({
	Name = "Refresh",
	Callback = function()
		flagView:Rebuild(function(container)
			local flags = {}
			for flag in window.Values do
				table.insert(flags, flag)
			end
			table.sort(flags)
			for _, flag in flags do
				local value = window.Values[flag]
				if type(value) == "table" then
					value = "{" .. table.concat(value, ", ") .. "}"
				end
				container:AddLabel({ Text = `{flag} = {tostring(value)}` })
			end
		end)
	end,
})

--------------------------------------------------------------------------
-- Debug
--------------------------------------------------------------------------

local debugTab = window:AddTab({ Name = "Debug", Columns = 2 })

local perf = debugTab:AddGroup({ Name = "Performance" })
local fpsPlot = perf:AddPlot({
	Name = "Physics FPS",
	Min = 0,
	Max = 70,
	Format = function(v)
		return string.format("%.0f fps", v)
	end,
})
local memoryPlot = perf:AddPlot({
	Name = "Lua Heap",
	Type = "Histogram",
	Capacity = 30,
	Format = function(v)
		return string.format("%.1f MB", v)
	end,
})
local progress = perf:AddProgressBar({ Name = "Task", Default = 0 })

local stats = debugTab:AddGroup({ Name = "Library", Side = "Right" })
local windowCount = stats:AddLabel({ Text = "Windows: 1" })
local flagCount = stats:AddLabel({ Text = "Flags: 0" })
local themeLabel = stats:AddLabel({ Text = "Theme: Dark" })
stats:AddLabel({ Text = `Version: {Velumi.Version}`, Style = "Secondary" })
stats:AddSeparator()
stats:AddButton({
	Name = "Destroy Velumi",
	Style = "Danger",
	Confirm = true,
	Tooltip = "Tears down every window, popup, connection and tween.",
	Callback = function()
		Velumi:Destroy()
	end,
})

task.spawn(function()
	local elapsed = 0
	while alive do
		local dt = task.wait(0.25)
		if not alive then
			break
		end
		elapsed += dt
		fpsPlot:Push(workspace:GetRealPhysicsFPS())
		memoryPlot:Push(gcinfo() / 1024)
		progress:SetValue((elapsed % 5) / 5)

		local flags = 0
		for _ in window.Flags do
			flags += 1
		end
		windowCount:SetText(`Windows: {#Velumi:GetWindows()}`)
		flagCount:SetText(`Flags: {flags}`)
		themeLabel:SetText(`Theme: {Velumi:GetTheme()}`)
	end
end)
