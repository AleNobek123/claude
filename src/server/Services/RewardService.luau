--[[
	RewardService
	First-join starter kit, promo codes, and the Rewards hub. Nothing is granted automatically:
	the daily login grid, playtime milestones (up to 2 h a day) and social rewards are claimed
	by hand from the Rewards panel. Honey/treat amounts scale with lifetime honey.
]]

local Players = game:GetService("Players")
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

-- Rewards hub ------------------------------------------------------------------------------------

local honorStarted = {} -- [player] = { [providerId] = os.clock() when "verify" was pressed }

local function today(): number
	return os.time() // 86400
end

local function rollPlaytimeDay(data)
	local day = today()
	if data.Playtime.Day ~= day then
		data.Playtime.Day = day
		data.Playtime.Seconds = 0
		data.Playtime.Claimed = {}
	end
end

-- Which day of the 7-day grid would be claimed now (streak continues if yesterday was claimed)
local function dailyIndex(data): (number, boolean)
	local daily = data.Daily
	local day = today()
	if daily.LastDay == day then
		return (daily.Streak - 1) % #Config.Rewards.Daily + 1, false
	end
	local streak = (daily.LastDay == day - 1) and daily.Streak + 1 or 1
	return (streak - 1) % #Config.Rewards.Daily + 1, true
end

function RewardService:State(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return nil
	end
	rollPlaytimeDay(data)
	local index, claimable = dailyIndex(data)
	local social = {}
	for _, provider in Config.Rewards.Social do
		local started = honorStarted[player] and honorStarted[player][provider.Id]
		social[provider.Id] = {
			Claimed = data.Social[provider.Id] == true,
			Ready = started ~= nil and os.clock() - started >= (provider.Wait or 0),
			Started = started ~= nil,
		}
	end
	return {
		Scale = Config.RewardScale(data.TotalHoney),
		Daily = { Index = index, Claimable = claimable, Streak = data.Daily.Streak, NextIn = (today() + 1) * 86400 - os.time() },
		Playtime = { Seconds = data.Playtime.Seconds, Claimed = data.Playtime.Claimed },
		Social = social,
	}
end

function RewardService:ClaimDaily(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return false, "Data not loaded yet"
	end
	local index, claimable = dailyIndex(data)
	if not claimable then
		return false, "Come back tomorrow!"
	end
	local daily = data.Daily
	daily.Streak = (daily.LastDay == today() - 1) and daily.Streak + 1 or 1
	daily.LastDay = today()
	local reward = Config.ScaleReward(Config.Rewards.Daily[index], data.TotalHoney)
	self:Grant(player, data, reward)
	S.DataService:MarkDirty(player, "Daily")
	return true, `Day {index} reward: {describe(reward)}`
end

function RewardService:ClaimPlaytime(player: Player, index: number)
	local data = S.DataService:Get(player)
	local milestone = typeof(index) == "number" and Config.Rewards.Playtime[index]
	if not data or not milestone then
		return false, "Invalid reward"
	end
	rollPlaytimeDay(data)
	if data.Playtime.Claimed[tostring(index)] then
		return false, "Already claimed"
	end
	if data.Playtime.Seconds < milestone.Minutes * 60 then
		return false, "Keep playing to unlock this reward"
	end
	data.Playtime.Claimed[tostring(index)] = true
	local reward = Config.ScaleReward(milestone.Reward, data.TotalHoney)
	self:Grant(player, data, reward)
	S.DataService:MarkDirty(player, "Playtime")
	return true, `Playtime reward: {describe(reward)}`
end

-- Social providers: "Group" asks Roblox, "Honor" trusts the player after a short wait
function RewardService:Social(player: Player, id: string)
	local data = S.DataService:Get(player)
	local provider
	for _, p in Config.Rewards.Social do
		if p.Id == id then
			provider = p
		end
	end
	if not data or not provider then
		return false, "Invalid reward"
	end
	if data.Social[id] then
		return false, "Already claimed"
	end
	if provider.Provider == "Group" then
		if Config.Rewards.GroupId == 0 then
			return false, "Group reward is coming soon!"
		end
		local ok, member = pcall(player.IsInGroup, player, Config.Rewards.GroupId)
		if not ok or not member then
			return false, "Join the group first, then press claim again"
		end
	else
		honorStarted[player] = honorStarted[player] or {}
		local started = honorStarted[player][id]
		if not started then
			honorStarted[player][id] = os.clock()
			return false, "Thanks! Come back in a few seconds to claim"
		end
		if os.clock() - started < (provider.Wait or 0) then
			return false, "Almost there..."
		end
	end
	data.Social[id] = true
	self:Grant(player, data, Config.ScaleReward(provider.Reward, data.TotalHoney))
	S.DataService:MarkDirty(player, "Social")
	return true, `{provider.Name}: {describe(Config.ScaleReward(provider.Reward, data.TotalHoney))}`
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
	self.Rewards = Net.Function("Rewards")
	self.MarkSeen = Net.Event("MarkSeen")
end

function RewardService:Start()
	S.DataService:OnLoaded(function(player, data)
		self:_starter(player, data)
	end)
	self.Rewards.OnServerInvoke = function(player, action, arg)
		if not Net.Allow(player, "Rewards", 0.3) then
			return false, "Slow down"
		end
		if action == "State" then
			return true, self:State(player)
		end
		-- claims answer with the fresh hub state so the panel updates immediately
		local ok, message
		if action == "Daily" then
			ok, message = self:ClaimDaily(player)
		elseif action == "Playtime" then
			ok, message = self:ClaimPlaytime(player, arg)
		elseif action == "Social" then
			ok, message = self:Social(player, arg)
		else
			return false, "Unknown action"
		end
		return ok, message, self:State(player)
	end
	-- Codex entries the player has looked at (drives the "!" badge)
	self.MarkSeen.OnServerEvent:Connect(function(player, kind, ids)
		local data = S.DataService:Get(player)
		if not data or kind ~= "Codex" or typeof(ids) ~= "table" or not Net.Allow(player, "MarkSeen", 0.5) then
			return
		end
		for _, id in ids do
			if typeof(id) == "string" and data.Codex[id] then
				data.CodexSeen[id] = true
			end
		end
		S.DataService:MarkDirty(player, "CodexSeen")
	end)
	-- playtime accumulates on the server (10 s steps), saved with the profile
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				local data = S.DataService:Get(player)
				if data then
					rollPlaytimeDay(data)
					data.Playtime.Seconds += 10
					if data.Playtime.Seconds % 30 == 0 then
						S.DataService:MarkDirty(player, "Playtime")
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		honorStarted[player] = nil
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
