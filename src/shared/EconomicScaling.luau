--[[
	EconomicScaling
	One place for every progression curve. Item lists in Config only name things and pick a
	look; prices and stats are generated from the item's tier with the same exponential rules,
	so the ladder can never jump backwards or skip (tier n always costs Growth x tier n-1).

	  Price(tier)  = 0 for the starter, else Round(BasePrice * PriceGrowth ^ (tier - 2))
	  Stat(tier)   = Base * Growth ^ (tier - 1)            (multiplicative stats)
	               = Base + Step * (tier - 1)               (additive stats)
	               = max(Min, Base * Decay ^ (tier - 1))    (stats that shrink, e.g. cooldowns)
	Prices and big stats are rounded to two significant digits so the shop reads cleanly
	(1,440 -> 1,400; 27,210 -> 27,000).
]]

local EconomicScaling = {}

EconomicScaling.Curves = {
	Collectors = {
		BasePrice = 750,
		PriceGrowth = 1.8,
		Stats = {
			Power = { Base = 2, Growth = 1.28, Round = true }, -- pollen per flower hit
			Radius = { Base = 3, Step = 0.7, Round = true }, -- studs
			Cooldown = { Base = 0.8, Decay = 0.96, Min = 0.4 }, -- seconds between swings
		},
	},
	Backpacks = {
		BasePrice = 1000,
		PriceGrowth = 1.8,
		Stats = {
			Capacity = { Base = 200, Growth = 1.62, Round = true }, -- pollen
		},
	},
	Boots = {
		BasePrice = 1200,
		PriceGrowth = 1.8,
		Stats = {
			Speed = { Base = 1, Step = 0.06 }, -- WalkSpeed multiplier
		},
	},
}

-- two significant digits (keeps small numbers exact)
function EconomicScaling.Round(n: number): number
	if n < 100 then
		return math.floor(n + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

function EconomicScaling.Price(curve, tier: number): number
	if tier <= 1 then
		return 0
	end
	return EconomicScaling.Round(curve.BasePrice * curve.PriceGrowth ^ (tier - 2))
end

function EconomicScaling.Stat(rule, tier: number): number
	local value
	if rule.Growth then
		value = rule.Base * rule.Growth ^ (tier - 1)
	elseif rule.Decay then
		value = math.max(rule.Min or 0, rule.Base * rule.Decay ^ (tier - 1))
	else
		value = rule.Base + (rule.Step or 0) * (tier - 1)
	end
	if rule.Round then
		return EconomicScaling.Round(value)
	end
	return math.floor(value * 100 + 0.5) / 100
end

-- Fill Price and every curve stat on a list of item definitions (index = tier)
function EconomicScaling.Build(kind: string, items)
	local curve = EconomicScaling.Curves[kind]
	assert(curve, "unknown curve " .. kind)
	for tier, item in items do
		item.Tier = tier
		item.Price = EconomicScaling.Price(curve, tier)
		for stat, rule in curve.Stats do
			item[stat] = EconomicScaling.Stat(rule, tier)
		end
	end
	return items
end

return EconomicScaling
