--[[
	Synergy
	Evaluates hive-layout combos. Pure function shared by server (authoritative modifiers)
	and client (badges/preview in the hive UI).

	Kinds:
	  Cluster     N+ connected cells whose bees share a tag (flood fill over hex neighbours)
	  Pair        a bee with TagA adjacent to a bee with TagB
	  Surrounded  a bee with Tag whose 6 neighbours are all occupied
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BeeData = require(Shared.BeeData)
local HexGrid = require(Shared.HexGrid)
local Config = require(Shared.Config)

local Synergy = {}

Synergy.Definitions = {
	{
		Id = "Supernova", Name = "Supernova Field Burn", Kind = "Cluster", Tag = "Fire", Min = 3,
		Description = "Every 20s a fire burst (r=14) harvests 2x pollen around you.",
	},
	{
		Id = "Glacier", Name = "Glacier Lattice", Kind = "Cluster", Tag = "Frost", Min = 3,
		Description = "Frost abilities +50% radius; monsters in your field -40% speed.",
	},
	{
		Id = "WorkerUnion", Name = "Worker Union", Kind = "Cluster", Tag = "Worker", Min = 4,
		Description = "+15% gather for Worker bees.",
	},
	{
		Id = "HoneycombCore", Name = "Honeycomb Core", Kind = "Cluster", Tag = "Honey", Min = 2,
		Description = "+25% convert speed.",
	},
	{
		Id = "Battalion", Name = "Battalion", Kind = "Cluster", Tag = "Soldier", Min = 3,
		Description = "+50% attack for Soldier bees.",
	},
	{
		Id = "Eclipse", Name = "Eclipse", Kind = "Pair", TagA = "Light", TagB = "Shadow",
		Description = "Light + Shadow neighbours: -30% cooldown, +50% ability power.",
	},
	{
		Id = "RoyalCourt", Name = "Royal Court", Kind = "Surrounded", Tag = "Royal",
		Description = "A Royal bee with 6 neighbours gets +25% to all stats.",
	},
}

Synergy.ById = {}
for _, def in Synergy.Definitions do
	Synergy.ById[def.Id] = def
end

local function newMods()
	return { Gather = 1, Attack = 1, Cooldown = 1, AbilityPower = 1, All = 1, Radius = 1 }
end

-- Connected groups of slots whose bee has `tag`
local function clusters(beesBySlot, tag: string)
	local radius = Config.Hive.Radius
	local visited = {}
	local groups = {}
	for slot, beeId in beesBySlot do
		if not visited[slot] and BeeData.HasTag(beeId, tag) then
			local group = {}
			local stack = { slot }
			visited[slot] = true
			while #stack > 0 do
				local current = table.remove(stack)
				table.insert(group, current)
				for _, n in HexGrid.Neighbors(radius, current) do
					local other = beesBySlot[n]
					if not visited[n] and other and BeeData.HasTag(other, tag) then
						visited[n] = true
						table.insert(stack, n)
					end
				end
			end
			table.insert(groups, group)
		end
	end
	return groups
end

-- beesBySlot: { [slotNumber] = beeId }
function Synergy.Evaluate(beesBySlot)
	local radius = Config.Hive.Radius
	local result = {
		Active = {},
		BeeMods = {},
		Hive = { ConvertBonus = 0, FrostRadius = 1, MonsterSlow = 0, Supernova = false, SupernovaSlots = {} },
	}
	for slot in beesBySlot do
		result.BeeMods[slot] = newMods()
	end

	local function activate(def, slots)
		table.insert(result.Active, { Id = def.Id, Name = def.Name, Slots = slots })
	end

	for _, def in Synergy.Definitions do
		if def.Kind == "Cluster" then
			for _, group in clusters(beesBySlot, def.Tag) do
				if #group >= def.Min then
					activate(def, group)
					if def.Id == "Supernova" then
						result.Hive.Supernova = true
						for _, s in group do
							table.insert(result.Hive.SupernovaSlots, s)
						end
					elseif def.Id == "Glacier" then
						result.Hive.FrostRadius = 1.5
						result.Hive.MonsterSlow = 0.4
						for _, s in group do
							result.BeeMods[s].Radius = 1.5
						end
					elseif def.Id == "WorkerUnion" then
						for _, s in group do
							result.BeeMods[s].Gather *= 1.15
						end
					elseif def.Id == "HoneycombCore" then
						result.Hive.ConvertBonus += 0.25
					elseif def.Id == "Battalion" then
						for _, s in group do
							result.BeeMods[s].Attack *= 1.5
						end
					end
				end
			end
		elseif def.Kind == "Pair" then
			local paired = {}
			for slot, beeId in beesBySlot do
				if BeeData.HasTag(beeId, def.TagA) then
					for _, n in HexGrid.Neighbors(radius, slot) do
						local other = beesBySlot[n]
						if other and BeeData.HasTag(other, def.TagB) then
							paired[slot] = true
							paired[n] = true
						end
					end
				end
			end
			local slots = {}
			for s in paired do
				table.insert(slots, s)
				result.BeeMods[s].Cooldown *= 0.7
				result.BeeMods[s].AbilityPower *= 1.5
			end
			if #slots > 0 then
				activate(def, slots)
			end
		elseif def.Kind == "Surrounded" then
			for slot, beeId in beesBySlot do
				if BeeData.HasTag(beeId, def.Tag) then
					local around = HexGrid.Neighbors(radius, slot)
					local full = #around == 6
					for _, n in around do
						if not beesBySlot[n] then
							full = false
							break
						end
					end
					if full then
						result.BeeMods[slot].All *= 1.25
						activate(def, { slot })
					end
				end
			end
		end
	end

	return result
end

return Synergy
