--[[
	Fx
	Client-only visual effects driven by the server's "Fx" and "Token" remotes:
	floating "+N" popups, ability rings and bursts, meteors, level-ups and honey tokens.
	Everything here is cosmetic; the server already applied the gameplay effect.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Fx = {}

local C
local folder: Folder
local tokens = {} -- [id] = { Part, Claimed }

local COLORS = {
	Fire = Color3.fromRGB(255, 110, 40),
	Frost = Color3.fromRGB(150, 225, 255),
	Bomb = Color3.fromRGB(255, 200, 60),
	Strike = Color3.fromRGB(255, 70, 70),
	Shadow = Color3.fromRGB(120, 60, 200),
	Gold = Color3.fromRGB(255, 215, 60),
	Solar = Color3.fromRGB(255, 240, 140),
	Void = Color3.fromRGB(140, 60, 255),
	Supernova = Color3.fromRGB(255, 80, 20),
	Water = Color3.fromRGB(90, 180, 255),
	Nature = Color3.fromRGB(110, 220, 90),
	Electric = Color3.fromRGB(255, 245, 110),
	Toxic = Color3.fromRGB(160, 240, 60),
	Candy = Color3.fromRGB(255, 140, 210),
}

local function anchorPart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	return part
end

function Fx:Popup(position: Vector3, text: string, color: Color3, big: boolean?)
	local part = anchorPart(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(big and 220 or 150, big and 60 or 40)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 1, 0)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffset = gui.StudsOffset + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(part, 1.2)
end

function Fx:Ring(position: Vector3, radius: number, color: Color3, duration: number?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, (duration or 0.6) + 0.1)
end

function Fx:Burst(position: Vector3, color: Color3, count: number?)
	if C.Settings and C.Settings:Low() then
		count = math.ceil((count or 18) / 3)
	end
	local part = anchorPart(position + Vector3.new(0, 1, 0))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(count or 18)
	Debris:AddItem(part, 1.2)
end

function Fx:Meteor(target: Vector3, delay: number)
	local rock = Instance.new("Part")
	rock.Shape = Enum.PartType.Ball
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.Material = Enum.Material.Neon
	rock.Color = Color3.fromRGB(255, 150, 40)
	rock.Size = Vector3.new(4, 4, 4)
	local start = target + Vector3.new(30, 90, 18)
	rock.CFrame = CFrame.new(start)
	rock.Parent = folder
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = rock
	local tween = TweenService:Create(rock, TweenInfo.new(delay, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target) })
	tween:Play()
	tween.Completed:Connect(function()
		rock:Destroy()
		self:Ring(target, 10, Color3.fromRGB(255, 170, 50), 0.8)
		self:Burst(target, Color3.fromRGB(255, 200, 80), 30)
	end)
end

-- Server FX -------------------------------------------------------------------------------------

function Fx:_onFx(kind: string, payload)
	if kind == "Pollen" then
		self:Popup(payload.Position + Vector3.new(0, 2, 0), "+" .. Format.Short(payload.Amount), Color3.fromRGB(255, 250, 200))
	elseif kind == "Honey" then
		self:Popup(payload.Position, "+" .. Format.Short(payload.Amount), Color3.fromRGB(255, 200, 50), true)
		C.Sound:Play("Coin", { Volume = 0.6 })
	elseif kind == "Ability" then
		local color = COLORS[payload.Fx] or Color3.new(1, 1, 1)
		for _, point in payload.Points or {} do
			self:Ring(point, payload.Radius or 6, color)
			self:Burst(point, color, 14)
		end
		local myHive = player:GetAttribute("HiveIndex")
		if payload.Name and payload.Points and payload.Points[1] and payload.Hive == myHive then
			self:Popup(payload.Points[1] + Vector3.new(0, 4, 0), payload.Name .. "!", color)
		end
	elseif kind == "Meteor" then
		self:Meteor(payload.Position, payload.Delay or 1.2)
	elseif kind == "LevelUp" then
		local renderer = C.BeeRenderer
		local pos = renderer and renderer:GetBeePosition(payload.Hive, payload.Slot)
		if pos then
			self:Popup(pos + Vector3.new(0, 1.5, 0), "Level " .. payload.Level .. "!", Color3.fromRGB(140, 255, 140))
			if payload.Hive == player:GetAttribute("HiveIndex") then
				C.Sound:Play("LevelUp", { Volume = 0.6 })
			end
		end
	end
end

-- Honey Rain tokens ---------------------------------------------------------------------------------

function Fx:_spawnToken(id: number, position: Vector3)
	if tokens[id] then
		return
	end
	local coin = Instance.new("Part")
	coin.Shape = Enum.PartType.Cylinder
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.Material = Enum.Material.Neon
	coin.Color = Color3.fromRGB(255, 200, 40)
	coin.Size = Vector3.new(0.4, 3, 3)
	coin.CFrame = CFrame.new(position)
	coin.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = coin.Color
	light.Range = 8
	light.Parent = coin
	tokens[id] = { Part = coin, Position = position, Claimed = false }
end

function Fx:_removeToken(id: number)
	local token = tokens[id]
	if token then
		self:Burst(token.Position, Color3.fromRGB(255, 210, 60), 10)
		token.Part:Destroy()
		tokens[id] = nil
	end
end

function Fx:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "ClientFx"
	folder.Parent = Workspace
end

function Fx:Start()
	Net.Event("Fx").OnClientEvent:Connect(function(kind, payload)
		self:_onFx(kind, payload)
	end)

	local tokenEvent = Net.Event("Token")
	local claim = Net.Event("ClaimToken")
	tokenEvent.OnClientEvent:Connect(function(op, id, position)
		if op == "Spawn" then
			self:_spawnToken(id, position)
		elseif op == "Gone" then
			self:_removeToken(id)
		end
	end)
	task.spawn(function()
		local ok, _, list = pcall(function()
			return Net.Function("GetEventState"):InvokeServer()
		end)
		if ok and list then
			for _, token in list do
				self:_spawnToken(token.Id, token.Position)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for id, token in tokens do
			token.Part.CFrame = CFrame.new(token.Position + Vector3.new(0, math.sin(t * 3 + id) * 0.4, 0))
				* CFrame.Angles(0, t * 3 + id, math.pi / 2)
			if root and not token.Claimed and (root.Position - token.Position).Magnitude < 6 then
				token.Claimed = true
				claim:FireServer(id)
			end
		end
	end)
end

return Fx
