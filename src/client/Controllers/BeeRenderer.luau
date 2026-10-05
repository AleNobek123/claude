--[[
	BeeRenderer
	Draws every bee on the client from task messages. The server only says
	"bee (hive 3, slot 7) flies to P, starting at server time T, for D seconds";
	this module turns that into smooth motion every frame.

	Optimizations:
	  - Bee models exist only on clients (never replicated instances).
	  - All parts are anchored and moved in one workspace:BulkMoveTo call per frame.
	  - Distance LOD: beyond 110 studs a bee updates every 3rd frame and stops flapping;
	    beyond 320 studs it is unparented and skipped entirely.
	  - Follow/hover motion is procedural, so idle bees cost zero network traffic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local BeeCodec = require(Shared.BeeCodec)
local Net = require(Shared.Net)

local TASK = BeeCodec.Task
local CULL_DISTANCE = 320
local LOD_DISTANCE = 110
local FLAP_DISTANCE = 70
local RARITY_SCALE = { Legendary = 1.15, Mythic = 1.3 }

local BeeRenderer = {}

local C
local folder: Folder
local swarms = {} -- [hiveIndex] = { UserId = number, Bees = { [slot] = RenderBee } }
local frameCount = 0
local partsBuffer: { BasePart } = {}
local cframeBuffer: { CFrame } = {}

-- Model preparation ----------------------------------------------------------------------------

local function fallbackTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "Bee"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.2, 1.2, 1.2)
	body:SetAttribute("Role", "Body")
	body.Parent = model
	model.PrimaryPart = body
	return model
end

local function template(): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local bees = assets and assets:FindFirstChild("Bees")
	local found = bees and bees:FindFirstChild("Bee")
	return found or fallbackTemplate()
end

local function role(part: BasePart): string
	return part:GetAttribute("Role") or part.Name
end

local function buildModel(def, mutation: string?)
	local model = template():Clone()
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	model.PrimaryPart = body

	-- accessories: keep only the one this bee wears
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local r = role(part)
			if (r == "Crown" or r == "Halo") and def.Visual.Accessory ~= r then
				part:Destroy()
			end
		end
	end

	local scale = RARITY_SCALE[def.Rarity]
	if scale then
		model:ScaleTo(scale)
	end

	local mutationDef = mutation and Config.Mutations[mutation]
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			local r = role(part)
			if r == "Body" then
				part.Color = def.Visual.Body
			elseif r == "Stripe" or r == "Stripes" then
				part.Color = def.Visual.Stripe
				if mutation == "Neon" then
					part.Material = Enum.Material.Neon
					part.Color = mutationDef.Color
				end
			elseif r == "Eye" or r == "Eyes" then
				if mutation == "Shadow" then
					part.Material = Enum.Material.Neon
					part.Color = mutationDef.Color
				end
			end
		end
	end

	if mutation == "Gifted" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mutationDef.Color
		sparkles.Parent = body
	elseif mutation == "Neon" then
		local light = Instance.new("PointLight")
		light.Color = mutationDef.Color
		light.Range = 7
		light.Brightness = 1.5
		light.Parent = body
	elseif mutation == "Shadow" then
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(40, 20, 60)
		smoke.Size = 0.5
		smoke.Opacity = 0.25
		smoke.RiseVelocity = 1
		smoke.Parent = body
	end

	-- offsets from the body; wings remember their hinge for flapping
	local parts = {}
	local bodyCF = body.CFrame
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local offset = bodyCF:ToObjectSpace(part.CFrame)
			local r = role(part)
			local wing = (r == "WingL" and 1) or (r == "WingR" and -1) or 0
			table.insert(parts, {
				Part = part,
				Offset = offset,
				Wing = wing,
				Hinge = CFrame.new(0, offset.Position.Y, offset.Position.Z),
			})
		end
	end
	return model, parts
end

-- Public builder (hive UI viewports, hatch cutscene); returns a ready model
function BeeRenderer.Build(beeId: string, mutation: string?): Model?
	local def = BeeData.Bees[beeId]
	if not def then
		return nil
	end
	local model = buildModel(def, mutation)
	return model
end

-- Swarm management --------------------------------------------------------------------------------

local function ownerRoot(swarm): BasePart?
	local owner = Players:GetPlayerByUserId(swarm.UserId)
	local character = owner and owner.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function BeeRenderer:_createBee(swarm, slot: number, info)
	local def = BeeData.Bees[info.Id]
	if not def then
		return nil
	end
	local model, parts = buildModel(def, info.Mutation)
	local root = ownerRoot(swarm)
	local start = root and root.Position + Vector3.new(math.random(-3, 3), 3, math.random(-3, 3)) or Vector3.new(0, 10, 0)
	model.Parent = folder
	return {
		Id = info.Id,
		Mutation = info.Mutation,
		Model = model,
		Parts = parts,
		Position = start,
		StartPos = start,
		Look = Vector3.new(0, 0, -1),
		Task = nil,
		Phase = math.random() * math.pi * 2,
		Ring = slot % 4,
		Visible = true,
	}
end

function BeeRenderer:SetSwarm(hiveIndex: number, userId: number, bees, _synergies)
	local swarm = swarms[hiveIndex]
	if not bees then
		if swarm then
			for _, bee in swarm.Bees do
				bee.Model:Destroy()
			end
		end
		swarms[hiveIndex] = nil
		return
	end
	if not swarm or swarm.UserId ~= userId then
		if swarm then
			for _, bee in swarm.Bees do
				bee.Model:Destroy()
			end
		end
		swarm = { UserId = userId, Bees = {} }
		swarms[hiveIndex] = swarm
	end
	-- remove bees that left or changed
	for slot, bee in swarm.Bees do
		local info = bees[tostring(slot)]
		if not info or info.Id ~= bee.Id or info.Mutation ~= bee.Mutation then
			bee.Model:Destroy()
			swarm.Bees[slot] = nil
		end
	end
	-- add new ones
	for key, info in bees do
		local slot = tonumber(key)
		if slot and not swarm.Bees[slot] then
			swarm.Bees[slot] = self:_createBee(swarm, slot, info)
		end
	end
end

function BeeRenderer:ApplyTasks(records)
	for _, record in records do
		local swarm = swarms[record.Hive]
		local bee = swarm and swarm.Bees[record.Slot]
		if bee then
			bee.StartPos = bee.Position
			bee.Task = record
		end
	end
end

function BeeRenderer:GetBeePosition(hiveIndex: number, slot: number): Vector3?
	local swarm = swarms[hiveIndex]
	local bee = swarm and swarm.Bees[slot]
	return bee and bee.Position or nil
end

-- Motion ----------------------------------------------------------------------------------------------

local function damp(a: Vector3, b: Vector3, dt: number, k: number): Vector3
	return a:Lerp(b, 1 - math.exp(-k * dt))
end

function BeeRenderer:_evaluate(bee, root: BasePart?, now: number, t: number, dt: number): Vector3
	local task = bee.Task
	local kind = task and task.Task or TASK.Follow

	if kind == TASK.Follow then
		if not root then
			return bee.Position
		end
		local angle = t * 0.9 + bee.Phase
		local radius = 2.6 + bee.Ring * 0.9
		local goal = root.Position
			+ Vector3.new(math.cos(angle) * radius, 2.2 + bee.Ring * 0.3 + math.sin(t * 1.8 + bee.Phase) * 0.5, math.sin(angle) * radius)
		return damp(bee.Position, goal, dt, 5)
	end

	if kind == TASK.Gather or kind == TASK.Rest then
		local hover = Vector3.new(math.sin(t * 3 + bee.Phase) * 0.4, 0.2 + math.sin(t * 5 + bee.Phase) * 0.25, math.cos(t * 3 + bee.Phase) * 0.4)
		return damp(bee.Position, task.Target + hover, dt, 8)
	end

	local goal = task.Target
	if kind == TASK.ToOwner and root then
		goal = root.Position + Vector3.new(0, 2.2, 0)
	elseif kind == TASK.Attack then
		local monsterPos = C.MonsterRenderer and C.MonsterRenderer:GetPosition(task.TargetId)
		goal = monsterPos and (monsterPos + Vector3.new(0, 1.5, 0)) or goal
	end

	local alpha = task.Duration > 0 and math.clamp((now - task.Start) / task.Duration, 0, 1) or 1
	if alpha >= 1 then
		if kind == TASK.Attack then
			return goal + Vector3.new(0, math.sin(t * 22) * 0.5, 0)
		end
		return damp(bee.Position, goal, dt, 10)
	end
	local eased = alpha * alpha * (3 - 2 * alpha)
	local base = bee.StartPos:Lerp(goal, eased)
	local arc = math.sin(alpha * math.pi) * math.min(3.5, (goal - bee.StartPos).Magnitude * 0.12)
	local wobble = Vector3.new(math.sin(t * 6 + bee.Phase) * 0.15, math.sin(t * 7.3 + bee.Phase) * 0.15, 0)
	return base + Vector3.new(0, arc, 0) + wobble
end

function BeeRenderer:_step(dt: number)
	frameCount += 1
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local now = Workspace:GetServerTimeNow()
	local t = os.clock()
	table.clear(partsBuffer)
	table.clear(cframeBuffer)

	for _, swarm in swarms do
		local root = ownerRoot(swarm)
		for slot, bee in swarm.Bees do
			local position = self:_evaluate(bee, root, now, t, dt)
			local moved = position - bee.Position
			bee.Position = position

			local distance = (position - camPos).Magnitude
			if distance > CULL_DISTANCE then
				if bee.Visible then
					bee.Visible = false
					bee.Model.Parent = nil
				end
				continue
			elseif not bee.Visible then
				bee.Visible = true
				bee.Model.Parent = folder
			end
			if distance > LOD_DISTANCE and (frameCount + slot) % 3 ~= 0 then
				continue
			end

			if moved.Magnitude > 0.01 then
				local flat = Vector3.new(moved.X, moved.Y * 0.4, moved.Z)
				if flat.Magnitude > 0.001 then
					bee.Look = bee.Look:Lerp(flat.Unit, math.min(1, dt * 10))
				end
			end
			local look = bee.Look.Magnitude > 0.01 and bee.Look.Unit or Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(position, position + look)
			local flap = distance < FLAP_DISTANCE and math.sin(t * 45 + bee.Phase) * 0.6 or 0

			for _, entry in bee.Parts do
				local offset = entry.Offset
				if entry.Wing ~= 0 and flap ~= 0 then
					offset = entry.Hinge * CFrame.Angles(0, 0, flap * entry.Wing) * entry.Hinge:Inverse() * offset
				end
				table.insert(partsBuffer, entry.Part)
				table.insert(cframeBuffer, cf * offset)
			end
		end
	end

	if #partsBuffer > 0 then
		Workspace:BulkMoveTo(partsBuffer, cframeBuffer, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Lifecycle -------------------------------------------------------------------------------------------

function BeeRenderer:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "ClientBees"
	folder.Parent = Workspace
end

function BeeRenderer:Start()
	Net.Event("SwarmUpdate").OnClientEvent:Connect(function(hiveIndex, userId, bees, synergies)
		self:SetSwarm(hiveIndex, userId, bees, synergies)
	end)
	Net.Event("BeeTasks").OnClientEvent:Connect(function(buf)
		self:ApplyTasks(BeeCodec.Decode(buf))
	end)

	local ok, list = pcall(function()
		return Net.Function("GetSwarms"):InvokeServer()
	end)
	if ok and list then
		for _, entry in list do
			self:SetSwarm(entry.Hive, entry.UserId, entry.Bees, entry.Synergies)
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		self:_step(dt)
	end)
end

return BeeRenderer
