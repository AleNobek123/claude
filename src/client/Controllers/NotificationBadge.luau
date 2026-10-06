--[[
	NotificationBadge
	The red bouncing "!" hook on HUD menu tiles. Each badge is a red bubble with an outlined "!"
	that loops a rotation wobble and a scale bounce (TweenService, reversing, infinite).

	  NotificationBadge:Attach(name, gui)   host a badge on a GuiObject (top-right corner)
	  NotificationBadge:Set(name, visible)  show / hide it (pops in with Back easing)
	  NotificationBadge:Rule(name, fn)      fn(data) -> boolean, evaluated once per second

	Built-in rules: Shop (an upgrade is affordable), Codex (newly discovered bees not opened yet),
	Rewards (daily / playtime / social reward ready), Eggs (an owned egg and a free hive cell).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local player = Players.LocalPlayer

local NotificationBadge = {}

local C
local UI
local badges = {} -- [name] = { Holder, Tweens, Visible }
local rules = {} -- [name] = fn

local WOBBLE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local BOUNCE = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true)

local function build(host: GuiObject)
	local holder = UI.Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = host,
	})
	local scale = UI.Create("UIScale", { Scale = 0, Parent = holder })
	local bubble = UI.Create("Frame", {
		Name = "Bubble",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 40,
		Parent = holder,
	}, {
		UI.Round(),
		UI.Gradient(Color3.fromRGB(255, 110, 100), Color3.fromRGB(215, 20, 30)),
		UI.Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
	})
	UI.Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Text = "!",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 41,
		Parent = bubble,
	}, { UI.Create("UIStroke", { Color = Color3.fromRGB(110, 0, 0), Thickness = 1.5 }), UI.Create("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.08, 0) }) })
	return holder, scale, bubble
end

function NotificationBadge:Attach(name: string, host: GuiObject)
	if badges[name] or not host then
		return
	end
	local holder, scale, bubble = build(host)
	badges[name] = { Holder = holder, Scale = scale, Bubble = bubble, Loops = {}, Visible = false }
end

function NotificationBadge:Set(name: string, visible: boolean)
	local badge = badges[name]
	if not badge or badge.Visible == visible then
		return
	end
	badge.Visible = visible
	for _, tween in badge.Loops do
		tween:Cancel()
	end
	table.clear(badge.Loops)
	if visible then
		badge.Holder.Visible = true
		badge.Bubble.Rotation = -12
		badge.Bubble.Size = UDim2.fromScale(1, 1)
		TweenService:Create(badge.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local wobble = TweenService:Create(badge.Bubble, WOBBLE, { Rotation = 12 })
		local bounce = TweenService:Create(badge.Bubble, BOUNCE, { Size = UDim2.fromScale(1.25, 1.25) })
		wobble:Play()
		bounce:Play()
		badge.Loops = { wobble, bounce }
	else
		local out = TweenService:Create(badge.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		out:Play()
		out.Completed:Once(function()
			if not badge.Visible then
				badge.Holder.Visible = false
			end
		end)
	end
end

function NotificationBadge:Rule(name: string, fn)
	rules[name] = fn
end

-- Built-in rules ----------------------------------------------------------------------------------

local function nextAffordable(data, list, owned): boolean
	for i, item in list do
		if not owned[item.Id] then
			local previous = list[i - 1]
			return (not previous or owned[previous.Id]) and (data.Honey or 0) >= item.Price
		end
	end
	return false
end

local function hasFreeCell(data): boolean
	local unlocked = math.min(data.HiveSlots or 0, Config.Hive.MaxHoneySlots)
		+ (player:GetAttribute("Pass_ExtraSlots") and Config.Hive.GamepassSlots or 0)
	return C.State:BeeCount() < unlocked
end

function NotificationBadge:_defaultRules()
	self:Rule("Shop", function(data)
		return nextAffordable(data, Config.Collectors, data.OwnedCollectors or {})
			or nextAffordable(data, Config.Backpacks, data.OwnedBackpacks or {})
			or nextAffordable(data, Config.Boots, data.OwnedBoots or {})
	end)
	self:Rule("Codex", function(data)
		for id in data.Codex or {} do
			if not (data.CodexSeen and data.CodexSeen[id]) then
				return true
			end
		end
		return false
	end)
	self:Rule("Rewards", function()
		return C.Rewards and C.Rewards:AnyClaimable() or false
	end)
	self:Rule("Eggs", function(data)
		local eggs = 0
		for _, n in data.Eggs or {} do
			eggs += n
		end
		return eggs > 0 and hasFreeCell(data)
	end)
end

function NotificationBadge:Init(controllers)
	C = controllers
	UI = C.UI
end

function NotificationBadge:Start()
	self:_defaultRules()
	while not (C.HUD and C.HUD.MenuButtons) do
		task.wait(0.2)
	end
	for name in rules do
		self:Attach(name, C.HUD.MenuButtons[name])
	end
	task.spawn(function()
		while true do
			local data = C.State.Data
			if data then
				for name, fn in rules do
					local ok, on = pcall(fn, data)
					self:Set(name, ok and on == true)
				end
			end
			task.wait(1)
		end
	end)
end

return NotificationBadge
