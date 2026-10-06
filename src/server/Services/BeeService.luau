--[[
	BeeService
	Runs every swarm on the server as pure logic: a state machine per bee that decides
	tasks (fly to a flower, gather, carry pollen to the hive, attack a monster, follow).

	Network model:
	  - A task change is sent once, as a 32-byte record (BeeCodec), batched per tick for
	    all players in one RemoteEvent call.
	  - Clients animate the flight (BeeRenderer). The server never sends positions per frame.
	  - Swarm composition (which bee sits in which slot, mutations) is sent only when it
	    changes, so other players can render your rare bees and auras.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local BeeClass = require(Shared.BeeClass)
local BeeCodec = require(Shared.BeeCodec)
local DayNight = require(Shared.DayNight)
local Synergy = require(Shared.Synergy)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local BeeService = {}
BeeService.Name = "BeeService"

local TICK = 0.1
local GATHER_RADIUS = 20
local HUNT_RANGE = 30
local ASSIST_RANGE = 18 -- non-soldier bees join a fight this close to their owner
local ASSIST_CHANCE = 0.6
local STANDOFF = 7 -- ranged bees hover this far from the target and shoot stingers
local SUPERNOVA_EVERY = 20
local TASK = BeeCodec.Task

local TITLES = {
	Mythic = "Mythic Keeper",
	Legendary = "Legend Tamer",
	Epic = "Epic Beekeeper",
	Rare = "Beekeeper",
	Common = "Rookie",
}

local S
local swarms = {} -- [player] = swarm
local outgoing = {} -- task records queued this tick

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function emptyHiveMods()
	return {
		HiveConvert = 0, -- from Honey Bee passives
		ConvertBonus = 0, -- from Honeycomb Core
		RedPollen = 0,
		MonsterHoney = 0,
		HoneyMult = 0,
		PollenMult = 0,
		MonsterSlow = 0,
		FrostRadius = 1,
		Supernova = false,
		SupernovaSlots = {},
	}
end

-- Queries --------------------------------------------------------------------------------

function BeeService:GetSwarm(player: Player)
	return swarms[player]
end

function BeeService:GetHiveMods(player: Player)
	local swarm = swarms[player]
	return swarm and swarm.HiveMods or nil
end

-- Composition broadcast ---------------------------------------------------------------------

local function composition(data)
	local comp = {}
	for slotKey, record in data.Bees do
		comp[slotKey] = { Id = record.Id, Mutation = record.Mutation, Level = record.Level }
	end
	return comp
end

local function synergyNames(swarm)
	local list = {}
	for _, active in swarm.Synergies do
		table.insert(list, { Id = active.Id, Slots = active.Slots })
	end
	return list
end

function BeeService:_broadcastSwarm(player: Player)
	local swarm = swarms[player]
	local data = S.DataService:Get(player)
	if not swarm or not data then
		return
	end
	self.SwarmUpdate:FireAllClients(swarm.HiveIndex, player.UserId, composition(data), synergyNames(swarm))
end

-- Build ---------------------------------------------------------------------------------------

function BeeService:RebuildSwarm(player: Player)
	local data = S.DataService:Get(player)
	local hiveIndex = S.HiveService:GetHiveIndex(player)
	if not data or not hiveIndex then
		return
	end
	local old = swarms[player]
	local previous = {}
	if old then
		for _, bee in old.Bees do
			previous[bee.Record] = bee -- records move between slots on swaps
		end
	end

	local bees = {}
	local idsBySlot = {}
	for slotKey, record in data.Bees do
		local slot = tonumber(slotKey)
		if slot and BeeData.Bees[record.Id] then
			local bee = BeeClass.new(slot, record, player)
			local prior = previous[record]
			if prior then
				bee.State = prior.State
				bee.NextAbilityAt = prior.NextAbilityAt
				bee.State.EndsAt = 0 -- re-plan now (slot may have changed)
			end
			bees[slot] = bee
			idsBySlot[slot] = record.Id
		end
	end

	local synergy = Synergy.Evaluate(idsBySlot)
	local hive = emptyHiveMods()
	hive.ConvertBonus = synergy.Hive.ConvertBonus
	hive.MonsterSlow = synergy.Hive.MonsterSlow
	hive.FrostRadius = synergy.Hive.FrostRadius
	hive.Supernova = synergy.Hive.Supernova
	hive.SupernovaSlots = synergy.Hive.SupernovaSlots

	for slot, bee in bees do
		bee:SetModifiers(synergy.BeeMods[slot])
		local passive = bee.Def.Passive
		if passive then
			hive.HiveConvert += passive.HiveConvert or 0
			hive.RedPollen += passive.RedPollen or 0
			hive.MonsterHoney += passive.MonsterHoney or 0
			hive.HoneyMult += passive.HoneyMult or 0
			hive.PollenMult += passive.PollenMult or 0
		end
	end

	swarms[player] = {
		Player = player,
		HiveIndex = hiveIndex,
		Bees = bees,
		HiveMods = hive,
		Synergies = synergy.Active,
		NextSupernova = os.clock() + SUPERNOVA_EVERY,
	}

	self:_broadcastSwarm(player)
	self:RefreshScore(player)
end

function BeeService:RefreshScore(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	local score = BeeClass.SwarmScore(data.Bees)
	local best = 0
	for _, record in data.Bees do
		local def = BeeData.Bees[record.Id]
		if def then
			best = math.max(best, Config.Rarities[def.Rarity].Order)
		end
	end
	local title = best > 0 and TITLES[Config.RarityOrder[best]] or nil

	player:SetAttribute("SwarmScore", score)
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Swarm") then
		stats.Swarm.Value = score
	end
	local index = S.HiveService:GetHiveIndex(player)
	if index then
		S.HiveService:RefreshSign(player, index, score)
	end
	S.HiveService:UpdateOverhead(player, score, title)
	if S.LeaderboardService then
		S.LeaderboardService:SetSwarmScore(player, score)
	end
end

-- Task planning ----------------------------------------------------------------------------------

local function queue(swarm, bee, phase: string, target: Vector3, duration: number, now: number, targetId: number?)
	local state = bee.State
	state.Phase = phase
	state.Start = now
	state.EndsAt = now + duration
	state.Target = target
	state.TargetId = targetId
	table.insert(outgoing, {
		Hive = swarm.HiveIndex,
		Slot = bee.Slot,
		Task = TASK[phase],
		Target = target,
		Start = now,
		Duration = duration,
		TargetId = targetId or 0,
	})
end

local function travelTime(bee, from: Vector3?, to: Vector3): number
	local distance = from and (to - from).Magnitude or 10
	return math.clamp(distance / bee.Stats.Speed, 0.25, 12)
end

-- Finish the bee's current task (apply its effect), then choose and queue the next one
function BeeService:_advance(swarm, bee, ctx, now: number)
	local player = swarm.Player
	local state = bee.State
	local phase = state.Phase

	-- 1. effects of the task that just ended
	if phase == "Gather" then
		local field = S.FieldService:GetField(state.FieldId)
		if field and ctx.Field == field then
			local added = S.FieldService:BeeGather(player, field, state.Tile, bee.Stats.Gather, bee.Def.Color)
			if added > 0 then
				local levels = bee:AddXP(Config.Levels.GatherXP)
				if levels > 0 then
					S.DataService:MarkDirty(player, "Bees")
					Notify.Fx("LevelUp", { Hive = swarm.HiveIndex, Slot = bee.Slot, Level = bee.Record.Level })
					self:RefreshScore(player)
				end
			end
		end
	elseif phase == "ToHive" then
		S.ConvertService:BeeConvert(player, bee, state.Target)
	elseif phase == "Attack" and state.TargetId then
		S.MonsterService:Damage(state.TargetId, bee.Stats.Attack, player)
	end

	local root = ctx.Root
	if not root then
		state.Phase = "Follow"
		state.EndsAt = now + 1
		return
	end
	local position = state.Target or root.Position
	if phase == "Follow" or phase == "ToOwner" then
		position = root.Position
	end

	-- 0. night: half of the swarm flies home and sleeps in its hive cell
	if DayNight.Sleeps(bee.Slot, now) then
		local cell = S.HiveService:CellPosition(player, bee.Slot)
		if cell then
			if phase == "Rest" then
				state.EndsAt = now + 3 -- already asleep: stay silent on the network
			elseif phase == "FlyTo" and state.Sleeping then
				queue(swarm, bee, "Rest", cell, 3, now)
			else
				state.Sleeping = true
				state.Tile = nil
				queue(swarm, bee, "FlyTo", cell, travelTime(bee, position, cell), now)
			end
			return
		end
	end
	if state.Sleeping then
		state.Sleeping = nil
		phase = "Wake"
	end

	-- 2. converting: shuttle between owner and hive cell
	if ctx.Converting then
		if phase == "ToHive" then
			queue(swarm, bee, "ToOwner", root.Position, travelTime(bee, position, root.Position), now)
		else
			local cell = S.HiveService:CellPosition(player, bee.Slot)
			if cell then
				queue(swarm, bee, "ToHive", cell, travelTime(bee, position, cell), now)
				return
			end
		end
		return
	end

	-- 3. in a field: the swarm fights monsters, otherwise gathers.
	-- Soldiers always hunt and dash into the target; other bees join fights near their owner
	-- and keep a stand-off distance, shooting stingers (the client draws the projectile).
	if ctx.Field then
		local soldier = bee:HasTag("Soldier")
		local range = soldier and HUNT_RANGE or ASSIST_RANGE
		local monster = S.MonsterService:FindNearest(ctx.Field.Id, root.Position, range)
		if monster and (soldier or math.random() < ASSIST_CHANCE) then
			local target = S.MonsterService:Position(monster) + Vector3.new(0, 1.5, 0)
			if soldier then
				queue(swarm, bee, "Attack", target, travelTime(bee, position, target) + 0.35, now, monster.Id)
			else
				local away = (position - target) * Vector3.new(1, 0, 1)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
				local hover = target + away * STANDOFF + Vector3.new(0, 2.5, 0)
				queue(swarm, bee, "Attack", hover, travelTime(bee, position, hover) + 0.6, now, monster.Id)
			end
			return
		end
		if not ctx.Full then
			if phase == "FlyTo" and state.FieldId == ctx.Field.Id and state.Tile then
				queue(swarm, bee, "Gather", state.Target, bee.Stats.GatherTime, now)
				return
			end
			local index, tile = S.FieldService:RandomTileNear(ctx.Field, root.Position, GATHER_RADIUS)
			local target = tile.Position + Vector3.new(0, 1.4, 0)
			state.FieldId = ctx.Field.Id
			state.Tile = index
			queue(swarm, bee, "FlyTo", target, travelTime(bee, position, target), now)
			return
		end
	end

	-- 4. idle: follow the owner (one message on entering the state, then silent)
	if phase ~= "Follow" then
		queue(swarm, bee, "Follow", Vector3.zero, 0.8, now)
	else
		state.EndsAt = now + 0.8
	end
end

-- Ability context: the only door from a bee to the world -------------------------------------------

local function makeContext(player: Player, field, root: BasePart)
	return {
		Owner = player,
		Origin = root.Position,
		PickPoint = function(spread: number)
			return S.FieldService:RandomPointNear(field, root.Position, spread)
		end,
		Harvest = function(center: Vector3, radius: number, perTile: number, color: string?)
			return S.FieldService:Harvest(player, field, center, radius, perTile, {
				Color = color,
				Depletion = Config.Tiles.BeeDepletion,
				Popup = true,
			})
		end,
		Strike = function(center: Vector3, range: number, damage: number, hitAll: boolean)
			return S.MonsterService:Strike(field.Id, center, range, damage, hitAll, player)
		end,
		Slow = function(center: Vector3, radius: number, factor: number, duration: number)
			S.MonsterService:SlowArea(field.Id, center, radius, factor, duration)
		end,
		ConvertFraction = function(fraction: number)
			return S.ConvertService:ConvertFraction(player, fraction)
		end,
	}
end

-- Tick --------------------------------------------------------------------------------------------

function BeeService:_tickSwarm(swarm, now: number, clock: number)
	local player = swarm.Player
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	local field, root = S.FieldService:GetPlayerField(player)
	local ctx = {
		Field = field,
		Root = root,
		Converting = S.ConvertService:IsConverting(player),
		Full = data.Pollen >= S.FieldService:Capacity(player),
	}

	local abilityCtx
	for _, bee in swarm.Bees do
		if now >= bee.State.EndsAt then
			self:_advance(swarm, bee, ctx, now)
		end
		if field and root and not ctx.Converting and not bee.State.Sleeping and bee:IsAbilityReady(clock) then
			abilityCtx = abilityCtx or makeContext(player, field, root)
			local result = bee:CastAbility(abilityCtx, clock)
			if result then
				Notify.Fx("Ability", {
					Fx = result.Fx,
					Points = result.Points,
					Radius = result.Radius,
					Hive = swarm.HiveIndex,
					Slot = bee.Slot,
					Name = bee.Def.Ability.Name,
				})
			end
		end
	end

	-- Supernova Field Burn synergy
	local hive = swarm.HiveMods
	if hive.Supernova and field and root and not ctx.Converting and clock >= swarm.NextSupernova then
		swarm.NextSupernova = clock + SUPERNOVA_EVERY
		local power = 0
		for _, slot in hive.SupernovaSlots do
			local bee = swarm.Bees[slot]
			if bee then
				power += bee.Stats.Gather * 0.1 * 2
			end
		end
		local center = Vector3.new(root.Position.X, field.Center.Y, root.Position.Z)
		S.FieldService:Harvest(player, field, center, 14, power, { Depletion = 0.15, Popup = true })
		Notify.Fx("Ability", { Fx = "Supernova", Points = { center }, Radius = 14, Hive = swarm.HiveIndex, Name = "Supernova" })
	end
end

function BeeService:Init(services)
	S = services
	self.BeeTasks = Net.Event("BeeTasks")
	self.SwarmUpdate = Net.Event("SwarmUpdate")
	self.GetSwarms = Net.Function("GetSwarms")
end

function BeeService:Start()
	self.GetSwarms.OnServerInvoke = function()
		local list = {}
		for player, swarm in swarms do
			local data = S.DataService:Get(player)
			if data then
				table.insert(list, {
					Hive = swarm.HiveIndex,
					UserId = player.UserId,
					Bees = composition(data),
					Synergies = synergyNames(swarm),
				})
			end
		end
		return list
	end

	Players.PlayerRemoving:Connect(function(player)
		local swarm = swarms[player]
		if swarm then
			for _, bee in swarm.Bees do
				bee:Destroy()
			end
			self.SwarmUpdate:FireAllClients(swarm.HiveIndex, player.UserId, nil, nil)
		end
		swarms[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = serverNow()
			local clock = os.clock()
			for _, swarm in swarms do
				local ok, err = pcall(self._tickSwarm, self, swarm, now, clock)
				if not ok then
					warn("[BeeService] tick:", err)
				end
			end
			if #outgoing > 0 then
				self.BeeTasks:FireAllClients(BeeCodec.Encode(outgoing))
				table.clear(outgoing)
			end
		end
	end)
end

return BeeService
