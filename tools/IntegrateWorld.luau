--[[
	IntegrateWorld (Studio edit-time tool)
	Turns the imported BeeTycoon_World.fbx into templates:
	  Assets.Raw.{Nest, Gate, Rock_A, Rock_B, Bush, Mushroom, Fence, Lantern, Signpost, Arrow3D, Pine}
	  Assets.Eggs.Egg (Top / Bottom / Spots, for the hatch cutscene and nest display eggs)
	Orientation is normalized from the gate pillars (long axis = X).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function findImport(): Model?
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child:FindFirstChild("Nest_Twigs", true) then
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

return function()
	local import = findImport()
	if not import then
		return "No imported world model (Nest_Twigs) in Workspace"
	end
	local function get(name: string): BasePart
		local part = import:FindFirstChild(name, true)
		assert(part and part:IsA("BasePart"), "missing mesh " .. name)
		return part
	end
	local log = {}

	-- yaw normalization: the gate pillars span the X axis (snap the import back to axis-aligned)
	local pillars = get("Gate_Pillars")
	local _, yaw = pillars.CFrame:ToOrientation()
	if pillars.Size.Z > pillars.Size.X then
		yaw += math.pi / 2
	end
	if math.abs(yaw) > 0.01 then
		local pivot = import:GetPivot()
		local fix = CFrame.Angles(0, -yaw, 0)
		for _, part in import:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = pivot * (fix * pivot:ToObjectSpace(part.CFrame))
			end
		end
		table.insert(log, string.format("rotated world import by %.0f deg", math.deg(-yaw)))
	end

	local assets = folder("Assets", ReplicatedStorage)
	local raw = folder("Raw", assets)
	local eggs = folder("Eggs", assets)

	local function template(parent: Instance, name: string, parts, extra)
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = name
		local minY, sum, n = math.huge, Vector3.zero, 0
		for meshName in parts do
			local p = get(meshName)
			minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
			sum += p.Position
			n += 1
		end
		local center = sum / n
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Transparency = 1
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CFrame = CFrame.new(center.X, minY, center.Z)
		root.Parent = model
		for meshName, info in parts do
			local part = get(meshName):Clone()
			part.Name = info.Name
			part.Anchored = true
			part.Color = info.Color or part.Color
			part.Material = info.Material or Enum.Material.SmoothPlastic
			part.Transparency = info.Transparency or 0
			part.CanCollide = info.Collide == true
			part.CanQuery = info.Collide == true
			part.CastShadow = info.Shadow ~= false
			for key, value in info.Attributes or {} do
				part:SetAttribute(key, value)
			end
			part.Parent = model
		end
		model.PrimaryPart = root
		model.WorldPivot = root.CFrame
		if extra then
			extra(model, root)
		end
		model:PivotTo(CFrame.new(math.random(-50, 50), 150, math.random(-50, 50)))
		model.Parent = parent
		return model
	end

	local STONE = Color3.fromRGB(160, 152, 140)
	local GOLD = Color3.fromRGB(255, 200, 60)

	template(raw, "Nest", {
		Nest_Twigs = { Name = "Twigs", Color = Color3.fromRGB(160, 108, 60), Material = Enum.Material.Wood, Collide = true },
		Nest_Gold = { Name = "Gold", Color = GOLD, Material = Enum.Material.Foil },
		Nest_Honey = { Name = "Honey", Color = Color3.fromRGB(255, 176, 30), Material = Enum.Material.Glass, Transparency = 0.05 },
		Nest_Pedestal = { Name = "Pedestal", Color = Color3.fromRGB(235, 225, 205), Material = Enum.Material.Limestone, Collide = true },
	}, function(model, root)
		local honey = model:FindFirstChild("Honey")
		model:SetAttribute("EggHeight", honey.Position.Y + honey.Size.Y / 2 - root.Position.Y)
	end)
	template(eggs, "Egg", {
		Egg_Bottom = { Name = "Bottom" },
		Egg_Top = { Name = "Top" },
		Egg_Spots = { Name = "Spots", Color = GOLD },
	})
	template(raw, "Gate", {
		Gate_Pillars = { Name = "Pillars", Color = STONE, Material = Enum.Material.Slate, Collide = true },
		Gate_Arch = { Name = "Arch", Color = STONE, Material = Enum.Material.Slate, Collide = true },
		Gate_Moss = { Name = "Moss", Color = Color3.fromRGB(96, 168, 72), Material = Enum.Material.Grass },
		Gate_Boulders = { Name = "Boulders", Color = Color3.fromRGB(140, 132, 122), Material = Enum.Material.Slate, Collide = true, Attributes = { Barrier = true } },
	})
	template(raw, "Rock_A", { Rock_A = { Name = "Rock", Color = STONE, Material = Enum.Material.Slate, Collide = true } })
	template(raw, "Rock_B", { Rock_B = { Name = "Rock", Color = STONE, Material = Enum.Material.Slate, Collide = true } })
	template(raw, "Bush", { Bush = { Name = "Bush", Color = Color3.fromRGB(86, 170, 76), Material = Enum.Material.Grass } })
	template(raw, "Mushroom", {
		Mushroom_Stem = { Name = "Stem", Color = Color3.fromRGB(250, 240, 220) },
		Mushroom_Cap = { Name = "Cap", Color = Color3.fromRGB(230, 70, 60) },
		Mushroom_Dots = { Name = "Dots", Color = Color3.fromRGB(255, 250, 240) },
	})
	template(raw, "Fence", { Fence = { Name = "Fence", Color = Color3.fromRGB(170, 120, 72), Material = Enum.Material.Wood, Collide = true } })
	template(raw, "Lantern", {
		Lantern_Post = { Name = "Post", Color = Color3.fromRGB(70, 60, 55), Material = Enum.Material.Metal, Collide = true },
		Lantern_Glow = { Name = "Glow", Color = Color3.fromRGB(255, 214, 120), Material = Enum.Material.Neon, Shadow = false },
	}, function(model)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Range = 18
		light.Brightness = 1.4
		light.Parent = model:FindFirstChild("Glow")
	end)
	template(raw, "Signpost", { Signpost = { Name = "Board", Color = Color3.fromRGB(170, 120, 72), Material = Enum.Material.Wood, Collide = true } })
	template(raw, "Arrow3D", { Arrow3D = { Name = "Arrow", Color = GOLD, Material = Enum.Material.Neon, Shadow = false } })
	template(raw, "Pine", {
		Pine_Leaves = { Name = "Leaves", Color = Color3.fromRGB(70, 150, 80), Material = Enum.Material.Grass },
		Pine_Trunk = { Name = "Trunk", Color = Color3.fromRGB(110, 74, 44), Material = Enum.Material.Wood, Collide = true },
	})
	table.insert(log, "world templates created")
	import:Destroy()
	table.insert(log, "removed world import from Workspace")
	return table.concat(log, "\n")
end
