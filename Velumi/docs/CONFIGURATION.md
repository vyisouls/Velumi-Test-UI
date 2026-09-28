# Configuration

Velumi keeps track of the values of every **saveable** element. It can serialize them to plain data and apply that data back later. The library never reads or writes files. What you do with the data is up to you: keep it in memory, send it to the server, or store it in a DataStore.

Saveable elements: **Checkbox, Toggle, Slider, Dropdown, MultiDropdown, Input, Keybind, ColorPicker**, plus custom elements with `Saveable = true`.

## Flags

Each saveable element registers under a flag in its window's configuration:

| How | Example flag |
| --- | --- |
| Explicit `Flag` option (recommended for anything you persist) | `"WalkSpeed"` |
| Implicit: `"<Tab>/<Group>/<Name>"` | `"Main/General/Walk Speed"` |
| Duplicate implicit flags get a suffix and a warning | `"Main/General/Enabled#2"` |
| `Save = false` excludes the element | — |

Implicit flags change when you rename a tab, group or element, so use explicit flags for data you store long term.

Sections and child regions don't add a path segment, so moving an element into a section keeps its flag.

## Reading values

```lua
local speed = Window.Values.WalkSpeed             -- live value by flag
local element = Window:GetFlag("WalkSpeed")       -- the element itself
element:SetValue(24)

Window.ConfigChanged:Connect(function(flag, value, element)
	print(flag, "=", value)
end)
```

`Window.Values` is updated every time a value changes, including silent changes. `ConfigChanged` fires only for non-silent changes.

## Saving and loading

```lua
local data = Window:GetConfig()
--> {
-->     Version = 1,
-->     Values = {
-->         WalkSpeed = 16,
-->         Enabled = true,
-->         Mode = "Default",
-->         Layers = { "Players", "Items" },
-->         FlyKey = { Key = "F", Mode = "Toggle" },
-->         Tint = { Color = "4C8DFF", Transparency = 0 },
-->     },
--> }

local applied = Window:LoadConfig(data)   --> number of values applied
```

When loading:

- Flags that don't exist in the window are ignored, so old configs keep working.
- Elements missing from the data keep their current value.
- Values are applied through `SetValue`, so `Callback` and `Changed` fire for every value that changes and your game state stays in sync.
- A bare `{ [flag] = value }` table is accepted too.

### JSON

```lua
local json = Window:ExportConfig()        -- HttpService:JSONEncode(GetConfig())
local applied = Window:ImportConfig(json) -- invalid JSON warns and returns 0
```

`JSONEncode` and `JSONDecode` work without enabling HTTP requests.

### Reset

```lua
Window:ResetConfig()   -- every saveable element back to its Default
```

## Serialized formats

| Element | Stored as |
| --- | --- |
| Checkbox, Toggle | `boolean` |
| Slider | `number` |
| Dropdown | `string` or `nil` |
| MultiDropdown | array of strings |
| Input | `string`, or `number` when `Numeric` |
| Keybind | `{ Key = "F", Mode = "Toggle" }` |
| ColorPicker | `{ Color = "RRGGBB", Transparency = number }` |

## Persisting with DataStores

DataStores only work on the server, so send the config there through a RemoteEvent. Here is a minimal pair of scripts.

**Server** (`ServerScriptService/VelumiSettings.server.luau`):

```lua
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local store = DataStoreService:GetDataStore("VelumiSettings")

local save = Instance.new("RemoteEvent")
save.Name = "SaveSettings"
save.Parent = ReplicatedStorage

local load = Instance.new("RemoteFunction")
load.Name = "LoadSettings"
load.Parent = ReplicatedStorage

save.OnServerEvent:Connect(function(player, json)
	if type(json) ~= "string" or #json > 50_000 then
		return
	end
	pcall(store.SetAsync, store, tostring(player.UserId), json)
end)

load.OnServerInvoke = function(player)
	local ok, json = pcall(store.GetAsync, store, tostring(player.UserId))
	return ok and json or nil
end
```

**Client** (inside your Velumi LocalScript):

```lua
local saveRemote = ReplicatedStorage:WaitForChild("SaveSettings")
local loadRemote = ReplicatedStorage:WaitForChild("LoadSettings")

local json = loadRemote:InvokeServer()
if json then
	Window:ImportConfig(json)
end

Window:AddMenu("File", {
	{ Name = "Save Settings", Callback = function()
		saveRemote:FireServer(Window:ExportConfig())
		Velumi:Notify({ Title = "Saved", Type = "Success" })
	end },
})
```

Treat data that comes from clients as untrusted. Validate it on the server before you use it for anything beyond restoring the player's own UI.

## Bound tables

As an alternative to callbacks, `Bind` keeps a field of your own table in sync with an element:

```lua
local Settings = { WalkSpeed = 16 }

Group:AddSlider({ Name = "Walk Speed", Min = 0, Max = 100, Bind = { Settings, "WalkSpeed" } })
-- or Bind = { Table = Settings, Key = "WalkSpeed" }
```

- If the table already has a value for the key, it becomes the element's `Default`.
- User changes, `SetValue` and `LoadConfig` all write to the table.
- After you change the table in code, call `element:Sync()` or `Window:Sync()` to update the UI (silently).

Binding and flags are independent. A bound element is still saved unless `Save = false`.

## Modals

Elements inside a modal dialog are not part of any window configuration. Give them a `Flag` and read them with `modal:GetValues()`.
