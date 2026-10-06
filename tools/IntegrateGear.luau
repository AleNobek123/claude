--[[
	IntegrateGear (Studio edit-time tool)
	Turns the AI-generated collector and backpack meshes sitting in Workspace (tagged
	"AssistantAIGeneratedAsset", named after their prompt) into per-item templates:
	  ReplicatedStorage.Assets.Collectors.<CollectorId>  (Tool with a Handle MeshPart)
	  ReplicatedStorage.Assets.Backpacks.<BackpackId>    (Model, PrimaryPart "Main")
	ShopService and the Shop panel look templates up by item Id first, then by Shape.
	Generated models that were integrated are removed from Workspace.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- prompt keyword -> item id
local COLLECTORS = {
	["honey scoop"] = { Id = "Scoop", Height = 4.2 },
	["garden rake"] = { Id = "Rake", Height = 4.6 },
	["pruning shears"] = { Id = "Clippers", Height = 4.4 },
	["pollen vacuum"] = { Id = "Vacuum", Height = 4.6 },
	["magic honey wand"] = { Id = "HoneyWand", Height = 4.8 },
	["storm harvester"] = { Id = "StormHarvester", Height = 5 },
	["golden reaper"] = { Id = "GoldenReaper", Height = 5 },
}
local BACKPACKS = {
	["leather pouch"] = { Id = "Pouch", Height = 2 },
	["glass honey jar"] = { Id = "Jar", Height = 2.3 },
	["pollen canister"] = { Id = "Canister", Height = 2.5 },
	["adventurer satchel"] = { Id = "Satchel", Height = 2.4 },
	["beehive backpack"] = { Id = "HivePack", Height = 2.8 },
	["porcelain tank"] = { Id = "PorcelainTank", Height = 3 },
	["royal reservoir"] = { Id = "RoyalReservoir", Height = 3.2 },
}

local function folder(name: string, parent: Instance)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function match(name: string, map)
	local lower = name:lower()
	for key, info in map do
		if lower:find(key, 1, true) then
			return info
		end
	end
	return nil
end

-- the single mesh of a generated model, scaled so its height matches `height`, upright, centred
local function mesh(model: Model, height: number): MeshPart?
	local part = model:FindFirstChildWhichIsA("MeshPart", true)
	if not part then
		return nil
	end
	local clone = part:Clone()
	local scale = height / clone.Size.Y
	clone.Size *= scale
	clone.CFrame = CFrame.new(0, 100, 0) * clone.CFrame.Rotation
	clone.Anchored = false
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Massless = true
	return clone
end

return function()
	local assets = folder("Assets", ReplicatedStorage)
	local collectors = folder("Collectors", assets)
	local backpacks = folder("Backpacks", assets)
	local log = {}
	for _, model in Workspace:GetChildren() do
		if not (model:IsA("Model") and CollectionService:HasTag(model, "AssistantAIGeneratedAsset")) then
			continue
		end
		local collector = match(model.Name, COLLECTORS)
		local backpack = not collector and match(model.Name, BACKPACKS)
		if collector then
			local handle = mesh(model, collector.Height)
			if handle then
				local old = collectors:FindFirstChild(collector.Id)
				if old then
					old:Destroy()
				end
				local tool = Instance.new("Tool")
				tool.Name = collector.Id
				tool.CanBeDropped = false
				handle.Name = "Handle"
				handle.Parent = tool
				-- hold the shaft about a quarter of the way up
				tool.Grip = CFrame.new(0, -(handle.Size.Y / 2 - handle.Size.Y * 0.22), 0)
				tool.Parent = collectors
				model:Destroy()
				table.insert(log, "collector " .. collector.Id)
			end
		elseif backpack then
			local main = mesh(model, backpack.Height)
			if main then
				local old = backpacks:FindFirstChild(backpack.Id)
				if old then
					old:Destroy()
				end
				local pack = Instance.new("Model")
				pack.Name = backpack.Id
				main.Name = "Main"
				main.Anchored = true
				main.Parent = pack
				pack.PrimaryPart = main
				pack:SetAttribute("Yaw", math.pi) -- generated meshes face -Z; turn the decorated side outward
				pack.Parent = backpacks
				model:Destroy()
				table.insert(log, "backpack " .. backpack.Id)
			end
		end
	end
	return #log > 0 and table.concat(log, "\n") or "no generated gear found"
end
