--[[
	Rewards
	Free-rewards hub, everything claimed by hand:
	  Daily     7-day login grid (streak), today's tile glows with a CLAIM button
	  Playtime  milestones up to 2 hours of play today, live countdowns
	  Social    like / group / follow rewards through modular providers (see Config.Rewards.Social)
	Amounts shown are already scaled to the player's progression (server-side Config.ScaleReward).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local ShopJuicer = require(script.Parent.ShopJuicer)

local Rewards = {}

local C
local UI
local Juice
local state = nil
local fetchedAt = 0
local content: Frame
local sections = {}
local adAvailable = RunService:IsStudio() -- ads never run in Studio; the server grants directly there
local adBusy = false

function Rewards:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

local function rewardIcon(reward): string
	if reward.Eggs then
		return "Egg"
	elseif reward.Treats and not reward.Honey then
		return "Treat"
	end
	return "Honey"
end

local function rewardText(reward): string
	local scaled = Config.ScaleReward(reward, C.State.Data and C.State.Data.TotalHoney)
	if scaled.Eggs then
		for eggId, n in scaled.Eggs do
			return `{n}x {Config.Eggs[eggId].Name}`
		end
	end
	local parts = {}
	if scaled.Honey then
		table.insert(parts, Format.Short(scaled.Honey))
	end
	if scaled.Treats then
		table.insert(parts, `{scaled.Treats} treats`)
	end
	return table.concat(parts, " + ")
end

function Rewards:_fetch()
	local ok, success, result = pcall(function()
		return Net.Function("Rewards"):InvokeServer("State")
	end)
	if ok and success and result then
		state = result
		fetchedAt = os.clock()
	end
	return state
end

local function playSeconds(): number
	if not state then
		return 0
	end
	return state.Playtime.Seconds + (os.clock() - fetchedAt)
end

function Rewards:AnyClaimable(): boolean
	if not state or os.clock() - fetchedAt > 15 then
		task.spawn(self._fetch, self)
	end
	if not state then
		return false
	end
	if state.Daily.Claimable then
		return true
	end
	local seconds = playSeconds()
	for i, milestone in Config.Rewards.Playtime do
		if not state.Playtime.Claimed[tostring(i)] and seconds >= milestone.Minutes * 60 then
			return true
		end
	end
	for id, s in state.Social do
		if not s.Claimed and (not s.Started or s.Ready) then
			return true
		end
	end
	return false
end

local function claim(action: string, arg, source: GuiObject?)
	local ok, success, message, fresh = pcall(function()
		return Net.Function("Rewards"):InvokeServer(action, arg)
	end)
	if not ok then
		return
	end
	if fresh then
		state = fresh
		fetchedAt = os.clock()
	end
	C.NotificationCenter:Push(message or "", success and "good" or "info")
	if success then
		C.Sound:Play("Purchase")
		if source then
			ShopJuicer.Burst(source, 14)
		end
	end
	Rewards:_render()
end

-- Tiles -----------------------------------------------------------------------------------------------

local function sectionTitle(parent: Instance, order: number, icon: string, text: string)
	local row = UI.Create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = parent })
	UI.Icon(icon, { Size = UDim2.fromOffset(32, 32), Parent = row })
	UI.Label({ Text = text, Position = UDim2.fromOffset(40, 2), Size = UDim2.new(1, -40, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = row })
	return row
end

local function tile(parent: Instance, order: number, size: Vector2, color: Color3, glow: boolean)
	local frame = UI.Create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, { UI.Corner(16), UI.Gradient(color:Lerp(Color3.new(1, 1, 1), 0.45), color) })
	if glow then
		ShopJuicer.Shine(frame, { Period = 0.8, Pause = 1.2, Transparency = 0.1 })
		local stroke = UI.Create("UIStroke", { Color = Color3.fromRGB(255, 240, 120), Thickness = 3, Parent = frame })
		Juice.Float(frame, 2, 3)
		stroke.Transparency = 0
	end
	return frame
end

function Rewards:_renderDaily(parent: Instance)
	local grid = UI.Create("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1, Parent = parent }, { UI.List(8, true, Enum.HorizontalAlignment.Center) })
	for i, reward in Config.Rewards.Daily do
		local current = state.Daily.Index == i
		local done = i < state.Daily.Index or (current and not state.Daily.Claimable)
		local color = done and Color3.fromRGB(150, 220, 150) or (current and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(240, 220, 190))
		local frame = tile(grid, i, Vector2.new(92, 116), color, current and state.Daily.Claimable)
		UI.Label({ Text = "Day " .. i, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 20), MaxTextSize = 16, Parent = frame })
		UI.Icon(rewardIcon(reward), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(44, 44), Parent = frame })
		UI.Label({ Text = rewardText(reward), Font = UI.Body, Position = UDim2.fromOffset(4, 70), Size = UDim2.new(1, -8, 0, 18), MaxTextSize = 13, Parent = frame })
		if done then
			UI.Icon("Check", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(22, 22), Parent = frame })
		elseif current then
			UI.Button({ Text = "CLAIM", BackgroundColor3 = UI.Colors.Good, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -10, 0, 24), MaxTextSize = 14, Parent = frame }, function()
				claim("Daily", nil, frame)
			end)
		end
	end
