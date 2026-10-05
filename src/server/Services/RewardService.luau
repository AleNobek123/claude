--[[
	RewardService
	First-join starter kit and the daily login streak (day 7 = Silver Egg).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeClass = require(Shared.BeeClass)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
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

-- Promo codes: case-insensitive, once per player. Returns (ok, message).
function RewardService:Redeem(player: Player, code: string)
	if typeof(code) ~= "string" or #code > 32 then
		return false, "Invalid code"
	end
	local data = S.DataService:Get(player)
	if not data then
		return false, "Data not loaded yet"
	end
	local key = code:upper():gsub("%s", "")
	local reward = Config.Codes[key]
	if not reward then
		return false, "Unknown code"
	end
	if data.Codes[key] then
		return false, "Already redeemed"
	end
	data.Codes[key] = true
	self:Grant(player, data, reward)
	S.DataService:MarkDirty(player, "Codes")
	return true, "Redeemed: " .. describe(reward)
end

local SETTINGS_SCHEMA = { Music = "boolean", Sfx = "boolean", Graphics = "string" }

function RewardService:_saveSettings(player: Player, settings)
	local data = S.DataService:Get(player)
	if not data or typeof(settings) ~= "table" then
		return
	end
	for key, kind in SETTINGS_SCHEMA do
		local value = settings[key]
		if typeof(value) == kind then
			if key ~= "Graphics" or value == "High" or value == "Low" then
				data.Settings[key] = value
			end
		end
	end
	S.DataService:MarkDirty(player, "Settings")
end

function RewardService:_tutorialStep(player: Player, step: number)
	local data = S.DataService:Get(player)
	if not data or typeof(step) ~= "number" then
		return
	end
	step = math.clamp(math.floor(step), 1, #Config.Tutorial + 1)
	if step > data.Tutorial.Step then
		data.Tutorial.Step = step
		data.Tutorial.Done = step > #Config.Tutorial
		S.DataService:MarkDirty(player, "Tutorial")
	end
end

function RewardService:Init(services)
	S = services
	self.RedeemCode = Net.Function("RedeemCode")
	self.SaveSettings = Net.Event("SaveSettings")
	self.TutorialStep = Net.Event("TutorialStep")
end

function RewardService:Start()
	S.DataService:OnLoaded(function(player, data)
		self:_starter(player, data)
		self:_daily(player, data)
	end)
	self.RedeemCode.OnServerInvoke = function(player, code)
		if not Net.Allow(player, "RedeemCode", 1) then
			return false, "Slow down"
		end
		return self:Redeem(player, code)
	end
	self.SaveSettings.OnServerEvent:Connect(function(player, settings)
		if Net.Allow(player, "SaveSettings", 0.5) then
			self:_saveSettings(player, settings)
		end
	end)
	self.TutorialStep.OnServerEvent:Connect(function(player, step)
		if Net.Allow(player, "TutorialStep", 0.5) then
			self:_tutorialStep(player, step)
		end
	end)
end

return RewardService
