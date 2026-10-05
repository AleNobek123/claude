--[[
	IntegrateAssets (Studio edit-time tool)
	Turns the model imported from Blender (BeeTycoon_Assets.fbx) into the game's asset
	templates in ReplicatedStorage.Assets:

	  Bees.Bee, Monsters.{Aphid, Ladybug, AphidQueen}, Collectors.{Scoop, Rake, Vacuum, Wand},
	  Backpacks.{Pouch, Canister, Tank} and Raw.{Hive, HexCell, Flower_*, Tree} for the map builder.

	It normalizes scale (Bee_Body is 1.45 studs long) and orientation (bee halo = up,
	bee eyes = front = -Z), whatever axis convention the importer used.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function findImport(): Model?
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child:FindFirstChild("Bee_Body", true) then
			return child
		end
	end
	return nil
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

local function prep(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

local function rootPart(cf: CFrame, size: Vector3?): Part
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Transparency = 1
	root.Size = size or Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = cf
	prep(root)
	root:SetAttribute("Role", "Root")
	return root
end

return function()
	local import = findImport()
	if not import then
		return "No imported model with Bee_Body found in Workspace"
	end
	local log = {}
	local function get(name: string): MeshPart
		local part = import:FindFirstChild(name, true)
		assert(part and part:IsA("BasePart"), "missing mesh " .. name)
		return part
	end

	-- 1. scale: Bee_Body must be 1.45 studs long
	local body = get("Bee_Body")
	local longest = math.max(body.Size.X, body.Size.Y, body.Size.Z)
	local factor = 1.45 / longest
	if math.abs(factor - 1) > 0.01 then
		import:ScaleTo(import:GetScale() * factor)
		table.insert(log, string.format("scaled import by %.3f", factor))
	end

	-- 2. orientation: halo above the body = up, eyes = front (-Z)
	local up = (get("Bee_Halo").Position - body.Position).Unit
	local front = get("Bee_Eyes").Position - body.Position
	front = (front - up * front:Dot(up)).Unit
	local right = front:Cross(up)
	local measured = CFrame.fromMatrix(Vector3.zero, right, up, -front) -- -Z = front
	local fix = measured:Inverse()
	if not fix:FuzzyEq(CFrame.identity, 1e-3) then
		local pivot = import:GetPivot()
		for _, part in import:GetDescendants() do
			if part:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(part.CFrame)
				part.CFrame = pivot * (fix * rel)
			end
		end
		table.insert(log, "re-oriented import")
	end
	for _, part in import:GetDescendants() do
		if part:IsA("BasePart") then
			prep(part)
		end
	end

	local assets = folder("Assets", ReplicatedStorage)

	-- builds a template model from named meshes; `roles` maps mesh name -> { NewName, Role, Tint }
	local function template(parent: Instance, name: string, roles, rootCF: CFrame, rootSize: Vector3?, park: CFrame)
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = name
		local root = rootPart(rootCF, rootSize)
		root.Parent = model
		for meshName, info in roles do
			local part = get(meshName):Clone()
			part.Name = info.Name
			if info.Role then
				part:SetAttribute("Role", info.Role)
			end
			if info.Tint then
				part:SetAttribute("Tint", true)
			end
			if info.Color then
				part.Color = info.Color
			end
			if info.Material then
				part.Material = info.Material
			end
			if info.Transparency then
				part.Transparency = info.Transparency
			end
			part.Parent = model
		end
		model.PrimaryPart = root
		model.WorldPivot = root.CFrame
		model:PivotTo(park)
		model.Parent = parent
		return model
	end

	-- Bee ------------------------------------------------------------------------------------
	local bees = folder("Bees", assets)
	template(bees, "Bee", {
		Bee_Body = { Name = "Body", Role = "Body", Color = Color3.fromRGB(255, 200, 40) },
		Bee_Stripes = { Name = "Stripes", Role = "Stripe", Color = Color3.fromRGB(45, 32, 22) },
		Bee_Eyes = { Name = "Eyes", Role = "Eye", Color = Color3.fromRGB(18, 18, 24) },
		Bee_Shine = { Name = "Shine", Role = "Detail", Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon },
		Bee_Details = { Name = "Details", Role = "Detail", Color = Color3.fromRGB(35, 28, 22) },
		Bee_WingL = { Name = "WingL", Role = "WingL", Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Glass, Transparency = 0.35 },
		Bee_WingR = { Name = "WingR", Role = "WingR", Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Glass, Transparency = 0.35 },
		Bee_Crown = { Name = "Crown", Role = "Crown", Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Metal },
		Bee_Halo = { Name = "Halo", Role = "Halo", Color = Color3.fromRGB(255, 248, 200), Material = Enum.Material.Neon },
	}, CFrame.new(body.Position), nil, CFrame.new(0, 50, 0))
	table.insert(log, "Bee template")

	-- Monsters (root at ground level so the renderer can stand them on the field) -------------
	local monsters = folder("Monsters", assets)
	local function groundRoot(names: { string })
		local minY, center = math.huge, Vector3.zero
		for _, n in names do
			local p = get(n)
			minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
			center += p.Position
		end
		center /= #names
		return CFrame.new(center.X, minY, center.Z)
	end
	local aphidNames = { "Aphid_Body", "Aphid_Eyes", "Aphid_Legs" }
	local aphid = template(monsters, "Aphid", {
		Aphid_Body = { Name = "Body", Color = Color3.fromRGB(130, 210, 80) },
		Aphid_Eyes = { Name = "Eyes", Color = Color3.fromRGB(200, 30, 30) },
		Aphid_Legs = { Name = "Legs", Color = Color3.fromRGB(60, 110, 40) },
	}, groundRoot(aphidNames), nil, CFrame.new(0, 60, 0))
	aphid:SetAttribute("Grounded", true)
	aphid:ScaleTo(0.85)
	local queen = template(monsters, "AphidQueen", {
		Aphid_Body = { Name = "Body", Color = Color3.fromRGB(150, 110, 210) },
		Aphid_Eyes = { Name = "Eyes", Color = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Neon },
		Aphid_Legs = { Name = "Legs", Color = Color3.fromRGB(80, 50, 120) },
		Aphid_Crown = { Name = "Crown", Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Neon },
	}, groundRoot(aphidNames), nil, CFrame.new(20, 60, 0))
	queen:SetAttribute("Grounded", true)
	queen:ScaleTo(2.6)
	local ladyNames = { "Ladybug_Shell", "Ladybug_Body", "Ladybug_Spots", "Ladybug_Eyes" }
	local lady = template(monsters, "Ladybug", {
		Ladybug_Shell = { Name = "Shell", Color = Color3.fromRGB(220, 40, 40) },
		Ladybug_Body = { Name = "Body", Color = Color3.fromRGB(25, 25, 28) },
		Ladybug_Spots = { Name = "Spots", Color = Color3.fromRGB(25, 25, 28) },
		Ladybug_Eyes = { Name = "Eyes", Color = Color3.new(1, 1, 1) },
	}, groundRoot(ladyNames), nil, CFrame.new(40, 60, 0))
	lady:SetAttribute("Grounded", true)
	lady:ScaleTo(0.9)
	table.insert(log, "Monster templates")

	-- Collectors (Tools: Handle + tinted head) ---------------------------------------------------
	local collectors = folder("Collectors", assets)
	for _, shape in { "Scoop", "Rake", "Vacuum", "Wand" } do
		local old = collectors:FindFirstChild(shape)
		if old then
			old:Destroy()
		end
		local tool = Instance.new("Tool")
		tool.Name = shape
		tool.CanBeDropped = false
		local handle = get(shape .. "_Handle"):Clone()
		handle.Name = "Handle"
		handle.Color = Color3.fromRGB(160, 110, 64)
		handle.Material = Enum.Material.Wood
		handle.Parent = tool
		local head = get(shape .. "_Head"):Clone()
		head.Name = "Head"
		head:SetAttribute("Tint", true)
		head.Material = shape == "Wand" and Enum.Material.Neon or Enum.Material.SmoothPlastic
		head.Parent = tool
		for _, p in { handle, head } do
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = head
		weld.Parent = head
		-- the hand holds the lower quarter of the handle
		local length = handle.Size.Y
		tool.Grip = CFrame.new(0, -length * 0.2, 0)
		tool.Parent = collectors
	end
	table.insert(log, "Collector tools")

	-- Backpacks (root faces away from the player: +Z of the torso = back) ------------------------
	local backpacks = folder("Backpacks", assets)
	local function packRoot(mainName: string)
		local main = get(mainName)
		-- pack front is -Z after normalization; the root must have the front pointing +Z
		return CFrame.new(main.Position) * CFrame.Angles(0, math.pi, 0)
	end
	template(backpacks, "Pouch", {
		Pouch_Main = { Name = "Main", Tint = true },
		Pouch_Detail = { Name = "Detail", Color = Color3.fromRGB(110, 72, 40) },
	}, packRoot("Pouch_Main"), nil, CFrame.new(0, 80, 0))
	template(backpacks, "Canister", {
		Canister_Main = { Name = "Main", Tint = true, Material = Enum.Material.Glass, Transparency = 0.35 },
		Canister_Honey = { Name = "Honey", Color = Color3.fromRGB(255, 180, 30), Material = Enum.Material.Neon, Transparency = 0.15 },
		Canister_Detail = { Name = "Detail", Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal },
	}, packRoot("Canister_Main"), nil, CFrame.new(6, 80, 0))
	template(backpacks, "Tank", {
		Tank_Main = { Name = "Main", Tint = true },
		Tank_Detail = { Name = "Detail", Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal },
	}, packRoot("Tank_Main"), nil, CFrame.new(12, 80, 0))
	table.insert(log, "Backpack templates")

	-- Raw meshes for the map builder ---------------------------------------------------------------
	local raw = folder("Raw", assets)
	raw:ClearAllChildren()
	local frame = get("Hive_Frame")
	local hiveFront = frame.Position + Vector3.new(0, 0, -frame.Size.Z / 2) -- front face centre
	template(raw, "Hive", {
		Hive_Frame = { Name = "Frame", Color = Color3.fromRGB(196, 128, 40), Material = Enum.Material.Wood },
		Hive_Rim = { Name = "Rim", Color = Color3.fromRGB(104, 70, 40), Material = Enum.Material.Wood },
		Hive_Roof = { Name = "Roof", Color = Color3.fromRGB(170, 70, 40), Material = Enum.Material.WoodPlanks },
		Hive_Honey = { Name = "Honey", Color = Color3.fromRGB(255, 170, 20), Material = Enum.Material.Glass, Transparency = 0.1 },
		Hive_Posts = { Name = "Posts", Color = Color3.fromRGB(104, 70, 40), Material = Enum.Material.Wood },
	}, CFrame.new(hiveFront), nil, CFrame.new(0, 100, 0))
	local cell = get("HexCell")
	template(raw, "HexCell", {
		HexCell = { Name = "Cell" },
	}, CFrame.new(cell.Position), nil, CFrame.new(40, 100, 0))
	for _, n in { "Flower_Daisy", "Flower_Rose", "Flower_Bell", "Flower_Center" } do
		local p = get(n)
		local pivotY = p.Position.Y - p.Size.Y / 2
		template(raw, n, { [n] = { Name = "Mesh" } }, CFrame.new(p.Position.X, pivotY, p.Position.Z), nil, CFrame.new(60, 100, 0))
	end
	local trunk = get("Tree_Trunk")
	template(raw, "Tree", {
		Tree_Trunk = { Name = "Trunk", Color = Color3.fromRGB(110, 74, 44), Material = Enum.Material.Wood },
		Tree_Leaves = { Name = "Leaves", Color = Color3.fromRGB(80, 160, 70), Material = Enum.Material.Grass },
	}, CFrame.new(trunk.Position.X, trunk.Position.Y - trunk.Size.Y / 2, trunk.Position.Z), nil, CFrame.new(80, 100, 0))
	table.insert(log, "Raw map meshes")

	import:Destroy()
	table.insert(log, "removed import from Workspace")
	return table.concat(log, "\n")
end
