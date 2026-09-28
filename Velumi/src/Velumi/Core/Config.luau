--[[
	Config
	Per-window configuration state. Every saveable element (checkbox,
	toggle, slider, dropdown, multi dropdown, input, keybind, color picker)
	registers here under a *flag*.

	Flags
	-----
	• Explicit:  `Flag = "WalkSpeed"` in the element options.
	• Implicit:  "<Tab>/<Group>/<Name>" — stable as long as names don't change.
	  Duplicates get a numeric suffix ("Main/General/Enabled#2") and a warning.
	• Opt out:   `Save = false`.

	Data format
	-----------
	    {
	        Version = 1,
	        Values = { [flag] = <JSON-safe value> },
	    }

	The table is plain data: store it in a DataStore via a RemoteEvent, encode
	it with `Window:ExportConfig()` / `Window:ImportConfig(json)`, or keep it
	in memory. The library itself never touches the filesystem.
]]

local HttpService = game:GetService("HttpService")

local Signal = require(script.Parent.Parent.Utilities.Signal)
local Utility = require(script.Parent.Parent.Utilities.Utility)

local Config = {}
Config.__index = Config

Config.FormatVersion = 1

export type Data = {
	Version: number,
	Values: { [string]: any },
}

function Config.new(window: any)
	local self = setmetatable({}, Config)
	self.Window = window
	self.Flags = {} :: { [string]: any } -- flag -> element
	self.Values = {} :: { [string]: any } -- flag -> live value
	self.Changed = Signal.new() -- (flag, value, element)
	self._order = {} :: { string }
	return self
end

--- Registers an element and assigns its flag.
function Config:Register(element: any, flag: string?)
	local base = flag
	if base == nil or base == "" then
		local path = element.Container and element.Container._path or "Window"
		base = `{path}/{element.Name}`
	end

	local unique = base
	if self.Flags[unique] then
		local suffix = 2
		while self.Flags[`{base}#{suffix}`] do
			suffix += 1
		end
		unique = `{base}#{suffix}`
		Utility.Warn(`Duplicate flag "{base}" — using "{unique}". Give the element an explicit Flag to silence this.`)
	end

	element.Flag = unique
	self.Flags[unique] = element
	self.Values[unique] = element:GetValue()
	table.insert(self._order, unique)
end

function Config:Unregister(element: any)
	local flag = element.Flag
	if flag and self.Flags[flag] == element then
		self.Flags[flag] = nil
		self.Values[flag] = nil
		local index = table.find(self._order, flag)
		if index then
			table.remove(self._order, index)
		end
	end
end

--- Called by elements whenever their value changes.
function Config:_valueChanged(element: any, silent: boolean?)
	local flag = element.Flag
	if not flag or self.Flags[flag] ~= element then
		return
	end
	self.Values[flag] = element:GetValue()
	if not silent then
		self.Changed:Fire(flag, element:GetValue(), element)
	end
end

function Config:Get(flag: string): any
	return self.Flags[flag]
end

--- Serializes every registered element into plain, JSON-safe data.
function Config:Serialize(): Data
	local values = {}
	for _, flag in self._order do
		local element = self.Flags[flag]
		if element then
			local ok, value = pcall(element._serialize, element)
			if ok then
				values[flag] = value
			else
				Utility.Warn(`Could not serialize "{flag}": {value}`)
			end
		end
	end
	return {
		Version = Config.FormatVersion,
		Values = values,
	}
end

--- Applies previously serialized data. Unknown flags are ignored, and
--- elements missing from `data` keep their current value. Callbacks fire for
--- values that change. Returns the number of values applied.
function Config:Load(data: Data): number
	if type(data) ~= "table" then
		Utility.Warn("LoadConfig expects a table")
		return 0
	end
	local values = data.Values
	if type(values) ~= "table" then
		-- Accept a bare { flag = value } table too.
		values = data
	end

	local applied = 0
	for _, flag in table.clone(self._order) do
		local value = values[flag]
		local element = self.Flags[flag]
		if value ~= nil and element and not element:IsDestroyed() then
			local ok, err = pcall(element._deserialize, element, value)
			if ok then
				applied += 1
			else
				Utility.Warn(`Could not load "{flag}": {err}`)
			end
		end
	end
	return applied
end

--- Resets every registered element to its Default.
function Config:Reset()
	for _, flag in table.clone(self._order) do
		local element = self.Flags[flag]
		if element then
			element:Reset()
		end
	end
end

function Config:Export(): string
	return HttpService:JSONEncode(self:Serialize())
end

function Config:Import(json: string): number
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		Utility.Warn("ImportConfig: invalid JSON")
		return 0
	end
	return self:Load(data)
end

function Config:Destroy()
	self.Changed:Destroy()
	table.clear(self.Flags)
	table.clear(self.Values)
	table.clear(self._order)
end

return Config
