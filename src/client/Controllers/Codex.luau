--[[
	Codex
	Every bee in the game, grouped by rarity. Undiscovered bees stay hidden as "???".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)

local Codex = {}

local C
local UI
local list: ScrollingFrame

function Codex:Init(controllers)
	C = controllers
	UI = C.UI
end

function Codex:_render()
	local data = C.State.Data
	if not data then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local found, total = 0, 0
	local order = 0
	for _, rarity in Config.RarityOrder do
		local ids = BeeData.ByRarity[rarity] or {}
		order += 1
		UI.Label({
			Text = `{rarity}  (each 1 in {#ids} within its rarity)`,
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Config.Rarities[rarity].Color:Lerp(Color3.new(0, 0, 0), 0.3),
			MaxTextSize = 22,
			Parent = list,
		})
		order += 1
		local row = UI.Create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 92),
			BackgroundTransparency = 1,
			Parent = list,
		}, { UI.List(8, true) })
		for i, id in ids do
			total += 1
			local def = BeeData.Bees[id]
			local known = data.Codex[id] == true
			if known then
				found += 1
			end
			local card = UI.Create("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromOffset(150, 88),
				BackgroundColor3 = known and Config.Rarities[rarity].Color or Color3.fromRGB(90, 70, 50),
				Parent = row,
			}, { UI.Corner(12), UI.Stroke(UI.Colors.Brown, 2), UI.Padding(6) })
			UI.Label({ Text = known and def.Name or "???", Size = UDim2.new(1, 0, 0, 26), MaxTextSize = 20, TextColor3 = known and UI.Colors.Brown or UI.Colors.Cream, Parent = card })
			UI.Label({
				Text = known and def.Description or "Hatch eggs to discover.",
				Font = UI.Body,
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, 0, 1, -28),
				TextColor3 = known and UI.Colors.Text or UI.Colors.CreamDark,
				MaxTextSize = 12,
				Parent = card,
			})
		end
	end
	C.UI.Panels.Codex.Title.Text = `Bee Codex  {found}/{total}`
end

function Codex:Start()
	local content, panel = UI:Panel("Codex", "Bee Codex")
	list = UI.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UI.List(6) })
	panel.OnOpen = function()
		self:_render()
	end
	C.State:OnChange({ "Codex" }, function()
		if UI.Current == "Codex" then
			self:_render()
		end
	end)
end

return Codex
