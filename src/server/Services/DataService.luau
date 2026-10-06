--[[
	DataService
	Session-locked player profiles on top of DataStoreService (the ProfileService pattern,
	written out so every rule is visible):

	  1. Load = UpdateAsync that claims the profile for this server (Meta.Session).
	     If another live server holds it, wait and retry; a lock older than 30 min is stale
	     and may be taken over.
	  2. Every save is an UpdateAsync that first checks this server still owns the session.
	     If another server took it, this server drops its copy and kicks the player, so two
	     servers can never both write (no duplication through server hopping).
	  3. Leaving releases the lock in the same write as the final save.
	  4. Purchases are granted into the profile together with their PurchaseId; the receipt is
	     acknowledged only after that write succeeds (see GrantPurchase).

	When DataStores are unavailable (unpublished place in Studio) an in-memory store is used
	and a warning is printed, so the game stays testable.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local STORE_NAME = "BeeTycoon_Players_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_STALE_SECONDS = 1800
local LOAD_ATTEMPTS = 5
local RETRY_DELAY = 6
local MAX_RECEIPTS = 50
local REPLICATE_INTERVAL = 0.1

local DataService = {}
DataService.Name = "DataService"

DataService.Template = {
	Honey = 0,
	TotalHoney = 0,
	Pollen = 0,
	Collector = "Scoop",
	OwnedCollectors = { Scoop = true },
	Backpack = "Pouch",
	OwnedBackpacks = { Pouch = true },
	HiveSlots = Config.Hive.StartSlots,
	Bees = {}, -- ["slot"] = BeeRecord
	Eggs = { Basic = 1 },
	Pity = { Basic = 0, Silver = 0, Royal = 0 },
	Codex = {},
	Treats = 0,
	Serums = 0,
	Boosts = {}, -- [fieldId] = unix expiry
	LastField = "Sunflower",
	Daily = { LastDay = 0, Streak = 0 },
	Stats = { PollenCollected = 0, MonstersDefeated = 0, EggsHatched = 0, EventsJoined = 0 },
	Tutorial = { Done = false, Starter = false, Step = 1 },
	Settings = { Music = true, Sfx = true, Graphics = "High" },
	Codes = {}, -- [CODE] = true
	HoneyTier = 0, -- Honey Forever ladder: honey x Config.HoneyMultiplier(tier)
	Boots = "FlipFlops",
	OwnedBoots = { FlipFlops = true },
	Playtime = { Day = 0, Seconds = 0, Claimed = {} }, -- today's play time and claimed milestones
	Social = {}, -- [providerId] = true once claimed
	CodexSeen = {}, -- bees whose Codex entry the player has opened
}

type Profile = {
	Key: string,
	Data: { [string]: any },
	Meta: { [string]: any },
	Released: boolean,
	LastSave: number,
}

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: { [string]: boolean } } = {}
local store
local usingMock = false

-- Signals (not BindableEvents: those would deep-copy the profile table)
local loadedEvent = Signal.new()
local releasingEvent = Signal.new()
local honeyEarnedEvent = Signal.new()

DataService.ProfileLoaded = loadedEvent -- (player, data)
DataService.ProfileReleasing = releasingEvent -- (player, data)
DataService.HoneyEarned = honeyEarnedEvent -- (player, amount)

-- Utilities -------------------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds keys missing from `data` (new fields after an update) without touching existing ones
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

-- In-memory store with UpdateAsync semantics (returning nil cancels the write)
local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({ data = {} }, MockStore)
end

function MockStore:UpdateAsync(key, transform)
	local result = transform(deepCopy(self.data[key]))
	if result ~= nil then
		self.data[key] = deepCopy(result)
	end
	return result
end

function MockStore:GetAsync(key)
	return deepCopy(self.data[key])
end

local function resolveStore()
	local ok, dataStore = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		local probeOk, err = pcall(dataStore.GetAsync, dataStore, "__probe")
		if probeOk then
			return dataStore, false
		end
		warn("[DataService] DataStore unavailable, using in-memory store. Reason:", err)
	else
		warn("[DataService] DataStore unavailable, using in-memory store. Reason:", dataStore)
	end
	return MockStore.new(), true
end

local function sessionIsOurs(meta): boolean
	local session = meta and meta.Session
	return session ~= nil and session.JobId == game.JobId and session.PlaceId == game.PlaceId
end

-- Loading ------------------------------------------------------------------------------

local function claimProfile(key: string, force: boolean)
	local lockedByOther = false
	local ok, result = pcall(function()
		return store:UpdateAsync(key, function(stored)
			stored = stored or {
				Data = deepCopy(DataService.Template),
				Meta = { Created = os.time(), ReceiptIds = {}, LoadCount = 0 },
			}
			local meta = stored.Meta
			local session = meta.Session
			local fresh = session and (os.time() - (meta.LastUpdate or 0)) < LOCK_STALE_SECONDS
			if session and not sessionIsOurs(meta) and fresh and not force then
				lockedByOther = true
				return nil -- cancel: someone else is playing on this profile
			end
			meta.Session = { JobId = game.JobId, PlaceId = game.PlaceId }
			meta.LastUpdate = os.time()
			meta.LoadCount = (meta.LoadCount or 0) + 1
			return stored
		end)
	end)
	return ok, result, lockedByOther
end

function DataService:Load(player: Player)
	local key = "Player_" .. player.UserId
	local stored
	for attempt = 1, LOAD_ATTEMPTS + 1 do
		local force = attempt > LOAD_ATTEMPTS -- last resort: take the session over
		local ok, result, locked = claimProfile(key, force)
		if ok and result then
			stored = result
			break
		end
		if not ok then
			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {result}`)
		elseif locked then
			warn(`[DataService] {player.Name}'s profile is open on another server, retrying`)
		end
		if not player.Parent then
			return nil
		end
		task.wait(RETRY_DELAY)
	end

	if not stored then
		player:Kick("Could not load your data. Please rejoin in a moment.")
		return nil
	end
	if not player.Parent then
		-- left while loading: give the lock back straight away
		self:_release(key, stored)
		return nil
	end

	reconcile(stored.Data, DataService.Template)
	stored.Meta.ReceiptIds = stored.Meta.ReceiptIds or {}

	local profile: Profile = {
		Key = key,
		Data = stored.Data,
		Meta = stored.Meta,
		Released = false,
		LastSave = os.clock(),
	}
	profiles[player] = profile
	dirty[player] = {}
	self:_createLeaderstats(player, profile.Data)
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, profile.Data)
	return profile.Data
