--[[
	Collector
	Click or hold with the collector tool to harvest. The client only paces requests to
	the collector's cooldown and plays the swing; the server decides what is harvested.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
			if C.Fx then
				C.Fx:Ring(Vector3.new(center.X, field.Center.Y, center.Z), def.Radius, Color3.fromRGB(255, 255, 220), 0.35)
			end
		end
	end)
end

return Collector
