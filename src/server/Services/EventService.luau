--[[
	EventService
	Global field events every 15 minutes, derived from the clock so every server runs the
	same event at the same time:

	  cycle  = floor(serverTime / Interval)
	  type   = Random.new(cycle) pick from Config.Events.Types
	  field  = Random.new(cycle) pick from Config.Events.FieldPool
	  0..60s warning, 60..240s active, then idle until the next cycle.

	During an event the field gives 5x, its gate is open for everyone, and each type adds
	its own mechanic (meteors, aphid waves with a server-wide goal, golden regrowth,
	honey tokens).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local EventService = {}
EventService.Name = "EventService"

local E = Config.Events
local S
local state = { Phase = "Idle" }
local participants: { [Player]: number } = {}
local tokens = {} -- [id] = { Position, Value }
local nextTokenId = 1
local rng = Random.new()
local lastMeteor = 0
local lastToken = 0
local lastAphidSpawn = 0

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function interval(): number
	return RunService:IsStudio() and E.StudioInterval or E.Interval
end

-- Deterministic schedule ------------------------------------------------------------------

function EventService:Describe(cycle: number)
	local seeded = Random.new(cycle * 7919 + 17)
	local eventType = E.Types[seeded:NextInteger(1, #E.Types)]
	local fieldId = E.FieldPool[seeded:NextInteger(1, #E.FieldPool)]
	if eventType == "MeteorShower" then
		fieldId = "Sunflower" -- the name promises sunflowers
	end
	return eventType, fieldId
end

function EventService:Schedule(now: number)
	local length = interval()
	local cycle = now // length
	local t = now - cycle * length
	local eventType, fieldId = self:Describe(cycle)
	local warnEnd = cycle * length + E.Warning
	local activeEnd = warnEnd + E.Duration
	if t < E.Warning then
		return { Phase = "Warning", Cycle = cycle, Type = eventType, FieldId = fieldId, StartsAt = warnEnd, EndsAt = activeEnd }
	elseif t < E.Warning + E.Duration then
		return { Phase = "Active", Cycle = cycle, Type = eventType, FieldId = fieldId, StartsAt = warnEnd, EndsAt = activeEnd }
	end
	local nextType, nextField = self:Describe(cycle + 1)
	return {
		Phase = "Idle",
		Cycle = cycle,
		Type = nextType,
		FieldId = nextField,
		StartsAt = (cycle + 1) * length + E.Warning,
		EndsAt = (cycle + 1) * length + E.Warning + E.Duration,
	}
end

function EventService:GetState()
	return state
end

local function fieldName(fieldId: string): string
	local def = Config.FieldById[fieldId]
	return def and def.Name or fieldId
end

local function publicState()
	return {
		Phase = state.Phase,
		Type = state.Type,
		FieldId = state.FieldId,
		StartsAt = state.StartsAt,
		EndsAt = state.EndsAt,
		Progress = state.Progress,
		Goal = state.Goal,
	}
end

function EventService:_broadcast()
	self.EventState:FireAllClients(publicState())
end

-- Transitions -------------------------------------------------------------------------------

function EventService:_begin()
	local info = Config.EventInfo[state.Type]
	S.FieldService:SetEvent(state.FieldId, E.Multiplier, state.Type)
	table.clear(participants)
	state.Progress = 0
	state.Goal = state.Type == "AphidInvasion" and E.AphidGoal or nil
	state.GoalMet = false
	Notify.All(`{info.Name} has started in {fieldName(state.FieldId)}! 5x rewards, gate open for all.`, "rare")
	if state.Type == "AphidInvasion" then
		S.MonsterService:Spawn("AphidQueen", state.FieldId, nil, true)
	end
end

function EventService:_finish()
	local info = Config.EventInfo[state.Type]
	S.FieldService:SetEvent(nil)
	S.MonsterService:ClearEvent()
	for id in tokens do
		self.Token:FireAllClients("Gone", id)
	end
	table.clear(tokens)

	for player, seconds in participants do
		if player.Parent and seconds >= E.ParticipationTime then
			local data = S.DataService:Get(player)
			if data then
				data.Stats.EventsJoined += 1
				data.Treats += 5
				S.DataService:MarkDirty(player, "Treats", "Stats")
				local message = `{info.Name} over! +5 Treats for joining.`
				if state.Type == "AphidInvasion" and state.GoalMet then
					data.Eggs.Silver = (data.Eggs.Silver or 0) + 1
					S.DataService:MarkDirty(player, "Eggs")
					message = `Invasion repelled! +1 Silver Egg and +5 Treats.`
				end
				Notify.Player(player, message, "good")
			end
		end
	end
	table.clear(participants)
end

-- Per-type ticks ------------------------------------------------------------------------------

function EventService:_meteor(field)
	local pos = S.FieldService:RandomPointNear(field, field.Center, field.Half - 2)
	Notify.Fx("Meteor", { Position = pos, Delay = 1.2 })
	task.delay(1.2, function()
		if state.Phase ~= "Active" then
			return
		end
		for _, player in Players:GetPlayers() do
			local playerField, root = S.FieldService:GetPlayerField(player)
			if playerField == field and root and (root.Position - pos).Magnitude <= E.MeteorRadius then
				local data = S.DataService:Get(player)
				local collector = data and Config.CollectorById[data.Collector]
				local power = (collector and collector.Power or 2) * 3
				S.FieldService:Harvest(player, field, pos, E.MeteorRadius * 0.6, power, { Depletion = 0.3, Popup = true })
			end
		end
	end)
end

function EventService:_token(field)
	local pos = S.FieldService:RandomPointNear(field, field.Center, field.Half - 2)
	local id = nextTokenId
	nextTokenId = nextTokenId % 60000 + 1
	tokens[id] = { Position = pos + Vector3.new(0, 1.5, 0), Born = os.clock() }
	self.Token:FireAllClients("Spawn", id, tokens[id].Position)
end

function EventService:_claimToken(player: Player, id: number)
	local token = tokens[id]
	if not token then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - token.Position).Magnitude > 9 then
		return
	end
	tokens[id] = nil
	self.Token:FireAllClients("Gone", id)
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	local collector = Config.CollectorById[data.Collector]
	local field = S.FieldService:GetField(state.FieldId or "Sunflower")
	local honey = math.floor(100 * 2 ^ ((collector and collector.Index or 1) - 1) * (field and field.Def.Multiplier or 1))
	S.DataService:AddHoney(player, honey)
	Notify.FxTo(player, "Honey", { Position = token.Position + Vector3.new(0, 2, 0), Amount = honey })
end

function EventService:_activeTick(dt: number)
	local field = S.FieldService:GetField(state.FieldId)
	if not field then
		return
	end
	-- participation
	for _, player in Players:GetPlayers() do
		local playerField = S.FieldService:GetPlayerField(player)
		if playerField == field then
			participants[player] = (participants[player] or 0) + dt
		end
	end

	local clock = os.clock()
	if state.Type == "MeteorShower" and clock - lastMeteor >= E.MeteorEvery then
		lastMeteor = clock
		self:_meteor(field)
	elseif state.Type == "HoneyRain" and clock - lastToken >= E.TokenEvery then
		lastToken = clock
		self:_token(field)
		for id, token in tokens do
			if clock - token.Born > 20 then
				tokens[id] = nil
				self.Token:FireAllClients("Gone", id)
			end
		end
	elseif state.Type == "AphidInvasion" and clock - lastAphidSpawn >= 0.4 then
		lastAphidSpawn = clock
		if S.MonsterService:CountEvent() < 40 then
			S.MonsterService:Spawn("Aphid", state.FieldId, nil, true)
		end
	end
end

-- Lifecycle ------------------------------------------------------------------------------------

function EventService:Init(services)
	S = services
	self.EventState = Net.Event("EventState")
	self.GetEventState = Net.Function("GetEventState")
	self.Token = Net.Event("Token")
	self.ClaimToken = Net.Event("ClaimToken")
end

function EventService:Start()
	self.GetEventState.OnServerInvoke = function()
		local list = {}
		for id, token in tokens do
			table.insert(list, { Id = id, Position = token.Position })
		end
		return publicState(), list
	end
	self.ClaimToken.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "number" and Net.Allow(player, "ClaimToken", 0.05) then
			self:_claimToken(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
	end)

	S.MonsterService.Killed:Connect(function(monster)
		if state.Phase == "Active" and state.Type == "AphidInvasion" and monster.Event then
			state.Progress = (state.Progress or 0) + (monster.Type == "AphidQueen" and 25 or 1)
			if not state.GoalMet and state.Progress >= E.AphidGoal then
				state.GoalMet = true
				Notify.All("Server goal reached! Everyone in the invasion earns a Silver Egg.", "rare")
			end
			self:_broadcast()
		end
	end)

	task.spawn(function()
		local lastBroadcast = 0
		while true do
			local dt = task.wait(1)
			local now = serverNow()
			local upcoming = self:Schedule(now)
			local changed = upcoming.Phase ~= state.Phase or upcoming.Cycle ~= state.Cycle

			if changed then
				local previous = state.Phase
				if previous == "Active" then
					self:_finish()
				end
				state.Phase = upcoming.Phase
				state.Cycle = upcoming.Cycle
				state.Type = upcoming.Type
				state.FieldId = upcoming.FieldId
				state.StartsAt = upcoming.StartsAt
				state.EndsAt = upcoming.EndsAt
				state.Progress = nil
				state.Goal = nil
				if upcoming.Phase == "Warning" then
					local info = Config.EventInfo[upcoming.Type]
					Notify.All(`{info.Name} in {fieldName(upcoming.FieldId)} in {E.Warning} seconds!`, "info")
				elseif upcoming.Phase == "Active" then
					self:_begin()
				end
				self:_broadcast()
				lastBroadcast = os.clock()
			end

			if state.Phase == "Active" then
				local ok, err = pcall(self._activeTick, self, dt)
				if not ok then
					warn("[EventService] tick:", err)
				end
			end
			if os.clock() - lastBroadcast > 10 then
				lastBroadcast = os.clock()
				self:_broadcast()
			end
		end
	end)
end

return EventService
