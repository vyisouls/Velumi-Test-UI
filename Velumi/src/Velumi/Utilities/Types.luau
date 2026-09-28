--!strict
--[[
	Types
	Public Luau types for Velumi. They drive autocomplete in Roblox Studio and
	can be used in your own annotations:

	    local Velumi = require(ReplicatedStorage.Velumi)
	    local window: Velumi.Window = Velumi:CreateWindow({ Title = "Tools" })
]]

--------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------

export type Connection = {
	Connected: boolean,
	Disconnect: (self: any) -> (),
}

export type Signal<T...> = {
	Connect: (self: any, handler: (T...) -> ()) -> Connection,
	Once: (self: any, handler: (T...) -> ()) -> Connection,
	Wait: (self: any) -> T...,
	Fire: (self: any, T...) -> (),
	DisconnectAll: (self: any) -> (),
	Destroy: (self: any) -> (),
}

--------------------------------------------------------------------------
-- Themes
--------------------------------------------------------------------------

export type ThemeDefinition = {
	-- Core colors (required for a theme without a base).
	Background: Color3?,
	Window: Color3?,
	Child: Color3?,
	Border: Color3?,
	Text: Color3?,
	SecondaryText: Color3?,
	DisabledText: Color3?,
	Hover: Color3?,
	Active: Color3?,
	Accent: Color3?,
	Success: Color3?,
	Warning: Color3?,
	Error: Color3?,

	-- Frequently overridden derived colors.
	Frame: Color3?,
	FrameHover: Color3?,
	FrameActive: Color3?,
	Button: Color3?,
	ButtonHover: Color3?,
	ButtonActive: Color3?,
	Header: Color3?,
	HeaderHover: Color3?,
	HeaderActive: Color3?,
	TitleBar: Color3?,
	TitleBarActive: Color3?,
	Popup: Color3?,
	Tooltip: Color3?,

	-- Non-color style values.
	Font: Font?,
	TextSize: number?,
	Rounding: number?,
	WindowRounding: number?,
	WindowTransparency: number?,
	ModalDimTransparency: number?,

	[string]: any,
}

--------------------------------------------------------------------------
-- Menus
--------------------------------------------------------------------------

export type MenuItem = {
	Name: string?,
	Callback: (() -> ())?,
	Shortcut: string?,
	Checked: boolean?,
	Disabled: boolean?,
	Items: { MenuItem | string }?,
	Separator: boolean?,
}

export type MenuItems = { MenuItem | string }

export type Menu = {
	Name: string,
	Items: MenuItems,
	SetItems: (self: any, items: MenuItems) -> (),
	Destroy: (self: any) -> (),
}

--------------------------------------------------------------------------
-- Element options
--------------------------------------------------------------------------

export type Binding = { any } | { Table: { [any]: any }, Key: any }

export type BaseOptions = {
	Name: string?,
	Tooltip: string?,
	Disabled: boolean?,
	Visible: boolean?,
	ContextMenu: (MenuItems | ((element: any) -> MenuItems))?,
}

export type ValueOptions<T, C> = BaseOptions & {
	Default: T?,
	Callback: C?,
	Flag: string?,
	Save: boolean?,
	Bind: Binding?,
}

export type ButtonOptions = BaseOptions & {
	Text: string?,
	Callback: (() -> ())?,
	Style: ("Default" | "Accent" | "Danger")?,
	FullWidth: boolean?,
	Width: number?,
	Confirm: boolean?,
	ConfirmText: string?,
}

export type CheckboxOptions = ValueOptions<boolean, (value: boolean) -> ()>
export type ToggleOptions = ValueOptions<boolean, (value: boolean) -> ()>

export type SliderOptions = ValueOptions<number, (value: number) -> ()> & {
	Min: number?,
	Max: number?,
	Step: number?,
	Decimals: number?,
	Prefix: string?,
	Suffix: string?,
	Format: ((value: number) -> string)?,
}

