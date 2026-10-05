--[[
	BuildMap (Studio edit-time tool, not shipped with the game)
	Builds Workspace.Map (fields, hives, shops, leaderboards, gates, decor), lighting,
	and placeholder models in ReplicatedStorage.Assets. Placeholders are only created when
	missing, so imported Blender meshes are never overwritten.

	Usage from the command bar / a plugin:
		require(thisModule)({ Map = true, Assets = true })
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local HexGrid = require(Shared.HexGrid)

local WOOD = Color3.fromRGB(150, 104, 62)
local DARK_WOOD = Color3.fromRGB(104, 70, 40)
local HONEY = Color3.fromRGB(255, 196, 46)
local SPAWN = Vector3.new(0, 0, 0)

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Attributes" then
			p[key] = value
		end
	end
	for key, value in props.Attributes or {} do
		p:SetAttribute(key, value)
	end
	p.Parent = props.Parent
	return p
end

local function folder(name: string, parent: Instance)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function label(parent: Instance, name: string, text: string, props)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	for key, value in props or {} do
		l[key] = value
	end
	l.Parent = parent
	return l
end

-- Environment -----------------------------------------------------------------------------

local function buildEnvironment()
	Workspace.StreamingEnabled = false
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate.Color = Color3.fromRGB(106, 168, 74)
		baseplate.Material = Enum.Material.Grass
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") then
				child:Destroy()
			end
		end
	end
	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.CFrame = CFrame.new(SPAWN + Vector3.new(0, 0.5, 0))
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.Color = HONEY
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Neutral = true
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 120)
	Lighting.Ambient = Color3.fromRGB(90, 80, 70)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(255, 236, 200)
	atmosphere.Decay = Color3.fromRGB(255, 210, 150)
	atmosphere.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.TintColor = Color3.fromRGB(255, 250, 240)
	cc.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

-- Fields -------------------------------------------------------------------------------------

local CENTER_COLORS = {
	White = Color3.fromRGB(255, 196, 40),
	Red = Color3.fromRGB(255, 225, 120),
	Blue = Color3.fromRGB(255, 255, 240),
}

local function buildField(def, fieldsFolder, gatesFolder)
	local f = Instance.new("Folder")
	f.Name = def.Id
	f.Parent = fieldsFolder
	local size = def.Tiles * Config.Tiles.Size
	local c = def.Center
	part({
		Name = "Base",
		Size = Vector3.new(size + 2, 1, size + 2),
		CFrame = CFrame.new(c + Vector3.new(0, -0.45, 0)),
		Color = def.Ground,
		Material = Enum.Material.Grass,
		Parent = f,
	})
	-- wooden border rails
	for i, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local along = side.X ~= 0 and Vector3.new(1, 1, size + 3) or Vector3.new(size + 3, 1, 1)
		part({
			Name = "Rail" .. i,
			Size = along,
			CFrame = CFrame.new(c + side * (size / 2 + 1.5) + Vector3.new(0, 0.5, 0)),
			Color = WOOD,
			Material = Enum.Material.Wood,
			Parent = f,
		})
	end

	local flowers = Instance.new("Folder")
	flowers.Name = "Flowers"
	flowers.Parent = f
	local rng = Random.new(def.Index * 1000)
	local offset = (def.Tiles + 1) / 2
	for gx = 1, def.Tiles do
		for gz = 1, def.Tiles do
			local index = (gx - 1) * def.Tiles + gz
			local colorName = def.Flowers[rng:NextInteger(1, #def.Flowers)]
			local pos = c + Vector3.new((gx - offset) * Config.Tiles.Size, 0, (gz - offset) * Config.Tiles.Size)
			local jitter = Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
			part({
				Name = "P" .. index,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.35, 3.1, 3.1),
				CFrame = CFrame.new(pos + jitter + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.pi / 2),
				Color = Config.FlowerColors[colorName],
				CanCollide = false,
				CastShadow = false,
				Attributes = { Tile = index, FlowerColor = colorName, Petal = true },
				Parent = flowers,
			})
			part({
				Name = "C" .. index,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.1, 1.1, 1.1),
				CFrame = CFrame.new(pos + jitter + Vector3.new(0, 1.15, 0)),
				Color = CENTER_COLORS[colorName],
				CanCollide = false,
				CastShadow = false,
				Attributes = { Tile = index, FlowerColor = colorName },
				Parent = flowers,
			})
		end
	end

	-- sign facing the spawn
	local edge = c + Vector3.new(0, 0, -(size / 2 + 4))
	local post = part({
		Name = "SignPost",
		Size = Vector3.new(1, 7, 1),
		CFrame = CFrame.new(edge + Vector3.new(0, 3.5, 0)),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = f,
	})
	local board = part({
		Name = "Sign",
		Size = Vector3.new(14, 5, 0.6),
		CFrame = CFrame.lookAt(edge + Vector3.new(0, 7.5, 0), Vector3.new(SPAWN.X, edge.Y + 7.5, SPAWN.Z)),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = f,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, "Name", def.Name, { Size = UDim2.fromScale(1, 0.5), TextColor3 = Color3.fromRGB(255, 240, 200) })
	local req = def.VIP and "VIP Gamepass" or (def.BeesRequired > 0 and `{def.BeesRequired} bees required` or "Open to all")
	label(gui, "Info", `{def.Multiplier}x pollen • {req}`, { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.55) })
	post.Name = "SignPost"

	-- gate walls for locked fields (collision toggled per client)
	if def.BeesRequired > 0 or def.VIP then
		local gate = Instance.new("Folder")
		gate.Name = def.Id
		gate.Parent = gatesFolder
		local tint = def.VIP and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(120, 200, 255)
		for i, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local dims = side.X ~= 0 and Vector3.new(0.6, 12, size + 4) or Vector3.new(size + 4, 12, 0.6)
			part({
				Name = "Wall" .. i,
				Size = dims,
				CFrame = CFrame.new(c + side * (size / 2 + 2.4) + Vector3.new(0, 6, 0)),
				Color = tint,
				Material = Enum.Material.ForceField,
				Transparency = 0.55,
				CastShadow = false,
				Parent = gate,
			})
		end
	end
end

-- Hives ---------------------------------------------------------------------------------------------

local function buildHive(index: number, hivesFolder)
	local count = Config.Hive.Count
	local x = -((count - 1) * 50) / 2 + (index - 1) * 50
	local z = -95
	local forward = Vector3.new(0, 0, 1)
	local model = Instance.new("Model")
	model.Name = "Hive_" .. index
	model:SetAttribute("Index", index)
	model:SetAttribute("Forward", forward)
	model.Parent = hivesFolder

	local centerY = 13.5
	part({
		Name = "Base",
		Size = Vector3.new(30, 1, 16),
		CFrame = CFrame.new(x, 0.5, z + 2),
		Color = DARK_WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	local frame = part({
		Name = "Frame",
		Size = Vector3.new(27, 25, 2),
		CFrame = CFrame.new(x, centerY, z - 1.3),
		Color = Color3.fromRGB(196, 128, 40),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Name = "Roof",
		ClassName = "WedgePart",
		Size = Vector3.new(29, 4, 5),
		CFrame = CFrame.new(x, centerY + 14.5, z - 0.8),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Post",
			Size = Vector3.new(2, 27, 2),
			CFrame = CFrame.new(x + side * 14, centerY, z - 0.5),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	model.PrimaryPart = frame

	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = model
	local grid = HexGrid.Get(Config.Hive.Radius)
	local diameter = Config.Hive.CellSize * math.sqrt(3) * 0.92
	for slot = 1, grid.count do
		local offset = HexGrid.ToOffset(Config.Hive.Radius, slot, Config.Hive.CellSize)
		local pos = Vector3.new(x - offset.X, centerY + offset.Y, z)
		part({
			Name = "Cell_" .. slot,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, diameter, diameter),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0),
			Color = Color3.fromRGB(92, 64, 36),
			Transparency = 0.35,
			Attributes = { Slot = slot },
			Parent = cells,
		})
	end

	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 10, 10),
		CFrame = CFrame.new(x, 1.1, z + 12) * CFrame.Angles(0, 0, math.pi / 2),
		Color = HONEY,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		Parent = model,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Make Honey"
	prompt.ObjectText = "Hive " .. index
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(x, centerY + 19, z),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(16, 0, 4, 0)
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	billboard.Parent = sign
	label(billboard, "Owner", "Free Hive", { Size = UDim2.fromScale(1, 0.55), TextColor3 = Color3.fromRGB(255, 230, 150) })
	label(billboard, "Score", "Walk up to claim", { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.58) })
end

-- Shops ------------------------------------------------------------------------------------------------

local function buildStand(name: string, position: Vector3, color: Color3, title: string, panel: string, arg: string?, shopsFolder)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = shopsFolder
	local facing = CFrame.lookAt(position, Vector3.new(SPAWN.X, position.Y, SPAWN.Z))
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(12, 3.5, 4),
		CFrame = facing * CFrame.new(0, 1.75, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, sx in { -5.5, 5.5 } do
		part({
			Name = "Pole",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = facing * CFrame.new(sx, 4.5, 1.5),
			Color = DARK_WOOD,
			Parent = model,
		})
	end
	local roof = part({
		Name = "Roof",
		Size = Vector3.new(14, 1, 7),
		CFrame = facing * CFrame.new(0, 9.4, 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = color,
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = counter
	label(gui, "Title", title, { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 240, 200) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenPanel", panel)
	if arg then
		prompt:SetAttribute("OpenArg", arg)
	end
	prompt.Parent = counter
	model.PrimaryPart = counter
	roof.Name = "Roof"
end

-- Leaderboards -------------------------------------------------------------------------------------------

local function buildBoard(name: string, title: string, position: Vector3, boardsFolder)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = boardsFolder
	local facing = CFrame.lookAt(position, Vector3.new(SPAWN.X, position.Y, SPAWN.Z))
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(16, 14, 0.4),
		CFrame = facing * CFrame.new(0, 10, 0),
		Color = Color3.fromRGB(60, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		Parent = model,
	})
	for _, data in {
		{ CFrame.new(0, 7.3, 0), Vector3.new(17, 0.6, 0.6) },
		{ CFrame.new(0, -7.3, 0), Vector3.new(17, 0.6, 0.6) },
		{ CFrame.new(8.3, 0, 0), Vector3.new(0.6, 15.2, 0.6) },
		{ CFrame.new(-8.3, 0, 0), Vector3.new(0.6, 15.2, 0.6) },
	} do
		part({
			Name = "Edge",
			Size = data[2],
			CFrame = screen.CFrame * data[1],
			Color = Color3.fromRGB(90, 230, 255),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	part({
		Name = "Stand",
		Size = Vector3.new(2, 3, 2),
		CFrame = facing * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(40, 50, 70),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = screen
	label(gui, "Title", title, { Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 0.02), TextColor3 = Color3.fromRGB(255, 230, 120) })
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.05, 0.16)
	rows.Size = UDim2.fromScale(0.9, 0.82)
	rows.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = rows
	for i = 1, 10 do
		label(rows, "Row" .. i, i .. ".  ---", {
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 0.09),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = i <= 3 and Color3.fromRGB(255, 230, 140) or Color3.new(1, 1, 1),
		})
	end
	model.PrimaryPart = screen
end

-- Decor ------------------------------------------------------------------------------------------------------

local function buildDecor(decorFolder)
	local rng = Random.new(42)
	local placed = 0
	local attempts = 0
	while placed < 40 and attempts < 400 do
		attempts += 1
		local pos = Vector3.new(rng:NextNumber(-260, 260), 0, rng:NextNumber(-160, 340))
		local clear = pos.Magnitude > 40
		for _, def in Config.Fields do
			local half = def.Tiles * Config.Tiles.Size / 2 + 14
			if math.abs(pos.X - def.Center.X) < half and math.abs(pos.Z - def.Center.Z) < half then
				clear = false
			end
		end
		if pos.Z > -125 and pos.Z < -70 and math.abs(pos.X) < 215 then
			clear = false -- hive row
		end
		if math.abs(pos.Z) < 60 and math.abs(pos.X) < 120 then
			clear = false -- spawn plaza and shops
		end
		if clear then
			placed += 1
			local height = rng:NextNumber(8, 14)
			local tree = Instance.new("Model")
			tree.Name = "Tree"
			tree.Parent = decorFolder
			part({
				Name = "Trunk",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 2, 2),
				CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = DARK_WOOD,
				Material = Enum.Material.Wood,
				Parent = tree,
			})
			local leaves = rng:NextNumber(8, 12)
			part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(leaves, leaves, leaves),
				CFrame = CFrame.new(pos + Vector3.new(0, height + leaves * 0.3, 0)),
				Color = Color3.fromRGB(rng:NextInteger(60, 90), rng:NextInteger(140, 175), rng:NextInteger(55, 80)),
				Material = Enum.Material.Grass,
				Parent = tree,
			})
		end
	end
	-- path from spawn to the meadow and to the hives
	part({ Name = "PathNorth", Size = Vector3.new(10, 0.2, 80), CFrame = CFrame.new(0, 0.1, 46), Color = Color3.fromRGB(220, 190, 130), Material = Enum.Material.Sand, Parent = decorFolder })
	part({ Name = "PathSouth", Size = Vector3.new(10, 0.2, 70), CFrame = CFrame.new(0, 0.1, -42), Color = Color3.fromRGB(220, 190, 130), Material = Enum.Material.Sand, Parent = decorFolder })
	part({ Name = "HiveWalk", Size = Vector3.new(400, 0.2, 10), CFrame = CFrame.new(0, 0.1, -76), Color = Color3.fromRGB(220, 190, 130), Material = Enum.Material.Sand, Parent = decorFolder })
end

-- Placeholder assets ----------------------------------------------------------------------------------------

local function weldAll(model: Model, root: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
			p.Anchored = false
		end
	end
	root.Anchored = false
end

local function sphereMesh(p: BasePart, scale: Vector3)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale
	mesh.Parent = p
end

local function buildBee(parent: Instance)
	if parent:FindFirstChild("Bee") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Bee"
	local origin = CFrame.new(0, 50, 0)
	local body = part({ Name = "Body", Size = Vector3.new(1, 1, 1), CFrame = origin, Color = HONEY, CanCollide = false, Attributes = { Role = "Body" }, Parent = model })
	sphereMesh(body, Vector3.new(1, 0.95, 1.45))
	for i, z in { -0.05, 0.3 } do
		part({
			Name = "Stripe" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.16, 0.98, 0.98),
			CFrame = origin * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
			Color = Color3.fromRGB(40, 30, 20),
			CanCollide = false,
			Attributes = { Role = "Stripe" },
			Parent = model,
		})
	end
	for i, x in { -0.22, 0.22 } do
		part({ Name = "Eye" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), CFrame = origin * CFrame.new(x, 0.15, -0.62), Color = Color3.fromRGB(20, 20, 25), CanCollide = false, Attributes = { Role = "Eye" }, Parent = model })
		part({ Name = "Antenna" .. i, Size = Vector3.new(0.06, 0.5, 0.06), CFrame = origin * CFrame.new(x * 0.8, 0.6, -0.55) * CFrame.Angles(math.rad(-25), 0, math.rad(x > 0 and -15 or 15)), Color = Color3.fromRGB(30, 25, 20), CanCollide = false, Attributes = { Role = "Detail" }, Parent = model })
	end
	part({ Name = "Stinger", Size = Vector3.new(0.12, 0.12, 0.35), CFrame = origin * CFrame.new(0, -0.05, 0.82), Color = Color3.fromRGB(30, 25, 20), CanCollide = false, Attributes = { Role = "Detail" }, Parent = model })
	for _, side in { { "WingL", -1 }, { "WingR", 1 } } do
		local wing = part({
			Name = side[1],
			Size = Vector3.new(0.9, 0.05, 0.55),
			CFrame = origin * CFrame.new(side[2] * 0.55, 0.5, 0.05) * CFrame.Angles(0, 0, math.rad(side[2] * -20)),
			Color = Color3.fromRGB(225, 240, 255),
			Transparency = 0.35,
			Material = Enum.Material.Glass,
			CanCollide = false,
			Attributes = { Role = side[1] },
			Parent = model,
		})
		sphereMesh(wing, Vector3.new(1, 1, 1))
	end
	local crown = part({ Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.55, 0.55), CFrame = origin * CFrame.new(0, 0.62, -0.25) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 210, 50), Material = Enum.Material.Neon, CanCollide = false, Attributes = { Role = "Crown" }, Parent = model })
	crown.Name = "Crown"
	part({ Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.9, 0.9), CFrame = origin * CFrame.new(0, 0.95, -0.1) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 250, 200), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, Attributes = { Role = "Halo" }, Parent = model })
	model.PrimaryPart = body
	model.Parent = parent
