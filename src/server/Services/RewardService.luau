--[[
	RewardService
	First-join starter kit and the daily login streak (day 7 = Silver Egg).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeClass = require(Shared.BeeClass)
local Format = require(Shared.Format)
local Notify = require(script.Parent.Parent.Util.Notify)

local RewardService = {}
RewardService.Name = "RewardService"

local S

local function describe(reward): string
	local parts = {}
	if reward.Honey then
		table.insert(parts, Format.Short(reward.Honey) .. " honey")
	end
	if reward.Treats then
		table.insert(parts, reward.Treats .. " treats")
	end
	if reward.Eggs then
		for eggId, n in reward.Eggs do
			table.insert(parts, `{n}x {Config.Eggs[eggId].Name}`)
		end
	end
	return table.concat(parts, ", ")
end

function RewardService:Grant(player: Player, data, reward)
	if reward.Honey then
		S.DataService:AddHoney(player, reward.Honey, false)
	end
	if reward.Treats then
		data.Treats += reward.Treats
		S.DataService:MarkDirty(player, "Treats")
	end
	if reward.Eggs then
		for eggId, n in reward.Eggs do
			data.Eggs[eggId] = (data.Eggs[eggId] or 0) + n
		end
		S.DataService:MarkDirty(player, "Eggs")
	end
end

function RewardService:_starter(player: Player, data)
	if data.Tutorial.Starter then
		return
	end
	data.Tutorial.Starter = true
	if not data.Bees["1"] then
		data.Bees["1"] = BeeClass.NewRecord("Basic", nil)
		data.Codex.Basic = true
	end
	S.DataService:MarkDirty(player, "Bees", "Codex", "Tutorial")
	S.BeeService:RebuildSwarm(player)
	S.HiveService:RefreshCells(player)
	task.delay(3, function()
		Notify.Player(player, "Welcome! Grab pollen in Sunflower Meadow, then make honey at your hive.", "info")
		task.wait(5)
		Notify.Player(player, "You have a free Basic Egg: open the Hive menu to hatch it.", "info")
	end)
end

function RewardService:_daily(player: Player, data)
	local today = os.time() // 86400
	local daily = data.Daily
	if daily.LastDay == today then
		return
	end
	daily.Streak = (daily.LastDay == today - 1) and daily.Streak + 1 or 1
	daily.LastDay = today
	local reward = Config.DailyRewards[(daily.Streak - 1) % #Config.DailyRewards + 1]
	self:Grant(player, data, reward)
	S.DataService:MarkDirty(player, "Daily")
	task.delay(6, function()
		Notify.Player(player, `Day {daily.Streak} login reward: {describe(reward)}!`, "good")
	end)
end

function RewardService:Init(services)
	S = services
end

function RewardService:Start()
	S.DataService:OnLoaded(function(player, data)
		self:_starter(player, data)
		self:_daily(player, data)
	end)
end

return RewardService
