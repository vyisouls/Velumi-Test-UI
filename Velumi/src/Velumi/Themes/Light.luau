--[[
	Light — a bright, low-contrast-border theme for well-lit screens.
	Mirrors the structure of Dark; derived keys adapt automatically.
]]

return {
	Background = Color3.fromRGB(226, 226, 226),
	Window = Color3.fromRGB(240, 240, 240),
	Child = Color3.fromRGB(232, 232, 232),

	Border = Color3.fromRGB(196, 196, 196),

	Text = Color3.fromRGB(28, 28, 28),
	SecondaryText = Color3.fromRGB(92, 92, 92),
	DisabledText = Color3.fromRGB(160, 160, 160),

	Hover = Color3.fromRGB(216, 216, 216),
	Active = Color3.fromRGB(202, 202, 202),

	Accent = Color3.fromRGB(46, 110, 230),

	Success = Color3.fromRGB(46, 145, 72),
	Warning = Color3.fromRGB(190, 128, 20),
	Error = Color3.fromRGB(200, 55, 55),

	-- Derived defaults are tuned for dark themes; a few read better
	-- when set explicitly on a light background.
	Frame = Color3.fromRGB(252, 252, 252),
	FrameHover = Color3.fromRGB(236, 241, 250),
	FrameActive = Color3.fromRGB(222, 232, 250),
	Button = Color3.fromRGB(226, 226, 226),
	TitleBar = Color3.fromRGB(214, 214, 214),
	TitleBarActive = Color3.fromRGB(190, 208, 240),
	Tooltip = Color3.fromRGB(250, 250, 250),
	Popup = Color3.fromRGB(250, 250, 250),
	ScrollBar = Color3.fromRGB(184, 184, 184),
	ModalDimTransparency = 0.65,
}
