--[[
	Eggs
	Odds, pity and owned eggs (eggs are bought and hatched at the physical Golden Nests).
	Odds are always visible before any purchase (Roblox policy for random items).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Eggs = {}

local C
local UI
local Juice
local row: Frame

function Eggs:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

local function price(eggId: string): number
	local egg = Config.Eggs[eggId]
	if egg.BasePrice then
		return math.floor(egg.BasePrice * egg.Growth ^ C.State:BeeCount())
	end
	return egg.HoneyPrice
end

function Eggs:_render()
	local data = C.State.Data
	if not data or not row then
		return
	end
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, eggId in Config.EggOrder do
		local egg = Config.Eggs[eggId]
		local card = UI.Glass({ LayoutOrder = i, Size = UDim2.new(1 / 3, -12, 1, 0), Transparency = 0.2, Radius = 22, Parent = row })
		Juice.Pop(card, i * 0.05)
		UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(130, 130), ImageColor3 = egg.Color, ImageTransparency = 0.3, Parent = card })
		local icon = UI.Icon("Egg", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(86, 86), ImageColor3 = egg.Color:Lerp(Color3.new(1, 1, 1), 0.25), Parent = card })
		Juice.Float(icon, 3, 1.8 + i * 0.3)
		UI.Label({ Text = egg.Name, Position = UDim2.fromOffset(10, 108), Size = UDim2.new(1, -20, 0, 28), MaxTextSize = 22, Parent = card })
		local y = 142
		for _, rarity in Config.RarityOrder do
			local chance = egg.Odds[rarity]
			local line = UI.Create("Frame", { Position = UDim2.new(0, 18, 0, y), Size = UDim2.new(1, -36, 0, 20), BackgroundTransparency = 1, Parent = card })
			UI.Create("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Config.Rarities[rarity].Color, BackgroundTransparency = chance > 0 and 0 or 0.7, Parent = line }, { UI.Round() })
			UI.Label({ Text = rarity, Font = UI.Body, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0.6, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = chance > 0 and UI.Colors.Text or UI.Colors.Muted, MaxTextSize = 14, Parent = line })
			UI.Label({ Text = Format.Percent(chance), Font = UI.Body, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = chance > 0 and UI.Colors.Text or UI.Colors.Muted, MaxTextSize = 14, Parent = line })
			y += 21
		end
		local pity = data.Pity[eggId] or 0
		local _, fill, text = UI.Bar({ Position = UDim2.new(0, 18, 0, y + 6), Size = UDim2.new(1, -36, 0, 20), Color = Config.Rarities.Legendary.Color, MaxTextSize = 12, Parent = card })
		fill.Size = UDim2.fromScale(math.clamp(pity / egg.Pity, 0.04, 1), 1)
		text.Text = `Legendary in {egg.Pity - pity}`
		local owned = data.Eggs[eggId] or 0
		local ownedRow = UI.Create("Frame", { Position = UDim2.new(0, 18, 0, y + 32), Size = UDim2.new(1, -36, 0, 26), BackgroundTransparency = 1, Parent = card })
		UI.Icon("Egg", { Size = UDim2.fromOffset(24, 24), Parent = ownedRow })
		UI.Label({ Text = `x{owned}   •   {Format.Short(price(eggId))}`, Font = UI.Body, Position = UDim2.fromOffset(30, 2), Size = UDim2.new(1, -30, 1, -4), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = ownedRow })

		if owned > 0 then
			UI.Button({ Text = "HATCH", Icon = "Egg", BackgroundColor3 = UI.Colors.Good, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -28, 0, 44), Parent = card }, function()
				C.Hive:StartHatch(eggId)
			end)
		else
			local product = egg.Product and Config.Products[egg.Product]
			if product and not player:GetAttribute("PaidRandomRestricted") then
				UI.Button({ Text = `{product.Robux} R$`, Icon = "Gift", BackgroundColor3 = UI.Colors.Good, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.new(1, -28, 0, 44), Parent = card }, function()
					Net.Event("RequestPurchase"):FireServer("Product", egg.Product)
				end)
			end
			UI.Button({ Text = "FIND NEST", Icon = "Home", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -28, 0, 44), Parent = card }, function()
				UI:Close()
				if C.Tutorial then
					C.Tutorial:Guide("Nest", i)
				end
			end)
		end
	end
end

function Eggs:Start()
	local content, panel = UI:Panel("Eggs", "Eggs", "Egg")
	row = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content }, { UI.List(16, true) })
	row.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	panel.OnOpen = function()
		self:_render()
	end
	C.State:OnChange({ "Honey", "Eggs", "Pity", "Bees" }, function()
		if UI.Current == "Eggs" then
			self:_render()
		end
	end)
end

return Eggs
