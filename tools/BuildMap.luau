--[[
	BuildMap v2 (Studio edit-time tool, not shipped with the game)
	Builds a tiered, terrain-based world:
	  - smooth terrain ground, rolling outer hills, a pond, sandy paths and a stone plaza
	  - fields on plateaus: Sunflower (ground), Clover / Rose (tier 1), Bluebell / Royal (tier 2),
	    Crystal (tier 3), each reached by a ramp guarded by a natural stone gate
	  - 8 hives, physical Golden Nests, shop stands, holographic leaderboards
	  - low-poly decor (trees, pines, bushes, rocks, mushrooms, fences, lanterns)
	  - warm, dreamy stylized lighting
	Meshes come from ReplicatedStorage.Assets.Raw (IntegrateAssets / IntegrateWorld).
	For a fresh place without meshes, run BuildMapV1 first (it creates placeholder assets).

	Usage: require(thisModule)({ Map = true, Terrain = true })
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local HexGrid = require(Shared.HexGrid)
local Assets = require(Shared.Assets)

local WOOD = Color3.fromRGB(150, 104, 62)
local DARK_WOOD = Color3.fromRGB(104, 70, 40)
local HONEY = Color3.fromRGB(255, 196, 46)
local SPAWN = Vector3.new(0, 0, 0)
local Terrain = Workspace.Terrain

-- Plateaus: field id -> plateau (a ramp climbs from RampFrom to the plateau edge)
local PLATEAUS = {
	Clover = { Size = 110, RampFrom = Vector3.new(-58, 0, 140), Edge = Vector3.new(-95, 14, 140) },
	Rose = { Size = 110, RampFrom = Vector3.new(58, 0, 140), Edge = Vector3.new(95, 14, 140) },
	Bluebell = { Size = 110, RampFrom = Vector3.new(-150, 14, 193), Edge = Vector3.new(-150, 30, 245) },
	Crystal = { Size = 110, RampFrom = Vector3.new(150, 14, 193), Edge = Vector3.new(150, 40, 255) },
	Royal = { Size = 92, RampFrom = Vector3.new(0, 0, 196), Edge = Vector3.new(0, 22, 254) },
}

-- Helpers ------------------------------------------------------------------------------------

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

local function raw(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local rawFolder = assets and assets:FindFirstChild("Raw")
	return rawFolder and rawFolder:FindFirstChild(name)
end

local function rawMesh(name: string)
	local model = raw(name)
	if not model or not model.PrimaryPart then
		return nil
	end
	local mesh = model:FindFirstChildWhichIsA("MeshPart")
	if not mesh then
		return nil
	end
	return mesh, model.PrimaryPart.CFrame:ToObjectSpace(mesh.CFrame)
end

-- clone a raw template, scale it and stand its root on `cf`
local function place(name: string, cf: CFrame, scale: number?, parent: Instance)
	local template = raw(name)
	if not template then
		return nil
	end
	local model = template:Clone()
	if scale and scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model:PivotTo(cf)
	model.Parent = parent
	return model
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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Terrain }

local function groundY(x: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rayParams)
	return hit and hit.Position.Y or nil
end

-- Lighting: warm, low-contrast, saturated, soft shadows ---------------------------------------------

local function effect(className: string)
	local e = Lighting:FindFirstChildOfClass(className)
	if not e then
		e = Instance.new(className)
		e.Parent = Lighting
	end
	return e
end

local function buildLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 15.2
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.1
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ShadowSoftness = 0.55
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(112, 96, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 145, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 205)
	Lighting.ColorShift_Bottom = Color3.fromRGB(120, 140, 170)

	local atmosphere = effect("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(255, 232, 200)
	atmosphere.Decay = Color3.fromRGB(255, 186, 140)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.5

	local bloom = effect("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 26
	bloom.Threshold = 1.25

	local rays = effect("SunRaysEffect")
	rays.Intensity = 0.09
	rays.Spread = 0.75

	local cc = effect("ColorCorrectionEffect")
	cc.Brightness = 0.03
	cc.Contrast = -0.04
	cc.Saturation = 0.28
	cc.TintColor = Color3.fromRGB(255, 247, 235)

	local dof = effect("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 90
	dof.InFocusRadius = 110
	dof.NearIntensity = 0

	local sky = effect("Sky")
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 8
	sky.StarCount = 0
	sky.CelestialBodiesShown = true

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 252, 245)
	clouds.Parent = Terrain
end

-- Terrain -------------------------------------------------------------------------------------------------

-- Smooth terrain renders a full voxel's surface 2 studs above the filled volume, so every fill is biased down.
local SURFACE_BIAS = Vector3.new(0, -2, 0)

local function fillBlock(cf: CFrame, size: Vector3, material: Enum.Material)
	Terrain:FillBlock(cf + SURFACE_BIAS, size, material)
end

local function fillBall(center: Vector3, radius: number, material: Enum.Material)
	Terrain:FillBall(center + SURFACE_BIAS, radius, material)
end

local function fillCylinder(cf: CFrame, height: number, radius: number, material: Enum.Material)
	Terrain:FillCylinder(cf + SURFACE_BIAS, height, radius, material)
end

local function ramp(from: Vector3, to: Vector3, width: number, material: Enum.Material)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local dir = flat.Unit
	local rise = to.Y - from.Y
	local slope = (flat + Vector3.new(0, rise, 0)).Unit
	local slabLength = math.sqrt(length * length + rise * rise) + 6
	local center = (from + to) / 2
	local cf = CFrame.lookAt(center, center + slope) * CFrame.new(0, -3, 0)
	-- solid support under the slope, then the walkable slab on top
	local steps = math.ceil(length / 4)
	for i = 0, steps do
		local t = i / steps
		local p = from + dir * (length * t)
		local h = rise * t
		if h > 1 then
			fillBlock(CFrame.new(p.X, from.Y + h / 2 - 3, p.Z), Vector3.new(width, h, 4), Enum.Material.Rock)
		end
	end
	fillBlock(cf, Vector3.new(width, 6, slabLength), material)
end

local function plateau(center: Vector3, size: number, top: number)
	fillBlock(CFrame.new(center.X, top / 2 - 6, center.Z), Vector3.new(size, top + 12, size), Enum.Material.Rock)
	fillBlock(CFrame.new(center.X, top * 0.35, center.Z), Vector3.new(size + 2, math.max(4, top * 0.3), size + 2), Enum.Material.Slate)
	fillBlock(CFrame.new(center.X, top - 2, center.Z), Vector3.new(size - 2, 4, size - 2), Enum.Material.Grass)
end

local function buildTerrain()
	Terrain:Clear()
	Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(116, 190, 82))
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 140, 128))
	Terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(132, 124, 116))
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(200, 164, 112))
	Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(236, 214, 160))
	Terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(232, 214, 176))
	Terrain.WaterColor = Color3.fromRGB(80, 190, 220)
	Terrain.WaterTransparency = 0.6
	Terrain.WaterWaveSize = 0.08
	Terrain.WaterReflectance = 0.3

	-- ground (top surface at y = 0)
	fillBlock(CFrame.new(0, -10, 130), Vector3.new(820, 20, 820), Enum.Material.Grass)
	-- rolling outer hills and rocky outcrops
	local rng = Random.new(7)
	for i = 1, 46 do
		local angle = (i / 46) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = rng:NextNumber(330, 390)
		fillBall(Vector3.new(math.cos(angle) * r, rng:NextNumber(-20, -6), 130 + math.sin(angle) * r), rng:NextNumber(34, 62), Enum.Material.Grass)
	end
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(300, 360)
		fillBall(Vector3.new(math.cos(angle) * r, rng:NextNumber(10, 30), 130 + math.sin(angle) * r), rng:NextNumber(14, 26), Enum.Material.Rock)
	end
	-- plateaus, then ramps (ramps last so they cut cleanly into the cliffs)
	for fieldId, info in PLATEAUS do
		local def = Config.FieldById[fieldId]
		plateau(def.Center, info.Size, def.Center.Y)
	end
	for _, info in PLATEAUS do
		ramp(info.RampFrom, info.Edge, 22, Enum.Material.Ground)
	end
	-- spawn plaza and paths
	fillCylinder(CFrame.new(0, -1, 0), 2.2, 26, Enum.Material.Pavement)
	local paths = {
		{ Vector3.new(0, 0, 18), Vector3.new(0, 0, 86) }, -- spawn -> meadow
		{ Vector3.new(0, 0, -18), Vector3.new(0, 0, -78) }, -- spawn -> hives
		{ Vector3.new(-215, 0, -78), Vector3.new(215, 0, -78) }, -- hive walk
		{ Vector3.new(-22, 0, 22), Vector3.new(-58, 0, 140) }, -- to Clover ramp
		{ Vector3.new(22, 0, 22), Vector3.new(58, 0, 140) }, -- to Rose ramp
		{ Vector3.new(0, 0, 152), Vector3.new(0, 0, 198) }, -- meadow -> Royal ramp
		{ Vector3.new(-44, 0, -32), Vector3.new(44, 0, -32) }, -- nest row
	}
	for _, seg in paths do
		local a, b = seg[1], seg[2]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		fillBlock(CFrame.lookAt(Vector3.new(mid.X, -1, mid.Z), Vector3.new(b.X, -1, b.Z)), Vector3.new(11, 2, len + 6), Enum.Material.Ground)
	end
	-- decoration-free beds (grass blades would poke through flowers, pads and nests)
	for _, def in Config.Fields do
		local size = def.Tiles * Config.Tiles.Size + 4
		fillBlock(CFrame.new(def.Center.X, def.Center.Y - 1, def.Center.Z), Vector3.new(size, 2, size), Enum.Material.Ground)
	end
	fillBlock(CFrame.new(0, -1, -88), Vector3.new(Config.Hive.Count * 50 + 20, 2, 30), Enum.Material.Pavement)
	for _, nest in Config.Nests do
		fillCylinder(CFrame.new(nest.Position.X, -1, nest.Position.Z), 2, 12, Enum.Material.Pavement)
	end
	for _, pos in { Vector3.new(-56, 0, 28), Vector3.new(56, 0, 28), Vector3.new(-80, 0, -36), Vector3.new(80, 0, -36), Vector3.new(-100, 0, 14), Vector3.new(100, 0, 14) } do
		fillCylinder(CFrame.new(pos.X, -1, pos.Z), 2, 10, Enum.Material.Pavement)
	end
	-- pond with a sandy rim
	fillCylinder(CFrame.new(-82, -0.9, 40), 1.8, 20, Enum.Material.Sand)
	fillCylinder(CFrame.new(-82, -1, 40), 6, 16, Enum.Material.Air)
	fillCylinder(CFrame.new(-82, -3.4, 40), 2.4, 16, Enum.Material.Water)
