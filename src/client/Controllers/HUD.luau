--[[
	HUD
	Borderless, colour-rich heads-up display:
	  top-left      honey / bees / eggs: big outlined numbers next to their icons (no boxes)
	  left          compact menu grid of saturated tiles: Home, Hive, Shop, Eggs, Codex, Store, Settings
	  bottom        pollen bar with backpack icon, boost chips
	  bottom-right  glossy MAKE HONEY button near your hive
	The default Roblox hotbar is disabled: the collector is always equipped.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local ShopJuicer = require(script.Parent.ShopJuicer)

local player = Players.LocalPlayer

local HUD = {}

local C
local UI
local Juice
local shownHoney = 0

local MENU = {
	{ Name = "Home", Icon = "Home", Tooltip = "Teleport to hive", Color = Color3.fromRGB(64, 170, 255) },
	{ Name = "Hive", Icon = "Honeycomb", Tooltip = "My hive", Color = Color3.fromRGB(150, 92, 255) },
	{ Name = "Shop", Icon = "Shop", Tooltip = "Shop", Color = Color3.fromRGB(255, 140, 36) },
	{ Name = "Eggs", Icon = "Egg", Tooltip = "Eggs & odds", Color = Color3.fromRGB(255, 84, 160) },
	{ Name = "Codex", Icon = "Book", Tooltip = "Bee album", Color = Color3.fromRGB(255, 196, 30) },
	{ Name = "Rewards", Icon = "Gift", Tooltip = "Free rewards", Color = Color3.fromRGB(60, 200, 110) },
	{ Name = "Store", Icon = "Star", Tooltip = "Robux store", Color = Color3.fromRGB(240, 58, 72) },
	{ Name = "Feedback", Icon = "Speaker", Tooltip = "Report a bug / review", Color = Color3.fromRGB(120, 130, 255) },
	{ Name = "Settings", Icon = "Gear", Tooltip = "Settings & codes", Color = Color3.fromRGB(38, 180, 160) },
}
local TILE = 64
local GAP = 10
local STATS_HEIGHT = 64 + 52 + 52 + 2 * 6

function HUD:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

-- Outlined number next to an icon; no background at all
local function stat(parent: Instance, order: number, iconName: string, big: boolean?)
	local height = big and 64 or 52
	local row = UI.Create("Frame", {
		Name = iconName .. "Stat",
		LayoutOrder = order,
		Size = UDim2.fromOffset(260, height),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local iconSize = big and 62 or 50
	UI.Icon(iconName, {
		Name = "IconShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, iconSize / 2 + 2, 0.5, 3),
		Size = UDim2.fromOffset(iconSize, iconSize),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.7,
		Parent = row,
	})
	local icon = UI.Icon(iconName, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, iconSize / 2, 0.5, 0),
		Size = UDim2.fromOffset(iconSize, iconSize),
		ZIndex = 2,
		Parent = row,
	})
	local label = UI.Create("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(iconSize + 10, 0),
		Size = UDim2.new(1, -iconSize - 10, 1, 0),
		Font = UI.Font,
		TextSize = big and 40 or 32,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		ZIndex = 2,
		Parent = row,
	})
	UI.Create("UIStroke", { Color = Color3.fromRGB(84, 46, 12), Thickness = big and 3.5 or 3, Parent = label })
	UI.Create("UIGradient", {
		Rotation = 90,
		Color = big and ColorSequence.new(Color3.fromRGB(255, 252, 220), Color3.fromRGB(255, 196, 46)) or ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 232, 190)),
		Parent = label,
	})
	return row, label, icon
end

