--[[
	EggService
	Buying and hatching eggs (gacha with published odds + pity), feeding treats and
	using Mutation Serums.

	Pity: each egg type counts hatches since the last Legendary+. From 75% of the hard
	threshold the Legendary+ chance rises linearly to 100% at the threshold.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local BeeClass = require(Shared.BeeClass)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local EggService = {}
EggService.Name = "EggService"

local S
local rng = Random.new()

-- Prices ---------------------------------------------------------------------------------

function EggService:Price(eggId: string, data): number?
	local egg = Config.Eggs[eggId]
	if not egg then
		return nil
	end
	if egg.BasePrice then
		local bees = S.HiveService:CountBees(data)
		return math.floor(egg.BasePrice * egg.Growth ^ bees)
	end
	return egg.HoneyPrice
end

-- Rolls ------------------------------------------------------------------------------------

local function weightedPick(weights: { [string]: number }, order: { string }): string
	local total = 0
	for _, key in order do
		total += weights[key] or 0
	end
	local roll = rng:NextNumber() * total
	for _, key in order do
		roll -= weights[key] or 0
		if roll <= 0 and (weights[key] or 0) > 0 then
			return key
		end
	end
	for i = #order, 1, -1 do
		if (weights[order[i]] or 0) > 0 then
			return order[i]
		end
	end
	return order[1]
end

-- Returns rarity and whether pity forced it. `count` = hatches since last Legendary+, including this one.
function EggService:RollRarity(eggId: string, count: number): (string, boolean)
	local egg = Config.Eggs[eggId]
	local odds = egg.Odds
	local high = (odds.Legendary + odds.Mythic) / 100
	local hard = egg.Pity
	local softStart = math.floor(hard * Config.SoftPityStart)

	local forced = false
	if count >= hard then
		forced = true
	elseif count > softStart then
		local boosted = high + (1 - high) * (count - softStart) / (hard - softStart)
		forced = rng:NextNumber() < boosted
	end

	if forced then
		local weights = { Legendary = odds.Legendary, Mythic = odds.Mythic }
		if weights.Legendary + weights.Mythic <= 0 then
			weights.Legendary = 1
		end
		return weightedPick(weights, { "Legendary", "Mythic" }), true
	end
	return weightedPick(odds, Config.RarityOrder), false
end

-- Remotes ----------------------------------------------------------------------------------

function EggService:_buy(player: Player, eggId: string)
	local data = S.DataService:Get(player)
	if not data or typeof(eggId) ~= "string" then
		return
	end
	local price = self:Price(eggId, data)
	if not price then
		return
	end
	if not S.DataService:SpendHoney(player, price) then
		Notify.Player(player, "Not enough honey.", "bad")
		return
	end
	data.Eggs[eggId] = (data.Eggs[eggId] or 0) + 1
	S.DataService:MarkDirty(player, "Eggs")
	Notify.Player(player, `Bought a {Config.Eggs[eggId].Name}! Hatch it in your hive.`, "good")
end

function EggService:_firstEmptySlot(player: Player, data): number?
	for slot = 1, S.HiveService:GetUnlockedSlots(player) do
		if not data.Bees[tostring(slot)] then
			return slot
		end
	end
	return nil
end

-- Rolls and places a bee from `eggId` into `slot`. The egg must already be paid for.
function EggService:_hatchInto(player: Player, data, eggId: string, slot: number, nestIndex: number?)
	local count = (data.Pity[eggId] or 0) + 1
	local rarity, forced = self:RollRarity(eggId, count)
	local pool = BeeData.ByRarity[rarity]
	local beeId = pool[rng:NextInteger(1, #pool)]
	local mutation = BeeClass.RollMutation(rng, false)
	local record = BeeClass.NewRecord(beeId, mutation)

	local order = Config.Rarities[rarity].Order
	data.Pity[eggId] = order >= Config.Rarities.Legendary.Order and 0 or count
	local isNew = not data.Codex[beeId]
	data.Bees[tostring(slot)] = record
	data.Codex[beeId] = true
	data.Stats.EggsHatched += 1
	S.DataService:MarkDirty(player, "Eggs", "Pity", "Bees", "Codex")

	S.BeeService:RebuildSwarm(player)
	S.HiveService:RefreshCells(player)

	self.HatchResult:FireClient(player, {
		Slot = slot,
		Record = record,
		Egg = eggId,
		Pity = forced,
		New = isNew,
		Nest = nestIndex,
	})
	if order >= Config.Rarities.Legendary.Order or mutation == "Shadow" then
		local def = BeeData.Bees[beeId]
		local label = (mutation and (mutation .. " ") or "") .. def.Name
		task.delay(nestIndex and 3.5 or 0, function()
			Notify.All(`{player.DisplayName} hatched a {rarity} {label}!`, "rare")
		end)
	end
end

-- Hatch an owned egg into a chosen hive cell (hive menu)
-- one hatch at a time: the client plays a cutscene per hatch, so hatches must not stack up
local hatchLock: { [Player]: number } = {}
local HATCH_GAP = 3.5
local function hatchBusy(player: Player): boolean
	return (hatchLock[player] or 0) > os.clock()
end
game:GetService("Players").PlayerRemoving:Connect(function(player)
	hatchLock[player] = nil
end)

function EggService:_hatch(player: Player, eggId: string, slot: number)
	local data = S.DataService:Get(player)
	if not data or typeof(eggId) ~= "string" or typeof(slot) ~= "number" then
		return
	end
	if hatchBusy(player) then
		return
	end
	slot = math.floor(slot)
	local egg = Config.Eggs[eggId]
	if not egg or (data.Eggs[eggId] or 0) <= 0 then
		Notify.Player(player, "You don't have that egg.", "bad")
		return
	end
	if slot < 1 or slot > S.HiveService:GetUnlockedSlots(player) then
		Notify.Player(player, "That hive slot is locked.", "bad")
		return
	end
	if data.Bees[tostring(slot)] then
		Notify.Player(player, "Pick an empty hive slot.", "bad")
		return
	end
	data.Eggs[eggId] -= 1
	hatchLock[player] = os.clock() + HATCH_GAP
	self:_hatchInto(player, data, eggId, slot, nil)
end

-- Physical nest: walk up, pay honey (or use an owned egg) and hatch into the first free cell
function EggService:_nestHatch(player: Player, nestIndex: number)
	local data = S.DataService:Get(player)
	local nest = typeof(nestIndex) == "number" and Config.Nests[nestIndex]
	if not data or not nest then
		return
	end
	if hatchBusy(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local flat = root and (root.Position - nest.Position) * Vector3.new(1, 0, 1)
	if not flat or flat.Magnitude > Config.NestRange then
		return
	end
	local slot = self:_firstEmptySlot(player, data)
	if not slot then
		Notify.Player(player, "Your hive is full. Unlock a new cell first!", "bad")
		return
	end
	local eggId = nest.Egg
	if (data.Eggs[eggId] or 0) > 0 then
		data.Eggs[eggId] -= 1
	else
		local price = self:Price(eggId, data)
		if not price or not S.DataService:SpendHoney(player, price) then
			Notify.Player(player, "Not enough honey for this egg.", "bad")
			return
		end
	end
	hatchLock[player] = os.clock() + HATCH_GAP
	self:_hatchInto(player, data, eggId, slot, nestIndex)
end

function EggService:_feed(player: Player, slot: number, count: number)
	local data = S.DataService:Get(player)
	if not data or typeof(slot) ~= "number" or typeof(count) ~= "number" then
		return
	end
	count = math.clamp(math.floor(count), 1, 100)
	local record = data.Bees[tostring(math.floor(slot))]
	if not record then
		return
	end
	if record.Level >= Config.Levels.Max then
		Notify.Player(player, "This bee is already max level.", "info")
		return
	end
	count = math.min(count, data.Treats)
	if count <= 0 then
		Notify.Player(player, "No treats left. Buy some in the shop.", "bad")
		return
	end
	data.Treats -= count
	local swarm = S.BeeService:GetSwarm(player)
	local bee = swarm and swarm.Bees[math.floor(slot)]
	local gained
	if bee then
		gained = bee:AddXP(count * Config.Levels.TreatXP)
	else
		local temp = BeeClass.new(math.floor(slot), record, player)
		gained = temp:AddXP(count * Config.Levels.TreatXP)
	end
	S.DataService:MarkDirty(player, "Treats", "Bees")
	if gained > 0 then
		Notify.Player(player, `{BeeData.Bees[record.Id].Name} reached level {record.Level}!`, "good")
		S.BeeService:RebuildSwarm(player)
		S.HiveService:RefreshCells(player)
	end
end

function EggService:_useSerum(player: Player, slot: number)
	local data = S.DataService:Get(player)
	if not data or typeof(slot) ~= "number" then
		return
	end
	local record = data.Bees[tostring(math.floor(slot))]
	if not record then
		return
	end
	if data.Serums <= 0 then
		Notify.Player(player, "You have no Mutation Serum.", "bad")
		return
	end
	local current = record.Mutation and Config.Mutations[record.Mutation]
	if current and current.Order >= #Config.MutationOrder then
		Notify.Player(player, "This bee already has the rarest mutation.", "info")
		return
	end
	data.Serums -= 1
	local rolled = BeeClass.RollMutation(rng, true)
	local rolledDef = Config.Mutations[rolled]
	if not current or rolledDef.Order > current.Order then
		record.Mutation = rolled
		Notify.Player(player, `Mutation: {rolled}!`, "rare")
	else
		Notify.Player(player, `Rolled {rolled}, kept {record.Mutation} (serums never downgrade).`, "info")
	end
	S.DataService:MarkDirty(player, "Serums", "Bees")
	S.BeeService:RebuildSwarm(player)
	S.HiveService:RefreshCells(player)
end

function EggService:_buySerum(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	if not S.DataService:SpendHoney(player, Config.SerumHoneyPrice) then
		Notify.Player(player, "Not enough honey.", "bad")
		return
	end
	data.Serums += 1
	S.DataService:MarkDirty(player, "Serums")
	Notify.Player(player, "Bought a Mutation Serum!", "good")
end

function EggService:Init(services)
	S = services
	self.BuyEgg = Net.Event("BuyEgg")
	self.HatchEgg = Net.Event("HatchEgg")
	self.HatchResult = Net.Event("HatchResult")
	self.FeedBee = Net.Event("FeedBee")
	self.UseSerum = Net.Event("UseSerum")
	self.BuySerum = Net.Event("BuySerum")
	self.NestHatch = Net.Event("NestHatch")
end

function EggService:Start()
	self.BuyEgg.OnServerEvent:Connect(function(player, eggId)
		if Net.Allow(player, "BuyEgg", 0.25) then
			self:_buy(player, eggId)
		end
	end)
	self.HatchEgg.OnServerEvent:Connect(function(player, eggId, slot)
		if Net.Allow(player, "HatchEgg", 0.4) then
			self:_hatch(player, eggId, slot)
		end
	end)
	self.FeedBee.OnServerEvent:Connect(function(player, slot, count)
		if Net.Allow(player, "FeedBee", 0.2) then
			self:_feed(player, slot, count)
		end
	end)
	self.UseSerum.OnServerEvent:Connect(function(player, slot)
		if Net.Allow(player, "UseSerum", 0.5) then
			self:_useSerum(player, slot)
		end
	end)
	self.BuySerum.OnServerEvent:Connect(function(player)
		if Net.Allow(player, "BuySerum", 0.5) then
			self:_buySerum(player)
		end
	end)
	self.NestHatch.OnServerEvent:Connect(function(player, nestIndex)
		if Net.Allow(player, "NestHatch", 1.5) then
			self:_nestHatch(player, nestIndex)
		end
	end)
end

return EggService
