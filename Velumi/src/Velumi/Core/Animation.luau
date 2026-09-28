--[[
	Animation
	A thin, allocation-conscious wrapper around TweenService.

	• At most one tween runs per instance. Starting a new tween on the same
	  instance cancels the previous one, snapping any properties the new tween
	  does not touch to their final values (so nothing is left half-way).
	• Animations can be disabled globally (`Animation.Enabled = false`), in
	  which case properties are assigned instantly.
	• `Animation.CancelTree(root)` stops every tween under a root; windows call
	  this when they are destroyed.
]]

local TweenService = game:GetService("TweenService")

local Animation = {}

Animation.Enabled = true

Animation.Durations = {
	Fast = 0.08, -- hover / press feedback
	Normal = 0.14, -- dropdowns, toggles, tooltips
	Slow = 0.22, -- notifications, window appearance
}

local active: { [Instance]: { Tween: Tween, Props: { [string]: any } } } = {}
local infoCache: { [string]: TweenInfo } = {}

local function getInfo(duration: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	local easingStyle = style or Enum.EasingStyle.Quad
	local easingDirection = direction or Enum.EasingDirection.Out
	local key = `{duration}|{easingStyle.Name}|{easingDirection.Name}`
	local info = infoCache[key]
	if not info then
		info = TweenInfo.new(duration, easingStyle, easingDirection)
		infoCache[key] = info
	end
	return info
end

local function stop(instance: Instance, keepProps: { [string]: any }?)
	local entry = active[instance]
	if not entry then
		return
	end
	active[instance] = nil
	entry.Tween:Cancel()
	-- Snap properties that the replacement tween won't animate.
	for property, value in entry.Props do
		if not (keepProps and keepProps[property] ~= nil) then
			(instance :: any)[property] = value
		end
	end
	entry.Tween:Destroy()
end

--- Tweens `props` on `instance`. Returns the Tween, or nil when animations
--- are disabled or the duration is zero (props are then applied instantly).
function Animation.Tween(
	instance: Instance,
	props: { [string]: any },
	duration: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	stop(instance, props)

	local time = duration or Animation.Durations.Normal
	if not Animation.Enabled or time <= 0 or instance.Parent == nil then
		for property, value in props do
			(instance :: any)[property] = value
		end
		return nil
	end

	local tween = TweenService:Create(instance, getInfo(time, style, direction), props)
	local entry = { Tween = tween, Props = props }
	active[instance] = entry

	tween.Completed:Once(function()
		if active[instance] == entry then
			active[instance] = nil
			tween:Destroy()
		end
	end)

	tween:Play()
	return tween
end

--- Cancels an instance's running tween, snapping it to its target values.
function Animation.Cancel(instance: Instance)
	stop(instance, nil)
end

--- Cancels every running tween on `root` and its descendants.
function Animation.CancelTree(root: Instance)
	for instance in active do
		if instance == root or instance:IsDescendantOf(root) then
			stop(instance, nil)
		end
	end
end

--- Cancels every running tween (used by Velumi:Destroy()).
function Animation.CancelAll()
	for instance in active do
		stop(instance, nil)
	end
end

function Animation.IsPlaying(instance: Instance): boolean
	return active[instance] ~= nil
end

return Animation