-- Saturated rounded tile with a glossy top highlight; text only on hover
local function tile(parent: Instance, order: number, item, onClick)
	local button = UI.Create("ImageButton", {
		Name = item.Name,
		LayoutOrder = order,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Image = "",
		Parent = parent,
	}, { UI.Corner(18), UI.Gradient(item.Color:Lerp(Color3.new(1, 1, 1), 0.22), item.Color:Lerp(Color3.new(0, 0, 0), 0.12)) })
	UI.Create("Frame", {
		Name = "Gloss",
		Position = UDim2.fromScale(0.08, 0.05),
		Size = UDim2.fromScale(0.84, 0.42),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Parent = button,
	}, { UI.Corner(14) })
	UI.Icon(item.Icon, {
		Name = "IconShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 2, 0.5, 4),
		Size = UDim2.fromScale(0.7, 0.7),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.65,
		Parent = button,
	})
	UI.Icon(item.Icon, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Parent = button,
	})
	local tip = UI.Create("TextLabel", {
		Name = "Tooltip",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 12, 0.5, 0),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = item.Tooltip,
		Visible = false,
		ZIndex = 30,
		Parent = button,
	}, { UI.Create("UIStroke", { Color = item.Color:Lerp(Color3.new(0, 0, 0), 0.55), Thickness = 3 }) })
	button.MouseEnter:Connect(function()
		tip.Visible = true
		tip.TextTransparency = 1
		TweenService:Create(tip, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	end)
	button.MouseLeave:Connect(function()
		tip.Visible = false
	end)
	Juice.Bind(button, { Rotate = 4 })
	button.Activated:Connect(onClick)
	return button
end

function HUD:_build()
	local screen = UI:_screen()

	-- stats
	local stats = UI.Create("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.fromOffset(260, STATS_HEIGHT),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.List(6), UI.Create("UIScale", { Name = "Responsive" }) })
	stats.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	self.Stats = stats
	self.HoneyStat, self.HoneyLabel, self.HoneyIcon = stat(stats, 1, "Honey", true)
	self.BeeStat, self.BeeLabel = stat(stats, 2, "Bee")
	self.EggStat, self.EggLabel = stat(stats, 3, "Egg")
	Juice.Float(self.HoneyIcon, 2, 2.4)

	-- menu grid
	local menu = UI.Create("Frame", {
		Name = "Menu",
		Position = UDim2.fromOffset(18, 200),
		Size = UDim2.fromOffset(3 * (TILE + GAP) - GAP, 3 * (TILE + GAP)),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UI.Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.Create("UIScale", { Name = "Responsive" }),
	})
	self.Menu = menu
	self.MenuButtons = {}
	for i, item in MENU do
		local button = tile(menu, i, item, function()
			if item.Name == "Home" then
				self:TeleportHome()
			else
				UI:Toggle(item.Name)
			end
		end)
		self.MenuButtons[item.Name] = button
		Juice.Pop(button, i * 0.04)
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
	self.PollenBar = barHolder
	local bar, fill, text = UI.Bar({
		Size = UDim2.new(1, -40, 1, -8),
		Position = UDim2.new(0, 40, 0, 4),
		Color = Color3.fromRGB(255, 205, 50),
		MaxTextSize = 20,
		Parent = barHolder,
	})
	bar.Name = "Bar"
	text.Name = "Text"
	self.PollenFill = fill
	self.PollenText = text
	self.BackpackIcon = UI.Icon("Backpack", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		ZIndex = 4,
		Parent = barHolder,
	})

	-- boost chips
	self.Boosts = UI.Create("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -134),
		Size = UDim2.fromOffset(460, 30),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.List(8, true, Enum.HorizontalAlignment.Center) })

	self:_buildConvertButton(screen)
end

-- Glossy honey button: soft shadow + glow behind, light sweep across, outlined label
function HUD:_buildConvertButton(screen: Instance)
	local holder = UI.Create("Frame", {
		Name = "MakeHoney",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -84),
		Size = UDim2.fromOffset(240, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	}, { UI.Create("UIScale", { Name = "Responsive" }) })
	local glow = UI.Create("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Image = UI.Icons.Glow,
		ImageColor3 = Color3.fromRGB(255, 190, 40),
		ImageTransparency = 0.5,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1.5, 0, 2.4, 0),
		Parent = holder,
	})
	UI.Create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = UI.Icons.Shadow,
		ImageColor3 = Color3.fromRGB(90, 40, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(80, 80, 176, 176),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Size = UDim2.new(1, 30, 1, 30),
		Parent = holder,
	})
	local button = UI.Create("TextButton", {
		Name = "Button",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = holder,
	}, { UI.Round() })
	-- the gradient would tint the button's own text, so the label is a separate child
	local gradient = UI.Create("UIGradient", { Rotation = 90, Parent = button })
	UI.Create("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(1, -28, 0.38, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Parent = button,
	}, { UI.Round() })
	local label = UI.Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(58, 0),
		Size = UDim2.new(1, -66, 1, 0),
		Font = UI.Font,
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "MAKE HONEY",
		ZIndex = 3,
		Parent = button,
	})
	local outline = UI.Create("UIStroke", { Thickness = 3, Parent = label })
	local icon = UI.Icon("Honey", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 30, 0.5, -2),
		Size = UDim2.fromOffset(62, 62),
		ZIndex = 3,
		Parent = button,
	})
	ShopJuicer.Shine(button, { Period = 0.8, Pause = 1.8, Transparency = 0.1 })
	Juice.Bind(button)
	button.Activated:Connect(function()
		Net.Event("ToggleConvert"):FireServer(not player:GetAttribute("Converting"))
	end)
	local function paint(on: boolean)
		local top = on and Color3.fromRGB(255, 120, 110) or Color3.fromRGB(255, 214, 70)
		local bottom = on and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(255, 130, 20)
		gradient.Color = ColorSequence.new(top, bottom)
		outline.Color = on and Color3.fromRGB(110, 16, 16) or Color3.fromRGB(130, 60, 0)
		glow.ImageColor3 = on and Color3.fromRGB(255, 90, 80) or Color3.fromRGB(255, 190, 40)
		label.Text = on and "STOP" or "MAKE HONEY"
	end
	paint(false)
	self.ConvertHolder = holder
	self.ConvertButton = button
	self.ConvertGlow = glow
	self.ConvertIcon = icon
	self._paintConvert = paint
end

