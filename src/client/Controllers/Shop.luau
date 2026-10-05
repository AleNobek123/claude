--[[
	Shop
	Honey shop: collectors, backpacks and treats. Opened from the HUD or the shop stands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Shop = {}

local C
local UI
local tab = "Collector"
local list: ScrollingFrame
local tabButtons = {}

local TABS = {
	{ Id = "Collector", Label = "Collectors" },
	{ Id = "Backpack", Label = "Backpacks" },
	{ Id = "Treats", Label = "Treats" },
}

function Shop:Init(controllers)
	C = controllers
	UI = C.UI
end

local function card(order: number, title: string, lines: { string }, color: Color3)
	local frame = UI.Create("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = UI.Colors.CreamDark,
		Parent = list,
	}, { UI.Corner(14), UI.Stroke(UI.Colors.Brown, 2) })
	UI.Create("Frame", {
		Size = UDim2.new(1, -16, 0, 10),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = color,
		Parent = frame,
	}, { UI.Corner(5) })
	UI.Label({
		Text = title,
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 30),
		MaxTextSize = 24,
		Parent = frame,
	})
	for i, line in lines do
		UI.Label({
			Text = line,
			Font = UI.Body,
			TextColor3 = UI.Colors.Muted,
			Position = UDim2.fromOffset(10, 52 + (i - 1) * 22),
			Size = UDim2.new(1, -20, 0, 20),
			MaxTextSize = 15,
			Parent = frame,
		})
	end
	return frame
end

function Shop:_render()
	local data = C.State.Data
	if not data or not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for id, button in tabButtons do
		button.BackgroundColor3 = id == tab and UI.Colors.Honey or UI.Colors.CreamDark
	end

	if tab == "Treats" then
		for i, count in { 1, 10, 100 } do
			local frame = card(i, `{count} Treat{count > 1 and "s" or ""}`, {
				`+{Config.Levels.TreatXP * count} bee XP`,
				`You have {data.Treats}`,
			}, Color3.fromRGB(255, 160, 200))
			UI.Button({
				Text = Format.Short(Config.Levels.TreatPrice * count) .. " honey",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 40),
				Parent = frame,
			}, function()
				Net.Event("BuyTreats"):FireServer(count)
			end)
		end
		return
	end

	local isCollector = tab == "Collector"
	local items = isCollector and Config.Collectors or Config.Backpacks
	local owned = isCollector and data.OwnedCollectors or data.OwnedBackpacks
	local equipped = isCollector and data.Collector or data.Backpack
	for i, item in items do
		local lines = isCollector
				and { `Power {item.Power} per flower`, `Radius {item.Radius} • {item.Cooldown}s` }
			or { `Holds {Format.Commas(item.Capacity)} pollen` }
		local frame = card(i, item.Name, lines, item.Color)
		local text, color, enabled
		if equipped == item.Id then
			text, color, enabled = "Equipped", UI.Colors.Good, false
		elseif owned[item.Id] then
			text, color, enabled = "Equip", UI.Colors.Blue, true
		else
			local previous = items[i - 1]
			local unlocked = not previous or owned[previous.Id]
			local affordable = data.Honey >= item.Price
			text = unlocked and (Format.Short(item.Price) .. " honey") or "Locked"
			color = (unlocked and affordable) and UI.Colors.Honey or UI.Colors.CreamDark
			enabled = unlocked
		end
		UI.Button({
			Text = text,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 40),
			BackgroundColor3 = color,
			TextColor3 = (color == UI.Colors.Good or color == UI.Colors.Blue) and UI.Colors.White or UI.Colors.Brown,
			Parent = frame,
		}, function()
			if not enabled then
				return
			end
			if owned[item.Id] then
				Net.Event("Equip"):FireServer(tab, item.Id)
			else
				Net.Event("Buy"):FireServer(tab, item.Id)
			end
		end)
	end
end

function Shop:Start()
	local content, panel = UI:Panel("Shop", "Honey Shop")
	local tabs = UI.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UI.List(8, true) })
	for i, info in TABS do
		tabButtons[info.Id] = UI.Button({
			Text = info.Label,
			LayoutOrder = i,
			Size = UDim2.fromOffset(150, 40),
			Parent = tabs,
		}, function()
			tab = info.Id
			self:_render()
		end)
	end
	list = UI.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Colors.Brown,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UI.Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(210, 170),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.Padding(6),
	})
	panel.OnOpen = function(openTab)
		if openTab then
			tab = openTab
		end
		self:_render()
	end
	C.State:OnChange({ "Honey", "OwnedCollectors", "OwnedBackpacks", "Collector", "Backpack", "Treats" }, function()
		if UI.Current == "Shop" then
			self:_render()
		end
	end)
end

return Shop
