--[[
	HoneyFx
	Physical honey conversion: while you convert, glowing honey spheres fly one by one from
	your backpack into your hive cells along a curved path and pop into the comb.
	Bee deposits (server "HoneyOrb") send an orb from that bee into its own cell, visible to all.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local HoneyFx = {}

local C
local folder: Folder
local orbs = {} -- active orbs: { Part, From, Control, To, Start, Duration, Cell }
local ORB_EVERY = 0.12
local MAX_ORBS = 40

local function hive(index: number?)
	local map = Workspace:FindFirstChild("Map")
	return index and map and map.Hives:FindFirstChild("Hive_" .. index)
end

local function cellOf(hiveModel: Instance, slot: number): BasePart?
	local cells = hiveModel and hiveModel:FindFirstChild("Cells")
	return cells and cells:FindFirstChild("Cell_" .. slot)
end

local function newOrb(): Part
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.9, 0.9, 0.9)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(255, 186, 30)
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	if not (C.Settings and C.Settings:Low()) then
		local trail = Instance.new("Trail")
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.3, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.3, 0)
		a1.Parent = orb
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.25
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 150, 20))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.LightEmission = 0.8
		trail.Parent = orb
	end
	orb.Parent = folder
	return orb
end

-- Launch an orb along a quadratic bezier from `from` to the cell
function HoneyFx:Launch(from: Vector3, cell: BasePart, duration: number?)
	if #orbs >= MAX_ORBS then
		return
	end
	local to = cell.Position
	local mid = (from + to) / 2 + Vector3.new(math.random(-4, 4), 8 + (to - from).Magnitude * 0.15, math.random(-4, 4))
	table.insert(orbs, {
		Part = newOrb(),
		From = from,
		Control = mid,
		To = to,
		Start = os.clock(),
		Duration = duration or 0.55,
		Cell = cell,
	})
end

local function arrive(entry)
	entry.Part:Destroy()
	local cell = entry.Cell
	if cell and cell.Parent then
		-- the comb flashes gold and bulges briefly
		local original = cell:GetAttribute("FxColor") or cell.Color
		cell:SetAttribute("FxColor", original)
		cell.Color = Color3.fromRGB(255, 215, 80)
		local size = cell.Size
		cell.Size = size * 1.12
		task.delay(0.12, function()
			if cell.Parent then
				cell.Size = size
				cell.Color = cell:GetAttribute("FxColor") or original
				cell:SetAttribute("FxColor", nil)
			end
		end)
		if C.Fx then
			C.Fx:Burst(cell.Position - Vector3.new(0, 1, 0), Color3.fromRGB(255, 205, 60), 6)
		end
	end
	C.Sound:Play("Pop", { Volume = 0.6, Vary = 0.35 })
end

function HoneyFx:_step()
	local now = os.clock()
	for i = #orbs, 1, -1 do
		local entry = orbs[i]
		local t = math.clamp((now - entry.Start) / entry.Duration, 0, 1)
		local eased = t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
		local a = entry.From:Lerp(entry.Control, eased)
		local b = entry.Control:Lerp(entry.To, eased)
		local pos = a:Lerp(b, eased)
		local s = 0.9 + math.sin(t * math.pi) * 0.5
		entry.Part.Size = Vector3.new(s, s, s)
		entry.Part.CFrame = CFrame.new(pos)
		if t >= 1 then
			table.remove(orbs, i)
			arrive(entry)
		end
	end
end

-- Stream orbs from the backpack while converting
function HoneyFx:_stream()
	local last = 0
	RunService.Heartbeat:Connect(function()
		if not player:GetAttribute("Converting") then
			return
		end
		local now = os.clock()
		if now - last < ORB_EVERY then
			return
		end
		last = now
		local character = player.Character
		local pack = character and character:FindFirstChild("BeeBackpack")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hiveModel = hive(player:GetAttribute("HiveIndex"))
		if not hiveModel or not root then
			return
		end
		local data = C.State.Data
		if not data or (data.Pollen or 0) <= 0 then
			return
		end
		local unlocked = math.min(data.HiveSlots, 37)
		local cell = cellOf(hiveModel, math.random(1, unlocked))
		if cell then
			local from = pack and pack:GetPivot().Position or root.Position + Vector3.new(0, 1, 0)
			self:Launch(from, cell, 0.5 + math.random() * 0.2)
		end
	end)
end

function HoneyFx:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "HoneyOrbs"
	folder.Parent = Workspace
end

function HoneyFx:Start()
	RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	self:_stream()
	Net.Event("Fx").OnClientEvent:Connect(function(kind, payload)
		if kind ~= "HoneyOrb" then
			return
		end
		local hiveModel = hive(payload.Hive)
		local cell = hiveModel and cellOf(hiveModel, payload.Slot)
		local beePos = C.BeeRenderer and C.BeeRenderer:GetBeePosition(payload.Hive, payload.Slot)
		local camera = Workspace.CurrentCamera
		if cell and beePos and camera and (camera.CFrame.Position - cell.Position).Magnitude < 150 then
			self:Launch(beePos, cell, 0.35)
		end
	end)
end

return HoneyFx
