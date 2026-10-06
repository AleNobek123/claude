--[[
	Promo
	"x2 Honey Forever" promotional banner (right side of the HUD) and the matching Store tile.
	The offer climbs a ladder: buying x2 unlocks x4, then x8, ... forever (Config.HoneyLadder).
	Both tiles use ShopJuicer: light sweep, rotating rays, twinkles, and a burst on purchase.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ShopJuicer = require(script.Parent.ShopJuicer)

local player = Players.LocalPlayer

local Promo = {}

local C
local UI
local Juice
local tiles = {} -- every built tile: { Title, Price, Owned, Root }

local TOP = Color3.fromRGB(255, 120, 200)
local BOTTOM = Color3.fromRGB(255, 150, 30)

local function tier(): number
	return player:GetAttribute("HoneyTier") or 0
end

local function outlined(props, strokeColor: Color3, thickness: number)
	local label = UI.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	})
	for key, value in props do
		if key ~= "Parent" then
			label[key] = value
		end
	end
	UI.Create("UIStroke", { Color = strokeColor, Thickness = thickness, Parent = label })
	label.Parent = props.Parent
	return label
end

-- One glossy offer tile; `size` in pixels. Returns the clickable button.
function Promo:_tile(parent: Instance, size: Vector2, compact: boolean)
	local button = UI.Create("ImageButton", {
		Name = "HoneyForever",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Image = "",
		ZIndex = 3,
		Parent = parent,
	}, { UI.Corner(22), UI.Gradient(TOP, BOTTOM, 35) })
	UI.Create("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -20, 0.36, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = button,
	}, { UI.Corner(16) })
	local icon = UI.Icon("Honey", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, size.Y * 0.42, 0.45, 0),
		Size = UDim2.fromOffset(size.Y * 0.82, size.Y * 0.82),
		ZIndex = 4,
		Parent = button,
	})
	local textLeft = size.Y * 0.85
	local title = outlined({
		Name = "Title",
		Position = UDim2.new(0, textLeft, 0.08, 0),
		Size = UDim2.new(1, -textLeft - 10, 0.42, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = button,
	}, Color3.fromRGB(120, 20, 70), 3)
	outlined({
		Name = "Forever",
		Text = "FOREVER",
		Position = UDim2.new(0, textLeft, 0.5, 0),
		Size = UDim2.new(0.28, 0, 0.18, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 246, 170),
		ZIndex = 4,
		Parent = button,
	}, Color3.fromRGB(120, 40, 10), 2)
	local price = UI.Create("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -7),
		Size = UDim2.new(0.34, 0, 0.28, 0),
		BackgroundColor3 = Color3.fromRGB(70, 210, 90),
		ZIndex = 4,
		Parent = button,
	}, { UI.Round(), UI.Gradient(Color3.fromRGB(130, 240, 120), Color3.fromRGB(40, 180, 70)) })
	local priceText = outlined({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = price,
	}, Color3.fromRGB(20, 90, 30), 2)
	UI.Create("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), Parent = price })
	local owned = outlined({
		Name = "Owned",
		Position = UDim2.new(0, textLeft, 0.72, 0),
		Size = UDim2.new(0.3, 0, 0.17, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 4,
		Parent = button,
	}, Color3.fromRGB(100, 20, 60), 2)

	ShopJuicer.Shine(button, { Period = 0.9, Pause = 1.4, Transparency = 0.05 })
	ShopJuicer.Sparkle(button, { Rate = compact and 1.5 or 2.5 })
	Juice.Bind(button, { Hover = 1.06, Rotate = 2 })
	button.Activated:Connect(function()
		ShopJuicer.Burst(button, 8)
		Net.Event("RequestPurchase"):FireServer("Ladder", "Honey")
	end)

	local entry = { Root = button, Title = title, Price = priceText, Owned = owned, Icon = icon }
	table.insert(tiles, entry)
	self:_paint(entry)
	return button, entry
end

function Promo:_paint(entry)
	local current = tier()
	local nextMult = Config.HoneyMultiplier(current + 1)
	entry.Title.Text = `x{nextMult} HONEY`
	entry.Price.Text = `R$ {Config.HoneyLadderStep(current).Robux}`
	entry.Owned.Text = current > 0 and `you have x{Config.HoneyMultiplier(current)}` or ""
end

function Promo:_buildBanner()
	-- holder without a layout, so the rotating rays can sit behind the tile as a sibling
	local holder = UI.Create("Frame", {
		Name = "PromoBanner",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.42, 0),
		Size = UDim2.fromOffset(250, 100),
		BackgroundTransparency = 1,
		Parent = UI:_screen(),
	}, { UI.Create("UIScale", { Name = "Responsive" }) })
	local button = self:_tile(holder, Vector2.new(250, 96), false)
	ShopJuicer.Rays(button, { Color = Color3.fromRGB(255, 200, 120), Size = 1.25, Speed = 30 })
	ShopJuicer.NeonBorder(button, { Style = "Gold", Thickness = 3 })
	Juice.Float(button, 4, 1.6)
	self.Banner = holder
	-- periodic attention wiggle
	task.spawn(function()
		while holder.Parent do
			task.wait(7)
			if holder.Visible then
				Juice.Punch(button, 0.1)
				ShopJuicer.Burst(button, 6)
			end
		end
	end)
end

-- Store panel hook: a wide promo tile on top of the Store grid (wrapped so rays are not laid out)
function Promo:BuildStoreTile(parent: Instance, order: number)
	local cell = UI.Create("Frame", {
		Name = "PromoCell",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = parent,
	})
	local button = self:_tile(cell, Vector2.new(196, 96), true)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.new(1, -8, 0.62, 0)
	ShopJuicer.Rays(button, { Color = Color3.fromRGB(255, 200, 120), Size = 1.1, Speed = 30 })
	ShopJuicer.NeonBorder(button, { Style = "Rainbow", Thickness = 3 })
	ShopJuicer.ValueTag(button, "INFINITE STACKING!")
	return cell
end

function Promo:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

function Promo:Start()
	self:_buildBanner()
	player:GetAttributeChangedSignal("HoneyTier"):Connect(function()
		for i = #tiles, 1, -1 do
			local entry = tiles[i]
			if entry.Root.Parent then
				self:_paint(entry)
				Juice.Punch(entry.Root, 0.2)
				ShopJuicer.Burst(entry.Root, 16, Color3.fromRGB(255, 230, 120))
			else
				table.remove(tiles, i)
			end
		end
		if C.Sound then
			C.Sound:Play("Purchase")
		end
	end)
	-- hide the banner while a panel or cutscene owns the screen
	task.spawn(function()
		while true do
			task.wait(0.3)
			local hud = UI:_screen()
			self.Banner.Visible = hud.Enabled and UI.Current == nil
			local camera = workspace.CurrentCamera
			local scale = math.clamp(math.min(camera.ViewportSize.Y / 760, camera.ViewportSize.X / 1200), 0.55, 1)
			self.Banner.Responsive.Scale = scale
		end
	end)
end

return Promo
