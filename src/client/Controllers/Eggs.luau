--[[
	Eggs
	Egg shop with the full odds table and pity counter shown before any purchase
	(Roblox policy for random items). Royal Egg can also be bought with Robux where
	paid random items are allowed.
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
local row: Frame

function Eggs:Init(controllers)
	C = controllers
	UI = C.UI
end

local function price(eggId: string, data): number
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
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, eggId in Config.EggOrder do
		local egg = Config.Eggs[eggId]
		local card = UI.Create("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1 / 3, -10, 1, 0),
			BackgroundColor3 = UI.Colors.CreamDark,
			Parent = row,
		}, { UI.Corner(16), UI.Stroke(UI.Colors.Brown, 2) })
		local eggShape = UI.Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(56, 70),
			BackgroundColor3 = egg.Color,
			Parent = card,
		}, { UI.Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.Stroke(UI.Colors.Brown, 2) })
		eggShape.Name = "Egg"
		UI.Label({ Text = egg.Name, Position = UDim2.fromOffset(8, 84), Size = UDim2.new(1, -16, 0, 28), MaxTextSize = 24, Parent = card })
		local y = 114
		for _, rarity in Config.RarityOrder do
			local chance = egg.Odds[rarity]
			UI.Label({
				Text = `{rarity}: {Format.Percent(chance)}`,
				Font = UI.Body,
				TextColor3 = chance > 0 and Config.Rarities[rarity].Color:Lerp(Color3.new(0, 0, 0), 0.35) or UI.Colors.Muted,
				Position = UDim2.fromOffset(12, y),
				Size = UDim2.new(1, -24, 0, 18),
				MaxTextSize = 15,
				Parent = card,
			})
			y += 19
		end
		local pity = data.Pity[eggId] or 0
		UI.Label({
			Text = `Legendary+ guaranteed in {egg.Pity - pity} hatches`,
			Font = UI.Body,
			TextColor3 = UI.Colors.HoneyDark,
			Position = UDim2.fromOffset(10, y + 4),
			Size = UDim2.new(1, -20, 0, 34),
			MaxTextSize = 14,
			Parent = card,
		})
		UI.Label({
			Text = `Owned: {data.Eggs[eggId] or 0}`,
			Position = UDim2.fromOffset(10, y + 38),
			Size = UDim2.new(1, -20, 0, 22),
			MaxTextSize = 18,
			Parent = card,
		})
		local cost = price(eggId, data)
		UI.Button({
			Text = `Buy • {Format.Short(cost)} honey`,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -54),
			Size = UDim2.new(1, -20, 0, 38),
			BackgroundColor3 = data.Honey >= cost and UI.Colors.Honey or UI.Colors.CreamDark,
			Parent = card,
		}, function()
			Net.Event("BuyEgg"):FireServer(eggId)
		end)
		local product = egg.Product and Config.Products[egg.Product]
		if product and not player:GetAttribute("PaidRandomRestricted") and (data.Eggs[eggId] or 0) == 0 then
			UI.Button({
				Text = `Buy • {product.Robux} R$`,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 38),
				BackgroundColor3 = Color3.fromRGB(110, 230, 140),
				Parent = card,
			}, function()
				Net.Event("RequestPurchase"):FireServer("Product", egg.Product)
			end)
		else
			UI.Button({
				Text = (data.Eggs[eggId] or 0) > 0 and "Hatch" or "No eggs",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 38),
				BackgroundColor3 = (data.Eggs[eggId] or 0) > 0 and UI.Colors.Good or UI.Colors.CreamDark,
				TextColor3 = UI.Colors.White,
				Parent = card,
			}, function()
				if (data.Eggs[eggId] or 0) > 0 then
					C.Hive:StartHatch(eggId)
				end
			end)
		end
	end
end

function Eggs:Start()
	local content, panel = UI:Panel("Eggs", "Egg Shop")
	UI.Label({
		Text = "Odds per hatch. Every bee within a rarity is equally likely.",
		Font = UI.Body,
		TextColor3 = UI.Colors.Muted,
		Size = UDim2.new(1, 0, 0, 22),
		MaxTextSize = 15,
		Parent = content,
	})
	row = UI.Create("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UI.List(14, true) })
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
