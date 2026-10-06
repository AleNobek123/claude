--[[
	Store
	Robux products and gamepasses as icon cards. Purchases are validated and granted server-side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ShopJuicer = require(script.Parent.ShopJuicer)

local player = Players.LocalPlayer

local Store = {}

local C
local UI
local Juice
local list: ScrollingFrame

local ICONS = {
	ExtraSlots = "Honeycomb",
	VIPField = "Star",
	AutoConvert = "Bee",
	InstantConvert = "Honey",
	FieldBooster = "Lightning",
	HoneyPackS = "Honey",
	HoneyPackL = "Honey",
	RoyalEgg = "Egg",
	MutationSerum = "Serum",
}

function Store:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

-- saturated gradient per item family; passes get a gold neon border, products a rainbow one
local FAMILY = {
	Pass = { Top = Color3.fromRGB(190, 120, 255), Bottom = Color3.fromRGB(110, 50, 210), Border = "Gold" },
	Product = { Top = Color3.fromRGB(255, 200, 80), Bottom = Color3.fromRGB(255, 120, 40), Border = "Rainbow" },
}

local function entry(order: number, key: string, def, owned: boolean, onBuy, family: string)
	local style = FAMILY[family] or FAMILY.Product
	local frame = UI.Create("Frame", { LayoutOrder = order, BackgroundColor3 = Color3.new(1, 1, 1), Parent = list }, { UI.Corner(20), UI.Gradient(style.Top, style.Bottom) })
	UI.Create("Frame", { Name = "Gloss", Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -16, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, BorderSizePixel = 0, Parent = frame }, { UI.Corner(16) })
	if not owned then
		ShopJuicer.NeonBorder(frame, { Style = style.Border, Thickness = 3 })
		if def.Tag then
			ShopJuicer.ValueTag(frame, def.Tag)
		end
	end
	UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(120, 120), ImageColor3 = Color3.fromRGB(255, 250, 220), ImageTransparency = 0.25, Parent = frame })
	local icon = UI.Icon(ICONS[key] or "Gift", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.fromOffset(72, 72), Parent = frame })
	Juice.Float(icon, 2.5, 2 + order * 0.1)
	local title = UI.Label({ Text = def.Name, Position = UDim2.fromOffset(10, 98), Size = UDim2.new(1, -20, 0, 24), MaxTextSize = 19, TextColor3 = Color3.new(1, 1, 1), Parent = frame })
	UI.Create("UIStroke", { Color = style.Bottom:Lerp(Color3.new(0, 0, 0), 0.5), Thickness = 2, Parent = title })
	UI.Label({ Text = def.Description, Font = UI.Body, TextColor3 = Color3.fromRGB(255, 248, 235), Position = UDim2.fromOffset(12, 124), Size = UDim2.new(1, -24, 0, 34), MaxTextSize = 12, Parent = frame })
	local buy = UI.Button({
		Text = owned and "" or `{def.Robux} R$`,
		Icon = owned and "Check" or nil,
		BackgroundColor3 = UI.Colors.Good,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 42),
		Parent = frame,
	}, function()
		if not owned then
			ShopJuicer.Burst(frame, 8)
			onBuy()
		end
	end)
	if not owned then
		-- Robux buttons get the looping light sweep
		ShopJuicer.Shine(buy, { Period = 0.8, Pause = 2 + order * 0.15 })
	end
	Juice.Pop(frame, order * 0.03)
end

function Store:_render()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local n = 1
	C.Promo:BuildStoreTile(list, n)
	for _, name in Config.GamepassOrder do
		n += 1
		entry(n, name, Config.Gamepasses[name], player:GetAttribute("Pass_" .. name) == true, function()
			Net.Event("RequestPurchase"):FireServer("Pass", name)
		end, "Pass")
	end
	for _, name in Config.ProductOrder do
		local def = Config.Products[name]
		if not (def.RandomItem and player:GetAttribute("PaidRandomRestricted")) then
			n += 1
			entry(n, name, def, false, function()
				Net.Event("RequestPurchase"):FireServer("Product", name)
			end, "Product")
		end
	end
end

function Store:Start()
	local content, panel = UI:Panel("Store", "Store", "Star")
	list = UI.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UI.Create("UIGridLayout", { CellSize = UDim2.fromOffset(200, 220), CellPadding = UDim2.fromOffset(16, 16), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.Padding(8),
	})
	if Config.StudioFreePurchases and RunService:IsStudio() then
		panel.Title.Text = "Store  (Studio: free test purchases)"
	end
	panel.OnOpen = function()
		self:_render()
	end
	for name in Config.Gamepasses do
		player:GetAttributeChangedSignal("Pass_" .. name):Connect(function()
			if UI.Current == "Store" then
				self:_render()
			end
		end)
	end
end

return Store
