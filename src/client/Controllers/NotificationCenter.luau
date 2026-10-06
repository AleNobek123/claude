--[[
	NotificationCenter
	Every gameplay message pops at the upper center of the screen: no frames, no borders,
	just an icon and outlined text inside a CanvasGroup that scales and fades as one image.

	  NotificationCenter:Push(text, kind?, opts?)
	    kind: "info" | "good" | "bad" | "rare" | "honey" | "event"
	    opts: { Icon = string?, Duration = number? }

	Identical messages merge into one line with a counter instead of stacking.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NotificationCenter = {}

local C
local UI
local holder: Frame
local active = {} -- [text] = entry
local order = 0

local MAX_VISIBLE = 4
local STYLES = {
	info = { Icon = "Bee", Top = Color3.fromRGB(255, 255, 255), Bottom = Color3.fromRGB(255, 236, 190), Stroke = Color3.fromRGB(92, 56, 20), Sound = "Notify" },
	good = { Icon = "Check", Top = Color3.fromRGB(214, 255, 196), Bottom = Color3.fromRGB(110, 225, 110), Stroke = Color3.fromRGB(26, 82, 30), Sound = "Notify" },
	bad = { Icon = "Close", Top = Color3.fromRGB(255, 214, 200), Bottom = Color3.fromRGB(255, 96, 84), Stroke = Color3.fromRGB(100, 20, 16), Sound = "Notify" },
	honey = { Icon = "Honey", Top = Color3.fromRGB(255, 244, 170), Bottom = Color3.fromRGB(255, 176, 30), Stroke = Color3.fromRGB(110, 56, 8), Sound = "Coin" },
	event = { Icon = "Lightning", Top = Color3.fromRGB(255, 236, 160), Bottom = Color3.fromRGB(255, 120, 40), Stroke = Color3.fromRGB(100, 36, 10), Sound = "Event" },
	rare = { Icon = "Star", Top = Color3.fromRGB(255, 255, 255), Bottom = Color3.fromRGB(255, 196, 46), Stroke = Color3.fromRGB(80, 30, 110), Sound = "Event", Rainbow = true },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 255, 150)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 140, 255)),
})

local function tween(obj: Instance, time: number, goals, style, direction)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function build(text: string, style): CanvasGroup
	order -= 1
	local group = UI.Create("CanvasGroup", {
		Name = "Notification",
		LayoutOrder = order,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = holder,
	})
	local scale = UI.Create("UIScale", { Scale = 0.6, Parent = group })
	-- a soft dark glow keeps the text readable over bright grass without drawing a box
	UI.Create("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Image = UI.Icons.Glow,
		ImageColor3 = Color3.fromRGB(40, 22, 6),
		ImageTransparency = 0.72,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 2.2, 0),
		Parent = group,
	})
	local row = UI.Create("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = group,
	}, { UI.List(10, true, Enum.HorizontalAlignment.Center) })
	UI.Icon(style.Icon, { Name = "Icon", LayoutOrder = 1, Size = UDim2.fromOffset(38, 38), Parent = row })
	local label = UI.Create("TextLabel", {
		Name = "Text",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 27,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Parent = row,
	})
	UI.Create("UIStroke", { Color = style.Stroke, Thickness = 3, Transparency = 0.05, Parent = label })
	local gradient = UI.Create("UIGradient", { Rotation = 90, Color = ColorSequence.new(style.Top, style.Bottom), Parent = label })
	if style.Rainbow then
		gradient.Rotation = 0
		gradient.Color = RAINBOW
	end
	local count = UI.Create("TextLabel", {
		Name = "Count",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(46, 40),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = style.Bottom,
		Text = "",
		Visible = false,
		Parent = row,
	}, { UI.Create("UIStroke", { Color = style.Stroke, Thickness = 2.5 }) })
	return group, scale, label, count, gradient
end

function NotificationCenter:_dismiss(entry)
	if entry.Gone then
		return
	end
	entry.Gone = true
	if active[entry.Text] == entry then
		active[entry.Text] = nil
	end
	tween(entry.Scale, 0.22, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(entry.Group, 0.22, { GroupTransparency = 1 }).Completed:Once(function()
		entry.Group:Destroy()
	end)
end

function NotificationCenter:Push(text: string, kind: string?, opts)
	if not holder or typeof(text) ~= "string" or text == "" then
		return
	end
	opts = opts or {}
	local style = STYLES[kind or "info"] or STYLES.info
	if opts.Icon then
		style = table.clone(style)
		style.Icon = opts.Icon
	end
	local duration = opts.Duration or ((kind == "rare" or kind == "event") and 5 or 3.2)

	-- same message again: bump its counter instead of stacking a duplicate
	local existing = active[text]
	if existing and not existing.Gone then
		existing.Times += 1
		existing.Count.Text = "x" .. existing.Times
		existing.Count.Visible = true
		existing.Expires = os.clock() + duration
		existing.Scale.Scale = 1.12
		tween(existing.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		return
	end

	local group, scale, label, count, gradient = build(text, style)
	local entry = { Text = text, Group = group, Scale = scale, Label = label, Count = count, Gradient = gradient, Times = 1, Expires = os.clock() + duration, Rainbow = style.Rainbow }
	active[text] = entry
	tween(group, 0.18, { GroupTransparency = 0 })
	tween(scale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
	if C.Sound then
		C.Sound:Play(style.Sound, { Volume = kind == "bad" and 0.6 or 0.9 })
	end

	-- keep the stack short: oldest lines fade first
	local entries = {}
	for _, e in active do
		if not e.Gone then
			table.insert(entries, e)
		end
	end
	if #entries > MAX_VISIBLE then
		table.sort(entries, function(a, b)
			return a.Group.LayoutOrder > b.Group.LayoutOrder
		end)
		for i = 1, #entries - MAX_VISIBLE do
			self:_dismiss(entries[i])
		end
	end
end

function NotificationCenter:Init(controllers)
	C = controllers
	UI = C.UI
end

function NotificationCenter:Start()
	holder = UI.Create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 176),
		Size = UDim2.new(0.6, 0, 0, 4 * 50),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = UI:_screen(),
	}, { UI.List(6, false, Enum.HorizontalAlignment.Center), UI.Create("UISizeConstraint", { MaxSize = Vector2.new(720, 200) }) })
	holder.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	UI.Notify = function(text, kind, opts)
		self:Push(text, kind, opts)
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, entry in active do
			if not entry.Gone then
				if now >= entry.Expires then
					self:_dismiss(entry)
				elseif entry.Rainbow then
					entry.Gradient.Offset = Vector2.new(math.sin(now * 1.6) * 0.35, 0)
				end
			end
		end
	end)
end

return NotificationCenter
