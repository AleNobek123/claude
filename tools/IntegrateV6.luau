--[[
	IntegrateV6 (Studio edit-time tool)
	Run once after File > Import 3D of BeeTycoon_V6.fbx (Blender export). It turns the imported
	meshes into runtime templates:
	  Assets.BeeAccessories.<Name>  parts in the bee body frame (body centre = origin, front = -Z),
	                                Role attribute = how BeeLooks colours them
	  Assets.Boots.<Style>          parts in the foot frame of a reference foot (1 x 0.55 x 1.5),
	                                Role attribute = how ShopService colours them
	  Assets.Backpacks.Jar / CrystalJar   coloured honey jar packs (replace the grey textured jar)
	Mesh names come from Blender: Acc_<Name>_<Role>, Boot_<Style>_<Role>, Pack_Jar_<Role>, and the
	markers Acc_Ref (the bee body), Boot_Ref_<Style>, Pack_Ref_Jar give each asset's origin.
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

	-- honey jar packs --------------------------------------------------------------------------------
	local jarRef = meshes.Pack_Ref_Jar
	if jarRef then
		local backpacks = folder(assets, "Backpacks")
		local jar = Instance.new("Model")
		jar.Name = "Jar"
		for partName, part in meshes do
			local role = partName:match("^Pack_Jar_(%w+)$")
			if role then
				local p = prep(part, role, jarRef.CFrame:ToObjectSpace(part.CFrame))
				p.Name = role == "Glass" and "Main" or role
				p.Parent = jar
			end
		end
		jar.PrimaryPart = jar:FindFirstChild("Main")
		jar:SetAttribute("Yaw", math.pi) -- straps were modelled on +Z; they must face the torso
		jar:SetAttribute("Hug", 0.18)
		local crystal = jar:Clone()
		crystal.Name = "CrystalJar"
		paint(jar, JAR)
		paint(crystal, CRYSTAL)
		for _, name in { "Jar", "CrystalJar" } do
			local old = backpacks:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		jar.Parent = backpacks
		crystal.Parent = backpacks
		table.insert(log, "jar packs")
	end

	import:Destroy()
	return table.concat(log, ", ")
end
