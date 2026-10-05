--[[
	Shop
	Collectors, backpacks and treats as glass cards with live 3D previews.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Viewport = require(script.Parent.Viewport)

local Shop = {}

local C
local UI
local Juice
local tab = "Collector"
local list: ScrollingFrame
local tabButtons = {}

local TABS = {
	{ Id = "Collector", Icon = "Pollen", Label = "Tools" },
	{ Id = "Backpack", Icon = "Backpack", Label = "Bags" },
	{ Id = "Treats", Icon = "Treat", Label = "Treats" },
}

function Shop:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

local function tinted(model: Model, color: Color3)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Tint") then
			part.Color = color
		end
	end
	return model
end

local function card(order: number, title: string)
	local frame = UI.Glass({ LayoutOrder = order, Transparency = 0.2, Radius = 20, Parent = list })
	local preview = UI.Create("Frame", { Name = "Preview", Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, Parent = frame })
	UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(120, 120), ImageColor3 = UI.Colors.HoneyLight, ImageTransparency = 0.45, Parent = preview })
	UI.Label({ Text = title, Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 26), MaxTextSize = 21, Parent = frame })
	Juice.Pop(frame, order * 0.03)
	return frame, preview
end

local function statLine(frame: Instance, y: number, iconName: string, text: string)
	UI.Icon(iconName, { Position = UDim2.new(0.5, -70, 0, y), Size = UDim2.fromOffset(22, 22), Parent = frame })
	UI.Label({ Text = text, Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.new(0.5, -44, 0, y + 1), Size = UDim2.fromOffset(120, 20), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = frame })
end

function Shop:_render()
	local data = C.State.Data
	if not data or not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for id, button in tabButtons do
		UI.SetButtonColor(button, id == tab and UI.Colors.Honey or Color3.fromRGB(215, 195, 165))
	end

	if tab == "Treats" then
		for i, count in { 1, 10, 100 } do
			local frame, preview = card(i, `x{count}`)
			UI.Icon("Treat", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(80, 80), Parent = preview })
			statLine(frame, 140, "Star", `+{Config.Levels.TreatXP * count} XP`)
			UI.Button({ Text = Format.Short(Config.Levels.TreatPrice * count), Icon = "Honey", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 44), Parent = frame }, function()
				Net.Event("BuyTreats"):FireServer(count)
				C.Sound:Play("Purchase")
			end)
		end
		return
	end

	local isCollector = tab == "Collector"
	local items = isCollector and Config.Collectors or Config.Backpacks
	local owned = isCollector and data.OwnedCollectors or data.OwnedBackpacks
	local equipped = isCollector and data.Collector or data.Backpack
	for i, item in items do
		local frame, preview = card(i, item.Name)
		local model = Viewport.Clone(isCollector and "Collectors" or "Backpacks", item.Shape)
		if model then
			Viewport.Model(preview, tinted(model, item.Color), { Mode = "spin", Zoom = 0.95, Pitch = 18 })
		end
		if isCollector then
			statLine(frame, 140, "Pollen", `{item.Power}  •  r{item.Radius}`)
		else
			statLine(frame, 140, "Backpack", Format.Short(item.Capacity))
		end
		local button
		if equipped == item.Id then
			button = UI.Button({ Text = "", Icon = "Check", BackgroundColor3 = UI.Colors.Good, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 44), Parent = frame })
		elseif owned[item.Id] then
			button = UI.Button({ Text = "EQUIP", BackgroundColor3 = UI.Colors.Blue, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 44), Parent = frame }, function()
				Net.Event("Equip"):FireServer(tab, item.Id)
			end)
		else
			local previous = items[i - 1]
			local unlocked = not previous or owned[previous.Id]
			local affordable = data.Honey >= item.Price
			button = UI.Button({
				Text = unlocked and Format.Short(item.Price) or "",
				Icon = unlocked and "Honey" or "Lock",
				BackgroundColor3 = (unlocked and affordable) and UI.Colors.Honey or Color3.fromRGB(200, 180, 150),
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -24, 0, 44),
				Parent = frame,
			}, function()
				if unlocked and affordable then
					Net.Event("Buy"):FireServer(tab, item.Id)
					C.Sound:Play("Purchase")
				end
			end)
			if not (unlocked and affordable) then
				button.Activated:Connect(function()
					Juice.Shake(frame, 5)
				end)
			end
		end
	end
end

function Shop:Start()
	local content, panel = UI:Panel("Shop", "Shop", "Shop")
	local tabs = UI.Create("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = content }, { UI.List(10, true) })
	for i, info in TABS do
		tabButtons[info.Id] = UI.Button({ Text = info.Label, Icon = info.Icon, LayoutOrder = i, Size = UDim2.fromOffset(150, 44), Parent = tabs }, function()
			tab = info.Id
			self:_render()
		end)
	end
	list = UI.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UI.Create("UIGridLayout", { CellSize = UDim2.fromOffset(200, 230), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.Padding(8),
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