end

local function buildMonsters(parent: Instance)
	local function monster(name: string, size: number, bodyColor: Color3, extras)
		if parent:FindFirstChild(name) then
			return
		end
		local model = Instance.new("Model")
		model.Name = name
		local origin = CFrame.new(0, 60, 0)
		local body = part({ Name = "Body", Size = Vector3.new(size, size * 0.7, size * 1.2), CFrame = origin, Color = bodyColor, CanCollide = false, Parent = model })
		sphereMesh(body, Vector3.new(1, 1, 1))
		extras(model, origin, size)
		model.PrimaryPart = body
		model.Parent = parent
	end
	local function legs(model, origin, size, color)
		for i = -1, 1 do
			for _, side in { -1, 1 } do
				part({ Name = "Leg", Size = Vector3.new(size * 0.6, size * 0.08, size * 0.08), CFrame = origin * CFrame.new(side * size * 0.45, -size * 0.25, i * size * 0.3) * CFrame.Angles(0, 0, math.rad(side * -30)), Color = color, CanCollide = false, Parent = model })
			end
		end
	end
	monster("Aphid", Config.Monsters.Aphid.Size, Color3.fromRGB(130, 210, 80), function(model, origin, size)
		legs(model, origin, size, Color3.fromRGB(70, 120, 40))
		for _, x in { -0.18, 0.18 } do
			part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.18, CFrame = origin * CFrame.new(x * size, size * 0.12, -size * 0.55), Color = Color3.fromRGB(200, 30, 30), CanCollide = false, Parent = model })
		end
	end)
	monster("Ladybug", Config.Monsters.Ladybug.Size, Color3.fromRGB(220, 40, 40), function(model, origin, size)
		legs(model, origin, size, Color3.fromRGB(20, 20, 20))
		part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.42, CFrame = origin * CFrame.new(0, 0, -size * 0.6), Color = Color3.fromRGB(25, 25, 25), CanCollide = false, Parent = model })
		for _, spot in { { -0.22, 0.1 }, { 0.22, 0.1 }, { -0.2, -0.25 }, { 0.2, -0.25 }, { 0, 0.32 } } do
			part({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.2, CFrame = origin * CFrame.new(spot[1] * size, size * 0.3, spot[2] * size), Color = Color3.fromRGB(20, 20, 20), CanCollide = false, Parent = model })
		end
	end)
	monster("AphidQueen", Config.Monsters.AphidQueen.Size, Color3.fromRGB(150, 110, 210), function(model, origin, size)
		legs(model, origin, size, Color3.fromRGB(80, 50, 120))
		part({ Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.25, size * 0.4, size * 0.4), CFrame = origin * CFrame.new(0, size * 0.45, -size * 0.3) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 210, 50), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	end)
