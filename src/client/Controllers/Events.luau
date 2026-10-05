--[[
	Events
	Floating pill for the global field event: next event countdown, warning pulse,
	live timer and the Aphid Invasion server goal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Events = {}

local C
local UI
local Juice
local state = nil
local lastPhase = nil
local banner: Frame
local gradient: UIGradient
local title: TextLabel
local timer: TextLabel
local goalBar: Frame
local goalFill: Frame
local goalText: TextLabel

function Events:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

function Events:_build()
	local screen = UI:_screen()
	banner = UI.Create("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(400, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Parent = screen,
	}, { UI.Round() })
	gradient = UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(250, 236, 205), 0)
	gradient.Parent = banner
	UI.Icon("Lightning", { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(48, 48), Parent = banner })
	title = UI.Label({ Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -150, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = banner })
	local sub = UI.Label({ Name = "Field", Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(60, 31), Size = UDim2.new(1, -150, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = banner })
	self.FieldLabel = sub
	timer = UI.Label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(80, 32), TextXAlignment = Enum.TextXAlignment.Right, MaxTextSize = 26, Parent = banner })
	goalBar, goalFill, goalText = UI.Bar({ Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 1, 6), Color = Color3.fromRGB(120, 210, 80), MaxTextSize = 13, Parent = banner })
	goalBar.Visible = false
end

function Events:_refresh()
	if not state or not banner or not state.StartsAt or not state.EndsAt then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local info = Config.EventInfo[state.Type] or { Name = state.Type or "Event", Color = UI.Colors.Honey }
	local field = Config.FieldById[state.FieldId]
	self.FieldLabel.Text = field and field.Name or ""
	if state.Phase == "Active" then
		gradient.Color = ColorSequence.new(info.Color:Lerp(Color3.new(1, 1, 1), 0.45), info.Color)
		title.Text = info.Name .. "  5x"
		timer.Text = Format.Time(state.EndsAt - now)
	elseif state.Phase == "Warning" then
		gradient.Color = ColorSequence.new(UI.Colors.HoneyLight, UI.Colors.Honey)
		title.Text = info.Name
		timer.Text = Format.Time(state.StartsAt - now)
	else
		gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(250, 236, 205))
		title.Text = "Next: " .. info.Name
		timer.Text = Format.Time(state.StartsAt - now)
	end
	if state.Phase ~= lastPhase then
		lastPhase = state.Phase
		Juice.Punch(banner, 0.15)
		if state.Phase == "Active" then
			C.Sound:Play("Event")
		end
	end
	local showGoal = state.Phase == "Active" and state.Goal ~= nil
	goalBar.Visible = showGoal
	if showGoal then
		local progress = math.min(state.Progress or 0, state.Goal)
		goalFill.Size = UDim2.fromScale(math.max(0.04, progress / state.Goal), 1)
		goalText.Text = `{progress} / {state.Goal}`
	end
end

function Events:Start()
	self:_build()
	Net.Event("EventState").OnClientEvent:Connect(function(newState)
		state = newState
		self:_refresh()
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
			task.wait(0.5)
		end
	end)
end

return Events
