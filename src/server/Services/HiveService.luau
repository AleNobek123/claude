--[[
	HiveService
	Hive ownership, the hex grid of cells, slot purchases and bee placement (swaps).

	Each player gets one of the hives in Workspace.Map.Hives. Bees are stored in the profile
	keyed by slot ("1".."37"), so a swap is a single atomic exchange of two table entries.
	Cells are coloured by the rarity of the bee they hold, so every passer-by sees the swarm.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VipStyle = require(Shared.VipStyle)
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local HiveService = {}
HiveService.Name = "HiveService"

local LOCKED_COLOR = Color3.fromRGB(122, 84, 48)
local EMPTY_COLOR = Color3.fromRGB(255, 205, 90)

local S
local hives = {} -- [index] = { Model, Owner, Cells = { [slot] = BasePart } }
local playerHive: { [Player]: number } = {}

-- Queries ---------------------------------------------------------------------------------

function HiveService:GetHive(player: Player)
	local index = playerHive[player]
	return index and hives[index] or nil
end

function HiveService:GetHiveIndex(player: Player): number?
	return playerHive[player]
end

function HiveService:GetOwner(index: number): Player?
	local hive = hives[index]
	return hive and hive.Owner or nil
end

function HiveService:GetUnlockedSlots(player: Player): number
	local data = S.DataService:Get(player)
	if not data then
		return 0
	end
	local slots = math.min(data.HiveSlots, Config.Hive.MaxHoneySlots)
	if S.MonetizationService:HasPass(player, "ExtraSlots") then
		slots += Config.Hive.GamepassSlots
	end
	return slots
end

function HiveService:SlotPrice(data): number
	local bought = data.HiveSlots - Config.Hive.StartSlots
	return math.floor(Config.Hive.SlotBasePrice * Config.Hive.SlotGrowth ^ bought)
end

-- World position just in front of a cell (where a bee lands)
function HiveService:CellPosition(player: Player, slot: number): Vector3?
	local hive = self:GetHive(player)
	local cell = hive and hive.Cells[slot]
	if not cell then
		return nil
	end
	local forward = hive.Model:GetAttribute("Forward") or Vector3.new(0, 0, 1)
	return cell.Position + forward * 1.4
end

function HiveService:PadPosition(player: Player): Vector3?
	local hive = self:GetHive(player)
	local pad = hive and hive.Model:FindFirstChild("Pad")
	return pad and pad.Position or nil
end

function HiveService:CountBees(data): number
	local n = 0
	for _ in data.Bees do
		n += 1
	end
	return n
end

-- Visuals --------------------------------------------------------------------------------------

function HiveService:RefreshCells(player: Player)
	local hive = self:GetHive(player)
	local data = S.DataService:Get(player)
	if not hive or not data then
		return
	end
	local unlocked = self:GetUnlockedSlots(player)
	for slot, cell in hive.Cells do
		local record = data.Bees[tostring(slot)]
		local light = cell:FindFirstChild("MutationLight")
		if record then
			local def = BeeData.Bees[record.Id]
			cell.Color = Config.Rarities[def.Rarity].Color
			cell.Transparency = 0
			cell.Material = Enum.Material.SmoothPlastic
			cell:SetAttribute("BeeId", record.Id)
			cell:SetAttribute("Level", record.Level)
			cell:SetAttribute("Mutation", record.Mutation)
			local mutation = record.Mutation and Config.Mutations[record.Mutation]
			if mutation then
				if not light then
					light = Instance.new("PointLight")
					light.Name = "MutationLight"
					light.Range = 6
					light.Brightness = 2
					light.Parent = cell
				end
				light.Color = mutation.Color
			elseif light then
				light:Destroy()
			end
		else
			cell:SetAttribute("BeeId", nil)
			cell:SetAttribute("Level", nil)
			cell:SetAttribute("Mutation", nil)
			if light then
				light:Destroy()
			end
			if slot <= unlocked then
				cell.Color = EMPTY_COLOR
				cell.Transparency = 0
			else
				cell.Color = LOCKED_COLOR
				cell.Transparency = 0 -- opaque: translucent cells showed dark see-through patches over the hive
			end
			cell.Material = Enum.Material.SmoothPlastic
		end
		cell:SetAttribute("Locked", slot > unlocked)
	end
end

local function resetCells(hive)
	for _, cell in hive.Cells do
		cell.Color = LOCKED_COLOR
		cell.Transparency = 0 -- opaque: translucent cells showed dark see-through patches over the hive
		cell:SetAttribute("BeeId", nil)
		cell:SetAttribute("Level", nil)
		cell:SetAttribute("Mutation", nil)
		cell:SetAttribute("Locked", true)
		local light = cell:FindFirstChild("MutationLight")
		if light then
			light:Destroy()
		end
	end
end

function HiveService:RefreshSign(player: Player?, index: number, score: number?)
	local hive = hives[index]
	local sign = hive and hive.Model:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChildWhichIsA("BillboardGui", true) or sign and sign:FindFirstChildWhichIsA("SurfaceGui", true)
	if not gui then
		return
	end
	local owner = gui:FindFirstChild("Owner", true)
	local scoreLabel = gui:FindFirstChild("Score", true)
	if owner then
		owner.Text = player and (player.DisplayName .. "'s Hive") or "Free Hive"
	end
	if scoreLabel then
		scoreLabel.Text = player and ("Swarm Score: " .. Format.Short(score or 0)) or "Walk up to claim"
	end
end

-- Overhead name tag: name, swarm score and a title from the rarest bee owned
function HiveService:UpdateOverhead(player: Player, score: number, title: string?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("BeeTag")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "BeeTag"
		gui.Size = UDim2.fromOffset(200, 56)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 90
		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0.45, 0)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Parent = gui
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.new(0, 0, 0.47, 0)
		sub.Size = UDim2.new(1, 0, 0.36, 0)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(255, 214, 90)
		sub.TextStrokeTransparency = 0.4
		sub.Parent = gui
		gui.Parent = head
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local isVip = player:GetAttribute("VIP") == true
	gui.PlayerName.Text = (isVip and "[VIP] " or "") .. player.DisplayName
	VipStyle.Apply(gui.PlayerName, isVip)
	gui.Sub.Text = (title and (title .. "  •  ") or "") .. "Swarm " .. Format.Short(score)
end

function HiveService:RefreshPlayer(player: Player)
	self:RefreshCells(player)
	if S.BeeService and S.BeeService.RefreshScore then
		S.BeeService:RefreshScore(player)
	end
end

-- Ownership ----------------------------------------------------------------------------------------

function HiveService:_assign(player: Player)
	if playerHive[player] then
		return playerHive[player]
	end
	for index = 1, #hives do
		local hive = hives[index]
		if hive and not hive.Owner then
			hive.Owner = player
			hive.Model:SetAttribute("OwnerId", player.UserId)
			playerHive[player] = index
			player:SetAttribute("HiveIndex", index)
			self:RefreshSign(player, index, 0)
			return index
		end
	end
	warn("[HiveService] No free hive for", player.Name)
	return nil
end

function HiveService:_release(player: Player)
	local index = playerHive[player]
	if not index then
		return
	end
	local hive = hives[index]
	hive.Owner = nil
	hive.Model:SetAttribute("OwnerId", nil)
	playerHive[player] = nil
	resetCells(hive)
	self:RefreshSign(nil, index)
end

function HiveService:_spawnAtHive(player: Player, character: Model)
	local hive = self:GetHive(player)
	local pad = hive and hive.Model:FindFirstChild("Pad")
	if not pad then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait() -- let the default spawn finish first
	local frame = hive.Model:FindFirstChild("Frame")
	local lookAt = frame and frame.Position or pad.Position + Vector3.new(0, 0, -10)
	local spot = pad.Position + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(lookAt.X, spot.Y, lookAt.Z)))
