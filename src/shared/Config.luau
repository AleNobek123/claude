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
		Center = Vector3.new(0, 0, 150),
		Tiles = 25,
		Ground = Color3.fromRGB(124, 186, 82),
	},
	{
		Id = "Clover",
		Name = "Clover Hill",
		BeesRequired = 5,
		Multiplier = 1.5,
		Flowers = { "White", "Blue", "Red" },
		Center = Vector3.new(-200, 14, 170),
		Tiles = 25,
		Ground = Color3.fromRGB(98, 170, 92),
	},
	{
		Id = "Rose",
		Name = "Rose Garden",
		BeesRequired = 10,
		Multiplier = 2.5,
		Flowers = { "Red" },
		Center = Vector3.new(205, 14, 180),
		Tiles = 25,
		Ground = Color3.fromRGB(136, 160, 74),
	},
	{
		Id = "Bluebell",
		Name = "Bluebell Grove",
		BeesRequired = 15,
		Multiplier = 4,
		Flowers = { "Blue" },
		Center = Vector3.new(-220, 30, 390),
		Tiles = 25,
		Ground = Color3.fromRGB(82, 150, 110),
	},
	{
		Id = "Pumpkin",
		Name = "Pumpkin Patch",
		BeesRequired = 18,
		Multiplier = 5,
		Flowers = { "White", "Red" },
		Center = Vector3.new(-370, 22, 200),
		Tiles = 22,
		Ground = Color3.fromRGB(150, 150, 72),
	},
	{
		Id = "Cactus",
		Name = "Cactus Canyon",
		BeesRequired = 22,
		Multiplier = 6.5,
		Flowers = { "Red", "Blue" },
		Center = Vector3.new(375, 24, 200),
		Tiles = 22,
		Ground = Color3.fromRGB(196, 170, 104),
	},
	{
		Id = "Crystal",
		Name = "Crystal Peak",
		BeesRequired = 25,
		Multiplier = 8,
		Flowers = { "White", "Blue", "Red" },
		Center = Vector3.new(210, 42, 410),
		Tiles = 25,
		Ground = Color3.fromRGB(120, 150, 170),
	},
	{
		Id = "Mushroom",
		Name = "Mushroom Hollow",
		BeesRequired = 29,
		Multiplier = 10,
		Flowers = { "Blue", "Red", "White" },
		Center = Vector3.new(-240, 52, 600),
		Tiles = 22,
		Ground = Color3.fromRGB(92, 128, 96),
	},
	{
		Id = "Pine",
		Name = "Pine Summit",
		BeesRequired = 33,
		Multiplier = 13,
		Flowers = { "White", "Blue" },
		Center = Vector3.new(230, 68, 620),
		Tiles = 22,
		Ground = Color3.fromRGB(86, 140, 100),
	},
	{
		Id = "Royal",
		Name = "Royal Orchard",
		BeesRequired = 0,
		Multiplier = 6,
		Flowers = { "White" },
		Center = Vector3.new(0, 22, 405),
		Tiles = 19,
		Ground = Color3.fromRGB(170, 150, 80),
		VIP = true,
	},
}

-- Equipment ---------------------------------------------------------------------------
-- Lists only name things and pick a look; EconomicScaling fills Price and stats from the tier
-- (index), so every step costs exactly PriceGrowth x the previous one.
-- Model/Variant: reuse another item's mesh with a new colour and material (premium reskins).

local EconomicScaling = require(script.Parent.EconomicScaling)
Config.Economy = EconomicScaling

