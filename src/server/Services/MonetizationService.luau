--[[
	MonetizationService
	Developer products, gamepasses and purchase policy.

	- ProcessReceipt routes each product to a grant function and acknowledges the receipt
	  only after DataService has stored the grant together with its PurchaseId.
	- Paid random items (Royal Egg) are hidden and refused where PolicyService restricts them.
	- In Studio, products and passes whose Id is 0 are granted directly for testing.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local MonetizationService = {}
MonetizationService.Name = "MonetizationService"

local S -- services table
local owned: { [Player]: { [string]: boolean } } = {}
local productById: { [number]: string } = {}
local passById: { [number]: string } = {}

local function studioGrants(): boolean
	return RunService:IsStudio() and Config.StudioFreePurchases
end

-- Product grants: run inside DataService:GrantPurchase (data is the live profile) ---------

local ProductGrants = {}

function ProductGrants.InstantConvert(player, data)
	S.ConvertService:ConvertAll(player)
	Notify.Player(player, "Instant Convert! Your backpack is now honey.", "good")
end

function ProductGrants.FieldBooster(player, data)
	local def = Config.Products.FieldBooster
	local field = data.LastField or "Sunflower"
	local now = os.time()
	data.Boosts[field] = math.max(now, data.Boosts[field] or 0) + def.Duration
	S.DataService:MarkDirty(player, "Boosts")
	local fieldDef = Config.FieldById[field]
	Notify.Player(player, `Field Booster active: 2x pollen in {fieldDef and fieldDef.Name or field}!`, "good")
end

local function honeyPackAmount(data): number
	local backpack = Config.BackpackById[data.Backpack]
	return math.max(5000, (backpack and backpack.Capacity or 200) * 15)
end

function ProductGrants.HoneyPackS(player, data)
	S.DataService:AddHoney(player, honeyPackAmount(data), false)
	Notify.Player(player, "Honey Pack delivered!", "good")
end

function ProductGrants.HoneyPackL(player, data)
	S.DataService:AddHoney(player, math.floor(honeyPackAmount(data) * 5.5), false)
	Notify.Player(player, "Big Honey Pack delivered!", "good")
end

function ProductGrants.RoyalEgg(player, data)
	data.Eggs.Royal = (data.Eggs.Royal or 0) + 1
	S.DataService:MarkDirty(player, "Eggs")
	Notify.Player(player, "You got a Royal Egg! Hatch it from the Hive menu.", "rare")
end

-- Rewarded video: the ad's reward product arrives here like any purchase
function ProductGrants.AdReward(player, data)
	S.RewardService:GrantAd(player, data)
end

function ProductGrants.MutationSerum(player, data)
	data.Serums += 1
	S.DataService:MarkDirty(player, "Serums")
	Notify.Player(player, "Mutation Serum added. Use it on a bee in the Hive menu.", "rare")
end

-- Honey Forever ladder: every purchase adds one tier (x2 honey each), up to Config.HoneyLadder.MaxTier.
-- Each step has its own product; a step older than the player's tier can only be bought by prompting
-- the product directly (e.g. an exploit buying the 3 R$ step again), so it never climbs the ladder.
local ladderStepById: { [number]: number } = {}

function ProductGrants.HoneyLadder(player, data, productId: number?)
	local tier = data.HoneyTier or 0
	local step = productId and ladderStepById[productId]
	if step and step < tier then
		Notify.Player(player, "You already own that Honey Forever step.", "info")
		return
	end
	data.HoneyTier = math.min(tier + 1, Config.HoneyLadder.MaxTier)
	S.DataService:MarkDirty(player, "HoneyTier")
	player:SetAttribute("HoneyTier", data.HoneyTier)
	Notify.Player(player, `Honey Forever upgraded: x{Config.HoneyMultiplier(data.HoneyTier)} honey!`, "rare")
end

-- Gamepasses ---------------------------------------------------------------------------------

function MonetizationService:HasPass(player: Player, name: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[name] == true
end

function MonetizationService:_setPass(player: Player, name: string, value: boolean)
	owned[player] = owned[player] or {}
	owned[player][name] = value
	player:SetAttribute("Pass_" .. name, value)
	if name == "VIPField" then
		player:SetAttribute("VIP", value)
	end
	if S.HiveService and S.HiveService.RefreshPlayer then
		task.spawn(S.HiveService.RefreshPlayer, S.HiveService, player)
	end
end

function MonetizationService:_checkPasses(player: Player)
	owned[player] = owned[player] or {}
	for name, def in Config.Gamepasses do
		if def.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.Id)
			if ok and has then
				self:_setPass(player, name, true)
			end
		end
	end
end

function MonetizationService:_checkPolicy(player: Player)
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	local restricted = ok and policy and policy.ArePaidRandomItemsRestricted or false
	player:SetAttribute("PaidRandomRestricted", restricted)
end

-- Purchase entry point from the client ----------------------------------------------------------

function MonetizationService:_request(player: Player, kind: string, name: string)
	if typeof(kind) ~= "string" or typeof(name) ~= "string" then
		return
	end
	if not Net.Allow(player, "Purchase", 0.5) then
		return
	end

	if kind == "Product" then
		local def = Config.Products[name]
		if not def then
			return
		end
		if def.RandomItem and player:GetAttribute("PaidRandomRestricted") then
			Notify.Player(player, "This item is not available in your region.", "bad")
			return
		end
		if def.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, def.Id)
		elseif studioGrants() then
			local grant = ProductGrants[name]
			S.DataService:GrantPurchase(player, "studio-" .. HttpService:GenerateGUID(false), function(data)
				grant(player, data)
			end)
		else
			Notify.Player(player, "This product is not configured yet.", "bad")
		end
	elseif kind == "Ladder" and name == "Honey" then
		local data = S.DataService:Get(player)
		if not data then
			return
		end
		local step = Config.HoneyLadderStep(data.HoneyTier)
		if not step then
			Notify.Player(player, `Honey Forever is maxed at x{Config.HoneyMultiplier(data.HoneyTier)}!`, "info")
		elseif step.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, step.Id)
		elseif studioGrants() then
			S.DataService:GrantPurchase(player, "studio-" .. HttpService:GenerateGUID(false), function(profile)
				ProductGrants.HoneyLadder(player, profile)
			end)
		else
			Notify.Player(player, "This product is not configured yet.", "bad")
		end
	elseif kind == "Pass" then
		local def = Config.Gamepasses[name]
		if not def or self:HasPass(player, name) then
			return
		end
		if def.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, def.Id)
		elseif studioGrants() then
			self:_setPass(player, name, true)
			Notify.Player(player, `{def.Name} unlocked (Studio test).`, "good")
		else
			Notify.Player(player, "This gamepass is not configured yet.", "bad")
		end
	end
