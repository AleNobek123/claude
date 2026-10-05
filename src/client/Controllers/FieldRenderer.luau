--[[
	FieldRenderer
	Resizes flowers locally from the server's tile levels, tints the event field and
	opens field gates on this client when the player meets the requirement (the server
	checks access again on every harvest).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local FieldRenderer = {}

local C
local LEVEL_STEPS = 20
local tiles = {} -- [fieldId] = { [index] = { Parts = { {Part, CFrame, Size} }, Color } }
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
							entry = { Parts = {}, Color = part:GetAttribute("FlowerColor"), Ground = def.Center.Y }
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

-- shrink each flower part and lower it towards the ground in proportion to the level
local function applyLevel(entry, q: number)
	local level = q / LEVEL_STEPS
	local s = 0.3 + 0.7 * level
	for _, p in entry.Parts do
		local height = p.CFrame.Position.Y - entry.Ground
		p.Part.Size = p.Size * s
		p.Part.CFrame = p.CFrame + Vector3.new(0, height * (s - 1), 0)
	end
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
			for _, wall in gate:GetDescendants() do
				if wall:IsA("BasePart") then
					wall.CanCollide = not open
					wall.Transparency = open and 1 or 0.55
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
						applyLevel(entry, buffer.readu8(buf, index - 1))
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
				applyLevel(entry, buffer.readu8(buf, o + 2))
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