Config.Collectors = EconomicScaling.Build("Collectors", {
	{ Id = "Scoop", Name = "Scoop", Shape = "Scoop", Color = Color3.fromRGB(205, 165, 95) },
	{ Id = "Rake", Name = "Rake", Shape = "Rake", Color = Color3.fromRGB(150, 110, 70) },
	{ Id = "Clippers", Name = "Clippers", Shape = "Rake", Color = Color3.fromRGB(120, 200, 120) },
	{ Id = "Vacuum", Name = "Vacuum", Shape = "Vacuum", Color = Color3.fromRGB(90, 160, 230) },
	{ Id = "HoneyWand", Name = "Honey Wand", Shape = "Wand", Color = Color3.fromRGB(255, 190, 40) },
	{ Id = "StormHarvester", Name = "Storm Harvester", Shape = "Vacuum", Color = Color3.fromRGB(130, 90, 230) },
	{ Id = "GoldenReaper", Name = "Golden Reaper", Shape = "Wand", Color = Color3.fromRGB(255, 215, 80) },
	{ Id = "CrystalScoop", Name = "Crystal Scoop", Shape = "Scoop", Model = "Scoop", Variant = { Color = Color3.fromRGB(130, 230, 255), Material = Enum.Material.Glass } },
	{ Id = "EmberRake", Name = "Ember Rake", Shape = "Rake", Model = "Rake", Variant = { Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon } },
	{ Id = "FrostClippers", Name = "Frost Clippers", Shape = "Rake", Model = "Clippers", Variant = { Color = Color3.fromRGB(190, 235, 255), Material = Enum.Material.Ice } },
	{ Id = "NebulaVacuum", Name = "Nebula Vacuum", Shape = "Vacuum", Model = "Vacuum", Variant = { Color = Color3.fromRGB(150, 70, 255), Material = Enum.Material.Neon } },
	{ Id = "DiamondWand", Name = "Diamond Wand", Shape = "Wand", Model = "HoneyWand", Variant = { Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.Glass } },
	{ Id = "ThunderHarvester", Name = "Thunder Harvester", Shape = "Vacuum", Model = "StormHarvester", Variant = { Color = Color3.fromRGB(255, 240, 80), Material = Enum.Material.Neon } },
	{ Id = "RoyalReaper", Name = "Royal Reaper", Shape = "Wand", Model = "GoldenReaper", Variant = { Color = Color3.fromRGB(255, 150, 210), Material = Enum.Material.Foil } },
})

-- Backpacks are procedural (Shared.GearModels): Style = silhouette, Color/Accent/Material = look
Config.Backpacks = EconomicScaling.Build("Backpacks", {
	{ Id = "Pouch", Name = "Pouch", Shape = "Pouch", Color = Color3.fromRGB(196, 150, 100) },
	{ Id = "Jar", Name = "Honey Jar", Shape = "Canister", Color = Color3.fromRGB(200, 230, 255) },
	{ Id = "Canister", Name = "Canister", Shape = "Canister", Color = Color3.fromRGB(150, 190, 120) },
	{ Id = "Satchel", Name = "Satchel", Shape = "Pouch", Color = Color3.fromRGB(120, 90, 160) },
	{ Id = "HivePack", Name = "Hive Pack", Shape = "Tank", Color = Color3.fromRGB(255, 190, 40) },
	{ Id = "PorcelainTank", Name = "Porcelain Tank", Shape = "Tank", Color = Color3.fromRGB(235, 240, 250) },
	{ Id = "RoyalReservoir", Name = "Royal Reservoir", Shape = "Tank", Color = Color3.fromRGB(255, 120, 170) },
	{ Id = "CrystalJar", Name = "Crystal Jar", Shape = "Canister" }, -- own template (tools/IntegrateV6)
	{ Id = "LavaCanister", Name = "Lava Canister", Shape = "Canister", Model = "Canister", Variant = { Color = Color3.fromRGB(255, 90, 20), Material = Enum.Material.Neon } },
	{ Id = "ShadowSatchel", Name = "Shadow Satchel", Shape = "Pouch", Model = "Satchel", Variant = { Color = Color3.fromRGB(70, 40, 110), Material = Enum.Material.Glass } },
	{ Id = "FrostHive", Name = "Frost Hive Pack", Shape = "Tank" }, -- own template (tools/IntegrateV6)
	{ Id = "GoldenTank", Name = "Golden Tank", Shape = "Tank" }, -- own template (tools/IntegrateV6)
	{ Id = "GalaxyReservoir", Name = "Galaxy Reservoir", Shape = "Tank", Model = "RoyalReservoir", Variant = { Color = Color3.fromRGB(140, 60, 255), Material = Enum.Material.Neon } },
	{ Id = "InfinityPack", Name = "Infinity Pack", Shape = "Pouch", Model = "Pouch", Variant = { Color = Color3.fromRGB(255, 240, 140), Material = Enum.Material.Neon } },
})

