--[[
	ShopService
	Collectors (tools), backpacks and treats bought with honey, plus the visuals that go
	with them: the collector Tool in the player's hand and the backpack on their back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local GearModels = require(Shared.GearModels)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Util.Notify)

local ShopService = {}
ShopService.Name = "ShopService"

local S

local CATEGORY = {
	Collector = { List = "Collectors", Lookup = "CollectorById", Owned = "OwnedCollectors", Equipped = "Collector" },
	Backpack = { List = "Backpacks", Lookup = "BackpackById", Owned = "OwnedBackpacks", Equipped = "Backpack" },
	Boots = { List = "Boots", Lookup = "BootsById", Owned = "OwnedBoots", Equipped = "Boots" },
}

local function assets(kind: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Assets")
	return root and root:FindFirstChild(kind)
end

local function tint(model: Instance, color: Color3)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Tint") then
			part.Color = color
		end
	end
end

-- Fallback visuals if the asset folder is missing ------------------------------------------

local function fallbackTool(): Tool
	local tool = Instance.new("Tool")
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3, 0.4)
	handle.CanCollide = false
	handle:SetAttribute("Tint", true)
	handle.Parent = tool
	return tool
end


-- Visuals -------------------------------------------------------------------------------------

function ShopService:GiveTool(player: Player)
	local data = S.DataService:Get(player)
	local character = player.Character
	local backpackFolder = player:FindFirstChildOfClass("Backpack")
	if not data or not character or not backpackFolder then
		return
	end
	for _, container in { backpackFolder, character } do
		for _, item in container:GetChildren() do
			if item:IsA("Tool") and item:GetAttribute("CollectorId") then
				item:Destroy()
			end
		end
	end

	local def = Config.CollectorById[data.Collector] or Config.Collectors[1]
	local folder = assets("Collectors")
	local template = folder and (folder:FindFirstChild(def.Id) or folder:FindFirstChild(def.Shape))
	local tool = template and template:Clone() or fallbackTool()
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = `+{def.Power} pollen per flower • {def.Radius} stud radius`
	tool:SetAttribute("CollectorId", def.Id)
	tint(tool, def.Color)
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end
	tool.Parent = backpackFolder

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

-- every pack is scaled to the same wearable size (some generated meshes came out huge)
local PACK_HEIGHT = 2.3
local PACK_MAX = Vector3.new(2.4, 2.5, 1.7)

local function fallbackBackpack(): Model
	local model = Instance.new("Model")
	local main = Instance.new("Part")
	main.Name = "Main"
	main.Size = Vector3.new(1.6, 2, 0.9)
	main:SetAttribute("Tint", true)
	main.Parent = model
	model.PrimaryPart = main
	return model
end

function ShopService:GiveBackpack(player: Player)
	local data = S.DataService:Get(player)
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if not data or not torso then
		return
	end
	local old = character:FindFirstChild("BeeBackpack")
	if old then
		old:Destroy()
	end
	local def = Config.BackpackById[data.Backpack] or Config.Backpacks[1]
	local folder = assets("Backpacks")
	local template = folder and (folder:FindFirstChild(def.Id) or folder:FindFirstChild(def.Shape))
	local model = template and template:Clone() or fallbackBackpack()
	model.Name = "BeeBackpack"
	tint(model, def.Color)
	local yaw = model:GetAttribute("Yaw") or 0
	model:PivotTo(CFrame.Angles(0, yaw, 0))
	local _, size = model:GetBoundingBox()
	local fit = math.min(PACK_HEIGHT / size.Y, PACK_MAX.X / size.X, PACK_MAX.Y / size.Y, PACK_MAX.Z / size.Z)
	if math.abs(fit - 1) > 0.03 then
		model:ScaleTo(model:GetScale() * fit)
	end
	local main = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if part ~= main then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = main
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	-- sit on the torso's back attachment; meshes are rounded and carry straps in front, so the
	-- pack is pulled in by part of its depth to touch the back instead of floating behind it
	local depth = model:GetExtentsSize().Z
	local back = torso:FindFirstChild("BodyBackAttachment")
	local anchor = back and back.WorldCFrame or torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2)
	local hug = depth * (model:GetAttribute("Hug") or 0.32)
	model:PivotTo(CFrame.new(anchor.Position) * torso.CFrame.Rotation * CFrame.new(0, 0.05, depth / 2 - hug) * CFrame.Angles(0, yaw, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = main
	weld.Parent = main
	model.Parent = character
end

-- Boots: one model per foot (Shared.GearModels), welded on, plus walk speed
local TALL_BOOTS = { Hiking = true, Rain = true, Honey = true, Rocket = true, Lightning = true, Royal = true }
local function buildShoe(foot: BasePart, def, r15: boolean): Model
	-- R6 legs are 2 studs tall: build around a virtual foot at the bottom of the leg
	local size = r15 and foot.Size or Vector3.new(foot.Size.X, 0.6, foot.Size.Z + 0.1)
	-- tall boots must enclose the lower leg (and the layered clothing on it)
	local leg = r15 and foot.Parent and foot.Parent:FindFirstChild((foot.Name:gsub("Foot", "LowerLeg")))
	if leg and TALL_BOOTS[def.Style] then
		size = Vector3.new(math.max(size.X, leg.Size.X * 1.12 / 1.2), size.Y, math.max(size.Z, leg.Size.Z * 1.12 * 1.5 / 1.4))
	end
	local frame = r15 and foot.CFrame or foot.CFrame * CFrame.new(0, -foot.Size.Y / 2 + 0.3, 0)
	local model = GearModels.Boot(def, size)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local offset = p.CFrame
			p.CFrame = frame * offset
			p.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = foot
			weld.Part1 = p
			weld.Parent = p
		end
	end
	if def.Trail then
		local attachment = Instance.new("Attachment")
		attachment.Name = "BeeBootTrail"
		attachment.Position = Vector3.new(0, -foot.Size.Y / 2, 0.3)
		attachment.Parent = foot
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(def.Accent or def.Color)
		sparkle.LightEmission = 0.8
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.3, 0.6)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.Rate = 12
		sparkle.Parent = attachment
	end
	return model
end

function ShopService:GiveBoots(player: Player)
	local data = S.DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	local def = Config.BootsById[data.Boots] or Config.Boots[1]
	humanoid.WalkSpeed = Config.BaseWalkSpeed * def.Speed
	for _, child in character:GetDescendants() do
		if child.Name == "BeeBoot" or child.Name == "BeeBootTrail" then
			child:Destroy()
		end
	end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	for _, name in r15 and { "LeftFoot", "RightFoot" } or { "Left Leg", "Right Leg" } do
		local foot = character:FindFirstChild(name)
		if foot then
			buildShoe(foot, def, r15).Parent = character
			-- shoes replace the feet (otherwise the avatar's foot pokes through the shoe);
			-- flip-flops show the foot
			if r15 then
				if foot:GetAttribute("BootBaseTransparency") == nil then
					foot:SetAttribute("BootBaseTransparency", foot.Transparency)
				end
				foot.Transparency = def.Style == "FlipFlop" and foot:GetAttribute("BootBaseTransparency") or 1
			end
		end
	end
end

function ShopService:RefreshVisuals(player: Player)
	self:GiveTool(player)
	self:GiveBackpack(player)
	self:GiveBoots(player)
end

-- Purchases -------------------------------------------------------------------------------------

function ShopService:_buy(player: Player, category: string, id: string)
	local info = CATEGORY[category]
	local data = S.DataService:Get(player)
	if not info or not data or typeof(id) ~= "string" then
		return
	end
	local def = Config[info.Lookup][id]
	if not def then
		return
	end
	local owned = data[info.Owned]
	if owned[id] then
		self:_equip(player, category, id)
		return
	end
	-- items must be bought in order: you need the previous tier first
	local previous = Config[info.List][def.Index - 1]
	if previous and not owned[previous.Id] then
		Notify.Player(player, `Buy the {previous.Name} first.`, "bad")
		return
	end
	if not S.DataService:SpendHoney(player, def.Price) then
		Notify.Player(player, "Not enough honey.", "bad")
		return
	end
	owned[id] = true
	S.DataService:MarkDirty(player, info.Owned)
	Notify.Player(player, `Bought {def.Name}!`, "good")
	self:_equip(player, category, id)
end

function ShopService:_equip(player: Player, category: string, id: string)
	local info = CATEGORY[category]
	local data = S.DataService:Get(player)
	if not info or not data or not data[info.Owned][id] then
		return
	end
	data[info.Equipped] = id
	S.DataService:MarkDirty(player, info.Equipped)
	if category == "Collector" then
		self:GiveTool(player)
	elseif category == "Boots" then
		self:GiveBoots(player)
	else
		-- a smaller bag cannot hold more than its capacity
		local capacity = Config.BackpackById[id].Capacity
		if data.Pollen > capacity then
			data.Pollen = capacity
			S.DataService:MarkDirty(player, "Pollen")
		end
		self:GiveBackpack(player)
	end
end

function ShopService:_buyTreats(player: Player, count: number)
	if typeof(count) ~= "number" then
		return
	end
	count = math.floor(count)
	if count ~= 1 and count ~= 10 and count ~= 100 then
		return
	end
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	if not S.DataService:SpendHoney(player, Config.Levels.TreatPrice * count) then
		Notify.Player(player, "Not enough honey.", "bad")
		return
	end
	data.Treats += count
	S.DataService:MarkDirty(player, "Treats")
	Notify.Player(player, `+{count} Treats`, "good")
end

function ShopService:Init(services)
	S = services
	self.Buy = Net.Event("Buy")
	self.Equip = Net.Event("Equip")
	self.BuyTreats = Net.Event("BuyTreats")
end

function ShopService:Start()
	self.Buy.OnServerEvent:Connect(function(player, category, id)
		if Net.Allow(player, "Buy", 0.25) then
			self:_buy(player, category, id)
		end
	end)
	self.Equip.OnServerEvent:Connect(function(player, category, id)
		if Net.Allow(player, "Equip", 0.25) then
			self:_equip(player, category, id)
		end
	end)
	self.BuyTreats.OnServerEvent:Connect(function(player, count)
		if Net.Allow(player, "BuyTreats", 0.25) then
			self:_buyTreats(player, count)
		end
	end)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			if S.DataService:WaitFor(player, 30) then
				task.wait(0.2)
				self:RefreshVisuals(player)
			end
		end)
		if player.Character then
			task.spawn(function()
				if S.DataService:WaitFor(player, 30) then
					self:RefreshVisuals(player)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return ShopService
