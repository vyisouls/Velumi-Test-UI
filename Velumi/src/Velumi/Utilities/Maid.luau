--[[
	Maid
	Owns "tasks" (connections, instances, tweens, threads, functions and
	objects with Destroy/Disconnect) and releases all of them in one call.

	Every Velumi object (window, tab, group, element, popup) owns exactly one
	Maid. Destroying the object cleans its Maid, and parent Maids own their
	children's objects, so destruction cascades without leaks.

	    local maid = Maid.new()
	    maid:Give(button.Activated:Connect(onClick))
	    maid:Give(frame)
	    maid.Hover = tween           -- named task, replaced tasks are cleaned
	    maid:Clean()
]]

local Maid = {}

local function cleanupTask(job: any)
	local kind = typeof(job)

	if kind == "RBXScriptConnection" then
		job:Disconnect()
	elseif kind == "Instance" then
		if job:IsA("Tween") then
			job:Cancel()
		end
		job:Destroy()
	elseif kind == "function" then
		job()
	elseif kind == "thread" then
		if coroutine.status(job) ~= "dead" and job ~= coroutine.running() then
			pcall(task.cancel, job)
		end
	elseif kind == "table" then
		if type(job.Destroy) == "function" then
			job:Destroy()
		elseif type(job.Disconnect) == "function" then
			job:Disconnect()
		elseif type(job.Clean) == "function" then
			job:Clean()
		end
	end
end

Maid.__index = function(self, key)
	if Maid[key] ~= nil then
		return Maid[key]
	end
	return rawget(self, "_named")[key]
end

Maid.__newindex = function(self, key, value)
	local named = rawget(self, "_named")
	local previous = named[key]
	if previous == value then
		return
	end
	named[key] = value
	if previous ~= nil then
		cleanupTask(previous)
	end
end

function Maid.new()
	return setmetatable({
		_tasks = {},
		_named = {},
		_cleaning = false,
	}, Maid)
end

--- Gives a task to the maid. Returns the task so calls can be chained:
--- `local frame = maid:Give(Instance.new("Frame"))`
function Maid:Give<T>(job: T): T
	if job == nil then
		return job
	end
	if rawget(self, "_cleaning") then
		-- A task given while cleaning is cleaned immediately.
		cleanupTask(job)
		return job
	end
	table.insert(rawget(self, "_tasks"), job)
	return job
end

--- Cleans and forgets a single named task.
function Maid:Remove(key: string)
	local named = rawget(self, "_named")
	local job = named[key]
	if job ~= nil then
		named[key] = nil
		cleanupTask(job)
	end
end

--- Cleans every task. The maid can be reused afterwards.
function Maid:Clean()
	if rawget(self, "_cleaning") then
		return
	end
	rawset(self, "_cleaning", true)

	local named = rawget(self, "_named")
	for key, job in named do
		named[key] = nil
		cleanupTask(job)
	end

	local tasks = rawget(self, "_tasks")
	-- Clean in reverse order: things created last are torn down first.
	for index = #tasks, 1, -1 do
		local job = tasks[index]
		tasks[index] = nil
		cleanupTask(job)
	end

	rawset(self, "_cleaning", false)
end

Maid.Destroy = Maid.Clean
Maid.Cleanup = cleanupTask

return Maid