-- Fit the HUD to the viewport: scale clusters down on small screens, widen the menu grid when
-- it would run too low, keep the bottom-left (thumbstick) and bottom-right (jump) clear on touch.
function HUD:_layout()
	local viewport = Workspace.CurrentCamera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local height = viewport.Y - inset.Y
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local scale = math.clamp(math.min(height / 760, viewport.X / 1200), 0.55, 1)
	self.Stats.Responsive.Scale = scale
	self.Menu.Responsive.Scale = scale
	self.ConvertHolder.Responsive.Scale = scale
	local top = 10 + STATS_HEIGHT * scale + 16
	self.Menu.Position = UDim2.fromOffset(18, top)
	local bottom = touch and height * 0.62 or height - 16
	local columns = 3
	while columns < #MENU and top + math.ceil(#MENU / columns) * (TILE + GAP) * scale > bottom do
		columns += 1
	end
	local rows = math.ceil(#MENU / columns)
	self.Menu.Size = UDim2.fromOffset(columns * (TILE + GAP) - GAP, rows * (TILE + GAP))
	self.PollenBar.Position = UDim2.new(0.5, 0, 1, touch and -24 or -86)
	self.Boosts.Position = UDim2.new(0.5, 0, 1, touch and -72 or -134)
	self.ConvertHolder.Position = UDim2.new(1, -24, 1, touch and -150 - 60 * scale or -84)
end

function HUD:_refresh(data)
	local honey = data.Honey or 0
	local formatter = function(n)
		return n < 1e6 and Format.Commas(n) or Format.Short(n)
	end
	if math.floor(honey) ~= math.floor(shownHoney) then
		Juice.CountUp(self.HoneyLabel, shownHoney, honey, formatter, 0.35)
		-- converting sends honey many times a second: punch at most every 0.7 s so it never flickers
		local now = os.clock()
		if honey > shownHoney and now - (self._lastPunch or 0) > 0.7 then
			self._lastPunch = now
			Juice.Punch(self.HoneyLabel, 0.1)
			Juice.Punch(self.HoneyIcon, 0.2)
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
	self._full = ratio >= 1
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

-- Honey-drip transition; the jump happens while the centre of the screen is covered
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
	C.TeleportTransition:Play(function()
		local frame = hive:FindFirstChild("Frame")
		local spot = pad.Position + Vector3.new(0, 4, 0)
		local lookAt = frame and Vector3.new(frame.Position.X, spot.Y, frame.Position.Z) or spot + Vector3.new(0, 0, -1)
		character:PivotTo(CFrame.lookAt(spot, lookAt))
		camera.CFrame = CFrame.lookAt(spot + (spot - lookAt).Unit * 14 + Vector3.new(0, 6, 0), spot)
	end)
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
				BackgroundTransparency = 1,
				Parent = self.Boosts,
			}, { UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 6) }) })
			UI.Icon("Lightning", { Position = UDim2.fromOffset(-32, 1), Size = UDim2.fromOffset(28, 28), Parent = chip })
			UI.Create("TextLabel", {
				Size = UDim2.fromOffset(0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Font = UI.Font,
				TextSize = 20,
				TextColor3 = Color3.fromRGB(255, 236, 140),
				Text = `2x {def and def.Name or fieldId}  {Format.Time(expiry - now)}`,
				Parent = chip,
			}, { UI.Create("UIStroke", { Color = Color3.fromRGB(90, 46, 6), Thickness = 2.5 }) })
		end
	end
end

-- The default hotbar is replaced by the always-equipped collector
local function disableHotbar()
	for _ = 1, 20 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

local function keepCollectorEquipped()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or humanoid.Health <= 0 or not backpack or character:FindFirstChildWhichIsA("Tool") then
		return
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("CollectorId") then
			humanoid:EquipTool(tool)
			return
		end
	end
end

function HUD:Start()
	task.spawn(disableHotbar)
	self:_build()
	self:_layout()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:_layout()
	end)

	-- coalesce rapid state updates (auto-convert loops) into at most ~6 HUD refreshes a second
	local queued = false
	C.State:OnChange({ "Honey", "Pollen", "Backpack", "Bees", "HiveSlots", "Eggs" }, function(data)
		if queued then
			return
		end
		queued = true
		task.delay(0.15, function()
			queued = false
			self:_refresh(C.State.Data)
		end)
	end)

	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		C.NotificationCenter:Push(text, kind)
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
		self._paintConvert(player:GetAttribute("Converting") == true)
		Juice.Punch(self.ConvertButton, 0.12)
	end)

	-- full backpack: the honey button breathes so it is impossible to miss
	RunService.RenderStepped:Connect(function()
		if self.ConvertHolder.Visible then
			local t = os.clock()
			local strength = self._full and 0.25 or 0.08
			self.ConvertGlow.ImageTransparency = 0.5 - math.sin(t * (self._full and 6 or 2.5)) * strength
			self.ConvertIcon.Rotation = math.sin(t * 3) * (self._full and 10 or 4)
		end
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
			if show and not self.ConvertHolder.Visible then
				self.ConvertHolder.Visible = true
				Juice.Pop(self.ConvertButton)
			elseif not show then
				self.ConvertHolder.Visible = false
			end
			keepCollectorEquipped()
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
