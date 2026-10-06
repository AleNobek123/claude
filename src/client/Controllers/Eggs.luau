--[[
	Eggs
	Egg codex: pick an egg on the left (odds, pity, owned, hatch / find nest / Robux), browse every
	bee it can hatch on the right as live 3D previews with rarity tags and exact per-bee chances,
	and open any bee for its description, combat stats and ability.
	Odds are always visible before any purchase (Roblox policy for random items).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BeeData = require(Shared.BeeData)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Viewport = require(script.Parent.Viewport)

local player = Players.LocalPlayer

local Eggs = {}

local C
local UI
local Juice
local selected = "Basic"
local left: Frame
local grid: ScrollingFrame
local detail: Frame

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

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function rarityPill(parent: Instance, rarity: string, props)
	local color = Config.Rarities[rarity].Color
	local pill = UI.Create("Frame", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color,
		Parent = parent,
	}, { UI.Round(), UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	for key, value in props or {} do
		pill[key] = value
	end
	UI.Create("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Text = rarity:upper(),
		Parent = pill,
	}, { UI.Create("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.5), Thickness = 1.5 }) })
	return pill
end

-- Left column: egg picker + odds + actions --------------------------------------------------------

function Eggs:_renderLeft(data)
	clear(left)
	local picker = UI.Create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1, Parent = left }, { UI.List(8, true, Enum.HorizontalAlignment.Center) })
	for i, eggId in Config.EggOrder do
		local egg = Config.Eggs[eggId]
		local isSelected = eggId == selected
		local button = UI.Create("ImageButton", {
			LayoutOrder = i,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(isSelected and 84 or 74, isSelected and 84 or 74),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Image = "",
			Parent = picker,
		}, { UI.Corner(18), UI.Gradient(egg.Color:Lerp(Color3.new(1, 1, 1), isSelected and 0.2 or 0.6), egg.Color:Lerp(Color3.new(0, 0, 0), isSelected and 0.05 or 0.25)) })
		if isSelected then
			UI.Create("UIStroke", { Color = Color3.fromRGB(255, 240, 150), Thickness = 3, Parent = button })
		end
		UI.Icon("Egg", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.62, 0.62), ImageColor3 = egg.Color:Lerp(Color3.new(1, 1, 1), 0.3), Parent = button })
		local owned = data.Eggs[eggId] or 0
		if owned > 0 then
			UI.Create("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(40, 20), BackgroundTransparency = 1, Font = UI.Font, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.new(1, 1, 1), Text = "x" .. owned, Parent = button }, { UI.Create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(80, 50, 10) }) })
		end
		Juice.Bind(button, { Hover = 1.08 })
		button.Activated:Connect(function()
			if selected ~= eggId then
				selected = eggId
				self:_render()
			end
		end)
	end

	local egg = Config.Eggs[selected]
	UI.Label({ LayoutOrder = 2, Text = egg.Name, Size = UDim2.new(1, 0, 0, 30), MaxTextSize = 26, Parent = left })
	-- odds per rarity
	local odds = UI.Glass({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 5 * 22 + 12), Transparency = 0.25, Radius = 14, Parent = left })
	for r, rarity in Config.RarityOrder do
		local chance = egg.Odds[rarity]
		local line = UI.Create("Frame", { Position = UDim2.new(0, 12, 0, 6 + (r - 1) * 22), Size = UDim2.new(1, -24, 0, 20), BackgroundTransparency = 1, Parent = odds })
		UI.Create("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Config.Rarities[rarity].Color, BackgroundTransparency = chance > 0 and 0 or 0.7, Parent = line }, { UI.Round() })
		UI.Label({ Text = rarity, Font = UI.Body, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0.6, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = chance > 0 and UI.Colors.Text or UI.Colors.Muted, MaxTextSize = 14, Parent = line })
		UI.Label({ Text = Format.Percent(chance), Font = UI.Body, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = chance > 0 and UI.Colors.Text or UI.Colors.Muted, MaxTextSize = 14, Parent = line })
	end
	local pity = data.Pity[selected] or 0
	local bar, fill, text = UI.Bar({ Size = UDim2.new(1, 0, 0, 20), Color = Config.Rarities.Legendary.Color, MaxTextSize = 12, Parent = left })
	bar.LayoutOrder = 4
	fill.Size = UDim2.fromScale(math.clamp(pity / egg.Pity, 0.04, 1), 1)
	text.Text = `Guaranteed Legendary in {egg.Pity - pity}`
	local info = UI.Create("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = left })
	UI.Icon("Honey", { Size = UDim2.fromOffset(24, 24), Parent = info })
	UI.Label({ Text = `{Format.Short(price(selected))} at the Golden Nest`, Font = UI.Body, Position = UDim2.fromOffset(30, 2), Size = UDim2.new(1, -30, 1, -4), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = info })

	local owned = data.Eggs[selected] or 0
	local index = table.find(Config.EggOrder, selected) or 1
	if owned > 0 then
		UI.Button({ LayoutOrder = 6, Text = "HATCH", Icon = "Egg", BackgroundColor3 = UI.Colors.Good, Size = UDim2.new(1, 0, 0, 44), Parent = left }, function()
			C.Hive:StartHatch(selected)
		end)
	end
	local product = egg.Product and Config.Products[egg.Product]
	if product and not player:GetAttribute("PaidRandomRestricted") then
		UI.Button({ LayoutOrder = 7, Text = `{product.Robux} R$`, Icon = "Gift", BackgroundColor3 = Color3.fromRGB(60, 200, 110), Size = UDim2.new(1, 0, 0, 40), Parent = left }, function()
			if C.HatchCutscene and C.HatchCutscene:IsBusy() then
				C.NotificationCenter:Push("Wait for the hatch to finish!", "info")
				return
			end
			Net.Event("RequestPurchase"):FireServer("Product", egg.Product)
		end)
	end
	UI.Button({ LayoutOrder = 8, Text = "FIND NEST", Icon = "Home", Size = UDim2.new(1, 0, 0, 40), Parent = left }, function()
		UI:Close()
		if C.Tutorial then
			C.Tutorial:Guide("Nest", index)
		end
	end)
end

-- Right side: every bee this egg can hatch ------------------------------------------------------------

function Eggs:_beeCard(order: number, id: string, chance: number, discovered: boolean)
	local def = BeeData.Bees[id]
	local color = Config.Rarities[def.Rarity].Color
	local card = UI.Create("ImageButton", {
		LayoutOrder = order,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Image = "",
		Parent = grid,
	}, { UI.Corner(16), UI.Gradient(color:Lerp(Color3.new(1, 1, 1), 0.55), Color3.fromRGB(255, 250, 240)) })
	local preview = UI.Create("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundTransparency = 1, Parent = card })
	UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(90, 90), ImageColor3 = color, ImageTransparency = 0.4, Parent = preview })
	local model = C.BeeRenderer and C.BeeRenderer.Build(id, nil)
	if model then
		Viewport.Model(preview, model, { Mode = "spin", Zoom = 0.9 })
	end
	rarityPill(card, def.Rarity, { Position = UDim2.fromOffset(6, 6) })
	if not discovered then
		UI.Create("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(40, 18), BackgroundColor3 = Color3.fromRGB(255, 80, 80), Font = UI.Font, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Text = "NEW", Parent = card }, { UI.Round() })
	end
	UI.Label({ Text = def.Name, Position = UDim2.fromOffset(6, 88), Size = UDim2.new(1, -12, 0, 22), MaxTextSize = 17, Parent = card })
	UI.Label({ Text = Format.Percent(chance), Font = UI.Body, Position = UDim2.fromOffset(6, 110), Size = UDim2.new(1, -12, 0, 18), TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35), MaxTextSize = 15, Parent = card })
	Juice.Bind(card, { Hover = 1.05 })
	card.Activated:Connect(function()
		self:_showDetail(id, chance)
	end)
	Juice.Pop(card, order * 0.015)
end

function Eggs:_renderGrid(data)
	clear(grid)
	local egg = Config.Eggs[selected]
	local order = 0
	for _, rarity in Config.RarityOrder do
		local chance = egg.Odds[rarity]
		local ids = BeeData.ByRarity[rarity] or {}
		if chance > 0 and #ids > 0 then
			for _, id in ids do
				order += 1
				self:_beeCard(order, id, chance / #ids, data.Codex[id] == true)
			end
		end
	end
end

-- Bee detail overlay: big preview, description, combat stats, ability
function Eggs:_showDetail(id: string, chance: number)
	clear(detail)
	local def = BeeData.Bees[id]
	local color = Config.Rarities[def.Rarity].Color
	detail.Visible = true
	Juice.Open(detail)
	UI.IconButton("Close", 36, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), BackgroundColor3 = UI.Colors.Bad, ZIndex = 30, Parent = detail }, function()
		Juice.Close(detail)
	end)
	local preview = UI.Create("Frame", { Size = UDim2.new(0.42, 0, 1, 0), BackgroundTransparency = 1, Parent = detail })
	UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.8), ImageColor3 = color, ImageTransparency = 0.3, Parent = preview })
	local model = C.BeeRenderer and C.BeeRenderer.Build(id, nil)
	if model then
		Viewport.Model(preview, model, { Mode = "float", Zoom = 0.8 })
	end
	local info = UI.Create("Frame", { Position = UDim2.new(0.42, 0, 0, 14), Size = UDim2.new(0.58, -16, 1, -28), BackgroundTransparency = 1, Parent = detail }, { UI.List(6) })
	info.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	UI.Label({ LayoutOrder = 1, Text = def.Name, Size = UDim2.new(1, -40, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 30, Parent = info })
	local tags = UI.Create("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = info }, { UI.List(6, true) })
	rarityPill(tags, def.Rarity, { LayoutOrder = 1 })
	UI.Label({ LayoutOrder = 2, Text = `{Format.Percent(chance)} from this egg  •  {def.Color} flowers`, Font = UI.Body, Size = UDim2.fromOffset(260, 20), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, TextColor3 = UI.Colors.Muted, Parent = tags })
	UI.Label({ LayoutOrder = 3, Text = def.Description, Font = UI.Body, Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MaxTextSize = 15, Parent = info })
	local function stat(order: number, icon: string, text: string)
		local row = UI.Create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = info })
		UI.Icon(icon, { Size = UDim2.fromOffset(22, 22), Parent = row })
		UI.Label({ Text = text, Font = UI.Body, Position = UDim2.fromOffset(30, 2), Size = UDim2.new(1, -30, 1, -4), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = row })
	end
	stat(4, "Pollen", `{def.Gather} pollen every {def.GatherTime}s`)
	stat(5, "Honey", `{def.Convert} honey per hive trip`)
	stat(6, "Lightning", `{def.Speed} speed  •  {def.Attack} attack`)
	if def.Ability then
		stat(7, "Star", `Ability: {def.Ability.Name}  ({def.Ability.Cooldown}s)`)
	end
	if def.Passive then
		local parts = {}
		for key, value in def.Passive do
			table.insert(parts, `+{math.floor(value * 100 + 0.5)}% {key:gsub("(%l)(%u)", "%1 %2"):lower()}`)
		end
		stat(8, "Sparkles", "Passive: " .. table.concat(parts, ", "))
	end
