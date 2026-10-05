--[[
	Config
	Every tunable number in the game lives here so balance changes never touch logic.
	Shared by server and client (the client reads prices, odds and stats for the UI).
]]

local Config = {}

Config.GameName = "Bee Tycoon: Honey Empire"
Config.DataVersion = 1

-- Rarities ------------------------------------------------------------------

Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(190, 190, 190), Points = 1 },
	Rare = { Order = 2, Color = Color3.fromRGB(74, 163, 255), Points = 3 },
	Epic = { Order = 3, Color = Color3.fromRGB(180, 96, 255), Points = 10 },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 194, 58), Points = 40 },
	Mythic = { Order = 5, Color = Color3.fromRGB(255, 79, 139), Points = 150 },
}

-- Flowers & fields ----------------------------------------------------------

Config.FlowerColors = {
	White = Color3.fromRGB(250, 248, 240),
	Red = Color3.fromRGB(232, 62, 74),
	Blue = Color3.fromRGB(72, 132, 240),
}

Config.ColorMatchBonus = 1.5 -- bee colour == flower colour

Config.Tiles = {
	Size = 4, -- studs per flower tile
	Depletion = 0.2, -- level lost per collector hit
	BeeDepletion = 0.1, -- level lost per bee gather / ability tile
	Regen = 0.04, -- level regained per second
}

Config.Fields = {
	{
		Id = "Sunflower",
		Name = "Sunflower Meadow",
		BeesRequired = 0,
		Multiplier = 1,
		Flowers = { "White" },
		Center = Vector3.new(0, 0, 120),
		Tiles = 16,
		Ground = Color3.fromRGB(124, 186, 82),
	},
	{
		Id = "Clover",
		Name = "Clover Hill",
		BeesRequired = 5,
		Multiplier = 1.5,
		Flowers = { "White", "Blue", "Red" },
		Center = Vector3.new(-150, 14, 140),
		Tiles = 16,
		Ground = Color3.fromRGB(98, 170, 92),
	},
	{
		Id = "Rose",
		Name = "Rose Garden",
		BeesRequired = 10,
		Multiplier = 2.5,
		Flowers = { "Red" },
		Center = Vector3.new(150, 14, 140),
		Tiles = 16,
		Ground = Color3.fromRGB(136, 160, 74),
	},
	{
		Id = "Bluebell",
		Name = "Bluebell Grove",
		BeesRequired = 15,
		Multiplier = 4,
		Flowers = { "Blue" },
		Center = Vector3.new(-150, 30, 300),
		Tiles = 16,
		Ground = Color3.fromRGB(82, 150, 110),
	},
	{
		Id = "Crystal",
		Name = "Crystal Peak",
		BeesRequired = 25,
		Multiplier = 8,
		Flowers = { "White", "Blue", "Red" },
		Center = Vector3.new(150, 40, 310),
		Tiles = 16,
		Ground = Color3.fromRGB(120, 150, 170),
	},
	{
		Id = "Royal",
		Name = "Royal Orchard",
		BeesRequired = 0,
		Multiplier = 6,
		Flowers = { "White" },
		Center = Vector3.new(0, 22, 300),
		Tiles = 12,
		Ground = Color3.fromRGB(170, 150, 80),
		VIP = true,
	},
}

-- Tools ----------------------------------------------------------------------

Config.Collectors = {
	{ Id = "Scoop", Name = "Scoop", Price = 0, Power = 2, Radius = 3, Cooldown = 0.8, Shape = "Scoop", Color = Color3.fromRGB(205, 165, 95) },
	{ Id = "Rake", Name = "Rake", Price = 800, Power = 3, Radius = 5, Cooldown = 0.75, Shape = "Rake", Color = Color3.fromRGB(150, 110, 70) },
	{ Id = "Clippers", Name = "Clippers", Price = 5000, Power = 5, Radius = 6, Cooldown = 0.65, Shape = "Rake", Color = Color3.fromRGB(120, 200, 120) },
	{ Id = "Vacuum", Name = "Vacuum", Price = 25000, Power = 7, Radius = 8, Cooldown = 0.6, Shape = "Vacuum", Color = Color3.fromRGB(90, 160, 230) },
	{ Id = "HoneyWand", Name = "Honey Wand", Price = 150000, Power = 12, Radius = 9, Cooldown = 0.55, Shape = "Wand", Color = Color3.fromRGB(255, 190, 40) },
	{ Id = "StormHarvester", Name = "Storm Harvester", Price = 1000000, Power = 20, Radius = 11, Cooldown = 0.5, Shape = "Vacuum", Color = Color3.fromRGB(130, 90, 230) },
	{ Id = "GoldenReaper", Name = "Golden Reaper", Price = 10000000, Power = 35, Radius = 13, Cooldown = 0.45, Shape = "Wand", Color = Color3.fromRGB(255, 215, 80) },
}

