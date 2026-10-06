--[[
	BuildVariants (Studio edit-time tool)
	Creates the premium reskins listed in Config (items with Model + Variant): clones the base
	item's template, strips its texture and applies the variant colour and material, and saves
	it under the variant's own Id in Assets.Collectors / Assets.Backpacks. Runtime code then
	just clones templates by Id, so no texture work happens while playing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function restyle(model: Instance, variant)
	for _, obj in model:GetDescendants() do
		if obj:IsA("SurfaceAppearance") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			if obj:IsA("MeshPart") then
				obj.TextureID = ""
			end
			obj.Color = variant.Color
			obj.Material = variant.Material or Enum.Material.SmoothPlastic
			if obj.Material == Enum.Material.Glass then
				obj.Transparency = 0.15
				obj.Reflectance = 0.1
			end
		end
	end
	-- glowing reskins carry a soft light so they read as premium
	if variant.Material == Enum.Material.Neon then
		local part = model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local light = Instance.new("PointLight")
			light.Color = variant.Color
			light.Range = 6
			light.Brightness = 0.8
			light.Parent = part
		end
	end
end

return function(Config)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local log = {}
	for kind, list in { Collectors = Config.Collectors, Backpacks = Config.Backpacks } do
		local folder = assets:FindFirstChild(kind)
		for _, def in list do
			if def.Model and def.Variant and folder then
				local base = folder:FindFirstChild(def.Model)
				if base then
					local old = folder:FindFirstChild(def.Id)
					if old then
						old:Destroy()
					end
					local clone = base:Clone()
					clone.Name = def.Id
					restyle(clone, def.Variant)
					clone.Parent = folder
					table.insert(log, kind .. "/" .. def.Id)
				else
					table.insert(log, "missing base " .. def.Model)
				end
			end
		end
	end
	return table.concat(log, ", ")
end
