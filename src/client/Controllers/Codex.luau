--[[
	Codex (Bee Album)
	Every bee as a 3D card. Undiscovered bees show as dark silhouettes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local Viewport = require(script.Parent.Viewport)

local Codex = {}

local C
local UI
local Juice
local list: ScrollingFrame
local built = {} -- [beeId] = { Card, Known }

function Codex:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

function Codex:_render()
	local data = C.State.Data
	if not data then
		return
	end
	local found, total = 0, 0
	for index, beeId in BeeData.Order do
		total += 1
		local def = BeeData.Bees[beeId]
		local known = data.Codex[beeId] == true
		if known then
			found += 1
		end
		local entry = built[beeId]
		if not entry or entry.Known ~= known then
			if entry then
				entry.Card:Destroy()
			end
			local rarity = Config.Rarities[def.Rarity]
			local card = UI.Glass({ LayoutOrder = index, Transparency = 0.2, Radius = 18, Parent = list })
			UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(120, 120), ImageColor3 = rarity.Color, ImageTransparency = known and 0.35 or 0.8, Parent = card })
			local preview = UI.Create("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1, Parent = card })
			local model = C.BeeRenderer.Build(beeId, nil)
			if model then
				if not known then
					Viewport.Silhouette(model)
				end
				Viewport.Model(preview, model, { Mode = known and "float" or nil, Zoom = 0.9 })
			end
			UI.Create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = rarity.Color, Parent = card }, { UI.Round() })
			UI.Label({ Text = known and def.Name or "???", Position = UDim2.fromOffset(8, 140), Size = UDim2.new(1, -16, 0, 24), MaxTextSize = 18, TextColor3 = known and UI.Colors.Text or UI.Colors.Muted, Parent = card })
			if known then
				UI.Label({ Text = def.Description, Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(10, 166), Size = UDim2.new(1, -20, 0, 30), MaxTextSize = 11, Parent = card })
			end
			built[beeId] = { Card = card, Known = known }
		end
	end
	C.UI.Panels.Codex.Title.Text = `Bee Album  {found}/{total}`
end

function Codex:Start()
	local content, panel = UI:Panel("Codex", "Bee Album", "Book")
	list = UI.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UI.Create("UIGridLayout", { CellSize = UDim2.fromOffset(160, 204), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.Padding(8),
	})
	panel.OnOpen = function()
		self:_render()
		for _, entry in built do
			Juice.Pop(entry.Card, math.random() * 0.15)
		end
	end
	C.State:OnChange({ "Codex" }, function()
		if UI.Current == "Codex" then
			self:_render()
		end
	end)
end

return Codex
