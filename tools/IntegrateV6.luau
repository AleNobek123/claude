--[[
	IntegrateV6 (Studio edit-time tool)
	Run once after File > Import 3D of BeeTycoon_V6.fbx (Blender export). It turns the imported
	meshes into runtime templates:
	  Assets.BeeAccessories.<Name>  parts in the bee body frame (body centre = origin, front = -Z),
	                                Role attribute = how BeeLooks colours them
	  Assets.Boots.<Style>          parts in the foot frame of a reference foot (1 x 0.55 x 1.5),
	                                Role attribute = how ShopService colours them
	  Assets.Backpacks.<Id>         Blender packs (honey jar, hive pack, porcelain tank), each in a
	                                base palette and a premium reskin palette
	Mesh names come from Blender: Acc_<Name>_<Role>, Boot_<Style>_<Role>, Pack_<Kind>_<Role>, and the
	markers Acc_Ref (the bee body), Boot_Ref_<Style>, Pack_Ref_<Kind> give each asset's origin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function findImport(): Instance?
	for _, container in { Workspace, ReplicatedStorage, game:GetService("ServerStorage") } do
		for _, obj in container:GetDescendants() do
			if obj:IsA("BasePart") and obj.Name == "Acc_Ref" then
				return obj:FindFirstAncestorWhichIsA("Model") or obj.Parent
			end
		end
	end
	return nil
end

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function prep(part: BasePart, role: string, rel: CFrame): BasePart
	local p = part:Clone()
	for _, child in p:GetChildren() do
		if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
	if p:IsA("MeshPart") then
		p.TextureID = ""
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	-- the importer pivots every mesh on its Blender object origin (far away and axis-converted)
	p.PivotOffset = CFrame.new()
	p.CFrame = rel
	p:SetAttribute("Role", role)
	return p
end

-- fixed colours for the jar packs (accessories and boots are coloured at runtime)
local JAR = {
	Glass = { Color3.fromRGB(230, 244, 255), Enum.Material.Glass, 0.55 },
	Honey = { Color3.fromRGB(255, 172, 24), Enum.Material.SmoothPlastic, 0 },
	Wood = { Color3.fromRGB(176, 116, 64), Enum.Material.Wood, 0 },
	Red = { Color3.fromRGB(226, 56, 70), Enum.Material.Fabric, 0 },
	Gold = { Color3.fromRGB(255, 204, 70), Enum.Material.Foil, 0 },
	Leather = { Color3.fromRGB(112, 66, 34), Enum.Material.Fabric, 0 },
}
local CRYSTAL = {
	Glass = { Color3.fromRGB(190, 240, 255), Enum.Material.Glass, 0.35 },
	Honey = { Color3.fromRGB(90, 210, 255), Enum.Material.Neon, 0.1 },
	Wood = { Color3.fromRGB(225, 245, 255), Enum.Material.Ice, 0 },
	Red = { Color3.fromRGB(80, 160, 255), Enum.Material.Fabric, 0 },
	Gold = { Color3.fromRGB(235, 250, 255), Enum.Material.Glass, 0.1 },
	Leather = { Color3.fromRGB(60, 90, 150), Enum.Material.Fabric, 0 },
}

local HIVE = {
	Main = { Color3.fromRGB(255, 192, 52), Enum.Material.SmoothPlastic, 0 },
	Comb = { Color3.fromRGB(236, 158, 28), Enum.Material.SmoothPlastic, 0 },
	Dark = { Color3.fromRGB(62, 36, 16), Enum.Material.SmoothPlastic, 0 },
	Honey = { Color3.fromRGB(255, 170, 20), Enum.Material.Glass, 0.1 },
	Wood = { Color3.fromRGB(150, 98, 52), Enum.Material.Wood, 0 },
	Leather = { Color3.fromRGB(112, 66, 34), Enum.Material.Fabric, 0 },
	Gold = { Color3.fromRGB(255, 220, 110), Enum.Material.Foil, 0 },
}
local FROST = {
	Main = { Color3.fromRGB(205, 238, 255), Enum.Material.Ice, 0 },
	Comb = { Color3.fromRGB(150, 210, 250), Enum.Material.Glass, 0.15 },
	Dark = { Color3.fromRGB(40, 70, 120), Enum.Material.SmoothPlastic, 0 },
	Honey = { Color3.fromRGB(120, 215, 255), Enum.Material.Neon, 0.1 },
	Wood = { Color3.fromRGB(220, 240, 255), Enum.Material.Ice, 0 },
	Leather = { Color3.fromRGB(60, 92, 150), Enum.Material.Fabric, 0 },
	Gold = { Color3.fromRGB(235, 250, 255), Enum.Material.Glass, 0.1 },
}
local PORCELAIN = {
	Main = { Color3.fromRGB(246, 248, 253), Enum.Material.SmoothPlastic, 0 },
	Accent = { Color3.fromRGB(44, 92, 222), Enum.Material.SmoothPlastic, 0 },
	White = { Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, 0 },
	Strap = { Color3.fromRGB(40, 82, 205), Enum.Material.Fabric, 0 },
	Metal = { Color3.fromRGB(200, 206, 216), Enum.Material.Metal, 0 },
}
local GOLDEN = {
	Main = { Color3.fromRGB(255, 204, 60), Enum.Material.Foil, 0 },
	Accent = { Color3.fromRGB(255, 246, 205), Enum.Material.SmoothPlastic, 0 },
	White = { Color3.fromRGB(255, 120, 60), Enum.Material.Neon, 0 },
	Strap = { Color3.fromRGB(150, 92, 32), Enum.Material.Fabric, 0 },
	Metal = { Color3.fromRGB(255, 230, 140), Enum.Material.Foil, 0 },
}

-- Blender pack -> templates: kind = Pack_<kind>_* meshes, Main = the role that becomes "Main"
local PACKS = {
	Jar = { Main = "Glass", Templates = { Jar = JAR, CrystalJar = CRYSTAL } },
	Hive = { Main = "Main", Templates = { HivePack = HIVE, FrostHive = FROST } },
	Tank = { Main = "Main", Templates = { PorcelainTank = PORCELAIN, GoldenTank = GOLDEN } },
}

local function paint(model: Model, palette)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local entry = palette[p:GetAttribute("Role")]
			if entry then
				p.Color, p.Material, p.Transparency = entry[1], entry[2], entry[3]
			end
		end
	end
end

return function()
	local import = findImport()
	if not import then
		return "Import BeeTycoon_V6.fbx first (File > Import 3D)"
	end
	local meshes = {}
	for _, obj in import:GetDescendants() do
		if obj:IsA("BasePart") then
			meshes[obj.Name] = obj
		end
	end
	local assets = folder(ReplicatedStorage, "Assets")
	local log = {}

	-- bee accessories ---------------------------------------------------------------------------
	local ref = meshes.Acc_Ref
	local accFolder = folder(assets, "BeeAccessories")
	accFolder:ClearAllChildren()
	local acc = {}
	for name, part in meshes do
		local item, role = name:match("^Acc_(%w+)_(%w+)$")
		if item and item ~= "Ref" then
			local model = acc[item]
			if not model then
				model = Instance.new("Model")
				model.Name = item
				model.Parent = accFolder
				acc[item] = model
			end
			prep(part, role, ref.CFrame:ToObjectSpace(part.CFrame)).Parent = model
		end
	end
	local count = 0
	for _ in acc do
		count += 1
	end
	table.insert(log, count .. " accessories")

	-- boots -----------------------------------------------------------------------------------------
	local bootFolder = folder(assets, "Boots")
	bootFolder:ClearAllChildren()
	local styles = 0
	for name, marker in meshes do
		local style = name:match("^Boot_Ref_(%w+)$")
		if style then
			local model = Instance.new("Model")
			model.Name = style
			for partName, part in meshes do
				local s, role = partName:match("^Boot_(%w+)_(%w+)$")
				if s == style and role ~= "Ref" and not partName:match("^Boot_Ref_") then
					prep(part, role, marker.CFrame:ToObjectSpace(part.CFrame)).Parent = model
				end
			end
			model:SetAttribute("FootSize", Vector3.new(1, 0.55, 1.5))
			model.Parent = bootFolder
			styles += 1
		end
	end
	table.insert(log, styles .. " boot styles")

	-- backpacks: one Blender model, two palettes each (base pack + its premium reskin) ----------
	local backpacks = folder(assets, "Backpacks")
	for kind, info in PACKS do
		local ref = meshes["Pack_Ref_" .. kind]
		if ref then
			local base = Instance.new("Model")
			for partName, part in meshes do
				local role = partName:match("^Pack_" .. kind .. "_(%w+)$")
				if role then
					local p = prep(part, role, ref.CFrame:ToObjectSpace(part.CFrame))
					p.Name = role == info.Main and "Main" or role
					p.Parent = base
				end
			end
			base.PrimaryPart = base:FindFirstChild("Main")
			base:SetAttribute("Yaw", math.pi) -- straps were modelled on +Z; they must face the torso
			base:SetAttribute("Hug", 0.02) -- the strap plate is the front face: rest it on the back
			for id, palette in info.Templates do
				local model = base:Clone()
				model.Name = id
				paint(model, palette)
				local old = backpacks:FindFirstChild(id)
				if old then
					old:Destroy()
				end
				model.Parent = backpacks
				table.insert(log, id)
			end
			base:Destroy()
		end
	end

	import:Destroy()
	return table.concat(log, ", ")
end
