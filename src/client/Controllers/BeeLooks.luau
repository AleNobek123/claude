--[[
	BeeLooks
	Gives every bee species its own silhouette on top of the shared bee mesh:
	  Visual.Shape   body proportions (chubby bumble, slim ninja, big lion...)
	  Visual.Extras  procedural accessories: mane, helmet, crest, shades, crystal spikes, ...
	  Visual.Aura    particle aura for the rare ones (fire, frost, sparks, stars, void, bubbles)
	Accessories are anchored parts added to the model before BeeRenderer records its offsets,
	so they fly, flap and BulkMove together with the bee.
]]

local BeeLooks = {}

local RESIZE = { Body = true, Stripe = true, Stripes = true, Detail = true, Details = true, Shine = true }

local function add(model: Model, body: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p:SetAttribute("Role", "Accessory")
	p:SetAttribute("Accessory", true)
	p.Size = size
	p.CFrame = body.CFrame * offset
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
	p.CastShadow = false
	if material == Enum.Material.Glass then
		p.Transparency = 0.4
	end
	p.Parent = model
	return p
end

-- u = body length unit (1.45 studs on the template, scaled with the bee)
local EXTRAS = {}

function EXTRAS.Mane(model, body, def, u)
	local color = def.Visual.Stripe
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		add(model, body, "Mane", Vector3.one * 0.3 * u, CFrame.new(math.cos(a) * 0.42 * u, 0.12 * u + math.sin(a) * 0.4 * u, -0.38 * u), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

function EXTRAS.Fluff(model, body, _def, u)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		add(model, body, "Fluff", Vector3.one * 0.26 * u, CFrame.new(math.cos(a) * 0.36 * u, math.sin(a) * 0.34 * u, -0.22 * u), Color3.fromRGB(255, 250, 240), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

function EXTRAS.Helmet(model, body, def, u)
	add(model, body, "Helmet", Vector3.new(0.62, 0.32, 0.6) * u, CFrame.new(0, 0.42 * u, -0.28 * u), Color3.fromRGB(150, 155, 165), Enum.Material.Metal, Enum.PartType.Ball)
	add(model, body, "Plume", Vector3.new(0.08, 0.28, 0.32) * u, CFrame.new(0, 0.62 * u, -0.25 * u), def.Visual.Stripe, Enum.Material.SmoothPlastic)
end

function EXTRAS.Crest(model, body, def, u)
	local color = def.Visual.Stripe:Lerp(Color3.fromRGB(255, 140, 30), 0.4)
	for i, z in { -0.4, -0.22, -0.04 } do
		add(model, body, "Crest", Vector3.new(0.06, (0.34 - i * 0.05) * u, 0.18 * u), CFrame.new(0, (0.55 - i * 0.03) * u, z * u) * CFrame.Angles(-0.4, 0, 0), color, Enum.Material.Neon)
	end
end

function EXTRAS.Horns(model, body, def, u)
	for _, x in { -1, 1 } do
		add(model, body, "Horn", Vector3.new(0.1, 0.32, 0.1) * u, CFrame.new(x * 0.2 * u, 0.52 * u, -0.42 * u) * CFrame.Angles(0.2, 0, -x * 0.35), def.Visual.Stripe:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.SmoothPlastic)
	end
end

function EXTRAS.Spikes(model, body, def, u)
	for i, offset in { Vector3.new(0, 0.5, 0.15), Vector3.new(0.22, 0.42, 0.35), Vector3.new(-0.22, 0.42, 0.35), Vector3.new(0, 0.38, 0.52) } do
		add(model, body, "Spike", Vector3.new(0.14, 0.42 - i * 0.04, 0.14) * u, CFrame.new(offset * u) * CFrame.Angles(0.35, i, 0.2 * (i % 2 == 0 and 1 or -1)), def.Visual.Body:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Glass)
	end
end

function EXTRAS.Mask(model, body, _def, u)
	add(model, body, "Mask", Vector3.new(0.82, 0.16, 0.08) * u, CFrame.new(0, 0.15 * u, -0.6 * u), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic)
	for _, x in { -1, 1 } do
		add(model, body, "Ribbon", Vector3.new(0.05, 0.08, 0.38) * u, CFrame.new(x * 0.18 * u, 0.2 * u, 0.12 * u) * CFrame.Angles(0.3, x * 0.4, 0), Color3.fromRGB(210, 40, 60), Enum.Material.SmoothPlastic)
	end
end

function EXTRAS.Shades(model, body, _def, u)
	for _, x in { -1, 1 } do
		add(model, body, "Lens", Vector3.new(0.26, 0.16, 0.05) * u, CFrame.new(x * 0.17 * u, 0.15 * u, -0.66 * u), Color3.fromRGB(20, 20, 30), Enum.Material.Glass)
	end
	add(model, body, "Bridge", Vector3.new(0.12, 0.04, 0.04) * u, CFrame.new(0, 0.17 * u, -0.66 * u), Color3.fromRGB(20, 20, 30))
end

function EXTRAS.Bandana(model, body, _def, u)
	add(model, body, "Bandana", Vector3.new(0.9, 0.12, 0.9) * u, CFrame.new(0, 0.38 * u, -0.2 * u) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(220, 40, 40), Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(model, body, "Knot", Vector3.new(0.14, 0.14, 0.22) * u, CFrame.new(0, 0.4 * u, 0.26 * u), Color3.fromRGB(220, 40, 40), Enum.Material.Fabric)
end

function EXTRAS.Flower(model, body, _def, u)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		add(model, body, "Petal", Vector3.one * 0.14 * u, CFrame.new(0.22 * u + math.cos(a) * 0.1 * u, 0.56 * u, -0.3 * u + math.sin(a) * 0.1 * u), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	add(model, body, "Center", Vector3.one * 0.12 * u, CFrame.new(0.22 * u, 0.58 * u, -0.3 * u), Color3.fromRGB(255, 190, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function EXTRAS.Leaf(model, body, _def, u)
	add(model, body, "Leaf", Vector3.new(0.05, 0.42, 0.24) * u, CFrame.new(0, 0.62 * u, -0.2 * u) * CFrame.Angles(0.5, 0, 0.2), Color3.fromRGB(90, 200, 70), Enum.Material.SmoothPlastic)
	add(model, body, "Stem", Vector3.new(0.04, 0.16, 0.04) * u, CFrame.new(0, 0.48 * u, -0.25 * u), Color3.fromRGB(60, 120, 40))
end

function EXTRAS.Bolts(model, body, _def, u)
	for _, x in { -1, 1 } do
		local a = add(model, body, "Bolt", Vector3.new(0.05, 0.26, 0.08) * u, CFrame.new(x * 0.16 * u, 0.62 * u, -0.45 * u) * CFrame.Angles(0, 0, x * 0.35), Color3.fromRGB(255, 240, 90), Enum.Material.Neon)
		add(model, body, "Bolt2", Vector3.new(0.05, 0.2, 0.08) * u, a.CFrame * CFrame.new(0, 0.18 * u, 0) * CFrame.Angles(0, 0, -x * 0.9), Color3.fromRGB(255, 240, 90), Enum.Material.Neon)
	end
end

function EXTRAS.Bomb(model, body, _def, u)
	add(model, body, "Bomb", Vector3.one * 0.42 * u, CFrame.new(0, 0.42 * u, 0.42 * u), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	add(model, body, "Fuse", Vector3.new(0.05, 0.18, 0.05) * u, CFrame.new(0, 0.68 * u, 0.42 * u), Color3.fromRGB(255, 160, 40), Enum.Material.Neon)
end

function EXTRAS.Candy(model, body, _def, u)
	add(model, body, "Candy", Vector3.new(0.08, 0.5, 0.5) * u, CFrame.new(0, 0.32 * u, 0.5 * u) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 120, 190), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	add(model, body, "Swirl", Vector3.new(0.09, 0.3, 0.3) * u, CFrame.new(0, 0.32 * u, 0.5 * u) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	add(model, body, "Stick", Vector3.new(0.05, 0.4, 0.05) * u, CFrame.new(0, 0.02 * u, 0.52 * u), Color3.fromRGB(250, 250, 250))
end

function EXTRAS.Gem(model, body, def, u)
	add(model, body, "Gem", Vector3.one * 0.18 * u, CFrame.new(0, 0.4 * u, -0.58 * u) * CFrame.Angles(0.8, 0.8, 0), def.Visual.Stripe, Enum.Material.Neon)
end

-- tilted planetary ring of tiny glowing orbs
function EXTRAS.Ring(model, body, def, u)
	local tilt = CFrame.Angles(0.35, 0, 0.2)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		add(model, body, "Ring", Vector3.one * 0.11 * u, tilt * CFrame.new(math.cos(a) * 0.85 * u, 0, math.sin(a) * 0.85 * u), def.Visual.Stripe, Enum.Material.Neon, Enum.PartType.Ball)
	end
end

function EXTRAS.Moon(model, body, _def, u)
	add(model, body, "Moon", Vector3.one * 0.22 * u, CFrame.new(0.25 * u, 0.6 * u, -0.2 * u), Color3.fromRGB(240, 235, 200), Enum.Material.Neon, Enum.PartType.Ball)
end

function EXTRAS.Drop(model, body, _def, u)
	add(model, body, "HoneyDrop", Vector3.new(0.3, 0.38, 0.3) * u, CFrame.new(0, 0.48 * u, 0.4 * u), Color3.fromRGB(255, 180, 30), Enum.Material.Glass, Enum.PartType.Ball)
end

function EXTRAS.Drips(model, body, def, u)
	for _, x in { -0.25, 0.05, 0.28 } do
		add(model, body, "Drip", Vector3.new(0.1, 0.22, 0.1) * u, CFrame.new(x * u, -0.52 * u, 0.1 * u), def.Visual.Body, Enum.Material.Glass)
	end
end

function EXTRAS.Bubble(model, body, _def, u)
	add(model, body, "Bubble", Vector3.one * 1.7 * u, CFrame.new(0, 0.05 * u, 0), Color3.fromRGB(190, 230, 255), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.82
end

-- Blender-made accessories (Assets.BeeAccessories, see tools/IntegrateV6): parts sit in the
-- body frame of the template bee; Paint says how to colour each part
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(255, 140, 30)
local PAINT = {
	Metal = function() return Color3.fromRGB(172, 178, 188), Enum.Material.Metal, 0 end,
	Gold = function() return Color3.fromRGB(255, 204, 70), Enum.Material.Foil, 0 end,
	Dark = function() return Color3.fromRGB(36, 32, 38), Enum.Material.SmoothPlastic, 0 end,
	White = function() return Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic, 0 end,
	Red = function() return Color3.fromRGB(222, 48, 58), Enum.Material.Fabric, 0 end,
	Green = function() return Color3.fromRGB(96, 204, 72), Enum.Material.SmoothPlastic, 0 end,
	Pink = function() return Color3.fromRGB(255, 128, 186), Enum.Material.SmoothPlastic, 0 end,
	Wood = function() return Color3.fromRGB(126, 84, 46), Enum.Material.Wood, 0 end,
	Honey = function() return Color3.fromRGB(255, 172, 30), Enum.Material.Glass, 0.15 end,
	Lens = function() return Color3.fromRGB(22, 22, 30), Enum.Material.Glass, 0.1 end,
	Glass = function() return Color3.fromRGB(200, 235, 255), Enum.Material.Glass, 0.78 end,
	Crystal = function(def) return def.Visual.Body:Lerp(WHITE, 0.5), Enum.Material.Glass, 0.2 end,
	Stripe = function(def) return def.Visual.Stripe, Enum.Material.SmoothPlastic, 0 end,
	Neon = function(def) return def.Visual.Stripe:Lerp(ORANGE, 0.6), Enum.Material.Neon, 0 end,
}
-- per accessory tweaks of the role palette
local OVERRIDE = {
	Bolts = { Neon = function() return Color3.fromRGB(255, 240, 90), Enum.Material.Neon, 0 end },
	Ring = { Neon = function(def) return def.Visual.Stripe, Enum.Material.Neon, 0.25 end },
	Gem = { Stripe = function(def) return def.Visual.Stripe:Lerp(WHITE, 0.2), Enum.Material.Neon, 0 end },
	Mane = { Stripe = function(def) return def.Visual.Stripe:Lerp(ORANGE, 0.25), Enum.Material.SmoothPlastic, 0 end },
}

local function meshAccessory(model: Model, body: BasePart, def, name: string, u: number): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("BeeAccessories")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return false
	end
	for _, src in template:GetChildren() do
		if src:IsA("BasePart") then
			local p = src:Clone()
			local paint = src:GetAttribute("Role") or "Stripe"
			local fn = (OVERRIDE[name] and OVERRIDE[name][paint]) or PAINT[paint] or PAINT.Stripe
			local color, material, transparency = fn(def)
			p.Name = name
			p.Color = color
			p.Material = material
			p.Transparency = transparency
			p.Size = src.Size * u
			p.CFrame = body.CFrame * CFrame.new(src.CFrame.Position * u) * src.CFrame.Rotation
			p:SetAttribute("Role", "Accessory")
			p:SetAttribute("Accessory", true)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = model
		end
	end
	return true
end

local AURAS = {
	Fire = { Color = Color3.fromRGB(255, 120, 30), Rate = 10, Speed = 1.5, Size = 0.35, Light = 1 },
	Frost = { Color = Color3.fromRGB(190, 235, 255), Rate = 6, Speed = 0.8, Size = 0.25, Light = 0.6 },
	Spark = { Color = Color3.fromRGB(255, 245, 120), Rate = 8, Speed = 3, Size = 0.18, Light = 1 },
	Stars = { Color = Color3.fromRGB(180, 220, 255), Rate = 6, Speed = 0.6, Size = 0.25, Light = 1 },
	Void = { Color = Color3.fromRGB(140, 60, 255), Rate = 8, Speed = 0.6, Size = 0.4, Light = 0.4 },
	Toxic = { Color = Color3.fromRGB(150, 240, 60), Rate = 6, Speed = 0.7, Size = 0.3, Light = 0.5 },
	Gold = { Color = Color3.fromRGB(255, 220, 90), Rate = 6, Speed = 0.8, Size = 0.25, Light = 1 },
}

-- Reshape the body, add accessories and an aura. `allowAura` is false for docked hive copies.
function BeeLooks.Apply(model: Model, def, body: BasePart, allowAura: boolean?)
	local visual = def.Visual or {}
	local shape = visual.Shape
	local reference = model:FindFirstChild("Body") or body
	-- accessories first, in the template body frame, so the reshape below fits them to the body
	local u = math.max(reference.Size.Z, 0.5) / 1.45
	for _, name in visual.Extras or {} do
		if not meshAccessory(model, reference, def, name, u) then
			local builder = EXTRAS[name]
			if builder then
				builder(model, reference, def, u * 1.45)
			end
		end
	end
	if shape then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= body and p ~= reference then
				local rel = reference.CFrame:ToObjectSpace(p.CFrame)
				p.CFrame = reference.CFrame * CFrame.new(rel.Position * shape) * rel.Rotation
				local role = p:GetAttribute("Role") or p.Name
				if RESIZE[role] or p:GetAttribute("Accessory") then
					p.Size *= shape
				end
			end
		end
		reference.Size *= shape
	end
	local aura = visual.Aura and AURAS[visual.Aura]
	if aura and allowAura ~= false then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Aura"
		emitter.Color = ColorSequence.new(aura.Color)
		emitter.LightEmission = aura.Light
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, aura.Size), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(0.5, 1)
		emitter.Speed = NumberRange.new(aura.Speed * 0.5, aura.Speed)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = aura.Rate
		emitter.LockedToPart = false
		emitter.Parent = reference
	end
end

return BeeLooks