end

function Rewards:_renderPlaytime(parent: Instance)
	local grid = UI.Create("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 124), BackgroundTransparency = 1, Parent = parent }, { UI.List(8, true, Enum.HorizontalAlignment.Center) })
	sections.Timers = {}
	local seconds = playSeconds()
	for i, milestone in Config.Rewards.Playtime do
		local claimed = state.Playtime.Claimed[tostring(i)] == true
		local ready = not claimed and seconds >= milestone.Minutes * 60
		local color = claimed and Color3.fromRGB(150, 220, 150) or (ready and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(210, 220, 245))
		local frame = tile(grid, i, Vector2.new(82, 120), color, ready)
		UI.Label({ Text = milestone.Minutes >= 60 and `{milestone.Minutes / 60}h` or `{milestone.Minutes}m`, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 20), MaxTextSize = 17, Parent = frame })
		UI.Icon(rewardIcon(milestone.Reward), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(40, 40), Parent = frame })
		UI.Label({ Text = rewardText(milestone.Reward), Font = UI.Body, Position = UDim2.fromOffset(4, 66), Size = UDim2.new(1, -8, 0, 18), MaxTextSize = 12, Parent = frame })
		if claimed then
			UI.Icon("Check", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(22, 22), Parent = frame })
		elseif ready then
			UI.Button({ Text = "CLAIM", BackgroundColor3 = UI.Colors.Good, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -10, 0, 24), MaxTextSize = 13, Parent = frame }, function()
				claim("Playtime", i, frame)
			end)
		else
			local timer = UI.Label({ Font = UI.Body, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -8, 0, 18), MaxTextSize = 14, TextColor3 = UI.Colors.Muted, Parent = frame })
			table.insert(sections.Timers, { Label = timer, At = milestone.Minutes * 60 })
		end
	end
end

