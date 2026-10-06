--[[
	MonsterService
	Field monsters (Aphid, Ladybug, Aphid Queen). They wander a field, drain pollen from
	nearby players, and drop honey for everyone who damaged them.

	Same replication pattern as bees: the server decides each move (from, to, start,
	duration) and clients interpolate. No physics, no per-frame network traffic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Notify = require(script.Parent.Parent.Util.Notify)

local MonsterService = {}
MonsterService.Name = "MonsterService"

local TICK = 0.25
local IDLE_DESPAWN = 60

local S
local monsters = {} -- [id] = monster
local nextId = 1
local lastSpawn = {} -- [fieldId] = os.clock()
local rng = Random.new()
local killedEvent = Signal.new()
MonsterService.Killed = killedEvent -- (monster, killer)

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Position ------------------------------------------------------------------------------

function MonsterService:Position(m, now: number?): Vector3
	now = now or serverNow()
	if m.Duration <= 0 then
		return m.To
	end
	local alpha = math.clamp((now - m.Start) / m.Duration, 0, 1)
	return m.From:Lerp(m.To, alpha)
end

local function playersInField(fieldId: string)
	local list = {}
	for _, player in Players:GetPlayers() do
		local field, root = S.FieldService:GetPlayerField(player)
		if field and field.Id == fieldId and root then
			table.insert(list, { Player = player, Root = root })
		end
	end
	return list
end

local function broadcast(payload)
	MonsterService.Update:FireAllClients(payload)
end

function MonsterService:_move(m, now: number)
	local field = S.FieldService:GetField(m.FieldId)
	if not field then
		return
	end
	local from = self:Position(m, now)
	local target
	local present = playersInField(m.FieldId)
	if #present > 0 and rng:NextNumber() < 0.6 then
		local victim = present[rng:NextInteger(1, #present)]
		target = S.FieldService:RandomPointNear(field, victim.Root.Position, 6)
	else
		target = S.FieldService:RandomPointNear(field, field.Center, field.Half)
	end
	target = Vector3.new(target.X, field.Center.Y, target.Z)

	local speed = m.Def.Speed
	if m.SlowUntil > now then
		speed *= 1 - m.SlowFactor
	end
	-- Glacier Lattice: any player in this field with the synergy slows monsters
	for _, entry in present do
		local hive = S.BeeService:GetHiveMods(entry.Player)
		if hive and hive.MonsterSlow > 0 then
			speed *= 1 - hive.MonsterSlow
			break
		end
	end

	local distance = (target - from).Magnitude
	m.From = from
	m.To = target
	m.Start = now + rng:NextNumber() * 1.2 -- short pause before walking
	m.Duration = math.max(0.5, distance / math.max(speed, 0.5))
	broadcast({ Op = "Move", Id = m.Id, From = m.From, To = m.To, Start = m.Start, Duration = m.Duration })
end

-- Lifecycle of a monster -------------------------------------------------------------------

function MonsterService:Spawn(monsterType: string, fieldId: string, position: Vector3?, isEvent: boolean?)
	local def = Config.Monsters[monsterType]
	local field = S.FieldService:GetField(fieldId)
	if not def or not field then
		return nil
	end
	local id = nextId
	nextId = nextId % 60000 + 1
	local pos = position or S.FieldService:RandomPointNear(field, field.Center, field.Half)
	pos = Vector3.new(pos.X, field.Center.Y, pos.Z)
	local now = serverNow()
	local m = {
		Id = id,
		Type = monsterType,
		Def = def,
		FieldId = fieldId,
		Health = def.Health,
		MaxHealth = def.Health,
		From = pos,
		To = pos,
		Start = now,
		Duration = 0,
		SlowUntil = 0,
		SlowFactor = 0,
		Contributors = {},
		Event = isEvent == true,
		LastSeenPlayers = os.clock(),
	}
	monsters[id] = m
	field.Monsters += 1
	broadcast({ Op = "Spawn", Id = id, Type = monsterType, Pos = pos, Health = m.Health, MaxHealth = m.MaxHealth })
	return m
end

function MonsterService:_remove(m, killed: boolean)
	if not monsters[m.Id] then
		return
	end
	monsters[m.Id] = nil
	local field = S.FieldService:GetField(m.FieldId)
	if field then
		field.Monsters = math.max(0, field.Monsters - 1)
	end
	broadcast({ Op = killed and "Die" or "Despawn", Id = m.Id })
end

function MonsterService:_kill(m, killer: Player?)
	local field = S.FieldService:GetField(m.FieldId)
	local fieldMult = field and field.Def.Multiplier or 1
	local eventState = S.FieldService:GetEventState()
	local eventMult = (eventState and eventState.FieldId == m.FieldId) and Config.Events.Multiplier or 1
	local pos = self:Position(m)
	for player in m.Contributors do
		if player.Parent then
			local hive = S.BeeService:GetHiveMods(player)
			local honey = math.floor(m.Def.Honey * fieldMult * eventMult * (1 + (hive and hive.MonsterHoney or 0)))
			S.DataService:AddHoney(player, honey)
			local data = S.DataService:Get(player)
			if data then
				data.Stats.MonstersDefeated += 1
			end
			Notify.FxTo(player, "Honey", { Position = pos + Vector3.new(0, 3, 0), Amount = honey })
			-- world bosses also drop an egg for everyone who fought
			if m.Def.EggReward and data then
				data.Eggs[m.Def.EggReward] = (data.Eggs[m.Def.EggReward] or 0) + 1
				S.DataService:MarkDirty(player, "Eggs")
				Notify.Player(player, `{m.Def.Name} defeated! +1 {Config.Eggs[m.Def.EggReward].Name}`, "rare")
			end
		end
	end
	if m.Def.Boss and m.WorldBoss then
		Notify.All(`{m.Def.Name} was defeated!`, "event")
	end
	self:_remove(m, true)
	killedEvent:Fire(m, killer)
end

-- Damage & control -------------------------------------------------------------------------------

function MonsterService:Damage(m, amount: number, player: Player?): number
	if type(m) == "number" then
		m = monsters[m]
	end
	if not m or m.Health <= 0 or amount <= 0 then
		return 0
	end
	local dealt = math.min(m.Health, amount)
	m.Health -= dealt
	if player then
		m.Contributors[player] = (m.Contributors[player] or 0) + dealt
	end
	broadcast({ Op = "Hit", Id = m.Id, Health = m.Health })
	if m.Health <= 0 then
		self:_kill(m, player)
	end
	return dealt
end

function MonsterService:FindNearest(fieldId: string, position: Vector3, range: number)
	local best, bestDist = nil, range
	local now = serverNow()
	for _, m in monsters do
		if m.FieldId == fieldId then
			local dist = (self:Position(m, now) - position).Magnitude
			if dist <= bestDist then
				best, bestDist = m, dist
			end
		end
	end
	return best
end

function MonsterService:DamageArea(fieldId: string, center: Vector3, radius: number, damage: number, player: Player?): number
	local hits = 0
	local now = serverNow()
	for _, m in table.clone(monsters) do
		if m.FieldId == fieldId and (self:Position(m, now) - center).Magnitude <= radius + m.Def.Size / 2 then
			self:Damage(m, damage, player)
			hits += 1
		end
	end
	return hits
end

-- Used by bee abilities. Returns damage dealt and where the (first) hit landed.
function MonsterService:Strike(fieldId: string, center: Vector3, range: number, damage: number, hitAll: boolean, player: Player?)
	if hitAll then
		local total, at = 0, nil
		local now = serverNow()
		for _, m in table.clone(monsters) do
			if m.FieldId == fieldId and (self:Position(m, now) - center).Magnitude <= range then
				at = at or self:Position(m, now)
				total += self:Damage(m, damage, player)
			end
		end
		return total, at
	end
	local target = self:FindNearest(fieldId, center, range)
	if not target then
		return 0, nil
	end
	local at = self:Position(target)
	return self:Damage(target, damage, player), at
end

function MonsterService:SlowArea(fieldId: string, center: Vector3, radius: number, factor: number, duration: number)
	local now = serverNow()
	for _, m in monsters do
		if m.FieldId == fieldId and (self:Position(m, now) - center).Magnitude <= radius then
			m.SlowUntil = now + duration
			m.SlowFactor = math.max(m.SlowFactor, factor)
			broadcast({ Op = "Slow", Id = m.Id, Until = m.SlowUntil })
		end
	end
end

function MonsterService:CountEvent(): number
	local n = 0
	for _, m in monsters do
		if m.Event then
			n += 1
		end
	end
	return n
end

function MonsterService:ClearEvent()
	for _, m in table.clone(monsters) do
		if m.Event then
			self:_remove(m, false)
		end
	end
end

-- Loops -------------------------------------------------------------------------------------------

function MonsterService:_tick()
	local now = serverNow()
	local clock = os.clock()
	local present = {}
	for _, m in table.clone(monsters) do
		local list = present[m.FieldId]
		if not list then
			list = playersInField(m.FieldId)
			present[m.FieldId] = list
		end
		if #list > 0 then
			m.LastSeenPlayers = clock
		elseif not m.Event and not m.WorldBoss and clock - m.LastSeenPlayers > IDLE_DESPAWN then
			self:_remove(m, false)
			continue
		end

		if now >= m.Start + m.Duration then
			self:_move(m, now)
		end

		-- drain pollen from players in reach
		local pos = self:Position(m, now)
		for _, entry in list do
			if (entry.Root.Position - pos).Magnitude <= m.Def.DrainRange then
				local data = S.DataService:Get(entry.Player)
				if data and data.Pollen > 0 then
					data.Pollen = math.max(0, data.Pollen - m.Def.Drain * TICK)
					S.DataService:MarkDirty(entry.Player, "Pollen")
				end
			end
		end
	end
end

function MonsterService:_spawnTick()
	local clock = os.clock()
	for fieldId, types in Config.MonsterSpawns.Fields do
		local field = S.FieldService:GetField(fieldId)
		if field and clock - (lastSpawn[fieldId] or 0) >= Config.MonsterSpawns.Interval then
			lastSpawn[fieldId] = clock
			local regular = 0
			for _, m in monsters do
				if m.FieldId == fieldId and not m.Event then
					regular += 1
				end
			end
			if regular < Config.MonsterSpawns.MaxPerField and #playersInField(fieldId) > 0 then
				self:Spawn(types[rng:NextInteger(1, #types)], fieldId)
			end
		end
	end
end

-- World bosses: one at a time, in a random high field, announced to the whole server
local nextBoss = os.clock() + 60
-- clients read these for the world clock HUD (server time, so every client agrees)
local function publishBoss(field: string?, escapeAt: number?)
	local now = Workspace:GetServerTimeNow()
	Workspace:SetAttribute("NextBossAt", now + math.max(0, nextBoss - os.clock()))
	Workspace:SetAttribute("BossField", field)
	Workspace:SetAttribute("BossEscapeAt", escapeAt and now + math.max(0, escapeAt - os.clock()) or nil)
end

function MonsterService:_bossTick()
	local clock = os.clock()
	for _, m in monsters do
		if m.WorldBoss then
			if clock > m.EscapeAt then
				self:_remove(m, false)
				Notify.All(`The {m.Def.Name} escaped...`, "info")
				publishBoss(nil)
			else
				local field = S.FieldService:GetField(m.FieldId)
				publishBoss(field and field.Def.Name or m.FieldId, m.EscapeAt)
			end
			return
		end
	end
	publishBoss(nil)
	if clock < nextBoss then
		return
	end
	local interval = RunService:IsStudio() and Config.Bosses.StudioInterval or Config.Bosses.Interval
	nextBoss = clock + interval
	local bossType = Config.Bosses.Types[rng:NextInteger(1, #Config.Bosses.Types)]
	local fieldId = Config.Bosses.Fields[rng:NextInteger(1, #Config.Bosses.Fields)]
	local field = S.FieldService:GetField(fieldId)
	local m = field and self:Spawn(bossType, fieldId, field.Center)
	if m then
		m.WorldBoss = true
		m.EscapeAt = clock + Config.Bosses.Lifetime
		Notify.All(`BOSS: a {m.Def.Name} appeared in {field.Def.Name}!`, "event")
	end
end

function MonsterService:Init(services)
	S = services
	self.Update = Net.Event("MonsterUpdate")
	self.GetMonsters = Net.Function("GetMonsters")
end

function MonsterService:Start()
	self.GetMonsters.OnServerInvoke = function()
		local list = {}
		for _, m in monsters do
			table.insert(list, {
				Id = m.Id,
				Type = m.Type,
				From = m.From,
				To = m.To,
				Start = m.Start,
				Duration = m.Duration,
				Health = m.Health,
				MaxHealth = m.MaxHealth,
			})
		end
		return list
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, m in monsters do
			m.Contributors[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn("[MonsterService] tick:", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			pcall(self._spawnTick, self)
			local ok, err = pcall(self._bossTick, self)
			if not ok then
				warn("[MonsterService] boss:", err)
			end
		end
	end)
end

return MonsterService
