--[[
	HUD
	Icon-first heads-up display:
	  top-left    honey / bees / eggs pills (animated counters)
	  left        sidebar: Home (teleport), Hive, Shop, Eggs, Codex, Store, Settings
	  bottom      pollen bar with backpack icon, boost chips
	  bottom-right Make Honey button near your hive
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local HUD = {}

local C
local UI
local Juice
local shownHoney = 0

local SIDEBAR = {
	{ Name = "Home", Icon = "Home", Tooltip = "Teleport to hive" },
	{ Name = "Hive", Icon = "Honeycomb", Tooltip = "My hive" },
	{ Name = "Shop", Icon = "Shop", Tooltip = "Shop" },
	{ Name = "Eggs", Icon = "Egg", Tooltip = "Eggs & odds" },
	{ Name = "Codex", Icon = "Book", Tooltip = "Bee album" },
	{ Name = "Store", Icon = "Gift", Tooltip = "Store" },
	{ Name = "Settings", Icon = "Gear", Tooltip = "Settings & codes" },
}

function HUD:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

local function pill(parent: Instance, order: number, iconName: string)
	local frame = UI.Glass({
		Name = iconName .. "Pill",
		LayoutOrder = order,
		Size = UDim2.fromOffset(200, 50),
		Transparency = 0.15,
		Radius = 25,
		Parent = parent,
	})
	frame.UICorner.CornerRadius = UDim.new(1, 0)
	local icon = UI.Icon(iconName, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(22, 25),
		Size = UDim2.fromOffset(54, 54),
		ZIndex = 3,
		Parent = frame,
	})
	local label = UI.Label({
		Name = "Value",
		Text = "0",
		Position = UDim2.fromOffset(54, 6),
		Size = UDim2.new(1, -66, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Text,
		MaxTextSize = 28,
		Parent = frame,
	})
	return frame, label, icon
end

function HUD:_build()
	local screen = UI:_screen()

	-- stat pills
	local stats = UI.Create("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(220, 180),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.List(10) })
	stats.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	self.HoneyPill, self.HoneyLabel, self.HoneyIcon = pill(stats, 1, "Honey")
	self.BeePill, self.BeeLabel = pill(stats, 2, "Bee")
	self.EggPill, self.EggLabel = pill(stats, 3, "Egg")
	Juice.Float(self.HoneyIcon, 2, 2.4)

	-- sidebar
	local sidebar = UI.Create("Frame", {
		Name = "Sidebar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.56, 0),
		Size = UDim2.fromOffset(70, 7 * 74),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.List(8) })
	for i, item in SIDEBAR do
		local button = UI.IconButton(item.Icon, 64, {
			Name = item.Name,
			LayoutOrder = i,
			Tooltip = item.Tooltip,
			BackgroundTransparency = 0.1,
			Parent = sidebar,
		}, function()
			if item.Name == "Home" then
				self:TeleportHome()
			else
				UI:Toggle(item.Name)
			end
		end)
		Juice.Pop(button, i * 0.05)
	end

	-- pollen bar
	local barHolder = UI.Create("Frame", {
		Name = "PollenBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.new(0.42, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.Create("UISizeConstraint", { MaxSize = Vector2.new(460, 40), MinSize = Vector2.new(240, 40) }) })
	local bar, fill, text = UI.Bar({
		Size = UDim2.new(1, -40, 1, -8),
		Position = UDim2.new(0, 40, 0, 4),
		Color = Color3.fromRGB(255, 205, 50),
		MaxTextSize = 20,
		Parent = barHolder,
	})
	bar.Name = "Bar"
	self.PollenFill = fill
	self.PollenText = text
	self.BackpackIcon = UI.Icon("Backpack", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		ZIndex = 4,
		Parent = barHolder,
	})
	-- keep the old path working for tools/tests
	text.Name = "Text"

	-- boost chips
	self.Boosts = UI.Create("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -134),
		Size = UDim2.fromOffset(460, 30),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.List(8, true, Enum.HorizontalAlignment.Center) })

	-- make honey
	self.ConvertButton = UI.Button({
		Name = "MakeHoney",
		Text = "MAKE HONEY",
		Icon = "Honey",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -84),
		Size = UDim2.fromOffset(230, 66),
		MaxTextSize = 26,
		Visible = false,
		Parent = screen,
	}, function()
		Net.Event("ToggleConvert"):FireServer(not player:GetAttribute("Converting"))
	end)
end

function HUD:_refresh(data)
	local honey = data.Honey or 0
	local formatter = function(n)
		return n < 1e6 and Format.Commas(n) or Format.Short(n)
	end
	if math.floor(honey) ~= math.floor(shownHoney) then
		Juice.CountUp(self.HoneyLabel, shownHoney, honey, formatter, 0.5)
		if honey > shownHoney then
			Juice.Punch(self.HoneyPill, 0.08)
			Juice.Punch(self.HoneyIcon, 0.25)
		end
		shownHoney = honey
	end
	local capacity = C.State:Capacity()
	local pollen = math.floor(data.Pollen or 0)
	local ratio = capacity > 0 and math.clamp(pollen / capacity, 0, 1) or 0
	TweenService:Create(self.PollenFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.max(ratio, 0.04), 1) }):Play()
	self.PollenFill.Visible = ratio > 0
	local gradient = self.PollenFill:FindFirstChildOfClass("UIGradient")
	if gradient then
		local color = ratio >= 1 and Color3.fromRGB(255, 120, 70) or Color3.fromRGB(255, 205, 50)
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color)
	end
	self.PollenText.Text = `{Format.Short(pollen)} / {Format.Short(capacity)}`
	if ratio >= 1 and not self._fullPulsed then
		self._fullPulsed = true
		Juice.Shake(self.BackpackIcon, 5, 0.4)
	elseif ratio < 1 then
		self._fullPulsed = false
	end

	local unlocked = math.min(data.HiveSlots or 0, Config.Hive.MaxHoneySlots)
		+ (player:GetAttribute("Pass_ExtraSlots") and Config.Hive.GamepassSlots or 0)
	self.BeeLabel.Text = `{C.State:BeeCount()} / {unlocked}`
	local eggs = 0
	for _, n in data.Eggs or {} do
		eggs += n
	end
	self.EggLabel.Text = tostring(eggs)