end

-- Fields --------------------------------------------------------------------------------------------------

local FLOWER_MESH = { White = "Flower_Daisy", Red = "Flower_Rose", Blue = "Flower_Bell" }
local CENTER_COLORS = {
	White = Color3.fromRGB(255, 196, 40),
	Red = Color3.fromRGB(255, 225, 120),
	Blue = Color3.fromRGB(255, 255, 240),
}

local function buildField(def, fieldsFolder)
	local f = Instance.new("Folder")
	f.Name = def.Id
	f.Parent = fieldsFolder
	local size = def.Tiles * Config.Tiles.Size
	local c = def.Center
	part({
		Name = "Base",
		Size = Vector3.new(size + 3, 1, size + 3),
		CFrame = CFrame.new(c + Vector3.new(0, -0.42, 0)),
		Color = def.Ground,
		Material = Enum.Material.Grass,
		Parent = f,
	})
	local flowers = Instance.new("Folder")
	flowers.Name = "Flowers"
	flowers.Parent = f
	local rng = Random.new(def.Index * 1000)
	local offset = (def.Tiles + 1) / 2
	local petalMeshes = {}
	for colorName, meshName in FLOWER_MESH do
		local mesh, rel = rawMesh(meshName)
		petalMeshes[colorName] = mesh and { Mesh = mesh, Rel = rel } or nil
	end
	local centerMesh, centerRel = rawMesh("Flower_Center")
	for gx = 1, def.Tiles do
		for gz = 1, def.Tiles do
			local index = (gx - 1) * def.Tiles + gz
			local colorName = def.Flowers[rng:NextInteger(1, #def.Flowers)]
			local pos = c + Vector3.new((gx - offset) * Config.Tiles.Size, 0, (gz - offset) * Config.Tiles.Size)
			local jitter = Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
			local yaw = rng:NextNumber(0, math.pi * 2)
			local petal = petalMeshes[colorName]
			if petal and centerMesh then
				local scale = 3.1 / math.max(petal.Mesh.Size.X, petal.Mesh.Size.Z)
				local base = CFrame.new(pos + jitter + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, yaw, 0)
				local petals = petal.Mesh:Clone()
				petals.Name = "P" .. index
				petals.Size = petal.Mesh.Size * scale
				petals.CFrame = base * CFrame.new(petal.Rel.Position * scale) * petal.Rel.Rotation
				petals.Color = Config.FlowerColors[colorName]
				petals.Material = Enum.Material.SmoothPlastic
				petals.Anchored = true
				petals.CanCollide = false
				petals.CanQuery = false
				petals.CastShadow = false
				petals:SetAttribute("Tile", index)
				petals:SetAttribute("FlowerColor", colorName)
				petals:SetAttribute("Petal", true)
				petals.Parent = flowers
				local center = centerMesh:Clone()
				center.Name = "C" .. index
				center.Size = centerMesh.Size * scale
				center.CFrame = base * CFrame.new(0, 0.12 * scale, 0) * CFrame.new(centerRel.Position * scale) * centerRel.Rotation
				center.Color = CENTER_COLORS[colorName]
				center.Anchored = true
				center.CanCollide = false
				center.CanQuery = false
				center.CastShadow = false
				center:SetAttribute("Tile", index)
				center:SetAttribute("FlowerColor", colorName)
				center.Parent = flowers
			else
				part({ Name = "P" .. index, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 3.1, 3.1), CFrame = CFrame.new(pos + jitter + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw, math.pi / 2), Color = Config.FlowerColors[colorName], CanCollide = false, CastShadow = false, Attributes = { Tile = index, FlowerColor = colorName, Petal = true }, Parent = flowers })
				part({ Name = "C" .. index, Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(pos + jitter + Vector3.new(0, 1.15, 0)), Color = CENTER_COLORS[colorName], CanCollide = false, CastShadow = false, Attributes = { Tile = index, FlowerColor = colorName }, Parent = flowers })
			end
		end
	end
	-- name sign beside the entrance
	local info = PLATEAUS[def.Id]
	local entry = info and info.Edge or Vector3.new(c.X, c.Y, c.Z - size / 2 - 4)
	local inward = (c - entry) * Vector3.new(1, 0, 1)
	inward = inward.Magnitude > 0 and inward.Unit or Vector3.new(0, 0, 1)
	local signPos = entry + inward * 10 + inward:Cross(Vector3.yAxis) * 16
	local sign = place("Signpost", CFrame.lookAt(Vector3.new(signPos.X, c.Y, signPos.Z), Vector3.new(signPos.X, c.Y, signPos.Z) - inward), 1.6, f)
	local board = sign and sign:FindFirstChild("Board")
	local holder = board or part({ Name = "Sign", Size = Vector3.new(6, 2.4, 0.4), CFrame = CFrame.new(signPos + Vector3.new(0, 5, 0)), Color = WOOD, Parent = f })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(14, 0, 3.6, 0)
	gui.StudsOffset = Vector3.new(0, board and 5.2 or 2.5, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = holder
	label(gui, "Name", def.Name, { Size = UDim2.fromScale(1, 0.6), TextColor3 = Color3.fromRGB(255, 240, 200) })
	label(gui, "Info", `{def.Multiplier}x pollen`, { Size = UDim2.fromScale(1, 0.38), Position = UDim2.fromScale(0, 0.62) })
end

-- Stone gates on the plateau edges ------------------------------------------------------------------------

local function buildGate(def, gatesFolder)
	local info = PLATEAUS[def.Id]
	if not info or not (def.BeesRequired > 0 or def.VIP) then
		return
	end
	local gate = Instance.new("Folder")
	gate.Name = def.Id
	gate.Parent = gatesFolder
	local outward = ((info.RampFrom - info.Edge) * Vector3.new(1, 0, 1)).Unit
	local pos = info.Edge + outward * 1.5
	local model = place("Gate", CFrame.lookAt(pos, pos + outward), 1.12, gate)
	local top
	if model then
		model.Name = "StoneGate"
		local boulders = model:FindFirstChild("Boulders")
		if boulders then
			boulders:SetAttribute("Barrier", true)
		end
		top = model:FindFirstChild("Arch") or model.PrimaryPart
	else
		top = part({ Name = "Boulders", Size = Vector3.new(22, 14, 3), CFrame = CFrame.lookAt(pos + Vector3.new(0, 7, 0), pos + Vector3.new(0, 7, 0) + outward), Color = Color3.fromRGB(140, 132, 122), Material = Enum.Material.Slate, Attributes = { Barrier = true }, Parent = gate })
	end
	local badge = Instance.new("BillboardGui")
	badge.Name = "Badge"
	badge.Size = UDim2.new(9, 0, 3.4, 0)
	badge.StudsOffset = Vector3.new(0, 5, 0)
	badge.MaxDistance = 160
	badge.LightInfluence = 0
	badge.Parent = top
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(40, 28, 18)
	back.BackgroundTransparency = 0.35
	back.Parent = badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = def.VIP and Assets.Icons.Star or Assets.Icons.Bee
	icon.Size = UDim2.fromScale(0.34, 0.9)
	icon.Position = UDim2.fromScale(0.06, 0.05)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = back
	label(back, "Requirement", def.VIP and "VIP" or tostring(def.BeesRequired), { Size = UDim2.fromScale(0.52, 0.8), Position = UDim2.fromScale(0.42, 0.1) })
end

-- Hives -----------------------------------------------------------------------------------------------------

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
	part({ Name = "Base", Size = Vector3.new(30, 1, 16), CFrame = CFrame.new(x, 0.5, z + 2), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks, Parent = model })

	local hiveMesh = raw("Hive")
	local cellMesh, cellRel = rawMesh("HexCell")
	local facing = function(pos: Vector3)
		return CFrame.lookAt(pos, pos + forward)
	end
	if hiveMesh then
		local body = hiveMesh:Clone()
		body.Name = "Body"
		body:PivotTo(facing(Vector3.new(x, 20, z - 0.45)))
		local boxCF, boxSize = body:GetBoundingBox()
		body:PivotTo(body:GetPivot() + Vector3.new(0, 1 - (boxCF.Position.Y - boxSize.Y / 2), 0))
		centerY = body:GetPivot().Position.Y
		for _, p in body:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = p.Name ~= "Honey" and p.Name ~= "Root"
				p.CanQuery = p.Name ~= "Root"
			end
		end
		local frameMesh = body:FindFirstChild("Frame")
		if frameMesh then
			frameMesh.Parent = model
		end
		body.Parent = model
		model.PrimaryPart = frameMesh or body.PrimaryPart
	else
		model.PrimaryPart = part({ Name = "Frame", Size = Vector3.new(27, 25, 2), CFrame = CFrame.new(x, centerY, z - 1.3), Color = Color3.fromRGB(196, 128, 40), Material = Enum.Material.Wood, Parent = model })
	end

	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = model
	local grid = HexGrid.Get(Config.Hive.Radius)
	local diameter = Config.Hive.CellSize * math.sqrt(3) * 0.92
	for slot = 1, grid.count do
		local offset = HexGrid.ToOffset(Config.Hive.Radius, slot, Config.Hive.CellSize)
		local pos = Vector3.new(x - offset.X, centerY + offset.Y, z)
		if cellMesh then
			local scale = (Config.Hive.CellSize * 0.95 * 2) / math.max(cellMesh.Size.X, cellMesh.Size.Y, cellMesh.Size.Z)
			local cell = cellMesh:Clone()
			cell.Name = "Cell_" .. slot
			cell.Size = cellMesh.Size * scale
			cell.CFrame = facing(pos) * cellRel.Rotation
			cell.Color = Color3.fromRGB(92, 64, 36)
			cell.Transparency = 0.35
			cell.Material = Enum.Material.SmoothPlastic
			cell.Anchored = true
			cell.CanCollide = false
			cell:SetAttribute("Slot", slot)
			cell.Parent = cells
		else
			part({ Name = "Cell_" .. slot, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, diameter, diameter), CFrame = CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(92, 64, 36), Transparency = 0.35, Attributes = { Slot = slot }, Parent = cells })
		end
	end

	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 10, 10),
		CFrame = CFrame.new(x, 0.25, z + 12) * CFrame.Angles(0, 0, math.pi / 2),
		Color = HONEY,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
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
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110))
	sparkle.LightEmission = 0.8
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1, 1.8)
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(15, 15)
	sparkle.Rate = 4
	sparkle.EmissionDirection = Enum.NormalId.Right
	sparkle.Parent = pad

	local sign = part({ Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(x, centerY + (hiveMesh and 24 or 19), z), Transparency = 1, CanCollide = false, Parent = model })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(16, 0, 4, 0)
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	billboard.Parent = sign
	label(billboard, "Owner", "Free Hive", { Size = UDim2.fromScale(1, 0.55), TextColor3 = Color3.fromRGB(255, 230, 150) })
	label(billboard, "Score", "Walk up to claim", { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.58) })
