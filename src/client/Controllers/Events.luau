--[[
	Events
	Cinematic banner for the global field event. On every phase change it drops down from the
	top of the screen (Back easing) in its big form: bold outlined title, field + reward line,
	animated countdown bar and a light sweep.
	After a few seconds it folds into a compact pill that keeps the timer and bar visible.
	The Aphid Invasion server goal shows as a bar under the banner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local ShopJuicer = require(script.Parent.ShopJuicer)

local Events = {}

local C
local UI
local Juice
local state = nil
local lastPhase = nil
local expandedUntil = 0
local expanded = false

local EXPANDED = Vector2.new(560, 118)
local COMPACT = Vector2.new(430, 60)
local IDLE_TOP = Color3.fromRGB(255, 250, 235)
local IDLE_BOTTOM = Color3.fromRGB(250, 230, 190)

local ui = {}

local function tween(obj: Instance, time: number, goals, style, direction)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function outlined(props, stroke: Color3, thickness: number)
	local label = UI.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
	})
	for key, value in props do
		if key ~= "Parent" then
			label[key] = value
		end
	end
	local s = UI.Create("UIStroke", { Color = stroke, Thickness = thickness, Parent = label })
	label.Parent = props.Parent
	return label, s
end

function Events:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

function Events:_build()
	local screen = UI:_screen()
	local banner = UI.Create("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -160),
		Size = UDim2.fromOffset(COMPACT.X, COMPACT.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 20,
		Parent = screen,
	}, { UI.Corner(26), UI.Create("UIScale", { Name = "Responsive" }) })
	ui.Banner = banner
	ui.Gradient = UI.Gradient(IDLE_TOP, IDLE_BOTTOM)
	ui.Gradient.Parent = banner
	ui.Shadow = UI.Create("ImageLabel", {
		Name = "EventShadow",
		BackgroundTransparency = 1,
		Image = UI.Icons.Shadow,
		ImageColor3 = Color3.fromRGB(60, 30, 0),
		ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(80, 80, 176, 176),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 19,
		Parent = screen,
	})
	UI.Create("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 14, 0, 5),
		Size = UDim2.new(1, -28, 0.36, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = banner,
	}, { UI.Corner(20) })
	ShopJuicer.Shine(banner, { Period = 1.1, Pause = 2.5, Transparency = 0.15 })

	ui.Icon = UI.Icon("Lightning", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 40, 0.45, 0),
		Size = UDim2.fromScale(0.62, 0.62),
		ZIndex = 24,
		Parent = banner,
	}, nil)
	UI.Create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = ui.Icon })
	ui.Title, ui.TitleStroke = outlined({
		Name = "Title",
		Position = UDim2.new(0, 78, 0.1, 0),
		Size = UDim2.new(1, -190, 0.44, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = banner,
	}, Color3.fromRGB(90, 40, 0), 3)
	ui.TitleGradient = UI.Create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 200)), Parent = ui.Title })
	ui.Sub, ui.SubStroke = outlined({
		Name = "Field",
		Position = UDim2.new(0, 80, 0.53, 0),
		Size = UDim2.new(1, -190, 0.2, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = banner,
	}, Color3.fromRGB(90, 40, 0), 2)
	ui.Timer, ui.TimerStroke = outlined({
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0.12, 0),
		Size = UDim2.new(0, 100, 0.48, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 24,
		Parent = banner,
	}, Color3.fromRGB(90, 40, 0), 3)

	-- countdown bar inside the banner
	ui.Track = UI.Create("Frame", {
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -36, 0.13, 0),
		BackgroundColor3 = Color3.fromRGB(40, 20, 0),
		BackgroundTransparency = 0.55,
		ZIndex = 24,
		Parent = banner,
	}, { UI.Round() })
	ui.Fill = UI.Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 25,
		Parent = ui.Track,
	}, { UI.Round() })
	ui.FillGradient = UI.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 120), 0)
	ui.FillGradient.Parent = ui.Fill
	ui.Spark = UI.Icon("Glow", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, 34, 2.8, 0),
		ImageTransparency = 0.2,
		ZIndex = 26,
		Parent = ui.Fill,
	})

	ui.GoalBar, ui.GoalFill, ui.GoalText = UI.Bar({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.new(0.8, 0, 0, 22),
		Color = Color3.fromRGB(120, 210, 80),
		MaxTextSize = 14,
		Parent = banner,
	})
	ui.GoalBar.Visible = false

	-- the shadow follows the banner (a child would draw over the banner's own background)
	local function syncShadow()
		ui.Shadow.Position = banner.Position + UDim2.fromOffset(0, -8)
		ui.Shadow.Size = UDim2.fromOffset(banner.AbsoluteSize.X + 40, banner.AbsoluteSize.Y + 40)
	end
	banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncShadow)
	banner:GetPropertyChangedSignal("Position"):Connect(syncShadow)
	syncShadow()
end