end

local function buildCollectors(parent: Instance)
	local function tool(name: string, build)
		if parent:FindFirstChild(name) then
			return
		end
		local t = Instance.new("Tool")
		t.Name = name
		t.CanBeDropped = false
		local handle = part({ Name = "Handle", Size = Vector3.new(0.3, 3.2, 0.3), CFrame = CFrame.new(0, 70, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = t })
		build(t, handle)
		t.Grip = CFrame.new(0, -0.8, 0)
		weldAll(t :: any, handle)
		t.Parent = parent
	end
	tool("Scoop", function(t, handle)
		local head = part({ Name = "Head", Size = Vector3.new(1.4, 0.3, 1.2), CFrame = handle.CFrame * CFrame.new(0, 1.7, -0.3) * CFrame.Angles(math.rad(-30), 0, 0), CanCollide = false, Attributes = { Tint = true }, Parent = t })
		head.Name = "Head"
	end)
	tool("Rake", function(t, handle)
		part({ Name = "Bar", Size = Vector3.new(2.2, 0.25, 0.3), CFrame = handle.CFrame * CFrame.new(0, 1.7, 0), CanCollide = false, Attributes = { Tint = true }, Parent = t })
		for i = -2, 2 do
			part({ Name = "Tine", Size = Vector3.new(0.12, 0.12, 0.6), CFrame = handle.CFrame * CFrame.new(i * 0.5, 1.7, -0.4), CanCollide = false, Attributes = { Tint = true }, Parent = t })
		end
	end)
	tool("Vacuum", function(t, handle)
		part({ Name = "Tank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 1, 1), CFrame = handle.CFrame * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = false, Attributes = { Tint = true }, Parent = t })
		part({ Name = "Nozzle", Size = Vector3.new(0.9, 0.3, 0.9), CFrame = handle.CFrame * CFrame.new(0, 2.2, -0.2), Color = Color3.fromRGB(60, 60, 70), CanCollide = false, Parent = t })
	end)
	tool("Wand", function(t, handle)
		local tip = part({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = handle.CFrame * CFrame.new(0, 1.9, 0), Material = Enum.Material.Neon, CanCollide = false, Attributes = { Tint = true }, Parent = t })
		local light = Instance.new("PointLight")
		light.Range = 6
		light.Parent = tip
	end)
end

local function buildBackpacks(parent: Instance)
	local function pack(name: string, build)
		if parent:FindFirstChild(name) then
			return
		end
		local model = Instance.new("Model")
		model.Name = name
		local main = build(model)
		model.PrimaryPart = main
		model.Parent = parent
	end
	pack("Pouch", function(model)
		local main = part({ Name = "Main", Size = Vector3.new(1.6, 1.8, 0.9), CFrame = CFrame.new(0, 80, 0), CanCollide = false, Attributes = { Tint = true }, Parent = model })
		sphereMesh(main, Vector3.new(1, 1, 1))
		part({ Name = "Flap", Size = Vector3.new(1.3, 0.5, 0.95), CFrame = main.CFrame * CFrame.new(0, 0.6, 0), Color = DARK_WOOD, CanCollide = false, Parent = model })
		return main
	end)
	pack("Canister", function(model)
		local main = part({ Name = "Main", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 1.3, 1.3), CFrame = CFrame.new(0, 80, 0) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, Attributes = { Tint = true }, Parent = model })
		part({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.4, 1.4), CFrame = main.CFrame * CFrame.new(1.2, 0, 0), Color = Color3.fromRGB(80, 80, 90), Material = Enum.Material.Metal, CanCollide = false, Parent = model })
		part({ Name = "Honey", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 1.1, 1.1), CFrame = main.CFrame * CFrame.new(-0.35, 0, 0), Color = HONEY, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, Parent = model })
		return main
	end)
	pack("Tank", function(model)
		local main = part({ Name = "Main", Size = Vector3.new(1.9, 2.2, 0.6), CFrame = CFrame.new(0, 80, 0), Color = Color3.fromRGB(80, 80, 90), Material = Enum.Material.Metal, CanCollide = false, Parent = model })
		for _, x in { -0.5, 0.5 } do
			part({ Name = "Cylinder", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 0.9, 0.9), CFrame = main.CFrame * CFrame.new(x, 0, 0.5) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = false, Attributes = { Tint = true }, Parent = model })
		end
		return main
	end)