Config.Backpacks = {
	{ Id = "Pouch", Name = "Pouch", Price = 0, Capacity = 200, Shape = "Pouch", Color = Color3.fromRGB(196, 150, 100) },
	{ Id = "Jar", Name = "Jar", Price = 1000, Capacity = 750, Shape = "Canister", Color = Color3.fromRGB(200, 230, 255) },
	{ Id = "Canister", Name = "Canister", Price = 7500, Capacity = 2500, Shape = "Canister", Color = Color3.fromRGB(150, 190, 120) },
	{ Id = "Satchel", Name = "Satchel", Price = 40000, Capacity = 8000, Shape = "Pouch", Color = Color3.fromRGB(120, 90, 160) },
	{ Id = "HivePack", Name = "Hive Pack", Price = 250000, Capacity = 25000, Shape = "Tank", Color = Color3.fromRGB(255, 190, 40) },
	{ Id = "PorcelainTank", Name = "Porcelain Tank", Price = 1500000, Capacity = 80000, Shape = "Tank", Color = Color3.fromRGB(235, 240, 250) },
	{ Id = "RoyalReservoir", Name = "Royal Reservoir", Price = 12000000, Capacity = 300000, Shape = "Tank", Color = Color3.fromRGB(255, 120, 170) },
}

-- Conversion -------------------------------------------------------------------

Config.Convert = {
	BasePerSecond = 25, -- pollen/s the player converts alone
	CapacityFraction = 0.01, -- + this share of backpack capacity per second
	Range = 25, -- studs from the hive pad
	HoneyPerPollen = 1,
	AutoConvertThreshold = 0.95, -- Auto-Convert Companion kicks in at 95% full
	AutoConvertFraction = 0.03, -- converts 3% of capacity per second
}

-- Hive -------------------------------------------------------------------------

Config.Hive = {
	Radius = 3, -- hex radius 3 = 37 cells
	StartSlots = 12,
	MaxHoneySlots = 35,
	GamepassSlots = 2,
	SlotBasePrice = 2000,
	SlotGrowth = 1.6,
	CellSize = 2.0, -- hex "size" (centre to corner) in studs
	Count = 8,
}

-- Bee progression ----------------------------------------------------------------

Config.Levels = {
	Max = 20,
	StatPerLevel = 0.08,
	SpeedPerLevel = 0.02,
	XPBase = 40,
	XPExponent = 1.6,
	TreatXP = 25,
	TreatPrice = 200,
	GatherXP = 1,
}

Config.Mutations = {
	Gifted = { Order = 1, Chance = 0.04, SerumWeight = 60, ScoreMult = 1.5, All = 1.25, Color = Color3.fromRGB(255, 215, 90) },
	Neon = { Order = 2, Chance = 0.015, SerumWeight = 30, ScoreMult = 2, Gather = 1.4, Color = Color3.fromRGB(90, 255, 220) },
	Shadow = { Order = 3, Chance = 0.005, SerumWeight = 10, ScoreMult = 3, Ability = 1.6, Color = Color3.fromRGB(150, 70, 255) },
}
Config.MutationOrder = { "Gifted", "Neon", "Shadow" }
Config.SerumHoneyPrice = 250000

-- Eggs -------------------------------------------------------------------------------

Config.EggOrder = { "Basic", "Silver", "Royal" }

Config.Eggs = {
	Basic = {
		Name = "Basic Egg",
		BasePrice = 500,
		Growth = 1.35, -- price = BasePrice * Growth ^ beesOwned
		Odds = { Common = 75, Rare = 20, Epic = 4.5, Legendary = 0.5, Mythic = 0 },
		Pity = 80,
		Color = Color3.fromRGB(245, 235, 210),
	},
	Silver = {
		Name = "Silver Egg",
		HoneyPrice = 50000,
		Odds = { Common = 40, Rare = 40, Epic = 16, Legendary = 3.6, Mythic = 0.4 },
		Pity = 40,
		Color = Color3.fromRGB(200, 210, 225),
	},
	Royal = {
		Name = "Royal Egg",
		HoneyPrice = 5000000,
		Odds = { Common = 0, Rare = 40, Epic = 40, Legendary = 17, Mythic = 3 },
		Pity = 15,
		Product = "RoyalEgg",
		Color = Color3.fromRGB(255, 205, 80),
	},
}
Config.SoftPityStart = 0.75 -- soft pity starts at 75% of the hard pity

-- Monsters ---------------------------------------------------------------------------

Config.Monsters = {
	Aphid = { Name = "Aphid", Health = 20, Speed = 6, Drain = 5, DrainRange = 8, Honey = 60, Size = 2.2 },
	Ladybug = { Name = "Ladybug", Health = 80, Speed = 8, Drain = 12, DrainRange = 9, Honey = 300, Size = 3.2 },
	AphidQueen = { Name = "Aphid Queen", Health = 2500, Speed = 4, Drain = 40, DrainRange = 14, Honey = 12000, Size = 7, Boss = true },
}