end

function MonetizationService:Init(services)
	S = services
	for name, def in Config.Products do
		if def.Id ~= 0 then
			productById[def.Id] = name
		end
	end
	for name, def in Config.Gamepasses do
		if def.Id ~= 0 then
			passById[def.Id] = name
		end
	end
	if Config.AdReward.ProductId ~= 0 then
		productById[Config.AdReward.ProductId] = "AdReward"
	end
	for index, step in Config.HoneyLadder.Steps do
		if step.Id ~= 0 then
			productById[step.Id] = "HoneyLadder"
			ladderStepById[step.Id] = ladderStepById[step.Id] or index
		end
	end
	self.RequestPurchase = Net.Event("RequestPurchase")
end

function MonetizationService:Start()
	self.RequestPurchase.OnServerEvent:Connect(function(player, kind, name)
		self:_request(player, kind, name)
	end)

	local function onPlayer(player: Player)
		task.spawn(self._checkPasses, self, player)
		task.spawn(self._checkPolicy, self, player)
		task.delay(8, function()
			if player.Parent and player.MembershipType == Enum.MembershipType.Premium then
				Notify.Player(player, `Roblox Premium bonus: +{math.floor(Config.Premium.HoneyBonus * 100)}% honey!`, "rare")
			end
		end)
	end
	S.DataService:OnLoaded(function(player, data)
		player:SetAttribute("HoneyTier", data.HoneyTier or 0)
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = passById[passId]
		if purchased and name then
			self:_setPass(player, name, true)
			Notify.Player(player, `Thanks! {Config.Gamepasses[name].Name} unlocked.`, "good")
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local name = productById[receipt.ProductId]
		if not player or not name then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not S.DataService:WaitFor(player, 10) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local grant = ProductGrants[name]
		local stored = S.DataService:GrantPurchase(player, receipt.PurchaseId, function(data)
			grant(player, data, receipt.ProductId)
		end)
		if stored then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return MonetizationService
