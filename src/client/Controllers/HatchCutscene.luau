--[[
	HatchCutscene
	Plays when the server reports a hatch:
	  1. letterbox bars slide in, controls lock, camera flies to the egg
	  2. (nest hatch) honey streams from the player into the nest and the egg drops in
	  3. the egg shakes harder and harder (sinusoidal rotation), glows and sheds light sparks
	  4. flash: the shell bursts, the top flies off, confetti and rays explode
	  5. the 3D bee rises and spins with a holographic rarity title floating up
	Everything is client-side and cosmetic; the result already arrived from the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local HatchCutscene = {}

local C
local UI
local playing = false
local queue = {}

local function tween(obj, time, goals, style, direction)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function controls(enabled: boolean)
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and module then
		local c = module:GetControls()
		if enabled then
			c:Enable()
		else
			c:Disable()
		end
	end
end

-- Egg model: Blender egg (Top/Bottom/Spots) or a simple fallback
local function buildEgg(eggId: string): Model
	local egg = Config.Eggs[eggId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Eggs") and assets.Eggs:FindFirstChild("Egg")
	local model
	if template then
		model = template:Clone()
	else
		model = Instance.new("Model")
		for _, name in { "Bottom", "Top" } do
			local p = Instance.new("Part")
			p.Name = name
			p.Size = Vector3.new(2, 1.3, 2)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			p.CFrame = CFrame.new(0, name == "Top" and 1.9 or 0.65, 0)
			p.Parent = model
		end
		model.PrimaryPart = model.Bottom
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = true
			if part.Name == "Spots" then
				part.Color = egg.Color:Lerp(Color3.fromRGB(255, 180, 40), 0.6)
				part.Material = Enum.Material.SmoothPlastic
			elseif part.Name ~= "Root" then
				part.Color = egg.Color
				part.Material = eggId == "Royal" and Enum.Material.Foil or Enum.Material.SmoothPlastic
			end
		end
	end
	return model
end

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LightEmission = 0.8
	e.Speed = NumberRange.new(10, 22)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	for key, value in props do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function holoTitle(parent: BasePart, rarity: string, name: string, extra: string)
	local color = Config.Rarities[rarity].Color
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 150)
	gui.StudsOffset = Vector3.new(0, 1, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = parent
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = rarity:upper()
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeColor3 = color:Lerp(Color3.new(0, 0, 0), 0.4)
	title.TextStrokeTransparency = 0
	title.TextTransparency = 1
	title.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.fromRGB(120, 230, 255), 0.5)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, color),
	})
	gradient.Parent = title
	local sub = title:Clone()
	sub.Position = UDim2.fromScale(0, 0.5)
	sub.Size = UDim2.new(1, 0, 0.3, 0)
	sub.Text = name
	sub.TextStrokeTransparency = 0.3
	sub.Parent = gui
	sub:FindFirstChildOfClass("UIGradient"):Destroy()
	local tag = sub:Clone()
	tag.Position = UDim2.fromScale(0, 0.82)
	tag.Size = UDim2.new(1, 0, 0.18, 0)
	tag.Text = extra
	tag.TextColor3 = Color3.fromRGB(255, 230, 120)
	tag.Parent = gui
	tween(gui, 1.6, { StudsOffset = Vector3.new(0, 4, 0) }, Enum.EasingStyle.Quint)
	for _, label in { title, sub, tag } do
		tween(label, 0.4, { TextTransparency = 0 })
	end
	local connection = RunService.RenderStepped:Connect(function()
		gradient.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.6, 0)
		gradient.Rotation = 15
	end)
	gui.Destroying:Connect(function()
		connection:Disconnect()
	end)
	return gui
end