end

local function buildAssets()
	local assets = folder("Assets", ReplicatedStorage)
	buildBee(folder("Bees", assets))
	buildMonsters(folder("Monsters", assets))
	buildCollectors(folder("Collectors", assets))
	buildBackpacks(folder("Backpacks", assets))
end

-- Entry ---------------------------------------------------------------------------------------------------

return function(options)
	options = options or { Map = true, Assets = true }
	buildEnvironment()
	if options.Map then
		local old = Workspace:FindFirstChild("Map")
		if old then
			old:Destroy()
		end
		local map = Instance.new("Folder")
		map.Name = "Map"
		map.Parent = Workspace
		local fields = folder("Fields", map)
		local gates = folder("Gates", map)
		for _, def in Config.Fields do
			buildField(def, fields, gates)
		end
		local hives = folder("Hives", map)
		for i = 1, Config.Hive.Count do
			buildHive(i, hives)
		end
		local shops = folder("Shops", map)
		buildStand("CollectorShop", Vector3.new(-55, 0, 25), Color3.fromRGB(120, 200, 110), "Collectors", "Shop", "Collector", shops)
		buildStand("BackpackShop", Vector3.new(55, 0, 25), Color3.fromRGB(110, 170, 240), "Backpacks", "Shop", "Backpack", shops)
		buildStand("EggShop", Vector3.new(32, 0, -45), Color3.fromRGB(245, 235, 210), "Egg Shop", "Eggs", nil, shops)
		buildStand("RobuxStore", Vector3.new(-32, 0, -45), Color3.fromRGB(110, 230, 140), "Store", "Store", nil, shops)
		local boards = folder("Leaderboards", map)
		buildBoard("HoneyBoard", "Top Honey Producers Today", Vector3.new(-95, 0, 12), boards)
		buildBoard("SwarmBoard", "Rarest Swarm Score", Vector3.new(95, 0, 12), boards)
		buildDecor(folder("Decor", map))
	end
	if options.Assets then
		buildAssets()
	end
	return "Map built"
end