Config.MonsterSpawns = {
	Interval = 25, -- seconds between spawn attempts per field
	MaxPerField = 3,
	Fields = {
		Sunflower = { "Aphid" },
		Clover = { "Aphid", "Ladybug" },
		Rose = { "Ladybug" },
		Bluebell = { "Ladybug", "Aphid" },
		Crystal = { "Ladybug" },
	},
}

-- Global events ------------------------------------------------------------------------

Config.Events = {
	Interval = 900, -- one event every 15 minutes, aligned to the clock
	StudioInterval = 180, -- faster cycle while testing in Studio
	Warning = 60,
	Duration = 180,
	Multiplier = 5,
	ParticipationTime = 30,
	FieldPool = { "Sunflower", "Clover", "Rose", "Bluebell" },
	Types = { "MeteorShower", "AphidInvasion", "GoldenBloom", "HoneyRain" },
	AphidGoal = 150,
	MeteorEvery = 2,
	MeteorRadius = 10,
	TokenEvery = 1,
	GoldenRegenMult = 3,
}

Config.EventInfo = {
	MeteorShower = { Name = "Sunflower Meteor Shower", Color = Color3.fromRGB(255, 140, 50) },
	AphidInvasion = { Name = "Aphid Invasion", Color = Color3.fromRGB(110, 210, 80) },
	GoldenBloom = { Name = "Golden Bloom", Color = Color3.fromRGB(255, 205, 60) },
	HoneyRain = { Name = "Honey Rain", Color = Color3.fromRGB(255, 170, 30) },
}

-- World: nests, codes, tutorial -----------------------------------------------------------

-- Physical egg nests on the plaza between spawn and the hives
Config.Nests = {
	{ Egg = "Basic", Position = Vector3.new(-34, 0, -44) },
	{ Egg = "Silver", Position = Vector3.new(0, 0, -50) },
	{ Egg = "Royal", Position = Vector3.new(34, 0, -44) },
}
Config.NestRange = 22

-- Promo codes (case-insensitive), each redeemable once per player
Config.Codes = {
	BEES = { Honey = 2500 },
	HONEY = { Treats = 15 },
	BUZZ = { Eggs = { Basic = 2 } },
	LAUNCH = { Eggs = { Silver = 1 } },
}

Config.Tutorial = {
	{ Id = "Field", Text = "Fly to Sunflower Meadow" },
	{ Id = "Collect", Text = "Hold click to collect pollen" },
	{ Id = "Convert", Text = "Return to your hive and make honey" },
	{ Id = "Hatch", Text = "Hatch an egg at the Golden Nest" },
}

-- Daily login streak ---------------------------------------------------------------------

Config.DailyRewards = {
	{ Honey = 500 },
	{ Treats = 5 },
	{ Honey = 2500 },
	{ Eggs = { Basic = 1 } },
	{ Honey = 10000 },
	{ Treats = 20 },
	{ Eggs = { Silver = 1 } },
}

-- Monetization (set real IDs after creating products on the Creator Dashboard) -------------

Config.Products = {
	InstantConvert = { Id = 0, Robux = 25, Name = "Instant Convert", Description = "Turn your whole backpack into honey now." },
	FieldBooster = { Id = 0, Robux = 49, Name = "Field Booster", Description = "2x pollen in your current field for 10 min.", Duration = 600, Multiplier = 2 },
	HoneyPackS = { Id = 0, Robux = 99, Name = "Honey Pack S", Description = "Honey that scales with your backpack." },
	HoneyPackL = { Id = 0, Robux = 399, Name = "Honey Pack L", Description = "5.5x the small honey pack." },
	RoyalEgg = { Id = 0, Robux = 149, Name = "Royal Egg", Description = "One Royal Egg (odds shown in the Egg shop).", RandomItem = true },
	MutationSerum = { Id = 0, Robux = 99, Name = "Mutation Serum", Description = "Guaranteed mutation, never a downgrade." },
}
Config.ProductOrder = { "InstantConvert", "FieldBooster", "HoneyPackS", "HoneyPackL", "RoyalEgg", "MutationSerum" }

Config.Gamepasses = {
	ExtraSlots = { Id = 0, Robux = 199, Name = "+2 Hive Slots", Description = "Unlocks hive cells 36 and 37." },
	VIPField = { Id = 0, Robux = 299, Name = "VIP Field Access", Description = "Enter the Royal Orchard (6x) + VIP tag." },
	AutoConvert = { Id = 0, Robux = 399, Name = "Auto-Convert Companion", Description = "Converts pollen remotely when your bag is full." },
}
Config.GamepassOrder = { "ExtraSlots", "VIPField", "AutoConvert" }

-- In Studio, products with Id = 0 are granted instantly so every flow can be tested.
Config.StudioFreePurchases = true

-- Lookups ---------------------------------------------------------------------------------

local function index(list)
	local map = {}
	for i, item in list do
		item.Index = i
		map[item.Id] = item
	end
	return map
end

Config.FieldById = index(Config.Fields)
Config.CollectorById = index(Config.Collectors)
Config.BackpackById = index(Config.Backpacks)

return Config
