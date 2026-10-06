--[[
	GearModels
	Procedural low-poly models for backpacks and boots, shared by the server (what players wear)
	and the client (shop previews). Built from parts, so colours and materials always show up
	(no textures to stream in) and every tier has its own silhouette, not just a new colour.

	  GearModels.Backpack(def)          -> Model (PrimaryPart "Main"; local +Z faces away from the back)
	  GearModels.Boot(def, footSize)    -> Model of parts placed in foot space (origin = foot centre)

	def.Style picks the silhouette; def.Color / def.Accent / def.Material dress it.
]]

local GearModels = {}

local HONEY = Color3.fromRGB(255, 180, 30)

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if material == Enum.Material.Glass then
		p.Transparency = 0.35
	end
	p.Parent = model
	return p
end

-- vertical cylinder helper (Roblox cylinders run along X)
local function cylinder(model: Model, name: string, height: number, diameter: number, at: Vector3, color: Color3, material: Enum.Material?)
	return part(model, name, Vector3.new(height, diameter, diameter), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

local function shades(def)
	local base = def.Color
	local accent = def.Accent or base:Lerp(Color3.new(1, 1, 1), 0.45)
	local dark = base:Lerp(Color3.new(0, 0, 0), 0.35)
	return base, accent, dark, def.Material or Enum.Material.SmoothPlastic
end

-- straps on the side that touches the back
local function straps(model: Model, height: number, width: number, depth: number, color: Color3)
	for _, x in { -width * 0.28, width * 0.28 } do
		part(model, "Strap", Vector3.new(0.22, height * 0.95, 0.12), CFrame.new(x, 0, -depth / 2 - 0.04), color, Enum.Material.Fabric)
	end
end

-- Backpacks -----------------------------------------------------------------------------------------

local BACKPACKS = {}

function BACKPACKS.Pouch(model, def)
	local base, accent, dark, material = shades(def)
	local main = part(model, "Main", Vector3.new(1.6, 1.8, 0.9), CFrame.new(0, 0, 0), base, material)
	part(model, "Flap", Vector3.new(1.66, 0.7, 0.96), CFrame.new(0, 0.62, 0.03), dark, material)
	part(model, "Pocket", Vector3.new(1.1, 0.7, 0.3), CFrame.new(0, -0.35, 0.55), accent, material)
	part(model, "Buckle", Vector3.new(0.26, 0.26, 0.1), CFrame.new(0, 0.32, 0.53), Color3.fromRGB(255, 210, 70), Enum.Material.Metal)
	cylinder(model, "Honey", 0.08, 0.42, Vector3.new(0, -0.35, 0.72), HONEY, Enum.Material.Neon).CFrame = CFrame.new(0, -0.35, 0.72) * CFrame.Angles(0, math.pi / 2, 0)
	straps(model, 1.8, 1.6, 0.9, dark)
	return main
end

function BACKPACKS.Jar(model, def)
	local base, accent, dark, material = shades(def)
	local main = cylinder(model, "Main", 1.9, 1.5, Vector3.new(0, 0, 0), base, material == Enum.Material.SmoothPlastic and Enum.Material.Glass or material)
	cylinder(model, "Fill", 1.2, 1.3, Vector3.new(0, -0.3, 0), HONEY, Enum.Material.Neon)
	cylinder(model, "Lid", 0.32, 1.62, Vector3.new(0, 1.08, 0), accent, Enum.Material.Wood)
	cylinder(model, "Knob", 0.2, 0.5, Vector3.new(0, 1.32, 0), dark, Enum.Material.Wood)
	for _, y in { 0.45, -0.55 } do
		cylinder(model, "Band", 0.14, 1.56, Vector3.new(0, y, 0), dark, Enum.Material.Fabric)
	end
	straps(model, 1.9, 1.5, 1.5, dark)
	return main
end

function BACKPACKS.Canister(model, def)
	local base, accent, dark, material = shades(def)
	local main = cylinder(model, "Main", 2.0, 1.4, Vector3.new(0, 0, 0), base, material == Enum.Material.SmoothPlastic and Enum.Material.Metal or material)
	for _, y in { 0.55, -0.55 } do
		cylinder(model, "Stripe", 0.2, 1.46, Vector3.new(0, y, 0), accent, Enum.Material.SmoothPlastic)
	end
	cylinder(model, "Cap", 0.3, 0.8, Vector3.new(0, 1.12, 0), dark, Enum.Material.Metal)
	local gauge = part(model, "Gauge", Vector3.new(0.12, 0.5, 0.5), CFrame.new(0, 0.05, 0.72) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(model, "Needle", Vector3.new(0.05, 0.22, 0.04), gauge.CFrame * CFrame.new(-0.07, 0.05, 0) * CFrame.Angles(0, 0, 0.6), Color3.fromRGB(220, 40, 40))
	straps(model, 2.0, 1.4, 1.4, dark)
	return main
end

function BACKPACKS.Satchel(model, def)
	local base, accent, dark, material = shades(def)
	local main = part(model, "Main", Vector3.new(1.9, 1.7, 0.85), CFrame.new(0, 0, 0), base, material)
	part(model, "Flap", Vector3.new(1.96, 1.0, 0.12), CFrame.new(0, 0.38, 0.47), dark, material)
	for _, x in { -0.5, 0.5 } do
		part(model, "Buckle", Vector3.new(0.22, 0.3, 0.08), CFrame.new(x, -0.05, 0.55), Color3.fromRGB(255, 205, 60), Enum.Material.Metal)
	end
	part(model, "Emblem", Vector3.new(0.06, 0.42, 0.42), CFrame.new(0, 0.42, 0.56) * CFrame.Angles(0, math.pi / 2, 0), accent, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(model, "Roll", Vector3.new(1.7, 0.4, 0.4), CFrame.new(0, 1.02, 0) * CFrame.Angles(0, 0, 0), accent, Enum.Material.Fabric, Enum.PartType.Cylinder)
	straps(model, 1.7, 1.9, 0.85, dark)
	return main
end

function BACKPACKS.Skep(model, def)
	local base, accent, dark, material = shades(def)
	local main = cylinder(model, "Main", 0.7, 1.9, Vector3.new(0, -0.6, 0), base, material)
	cylinder(model, "Ring2", 0.65, 1.6, Vector3.new(0, 0.05, 0), accent, material)
	cylinder(model, "Ring3", 0.55, 1.15, Vector3.new(0, 0.62, 0), base, material)
	part(model, "Top", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.95, 0), accent, material, Enum.PartType.Ball)
	part(model, "Door", Vector3.new(0.1, 0.45, 0.45), CFrame.new(0, -0.65, 0.92) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(50, 30, 15), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for i, x in { -0.55, 0.1, 0.6 } do
		part(model, "Drip", Vector3.new(0.18, 0.3 + i * 0.08, 0.18), CFrame.new(x, -0.95, 0.75), HONEY, Enum.Material.Glass)
	end
	straps(model, 1.9, 1.9, 1.9, dark)
	return main
end

function BACKPACKS.Tank(model, def)
	local base, accent, dark, material = shades(def)
	local main = cylinder(model, "Main", 2.0, 1.6, Vector3.new(0, 0, 0), base, material)
	part(model, "TopCap", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 1.0, 0), base, material, Enum.PartType.Ball)
	part(model, "Window", Vector3.new(0.5, 1.4, 0.1), CFrame.new(0, -0.05, 0.79), Color3.fromRGB(200, 240, 255), Enum.Material.Glass)
	part(model, "Fill", Vector3.new(0.38, 1.0, 0.06), CFrame.new(0, -0.22, 0.83), HONEY, Enum.Material.Neon)
	part(model, "Pipe", Vector3.new(0.22, 2.1, 0.22), CFrame.new(0.92, -0.1, 0.1), accent, Enum.Material.Metal)
	part(model, "PipeTop", Vector3.new(0.5, 0.22, 0.22), CFrame.new(0.72, 0.95, 0.1), accent, Enum.Material.Metal)
	cylinder(model, "Base", 0.25, 1.7, Vector3.new(0, -1.05, 0), dark, Enum.Material.Metal)
	straps(model, 2.0, 1.6, 1.6, dark)
	return main
end

function BACKPACKS.Twin(model, def)
	local base, accent, dark, material = shades(def)
	local main = part(model, "Main", Vector3.new(1.0, 2.0, 0.5), CFrame.new(0, 0, -0.3), accent, Enum.Material.Foil)
	for _, x in { -0.55, 0.55 } do
		cylinder(model, "Tank", 2.1, 0.95, Vector3.new(x, 0, 0.12), base, material)
		part(model, "Dome", Vector3.new(0.95, 0.95, 0.95), CFrame.new(x, 1.05, 0.12), base, material, Enum.PartType.Ball)
		cylinder(model, "Fill", 1.2, 0.75, Vector3.new(x, -0.35, 0.12), HONEY, Enum.Material.Neon)
	end
	part(model, "Gem", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.35, 0.1) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(255, 240, 255), Enum.Material.Neon)
	straps(model, 2.0, 1.8, 1.2, dark)
	return main
end

function GearModels.Backpack(def): Model
	local model = Instance.new("Model")
	model.Name = def.Id or "Backpack"
	local builder = BACKPACKS[def.Style or "Pouch"] or BACKPACKS.Pouch
	local main = builder(model, def)
	main.Name = "Main"
	-- cylinder mains are rotated (Roblox cylinders run along X): pivot on the upright model frame
	main.PivotOffset = main.CFrame:Inverse()
	model.PrimaryPart = main
	model:SetAttribute("Procedural", true)
	return model
end

-- Boots ----------------------------------------------------------------------------------------------
-- Built around a foot of size (x, y, z), toes towards -Z, sole at -y/2.

local BOOTS = {}

local function sole(model, f, color, thickness)
	return part(model, "Sole", Vector3.new(f.X + 0.18, thickness or 0.2, f.Z + 0.3), CFrame.new(0, -f.Y / 2 + (thickness or 0.2) / 2 - 0.04, -0.04), color, Enum.Material.SmoothPlastic)
end

function BOOTS.FlipFlop(model, def, f)
	local base, accent = shades(def)
	sole(model, f, base, 0.16)
	for _, x in { -1, 1 } do
		part(model, "Thong", Vector3.new(0.08, 0.08, f.Z * 0.6), CFrame.new(x * f.X * 0.25, -f.Y / 2 + 0.2, -f.Z * 0.15) * CFrame.Angles(0, -x * 0.5, 0), accent)
	end
	part(model, "Flower", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, -f.Y / 2 + 0.26, -f.Z * 0.38), Color3.fromRGB(255, 120, 170), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BOOTS.Sneaker(model, def, f)
	local base, accent, dark, material = shades(def)
	sole(model, f, Color3.fromRGB(245, 245, 245), 0.22)
	part(model, "Upper", Vector3.new(f.X + 0.12, f.Y * 0.65, f.Z + 0.14), CFrame.new(0, -f.Y / 2 + f.Y * 0.35, 0.02), base, material)
	part(model, "Toe", Vector3.new(f.X + 0.14, f.Y * 0.32, 0.3), CFrame.new(0, -f.Y / 2 + 0.25, -(f.Z / 2 + 0.1)), Color3.fromRGB(245, 245, 245))
	part(model, "Swoosh", Vector3.new(f.X + 0.16, 0.1, f.Z * 0.6), CFrame.new(0, -f.Y / 2 + f.Y * 0.3, 0.05) * CFrame.Angles(0.25, 0, 0), accent)
	for i = 0, 2 do
		part(model, "Lace", Vector3.new(f.X * 0.6, 0.05, 0.06), CFrame.new(0, -f.Y / 2 + f.Y * 0.6 + i * 0.02, -f.Z * 0.15 + i * 0.16), Color3.fromRGB(255, 255, 255))
	end
end

function BOOTS.Hiking(model, def, f)
	local base, accent, dark, material = shades(def)
	sole(model, f, Color3.fromRGB(60, 45, 35), 0.3)
	part(model, "Upper", Vector3.new(f.X + 0.14, f.Y + 0.25, f.Z + 0.16), CFrame.new(0, 0.1, 0.02), base, material == Enum.Material.SmoothPlastic and Enum.Material.Fabric or material)
	part(model, "Cuff", Vector3.new(f.X + 0.24, 0.22, f.Z + 0.26), CFrame.new(0, f.Y / 2 + 0.22, 0.02), accent, Enum.Material.Fabric)
	part(model, "ToeCap", Vector3.new(f.X + 0.18, f.Y * 0.4, 0.28), CFrame.new(0, -f.Y / 2 + 0.3, -(f.Z / 2 + 0.1)), dark)
end

function BOOTS.Rain(model, def, f)
	local base, accent, dark, material = shades(def)
	sole(model, f, dark, 0.22)
	part(model, "Shaft", Vector3.new(f.X + 0.2, f.Y + 0.7, f.Z + 0.2), CFrame.new(0, 0.33, 0.02), base, Enum.Material.SmoothPlastic)
	part(model, "Rim", Vector3.new(f.X + 0.3, 0.14, f.Z + 0.3), CFrame.new(0, f.Y / 2 + 0.7, 0.02), accent)
	part(model, "Toe", Vector3.new(f.X + 0.2, f.Y * 0.45, 0.3), CFrame.new(0, -f.Y / 2 + 0.28, -(f.Z / 2 + 0.12)), base)
end

local function sneakerWith(model, def, f, extra)
	BOOTS.Sneaker(model, def, f)
	extra()
end

function BOOTS.Speedy(model, def, f)
	local _, accent = shades(def)
	sneakerWith(model, def, f, function()
		for _, x in { -1, 1 } do
			part(model, "Wing", Vector3.new(0.05, 0.45, 0.7), CFrame.new(x * (f.X / 2 + 0.12), -f.Y / 2 + f.Y * 0.55, f.Z * 0.25) * CFrame.Angles(-0.5, 0, x * 0.3), accent, Enum.Material.Neon)
		end
	end)
end

function BOOTS.Honey(model, def, f)
	local base, accent = shades(def)
	BOOTS.Rain(model, def, f)
	for i, x in { -0.3, 0.05, 0.3 } do
		part(model, "Drip", Vector3.new(0.14, 0.25 + i * 0.1, 0.14), CFrame.new(x * f.X, f.Y / 2 + 0.55, -(f.Z / 2 + 0.12)), accent, Enum.Material.Glass)
	end
	part(model, "Comb", Vector3.new(0.06, 0.4, 0.4), CFrame.new(f.X / 2 + 0.13, 0.2, 0) * CFrame.Angles(0, 0, 0), HONEY, Enum.Material.Neon, Enum.PartType.Cylinder)
end

function BOOTS.Cloud(model, def, f)
	local base, accent = shades(def)
	BOOTS.Sneaker(model, def, f)
	for _, offset in { Vector3.new(-0.35, 0, 0.3), Vector3.new(0.35, 0.05, 0.1), Vector3.new(0, 0, -0.35), Vector3.new(0.3, -0.05, -0.4), Vector3.new(-0.3, 0.02, -0.2) } do
		part(model, "Puff", Vector3.new(0.55, 0.55, 0.55), CFrame.new(offset.X * f.X * 1.6, -f.Y / 2 - 0.05 + offset.Y, offset.Z * f.Z), Color3.fromRGB(250, 252, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

function BOOTS.Rocket(model, def, f)
	local base, accent, dark = shades(def)
	BOOTS.Hiking(model, def, f)
	part(model, "Nozzle", Vector3.new(0.5, 0.55, 0.55), CFrame.new(0, -f.Y / 2 + 0.25, f.Z / 2 + 0.3) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(model, "Flame", Vector3.new(0.3, 0.38, 0.38), CFrame.new(0, -f.Y / 2 + 0.25, f.Z / 2 + 0.6) * CFrame.Angles(0, math.pi / 2, 0), accent, Enum.Material.Neon, Enum.PartType.Cylinder)
end

function BOOTS.Lightning(model, def, f)
	local base, accent = shades(def)
	BOOTS.Sneaker(model, def, f)
	for _, x in { -1, 1 } do
		local bolt = part(model, "Bolt", Vector3.new(0.06, 0.6, 0.18), CFrame.new(x * (f.X / 2 + 0.11), -f.Y / 2 + f.Y * 0.5, 0.05) * CFrame.Angles(0, 0, x * 0.4), accent, Enum.Material.Neon)
		part(model, "Bolt2", Vector3.new(0.06, 0.45, 0.16), bolt.CFrame * CFrame.new(0, -0.35, -0.12) * CFrame.Angles(0, 0, -x * 0.8), accent, Enum.Material.Neon)
	end
end

function BOOTS.Royal(model, def, f)
	local base, accent = shades(def)
	BOOTS.Rain(model, def, f)
	for _, x in { -1, 1 } do
		part(model, "Feather", Vector3.new(0.06, 0.25, 0.9), CFrame.new(x * (f.X / 2 + 0.14), f.Y / 2 + 0.25, f.Z * 0.2) * CFrame.Angles(-0.6, 0, x * 0.35), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		part(model, "Feather2", Vector3.new(0.06, 0.2, 0.7), CFrame.new(x * (f.X / 2 + 0.14), f.Y / 2 + 0.05, f.Z * 0.3) * CFrame.Angles(-0.4, 0, x * 0.35), accent, Enum.Material.SmoothPlastic)
	end
	part(model, "Gem", Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 0, -(f.Z / 2 + 0.2)) * CFrame.Angles(0.8, 0.8, 0), Color3.fromRGB(255, 80, 160), Enum.Material.Neon)
end

function GearModels.Boot(def, footSize: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "BeeBoot"
	local builder = BOOTS[def.Style or "Sneaker"] or BOOTS.Sneaker
	builder(model, def, footSize)
	local first = model:FindFirstChildWhichIsA("BasePart")
	first.PivotOffset = first.CFrame:Inverse() -- pivot on the foot centre, whatever the part's rotation
	model.PrimaryPart = first
	return model
end

return GearModels
