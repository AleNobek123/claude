--[[
	FieldRenderer
	Flowers follow the server's tile levels with smooth motion: harvested flowers dip and
	wobble, then regrow gradually. Also tints the event field, exposes nearby flowers for
	harvest particles, and opens the stone gates on this client once you qualify
	(the server re-checks access on every harvest).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local FieldRenderer = {}

local C
local LEVEL_STEPS = 20
local tiles = {} -- [fieldId] = { [index] = entry }
local animating = {} -- [entry] = true
local gatesOpen = {} -- [fieldId] = boolean
local GOLD = Color3.fromRGB(255, 205, 60)

local function collect()
	local map = Workspace:WaitForChild("Map", 30)
	local fieldsFolder = map and map:WaitForChild("Fields", 10)
	if not fieldsFolder then
		return
	end
	for _, def in Config.Fields do
		local folder = fieldsFolder:FindFirstChild(def.Id)
		local flowers = folder and folder:FindFirstChild("Flowers")
		local byTile = {}
		if flowers then
			for _, part in flowers:GetDescendants() do
				if part:IsA("BasePart") then
					local index = part:GetAttribute("Tile")
					if index then
						local entry = byTile[index]
						if not entry then
							entry = {
								Parts = {},
								Color = part:GetAttribute("FlowerColor"),
								Ground = def.Center.Y,
								Scale = 1,
								Target = 1,
								Wobble = 0,
								Position = Vector3.new(part.Position.X, def.Center.Y, part.Position.Z),
							}
							byTile[index] = entry
						end
						table.insert(entry.Parts, {
							Part = part,
							CFrame = part.CFrame,
							Size = part.Size,
							Color = part.Color,
							Petal = part:GetAttribute("Petal") == true,
						})
					end
				end
			end
		end
		tiles[def.Id] = byTile
	end
end

local function levelScale(q: number): number
	return 0.3 + 0.7 * (q / LEVEL_STEPS)
end

local function setTarget(entry, q: number)
	local target = levelScale(q)
	if target < entry.Target - 0.01 then
		entry.Wobble = 1 -- harvested: dip and wobble
	end
	entry.Target = target
	animating[entry] = true
end

local function applyEntry(entry, t: number)
	local s = entry.Scale
	local tilt = entry.Wobble > 0 and math.sin(t * 28) * 0.35 * entry.Wobble or 0
	for _, p in entry.Parts do
		local height = p.CFrame.Position.Y - entry.Ground
		p.Part.Size = p.Size * s
		p.Part.CFrame = (p.CFrame + Vector3.new(0, height * (s - 1), 0)) * CFrame.Angles(tilt, 0, tilt * 0.6)
	end
end

-- Flowers near a point (for harvest particles): returns { Position, Color }
function FieldRenderer:FlowersNear(position: Vector3, radius: number, max: number)
	local out = {}
	for _, byTile in tiles do
		for _, entry in byTile do
			local d = entry.Position - position
			if d.X * d.X + d.Z * d.Z <= radius * radius then
				table.insert(out, { Position = entry.Parts[1] and entry.Parts[1].Part.Position or entry.Position, Color = Config.FlowerColors[entry.Color] or Color3.new(1, 1, 1) })
				if #out >= max then
					return out
				end
			end
		end
	end
	return out
end

function FieldRenderer:_tint()
	local eventField = Workspace:GetAttribute("EventField")
	local golden = Workspace:GetAttribute("EventType") == "GoldenBloom"
	for fieldId, byTile in tiles do
		local gold = golden and fieldId == eventField
		for _, entry in byTile do
			for _, p in entry.Parts do
				if p.Petal then
					p.Part.Color = gold and GOLD or p.Color
					p.Part.Material = gold and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
			end
		end
	end
end

-- Stone gates: the boulders sink into the ground when the gate opens for you
function FieldRenderer:_gates()
	local map = Workspace:FindFirstChild("Map")
	local gates = map and map:FindFirstChild("Gates")
	if not gates or not C.State.Data then
		return
	end
	local bees = C.State:BeeCount()
	local eventField = Workspace:GetAttribute("EventField")
	for _, def in Config.Fields do
		local gate = gates:FindFirstChild(def.Id)
		if gate then
			local open
			if def.Id == eventField then
				open = true
			elseif def.VIP then
				open = player:GetAttribute("VIP") == true
			else
				open = bees >= def.BeesRequired
			end
			if gatesOpen[def.Id] ~= open then
				local first = gatesOpen[def.Id] == nil
				gatesOpen[def.Id] = open
				for _, part in gate:GetDescendants() do
					if part:IsA("BasePart") and (part.Name == "Boulders" or part:GetAttribute("Barrier")) then
						local home = part:GetAttribute("HomeCFrame")
						if not home then
							home = part.CFrame
							part:SetAttribute("HomeCFrame", home)
						end
						local goal = open and (home - Vector3.new(0, part.Size.Y + 2, 0)) or home
						part.CanCollide = not open
						if first then
							part.CFrame = goal
							part.Transparency = open and 1 or 0
						else
							TweenService:Create(part, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
							TweenService:Create(part, TweenInfo.new(1.4), { Transparency = open and 1 or 0 }):Play()
							if open then
								C.Sound:Play("Rumble", { At = part.Position })
							end
						end
					end
				end
				local label = gate:FindFirstChild("Requirement", true)
				if label and label:IsA("TextLabel") then
					label.TextColor3 = open and Color3.fromRGB(140, 255, 140) or Color3.new(1, 1, 1)
				end
				if open and not first and C.UI then
					C.UI:Toast(`{def.Name} unlocked!`, "rare")
				end
			end
		end
	end
end

function FieldRenderer:Init(controllers)
	C = controllers
end

function FieldRenderer:Start()
	collect()

	local ok, states = pcall(function()
		return Net.Function("GetFieldStates"):InvokeServer()
	end)
	if ok and states then
		for fieldId, buf in states do
			local byTile = tiles[fieldId]
			if byTile then
				for index, entry in byTile do
					if index - 1 < buffer.len(buf) then
						local s = levelScale(buffer.readu8(buf, index - 1))
						entry.Scale, entry.Target = s, s
						applyEntry(entry, 0)
					end
				end
			end
		end
	end

	Net.Event("FieldUpdate").OnClientEvent:Connect(function(fieldId, buf)
		local byTile = tiles[fieldId]
		if not byTile then
			return
		end
		for o = 0, buffer.len(buf) - 3, 3 do
			local entry = byTile[buffer.readu16(buf, o)]
			if entry then
				setTarget(entry, buffer.readu8(buf, o + 2))
			end
		end
	end)

	-- smooth motion: dip fast, regrow slowly, wobble decays
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for entry in animating do
			local diff = entry.Target - entry.Scale
			local speed = diff < 0 and 10 or 1.6
			entry.Scale += diff * math.min(1, dt * speed)
			entry.Wobble = math.max(0, entry.Wobble - dt * 2.2)
			applyEntry(entry, t)
			if math.abs(diff) < 0.003 and entry.Wobble <= 0 then
				entry.Scale = entry.Target
				applyEntry(entry, t)
				animating[entry] = nil
			end
		end
	end)

	Workspace:GetAttributeChangedSignal("EventField"):Connect(function()
		self:_tint()
		self:_gates()
	end)
	Workspace:GetAttributeChangedSignal("EventType"):Connect(function()
		self:_tint()
	end)
	player:GetAttributeChangedSignal("VIP"):Connect(function()
		self:_gates()
	end)
	C.State:OnChange({ "Bees" }, function()
		self:_gates()
	end)
	self:_tint()
	self:_gates()
end

return FieldRenderer