end

local lastLeft, lastGrid = "", ""
local function signatures(data)
	local eggs, codex = {}, {}
	for id, count in data.Eggs or {} do
		table.insert(eggs, id .. count)
	end
	for id in data.Codex or {} do
		table.insert(codex, id)
	end
	table.sort(eggs)
	table.sort(codex)
	return table.concat(eggs, ",") .. "|" .. HttpService:JSONEncode(data.Pity or {}), selected .. "|" .. table.concat(codex, ",")
end

function Eggs:_render()
	local data = C.State.Data
	if not data or not left then
		return
	end
	self:_renderLeft(data)
	self:_renderGrid(data)
	lastLeft, lastGrid = signatures(data)
end

function Eggs:Start()
	local content, panel = UI:Panel("Eggs", "Eggs & Bees", "Egg")
	left = UI.Create("Frame", { Size = UDim2.new(0, 270, 1, 0), BackgroundTransparency = 1, Parent = content }, { UI.List(8) })
	left.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	left.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid = UI.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(286, 0),
		Size = UDim2.new(1, -286, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UI.Create("UIGridLayout", { CellSize = UDim2.fromOffset(132, 136), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.Padding(6),
	})
	detail = UI.Create("CanvasGroup", {
		Name = "BeeDetail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0.78, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 25,
		Parent = content,
	}, { UI.Corner(22), UI.Gradient(Color3.fromRGB(255, 252, 245), Color3.fromRGB(250, 232, 200)), UI.Create("UIStroke", { Color = Color3.fromRGB(255, 200, 80), Thickness = 3 }) })
	panel.OnOpen = function(eggId)
		if eggId and Config.Eggs[eggId] then
			selected = eggId
		end
		detail.Visible = false
		self:_render()
	end
	-- re-render only when what the panel shows changed (bee level-ups also touch "Bees")
	C.State:OnChange({ "Eggs", "Pity", "Codex" }, function(data)
		if UI.Current ~= "Eggs" or not data then
			return
		end
		local leftSig, gridSig = signatures(data)
		if leftSig ~= lastLeft then
			lastLeft = leftSig
			self:_renderLeft(data)
		end
		if gridSig ~= lastGrid then
			lastGrid = gridSig
			self:_renderGrid(data)
		end
	end)
end

return Eggs