local function letterbox(on: boolean, screen: ScreenGui)
	local topBar = screen:FindFirstChild("TopBar")
	local bottomBar = screen:FindFirstChild("BottomBar")
	if not topBar then
		topBar = UI.Create("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, -0.12), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = screen })
		bottomBar = UI.Create("Frame", { Name = "BottomBar", Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = screen })
	end
	tween(topBar, 0.4, { Position = on and UDim2.fromScale(0, 0) or UDim2.fromScale(0, -0.12) })
	tween(bottomBar, 0.4, { Position = on and UDim2.fromScale(0, 0.88) or UDim2.fromScale(0, 1) })
end

function HatchCutscene:Play(result)
	if playing then
		table.insert(queue, result)
		return
	end
	playing = true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		playing = false
		return
	end
	local camera = Workspace.CurrentCamera
	local low = C.Settings and C.Settings:Low()
	local record = result.Record
	local def = BeeData.Bees[record.Id]
	local rarity = def.Rarity
	local rarityColor = Config.Rarities[rarity].Color
	local order = Config.Rarities[rarity].Order

	-- stage
	local nest = result.Nest and Config.Nests[result.Nest]
	local stagePos
	if nest then
		local map = Workspace:FindFirstChild("Map")
		local nestModel = map and map:FindFirstChild("Nests") and map.Nests:FindFirstChild("Nest_" .. result.Nest)
		stagePos = nestModel and (nestModel:GetPivot().Position + Vector3.new(0, nestModel:GetAttribute("EggHeight") or 3, 0)) or nest.Position + Vector3.new(0, 3, 0)
	else
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		stagePos = root.Position + look.Unit * 9 + Vector3.new(0, 0.5, 0)
	end

	local screen = UI.Create("ScreenGui", { Name = "Cutscene", IgnoreGuiInset = true, DisplayOrder = 50, ResetOnSpawn = false, Parent = player.PlayerGui })
	local hud = UI:_screen()
	hud.Enabled = false
	letterbox(true, screen)
	controls(false)
	camera.CameraType = Enum.CameraType.Scriptable

	local folder = Instance.new("Folder")
	folder.Name = "HatchStage"
	folder.Parent = Workspace

	local egg = buildEgg(result.Egg)
	local _, size = egg:GetBoundingBox()
	egg:ScaleTo(egg:GetScale() * (4.2 / size.Y))
	local function eggPivotAt(pos: Vector3, rot: CFrame?)
		local _, s = egg:GetBoundingBox()
		egg:PivotTo(CFrame.new(pos + Vector3.new(0, s.Y / 2, 0)) * (rot or CFrame.identity))
	end
	egg.Parent = folder

	-- camera: from current to a framing shot
	local camGoal = CFrame.lookAt(stagePos + Vector3.new(9, 5, 9), stagePos + Vector3.new(0, 2.2, 0))
	tween(camera, 0.9, { CFrame = camGoal }, Enum.EasingStyle.Sine)

	if nest then
		-- honey stream from the player into the nest, then the egg drops in
		for i = 1, 10 do
			task.delay(i * 0.05, function()
				local orb = Instance.new("Part")
				orb.Shape = Enum.PartType.Ball
				orb.Material = Enum.Material.Neon
				orb.Color = Color3.fromRGB(255, 186, 30)
				orb.Size = Vector3.new(0.8, 0.8, 0.8)
				orb.Anchored = true
				orb.CanCollide = false
				orb.Position = root.Position + Vector3.new(0, 1.5, 0)
				orb.Parent = folder
				local t = tween(orb, 0.45, { Position = stagePos + Vector3.new(math.random(-2, 2), 0.5, math.random(-2, 2)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				t.Completed:Once(function()
					orb:Destroy()
					C.Sound:Play("SoftPop", { Vary = 0.3 })
				end)
			end)
		end
		eggPivotAt(stagePos + Vector3.new(0, 14, 0))
		task.wait(0.7)
		local value = Instance.new("NumberValue")
		value.Value = 14
		value.Changed:Connect(function(h)
			eggPivotAt(stagePos + Vector3.new(0, h, 0))
		end)
		tween(value, 0.6, { Value = 0 }, Enum.EasingStyle.Bounce)
		task.wait(0.65)
		value:Destroy()
		C.Sound:Play("Pop")
	else
		eggPivotAt(stagePos)
		C.Sound:Play("Whoosh")
		task.wait(0.8)
	end

	-- shake + glow
	local core = Instance.new("Part")
	core.Anchored = true
	core.CanCollide = false
	core.Transparency = 1
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Position = stagePos + Vector3.new(0, 2.1, 0)
	core.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = rarityColor:Lerp(Color3.new(1, 1, 1), 0.3)
	light.Range = 4
	light.Brightness = 0.5
	light.Parent = core
	local sparks = emitter(core, {
		Color = ColorSequence.new(rarityColor:Lerp(Color3.new(1, 1, 1), 0.5)),
		Speed = NumberRange.new(4, 9),
		Lifetime = NumberRange.new(0.3, 0.6),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
	})
	C.Sound:Play("Rumble")
	local shakeTime = 1.9
	local start = os.clock()
	local orbit = 0
	while os.clock() - start < shakeTime do
		local t = (os.clock() - start) / shakeTime
		local amp = math.rad(3 + 20 * t * t)
		local roll = math.sin(os.clock() * (22 + 18 * t)) * amp
		local hop = math.max(0, math.sin(os.clock() * 9)) * 0.35 * t
		eggPivotAt(stagePos + Vector3.new(0, hop, 0), CFrame.Angles(0, 0, roll) * CFrame.Angles(roll * 0.4, 0, 0))
		light.Brightness = 0.5 + 6 * t
		light.Range = 4 + 10 * t
		if not low then
			sparks.Rate = 10 + 90 * t
		end
		orbit += RunService.RenderStepped:Wait() * 0.25
		camera.CFrame = CFrame.lookAt(stagePos + Vector3.new(math.cos(orbit + 0.78) * 12.7, 5 - t * 1.5, math.sin(orbit + 0.78) * 12.7), stagePos + Vector3.new(0, 2.2, 0))
			* CFrame.new(math.random() * 0.15 * t, math.random() * 0.15 * t, 0)
	end
	sparks.Rate = 0

	-- burst
	local flash = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 10, Parent = screen })
	tween(flash, 0.6, { BackgroundTransparency = 1 })
	C.Sound:Play("EggBurst")
	local confetti = emitter(core, {
		Color = ColorSequence.new(rarityColor, Color3.fromRGB(255, 230, 120)),
		Speed = NumberRange.new(18, 32),
		Lifetime = NumberRange.new(0.8, 1.6),
		Acceleration = Vector3.new(0, -30, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.2) }),
	})
	confetti:Emit(low and 30 or 120)
	local rays = emitter(core, {
		Color = ColorSequence.new(Color3.new(1, 1, 1), rarityColor),
		Speed = NumberRange.new(0, 0),
		Lifetime = NumberRange.new(0.6, 0.9),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 7), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
	})
	rays:Emit(low and 2 or 6)
	light.Brightness = 10
	tween(light, 1.5, { Brightness = 2, Range = 10 })

	local top = egg:FindFirstChild("Top")
	for _, part in egg:GetDescendants() do
		if part:IsA("BasePart") then
			if part == top then
				tween(part, 0.9, { CFrame = part.CFrame * CFrame.new(math.random(-3, 3), 7, math.random(-3, 3)) * CFrame.Angles(math.rad(160), math.rad(90), 0), Transparency = 1 }, Enum.EasingStyle.Quad)
			else
				tween(part, 0.8, { CFrame = part.CFrame * CFrame.new(0, -0.6, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
	end

	-- the bee rises
	local bee = C.BeeRenderer.Build(record.Id, record.Mutation)
	if bee then
		bee:ScaleTo(bee:GetScale() * 2.6)
		bee.Parent = folder
		local riseStart = os.clock()
		local spin = RunService.RenderStepped:Connect(function()
			local t = os.clock() - riseStart
			local h = math.min(1, t / 0.9)
			local eased = 1 - (1 - h) ^ 3
			bee:PivotTo(CFrame.new(stagePos + Vector3.new(0, 1.5 + eased * 2.6 + math.sin(t * 2.4) * 0.2, 0)) * CFrame.Angles(0, t * 1.4 + math.pi * 0.25, 0))
		end)
		folder.Destroying:Connect(function()
			spin:Disconnect()
		end)
	end
	task.wait(0.35)
	local extras = {}
	if record.Mutation then
		table.insert(extras, record.Mutation:upper() .. " MUTATION")
	end
	if result.New then
		table.insert(extras, "NEW!")
	end
	if result.Pity then
		table.insert(extras, "PITY")
	end
	holoTitle(core, rarity, def.Name, table.concat(extras, "  •  "))
	C.Sound:Play(order >= 3 and "Reveal" or "Coin")
	if order >= 4 and not low then
		emitter(core, {
			Color = ColorSequence.new(rarityColor),
			Speed = NumberRange.new(2, 5),
			Lifetime = NumberRange.new(1, 2),
			Rate = 40,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		})
	end
	tween(camera, 2.6, { CFrame = CFrame.lookAt(stagePos + Vector3.new(6, 4.5, 6), stagePos + Vector3.new(0, 3.6, 0)) }, Enum.EasingStyle.Sine)

	-- wait (click/tap skips the hold)
	local skip = false
	local skipButton = UI.Create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 20, Parent = screen })
	skipButton.Activated:Connect(function()
		skip = true
	end)
	local holdStart = os.clock()
	while os.clock() - holdStart < 2.8 and not skip do
		task.wait()
	end

	-- out
	local fade = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 245, 220), BackgroundTransparency = 1, ZIndex = 30, Parent = screen })
	tween(fade, 0.3, { BackgroundTransparency = 0 }).Completed:Wait()
	folder:Destroy()
	camera.CameraType = Enum.CameraType.Custom
	controls(true)
	hud.Enabled = true
	letterbox(false, screen)
	tween(fade, 0.35, { BackgroundTransparency = 1 }).Completed:Wait()
	screen:Destroy()
	playing = false
	if #queue > 0 then
		self:Play(table.remove(queue, 1))
	end
end

function HatchCutscene:Init(controllers)
	C = controllers
	UI = C.UI
end

function HatchCutscene:Start()
	Net.Event("HatchResult").OnClientEvent:Connect(function(result)
		task.spawn(self.Play, self, result)
	end)
end

return HatchCutscene
