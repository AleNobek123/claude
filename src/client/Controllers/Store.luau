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

local function entry(order: number, key: string, def, owned: boolean, onBuy)
	local frame = UI.Glass({ LayoutOrder = order, Transparency = 0.2, Radius = 20, Parent = list })
	UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(110, 110), ImageColor3 = UI.Colors.HoneyLight, ImageTransparency = 0.4, Parent = frame })
	local icon = UI.Icon(ICONS[key] or "Gift", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.fromOffset(72, 72), Parent = frame })
	Juice.Float(icon, 2.5, 2 + order * 0.1)
	UI.Label({ Text = def.Name, Position = UDim2.fromOffset(10, 98), Size = UDim2.new(1, -20, 0, 24), MaxTextSize = 19, Parent = frame })
	UI.Label({ Text = def.Description, Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(12, 124), Size = UDim2.new(1, -24, 0, 34), MaxTextSize = 12, Parent = frame })
	UI.Button({
		Text = owned and "" or `{def.Robux} R$`,
		Icon = owned and "Check" or nil,
		BackgroundColor3 = UI.Colors.Good,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 42),
		Parent = frame,
	}, function()
		if not owned then
			onBuy()
		end
	end)
	Juice.Pop(frame, order * 0.03)
end

function Store:_render()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local n = 0
	for _, name in Config.GamepassOrder do
		n += 1
		entry(n, name, Config.Gamepasses[name], player:GetAttribute("Pass_" .. name) == true, function()
			Net.Event("RequestPurchase"):FireServer("Pass", name)
		end)
	end
	for _, name in Config.ProductOrder do
		local def = Config.Products[name]
		if not (def.RandomItem and player:GetAttribute("PaidRandomRestricted")) then
			n += 1
			entry(n, name, def, false, function()
				Net.Event("RequestPurchase"):FireServer("Product", name)
			end)
		end
	end
end

function Store:Start()
	local content, panel = UI:Panel("Store", "Store", "Gift")
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
