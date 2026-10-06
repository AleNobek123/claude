--[[
	TeleportTransition
	Cinematic "honey drip" cover for teleports: thick honey runs down from the top of the
	screen, the camera blurs and widens, the jump happens while the centre is covered,
	then the honey keeps sliding down and melts away. The screen edges stay semi-transparent
	so the player never sees a hard black frame.

	  TeleportTransition:Play(onCovered)   -- yields until the reveal has finished
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TeleportTransition = {}

local C
local UI
local busy = false

local HONEY_TOP = Color3.fromRGB(255, 214, 90)
local HONEY_BOTTOM = Color3.fromRGB(232, 142, 20)
local DRIP_COUNT = 14

local function tween(obj: Instance, time: number, goals, style, direction)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

-- Honey curtain: a band along the top plus rounded drips of random width/length, each with a
-- drop at its tip. The CanvasGroup's horizontal transparency gradient keeps the edges see-through.
local function buildCurtain(parent: Instance)
	local group = UI.Create("CanvasGroup", {
		Name = "Honey",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	UI.Create("UIGradient", {
		Transparency = NumberSequence.new({
			-- the outer ~18% of the viewport stays see-through, the centre is never fully opaque
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.18, 0.18),
			NumberSequenceKeypoint.new(0.82, 0.18),
			NumberSequenceKeypoint.new(1, 0.82),
		}),
		Parent = group,
	})
	local band = UI.Create("Frame", {
		Name = "Band",
		Size = UDim2.new(1, 0, 0.16, 0),
		Position = UDim2.fromScale(0, -0.2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = group,
	}, { UI.Gradient(HONEY_TOP, HONEY_BOTTOM) })

	local drips = {}
	local rng = Random.new()
	for i = 1, DRIP_COUNT do
		local width = rng:NextNumber(0.05, 0.11)
		local x = (i - 1) / (DRIP_COUNT - 1) + rng:NextNumber(-0.025, 0.025)
		-- drips in the middle run longest, so the centre is covered and the edges are not
		local centre = 1 - math.abs(x - 0.5) * 2
		local length = math.min(0.82, 0.32 + centre * 0.5 + rng:NextNumber(-0.06, 0.08))
		local drip = UI.Create("Frame", {
			Name = "Drip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(width, 0, 0, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = group,
		}, { UI.Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.Gradient(HONEY_TOP:Lerp(HONEY_BOTTOM, 0.25), HONEY_BOTTOM) })
		local drop = UI.Create("Frame", {
			Name = "Drop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0, 0),
			BackgroundColor3 = HONEY_BOTTOM,
			BorderSizePixel = 0,
			Parent = drip,
		}, { UI.Round(), UI.Create("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		-- glossy highlight on each drip
		UI.Create("Frame", {
			Name = "Shine",
			Position = UDim2.fromScale(0.22, 0.04),
			Size = UDim2.fromScale(0.16, 0.6),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Parent = drip,
		}, { UI.Round() })
		table.insert(drips, { Frame = drip, Drop = drop, Length = length, Delay = rng:NextNumber(0, 0.12) })
	end
	return group, band, drips
end

function TeleportTransition:Play(onCovered: () -> ())
	if busy then
		return
	end
	busy = true
	local camera = Workspace.CurrentCamera
	local screen = UI.Create("ScreenGui", {
		Name = "TeleportFx",
		IgnoreGuiInset = true,
		DisplayOrder = 45,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local group, band, drips = buildCurtain(screen)
	local blur = Instance.new("BlurEffect")
	blur.Name = "TeleportBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local baseFov = camera.FieldOfView

	-- cover: honey pours down (Quad In = accelerating like a real drip)
	if C.Sound then
		C.Sound:Play("Whoosh", { Pitch = 0.9 })
		C.Sound:Play("SoftPop", { Volume = 0.6 })
	end
	tween(band, 0.3, { Position = UDim2.fromScale(0, 0) })
	for _, d in drips do
		task.delay(d.Delay, function()
			tween(d.Frame, 0.42, { Size = UDim2.new(d.Frame.Size.X.Scale, 0, d.Length, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(d.Drop, 0.42, { Size = UDim2.fromScale(1.25, 0) }, Enum.EasingStyle.Back)
		end)
	end
	tween(blur, 0.45, { Size = 16 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(camera, 0.45, { FieldOfView = baseFov + 16 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.55)

	local ok, err = pcall(onCovered)
	if not ok then
		warn("[TeleportTransition] " .. tostring(err))
	end
	task.wait(0.12)

	-- reveal: the honey keeps sliding off the bottom and melts away
	if C.Sound then
		C.Sound:Play("Pop", { Pitch = 0.8, Volume = 0.7 })
	end
	tween(band, 0.5, { Position = UDim2.fromScale(0, 1.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in drips do
		tween(d.Frame, 0.55 + d.Delay, { Position = UDim2.fromScale(d.Frame.Position.X.Scale, 1.15) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	tween(group, 0.6, { GroupTransparency = 1 })
	tween(blur, 0.5, { Size = 0 })
	tween(camera, 0.6, { FieldOfView = baseFov }, Enum.EasingStyle.Back)
	task.wait(0.7)
	blur:Destroy()
	screen:Destroy()
	camera.FieldOfView = baseFov
	busy = false
end

function TeleportTransition:Init(controllers)
	C = controllers
	UI = C.UI
end

return TeleportTransition