function Rewards:_renderSocial(parent: Instance)
	local box = UI.Create("Frame", { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, #Config.Rewards.Social * 58), BackgroundTransparency = 1, Parent = parent }, { UI.List(8) })
	for i, provider in Config.Rewards.Social do
		local s = state.Social[provider.Id] or {}
		local frame = tile(box, i, Vector2.new(0, 50), Color3.fromRGB(225, 215, 255), not s.Claimed and s.Ready == true)
		frame.Size = UDim2.new(1, -8, 0, 50)
		UI.Icon(provider.Icon, { Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(40, 40), Parent = frame })
		UI.Label({ Text = provider.Name, Position = UDim2.fromOffset(58, 4), Size = UDim2.new(1, -230, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 19, Parent = frame })
		UI.Label({ Text = rewardText(provider.Reward), Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(58, 27), Size = UDim2.new(1, -230, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = frame })
		if s.Claimed then
			UI.Icon("Check", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(30, 30), Parent = frame })
		else
			local label = (provider.Provider == "Honor" and not s.Started) and "VERIFY" or "CLAIM"
			UI.Button({ Text = label, BackgroundColor3 = label == "CLAIM" and UI.Colors.Good or UI.Colors.Blue, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 36), MaxTextSize = 16, Parent = frame }, function()
				claim("Social", provider.Id, frame)
			end)
		end
	end
end

-- Roblox only serves rewarded videos to eligible players (13+, supported region/device)
local function checkAdAvailability()
	if RunService:IsStudio() then
		return
	end
	if Config.AdReward.ProductId == 0 then
		adAvailable = false -- not set up yet: no video card in live servers
		return
	end
	local format
	for _, item in Enum.AdFormat:GetEnumItems() do
		if item.Name:find("Rewarded") then
			format = item
			break
		end
	end
	if not format then
		adAvailable = false
		return
	end
	local ok, result = pcall(function()
		return game:GetService("AdService"):GetAdAvailabilityNowAsync(format)
	end)
	adAvailable = ok and result ~= nil and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
end

local function bonusCard(parent: Instance, order: number, color: Color3, glow: boolean, icon: string, title: string, sub: string)
	local frame = tile(parent, order, Vector2.new(0, 56), color, glow)
	frame.Size = UDim2.new(1, -8, 0, 56)
	UI.Icon(icon, { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(44, 44), Parent = frame })
	UI.Label({ Text = title, Position = UDim2.fromOffset(62, 5), Size = UDim2.new(1, -240, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 19, Parent = frame })
	local subLabel = UI.Label({ Text = sub, Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(62, 30), Size = UDim2.new(1, -240, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = frame })
	return frame, subLabel
end

function Rewards:_renderBonus(parent: Instance)
	local ad = state.Ad
	local premium = state.Premium
	local showAd = ad ~= nil and adAvailable
	local box = UI.Create("Frame", { LayoutOrder = 8, Size = UDim2.new(1, 0, 0, (showAd and 64 or 0) + 64), BackgroundTransparency = 1, Parent = parent }, { UI.List(8) })
	sections.Ad = nil

	if showAd then
		local ready = ad.Left > 0
		local frame = bonusCard(box, 1, Color3.fromRGB(255, 205, 120), ready and not adBusy, "Honey", "Watch a video",
			`+{Format.Short(ad.Amount)} honey  •  {ad.Left}/{ad.Max} left`)
		if ready then
			local button
			button = UI.Button({ Text = adBusy and "LOADING..." or "WATCH", BackgroundColor3 = UI.Colors.Good, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 38), MaxTextSize = 16, Parent = frame }, function()
				if adBusy then
					return
				end
				adBusy = true
				button.Text = "LOADING..."
				claim("Ad", nil, frame) -- yields until the video has finished
				adBusy = false
				self:_render()
				-- the honey arrives through a purchase receipt a moment later: refresh the counter then
				task.delay(3, function()
					if UI.Current == "Rewards" then
						self:_fetch()
						self:_render()
					end
				end)
			end)
		else
			local timer = UI.Label({ Font = UI.Body, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 22), MaxTextSize = 15, TextColor3 = UI.Colors.Muted, Parent = frame })
			sections.Ad = { Label = timer, At = os.clock() + ad.NextIn }
		end
	end

	local bonus = math.floor((premium and premium.Bonus or Config.Premium.HoneyBonus) * 100 + 0.5)
	local frame = bonusCard(box, 2, Color3.fromRGB(255, 225, 150), false, "Star", "Roblox Premium", `+{bonus}% honey on everything you make`)
	if premium and premium.Active then
		UI.Label({ Text = "ACTIVE", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -50, 0.5, 0), Size = UDim2.fromOffset(100, 26), MaxTextSize = 18, TextColor3 = UI.Colors.Good, Parent = frame })
		UI.Icon("Check", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(30, 30), Parent = frame })
	else
		UI.Button({ Text = "GET PREMIUM", BackgroundColor3 = UI.Colors.Honey, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 38), MaxTextSize = 16, Parent = frame }, function()
			pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, Players.LocalPlayer)
		end)
	end
end

function Rewards:_render()
	if not content or not state then
		return
	end
	for _, child in content.List:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = content.List
	sectionTitle(list, 1, "Gift", `Daily login  •  streak {state.Daily.Streak}`)
	self:_renderDaily(list)
	sectionTitle(list, 3, "Honey", "Playtime rewards")
	self:_renderPlaytime(list)
	sectionTitle(list, 5, "Star", "Support the game")
	self:_renderSocial(list)
	sectionTitle(list, 7, "Sparkles", "Bonus honey")
	self:_renderBonus(list)
end

function Rewards:Start()
	local panelContent, panel = UI:Panel("Rewards", "Free Rewards", "Gift")
	content = panelContent
	UI.Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UI.List(10), UI.Padding(6) })
	content.List.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	content.List.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panel.OnOpen = function()
		self:_fetch()
		self:_render()
		task.spawn(function()
			local before = adAvailable
			checkAdAvailability()
			if adAvailable ~= before and UI.Current == "Rewards" then
				self:_render()
			end
		end)
	end
	-- live countdowns while the panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.Current == "Rewards" and sections.Ad then
				local left = sections.Ad.At - os.clock()
				if left <= 0 then
					self:_fetch()
					self:_render()
				else
					sections.Ad.Label.Text = "Next in " .. Format.Time(left)
				end
			end
			if UI.Current == "Rewards" and sections.Timers then
				local seconds = playSeconds()
				for _, t in sections.Timers do
					local left = t.At - seconds
					if left <= 0 then
						self:_render()
						break
					end
					t.Label.Text = Format.Time(left)
				end
			end
		end
	end)
	task.delay(3, function()
		self:_fetch()
	end)
end

return Rewards
