--!strict
--[[
	Signal
	A small, dependency-free event implementation used for every public
	event in Velumi (element `Changed`, window `Closed`, and so on).

	Handlers are run on their own thread with `task.spawn`, so a handler that
	yields or errors never blocks or breaks the code that fired the signal.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false

	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_handlers = {},
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect(self: any, handler: (...any) -> ()): Connection
	assert(type(handler) == "function", "Signal:Connect expects a function")

	local connection = setmetatable({
		Connected = true,
		_signal = self,
		_handler = handler,
	}, Connection)

	table.insert(self._handlers, connection)
	return (connection :: any) :: Connection
end

function Signal.Once(self: any, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = Signal.Connect(self, function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	Signal.Once(self, function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.Fire(self: any, ...: any)
	local handlers = self._handlers
	if #handlers == 0 then
		return
	end

	-- Snapshot so handlers may connect/disconnect while we iterate.
	for _, connection in table.clone(handlers) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
