--[[
	Events
	Banner for the global field event: countdown to the next event, warning, live timer
	and the Aphid Invasion server goal.
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
local state = nil
local banner: Frame
local title: TextLabel
local subtitle: TextLabel
local goalBar: Frame
local goalFill: Frame
local goalText: TextLabel

function Events:Init(controllers)
	C = controllers
	UI = C.UI
end

function Events:_build()
	local screen = UI:_screen()
	banner = UI.Create("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(420, 58),
		BackgroundColor3 = UI.Colors.Cream,
		BackgroundTransparency = 0.1,
		Parent = screen,
	}, { UI.Corner(14), UI.Stroke(UI.Colors.Brown, 2) })
	title = UI.Label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 28), MaxTextSize = 22, Parent = banner })
	subtitle = UI.Label({ Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 20), MaxTextSize = 15, Parent = banner })
	goalBar, goalFill, goalText = UI.Bar({
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.new(0, 10, 1, 4),
		Color = Color3.fromRGB(120, 210, 80),
		MaxTextSize = 13,
		Parent = banner,
	})
	goalBar.Visible = false
end

function Events:_refresh()
	if not state or not banner or not state.StartsAt or not state.EndsAt then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local info = Config.EventInfo[state.Type] or { Name = state.Type or "Event", Color = UI.Colors.Honey }
	local field = Config.FieldById[state.FieldId]
	local fieldName = field and field.Name or "?"
	if state.Phase == "Active" then
		banner.BackgroundColor3 = info.Color
		title.Text = `{info.Name}  •  {fieldName}`
		subtitle.Text = `5x rewards, gate open • ends in {Format.Time(state.EndsAt - now)}`
		subtitle.TextColor3 = UI.Colors.Brown
	elseif state.Phase == "Warning" then
		banner.BackgroundColor3 = UI.Colors.Honey
		title.Text = `{info.Name} incoming!`
		subtitle.Text = `{fieldName} • starts in {Format.Time(state.StartsAt - now)}`
		subtitle.TextColor3 = UI.Colors.Brown
	else
		banner.BackgroundColor3 = UI.Colors.Cream
		title.Text = `Next event: {info.Name}`
		subtitle.Text = `{fieldName} • in {Format.Time(state.StartsAt - now)}`
		subtitle.TextColor3 = UI.Colors.Muted
	end
	local showGoal = state.Phase == "Active" and state.Goal ~= nil
	goalBar.Visible = showGoal
	if showGoal then
		local progress = math.min(state.Progress or 0, state.Goal)
		goalFill.Size = UDim2.fromScale(progress / state.Goal, 1)
		goalText.Text = `Server goal: {progress} / {state.Goal} aphids`
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