export type DropdownOptions = ValueOptions<string, (value: string?) -> ()> & {
	Values: { string }?,
	AllowNone: boolean?,
	Searchable: boolean?,
	Placeholder: string?,
	MaxVisible: number?,
	Multi: boolean?,
}

export type MultiDropdownOptions = ValueOptions<{ string }, (values: { string }) -> ()> & {
	Values: { string }?,
	Searchable: boolean?,
	Placeholder: string?,
	MaxVisible: number?,
}

export type InputOptions = ValueOptions<string | number, (value: any) -> ()> & {
	Placeholder: string?,
	Numeric: boolean?,
	Min: number?,
	Max: number?,
	MaxLength: number?,
	Validate: ((value: any) -> (boolean, string?))?,
	Finished: boolean?,
	ClearOnFocus: boolean?,
}

export type KeybindMode = "Toggle" | "Hold" | "Press" | "Always"

export type KeybindOptions = BaseOptions & {
	Default: (Enum.KeyCode | Enum.UserInputType | string)?,
	Mode: KeybindMode?,
	Callback: ((active: boolean) -> ())?,
	ChangedCallback: ((key: string) -> ())?,
	Target: any?,
	LockMode: boolean?,
	Flag: string?,
	Save: boolean?,
}

export type ColorPickerOptions = ValueOptions<Color3 | string, (color: Color3, transparency: number) -> ()> & {
	Transparency: number?,
}

export type LabelStyle = "Default" | "Secondary" | "Disabled" | "Accent" | "Success" | "Warning" | "Error"

export type LabelOptions = BaseOptions & {
	Text: string?,
	Style: LabelStyle?,
	Color: Color3?,
	Bullet: boolean?,
	Wrap: boolean?,
	Align: ("Left" | "Center" | "Right")?,
	RichText: boolean?,
}

export type ParagraphOptions = BaseOptions & {
	Title: string?,
	Text: string?,
	RichText: boolean?,
}

export type SeparatorOptions = {
	Text: string?,
	Visible: boolean?,
}

export type ProgressBarOptions = BaseOptions & {
	Default: number?,
	Format: ((value: number) -> string)?,
	Style: ("Accent" | "Success" | "Warning" | "Error")?,
}

export type PlotOptions = BaseOptions & {
	Type: ("Lines" | "Histogram")?,
	Values: { number }?,
	Capacity: number?,
	Min: number?,
	Max: number?,
	Height: number?,
	Format: ((value: number) -> string)?,
}

--------------------------------------------------------------------------
-- Elements
--------------------------------------------------------------------------

