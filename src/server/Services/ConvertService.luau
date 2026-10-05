--[[
	ConvertService
	Turns pollen into honey at the player's hive.

	  - The player converts a base rate alone (works with zero bees).
	  - Each bee trip (BeeService "ToHive") converts that bee's Convert stat.
	  - Honey Bee / Honeycomb Core speed both up; Golden Bee adds a honey multiplier.
	  - Auto-Convert Companion (gamepass) converts remotely when the bag is nearly full.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local ConvertService = {}
ConvertService.Name = "ConvertService"

local TICK = 0.25
local POPUP_EVERY = 1

local S
local converting: { [Player]: boolean } = {}
local pendingPopup: { [Player]: number } = {}

local function speedMult(player: Player): number
	local hive = S.BeeService:GetHiveMods(player)
	if not hive then
		return 1
	end
	return 1 + hive.HiveConvert + hive.ConvertBonus
end

local function honeyMult(player: Player): number
	local hive = S.BeeService:GetHiveMods(player)
	return 1 + (hive and hive.HoneyMult or 0)
end

function ConvertService:IsConverting(player: Player): boolean
	return converting[player] == true
end

function ConvertService:SetConverting(player: Player, value: boolean)
	if value then
		local data = S.DataService:Get(player)
		if not data or data.Pollen <= 0 then
			Notify.Player(player, "Your backpack is empty. Go collect pollen!", "info")
			value = false
		elseif not self:_inRange(player) then
			Notify.Player(player, "Stand on your hive pad to make honey.", "info")
			value = false
		end
	end
	converting[player] = value or nil
	player:SetAttribute("Converting", value == true)
end

function ConvertService:_inRange(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pad = S.HiveService:PadPosition(player)
	if not root or not pad then
		return false
	end
	return (root.Position - pad).Magnitude <= Config.Convert.Range
end

-- Converts up to `pollen` from the backpack. Returns honey made.
function ConvertService:_convert(player: Player, pollen: number): number
	local data = S.DataService:Get(player)
	if not data or pollen <= 0 or data.Pollen <= 0 then
		return 0
	end
	local amount = math.min(pollen, data.Pollen)
	data.Pollen -= amount
	if data.Pollen < 0.5 then
		data.Pollen = 0
	end
	S.DataService:MarkDirty(player, "Pollen")
	local honey = amount * Config.Convert.HoneyPerPollen * honeyMult(player)
	S.DataService:AddHoney(player, honey)
	pendingPopup[player] = (pendingPopup[player] or 0) + honey
	return honey
end

function ConvertService:BeeConvert(player: Player, bee, cellPosition: Vector3?)
	if not converting[player] then
		return 0
	end
	local honey = self:_convert(player, bee.Stats.Convert * speedMult(player))
	if honey > 0 then
		-- everyone sees the honey orb pop into that cell
		Notify.Fx("HoneyOrb", { Hive = S.HiveService:GetHiveIndex(player), Slot = bee.Slot })
	end
	return honey
end

function ConvertService:ConvertAll(player: Player): number
	local data = S.DataService:Get(player)
	if not data then
		return 0
	end
	return self:_convert(player, data.Pollen)
end

-- Converts a share of backpack capacity (Golden Touch)
function ConvertService:ConvertFraction(player: Player, fraction: number): number
	return self:_convert(player, S.FieldService:Capacity(player) * fraction)
end

function ConvertService:_tick()
	for _, player in Players:GetPlayers() do
		local data = S.DataService:Get(player)
		if data then
			local capacity = S.FieldService:Capacity(player)
			if converting[player] then
				if not self:_inRange(player) then
					self:SetConverting(player, false)
				else
					local rate = (Config.Convert.BasePerSecond + capacity * Config.Convert.CapacityFraction) * speedMult(player)
					self:_convert(player, rate * TICK)
					if data.Pollen <= 0 then
						converting[player] = nil
						player:SetAttribute("Converting", false)
						Notify.Player(player, "All pollen converted to honey!", "good")
					end
				end
			elseif S.MonetizationService:HasPass(player, "AutoConvert")
				and data.Pollen >= capacity * Config.Convert.AutoConvertThreshold
			then
				self:_convert(player, capacity * Config.Convert.AutoConvertFraction * TICK)
			end
		end
	end
end

function ConvertService:_flushPopups()
	for player, honey in pendingPopup do
		if honey >= 1 then
			local pad = S.HiveService:PadPosition(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local at = (converting[player] and pad) or (root and root.Position) or pad
			if at then
				Notify.FxTo(player, "Honey", { Position = at + Vector3.new(0, 5, 0), Amount = honey })
			end
		end
	end
	table.clear(pendingPopup)
end

function ConvertService:Init(services)
	S = services
	self.ToggleConvert = Net.Event("ToggleConvert")
end

function ConvertService:Start()
	self.ToggleConvert.OnServerEvent:Connect(function(player, on)
		if Net.Allow(player, "ToggleConvert", 0.3) then
			self:SetConverting(player, on == true)
		end
	end)

	-- "Make Honey" prompts on every hive pad
	local map = Workspace:WaitForChild("Map", 30)
	local hives = map and map:FindFirstChild("Hives")
	if hives then
		for _, hive in hives:GetChildren() do
			local pad = hive:FindFirstChild("Pad")
			local prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					if S.HiveService:GetHiveIndex(player) ~= hive:GetAttribute("Index") then
						Notify.Player(player, "This is not your hive.", "bad")
						return
					end
					self:SetConverting(player, not converting[player])
				end)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		converting[player] = nil
		pendingPopup[player] = nil
	end)

	task.spawn(function()
		local sincePopup = 0
		while true do
			task.wait(TICK)
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn("[ConvertService] tick:", err)
			end
			sincePopup += TICK
			if sincePopup >= POPUP_EVERY then
				sincePopup = 0
				self:_flushPopups()
			end
		end
	end)
end

return ConvertService