-- Big form for a few seconds after a phase change, compact pill otherwise
function Events:_setExpanded(on: boolean)
	if on == expanded then
		return
	end
	expanded = on
	local size = on and EXPANDED or COMPACT
	tween(ui.Banner, 0.45, { Size = UDim2.fromOffset(size.X, size.Y) }, Enum.EasingStyle.Back)
	ui.Sub.Visible = on
	ui.Title.Size = on and UDim2.new(1, -190, 0.44, 0) or UDim2.new(1, -190, 0.6, 0)
	ui.Title.Position = on and UDim2.new(0, 78, 0.1, 0) or UDim2.new(0, 72, 0.08, 0)
	ui.Timer.Size = on and UDim2.new(0, 100, 0.48, 0) or UDim2.new(0, 90, 0.6, 0)
	ui.Track.Size = on and UDim2.new(1, -36, 0.13, 0) or UDim2.new(1, -36, 0.14, 0)
	ui.Track.Position = on and UDim2.new(0.5, 0, 1, -10) or UDim2.new(0.5, 0, 1, -6)
end

function Events:_drop()
	ui.Banner.Position = UDim2.new(0.5, 0, 0, -160)
	expanded = false
	self:_setExpanded(true)
	tween(ui.Banner, 0.65, { Position = UDim2.new(0.5, 0, 0, 10) }, Enum.EasingStyle.Back)
	expandedUntil = os.clock() + 6
end

function Events:_refresh()
	if not state or not ui.Banner or not state.StartsAt or not state.EndsAt then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local info = Config.EventInfo[state.Type] or { Name = state.Type or "Event", Color = UI.Colors.Honey }
	local field = Config.FieldById[state.FieldId]
	local color = info.Color
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.6)
	local fraction = 1
	if state.Phase == "Active" then
		ui.Gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.1))
		ui.Title.Text = info.Name:upper()
		ui.Sub.Text = `{field and field.Name or ""}  •  5x REWARDS`
		ui.Timer.Text = Format.Time(state.EndsAt - now)
		fraction = (state.EndsAt - now) / math.max(1, state.EndsAt - state.StartsAt)
	elseif state.Phase == "Warning" then
		ui.Gradient.Color = ColorSequence.new(UI.Colors.HoneyLight, UI.Colors.HoneyDark)
		ui.Title.Text = info.Name:upper()
		ui.Sub.Text = `Starting soon in {field and field.Name or "a field"}!`
		ui.Timer.Text = Format.Time(state.StartsAt - now)
		fraction = (state.StartsAt - now) / Config.Events.Warning
		dark = Color3.fromRGB(110, 50, 0)
	else
		ui.Gradient.Color = ColorSequence.new(IDLE_TOP, IDLE_BOTTOM)
		ui.Title.Text = "Next: " .. info.Name
		ui.Sub.Text = field and field.Name or ""
		ui.Timer.Text = Format.Time(state.StartsAt - now)
		dark = Color3.fromRGB(120, 70, 20)
		fraction = 1
	end
	for _, s in { ui.TitleStroke, ui.SubStroke, ui.TimerStroke } do
		s.Color = dark
	end
	ui.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0.02, 1), 1)
	ui.Fill.Visible = state.Phase ~= "Idle"
	ui.Track.Visible = state.Phase ~= "Idle"

	if state.Phase ~= lastPhase then
		local first = lastPhase == nil
		lastPhase = state.Phase
		if state.Phase == "Idle" and not first then
			self:_setExpanded(false)
			Juice.Punch(ui.Banner, 0.08)
		else
			self:_drop()
		end
		if state.Phase == "Active" then
			C.Sound:Play("Event")
			ShopJuicer.Burst(ui.Banner, 14, color:Lerp(Color3.new(1, 1, 1), 0.5))
		elseif state.Phase == "Warning" and not first then
			C.Sound:Play("Notify")
		end
	end
	if expanded and os.clock() > expandedUntil then
		self:_setExpanded(false)
	end

	local showGoal = state.Phase == "Active" and state.Goal ~= nil
	ui.GoalBar.Visible = showGoal
	if showGoal then
		local progress = math.min(state.Progress or 0, state.Goal)
		ui.GoalFill.Size = UDim2.fromScale(math.max(0.04, progress / state.Goal), 1)
		ui.GoalText.Text = `{progress} / {state.Goal}`
	end
end

-- Subtle life on the banner: the countdown spark pulses and the title shimmers while active
function Events:_animate()
	local t = os.clock()
	local phase = state and state.Phase or "Idle"
	-- the bar's leading spark pulses
	ui.Spark.ImageTransparency = 0.25 + math.sin(t * 8) * 0.2
	if phase == "Active" then
		ui.TitleGradient.Offset = Vector2.new(0, math.sin(t * 3) * 0.15)
	end
end

function Events:Start()
	self:_build()
	Net.Event("EventState").OnClientEvent:Connect(function(newState)
		state = newState
		self:_refresh()
	end)
	RunService.RenderStepped:Connect(function()
		self:_animate()
		local camera = Workspace.CurrentCamera
		ui.Banner.Responsive.Scale = math.clamp(math.min(camera.ViewportSize.Y / 760, camera.ViewportSize.X / 1200), 0.55, 1)
		-- panels own the screen: the banner steps aside while one is open
		ui.Banner.Visible = UI.Current == nil and UI:_screen().Enabled
		ui.Shadow.Visible = ui.Banner.Visible
	end)
	task.spawn(function()
		local ok, initial = pcall(function()
			return Net.Function("GetEventState"):InvokeServer()
		end)
		if ok and initial and not state then
			state = initial
		end
		while true do
			self:_refresh()
			task.wait(0.25)
		end
	end)
end

return Events
