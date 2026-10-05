--[[
	Store
	Robux products and gamepasses. Purchases are always validated and granted server-side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Store = {}

local C
local UI
local list: ScrollingFrame

function Store:Init(controllers)
	C = controllers
	UI = C.UI
end

local function entry(order: number, def, owned: boolean, onBuy)
	local frame = UI.Create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 64),
		BackgroundColor3 = UI.Colors.CreamDark,
		Parent = list,
	}, { UI.Corner(12), UI.Stroke(UI.Colors.Brown, 2) })
	UI.Label({ Text = def.Name, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -180, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = frame })
	UI.Label({ Text = def.Description, Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -180, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = frame })
	UI.Button({
		Text = owned and "Owned" or `{def.Robux} R$`,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = owned and UI.Colors.Good or Color3.fromRGB(110, 230, 140),
		Parent = frame,
	}, function()
		if not owned then
			onBuy()
		end
	end)
end

function Store:_render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	UI.Label({ Text = "Gamepasses", LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = list })
	for i, name in Config.GamepassOrder do
		local def = Config.Gamepasses[name]
		entry(i, def, player:GetAttribute("Pass_" .. name) == true, function()
			Net.Event("RequestPurchase"):FireServer("Pass", name)
		end)
	end
	UI.Label({ Text = "Boosts & items", LayoutOrder = 10, Size = UDim2.new(1, -12, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = list })
	for i, name in Config.ProductOrder do
		local def = Config.Products[name]
		if not (def.RandomItem and player:GetAttribute("PaidRandomRestricted")) then
			entry(10 + i, def, false, function()
				Net.Event("RequestPurchase"):FireServer("Product", name)
			end)
		end
	end
	if Config.StudioFreePurchases and game:GetService("RunService"):IsStudio() then
		UI.Label({ Text = "Studio test mode: products without an ID are granted for free.", Font = UI.Body, TextColor3 = UI.Colors.Muted, LayoutOrder = 99, Size = UDim2.new(1, -12, 0, 24), MaxTextSize = 14, Parent = list })
	end
end

function Store:Start()
	local content, panel = UI:Panel("Store", "Robux Store")
	list = UI.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UI.List(8) })
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
