--[[
	FixDecor (Studio edit-time tool, run from the Command Bar)
	Applies decor fixes to the already built map, no rebuild needed (BuildMap does the same):
	  - Mushroom Hollow's giant mushrooms become the Blender mushroom scaled up (dots stay on the cap),
	    and caps that overlap are shrunk to fit (or removed when that would make them tiny)
	  - nest display eggs are NEST_EGG_HEIGHT studs tall (they were too small for the nests)
	Safe to run more than once. Save / publish the place afterwards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NEST_EGG_HEIGHT = 7.5

local function raw(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local rawFolder = assets and assets:FindFirstChild("Raw")
	return rawFolder and rawFolder:FindFirstChild(name)
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function giantMushroom(parent: Instance, ground: CFrame, height: number, cap: Color3): Model
	local template = raw("Mushroom")
	local m
	if template then
		m = template:Clone()
		local _, size = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * height / size.Y)
		m:PivotTo(ground)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				if p.Name == "Cap" then
					p.Color = cap
				end
			end
		end
	else
		m = Instance.new("Model")
		local s = height / 7
		local stem = Color3.fromRGB(245, 236, 216)
		local function sphere(name: string, size: Vector3, cf: CFrame, color: Color3)
			local p = part({ Name = name, Size = size, CFrame = cf, Color = color, CanCollide = false, Parent = m })
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere -- keeps the ellipsoid (a Ball part is always round)
			mesh.Parent = p
			return p
		end
		part({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5 * s, 1.6 * s, 1.6 * s), CFrame = ground * CFrame.new(0, 2.5 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = stem, CanCollide = false, Parent = m })
		sphere("Foot", Vector3.new(2.4 * s, 1.2 * s, 2.4 * s), ground * CFrame.new(0, 0.2 * s, 0), stem)
		local a, b, capY = 3.2 * s, 1.6 * s, 5.2 * s
		sphere("Cap", Vector3.new(2 * a, 2 * b, 2 * a), ground * CFrame.new(0, capY, 0), cap)
		local spots = { { 0, 0 }, { 0.55, 0.3 }, { 0.6, 1.5 }, { 0.5, 2.6 }, { 0.62, 3.7 }, { 0.5, 4.9 }, { 0.75, 0.9 }, { 0.75, 3.1 } }
		for i, spot in spots do
			local r, angle = spot[1] * a, spot[2]
			local x, z = math.cos(angle) * r, math.sin(angle) * r
			local y = b * math.sqrt(math.max(0, 1 - (r / a) ^ 2))
			local normal = Vector3.new(x / a ^ 2, y / b ^ 2, z / a ^ 2).Unit
			local right = normal:Cross(Vector3.zAxis)
			right = right.Magnitude > 1e-3 and right.Unit or Vector3.xAxis
			local d = (i == 1 and 1.1 or 0.8) * s
			-- centred on the dome surface: half of each flat spot shows, nothing floats
			sphere("Dot", Vector3.new(d, 0.3 * d, d), ground * CFrame.fromMatrix(Vector3.new(x, capY + y, z), right, normal), Color3.fromRGB(255, 250, 240))
		end
		m.PrimaryPart = m:FindFirstChild("Foot")
		m.WorldPivot = ground
	end
	m.Name = "MushroomProp"
	m:SetAttribute("Giant", true)
	m.Parent = parent
	return m
end


-- old part-built prop: square stem (Size.Y = 5 * scale) under a ball cap
local function rebuild(old: Model): boolean
	local stem, cap
	for _, p in old:GetChildren() do
		if p:IsA("Part") then
			if p.Shape == Enum.PartType.Block and (not stem or p.Size.Y > stem.Size.Y) then
				stem = p
			elseif p.Shape == Enum.PartType.Ball and (not cap or p.Size.X > cap.Size.X) then
				cap = p
			end
		end
	end
	if not stem or not cap then
		return false
	end
	local scale = stem.Size.Y / 5
	local ground = CFrame.new(stem.Position - Vector3.new(0, stem.Size.Y / 2, 0)) * stem.CFrame.Rotation
	giantMushroom(old.Parent, ground, 8 * scale, cap.Color)
	old:Destroy()
	return true
end

-- caps never grow into each other: biggest first, each next one shrinks to fit or goes away
local GAP = 1
local function spaceOut(): (number, number)
	local list = {}
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name == "MushroomProp" and obj:GetAttribute("Giant") then
			local _, size = obj:GetBoundingBox()
			table.insert(list, { Model = obj, Pos = obj:GetPivot().Position, Radius = math.max(size.X, size.Z) / 2 })
		end
	end
	table.sort(list, function(a, b)
		return a.Radius > b.Radius
	end)
	local kept, shrunk, removed = {}, 0, 0
	for _, entry in list do
		local allowed = entry.Radius
		for _, k in kept do
			local d = Vector3.new(entry.Pos.X - k.Pos.X, 0, entry.Pos.Z - k.Pos.Z).Magnitude
			allowed = math.min(allowed, d - k.Radius - GAP)
		end
		if allowed >= entry.Radius then
			table.insert(kept, entry)
		elseif allowed >= entry.Radius * 0.55 then
			entry.Model:ScaleTo(entry.Model:GetScale() * allowed / entry.Radius) -- pivot = stem foot
			entry.Radius = allowed
			table.insert(kept, entry)
			shrunk += 1
		else
			entry.Model:Destroy()
			removed += 1
		end
	end
	return shrunk, removed
end

return function()
	local mushrooms, eggs = 0, 0
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name == "MushroomProp" and not obj:GetAttribute("Giant") and obj.Parent then
			if rebuild(obj) then
				mushrooms += 1
			end
		elseif obj:IsA("Model") and obj.Name == "DisplayEgg" and obj.Parent and obj.Parent.Name:match("^Nest_") then
			local _, size = obj:GetBoundingBox()
			obj:ScaleTo(obj:GetScale() * NEST_EGG_HEIGHT / size.Y) -- pivot = egg bottom, so it grows upwards
			eggs += 1
		end
	end
	local shrunk, removed = spaceOut()
	return `{mushrooms} mushrooms rebuilt{raw("Mushroom") and " (Blender model)" or " (parts)"}, {shrunk} shrunk / {removed} removed so none overlap, {eggs} nest eggs resized`
end