export type Element<T> = {
	Kind: string,
	Name: string,
	Text: string,
	Flag: string?,
	Root: GuiObject,
	Value: T,
	Default: T?,
	Changed: Signal<...any>,

	GetValue: (self: any) -> T,
	SetValue: (self: any, value: T, silent: boolean?) -> (),
	Reset: (self: any, silent: boolean?) -> (),
	Sync: (self: any) -> (),
	OnChanged: (self: any, handler: (...any) -> ()) -> Connection,
	SetCallback: (self: any, callback: ((...any) -> ())?) -> (),
	SetVisible: (self: any, visible: boolean) -> (),
	IsVisible: (self: any) -> boolean,
	SetDisabled: (self: any, disabled: boolean) -> (),
	IsDisabled: (self: any) -> boolean,
	SetText: (self: any, text: string) -> (),
	GetText: (self: any) -> string,
	SetTooltip: (self: any, text: string?) -> (),
	SetContextMenu: (self: any, items: (MenuItems | ((element: any) -> MenuItems))?) -> (),
	IsDestroyed: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

export type Button = Element<nil> & {
	Pressed: Signal<()>,
	Press: (self: any) -> (),
	SetStyle: (self: any, style: "Default" | "Accent" | "Danger") -> (),
}

export type Checkbox = Element<boolean> & {
	Toggle: (self: any) -> (),
}

export type Toggle = Element<boolean> & {
	Toggle: (self: any) -> (),
}

export type Slider = Element<number> & {
	SetMin: (self: any, min: number) -> (),
	SetMax: (self: any, max: number) -> (),
	SetRange: (self: any, min: number, max: number) -> (),
	SetStep: (self: any, step: number) -> (),
	GetRange: (self: any) -> (number, number),
}

export type Dropdown = Element<string?> & {
	SetValues: (self: any, values: { string }) -> (),
	GetValues: (self: any) -> { string },
	AddValue: (self: any, value: string) -> (),
	RemoveValue: (self: any, value: string) -> (),
	IsSelected: (self: any, value: string) -> boolean,
	Open: (self: any) -> (),
	Close: (self: any) -> (),
	IsOpen: (self: any) -> boolean,
}

export type MultiDropdown = Element<{ string }> & {
	SetValues: (self: any, values: { string }) -> (),
	GetValues: (self: any) -> { string },
	AddValue: (self: any, value: string) -> (),
	RemoveValue: (self: any, value: string) -> (),
	IsSelected: (self: any, value: string) -> boolean,
	Open: (self: any) -> (),
	Close: (self: any) -> (),
	IsOpen: (self: any) -> boolean,
}

export type Input = Element<string | number> & {
	Invalid: Signal<string, string?>,
	SetPlaceholder: (self: any, text: string) -> (),
	Focus: (self: any) -> (),
}

export type Keybind = Element<string> & {
	Activated: Signal<boolean>,
	GetState: (self: any) -> boolean,
	SetMode: (self: any, mode: KeybindMode) -> (),
	GetMode: (self: any) -> KeybindMode,
}

export type ColorPicker = Element<Color3> & {
	GetTransparency: (self: any) -> number,
	SetTransparency: (self: any, transparency: number, silent: boolean?) -> (),
	GetHex: (self: any) -> string,
	Open: (self: any) -> (),
	Close: (self: any) -> (),
	IsOpen: (self: any) -> boolean,
}

export type Label = Element<string> & {
	SetStyle: (self: any, style: LabelStyle) -> (),
	SetColor: (self: any, color: Color3?) -> (),
}

export type Paragraph = Element<string> & {
	SetTitle: (self: any, title: string?) -> (),
}

export type Separator = Element<string>

export type ProgressBar = Element<number>

export type Plot = Element<number?> & {
	Push: (self: any, value: number) -> (),
	SetValues: (self: any, values: { number }) -> (),
	GetValues: (self: any) -> { number },
	Clear: (self: any) -> (),
}

--------------------------------------------------------------------------
-- Containers
--------------------------------------------------------------------------

export type SectionOptions = {
	Name: string?,
	Open: boolean?,
	Style: ("Header" | "Tree")?,
}

export type ChildOptions = {
	Name: string?,
	Height: number?,
	Border: boolean?,
	AutoScroll: boolean?,
}

export type Container = {
	AddButton: (self: any, options: ButtonOptions | string) -> Button,
	AddCheckbox: (self: any, options: CheckboxOptions | string) -> Checkbox,
	AddToggle: (self: any, options: ToggleOptions | string) -> Toggle,
	AddSlider: (self: any, options: SliderOptions | string) -> Slider,
	AddDropdown: (self: any, options: DropdownOptions | string) -> Dropdown,
	AddMultiDropdown: (self: any, options: MultiDropdownOptions | string) -> MultiDropdown,
	AddInput: (self: any, options: InputOptions | string) -> Input,
	AddKeybind: (self: any, options: KeybindOptions | string) -> Keybind,
	AddColorPicker: (self: any, options: ColorPickerOptions | string) -> ColorPicker,
	AddLabel: (self: any, options: LabelOptions | string) -> Label,
	AddParagraph: (self: any, options: ParagraphOptions) -> Paragraph,
	AddSeparator: (self: any, options: (SeparatorOptions | string)?) -> Separator,
	AddProgressBar: (self: any, options: ProgressBarOptions | string) -> ProgressBar,
	AddPlot: (self: any, options: PlotOptions | string) -> Plot,

	AddSection: (self: any, options: SectionOptions | string) -> Section,
	AddChild: (self: any, options: (ChildOptions | string)?) -> Child,
	BeginChild: (self: any, options: (ChildOptions | string)?) -> Child,
	EndChild: (self: any) -> (),

	SameLine: (self: any) -> any,
	AddSpacing: (self: any, pixels: number?) -> any,
	Indent: (self: any, pixels: number?) -> any,
	Unindent: (self: any, pixels: number?) -> any,
	BeginDisabled: (self: any) -> any,
	EndDisabled: (self: any) -> any,

	GetElements: (self: any) -> { any },
	Clear: (self: any) -> (),
	Rebuild: (self: any, build: (container: any) -> ()) -> (),
}

export type Section = Container & {
	Name: string,
	Toggled: Signal<boolean>,
	SetOpen: (self: any, open: boolean) -> (),
	IsOpen: (self: any) -> boolean,
	Toggle: (self: any) -> (),
	SetText: (self: any, text: string) -> (),
	SetVisible: (self: any, visible: boolean) -> (),
	IsVisible: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

export type Child = Container & {
	Name: string,
	SetHeight: (self: any, height: number) -> (),
	ScrollToTop: (self: any) -> (),
	ScrollToBottom: (self: any) -> (),
	SetVisible: (self: any, visible: boolean) -> (),
	IsVisible: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

export type GroupOptions = {
	Name: string?,
	Side: ("Left" | "Right")?,
	Column: number?,
	Collapsible: boolean?,
	Collapsed: boolean?,
	Border: boolean?,
}

export type Group = Container & {
	Name: string,
	Tab: Tab,
	SetText: (self: any, text: string) -> (),
	SetTitle: (self: any, text: string) -> (),
	SetCollapsed: (self: any, collapsed: boolean) -> (),
	IsCollapsed: (self: any) -> boolean,
	SetVisible: (self: any, visible: boolean) -> (),
	IsVisible: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

export type TabOptions = {
	Name: string?,
	Columns: number?,
	Visible: boolean?,
	Selected: boolean?,
}

export type Tab = {
	Name: string,
	Groups: { Group },
	AddGroup: (self: any, options: GroupOptions | string) -> Group,
	GetGroup: (self: any, name: string) -> Group?,
	Select: (self: any) -> (),
	IsSelected: (self: any) -> boolean,
	SetText: (self: any, text: string) -> (),
	SetVisible: (self: any, visible: boolean) -> (),
	IsVisible: (self: any) -> boolean,
	ScrollToTop: (self: any) -> (),
	Destroy: (self: any) -> (),
}

--------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------

export type ConfigData = {
	Version: number,
	Values: { [string]: any },
}

--------------------------------------------------------------------------
-- Windows
--------------------------------------------------------------------------

export type WindowOptions = {
	Title: string?,
	Size: (UDim2 | Vector2)?,
	Position: (UDim2 | Vector2)?,
	Center: boolean?,
	MinSize: Vector2?,
	MaxSize: Vector2?,
	Visible: boolean?,
	Resizable: boolean?,
	Draggable: boolean?,
	Closable: boolean?,
	Minimizable: boolean?,
	Maximizable: boolean?,
	DestroyOnClose: boolean?,
	OnClose: ((window: Window) -> ())?,
	TabStyle: ("Sidebar" | "Top")?,
	SidebarWidth: number?,
	StatusBar: (boolean | string)?,
	ToggleKey: (Enum.KeyCode | string)?,
	Scale: number?,
	AutoScale: boolean?,
	ImplicitTab: TabOptions?,
}

export type Window = {
	Title: string,
	Root: Frame,
	Tabs: { Tab },
	SelectedTab: Tab?,
	Values: { [string]: any },
	Flags: { [string]: any },

	Closed: Signal<()>,
	Destroyed: Signal<()>,
	VisibilityChanged: Signal<boolean>,
	FocusChanged: Signal<boolean>,
	TabChanged: Signal<Tab, Tab?>,
	ConfigChanged: Signal<string, any, any>,

	AddTab: (self: any, options: TabOptions | string) -> Tab,
	AddGroup: (self: any, options: GroupOptions | string) -> Group,
	SelectTab: (self: any, tab: Tab | string) -> (),
	GetTab: (self: any, name: string) -> Tab?,

	AddMenu: (self: any, name: string, items: MenuItems) -> Menu,
	SetStatus: (self: any, left: string?, right: string?) -> (),

	SetVisible: (self: any, visible: boolean) -> (),
	IsVisible: (self: any) -> boolean,
	Toggle: (self: any) -> (),
	Close: (self: any) -> (),
	Focus: (self: any) -> (),
	IsFocused: (self: any) -> boolean,
	Minimize: (self: any) -> (),
	Maximize: (self: any) -> (),
	Restore: (self: any) -> (),
	IsMinimized: (self: any) -> boolean,
	IsMaximized: (self: any) -> boolean,
	Center: (self: any) -> (),
	SetTitle: (self: any, title: string) -> (),
	SetSize: (self: any, size: UDim2 | Vector2) -> (),
	GetSize: (self: any) -> Vector2,
	SetPosition: (self: any, position: UDim2 | Vector2) -> (),
	GetPosition: (self: any) -> Vector2,
	SetMinSize: (self: any, size: Vector2) -> (),
	SetMaxSize: (self: any, size: Vector2) -> (),
	SetResizable: (self: any, resizable: boolean) -> (),
	SetDraggable: (self: any, draggable: boolean) -> (),
	SetScale: (self: any, scale: number) -> (),
	GetScale: (self: any) -> number,
	GetEffectiveScale: (self: any) -> number,
	SetToggleKey: (self: any, key: (Enum.KeyCode | string)?) -> (),

	GetConfig: (self: any) -> ConfigData,
	LoadConfig: (self: any, data: ConfigData | { [string]: any }) -> number,
	ExportConfig: (self: any) -> string,
	ImportConfig: (self: any, json: string) -> number,
	ResetConfig: (self: any) -> (),
	GetFlag: (self: any, flag: string) -> any,
	ForEachElement: (self: any, callback: (element: any) -> ()) -> (),
	Sync: (self: any) -> (),

	Notify: (self: any, options: NotifyOptions) -> Notification,
	IsDestroyed: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

--------------------------------------------------------------------------
-- Components
--------------------------------------------------------------------------

export type NotificationType = "Info" | "Success" | "Warning" | "Error"

export type NotifyOptions = {
	Title: string?,
	Description: string?,
	Type: NotificationType?,
	Duration: number?,
}

export type Notification = {
	Closed: Signal<()>,
	Close: (self: any) -> (),
	SetTitle: (self: any, text: string) -> (),
	SetDescription: (self: any, text: string) -> (),
}

export type ModalButton = string | {
	Name: string,
	Style: ("Default" | "Accent" | "Danger")?,
	Width: number?,
	Callback: ((modal: Modal) -> ())?,
	Close: boolean?,
}

export type ModalOptions = {
	Title: string?,
	Description: string?,
	Width: number?,
	Buttons: { ModalButton }?,
	Build: ((modal: Modal) -> ())?,
	Closable: boolean?,
	OnClose: ((result: string?) -> ())?,
}

export type Modal = Container & {
	Closed: Signal<string?>,
	GetValues: (self: any) -> { [string]: any },
	Close: (self: any, result: string?) -> (),
	IsOpen: (self: any) -> boolean,
	Destroy: (self: any) -> (),
}

export type ConfirmOptions = {
	Title: string?,
	Description: string?,
	ConfirmText: string?,
	CancelText: string?,
	Danger: boolean?,
	Callback: (confirmed: boolean) -> (),
}

export type ContextMenuHandle = {
	Frame: Frame,
	Close: () -> (),
}

return {}