-- Boots: walk-speed multiplier (Humanoid.WalkSpeed = BaseWalkSpeed * Speed)
Config.BaseWalkSpeed = 16
Config.Boots = EconomicScaling.Build("Boots", {
	{ Id = "FlipFlops", Style = "FlipFlop", Name = "Flip-Flops", Color = Color3.fromRGB(110, 190, 255) },
	{ Id = "Sneakers", Style = "Sneaker", Name = "Sneakers", Color = Color3.fromRGB(240, 240, 245), Accent = Color3.fromRGB(255, 80, 80) },
	{ Id = "HikingBoots", Style = "Hiking", Name = "Hiking Boots", Color = Color3.fromRGB(140, 96, 56), Accent = Color3.fromRGB(230, 200, 120) },
	{ Id = "RainBoots", Style = "Rain", Name = "Rain Boots", Color = Color3.fromRGB(255, 210, 40), Accent = Color3.fromRGB(60, 60, 70) },
	{ Id = "SpeedySneakers", Style = "Speedy", Name = "Speedy Sneakers", Color = Color3.fromRGB(80, 220, 120), Accent = Color3.fromRGB(255, 255, 255) },
	{ Id = "HoneyBoots", Style = "Honey", Name = "Honey Boots", Color = Color3.fromRGB(255, 170, 30), Accent = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Glass },
	{ Id = "CloudBoots", Style = "Cloud", Name = "Cloud Boots", Color = Color3.fromRGB(245, 250, 255), Accent = Color3.fromRGB(160, 210, 255), Trail = true },
	{ Id = "RocketBoots", Style = "Rocket", Name = "Rocket Boots", Color = Color3.fromRGB(230, 60, 60), Accent = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Trail = true },
	{ Id = "LightningBoots", Style = "Lightning", Name = "Lightning Boots", Color = Color3.fromRGB(80, 120, 255), Accent = Color3.fromRGB(255, 255, 120), Material = Enum.Material.Neon, Trail = true },
	{ Id = "RoyalBoots", Style = "Royal", Name = "Royal Wing Boots", Color = Color3.fromRGB(255, 215, 80), Accent = Color3.fromRGB(255, 120, 200), Material = Enum.Material.Foil, Trail = true },
})

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
	Mantis = { Name = "Mantis", Health = 220, Speed = 10, Drain = 20, DrainRange = 10, Honey = 900, Size = 3.6, Model = "Aphid", Tint = Color3.fromRGB(110, 220, 90), Scale = 1.7 },
	Scorpion = { Name = "Scorpion", Health = 600, Speed = 11, Drain = 30, DrainRange = 11, Honey = 2600, Size = 4, Model = "Ladybug", Tint = Color3.fromRGB(205, 130, 60), Scale = 1.6 },
	CaveSpider = { Name = "Cave Spider", Health = 1400, Speed = 12, Drain = 45, DrainRange = 12, Honey = 6000, Size = 4.4, Model = "Aphid", Tint = Color3.fromRGB(80, 50, 110), Scale = 2.2 },
	Hornet = { Name = "Hornet", Health = 2600, Speed = 14, Drain = 65, DrainRange = 13, Honey = 11000, Size = 4.6, Model = "Aphid", Tint = Color3.fromRGB(250, 190, 40), Scale = 2 },
	-- world bosses (see Config.Bosses): huge health pools fought by everyone in the field
	KingBeetle = { Name = "King Beetle", Health = 12000, Speed = 5, Drain = 60, DrainRange = 16, Honey = 60000, Size = 9, Boss = true, Model = "Ladybug", Tint = Color3.fromRGB(70, 50, 140), Scale = 3, EggReward = "Silver" },
	StumpSnail = { Name = "Stump Snail", Health = 30000, Speed = 2, Drain = 80, DrainRange = 18, Honey = 150000, Size = 10, Boss = true, Model = "AphidQueen", Tint = Color3.fromRGB(150, 110, 70), Scale = 1.5, EggReward = "Royal" },
}

