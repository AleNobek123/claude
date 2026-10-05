--[[
	BeeClass
	One bee in a player's swarm. Shared module:
	  - the server runs gameplay with it (stats, XP, ability casting through a context),
	  - the client uses the same stat math for the hive UI, so numbers always match.

	The class never touches the world directly. Ability effects go through a CastContext
	supplied by the server (dependency injection), which keeps the class testable and
	means an exploiter cannot trigger effects by requiring it on the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)

local BURST_SCALE = 0.2 -- share of a bee's gather stat harvested per tile by an ability

export type BeeRecord = {
	Id: string,
	Level: number,
	XP: number,
	Mutation: string?,
	Hatched: number?,
}

export type Modifiers = {
	Gather: number,
	Attack: number,
	Cooldown: number,
	AbilityPower: number,
	All: number,
	Radius: number,
}

export type Stats = {
	Gather: number,
	GatherTime: number,
	Speed: number,
	Convert: number,
	Attack: number,
	AbilityPower: number,
	AbilityCooldown: number?,
	AbilityRadius: number,
}

-- What the server lends a bee when it casts. Every function is authoritative server code.
export type CastContext = {
	Owner: Player,
	Origin: Vector3, -- owner's position
	PickPoint: (spread: number) -> Vector3, -- random point on the owner's field near the owner
	Harvest: (center: Vector3, radius: number, perTile: number, color: string?) -> number,
	Strike: (center: Vector3, range: number, damage: number, hitAll: boolean) -> (number, Vector3?),
	Slow: (center: Vector3, radius: number, factor: number, duration: number) -> (),
	ConvertFraction: (fraction: number) -> number,
}

export type CastResult = {
	Fx: string,
	Points: { Vector3 },
	Radius: number,
	Amount: number,
}

local DEFAULT_MODS: Modifiers = table.freeze({
	Gather = 1,
	Attack = 1,
	Cooldown = 1,
	AbilityPower = 1,
	All = 1,
	Radius = 1,
})

local BeeClass = {}
BeeClass.__index = BeeClass

export type Bee = typeof(setmetatable(
	{} :: {
		Slot: number,
		Record: BeeRecord,
		Def: any,
		Owner: Player?,
		Mods: Modifiers,
		Stats: Stats,
		NextAbilityAt: number,
		State: { [string]: any },
	},
	BeeClass
))

-- Static helpers -----------------------------------------------------------------

function BeeClass.LevelMultiplier(level: number): number
	return 1 + Config.Levels.StatPerLevel * (level - 1)
end

function BeeClass.XPToNext(level: number): number
	return math.floor(Config.Levels.XPBase * level ^ Config.Levels.XPExponent)
end

function BeeClass.ScoreOf(record: BeeRecord): number
	local def = BeeData.Bees[record.Id]
	if not def then
		return 0
	end
	local rarity = Config.Rarities[def.Rarity]
	local mutation = record.Mutation and Config.Mutations[record.Mutation]
	local mult = mutation and mutation.ScoreMult or 1
	return rarity.Points * mult * (1 + 0.05 * (record.Level - 1))
end

function BeeClass.SwarmScore(records: { [any]: BeeRecord }): number
	local total = 0
	for _, record in records do
		total += BeeClass.ScoreOf(record)
	end
	return math.floor(total + 0.5)
end

-- Rolls a mutation. With `serum`, a mutation is guaranteed and weighted by SerumWeight.
function BeeClass.RollMutation(rng: Random, serum: boolean?): string?
	if serum then
		local total = 0
		for _, name in Config.MutationOrder do
			total += Config.Mutations[name].SerumWeight
		end
		local roll = rng:NextNumber() * total
		for _, name in Config.MutationOrder do
			roll -= Config.Mutations[name].SerumWeight
			if roll <= 0 then
				return name
			end
		end
		return Config.MutationOrder[1]
	end
	-- rarest first so each chance is independent of the order of the table
	local roll = rng:NextNumber()
	for i = #Config.MutationOrder, 1, -1 do
		local name = Config.MutationOrder[i]
		local chance = Config.Mutations[name].Chance
		if roll < chance then
			return name
		end
		roll -= chance
	end
	return nil
end

function BeeClass.NewRecord(beeId: string, mutation: string?): BeeRecord
	return {
		Id = beeId,
		Level = 1,
		XP = 0,
		Mutation = mutation,
		Hatched = os.time(),
	}
end

-- Construction -----------------------------------------------------------------------

function BeeClass.new(slot: number, record: BeeRecord, owner: Player?): Bee
	local def = BeeData.Bees[record.Id]
	assert(def, `Unknown bee id "{record.Id}"`)

	local self = setmetatable({}, BeeClass)
	self.Slot = slot
	self.Record = record -- live reference into the player's profile
	self.Def = def
	self.Owner = owner
	self.Mods = DEFAULT_MODS
	self.Stats = {} :: any
	self.State = { Phase = "Follow", EndsAt = 0, Position = Vector3.zero }

	self:RecalculateStats()
	-- stagger the first cast so a freshly built swarm does not fire every ability at once
	local cooldown = self.Stats.AbilityCooldown or 0
	self.NextAbilityAt = os.clock() + cooldown * (0.3 + 0.7 * math.random())
	return self
end

-- Stats --------------------------------------------------------------------------------

function BeeClass.SetModifiers(self: Bee, mods: Modifiers?)
	self.Mods = mods or DEFAULT_MODS
	self:RecalculateStats()
end

function BeeClass.RecalculateStats(self: Bee)
	local def = self.Def
	local mods = self.Mods
	local level = math.clamp(self.Record.Level, 1, Config.Levels.Max)
	local mutation = self.Record.Mutation and Config.Mutations[self.Record.Mutation]

	local levelMult = BeeClass.LevelMultiplier(level)
	local speedMult = 1 + Config.Levels.SpeedPerLevel * (level - 1)
	local allMult = (mutation and mutation.All or 1) * mods.All
	local gatherMut = mutation and mutation.Gather or 1
	local abilityMut = mutation and mutation.Ability or 1

	local stats = self.Stats
	stats.Gather = def.Gather * levelMult * allMult * gatherMut * mods.Gather
	stats.GatherTime = def.GatherTime / speedMult
	stats.Speed = def.Speed * speedMult
	stats.Convert = def.Convert * levelMult * allMult
	stats.Attack = def.Attack * levelMult * allMult * mods.Attack
	stats.AbilityPower = abilityMut * mods.AbilityPower
	stats.AbilityCooldown = def.Ability and def.Ability.Cooldown * mods.Cooldown or nil
	stats.AbilityRadius = mods.Radius
end

function BeeClass.HasTag(self: Bee, tag: string): boolean
	return table.find(self.Def.Tags, tag) ~= nil
end

function BeeClass.GetScore(self: Bee): number
	return BeeClass.ScoreOf(self.Record)
end

-- Progression ----------------------------------------------------------------------------

-- Adds XP and levels up as many times as the XP allows. Returns levels gained.
function BeeClass.AddXP(self: Bee, amount: number): number
	local record = self.Record
	if record.Level >= Config.Levels.Max then
		return 0
	end
	record.XP += amount
	local gained = 0
	while record.Level < Config.Levels.Max and record.XP >= BeeClass.XPToNext(record.Level) do
		record.XP -= BeeClass.XPToNext(record.Level)
		record.Level += 1
		gained += 1
	end
	if record.Level >= Config.Levels.Max then
		record.XP = 0
	end
	if gained > 0 then
		self:RecalculateStats()
	end
	return gained
end

-- Abilities --------------------------------------------------------------------------------

local Abilities = {}

function Abilities.Burst(self: Bee, ability, ctx: CastContext): CastResult
	local radius = ability.Radius * self.Stats.AbilityRadius
	local center = ctx.PickPoint(8)
	local perTile = self.Stats.Gather * BURST_SCALE * ability.Power * self.Stats.AbilityPower
	local amount = ctx.Harvest(center, radius, perTile, self.Def.Color)
	if ability.Slow then
		ctx.Slow(center, radius, ability.Slow, ability.SlowTime)
	end
	if ability.StrikeMult then
		ctx.Strike(center, radius, self.Stats.Attack * ability.StrikeMult * self.Stats.AbilityPower, true)
	end
	return { Fx = ability.Fx, Points = { center }, Radius = radius, Amount = amount }
end

function Abilities.MultiBurst(self: Bee, ability, ctx: CastContext): CastResult
	local radius = ability.Radius * self.Stats.AbilityRadius
	local perTile = self.Stats.Gather * BURST_SCALE * ability.Power * self.Stats.AbilityPower
	local points = {}
	local amount = 0
	for _ = 1, ability.Count do
		local center = ctx.PickPoint(14)
		amount += ctx.Harvest(center, radius, perTile, self.Def.Color)
		table.insert(points, center)
	end
	return { Fx = ability.Fx, Points = points, Radius = radius, Amount = amount }
end

function Abilities.Strike(self: Bee, ability, ctx: CastContext): CastResult?
	local damage = self.Stats.Attack * ability.Damage * self.Stats.AbilityPower
	local dealt, hitAt = ctx.Strike(ctx.Origin, ability.Range, damage, false)
	if dealt <= 0 or not hitAt then
		return nil -- nothing in range: keep the ability ready
	end
	return { Fx = ability.Fx, Points = { hitAt }, Radius = 4, Amount = dealt }
end

function Abilities.InstantConvert(self: Bee, ability, ctx: CastContext): CastResult?
	local honey = ctx.ConvertFraction(ability.Fraction * self.Stats.AbilityPower)
	if honey <= 0 then
		return nil
	end
	return { Fx = ability.Fx, Points = { ctx.Origin }, Radius = 6, Amount = honey }
end

function BeeClass.IsAbilityReady(self: Bee, now: number): boolean
	return self.Def.Ability ~= nil and now >= self.NextAbilityAt
end

-- Casts the bee's ability through the server context. Returns an FX description for
-- clients, or nil when nothing happened (the cooldown is then not consumed).
function BeeClass.CastAbility(self: Bee, ctx: CastContext, now: number): CastResult?
	local ability = self.Def.Ability
	if not ability or now < self.NextAbilityAt then
		return nil
	end
	local handler = Abilities[ability.Type]
	if not handler then
		warn(`[BeeClass] No handler for ability type {ability.Type}`)
		return nil
	end
	local ok, result = pcall(handler, self, ability, ctx)
	if not ok then
		warn(`[BeeClass] {ability.Id} failed: {result}`)
		self.NextAbilityAt = now + (self.Stats.AbilityCooldown or 5)
		return nil
	end
	if result then
		self.NextAbilityAt = now + (self.Stats.AbilityCooldown or 5)
	else
		self.NextAbilityAt = now + 1 -- retry soon
	end
	return result
end

function BeeClass.Serialize(self: Bee): BeeRecord
	return table.clone(self.Record)
end

function BeeClass.Destroy(self: Bee)
	self.Owner = nil
	table.clear(self.State)
end

return BeeClass
