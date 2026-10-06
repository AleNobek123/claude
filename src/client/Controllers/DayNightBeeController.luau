--[[
	DayNightBeeController
	Client side of the day/night cycle (shared clock in Shared.DayNight; day = 2.5x night).
	  Lighting   ClockTime follows the shared clock; ambient, atmosphere, colour grading, bloom,
	             stars and lantern lights blend between the day and night presets
	  Sleeping   bees whose server task is Rest (the 50% that go home at night) sit in their hive
	             cell and emit drifting "Z z z" particles; HiveDisplay hides their docked copy
	  Cues       a short notification and chime at sunset and sunrise
	Nothing here touches gameplay: the server decides who sleeps (BeeService + DayNight.Sleeps).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BeeCodec = require(Shared.BeeCodec)
local DayNight = require(Shared.DayNight)

local DayNightBeeController = {}

local C
local sleepers = {} -- [bee record] = { Gui, Letters }
local lanterns = {} -- PointLights placed on the map
local lastNight = nil

local REST = BeeCodec.Task.Rest
local Z_DISTANCE = 90
local Z_LETTERS = 3

-- Lighting presets (day values match the stylised look from BuildMap)
local DAY = {
	Ambient = Color3.fromRGB(150, 135, 120),
	OutdoorAmbient = Color3.fromRGB(170, 160, 150),
	Brightness = 2.4,
	Exposure = -0.05,
	Tint = Color3.fromRGB(255, 248, 238),
	Saturation = 0.28,
	AtmosphereColor = Color3.fromRGB(255, 236, 205),
	AtmosphereDecay = Color3.fromRGB(255, 200, 150),
	Haze = 1.2,
	Bloom = 0.35,
	Stars = 0,
}
local NIGHT = {
	Ambient = Color3.fromRGB(70, 80, 130),
	OutdoorAmbient = Color3.fromRGB(80, 95, 150),
	Brightness = 1.1,
	Exposure = 0.15,
	Tint = Color3.fromRGB(190, 205, 255),
	Saturation = 0.1,
	AtmosphereColor = Color3.fromRGB(120, 140, 210),
	AtmosphereDecay = Color3.fromRGB(70, 80, 150),
	Haze = 1.8,
	Bloom = 0.7,
	Stars = 3000,
}

local function lerp(a, b, t)
	if typeof(a) == "Color3" then
		return a:Lerp(b, t)
	end
	return a + (b - a) * t
end

function DayNightBeeController:_applyLighting(now: number)
	local dark = DayNight.Darkness(now)
	Lighting.ClockTime = DayNight.ClockTime(now)
	Lighting.Ambient = lerp(DAY.Ambient, NIGHT.Ambient, dark)
	Lighting.OutdoorAmbient = lerp(DAY.OutdoorAmbient, NIGHT.OutdoorAmbient, dark)
	Lighting.Brightness = lerp(DAY.Brightness, NIGHT.Brightness, dark)
	Lighting.ExposureCompensation = lerp(DAY.Exposure, NIGHT.Exposure, dark)
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.TintColor = lerp(DAY.Tint, NIGHT.Tint, dark)
		cc.Saturation = lerp(DAY.Saturation, NIGHT.Saturation, dark)
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = lerp(DAY.AtmosphereColor, NIGHT.AtmosphereColor, dark)
		atmosphere.Decay = lerp(DAY.AtmosphereDecay, NIGHT.AtmosphereDecay, dark)
		atmosphere.Haze = lerp(DAY.Haze, NIGHT.Haze, dark)
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom and not (C.Settings and C.Settings:Low()) then
		bloom.Intensity = lerp(DAY.Bloom, NIGHT.Bloom, dark)
	end
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.StarCount = math.floor(lerp(DAY.Stars, NIGHT.Stars, dark))
	end
	-- lanterns glow brighter as it gets dark
	for _, light in lanterns do
		light.Brightness = 0.6 + dark * 2.2
		light.Range = 14 + dark * 12
	end
end

function DayNightBeeController:_collectLanterns()
	table.clear(lanterns)
	local map = Workspace:FindFirstChild("Map")
	local decor = map and map:FindFirstChild("Decor")
	if not decor then
		return
	end
	for _, light in decor:GetDescendants() do
		if light:IsA("PointLight") then
			table.insert(lanterns, light)
		end
	end
end

-- "Z z z" particles: three letters drifting up and fading on a loop
local function makeZzz(adornee: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SleepZzz"
	gui.Size = UDim2.fromOffset(60, 70)
	gui.StudsOffset = Vector3.new(0.4, 1.4, 0)
	gui.MaxDistance = Z_DISTANCE
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local letters = {}
	for i = 1, Z_LETTERS do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = i == 1 and "Z" or "z"
		label.TextColor3 = Color3.fromRGB(215, 230, 255)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(40, 55, 120)
		stroke.Thickness = 2
		stroke.Parent = label
		letters[i] = { Label = label, Stroke = stroke, Offset = (i - 1) / Z_LETTERS }
	end
	gui.Parent = Workspace:FindFirstChild("ClientFx") or Workspace
	return gui, letters
end

function DayNightBeeController:_updateSleepers()
	local renderer = C.BeeRenderer
	if not renderer then
		return
	end
	local camera = Workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local alive = {}
	for _, swarm in renderer:Swarms() do
		for _, bee in swarm.Bees do
			local resting = bee.Task and bee.Task.Task == REST
			if resting and bee.Model and bee.Model.PrimaryPart and (bee.Position - camPos).Magnitude < Z_DISTANCE then
				alive[bee] = true
				if not sleepers[bee] then
					local gui, letters = makeZzz(bee.Model.PrimaryPart)
					sleepers[bee] = { Gui = gui, Letters = letters, Phase = math.random() }
				end
			end
		end
	end
	for bee, entry in sleepers do
		if not alive[bee] then
			entry.Gui:Destroy()
			sleepers[bee] = nil
		end
	end
end

function DayNightBeeController:_animateSleepers(t: number)
	for _, entry in sleepers do
		for _, letter in entry.Letters do
			local cycle = (t * 0.4 + entry.Phase + letter.Offset) % 1
			letter.Label.Position = UDim2.fromScale(0.3 + cycle * 0.45 + math.sin(cycle * 6) * 0.06, 0.9 - cycle * 0.8)
			letter.Label.Size = UDim2.fromScale(0.25 + cycle * 0.35, 0.22 + cycle * 0.3)
			local fade = cycle < 0.15 and (1 - cycle / 0.15) or (cycle - 0.15) / 0.85
			letter.Label.TextTransparency = fade
			letter.Stroke.Transparency = fade
		end
	end
end

-- Is this bee asleep right now? (HiveDisplay hides docked copies of sleeping bees)
function DayNightBeeController:IsSleeping(bee): boolean
	return bee ~= nil and bee.Task ~= nil and bee.Task.Task == REST
end

function DayNightBeeController:Init(controllers)
	C = controllers
end

function DayNightBeeController:Start()
	task.delay(3, function()
		self:_collectLanterns()
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		self:_applyLighting(now)
		self:_animateSleepers(os.clock())
		acc += dt
		if acc >= 0.5 then
			acc = 0
			self:_updateSleepers()
			local night = DayNight.IsNight(now)
			if lastNight ~= nil and night ~= lastNight and C.NotificationCenter then
				if night then
					C.NotificationCenter:Push("Night falls: half of your bees fly home to sleep", "info", { Icon = "Star" })
				else
					C.NotificationCenter:Push("Good morning! Your bees are back to work", "honey", { Icon = "Bee" })
				end
				if C.Sound then
					C.Sound:Play("Reveal", { Volume = 0.5 })
				end
			end
			lastNight = night
		end
	end)
end

return DayNightBeeController
