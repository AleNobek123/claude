--[[
	WorldClock
	Small info pills under the left menu so players can plan ahead:
	  - day / night and how long until it changes (DayNight runs off server time)
	  - the current or next global event
	  - the next world boss, or where one is right now
	Everything is derived from server time, so the pills cost no network traffic beyond the
	event state and two Workspace attributes the server already keeps up to date.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayNight = require(Shared.DayNight)
local Format = require(Shared.Format)

local WorldClock = {}

local C
local UI
local pills = {}

local function pill(parent: Instance, order: number, color: Color3)
	local frame = UI.Create("Frame", {
		Name = "Pill" .. order,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundColor3 = Color3.fromRGB(40, 26, 12),
		BackgroundTransparency = 0.45,
		Parent = parent,
	}, {
		UI.Corner(15),
		UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12) }),
		UI.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dot = UI.Create("TextLabel", {
		Name = "Glyph",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = color,
		Parent = frame,
	})
	local label = UI.Create("TextLabel", {
		Name = "Text",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, { UI.Create("UIStroke", { Color = Color3.fromRGB(60, 34, 10), Thickness = 2 }) })
	return { Frame = frame, Glyph = dot, Text = label }
end

function WorldClock:Init(controllers)
	C = controllers
	UI = C.UI
end

function WorldClock:_update()
	local now = Workspace:GetServerTimeNow()

	-- day / night
	local night = DayNight.IsNight(now)
	local change = Format.Time(DayNight.NextChange(now))
	pills.Day.Glyph.Text = night and "🌙" or "☀️"
	pills.Day.Glyph.TextColor3 = night and Color3.fromRGB(170, 190, 255) or Color3.fromRGB(255, 214, 70)
	pills.Day.Text.Text = night and `Night · day in {change}` or `Day · night in {change}`

	-- events
	local state = C.Events and C.Events:GetState()
	local info = state and state.Type and Config.EventInfo[state.Type]
	if state and info and state.Phase == "Active" then
		pills.Event.Text.Text = `{info.Name} · {Format.Time(state.EndsAt - now)} left`
	elseif state and info and state.StartsAt then
		pills.Event.Text.Text = `{info.Name} in {Format.Time(state.StartsAt - now)}`
	elseif state and state.StartsAt then
		pills.Event.Text.Text = `Next event in {Format.Time(state.StartsAt - now)}`
	else
		pills.Event.Text.Text = "Next event soon"
	end

	-- world boss
	local bossField = Workspace:GetAttribute("BossField")
	local nextBoss = Workspace:GetAttribute("NextBossAt")
	if bossField then
		local escape = Workspace:GetAttribute("BossEscapeAt")
		pills.Boss.Text.Text = escape and `Boss in {bossField} · escapes in {Format.Time(escape - now)}` or `Boss in {bossField}!`
		pills.Boss.Frame.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	else
		pills.Boss.Text.Text = nextBoss and `Boss in {Format.Time(nextBoss - now)}` or "Boss soon"
		pills.Boss.Frame.BackgroundColor3 = Color3.fromRGB(40, 26, 12)
	end
end

function WorldClock:Start()
	local screen = UI:_screen()
	local holder = UI.Create("Frame", {
		Name = "WorldClock",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = screen,
	}, { UI.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	pills.Day = pill(holder, 1, Color3.fromRGB(255, 214, 70))
	pills.Event = pill(holder, 2, Color3.fromRGB(255, 170, 40))
	pills.Event.Glyph.Text = "⚡"
	pills.Boss = pill(holder, 3, Color3.fromRGB(255, 90, 80))
	pills.Boss.Glyph.Text = "☠"

	-- sit right under the menu grid, whatever size the responsive menu has
	local menu = screen:WaitForChild("Menu", 10)
	local function layout()
		if menu then
			local root = screen.AbsolutePosition
			holder.Position = UDim2.fromOffset(menu.AbsolutePosition.X - root.X, menu.AbsolutePosition.Y + menu.AbsoluteSize.Y + 12 - root.Y)
		else
			holder.Position = UDim2.fromOffset(18, 480)
		end
	end
	if menu then
		menu:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
		menu:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	end
	layout()

	task.spawn(function()
		while true do
			-- hidden behind open panels like the rest of the HUD extras
			holder.Visible = UI.Current == nil
			local ok, err = pcall(self._update, self)
			if not ok then
				warn("[WorldClock]", err)
			end
			task.wait(0.5)
		end
	end)
end

return WorldClock
