--[[
	MonsterRenderer
	Client-side monster models driven by server move/hit/die messages.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local MonsterRenderer = {}

local C
local folder: Folder
local monsters = {} -- [id] = { Model, Root, Offsets, From, To, Start, Duration, Health, MaxHealth, Bar, Look }

local function fallback(monsterType: string): Model
	local def = Config.Monsters[monsterType]
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * def.Size
	body.Color = monsterType == "Ladybug" and Color3.fromRGB(220, 40, 40) or Color3.fromRGB(120, 200, 70)
	body.Parent = model
	model.PrimaryPart = body
	return model
end

local function build(monsterType: string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folderAssets = assets and assets:FindFirstChild("Monsters")
	local template = folderAssets and folderAssets:FindFirstChild(monsterType)
	local model = template and template:Clone() or fallback(monsterType)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	model.PrimaryPart = root
	local offsets = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			table.insert(offsets, { Part = part, Offset = root.CFrame:ToObjectSpace(part.CFrame) })
		end
	end
	-- health bar (mesh templates are "Grounded": their root sits on the ground)
	local def = Config.Monsters[monsterType]
	local grounded = model:GetAttribute("Grounded") == true
	local height = grounded and model:GetExtentsSize().Y or def.Size * 0.7
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 26)
	gui.StudsOffset = Vector3.new(0, height + 1.2, 0)
	gui.MaxDistance = 90
	gui.Parent = root
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = def.Name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.6)
	back.Size = UDim2.fromScale(1, 0.4)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	model.Parent = folder
	return model, root, offsets, fill, grounded
end

function MonsterRenderer:GetPosition(id: number): Vector3?
	local m = monsters[id]
	return m and m.Position or nil
end

local function positionAt(m, now: number): Vector3
	if m.Duration <= 0 then
		return m.To
	end
	local alpha = math.clamp((now - m.Start) / m.Duration, 0, 1)
	return m.From:Lerp(m.To, alpha)
end

function MonsterRenderer:_spawn(info)
	if monsters[info.Id] then
		monsters[info.Id].Model:Destroy()
	end
	local model, root, offsets, fill, grounded = build(info.Type)
	local def = Config.Monsters[info.Type]
	local from = info.From or info.Pos
	monsters[info.Id] = {
		Type = info.Type,
		Model = model,
		Root = root,
		Offsets = offsets,
		From = from,
		To = info.To or from,
		Start = info.Start or 0,
		Duration = info.Duration or 0,
		Health = info.Health,
		MaxHealth = info.MaxHealth,
		Fill = fill,
		Height = grounded and 0 or def.Size / 2,
		Position = from,
		Look = Vector3.new(0, 0, -1),
	}
	fill.Size = UDim2.fromScale(math.clamp(info.Health / info.MaxHealth, 0, 1), 1)
end

function MonsterRenderer:_onUpdate(payload)
	local op = payload.Op
	if op == "Spawn" then
		self:_spawn(payload)
		return
	end
	local m = monsters[payload.Id]
	if not m then
		return
	end
	if op == "Move" then
		m.From = payload.From
		m.To = payload.To
		m.Start = payload.Start
		m.Duration = payload.Duration
	elseif op == "Hit" then
		m.Health = payload.Health
		m.Fill.Size = UDim2.fromScale(math.clamp(m.Health / m.MaxHealth, 0, 1), 1)
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.new(1, 0.2, 0.2)
		highlight.FillTransparency = 0.3
		highlight.OutlineTransparency = 1
		highlight.Parent = m.Model
		Debris:AddItem(highlight, 0.12)
	elseif op == "Die" or op == "Despawn" then
		monsters[payload.Id] = nil
		if op == "Die" and C.Fx then
			C.Fx:Burst(m.Position, Color3.fromRGB(255, 220, 120), 24)
		end
		local root = m.Root
		for _, entry in m.Offsets do
			TweenService:Create(entry.Part, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
		Debris:AddItem(m.Model, 0.3)
		root.Anchored = true
	elseif op == "Slow" then
		-- tint while slowed
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(150, 220, 255)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 1
		highlight.Parent = m.Model
		Debris:AddItem(highlight, math.max(0.2, payload.Until - Workspace:GetServerTimeNow()))
	end
end

function MonsterRenderer:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "ClientMonsters"
	folder.Parent = Workspace
end

function MonsterRenderer:Start()
	Net.Event("MonsterUpdate").OnClientEvent:Connect(function(payload)
		self:_onUpdate(payload)
	end)
	local ok, list = pcall(function()
		return Net.Function("GetMonsters"):InvokeServer()
	end)
	if ok and list then
		for _, info in list do
			self:_spawn(info)
		end
	end

	local parts, cframes = {}, {}
	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local t = os.clock()
		table.clear(parts)
		table.clear(cframes)
		for id, m in monsters do
			local pos = positionAt(m, now)
			local moved = pos - m.Position
			m.Position = pos
			if moved.Magnitude > 0.01 then
				m.Look = Vector3.new(moved.X, 0, moved.Z).Unit
			end
			local walking = now < m.Start + m.Duration and now > m.Start
			local bob = walking and math.abs(math.sin(t * 10 + id)) * 0.25 or 0
			local cf = CFrame.lookAt(pos, pos + m.Look) * CFrame.new(0, m.Height + bob, 0)
			for _, entry in m.Offsets do
				table.insert(parts, entry.Part)
				table.insert(cframes, cf * entry.Offset)
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return MonsterRenderer
