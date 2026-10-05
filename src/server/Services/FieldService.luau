--[[
	FieldService
	Flower fields: tile pollen levels, access rules, harvesting and the Collect remote.

	The server owns every tile level. Clients only receive quantized level changes
	(21 steps) in a compact buffer and resize the flowers locally.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local FieldService = {}
FieldService.Name = "FieldService"

local LEVEL_STEPS = 20
local REGEN_TICK = 0.5
local BROADCAST_TICK = 0.25

local S
local fields = {} -- [id] = field record
local eventState = nil -- { FieldId, Multiplier, Type }
local fullWarned: { [Player]: number } = {}
local rng = Random.new()

local function quantize(level: number): number
	return math.floor(level * LEVEL_STEPS + 0.5)
end

-- Setup ------------------------------------------------------------------------------------

local function tilePosition(def, gx: number, gz: number): Vector3
	local size = Config.Tiles.Size
	local offset = (def.Tiles + 1) / 2
	return def.Center + Vector3.new((gx - offset) * size, 0, (gz - offset) * size)
end

local function buildField(def, folder)
	local field = {
		Id = def.Id,
		Def = def,
		Center = def.Center,
		Half = def.Tiles * Config.Tiles.Size / 2,
		Tiles = {},
		Dirty = {},
		Monsters = 0,
	}
	-- colours come from the map (so a designer can repaint flowers); fallback is seeded
	local colors = {}
	local flowers = folder and folder:FindFirstChild("Flowers")
	if flowers then
		for _, part in flowers:GetChildren() do
			local tile = part:GetAttribute("Tile")
			local color = part:GetAttribute("FlowerColor")
			if tile and color then
				colors[tile] = color
			end
		end
	end
	local seeded = Random.new(def.Index * 1000)
	for gx = 1, def.Tiles do
		for gz = 1, def.Tiles do
			local index = (gx - 1) * def.Tiles + gz
			local color = colors[index] or def.Flowers[seeded:NextInteger(1, #def.Flowers)]
			field.Tiles[index] = {
				Position = tilePosition(def, gx, gz),
				Color = color,
				Level = 1,
				Sent = LEVEL_STEPS,
			}
		end
	end
	return field
end

-- Queries ---------------------------------------------------------------------------------------

function FieldService:GetField(id: string)
	return fields[id]
end

function FieldService:GetFields()
	return fields
end

function FieldService:GetFieldAt(position: Vector3)
	for _, field in fields do
		local d = position - field.Center
		if math.abs(d.X) <= field.Half + 1 and math.abs(d.Z) <= field.Half + 1 and d.Y > -5 and d.Y < 30 then
			return field
		end
	end
	return nil
end

function FieldService:GetEventState()
	return eventState
end

function FieldService:CanAccess(player: Player, field): boolean
	if eventState and eventState.FieldId == field.Id then
		return true -- events open the gate for everyone
	end
	if field.Def.VIP then
		return S.MonetizationService:HasPass(player, "VIPField")
	end
	local data = S.DataService:Get(player)
	if not data then
		return false
	end
	return S.HiveService:CountBees(data) >= field.Def.BeesRequired
end

-- The accessible field the player is standing in, plus their root part
function FieldService:GetPlayerField(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	local field = self:GetFieldAt(root.Position)
	if field and self:CanAccess(player, field) then
		return field, root
	end
	return nil, root
end

function FieldService:Capacity(player: Player): number
	local data = S.DataService:Get(player)
	local backpack = data and Config.BackpackById[data.Backpack]
	return backpack and backpack.Capacity or 0
end

-- Every multiplier that applies to pollen from `field` for `player`
function FieldService:PollenMultiplier(player: Player, field, color: string?): number
	local mult = field.Def.Multiplier
	if eventState and eventState.FieldId == field.Id then
		mult *= eventState.Multiplier
	end
	local data = S.DataService:Get(player)
	if data then
		local expiry = data.Boosts[field.Id]
		if expiry and expiry > os.time() then
			mult *= Config.Products.FieldBooster.Multiplier
		end
	end
	local hive = S.BeeService and S.BeeService:GetHiveMods(player)
	if hive then
		mult *= 1 + hive.PollenMult
		if color == "Red" then
			mult *= 1 + hive.RedPollen
		end
	end
	return mult
end

function FieldService:RandomPointNear(field, origin: Vector3, spread: number): Vector3
	local angle = rng:NextNumber() * math.pi * 2
	local dist = rng:NextNumber() * spread
	local p = origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
	local half = field.Half - 1
	local x = math.clamp(p.X, field.Center.X - half, field.Center.X + half)
	local z = math.clamp(p.Z, field.Center.Z - half, field.Center.Z + half)
	return Vector3.new(x, field.Center.Y, z)
end

-- Random tile within `radius` of origin (falls back to any tile)
function FieldService:RandomTileNear(field, origin: Vector3, radius: number)
	local candidates = {}
	for index, tile in field.Tiles do
		local d = tile.Position - origin
		if d.X * d.X + d.Z * d.Z <= radius * radius then
			table.insert(candidates, index)
		end
	end
	local index = #candidates > 0 and candidates[rng:NextInteger(1, #candidates)] or rng:NextInteger(1, #field.Tiles)
	return index, field.Tiles[index]
end

-- Harvesting ---------------------------------------------------------------------------------------

function FieldService:GivePollen(player: Player, amount: number): number
	local data = S.DataService:Get(player)
	if not data or amount <= 0 then
		return 0
	end
	local capacity = self:Capacity(player)
	local added = math.min(amount, math.max(0, capacity - data.Pollen))
	if added > 0 then
		data.Pollen += added
		data.Stats.PollenCollected += added
		S.DataService:MarkDirty(player, "Pollen")
	end
	if data.Pollen >= capacity then
		local now = os.clock()
		if not fullWarned[player] or now - fullWarned[player] > 8 then
			fullWarned[player] = now
			Notify.Player(player, "Backpack full! Head back to your hive to make honey.", "info")
		end
	end
	return added
end

local function harvestTile(tile, perTile: number, color: string?, depletion: number): number
	local amount = perTile * (0.5 + 0.5 * tile.Level)
	if color and color == tile.Color then
		amount *= Config.ColorMatchBonus
	end
	tile.Level = math.max(0, tile.Level - depletion)
	return amount
end

local function markDirty(field, index: number)
	local tile = field.Tiles[index]
	local q = quantize(tile.Level)
	if q ~= tile.Sent then
		field.Dirty[index] = true
	end
end

--[[
	Harvests every tile within `radius` of `center` and puts the pollen in the backpack.
	opts: Color (bee colour for the match bonus), Depletion, Popup (show "+N" to the player)
	Returns pollen actually added.
]]
function FieldService:Harvest(player: Player, field, center: Vector3, radius: number, perTile: number, opts)
	opts = opts or {}
	local depletion = opts.Depletion or Config.Tiles.BeeDepletion
	local reach = radius + Config.Tiles.Size / 2
	local mult = self:PollenMultiplier(player, field, nil)
	local hive = S.BeeService and S.BeeService:GetHiveMods(player)
	local redBonus = hive and (1 + hive.RedPollen) or 1
	local total = 0
	for index, tile in field.Tiles do
		local d = tile.Position - center
		if d.X * d.X + d.Z * d.Z <= reach * reach then
			local amount = harvestTile(tile, perTile, opts.Color, depletion)
			if tile.Color == "Red" then
				amount *= redBonus
			end
			total += amount
			markDirty(field, index)
		end
	end
	local added = self:GivePollen(player, math.floor(total * mult + 0.5))
	if opts.Popup and added > 0 then
		Notify.FxTo(player, "Pollen", { Position = center, Amount = added })
	end
	return added
end

-- One bee gather on one tile
function FieldService:BeeGather(player: Player, field, tileIndex: number, amount: number, color: string?): number
	local tile = field.Tiles[tileIndex]
	if not tile then
		return 0
	end
	local value = harvestTile(tile, amount, color, Config.Tiles.BeeDepletion)
	markDirty(field, tileIndex)
	return self:GivePollen(player, math.floor(value * self:PollenMultiplier(player, field, tile.Color) + 0.5))
end

-- Events ---------------------------------------------------------------------------------------

function FieldService:SetEvent(fieldId: string?, multiplier: number?, eventType: string?)
	if fieldId then
		eventState = { FieldId = fieldId, Multiplier = multiplier or 1, Type = eventType }
	else
		eventState = nil
	end
	Workspace:SetAttribute("EventField", fieldId)
	Workspace:SetAttribute("EventType", eventType)
end

-- Collect remote ---------------------------------------------------------------------------------

function FieldService:_collect(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	local collector = Config.CollectorById[data.Collector]
	if not collector then
		return
	end
	-- 15% tolerance for network jitter
	if not Net.Allow(player, "Collect", collector.Cooldown * 0.85) then
		return
	end
	local field, root = self:GetPlayerField(player)
	if not field or not root then
		return
	end
	if data.LastField ~= field.Id then
		data.LastField = field.Id
		S.DataService:MarkDirty(player, "LastField")
	end
	local look = root.CFrame.LookVector
	local center = root.Position + Vector3.new(look.X, 0, look.Z) * math.max(2, collector.Radius * 0.6)
	center = Vector3.new(center.X, field.Center.Y, center.Z)
	self:Harvest(player, field, center, collector.Radius, collector.Power, {
		Depletion = Config.Tiles.Depletion,
		Popup = true,
	})
	if S.MonsterService then
		S.MonsterService:DamageArea(field.Id, center, collector.Radius + 3, collector.Power * 2, player)
	end
end

-- Lifecycle ------------------------------------------------------------------------------------------

function FieldService:Init(services)
	S = services
	self.Collect = Net.Event("Collect")
	self.FieldUpdate = Net.Event("FieldUpdate")
	self.GetFieldStates = Net.Function("GetFieldStates")

	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Fields")
	for _, def in Config.Fields do
		fields[def.Id] = buildField(def, folder and folder:FindFirstChild(def.Id))
	end
end

local function encodeLevels(field): buffer
	local buf = buffer.create(#field.Tiles)
	for index, tile in field.Tiles do
		buffer.writeu8(buf, index - 1, quantize(tile.Level))
	end
	return buf
end

function FieldService:Start()
	self.Collect.OnServerEvent:Connect(function(player)
		self:_collect(player)
	end)

	self.GetFieldStates.OnServerInvoke = function()
		local states = {}
		for id, field in fields do
			states[id] = encodeLevels(field)
		end
		return states
	end

	Players.PlayerRemoving:Connect(function(player)
		fullWarned[player] = nil
	end)

	-- regeneration
	task.spawn(function()
		while true do
			task.wait(REGEN_TICK)
			for _, field in fields do
				local regen = Config.Tiles.Regen * REGEN_TICK
				if eventState and eventState.FieldId == field.Id and eventState.Type == "GoldenBloom" then
					regen *= Config.Events.GoldenRegenMult
				end
				for index, tile in field.Tiles do
					if tile.Level < 1 then
						tile.Level = math.min(1, tile.Level + regen)
						markDirty(field, index)
					end
				end
			end
		end
	end)

	-- batched level changes: [u16 tile][u8 level] per changed tile, one event per field
	task.spawn(function()
		while true do
			task.wait(BROADCAST_TICK)
			for id, field in fields do
				if next(field.Dirty) then
					local count = 0
					for _ in field.Dirty do
						count += 1
					end
					local buf = buffer.create(count * 3)
					local o = 0
					for index in field.Dirty do
						local tile = field.Tiles[index]
						local q = quantize(tile.Level)
						tile.Sent = q
						buffer.writeu16(buf, o, index)
						buffer.writeu8(buf, o + 2, q)
						o += 3
					end
					table.clear(field.Dirty)
					self.FieldUpdate:FireAllClients(id, buf)
				end
			end
		end
	end)
end

return FieldService
