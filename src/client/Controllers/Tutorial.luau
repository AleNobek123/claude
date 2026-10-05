--[[
	Tutorial
	In-world guidance instead of text walls: a bouncing 3D arrow over the goal, a glowing
	dotted trail on the ground leading to it, and a small floating hint that fades in/out.
	Steps: reach Sunflower Meadow -> collect pollen -> make honey at the hive -> hatch at a nest.
	Progress is saved on the server (TutorialStep).
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

local Tutorial = {}

local C
local UI
local folder: Folder
local arrow: Model?
local dots = {}
local hint: BillboardGui?
local step = 1
local stepStart = { Honey = 0 }
local temporary: { Until: number, Position: Vector3 }? = nil

local DOT_SPACING = 5.5
local MAX_DOTS = 70

function Tutorial:Init(controllers)
	C = controllers
	UI = C.UI
end

local function field()
	return Config.FieldById.Sunflower
end

local function hivePad(): Vector3?
	local index = player:GetAttribute("HiveIndex")
	local map = Workspace:FindFirstChild("Map")
	local hive = index and map and map.Hives:FindFirstChild("Hive_" .. index)
	local pad = hive and hive:FindFirstChild("Pad")
	return pad and pad.Position
end

local function nestPosition(index: number): Vector3
	local map = Workspace:FindFirstChild("Map")
	local nest = map and map:FindFirstChild("Nests") and map.Nests:FindFirstChild("Nest_" .. index)
	return nest and nest:GetPivot().Position or Config.Nests[index].Position
end

function Tutorial:_targetFor(id: string): Vector3?
	if id == "Field" or id == "Collect" then
		return field().Center
	elseif id == "Convert" then
		return hivePad()
	elseif id == "Hatch" then
		return nestPosition(1)
	end
	return nil
end

-- Visuals ----------------------------------------------------------------------------------------

function Tutorial:_arrow(): Model
	if arrow then
		return arrow
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Raw") and assets.Raw:FindFirstChild("Arrow3D")
	if template then
		arrow = template:Clone()
	else
		arrow = Instance.new("Model")
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2.5, 2.5, 2.5)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://1033714" -- classic cone
		mesh.Scale = Vector3.new(2.4, 3, 2.4)
		mesh.Parent = head
		head.Parent = arrow
		arrow.PrimaryPart = head
	end
	for _, part in arrow:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(255, 200, 50)
		end
	end
	arrow:ScaleTo(arrow:GetScale() * 1.6)
	arrow.Parent = folder
	return arrow
end

function Tutorial:_dot(i: number): Part
	local dot = dots[i]
	if not dot then
		dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Cylinder
		dot.Size = Vector3.new(0.2, 1.6, 1.6)
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.fromRGB(255, 214, 90)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CastShadow = false
		dot.Parent = folder
		dots[i] = dot
	end
	return dot
end

function Tutorial:_hint(text: string)
	if hint then
		local old = hint
		hint = nil
		for _, label in old:GetDescendants() do
			if label:IsA("TextLabel") then
				TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif label:IsA("ImageLabel") then
				TweenService:Create(label, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
			elseif label:IsA("Frame") then
				TweenService:Create(label, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.35, function()
			old:Destroy()
		end)
	end
	if not text then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TutorialHint"
	gui.Size = UDim2.fromOffset(320, 54)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local pill = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Colors.Ink, BackgroundTransparency = 1, Parent = gui }, { UI.Round() })
	local icon = UI.Icon("Bee", { Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(44, 44), ImageTransparency = 1, Parent = pill })
	local label = UI.Label({ Text = text, Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -68, 1, -16), TextColor3 = UI.Colors.White, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = pill })
	TweenService:Create(pill, TweenInfo.new(0.4), { BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(icon, TweenInfo.new(0.4), { ImageTransparency = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	UI.Juice.Float(pill, 4, 2)
	hint = gui
end

function Tutorial:_clearVisuals()
	if arrow then
		arrow.Parent = nil
	end
	for _, dot in dots do
		dot.Parent = nil
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local trailPoints = {} -- ground positions, recomputed at 5 Hz
local lastTrail = 0

-- Follow the dirt roads between the hive row and the plaza instead of cutting across the pond
local function route(from: Vector3, to: Vector3): { Vector3 }
	local points = { from }
	local function via(x: number, z: number)
		table.insert(points, Vector3.new(x, from.Y, z))
	end
	if from.Z < -55 and to.Z > -30 then
		if math.abs(from.X) > 20 then
			via(0, -78)
		end
		via(0, -18)
	elseif from.Z > -30 and to.Z < -55 then
		via(0, -18)
		if math.abs(to.X) > 20 then
			via(0, -78)
		end
	end
	table.insert(points, to)
	return points
end

function Tutorial:_updateTrail(from: Vector3, to: Vector3)
	local now = os.clock()
	if now - lastTrail > 0.2 then
		lastTrail = now
		table.clear(trailPoints)
		local exclude = { folder }
		if player.Character then
			table.insert(exclude, player.Character)
		end
		rayParams.FilterDescendantsInstances = exclude
		local points = route(from, to)
		local carry = DOT_SPACING -- distance left until the next dot
		for k = 1, #points - 1 do
			local a, b = points[k], points[k + 1]
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local length = flat.Magnitude
			local d = carry
			while d <= length and #trailPoints < MAX_DOTS do
				local p = a + flat.Unit * d
				local hit = Workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), rayParams)
				table.insert(trailPoints, Vector3.new(p.X, (hit and hit.Position.Y or from.Y - 3) + 0.15, p.Z))
				d += DOT_SPACING
			end
			carry = d - length
		end
	end
	for i = 1, MAX_DOTS do
		local dot = self:_dot(i)
		local p = trailPoints[i]
		if p then
			dot.Parent = folder
			local wave = (math.sin(now * 6 - i * 0.6) + 1) / 2
			local s = 1.2 + wave * 0.8
			dot.Size = Vector3.new(0.2, s, s)
			dot.Transparency = 0.15 + (1 - wave) * 0.45
			dot.CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 2)
		else
			dot.Parent = nil
		end
	end
end

-- Step logic -------------------------------------------------------------------------------------------

function Tutorial:_advance()
	step += 1
	Net.Event("TutorialStep"):FireServer(step)
	C.Sound:Play("LevelUp", { Volume = 0.7 })
	if step > #Config.Tutorial then
		self:_hint(nil)
		self:_clearVisuals()
		UI:Toast("Tutorial complete! Have fun building your empire.", "good")
		return
	end
	self:_beginStep()
end

function Tutorial:_beginStep()
	local data = C.State.Data
	stepStart.Honey = data and data.TotalHoney or 0
	stepStart.Bees = C.State:BeeCount()
	local info = Config.Tutorial[step]
	if info then
		self:_hint(info.Text)
	end
end

function Tutorial:_checkStep(root: BasePart)
	local info = Config.Tutorial[step]
	local data = C.State.Data
	if not info or not data then
		return
	end
	if info.Id == "Field" then
		local f = field()
		local half = f.Tiles * Config.Tiles.Size / 2
		local d = root.Position - f.Center
		if math.abs(d.X) <= half and math.abs(d.Z) <= half then
			self:_advance()
		end
	elseif info.Id == "Collect" then
		local capacity = C.State:Capacity()
		if (data.Pollen or 0) >= math.min(capacity, 150) then
			self:_advance()
		end
	elseif info.Id == "Convert" then
		if (data.TotalHoney or 0) - stepStart.Honey >= 100 then
			self:_advance()
		end
	elseif info.Id == "Hatch" then
		if C.State:BeeCount() > (stepStart.Bees or 1) then
			self:_advance()
		end
	end
end

-- Public: show a temporary trail to a nest (Eggs panel "Find nest")
function Tutorial:Guide(kind: string, index: number)
	if kind == "Nest" then
		temporary = { Until = os.clock() + 25, Position = nestPosition(index) }
	end
end

function Tutorial:Start()
	folder = Instance.new("Folder")
	folder.Name = "TutorialGuide"
	folder.Parent = Workspace

	-- wait for data, then resume at the saved step
	while not C.State.Loaded do
		task.wait(0.2)
	end
	local saved = C.State.Data.Tutorial
	step = saved and saved.Step or 1
	if step <= #Config.Tutorial then
		task.delay(4, function()
			self:_beginStep()
		end)
	end

	Net.Event("HatchResult").OnClientEvent:Connect(function()
		local info = Config.Tutorial[step]
		if info and info.Id == "Hatch" then
			task.delay(5, function()
				if Config.Tutorial[step] and Config.Tutorial[step].Id == "Hatch" then
					self:_advance()
				end
			end)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local goal
		if temporary and os.clock() < temporary.Until then
			goal = temporary.Position
			if (root.Position - goal).Magnitude < 16 then
				temporary = nil
			end
		elseif step <= #Config.Tutorial then
			goal = self:_targetFor(Config.Tutorial[step].Id)
		end
		if not goal then
			self:_clearVisuals()
			return
		end
		local a = self:_arrow()
		a.Parent = folder
		local t = os.clock()
		a:PivotTo(CFrame.new(goal + Vector3.new(0, 12 + math.abs(math.sin(t * 3)) * 2.5, 0)) * CFrame.Angles(0, t * 1.5, 0))
		local near = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(goal.X, 0, goal.Z)).Magnitude < 20
		if near then
			for _, dot in dots do
				dot.Parent = nil
			end
		else
			self:_updateTrail(root.Position, goal)
		end
		acc += dt
		if acc >= 0.3 and step <= #Config.Tutorial then
			acc = 0
			self:_checkStep(root)
		end
	end)
end

return Tutorial
