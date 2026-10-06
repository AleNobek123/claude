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
	"Basic", "Busy", "Bumble", "Rascal", "Cool", "Sunny",
	"Honey", "Fire", "Frost", "Guard", "Bubble", "Leaf", "Spark",
	"Bomber", "Soldier", "Ember", "Crystal", "Night", "Ninja", "Toxic", "Candy",
	"Phoenix", "QueensGuard", "Golden", "Thunder", "Lion",
	"Solar", "Void", "Galaxy", "Diamond",
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
		Visual = { Body = Color3.fromRGB(255, 225, 90), Stripe = Color3.fromRGB(70, 50, 30), Shape = Vector3.new(0.82, 0.82, 1.15) },
	},
	Bumble = {
		Name = "Bumble Bee", Rarity = "Common", Color = "Blue", Tags = { "Worker" },
		Gather = 18, GatherTime = 5.5, Speed = 11, Convert = 120, Attack = 1,
		Description = "Slow and fluffy, carries big loads.",
		Visual = { Body = Color3.fromRGB(110, 140, 230), Stripe = Color3.fromRGB(30, 30, 50), Shape = Vector3.new(1.22, 1.15, 1.0), Extras = { "Fluff" } },
	},

	Rascal = {
		Name = "Rascal Bee", Rarity = "Common", Color = "Red", Tags = { "Worker" },
		Gather = 9, GatherTime = 3.6, Speed = 16, Convert = 70, Attack = 3,
		Description = "A cheeky fighter that loves red flowers.",
		Visual = { Body = Color3.fromRGB(235, 90, 70), Stripe = Color3.fromRGB(50, 25, 20), Extras = { "Bandana", "Horns" } },
	},
	Cool = {
		Name = "Cool Bee", Rarity = "Common", Color = "Blue", Tags = { "Worker" },
		Gather = 11, GatherTime = 4.0, Speed = 15, Convert = 90, Attack = 1,
		Description = "Calm, steady and great with blue flowers.",
		Visual = { Body = Color3.fromRGB(120, 200, 255), Stripe = Color3.fromRGB(30, 50, 80), Extras = { "Shades" } },
	},
	Sunny = {
		Name = "Sunny Bee", Rarity = "Common", Color = "White", Tags = { "Worker" },
		Gather = 12, GatherTime = 4.2, Speed = 14, Convert = 95, Attack = 1,
		Description = "Always smiling, always gathering.",
		Visual = { Body = Color3.fromRGB(255, 235, 120), Stripe = Color3.fromRGB(200, 120, 30), Shape = Vector3.new(1.08, 1.05, 1.0), Extras = { "Flower" } },
	},

	-- Rare -------------------------------------------------------------------
	Honey = {
		Name = "Honey Bee", Rarity = "Rare", Color = "White", Tags = { "Honey" },
		Gather = 12, GatherTime = 4.0, Speed = 15, Convert = 200, Attack = 1,
		Description = "Its hive works faster: +20% convert speed.",
		Passive = { HiveConvert = 0.2 },
		Visual = { Body = Color3.fromRGB(255, 170, 30), Stripe = Color3.fromRGB(120, 70, 10), Shape = Vector3.new(1.12, 1.1, 1.0), Extras = { "Drop", "Drips" } },
	},
	Fire = {
		Name = "Fire Bee", Rarity = "Rare", Color = "Red", Tags = { "Fire" },
		Gather = 14, GatherTime = 4.0, Speed = 15, Convert = 100, Attack = 2,
		Description = "Sets flowers ablaze for a burst of pollen.",
		Ability = { Id = "FlamePatch", Name = "Flame Patch", Type = "Burst", Cooldown = 15, Radius = 6, Power = 1.5, Fx = "Fire" },
		Visual = { Body = Color3.fromRGB(240, 80, 50), Stripe = Color3.fromRGB(60, 20, 10), Extras = { "Crest" }, Aura = "Fire" },
	},
	Frost = {
		Name = "Frost Bee", Rarity = "Rare", Color = "Blue", Tags = { "Frost" },
		Gather = 14, GatherTime = 4.0, Speed = 15, Convert = 100, Attack = 2,
		Description = "Freezes a patch of flowers and slows monsters.",
		Ability = { Id = "FrostNova", Name = "Frost Nova", Type = "Burst", Cooldown = 15, Radius = 6, Power = 1.0, Fx = "Frost", Slow = 0.5, SlowTime = 4 },
		Visual = { Body = Color3.fromRGB(150, 220, 255), Stripe = Color3.fromRGB(40, 70, 120), Extras = { "Spikes" }, Aura = "Frost" },
	},
	Guard = {
		Name = "Guard Bee", Rarity = "Rare", Color = "Red", Tags = { "Soldier" },
		Gather = 10, GatherTime = 4.0, Speed = 16, Convert = 80, Attack = 5,
		Description = "Hunts monsters that come near you.",
		Visual = { Body = Color3.fromRGB(200, 70, 70), Stripe = Color3.fromRGB(50, 50, 55), Shape = Vector3.new(1.1, 1.05, 1.05), Extras = { "Helmet" } },
	},

	Bubble = {
		Name = "Bubble Bee", Rarity = "Rare", Color = "Blue", Tags = { "Water" },
		Gather = 14, GatherTime = 3.8, Speed = 15, Convert = 110, Attack = 2,
		Description = "Pops pollen bubbles over blue flowers.",
		Ability = { Id = "BubblePop", Name = "Bubble Pop", Type = "Burst", Cooldown = 13, Radius = 6, Power = 1.4, Fx = "Water" },
		Visual = { Body = Color3.fromRGB(90, 170, 255), Stripe = Color3.fromRGB(230, 245, 255), Shape = Vector3.new(1.1, 1.1, 0.95), Extras = { "Bubble" } },
	},
	Leaf = {
		Name = "Leaf Bee", Rarity = "Rare", Color = "White", Tags = { "Nature" },
		Gather = 15, GatherTime = 3.8, Speed = 15, Convert = 110, Attack = 1,
		Description = "Leaf Gust sweeps a patch of white flowers.",
		Ability = { Id = "LeafGust", Name = "Leaf Gust", Type = "Burst", Cooldown = 14, Radius = 7, Power = 1.3, Fx = "Nature" },
		Visual = { Body = Color3.fromRGB(120, 210, 90), Stripe = Color3.fromRGB(40, 90, 30), Shape = Vector3.new(0.92, 0.95, 1.08), Extras = { "Leaf" } },
	},
	Spark = {
		Name = "Spark Bee", Rarity = "Rare", Color = "White", Tags = { "Electric" },
		Gather = 12, GatherTime = 3.6, Speed = 18, Convert = 100, Attack = 4,
		Description = "Static Shock zaps the nearest monster.",
		Ability = { Id = "StaticShock", Name = "Static Shock", Type = "Strike", Cooldown = 9, Damage = 6, Range = 35, Fx = "Electric" },
		Visual = { Body = Color3.fromRGB(255, 240, 90), Stripe = Color3.fromRGB(70, 90, 200), Extras = { "Bolts" }, Aura = "Spark" },
	},

	-- Epic -----------------------------------------------------------------------
	Bomber = {
		Name = "Bomber Bee", Rarity = "Epic", Color = "Blue", Tags = { "Explosive" },
		Gather = 16, GatherTime = 3.5, Speed = 16, Convert = 140, Attack = 3,
		Description = "Drops pollen bombs that harvest a wide area.",
		Ability = { Id = "PollenBomb", Name = "Pollen Bomb", Type = "Burst", Cooldown = 12, Radius = 8, Power = 3, Fx = "Bomb" },
		Visual = { Body = Color3.fromRGB(90, 100, 120), Stripe = Color3.fromRGB(255, 120, 40), Shape = Vector3.new(1.15, 1.1, 1.0), Extras = { "Bomb", "Shades" } },
	},
	Soldier = {
		Name = "Soldier Bee", Rarity = "Epic", Color = "Red", Tags = { "Soldier" },
		Gather = 14, GatherTime = 3.5, Speed = 18, Convert = 120, Attack = 10,
		Description = "Defends your field with heavy strikes.",
		Ability = { Id = "Defend", Name = "Defend", Type = "Strike", Cooldown = 8, Damage = 5, Range = 40, Fx = "Strike" },
		Visual = { Body = Color3.fromRGB(180, 40, 40), Stripe = Color3.fromRGB(230, 200, 60), Shape = Vector3.new(1.05, 1.0, 1.12), Extras = { "Helmet", "Mask" } },
	},
	Ember = {
		Name = "Ember Bee", Rarity = "Epic", Color = "Red", Tags = { "Fire" },
		Gather = 20, GatherTime = 3.5, Speed = 16, Convert = 150, Attack = 4,
		Description = "A bigger blaze for bigger harvests.",
		Ability = { Id = "Blaze", Name = "Blaze", Type = "Burst", Cooldown = 14, Radius = 9, Power = 2, Fx = "Fire" },
		Visual = { Body = Color3.fromRGB(255, 120, 40), Stripe = Color3.fromRGB(120, 20, 10), Extras = { "Horns", "Crest" }, Aura = "Fire" },
	},
	Crystal = {
		Name = "Crystal Bee", Rarity = "Epic", Color = "Blue", Tags = { "Frost" },
		Gather = 20, GatherTime = 3.5, Speed = 16, Convert = 150, Attack = 4,
		Description = "Shatters crystal shards over flowers.",
		Ability = { Id = "CrystalShards", Name = "Crystal Shards", Type = "Burst", Cooldown = 14, Radius = 9, Power = 2, Fx = "Frost", Slow = 0.6, SlowTime = 5 },
		Visual = { Body = Color3.fromRGB(170, 240, 255), Stripe = Color3.fromRGB(80, 120, 200), Extras = { "Spikes", "Gem" }, Aura = "Frost" },
	},
	Night = {
		Name = "Night Bee", Rarity = "Epic", Color = "Blue", Tags = { "Shadow" },
		Gather = 18, GatherTime = 3.5, Speed = 17, Convert = 140, Attack = 5,
		Description = "Wraps flowers in a pollen-rich night veil.",
		Ability = { Id = "NightVeil", Name = "Night Veil", Type = "Burst", Cooldown = 15, Radius = 8, Power = 2, Fx = "Shadow" },
		Visual = { Body = Color3.fromRGB(60, 50, 110), Stripe = Color3.fromRGB(200, 190, 255), Shape = Vector3.new(0.95, 0.95, 1.1), Extras = { "Moon" }, Aura = "Stars" },
	},

	Ninja = {
		Name = "Ninja Bee", Rarity = "Epic", Color = "Blue", Tags = { "Soldier", "Shadow" },
		Gather = 16, GatherTime = 3.2, Speed = 22, Convert = 120, Attack = 12,
		Description = "Shuriken strikes from the shadows.",
		Ability = { Id = "Shuriken", Name = "Shuriken", Type = "Strike", Cooldown = 7, Damage = 10, Range = 45, Fx = "Shadow" },
		Visual = { Body = Color3.fromRGB(45, 45, 60), Stripe = Color3.fromRGB(200, 40, 60), Shape = Vector3.new(0.82, 0.85, 1.18), Extras = { "Mask" } },
	},
	Toxic = {
		Name = "Toxic Bee", Rarity = "Epic", Color = "Red", Tags = { "Toxic" },
		Gather = 19, GatherTime = 3.5, Speed = 16, Convert = 140, Attack = 5,
		Description = "Toxic Cloud harvests and slows monsters.",
		Ability = { Id = "ToxicCloud", Name = "Toxic Cloud", Type = "Burst", Cooldown = 14, Radius = 9, Power = 2, Fx = "Toxic", Slow = 0.5, SlowTime = 4 },
		Visual = { Body = Color3.fromRGB(150, 230, 60), Stripe = Color3.fromRGB(90, 30, 110), Extras = { "Drips", "Horns" }, Aura = "Toxic" },
	},
	Candy = {
		Name = "Candy Bee", Rarity = "Epic", Color = "Red", Tags = { "Honey" },
		Gather = 15, GatherTime = 3.5, Speed = 16, Convert = 260, Attack = 2,
		Description = "Sugar Rush converts a bit of your bag; +15% hive convert speed.",
		Ability = { Id = "SugarRush", Name = "Sugar Rush", Type = "InstantConvert", Cooldown = 30, Fraction = 0.02, Fx = "Candy" },
		Passive = { HiveConvert = 0.15 },
		Visual = { Body = Color3.fromRGB(255, 140, 200), Stripe = Color3.fromRGB(255, 250, 250), Shape = Vector3.new(1.1, 1.1, 0.95), Extras = { "Candy" } },
	},

	-- Legendary ----------------------------------------------------------------------
	Phoenix = {
		Name = "Phoenix Bee", Rarity = "Legendary", Color = "Red", Tags = { "Fire", "Royal" },
		Gather = 32, GatherTime = 3.0, Speed = 20, Convert = 300, Attack = 8,
		Description = "Rains three fire patches; +10% red pollen for the hive.",
		Ability = { Id = "RebirthFlames", Name = "Rebirth Flames", Type = "MultiBurst", Count = 3, Cooldown = 16, Radius = 7, Power = 2.5, Fx = "Fire" },
		Passive = { RedPollen = 0.1 },
		Visual = { Body = Color3.fromRGB(255, 90, 30), Stripe = Color3.fromRGB(255, 220, 80), Accessory = "Crown", Shape = Vector3.new(0.95, 1.0, 1.15), Extras = { "Crest" }, Aura = "Fire" },
	},
	QueensGuard = {
		Name = "Queen's Guard", Rarity = "Legendary", Color = "White", Tags = { "Soldier", "Royal" },
		Gather = 24, GatherTime = 3.0, Speed = 22, Convert = 250, Attack = 30,
		Description = "Royal Strike; monsters drop 2x honey.",
		Ability = { Id = "RoyalStrike", Name = "Royal Strike", Type = "Strike", Cooldown = 6, Damage = 8, Range = 45, Fx = "Strike" },
		Passive = { MonsterHoney = 1 },
		Visual = { Body = Color3.fromRGB(240, 240, 250), Stripe = Color3.fromRGB(190, 40, 60), Accessory = "Crown", Shape = Vector3.new(1.1, 1.08, 1.1), Extras = { "Helmet", "Gem" } },
	},
	Golden = {
		Name = "Golden Bee", Rarity = "Legendary", Color = "White", Tags = { "Honey", "Light", "Royal" },
		Gather = 28, GatherTime = 3.0, Speed = 20, Convert = 500, Attack = 4,
		Description = "Golden Touch converts part of your bag; +15% honey.",
		Ability = { Id = "GoldenTouch", Name = "Golden Touch", Type = "InstantConvert", Cooldown = 30, Fraction = 0.05, Fx = "Gold" },
		Passive = { HoneyMult = 0.15 },
		Visual = { Body = Color3.fromRGB(255, 215, 60), Stripe = Color3.fromRGB(255, 250, 200), Accessory = "Crown", Extras = { "Gem", "Drips" }, Aura = "Gold" },
	},

	Thunder = {
		Name = "Thunder Bee", Rarity = "Legendary", Color = "Blue", Tags = { "Electric", "Royal" },
		Gather = 30, GatherTime = 3.0, Speed = 22, Convert = 300, Attack = 10,
		Description = "Thunderstorm strikes four patches of flowers at once.",
		Ability = { Id = "Thunderstorm", Name = "Thunderstorm", Type = "MultiBurst", Count = 4, Cooldown = 16, Radius = 6, Power = 2.5, Fx = "Electric" },
		Visual = { Body = Color3.fromRGB(70, 110, 255), Stripe = Color3.fromRGB(255, 245, 120), Accessory = "Crown", Shape = Vector3.new(0.95, 0.95, 1.12), Extras = { "Bolts", "Mask" }, Aura = "Spark" },
	},
	Lion = {
		Name = "Lion Bee", Rarity = "Legendary", Color = "White", Tags = { "Soldier", "Royal" },
		Gather = 26, GatherTime = 3.0, Speed = 20, Convert = 260, Attack = 35,
		Description = "Roar hits every monster nearby; monsters drop +50% honey.",
		Ability = { Id = "Roar", Name = "Roar", Type = "Strike", Cooldown = 10, Damage = 15, Range = 40, Fx = "Strike" },
		Passive = { MonsterHoney = 0.5 },
		Visual = { Body = Color3.fromRGB(240, 170, 60), Stripe = Color3.fromRGB(150, 80, 20), Accessory = "Crown", Shape = Vector3.new(1.15, 1.12, 1.1), Extras = { "Mane" }, Aura = "Gold" },
	},

	-- Mythic --------------------------------------------------------------------------
	Solar = {
		Name = "Solar Bee", Rarity = "Mythic", Color = "White", Tags = { "Light", "Royal" },
		Gather = 50, GatherTime = 2.5, Speed = 24, Convert = 600, Attack = 15,
		Description = "Solar Flare harvests a huge area; +10% all pollen.",
		Ability = { Id = "SolarFlare", Name = "Solar Flare", Type = "Burst", Cooldown = 18, Radius = 15, Power = 5, Fx = "Solar" },
		Passive = { PollenMult = 0.1 },
		Visual = { Body = Color3.fromRGB(255, 240, 150), Stripe = Color3.fromRGB(255, 150, 40), Accessory = "Halo", Extras = { "Gem", "Crest" }, Aura = "Gold" },
	},
	Void = {
		Name = "Void Bee", Rarity = "Mythic", Color = "Blue", Tags = { "Shadow", "Royal" },
		Gather = 50, GatherTime = 2.5, Speed = 24, Convert = 600, Attack = 25,
		Description = "Black Hole pulls in pollen and crushes monsters.",
		Ability = { Id = "BlackHole", Name = "Black Hole", Type = "Burst", Cooldown = 18, Radius = 18, Power = 4, Fx = "Void", StrikeMult = 10 },
		Visual = { Body = Color3.fromRGB(40, 20, 70), Stripe = Color3.fromRGB(170, 80, 255), Accessory = "Halo", Shape = Vector3.new(0.95, 1.0, 1.12), Extras = { "Horns", "Mask" }, Aura = "Void" },
	},
	Galaxy = {
		Name = "Galaxy Bee", Rarity = "Mythic", Color = "Blue", Tags = { "Light", "Shadow", "Royal" },
		Gather = 52, GatherTime = 2.4, Speed = 25, Convert = 650, Attack = 20,
		Description = "Star Bloom harvests a huge area; +8% all pollen.",
		Ability = { Id = "StarBloom", Name = "Star Bloom", Type = "Burst", Cooldown = 17, Radius = 16, Power = 5, Fx = "Void" },
		Passive = { PollenMult = 0.08 },
		Visual = { Body = Color3.fromRGB(60, 40, 140), Stripe = Color3.fromRGB(120, 230, 255), Accessory = "Halo", Extras = { "Ring", "Moon" }, Aura = "Stars" },
	},
	Diamond = {
		Name = "Diamond Bee", Rarity = "Mythic", Color = "White", Tags = { "Honey", "Royal" },
		Gather = 45, GatherTime = 2.6, Speed = 23, Convert = 900, Attack = 10,
		Description = "Diamond Touch converts 8% of your bag; +20% honey.",
		Ability = { Id = "DiamondTouch", Name = "Diamond Touch", Type = "InstantConvert", Cooldown = 28, Fraction = 0.08, Fx = "Gold" },
		Passive = { HoneyMult = 0.2 },
		Visual = { Body = Color3.fromRGB(220, 245, 255), Stripe = Color3.fromRGB(120, 200, 255), Accessory = "Halo", Shape = Vector3.new(1.05, 1.05, 1.05), Extras = { "Spikes", "Gem" }, Aura = "Frost" },
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
