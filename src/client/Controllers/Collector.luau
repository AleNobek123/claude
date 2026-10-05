--[[
	Collector
	Click or hold with the collector tool to harvest. The client only paces requests to
	the collector's cooldown and plays the swing; the server decides what is harvested.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Collector = {}

local C
local tool: Tool? = nil
local holding = false
local lastFire = 0
local baseGrip: CFrame? = nil
local connections = {}

local function inAnyField(position: Vector3)
	for _, def in Config.Fields do
		local half = def.Tiles * Config.Tiles.Size / 2 + 1
		local d = position - def.Center
		if math.abs(d.X) <= half and math.abs(d.Z) <= half and d.Y > -5 and d.Y < 30 then
			return def
		end
	end
	return nil
end

local function disconnectTool()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if tool and baseGrip then
		tool.Grip = baseGrip
	end
	tool = nil
	holding = false
end

local function bindTool(newTool: Tool)
	disconnectTool()
	tool = newTool
	baseGrip = newTool.Grip
	table.insert(connections, newTool.Activated:Connect(function()
		holding = true
	end))
	table.insert(connections, newTool.Deactivated:Connect(function()
		holding = false
	end))
	table.insert(connections, newTool.Unequipped:Connect(function()
		disconnectTool()
	end))
end

function Collector:_swing(cooldown: number)
	if not tool or not baseGrip then
		return
	end
	local down = TweenService:Create(tool, TweenInfo.new(cooldown * 0.35, Enum.EasingStyle.Quad), {
		Grip = baseGrip * CFrame.Angles(math.rad(65), 0, 0),
	})
	down:Play()
	down.Completed:Once(function()
		if tool and baseGrip then
			TweenService:Create(tool, TweenInfo.new(cooldown * 0.4, Enum.EasingStyle.Quad), { Grip = baseGrip }):Play()
		end
	end)
end

-- Petals and glowing dust fly from the harvested flowers into the collector
function Collector:_harvestFx(center: Vector3, radius: number)
	local renderer = C.FieldRenderer
	local head = tool and (tool:FindFirstChild("Head") or tool:FindFirstChild("Handle"))
	if not renderer or not head then
		return
	end
	local low = C.Settings and C.Settings:Low()
	local flowers = renderer:FlowersNear(center, radius + 2, low and 4 or 10)
	for i, flower in flowers do
		task.delay(i * 0.02, function()
			local petal = Instance.new("Part")
			petal.Size = Vector3.new(0.5, 0.08, 0.32)
			petal.Color = flower.Color
			petal.Material = Enum.Material.SmoothPlastic
			petal.Anchored = true
			petal.CanCollide = false
			petal.CanQuery = false
			petal.CastShadow = false
			petal.CFrame = CFrame.new(flower.Position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			petal.Parent = Workspace
			local spin = CFrame.Angles(math.random() * 8, math.random() * 8, 0)
			local tween = TweenService:Create(petal, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(head.Position) * spin,
				Size = Vector3.new(0.1, 0.02, 0.06),
			})
			tween:Play()
			tween.Completed:Once(function()
				petal:Destroy()
			end)
		end)
	end
	if C.Fx and not low then
		C.Fx:Burst(center, Color3.fromRGB(255, 240, 150), 8)
	end
	C.Sound:Play("Swish", { Vary = 0.25, Volume = 0.8 })
end

function Collector:Init(controllers)
	C = controllers
end

function Collector:Start()
	local collect = Net.Event("Collect")

	local function hookCharacter(character: Model)
		disconnectTool()
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("CollectorId") then
				bindTool(child)
			end
		end)
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("CollectorId") then
				bindTool(child)
			end
		end
	end
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		hookCharacter(player.Character)
	end

	RunService.Heartbeat:Connect(function()
		if not holding or not tool or not C.State.Data then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or tool.Parent ~= character then
			return
		end
		local def = Config.CollectorById[C.State.Data.Collector]
		if not def then
			return
		end
		local now = os.clock()
		if now - lastFire < def.Cooldown then
			return
		end
		lastFire = now
		self:_swing(def.Cooldown)
		local field = inAnyField(root.Position)
		if field then
			collect:FireServer()
			local look = root.CFrame.LookVector
			local center = root.Position + Vector3.new(look.X, 0, look.Z) * math.max(2, def.Radius * 0.6)
			local ground = Vector3.new(center.X, field.Center.Y, center.Z)
			if C.Fx then
				C.Fx:Ring(ground, def.Radius, Color3.fromRGB(255, 255, 220), 0.35)
			end
			self:_harvestFx(ground, def.Radius)
		end
	end)
end

return Collector
