--[[
	Juice (UI Juicer)
	Micro-interactions for every GUI element:
	  Bind(button)       hover: +10% scale, 2.5 deg tilt (Back easing); press: -15%; release: spring back
	  Open(frame)        panel appears with a springy scale + fade (CanvasGroup)
	  Close(frame, done) reverse of Open
	  Pop(gui)           quick appear pop for new elements
	  Punch(gui)         one-shot emphasis (numbers changing, rewards)
	  Shake(gui)         error / denied feedback
	  Float(gui)         gentle idle bob for icons
	  CountUp(label)     animated number change
	All scaling goes through a UIScale child, so layouts (UIListLayout, UIGridLayout) are never disturbed.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = {}

Juice.Sound = nil -- set by the Sound controller: function(name)

local BACK_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function scaleOf(gui: GuiObject): UIScale
	local scale = gui:FindFirstChild("JuiceScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "JuiceScale"
		scale.Parent = gui
	end
	return scale
end

local function play(name: string)
	if Juice.Sound then
		Juice.Sound(name)
	end
end

function Juice.Tween(obj: Instance, info: TweenInfo, goals)
	local tween = TweenService:Create(obj, info, goals)
	tween:Play()
	return tween
end

-- Hover / press / release feedback. opts: Rotate (deg), Hover (scale), Press (scale), Silent
function Juice.Bind(button: GuiButton, opts)
	opts = opts or {}
	local hoverScale = opts.Hover or 1.1
	local pressScale = opts.Press or 0.85
	local rotate = opts.Rotate or 2.5
	local scale = scaleOf(button)
	local baseRotation = button.Rotation
	local hovering = false
	local side = 1

	button.MouseEnter:Connect(function()
		hovering = true
		side = -side
		Juice.Tween(scale, BACK_OUT, { Scale = hoverScale })
		Juice.Tween(button, BACK_OUT, { Rotation = baseRotation + rotate * side })
		if not opts.Silent then
			play("Hover")
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		Juice.Tween(scale, BACK_OUT, { Scale = 1 })
		Juice.Tween(button, BACK_OUT, { Rotation = baseRotation })
	end)
	button.MouseButton1Down:Connect(function()
		Juice.Tween(scale, QUICK, { Scale = pressScale })
	end)
	button.MouseButton1Up:Connect(function()
		Juice.Tween(scale, SPRING, { Scale = hovering and hoverScale or 1 })
	end)
	button.Activated:Connect(function()
		if not opts.Silent then
			play("Click")
		end
		if not hovering then -- touch devices: no hover, so give a full punch
			Juice.Punch(button, 0.12)
		end
	end)
	return button
end

-- Panels are CanvasGroups so the whole panel can fade as one image
function Juice.Open(frame: GuiObject)
	local scale = scaleOf(frame)
	frame.Visible = true
	scale.Scale = 0.82
	if frame:IsA("CanvasGroup") then
		frame.GroupTransparency = 1
		Juice.Tween(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { GroupTransparency = 0 })
	end
	Juice.Tween(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	play("Whoosh")
end

function Juice.Close(frame: GuiObject, done: (() -> ())?)
	local scale = scaleOf(frame)
	local tween = Juice.Tween(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.85 })
	if frame:IsA("CanvasGroup") then
		Juice.Tween(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
	end
	tween.Completed:Once(function()
		frame.Visible = false
		scale.Scale = 1
		if done then
			done()
		end
	end)
end

function Juice.Pop(gui: GuiObject, delay: number?)
	local scale = scaleOf(gui)
	scale.Scale = 0
	task.delay(delay or 0, function()
		Juice.Tween(scale, SPRING, { Scale = 1 })
	end)
end

function Juice.Punch(gui: GuiObject, amount: number?)
	local scale = scaleOf(gui)
	scale.Scale = 1 + (amount or 0.15)
	Juice.Tween(scale, SPRING, { Scale = 1 })
end

function Juice.Shake(gui: GuiObject, intensity: number?, duration: number?)
	intensity = intensity or 6
	duration = duration or 0.35
	local origin = gui.Position
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= duration then
			connection:Disconnect()
			gui.Position = origin
			return
		end
		local falloff = 1 - t / duration
		gui.Position = origin + UDim2.fromOffset(math.sin(t * 60) * intensity * falloff, 0)
	end)
end

-- Gentle idle bob; returns a stop function
function Juice.Float(gui: GuiObject, amplitude: number?, speed: number?)
	amplitude = amplitude or 3
	speed = speed or 2
	local origin = gui.Position
	local phase = math.random() * math.pi * 2
	local connection = RunService.RenderStepped:Connect(function()
		if gui.Parent then
			gui.Position = origin + UDim2.fromOffset(0, math.sin(os.clock() * speed + phase) * amplitude)
		end
	end)
	return function()
		connection:Disconnect()
		gui.Position = origin
	end
end

-- Animated number; formatter turns a number into text
local counting: { [TextLabel]: number } = {}
function Juice.CountUp(label: TextLabel, from: number, to: number, formatter: (number) -> string, duration: number?)
	duration = duration or 0.45
	local token = (counting[label] or 0) + 1
	counting[label] = token
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if counting[label] ~= token then
			connection:Disconnect()
			return
		end
		local alpha = math.min(1, (os.clock() - start) / duration)
		local eased = 1 - (1 - alpha) ^ 3
		label.Text = formatter(from + (to - from) * eased)
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

return Juice
