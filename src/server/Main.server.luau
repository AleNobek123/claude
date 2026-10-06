--[[
	Main
	Boots every service in dependency order: Init (wire up, no yielding) then Start.
]]

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"MonetizationService",
	"HiveService",
	"FieldService",
	"MonsterService",
	"BeeService",
	"ConvertService",
	"ShopService",
	"EggService",
	"RewardService",
	"EventService",
	"LeaderboardService",
	"FeedbackService",
}

local loaded = {}
for _, name in ORDER do
	local module = Services:FindFirstChild(name)
	if module then
		local ok, service = pcall(require, module)
		if ok then
			loaded[name] = service
		else
			warn(`[Main] Failed to require {name}: {service}`)
		end
	else
		warn(`[Main] Missing service {name}`)
	end
end

for _, name in ORDER do
	local service = loaded[name]
	if service and service.Init then
		local ok, err = pcall(service.Init, service, loaded)
		if not ok then
			warn(`[Main] {name}.Init failed: {err}`)
		end
	end
end

for _, name in ORDER do
	local service = loaded[name]
	if service and service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn(`[Main] {name}.Start failed: {err}`)
			end
		end)
	end
end

print(`[Main] {#ORDER} services started`)
