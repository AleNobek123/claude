--[[
	HiveDisplay
	Makes the physical hives look alive: every bee in a hive roster gets a docked copy sitting in
	its own hex cell, facing out of the hive.
	  - owner nearby (converting, visiting): bees are awake, wings buzzing, bobbing in their cells
	  - owner away: bees sleep, wings still, slow breathing and a drifting "z" over some cells
	Client-only and cheap: models are anchored, moved with one BulkMoveTo per frame, and hives
	further than ANIMATE_DISTANCE from the camera keep their last pose without updating.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HiveDisplay = {}

local C
local folder: Folder
local docks = {} -- [hiveIndex] = { UserId, Bees = { [slot] = Dock } }

local ANIMATE_DISTANCE = 150
local AWAKE_DISTANCE = 45
local Z_DISTANCE = 70
local FILL = 0.62 -- share of the cell diameter the bee occupies

local function role(part: BasePart): string
	return part:GetAttribute("Role") or part.Name
end

local function cellOf(hiveIndex: number, slot: number): (BasePart?, Vector3?)
	local map = Workspace:FindFirstChild("Map")
	local hive = map and map:FindFirstChild("Hives") and map.Hives:FindFirstChild("Hive_" .. hiveIndex)
	local cell = hive and hive:FindFirstChild("Cells") and hive.Cells:FindFirstChild("Cell_" .. slot)
	return cell, hive and hive:GetAttribute("Forward")
end

local function padOf(hiveIndex: number): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local hive = map and map:FindFirstChild("Hives") and map.Hives:FindFirstChild("Hive_" .. hiveIndex)
	return hive and hive:FindFirstChild("Pad")
end

function HiveDisplay:_build(hiveIndex: number, slot: number, info)
	local cell, forward = cellOf(hiveIndex, slot)
	if not cell or not C.BeeRenderer then
		return nil
	end
	local model = C.BeeRenderer.Build(info.Id, info.Mutation)
	if not model then
		return nil
	end
	-- docked copies skip the per-bee lights/smoke (dozens per hive would be expensive)
	for _, obj in model:GetDescendants() do
		if obj:IsA("Light") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("ParticleEmitter") then
			obj:Destroy()
		elseif obj:IsA("BasePart") and (obj.Name == "Bubble" or obj.Name == "Ring") then
			obj:Destroy() -- oversized accessories would shrink the docked bee
		end
	end
	local _, size = model:GetBoundingBox()
	local diameter = math.max(cell.Size.X, cell.Size.Y, cell.Size.Z)
	model:ScaleTo(model:GetScale() * (diameter * FILL) / math.max(size.X, size.Y, size.Z))
	local body = model.PrimaryPart
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local offset = body.CFrame:ToObjectSpace(part.CFrame)
			local r = role(part)
			table.insert(parts, {
				Part = part,
				Offset = offset,
				Wing = (r == "WingL" and 1) or (r == "WingR" and -1) or 0,
				Hinge = CFrame.new(0, offset.Position.Y, offset.Position.Z),
			})
		end
	end
	forward = forward or Vector3.new(0, 0, 1)
	local base = CFrame.lookAt(cell.Position + forward * 0.6, cell.Position + forward * 2)
	model.Parent = folder
	return {
		Id = info.Id,
		Mutation = info.Mutation,
		Model = model,
		Parts = parts,
		Base = base,
		Phase = math.random() * math.pi * 2,
		Zzz = nil,
	}
end

local function destroyDock(dock)
	dock.Model:Destroy()
	if dock.Zzz then
		dock.Zzz:Destroy()
	end
end

-- Sync dock models with BeeRenderer's rosters (cheap; runs twice a second)
function HiveDisplay:_sync()
	local swarms = C.BeeRenderer and C.BeeRenderer:Swarms() or {}
	for hiveIndex, hive in docks do
		local swarm = swarms[hiveIndex]
		if not swarm or swarm.UserId ~= hive.UserId then
			for _, dock in hive.Bees do
				destroyDock(dock)
			end
			docks[hiveIndex] = nil
		end
	end
	for hiveIndex, swarm in swarms do
		local hive = docks[hiveIndex]
		if not hive then
			hive = { UserId = swarm.UserId, Bees = {} }
			docks[hiveIndex] = hive
		end
		for slot, dock in hive.Bees do
			local bee = swarm.Bees[slot]
			if not bee or bee.Id ~= dock.Id or bee.Mutation ~= dock.Mutation then
				destroyDock(dock)
				hive.Bees[slot] = nil
			end
		end
		for slot, bee in swarm.Bees do
			if not hive.Bees[slot] then
				hive.Bees[slot] = self:_build(hiveIndex, slot, bee)
			end
		end
	end
end

local function makeZzz(dock)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Zzz"
	gui.Size = UDim2.fromOffset(40, 40)
	gui.StudsOffset = Vector3.new(0.6, 1.2, 0)
	gui.MaxDistance = Z_DISTANCE
	gui.LightInfluence = 0
	gui.Adornee = dock.Model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "z"
	label.TextColor3 = Color3.fromRGB(220, 235, 255)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 60, 110)
	stroke.Thickness = 2
	stroke.Parent = label
	gui.Parent = folder
	return gui
end

function HiveDisplay:_step()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local t = os.clock()
	local parts, cframes = {}, {}
	local swarms = C.BeeRenderer and C.BeeRenderer:Swarms() or {}
	local dayNight = C.DayNightBeeController
	for hiveIndex, hive in docks do
		local pad = padOf(hiveIndex)
		if not pad or (pad.Position - camPos).Magnitude > ANIMATE_DISTANCE then
			continue
		end
		local owner = Players:GetPlayerByUserId(hive.UserId)
		local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		local awake = root ~= nil and (root.Position - pad.Position).Magnitude < AWAKE_DISTANCE
		local showZ = not awake and (pad.Position - camPos).Magnitude < Z_DISTANCE
		local swarm = swarms[hiveIndex]
		for slot, dock in hive.Bees do
			-- the real bee is asleep in this cell tonight: hide the docked copy
			local real = swarm and swarm.Bees[slot]
			if dayNight and dayNight:IsSleeping(real) then
				if dock.Model.Parent then
					dock.Model.Parent = nil
				end
				if dock.Zzz then
					dock.Zzz:Destroy()
					dock.Zzz = nil
				end
				continue
			elseif not dock.Model.Parent then
				dock.Model.Parent = folder
			end
			local cf
			local flap = 0
			if awake then
				local bob = math.sin(t * 4 + dock.Phase) * 0.12
				local sway = math.sin(t * 2.3 + dock.Phase) * 0.18
				cf = dock.Base * CFrame.new(0, bob, 0.15) * CFrame.Angles(0, sway, 0)
				flap = math.sin(t * 42 + dock.Phase) * 0.6
			else
				-- sleeping: slow breathing and a sleepy head tilt, wings folded
				local breathe = math.sin(t * 1.3 + dock.Phase) * 0.04
				cf = dock.Base * CFrame.new(0, breathe - 0.05, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(8 + breathe * 60))
			end
			for _, entry in dock.Parts do
				local offset = entry.Offset
				if entry.Wing ~= 0 and flap ~= 0 then
					offset = entry.Hinge * CFrame.Angles(0, 0, flap * entry.Wing) * entry.Hinge:Inverse() * offset
				end
				table.insert(parts, entry.Part)
				table.insert(cframes, cf * offset)
			end
			-- a few sleepers get a drifting "z"
			local wantsZ = showZ and slot % 3 == 1
			if wantsZ and not dock.Zzz then
				dock.Zzz = makeZzz(dock)
			elseif not wantsZ and dock.Zzz then
				dock.Zzz:Destroy()
				dock.Zzz = nil
			end
			if dock.Zzz then
				local cycle = (t * 0.45 + dock.Phase) % 1
				dock.Zzz.StudsOffset = Vector3.new(0.6 + cycle * 0.5, 1 + cycle * 1.8, 0)
				local label = dock.Zzz:FindFirstChildOfClass("TextLabel")
				label.TextTransparency = cycle < 0.2 and (1 - cycle / 0.2) or (cycle - 0.2) / 0.8
				label.UIStroke.Transparency = label.TextTransparency
				label.Size = UDim2.fromScale(0.5 + cycle * 0.5, 0.5 + cycle * 0.5)
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	self:_spinFountain(camPos, t)
end

-- The golden bee on the plaza fountain slowly turns and bobs
local fountainBee: Model? = nil
local fountainBase: CFrame? = nil
function HiveDisplay:_spinFountain(camPos: Vector3, t: number)
	if not fountainBee or not fountainBee.Parent then
		local map = Workspace:FindFirstChild("Map")
		local fountain = map and map:FindFirstChild("BeeFountain")
		fountainBee = fountain and fountain:FindFirstChild("GoldenBee")
		fountainBase = fountainBee and fountainBee:GetPivot()
		if not fountainBee then
			return
		end
	end
	if (fountainBase.Position - camPos).Magnitude < ANIMATE_DISTANCE then
		fountainBee:PivotTo(fountainBase * CFrame.new(0, math.sin(t * 1.5) * 0.6, 0) * CFrame.Angles(0, t * 0.6, 0))
	end
end

function HiveDisplay:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "HiveBees"
	folder.Parent = Workspace
end

function HiveDisplay:Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(self._sync, self)
			if not ok then
				warn("[HiveDisplay] " .. tostring(err))
			end
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(function()
		self:_step()
	end)
end

return HiveDisplay