end

-- Golden Nests ----------------------------------------------------------------------------------------------

local function buildNests(nestsFolder)
	local eggTemplate = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Eggs")
		and ReplicatedStorage.Assets.Eggs:FindFirstChild("Egg")
	for index, nest in Config.Nests do
		local egg = Config.Eggs[nest.Egg]
		local y = groundY(nest.Position.X, nest.Position.Z) or 0
		local pos = Vector3.new(nest.Position.X, y, nest.Position.Z)
		local scale = index == 3 and 1.05 or 0.92
		local model = place("Nest", CFrame.lookAt(pos, Vector3.new(SPAWN.X, y, SPAWN.Z)), scale, nestsFolder)
		local eggHeight
		if model then
			eggHeight = (model:GetAttribute("EggHeight") or 3) * scale
		else
			model = Instance.new("Model")
			model.PrimaryPart = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 12, 12), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(235, 225, 205), Parent = model })
			model.Parent = nestsFolder
			eggHeight = 3
		end
		model.Name = "Nest_" .. index
		model:SetAttribute("NestIndex", index)
		model:SetAttribute("Egg", nest.Egg)
		model:SetAttribute("EggHeight", eggHeight)

		local anchor = part({ Name = "CardAnchor", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos + Vector3.new(0, eggHeight + 2, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Hatch"
		prompt.ObjectText = egg.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("NestIndex", index)
		prompt.Parent = anchor

		if eggTemplate then
			local display = eggTemplate:Clone()
			display.Name = "DisplayEgg"
			local _, s = display:GetBoundingBox()
			display:ScaleTo(display:GetScale() * (3.8 / s.Y))
			display:PivotTo(CFrame.new(pos + Vector3.new(0, eggHeight - 0.4, 0)))
			for _, p in display:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					if p.Name == "Spots" then
						p.Color = egg.Color:Lerp(Color3.fromRGB(255, 180, 40), 0.6)
					elseif p.Name ~= "Root" then
						p.Color = egg.Color
						p.Material = nest.Egg == "Royal" and Enum.Material.Foil or Enum.Material.SmoothPlastic
					end
				end
			end
			display.Parent = model
		end
		local glow = Instance.new("PointLight")
		glow.Color = egg.Color:Lerp(Color3.fromRGB(255, 200, 80), 0.5)
		glow.Range = 16
		glow.Brightness = 1.2
		glow.Parent = anchor
		local motes = Instance.new("ParticleEmitter")
		motes.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120))
		motes.LightEmission = 0.9
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		motes.Lifetime = NumberRange.new(1.5, 2.5)
		motes.Speed = NumberRange.new(0.5, 1.5)
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.Rate = 5
		motes.Parent = anchor
	end
end

-- Shops & boards -------------------------------------------------------------------------------------------------

local function buildStand(name: string, position: Vector3, color: Color3, title: string, panel: string, arg: string?, shopsFolder)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = shopsFolder
	local facing = CFrame.lookAt(position, Vector3.new(SPAWN.X, position.Y, SPAWN.Z))
	local counter = part({ Name = "Counter", Size = Vector3.new(12, 3.5, 4), CFrame = facing * CFrame.new(0, 1.75, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = model })
	for _, sx in { -5.5, 5.5 } do
		part({ Name = "Pole", Size = Vector3.new(0.8, 9, 0.8), CFrame = facing * CFrame.new(sx, 4.5, 1.5), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = model })
	end
	part({ Name = "Roof", Size = Vector3.new(14, 1, 7), CFrame = facing * CFrame.new(0, 9.4, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = color, Parent = model })
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
end

local function buildBoard(name: string, title: string, position: Vector3, boardsFolder)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = boardsFolder
	local facing = CFrame.lookAt(position, Vector3.new(SPAWN.X, position.Y, SPAWN.Z))
	local screen = part({ Name = "Screen", Size = Vector3.new(16, 14, 0.4), CFrame = facing * CFrame.new(0, 10, 0), Color = Color3.fromRGB(60, 200, 255), Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false, Parent = model })
	for _, data in {
		{ CFrame.new(0, 7.3, 0), Vector3.new(17, 0.6, 0.6) },
		{ CFrame.new(0, -7.3, 0), Vector3.new(17, 0.6, 0.6) },
		{ CFrame.new(8.3, 0, 0), Vector3.new(0.6, 15.2, 0.6) },
		{ CFrame.new(-8.3, 0, 0), Vector3.new(0.6, 15.2, 0.6) },
	} do
		part({ Name = "Edge", Size = data[2], CFrame = screen.CFrame * data[1], Color = Color3.fromRGB(90, 230, 255), Material = Enum.Material.Neon, Parent = model })
	end
	part({ Name = "Stand", Size = Vector3.new(2, 3, 2), CFrame = facing * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(40, 50, 70), Material = Enum.Material.Metal, Parent = model })
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
		label(rows, "Row" .. i, i .. ".  ---", { LayoutOrder = i, Size = UDim2.fromScale(1, 0.09), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = i <= 3 and Color3.fromRGB(255, 230, 140) or Color3.new(1, 1, 1) })
	end
	model.PrimaryPart = screen
end

-- Decor ------------------------------------------------------------------------------------------------------------

local function blocked(pos: Vector3): boolean
	if math.abs(pos.X) < 75 and pos.Z < 60 and pos.Z > -60 then
		return true -- spawn plaza, shops, nests
	end
	if pos.Z > -125 and pos.Z < -30 and math.abs(pos.X) < 225 then
		return true -- hives
	end
	for _, def in Config.Fields do
		local half = def.Tiles * Config.Tiles.Size / 2 + 8
		if math.abs(pos.X - def.Center.X) < half and math.abs(pos.Z - def.Center.Z) < half then
			return true
		end
	end
	for _, info in PLATEAUS do
		local a, b = info.RampFrom, info.Edge
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local ap = Vector3.new(pos.X - a.X, 0, pos.Z - a.Z)
		local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
		local closest = Vector3.new(a.X, 0, a.Z) + ab * t
		if (Vector3.new(pos.X, 0, pos.Z) - closest).Magnitude < 16 then
			return true -- ramps
		end
	end
	if math.abs(pos.X) < 10 and pos.Z > 0 and pos.Z < 200 then
		return true -- main path
	end
	if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(-82, 0, 40)).Magnitude < 22 then
		return true -- pond
	end
	return false
end

local function scatter(decor: Instance, name: string, count: number, minScale: number, maxScale: number, rng: Random, area)
	if not raw(name) then
		return
	end
	local placed, attempts = 0, 0
	while placed < count and attempts < count * 25 do
		attempts += 1
		local pos = Vector3.new(rng:NextNumber(area[1], area[2]), 0, rng:NextNumber(area[3], area[4]))
		if not blocked(pos) then
			local y = groundY(pos.X, pos.Z)
			if y and y > -2 then
				place(name, CFrame.new(pos.X, y - 0.2, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(minScale, maxScale), decor)
				placed += 1
			end
		end
	end
end

local function buildDecor(decor: Instance)
	local rng = Random.new(42)
	local area = { -300, 300, -170, 420 }
	scatter(decor, "Tree", 34, 0.8, 1.3, rng, area)
	scatter(decor, "Pine", 30, 0.9, 1.6, rng, area)
	scatter(decor, "Bush", 60, 0.7, 1.4, rng, area)
	scatter(decor, "Rock_A", 26, 0.8, 2.2, rng, area)
	scatter(decor, "Rock_B", 26, 0.8, 1.8, rng, area)
	scatter(decor, "Mushroom", 30, 0.8, 1.6, rng, area)
	-- big boulders at cliff feet
	for fieldId, info in PLATEAUS do
		local def = Config.FieldById[fieldId]
		for k = 1, 8 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local half = info.Size / 2 + 3
			local pos = def.Center + Vector3.new(math.cos(angle) * half, 0, math.sin(angle) * half)
			if not blocked(pos) then
				local y = groundY(pos.X, pos.Z) or 0
				if y < def.Center.Y - 4 then
					place(k % 2 == 0 and "Rock_A" or "Rock_B", CFrame.new(pos.X, y - 0.5, pos.Z) * CFrame.Angles(0, angle, 0), rng:NextNumber(1.6, 3), decor)
				end
			end
		end
	end
	-- fences and lanterns along the main path
	for z = 24, 80, 9 do
		for _, side in { -1, 1 } do
			place("Fence", CFrame.new(side * 9, 0, z) * CFrame.Angles(0, math.pi / 2, 0), 1, decor)
		end
	end
	for _, spot in {
		Vector3.new(-10, 0, 22), Vector3.new(10, 0, 22), Vector3.new(-10, 0, 60), Vector3.new(10, 0, 60),
		Vector3.new(-10, 0, -20), Vector3.new(10, 0, -20), Vector3.new(-48, 0, -26), Vector3.new(48, 0, -26),
		Vector3.new(-22, 0, 24), Vector3.new(22, 0, 24),
	} do
		place("Lantern", CFrame.lookAt(spot, Vector3.new(0, 0, spot.Z)), 1.2, decor)
	end
	for i = 1, Config.Hive.Count + 1 do
		local x = -(Config.Hive.Count * 50) / 2 + (i - 1) * 50
		place("Lantern", CFrame.new(x, 0, -72), 1.2, decor)
	end
	-- ramp signposts
	for fieldId, info in PLATEAUS do
		local def = Config.FieldById[fieldId]
		local side = ((info.Edge - info.RampFrom) * Vector3.new(1, 0, 1)).Unit:Cross(Vector3.yAxis)
		local pos = info.RampFrom + side * 15
		local y = groundY(pos.X, pos.Z) or info.RampFrom.Y
		local post = place("Signpost", CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(SPAWN.X, y, SPAWN.Z)), 1.5, decor)
		local board = post and post:FindFirstChild("Board")
		if board then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(12, 0, 3, 0)
			gui.StudsOffset = Vector3.new(0, 4.5, 0)
			gui.MaxDistance = 120
			gui.LightInfluence = 0
			gui.Parent = board
			label(gui, "Field", def.Name, { Size = UDim2.fromScale(1, 0.6), TextColor3 = Color3.fromRGB(255, 240, 200) })
			label(gui, "Req", def.VIP and "VIP pass" or (def.BeesRequired .. " bees"), { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.6) })
		end
	end
end

-- Entry --------------------------------------------------------------------------------------------------------

return function(options)
	options = options or { Map = true, Terrain = true }
	buildLighting()
	Workspace.StreamingEnabled = false
	if options.Terrain then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
		buildTerrain()
	end
	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.CFrame = CFrame.new(SPAWN + Vector3.new(0, 0.6, 0))
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Color = HONEY
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Transparency = 0.2
		spawn.Neutral = true
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
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
			buildField(def, fields)
			buildGate(def, gates)
		end
		local hives = folder("Hives", map)
		for i = 1, Config.Hive.Count do
			buildHive(i, hives)
		end
		buildNests(folder("Nests", map))
		local shops = folder("Shops", map)
		buildStand("CollectorShop", Vector3.new(-56, 0, 28), Color3.fromRGB(120, 200, 110), "Tools", "Shop", "Collector", shops)
		buildStand("BackpackShop", Vector3.new(56, 0, 28), Color3.fromRGB(110, 170, 240), "Bags", "Shop", "Backpack", shops)
		buildStand("RobuxStore", Vector3.new(-80, 0, -36), Color3.fromRGB(110, 230, 140), "Store", "Store", nil, shops)
		buildStand("EggInfo", Vector3.new(80, 0, -36), Color3.fromRGB(245, 235, 210), "Egg Odds", "Eggs", nil, shops)
		local boards = folder("Leaderboards", map)
		buildBoard("HoneyBoard", "Top Honey Producers Today", Vector3.new(-100, 0, 14), boards)
		buildBoard("SwarmBoard", "Rarest Swarm Score", Vector3.new(100, 0, 14), boards)
		buildDecor(folder("Decor", map))
	end
	return "Map v2 built"
end