end

function DataService:_release(key: string, stored)
	pcall(function()
		store:UpdateAsync(key, function(current)
			if current and sessionIsOurs(current.Meta) then
				current.Meta.Session = nil
				return current
			end
			return nil
		end)
	end)
end

-- Saving --------------------------------------------------------------------------------

-- Returns true when the profile was written. `release` gives the session lock back.
function DataService:Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	if release then
		profile.Released = true
	end

	local sessionLost = false
	local ok, err = pcall(function()
		store:UpdateAsync(profile.Key, function(stored)
			if stored and stored.Meta and stored.Meta.Session and not sessionIsOurs(stored.Meta) then
				sessionLost = true
				return nil
			end
			stored = stored or { Meta = { Created = os.time() } }
			stored.Data = profile.Data
			stored.Meta.ReceiptIds = profile.Meta.ReceiptIds
			stored.Meta.LastUpdate = os.time()
			stored.Meta.Session = (not release) and { JobId = game.JobId, PlaceId = game.PlaceId } or nil
			return stored
		end)
	end)

	if sessionLost then
		-- another server owns this profile now: never write again from here
		profile.Released = true
		profiles[player] = nil
		if player.Parent then
			player:Kick("Your data was opened on another server.")
		end
		return false
	end
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
		if release then
			profile.Released = false -- allow BindToClose to retry
		end
		return false
	end
	profile.LastSave = os.clock()
	return true
end

-- Access ------------------------------------------------------------------------------------

function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService:WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return self:Get(player)
end

-- Runs handler for profiles already loaded and every profile loaded later
-- (services start after early joiners may already be loaded)
function DataService:OnLoaded(handler)
	for player, profile in profiles do
		task.spawn(handler, player, profile.Data)
	end
	return loadedEvent:Connect(handler)
end

function DataService:IsMock(): boolean
	return usingMock
end

-- Queue keys to send to the owning client (flushed at 10 Hz)
function DataService:MarkDirty(player: Player, ...: string)
	local keys = dirty[player]
	if not keys then
		return
	end
	for _, key in { ... } do
		keys[key] = true
	end
end

function DataService:AddHoney(player: Player, amount: number, earned: boolean?)
	local data = self:Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Honey += amount
	if earned ~= false then
		data.TotalHoney += amount
		honeyEarnedEvent:Fire(player, amount)
	end
	self:MarkDirty(player, "Honey", "TotalHoney")
end

function DataService:SpendHoney(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or amount < 0 or data.Honey < amount then
		return false
	end
	data.Honey -= amount
	self:MarkDirty(player, "Honey")
	return true
end

-- Idempotent purchase grant. Returns true once the grant is safely stored.
function DataService:GrantPurchase(player: Player, purchaseId: string, grant: (data: any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local receipts = profile.Meta.ReceiptIds
	if table.find(receipts, purchaseId) then
		return true -- already granted earlier in this session
	end
	grant(profile.Data)
	table.insert(receipts, purchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	return self:Save(player, false)
end

-- Leaderstats --------------------------------------------------------------------------------

function DataService:_createLeaderstats(player: Player, data)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local honey = Instance.new("NumberValue")
	honey.Name = "Honey"
	honey.Value = data.Honey
	honey.Parent = stats
	local swarm = Instance.new("NumberValue")
	swarm.Name = "Swarm"
	swarm.Value = 0
	swarm.Parent = stats
	stats.Parent = player
end

-- Lifecycle -----------------------------------------------------------------------------------

function DataService:Init()
	store, usingMock = resolveStore()
	self.StateUpdate = Net.Event("StateUpdate")
	self.GetData = Net.Function("GetData")

	self.GetData.OnServerInvoke = function(player)
		local data = self:WaitFor(player, 30)
		return data and deepCopy(data) or nil
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.Load, self, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			releasingEvent:Fire(player, profile.Data)
			self:Save(player, true)
		end
		profiles[player] = nil
		dirty[player] = nil
		Net.Forget(player)
	end)

	-- autosave, spread across the interval so writes do not spike together
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, profile in profiles do
				if not profile.Released and now - profile.LastSave >= AUTOSAVE_INTERVAL then
					task.spawn(self.Save, self, player, false)
				end
			end
		end
	end)

	-- replicate changed keys to each owner
	task.spawn(function()
		while true do
			task.wait(REPLICATE_INTERVAL)
			for player, keys in dirty do
				if next(keys) then
					local data = self:Get(player)
					if data then
						local payload = {}
						for key in keys do
							payload[key] = data[key]
						end
						table.clear(keys)
						self.StateUpdate:FireClient(player, payload)
						local stats = player:FindFirstChild("leaderstats")
						if stats and payload.Honey then
							stats.Honey.Value = math.floor(data.Honey)
						end
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				local profile = profiles[player]
				if profile then
					releasingEvent:Fire(player, profile.Data)
				end
				self:Save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + (RunService:IsStudio() and 5 or 25)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
