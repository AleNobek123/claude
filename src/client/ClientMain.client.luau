--[[
	ClientMain
	Boots client controllers: Init (wire up) then Start.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"State",
	"UI",
	"Sound",
	"NotificationCenter",
	"TeleportTransition",
	"Settings",
	"HUD",
	"Fx",
	"BeeRenderer",
	"HiveDisplay",
	"DayNightBeeController",
	"Shop",
	"Hive",
	"Eggs",
	"Promo",
	"Store",
	"Rewards",
	"Feedback",
	"Codex",
	"FieldRenderer",
	"MonsterRenderer",
	"Collector",
	"Events",
	"HoneyFx",
	"HatchCutscene",
	"Nests",
	"Tutorial",
	"NotificationBadge",
	"VipTags",
}

local loaded = {}
for _, name in ORDER do
	local module = Controllers:WaitForChild(name, 10)
	if module then
		local ok, controller = pcall(require, module)
		if ok then
			loaded[name] = controller
		else
			warn(`[Client] Failed to require {name}: {controller}`)
		end
	end
end

for _, name in ORDER do
	local controller = loaded[name]
	if controller and controller.Init then
		local ok, err = pcall(controller.Init, controller, loaded)
		if not ok then
			warn(`[Client] {name}.Init failed: {err}`)
		end
	end
end

for _, name in ORDER do
	local controller = loaded[name]
	if controller and controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(`[Client] {name}.Start failed: {err}`)
			end
		end)
	end
end