-- Epic boss encounters: one world boss at a time, announced to everyone
Config.Bosses = {
	Interval = 1200, -- seconds between bosses
	StudioInterval = 480,
	Lifetime = 300, -- escapes if not defeated in time
	Types = { "KingBeetle", "StumpSnail" },
	Fields = { "Clover", "Rose", "Bluebell", "Pumpkin", "Cactus", "Crystal" },
}

Config.MonsterSpawns = {
	Interval = 25, -- seconds between spawn attempts per field
	MaxPerField = 3,
	Fields = {
		Sunflower = { "Aphid" },
		Clover = { "Aphid", "Ladybug" },
		Rose = { "Ladybug" },
		Bluebell = { "Ladybug", "Aphid", "Mantis" },
		Crystal = { "Ladybug", "Mantis" },
		Pumpkin = { "Ladybug", "Mantis" },
		Cactus = { "Mantis", "Scorpion" },
		Mushroom = { "Scorpion", "CaveSpider" },
		Pine = { "CaveSpider", "Hornet" },
	},
}

-- Global events ------------------------------------------------------------------------

Config.Events = {
	Interval = 1800, -- one event every 30 minutes, aligned to the clock
	StudioInterval = 600, -- faster cycle while testing in Studio
	Warning = 60,
	Duration = 180,
	Multiplier = 5,
	ParticipationTime = 30,
	FieldPool = { "Sunflower", "Clover", "Rose", "Bluebell", "Pumpkin", "Cactus" },
	Types = { "MeteorShower", "AphidInvasion", "GoldenBloom", "HoneyRain" },
	AphidGoal = 150,
	MeteorEvery = 2,
	MeteorRadius = 10,
	TokenEvery = 1,
	GoldenRegenMult = 3,
}

