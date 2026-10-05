--[[
	BeeData
	Static definitions of every bee. Stats are level-1 base values; BeeClass applies
	level, mutation and synergy multipliers on top.

	Gather      pollen per gather (before field/colour multipliers)
	GatherTime  seconds spent on one flower
	Speed       flight speed in studs per second
	Convert     pollen converted to honey per hive trip
	Attack      damage per strike against field monsters
	Ability     active skill cast automatically while the owner is in a field
	Passive     hive-wide bonus, summed over the swarm
]]

local BeeData = {}

BeeData.Order = {
	"Basic", "Busy", "Bumble",
	"Honey", "Fire", "Frost", "Guard",
	"Bomber", "Soldier", "Ember", "Crystal", "Night",
	"Phoenix", "QueensGuard", "Golden",
	"Solar", "Void",
}

BeeData.Bees = {
	-- Common ---------------------------------------------------------------
	Basic = {
		Name = "Basic Bee", Rarity = "Common", Color = "White", Tags = { "Worker" },
		Gather = 10, GatherTime = 4.0, Speed = 14, Convert = 80, Attack = 1,
		Description = "A dependable all-rounder.",
		Visual = { Body = Color3.fromRGB(255, 200, 40), Stripe = Color3.fromRGB(40, 30, 20) },
	},
	Busy = {
		Name = "Busy Bee", Rarity = "Common", Color = "White", Tags = { "Worker" },
		Gather = 7, GatherTime = 2.5, Speed = 18, Convert = 60, Attack = 1,
		Description = "Small hauls, but never stops moving.",
		Visual = { Body = Color3.fromRGB(255, 225, 90), Stripe = Color3.fromRGB(70, 50, 30) },
	},
	Bumble = {
		Name = "Bumble Bee", Rarity = "Common", Color = "Blue", Tags = { "Worker" },
		Gather = 18, GatherTime = 5.5, Speed = 11, Convert = 120, Attack = 1,
		Description = "Slow and fluffy, carries big loads.",
		Visual = { Body = Color3.fromRGB(110, 140, 230), Stripe = Color3.fromRGB(30, 30, 50) },
	},

	-- Rare -------------------------------------------------------------------
	Honey = {
		Name = "Honey Bee", Rarity = "Rare", Color = "White", Tags = { "Honey" },
		Gather = 12, GatherTime = 4.0, Speed = 15, Convert = 200, Attack = 1,
		Description = "Its hive works faster: +20% convert speed.",
		Passive = { HiveConvert = 0.2 },
		Visual = { Body = Color3.fromRGB(255, 170, 30), Stripe = Color3.fromRGB(120, 70, 10) },
	},
	Fire = {
		Name = "Fire Bee", Rarity = "Rare", Color = "Red", Tags = { "Fire" },
		Gather = 14, GatherTime = 4.0, Speed = 15, Convert = 100, Attack = 2,
		Description = "Sets flowers ablaze for a burst of pollen.",
		Ability = { Id = "FlamePatch", Name = "Flame Patch", Type = "Burst", Cooldown = 15, Radius = 6, Power = 1.5, Fx = "Fire" },
		Visual = { Body = Color3.fromRGB(240, 80, 50), Stripe = Color3.fromRGB(60, 20, 10) },
	},
	Frost = {
		Name = "Frost Bee", Rarity = "Rare", Color = "Blue", Tags = { "Frost" },
		Gather = 14, GatherTime = 4.0, Speed = 15, Convert = 100, Attack = 2,
		Description = "Freezes a patch of flowers and slows monsters.",
		Ability = { Id = "FrostNova", Name = "Frost Nova", Type = "Burst", Cooldown = 15, Radius = 6, Power = 1.0, Fx = "Frost", Slow = 0.5, SlowTime = 4 },
		Visual = { Body = Color3.fromRGB(150, 220, 255), Stripe = Color3.fromRGB(40, 70, 120) },
	},
	Guard = {
		Name = "Guard Bee", Rarity = "Rare", Color = "Red", Tags = { "Soldier" },
		Gather = 10, GatherTime = 4.0, Speed = 16, Convert = 80, Attack = 5,
		Description = "Hunts monsters that come near you.",
		Visual = { Body = Color3.fromRGB(200, 70, 70), Stripe = Color3.fromRGB(50, 50, 55) },
	},

	-- Epic -----------------------------------------------------------------------
	Bomber = {
		Name = "Bomber Bee", Rarity = "Epic", Color = "Blue", Tags = { "Explosive" },
		Gather = 16, GatherTime = 3.5, Speed = 16, Convert = 140, Attack = 3,
		Description = "Drops pollen bombs that harvest a wide area.",
		Ability = { Id = "PollenBomb", Name = "Pollen Bomb", Type = "Burst", Cooldown = 12, Radius = 8, Power = 3, Fx = "Bomb" },
		Visual = { Body = Color3.fromRGB(90, 100, 120), Stripe = Color3.fromRGB(255, 120, 40) },
	},
	Soldier = {
		Name = "Soldier Bee", Rarity = "Epic", Color = "Red", Tags = { "Soldier" },
		Gather = 14, GatherTime = 3.5, Speed = 18, Convert = 120, Attack = 10,
		Description = "Defends your field with heavy strikes.",
		Ability = { Id = "Defend", Name = "Defend", Type = "Strike", Cooldown = 8, Damage = 5, Range = 40, Fx = "Strike" },
		Visual = { Body = Color3.fromRGB(180, 40, 40), Stripe = Color3.fromRGB(230, 200, 60) },
	},
	Ember = {
		Name = "Ember Bee", Rarity = "Epic", Color = "Red", Tags = { "Fire" },
		Gather = 20, GatherTime = 3.5, Speed = 16, Convert = 150, Attack = 4,
		Description = "A bigger blaze for bigger harvests.",
		Ability = { Id = "Blaze", Name = "Blaze", Type = "Burst", Cooldown = 14, Radius = 9, Power = 2, Fx = "Fire" },
		Visual = { Body = Color3.fromRGB(255, 120, 40), Stripe = Color3.fromRGB(120, 20, 10) },
	},
	Crystal = {
		Name = "Crystal Bee", Rarity = "Epic", Color = "Blue", Tags = { "Frost" },
		Gather = 20, GatherTime = 3.5, Speed = 16, Convert = 150, Attack = 4,
		Description = "Shatters crystal shards over flowers.",
		Ability = { Id = "CrystalShards", Name = "Crystal Shards", Type = "Burst", Cooldown = 14, Radius = 9, Power = 2, Fx = "Frost", Slow = 0.6, SlowTime = 5 },
		Visual = { Body = Color3.fromRGB(170, 240, 255), Stripe = Color3.fromRGB(80, 120, 200) },
	},
	Night = {
		Name = "Night Bee", Rarity = "Epic", Color = "Blue", Tags = { "Shadow" },
		Gather = 18, GatherTime = 3.5, Speed = 17, Convert = 140, Attack = 5,
		Description = "Wraps flowers in a pollen-rich night veil.",
		Ability = { Id = "NightVeil", Name = "Night Veil", Type = "Burst", Cooldown = 15, Radius = 8, Power = 2, Fx = "Shadow" },
		Visual = { Body = Color3.fromRGB(60, 50, 110), Stripe = Color3.fromRGB(200, 190, 255) },
	},

	-- Legendary ----------------------------------------------------------------------
	Phoenix = {
		Name = "Phoenix Bee", Rarity = "Legendary", Color = "Red", Tags = { "Fire", "Royal" },
		Gather = 32, GatherTime = 3.0, Speed = 20, Convert = 300, Attack = 8,
		Description = "Rains three fire patches; +10% red pollen for the hive.",
		Ability = { Id = "RebirthFlames", Name = "Rebirth Flames", Type = "MultiBurst", Count = 3, Cooldown = 16, Radius = 7, Power = 2.5, Fx = "Fire" },
		Passive = { RedPollen = 0.1 },
		Visual = { Body = Color3.fromRGB(255, 90, 30), Stripe = Color3.fromRGB(255, 220, 80), Accessory = "Crown" },
	},
	QueensGuard = {
		Name = "Queen's Guard", Rarity = "Legendary", Color = "White", Tags = { "Soldier", "Royal" },
		Gather = 24, GatherTime = 3.0, Speed = 22, Convert = 250, Attack = 30,
		Description = "Royal Strike; monsters drop 2x honey.",
		Ability = { Id = "RoyalStrike", Name = "Royal Strike", Type = "Strike", Cooldown = 6, Damage = 8, Range = 45, Fx = "Strike" },
		Passive = { MonsterHoney = 1 },
		Visual = { Body = Color3.fromRGB(240, 240, 250), Stripe = Color3.fromRGB(190, 40, 60), Accessory = "Crown" },
	},
	Golden = {
		Name = "Golden Bee", Rarity = "Legendary", Color = "White", Tags = { "Honey", "Light", "Royal" },
		Gather = 28, GatherTime = 3.0, Speed = 20, Convert = 500, Attack = 4,
		Description = "Golden Touch converts part of your bag; +15% honey.",
		Ability = { Id = "GoldenTouch", Name = "Golden Touch", Type = "InstantConvert", Cooldown = 30, Fraction = 0.05, Fx = "Gold" },
		Passive = { HoneyMult = 0.15 },
		Visual = { Body = Color3.fromRGB(255, 215, 60), Stripe = Color3.fromRGB(255, 250, 200), Accessory = "Crown" },
	},

	-- Mythic --------------------------------------------------------------------------
	Solar = {
		Name = "Solar Bee", Rarity = "Mythic", Color = "White", Tags = { "Light", "Royal" },
		Gather = 50, GatherTime = 2.5, Speed = 24, Convert = 600, Attack = 15,
		Description = "Solar Flare harvests a huge area; +10% all pollen.",
		Ability = { Id = "SolarFlare", Name = "Solar Flare", Type = "Burst", Cooldown = 18, Radius = 15, Power = 5, Fx = "Solar" },
		Passive = { PollenMult = 0.1 },
		Visual = { Body = Color3.fromRGB(255, 240, 150), Stripe = Color3.fromRGB(255, 150, 40), Accessory = "Halo" },
	},
	Void = {
		Name = "Void Bee", Rarity = "Mythic", Color = "Blue", Tags = { "Shadow", "Royal" },
		Gather = 50, GatherTime = 2.5, Speed = 24, Convert = 600, Attack = 25,
		Description = "Black Hole pulls in pollen and crushes monsters.",
		Ability = { Id = "BlackHole", Name = "Black Hole", Type = "Burst", Cooldown = 18, Radius = 18, Power = 4, Fx = "Void", StrikeMult = 10 },
		Visual = { Body = Color3.fromRGB(40, 20, 70), Stripe = Color3.fromRGB(170, 80, 255), Accessory = "Halo" },
	},
}

-- bees grouped by rarity, used by egg rolls (equal chance inside a rarity)
BeeData.ByRarity = {}
for _, id in BeeData.Order do
	local def = BeeData.Bees[id]
	def.Id = id
	BeeData.ByRarity[def.Rarity] = BeeData.ByRarity[def.Rarity] or {}
	table.insert(BeeData.ByRarity[def.Rarity], id)
end

function BeeData.Get(id: string)
	return BeeData.Bees[id]
end

function BeeData.HasTag(id: string, tag: string): boolean
	local def = BeeData.Bees[id]
	if not def then
		return false
	end
	return table.find(def.Tags, tag) ~= nil
end

return BeeData