end

-- Remotes ---------------------------------------------------------------------------------------------

function HiveService:_moveBee(player: Player, from: number, to: number)
	if typeof(from) ~= "number" or typeof(to) ~= "number" then
		return
	end
	from, to = math.floor(from), math.floor(to)
	local unlocked = self:GetUnlockedSlots(player)
	if from == to or from < 1 or to < 1 or from > unlocked or to > unlocked then
		return
	end
	local data = S.DataService:Get(player)
	if not data or not data.Bees[tostring(from)] then
		return
	end
	local a, b = tostring(from), tostring(to)
	data.Bees[a], data.Bees[b] = data.Bees[b], data.Bees[a]
	S.DataService:MarkDirty(player, "Bees")
	S.BeeService:RebuildSwarm(player)
	self:RefreshCells(player)
end

function HiveService:_buySlot(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	if data.HiveSlots >= Config.Hive.MaxHoneySlots then
		Notify.Player(player, "All honey slots unlocked! The last 2 come with the +2 Hive Slots pass.", "info")
		return
	end
	local price = self:SlotPrice(data)
	if not S.DataService:SpendHoney(player, price) then
		Notify.Player(player, "Not enough honey for a new slot.", "bad")
		return
	end
	data.HiveSlots += 1
	S.DataService:MarkDirty(player, "HiveSlots")
	self:RefreshCells(player)
	Notify.Player(player, `Hive slot {data.HiveSlots} unlocked!`, "good")
end

-- Lifecycle ----------------------------------------------------------------------------------------------

function HiveService:Init(services)
	S = services
	self.MoveBee = Net.Event("MoveBee")
	self.BuySlot = Net.Event("BuySlot")
end

function HiveService:Start()
	local map = Workspace:WaitForChild("Map", 30)
	local folder = map and map:WaitForChild("Hives", 10)
	if folder then
		for _, model in folder:GetChildren() do
			local index = model:GetAttribute("Index")
			if index then
				local cells = {}
				local cellFolder = model:FindFirstChild("Cells")
				if cellFolder then
					for _, cell in cellFolder:GetChildren() do
						local slot = cell:GetAttribute("Slot")
						if slot then
							cells[slot] = cell
						end
					end
				end
				hives[index] = { Model = model, Owner = nil, Cells = cells }
				resetCells(hives[index])
				self:RefreshSign(nil, index)
			end
		end
	else
		warn("[HiveService] Workspace.Map.Hives not found - run the map builder")
	end

	self.MoveBee.OnServerEvent:Connect(function(player, from, to)
		if Net.Allow(player, "MoveBee", 0.15) then
			self:_moveBee(player, from, to)
		end
	end)
	self.BuySlot.OnServerEvent:Connect(function(player)
		if Net.Allow(player, "BuySlot", 0.3) then
			self:_buySlot(player)
		end
	end)

	S.DataService:OnLoaded(function(player)
		self:_assign(player)
		self:RefreshCells(player)
		S.BeeService:RebuildSwarm(player)
		if player.Character then
			task.spawn(self._spawnAtHive, self, player, player.Character)
		end
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			if playerHive[player] then
				self:_spawnAtHive(player, character)
				task.delay(1, function()
					if S.BeeService and S.BeeService.RefreshScore then
						S.BeeService:RefreshScore(player)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)
end

return HiveService