Config.EventInfo = {
	MeteorShower = { Name = "Meteor Shower", Color = Color3.fromRGB(255, 140, 50) },
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

-- Objectives are picked live from the player's state (see Tutorial controller); the saved step
-- only records milestones: 3 = first honey made, 5 = first egg hatched (tutorial done).
Config.Tutorial = {
	{ Id = "Field", Text = "Follow the arrows to Sunflower Meadow" },
	{ Id = "Collect", Text = "Hold click to collect pollen" },
	{ Id = "Convert", Text = "Backpack full! Make honey at your hive" },
	{ Id = "Hatch", Text = "Hatch an egg at the Golden Nest" },
}

-- Rewards hub (everything is claimed by hand in the Rewards panel) ----------------------------

Config.Rewards = {
	-- 7-day login grid; missing a day restarts at day 1
	Daily = {
		{ Honey = 500 },
		{ Treats = 5 },
		{ Honey = 2500 },
		{ Eggs = { Basic = 1 } },
		{ Honey = 10000 },
		{ Treats = 20 },
		{ Eggs = { Silver = 1 } },
	},
	-- minutes played today (resets daily), up to 2 hours
	Playtime = {
		{ Minutes = 5, Reward = { Honey = 400 } },
		{ Minutes = 10, Reward = { Treats = 3 } },
		{ Minutes = 15, Reward = { Honey = 1200 } },
		{ Minutes = 30, Reward = { Eggs = { Basic = 1 } } },
		{ Minutes = 45, Reward = { Honey = 4000 } },
		{ Minutes = 60, Reward = { Treats = 15 } },
		{ Minutes = 90, Reward = { Honey = 12000 } },
		{ Minutes = 120, Reward = { Eggs = { Silver = 1 } } },
	},
	-- social providers: "Group" checks membership (set GroupId), "Honor" trusts the player after Wait seconds
	GroupId = 0,
	Social = {
		{ Id = "Like", Name = "Like the game", Icon = "Star", Provider = "Honor", Wait = 20, Reward = { Honey = 2000 } },
		{ Id = "Group", Name = "Join our group", Icon = "Bee", Provider = "Group", Reward = { Honey = 5000, Treats = 10 } },
		{ Id = "Follow", Name = "Follow the creator", Icon = "Gift", Provider = "Honor", Wait = 20, Reward = { Honey = 2000 } },
	},
}

-- Honey and treat rewards grow with lifetime honey so late players still care about them
function Config.RewardScale(totalHoney: number?): number
	return math.clamp(math.sqrt((totalHoney or 0) / 20000), 1, 500)
end

function Config.ScaleReward(reward, totalHoney: number?)
	local scale = Config.RewardScale(totalHoney)
	local out = {}
	if reward.Honey then
		out.Honey = Config.Economy.Round(reward.Honey * scale)
	end
	if reward.Treats then
		out.Treats = math.floor(reward.Treats * math.sqrt(scale) + 0.5)
	end
	out.Eggs = reward.Eggs
	return out
end

Config.DailyRewards = Config.Rewards.Daily -- legacy name

Config.Feedback = {
	MinLength = 10,
	MaxLength = 500,
	Cooldown = 60, -- seconds between submissions per player
	Webhook = "", -- optional HTTPS endpoint that receives each report as JSON
}

-- Monetization (set real IDs after creating products on the Creator Dashboard) -------------

Config.Products = {
	InstantConvert = { Id = 0, Robux = 25, Tag = "INSTANT!",  Name = "Instant Convert", Description = "Turn your whole backpack into honey now." },
	FieldBooster = { Id = 0, Robux = 49, Name = "Field Booster", Description = "2x pollen in your current field for 10 min.", Duration = 600, Multiplier = 2 },
	HoneyPackS = { Id = 0, Robux = 99, Name = "Honey Pack S", Description = "Honey that scales with your backpack." },
	HoneyPackL = { Id = 0, Robux = 399, Tag = "BEST VALUE!",  Name = "Honey Pack L", Description = "5.5x the small honey pack." },
	RoyalEgg = { Id = 0, Robux = 149, Tag = "LEGENDARY ODDS",  Name = "Royal Egg", Description = "One Royal Egg (odds shown in the Egg shop).", RandomItem = true },
	MutationSerum = { Id = 0, Robux = 99, Name = "Mutation Serum", Description = "Guaranteed mutation, never a downgrade.", RandomItem = true },
}
Config.ProductOrder = { "InstantConvert", "FieldBooster", "HoneyPackS", "HoneyPackL", "RoyalEgg", "MutationSerum" }

Config.Gamepasses = {
	ExtraSlots = { Id = 0, Robux = 199, Tag = "+2 BEES",  Name = "+2 Hive Slots", Description = "Unlocks hive cells 36 and 37." },
	VIPField = { Id = 0, Robux = 299, Tag = "POPULAR",  Name = "VIP Field Access", Description = "Enter the Royal Orchard (6x) + VIP tag." },
	AutoConvert = { Id = 0, Robux = 399, Tag = "MUST HAVE",  Name = "Auto-Convert Companion", Description = "Converts pollen remotely when your bag is full." },
}
Config.GamepassOrder = { "ExtraSlots", "VIPField", "AutoConvert" }

-- Honey multiplier ladder ("x2 Honey Forever"): every purchase doubles honey again, up to x1024.
-- Each step is a developer product (create one per price on the Creator Dashboard); steps with
-- the same price may share one product.
Config.HoneyLadder = {
	Name = "Honey Forever",
	Base = 2, -- multiplier = Base ^ tier
	-- price triples every step (x2 = 3, x4 = 9, x8 = 27 ...) up to 1999; the ladder ends at x1024
	-- (tier 10). The 1999 steps may share one developer product.
	Steps = {
		{ Id = 0, Robux = 3 },
		{ Id = 0, Robux = 9 },
		{ Id = 0, Robux = 27 },
		{ Id = 0, Robux = 81 },
		{ Id = 0, Robux = 243 },
		{ Id = 0, Robux = 729 },
		{ Id = 0, Robux = 1999 },
		{ Id = 0, Robux = 1999 },
		{ Id = 0, Robux = 1999 },
		{ Id = 0, Robux = 1999 },
	},
}
Config.HoneyLadder.MaxTier = #Config.HoneyLadder.Steps

function Config.HoneyMultiplier(tier: number?): number
	return Config.HoneyLadder.Base ^ math.min(tier or 0, Config.HoneyLadder.MaxTier)
end

-- The product that buys the next tier for a player currently at `tier` (nil once maxed)
function Config.HoneyLadderStep(tier: number?)
	return Config.HoneyLadder.Steps[(tier or 0) + 1]
end

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
Config.BootsById = index(Config.Boots)

return Config
