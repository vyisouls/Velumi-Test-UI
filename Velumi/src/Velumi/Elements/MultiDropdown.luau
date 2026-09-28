--[[
	MultiDropdown
	A Dropdown that allows several values to be selected. Selected rows show
	a check mark and the popup stays open while you pick.

	    group:AddMultiDropdown({
	        Name = "Layers",
	        Values = { "Players", "NPCs", "Items" },
	        Default = { "Players" },
	        Callback = function(selected) print(table.concat(selected, ", ")) end,
	    })

	Accepts the same options and methods as Dropdown.
	Value: { string } — selected values, in `Values` order.
	Also accepts a set `{ Players = true }` in SetValue / Default.
]]

local Dropdown = require(script.Parent.Dropdown)

local MultiDropdown = setmetatable({}, { __index = Dropdown })
MultiDropdown.__index = MultiDropdown
MultiDropdown.Kind = "MultiDropdown"

function MultiDropdown:_build()
	self.Options.Multi = true
	Dropdown._build(self)
end

return MultiDropdown