end

-- Fast camera swoop + teleport to the player's hive pad
function HUD:TeleportHome()
	local index = player:GetAttribute("HiveIndex")
	local map = Workspace:FindFirstChild("Map")
	local hive = index and map and map.Hives:FindFirstChild("Hive_" .. index)
	local pad = hive and hive:FindFirstChild("Pad")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not pad or not root or self._teleporting then
		return
	end
	self._teleporting = true
	local camera = Workspace.CurrentCamera
	local flash = UI.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 240, 200),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Parent = UI:_screen(),
	})
	C.Sound:Play("Whoosh")
	camera.CameraType = Enum.CameraType.Scriptable
	local lift = CFrame.lookAt(root.Position + Vector3.new(0, 45, 25), root.Position)
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = lift }):Play()
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	task.wait(0.37)
	local frame = hive:FindFirstChild("Frame")
	local spot = pad.Position + Vector3.new(0, 4, 0)
	local lookAt = frame and Vector3.new(frame.Position.X, spot.Y, frame.Position.Z) or spot + Vector3.new(0, 0, -1)
	character:PivotTo(CFrame.lookAt(spot, lookAt))
	local behind = CFrame.lookAt(spot + (spot - lookAt).Unit * 14 + Vector3.new(0, 6, 0), spot)
	camera.CFrame = CFrame.lookAt(spot + Vector3.new(0, 45, 25), spot)
	TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	local down = TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = behind })
	down:Play()
	down.Completed:Wait()
	camera.CameraType = Enum.CameraType.Custom
	flash:Destroy()
	self._teleporting = false
end

function HUD:_boostChips()
	local data = C.State.Data
	if not data or not data.Boosts then
		return
	end
	for _, child in self.Boosts:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local now = os.time()
	for fieldId, expiry in data.Boosts do
		if expiry > now then
			local def = Config.FieldById[fieldId]
			local chip = UI.Create("Frame", {
				Size = UDim2.fromOffset(0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = UI.Colors.Ink,
				BackgroundTransparency = 0.35,
				Parent = self.Boosts,
			}, { UI.Round(), UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 12) }) })
			UI.Icon("Lightning", { Position = UDim2.fromOffset(-30, 2), Size = UDim2.fromOffset(26, 26), Parent = chip })
			UI.Create("TextLabel", {
				Size = UDim2.fromOffset(0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Font = UI.Body,
				TextSize = 15,
				TextColor3 = UI.Colors.White,
				Text = `2x {def and def.Name or fieldId}  {Format.Time(expiry - now)}`,
				Parent = chip,
			})
		end
	end
end

function HUD:Start()
	self:_build()

	C.State:OnChange({ "Honey", "Pollen", "Backpack", "Bees", "HiveSlots", "Eggs" }, function(data)
		self:_refresh(data)
	end)

	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		UI:Toast(text, kind)
		C.Sound:Play(kind == "rare" and "Event" or "Notify", { Volume = kind == "bad" and 0.6 or 1 })
	end)

	-- shop stands and other world objects carry an OpenPanel attribute on their prompt
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local panel = prompt:GetAttribute("OpenPanel")
		if panel then
			UI:Open(panel, prompt:GetAttribute("OpenArg"))
		end
	end)

	player:GetAttributeChangedSignal("Converting"):Connect(function()
		local on = player:GetAttribute("Converting")
		self.ConvertButton.Text = on and "STOP" or "MAKE HONEY"
		UI.SetButtonColor(self.ConvertButton, on and UI.Colors.Bad or UI.Colors.Honey)
		Juice.Punch(self.ConvertButton, 0.12)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local index = player:GetAttribute("HiveIndex")
			local map = Workspace:FindFirstChild("Map")
			local hive = index and map and map:FindFirstChild("Hives") and map.Hives:FindFirstChild("Hive_" .. index)
			local pad = hive and hive:FindFirstChild("Pad")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local near = pad and root and (root.Position - pad.Position).Magnitude <= Config.Convert.Range
			local show = near == true or player:GetAttribute("Converting") == true
			if show and not self.ConvertButton.Visible then
				self.ConvertButton.Visible = true
				Juice.Pop(self.ConvertButton)
			elseif not show then
				self.ConvertButton.Visible = false
			end
		end
	end)
	task.spawn(function()
		while true do
			self:_boostChips()
			task.wait(1)
		end
	end)
end

return HUD
