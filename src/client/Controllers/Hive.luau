--[[
	Hive
	Clean hex grid of the 37 hive cells. Each hexagon shows the actual 3D bee (ViewportFrame,
	gently sleeping), a rarity dot and a mutation sparkle. Text appears only on hover or in
	the detail card of the selected bee.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local BeeClass = require(Shared.BeeClass)
local HexGrid = require(Shared.HexGrid)
local Synergy = require(Shared.Synergy)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Viewport = require(script.Parent.Viewport)

local player = Players.LocalPlayer

local Hive = {}

local C
local UI
local Juice
local grid: Frame
local detail: Frame
local header: TextLabel
local tooltip: TextLabel
local cells = {} -- [slot] = { Button, Viewport, Dot, Spark, Lock, Key }
local selected: number? = nil
local moveMode = false
local hatchEgg: string? = nil

local RADIUS = Config.Hive.Radius
local COUNT = HexGrid.Get(RADIUS).count

local function hatchBusy(): boolean
	if C.HatchCutscene and C.HatchCutscene:IsBusy() then
		C.NotificationCenter:Push("Wait for the hatch to finish!", "info")
		return true
	end
	return false
end

function Hive:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

local function unlockedSlots(data): number
	local slots = math.min(data.HiveSlots, Config.Hive.MaxHoneySlots)
	if player:GetAttribute("Pass_ExtraSlots") then
		slots += Config.Hive.GamepassSlots
	end
	return slots
end

local function slotPrice(data): number
	return math.floor(Config.Hive.SlotBasePrice * Config.Hive.SlotGrowth ^ (data.HiveSlots - Config.Hive.StartSlots))
end

local function evaluate(data)
	local ids = {}
	for key, record in data.Bees do
		ids[tonumber(key)] = record.Id
	end
	return Synergy.Evaluate(ids)
end

-- Grid ---------------------------------------------------------------------------------------------

function Hive:_layout()
	local size = grid.AbsoluteSize
	local s = math.min(size.X / (math.sqrt(3) * 7.2), size.Y / 11.2)
	for slot, cell in cells do
		local offset = HexGrid.ToOffset(RADIUS, slot, s)
		cell.Button.Size = UDim2.fromOffset(s * math.sqrt(3) * 0.98, s * 2 * 0.98)
		-- mirrored so the panel matches the real hive as seen from its pad (world x = -offset.X, up = +Y)
		cell.Button.Position = UDim2.new(0.5, -offset.X, 0.5, -offset.Y)
	end
end

function Hive:_buildGrid(parent: Frame)
	grid = UI.Create("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.56, -8, 1, -54),
		Position = UDim2.fromOffset(0, 54),
		Parent = parent,
	})
	for slot = 1, COUNT do
		local button = UI.Create("ImageButton", {
			Name = "Cell" .. slot,
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = UI.Icons.Hex,
			ImageColor3 = Color3.fromRGB(255, 236, 190),
			ScaleType = Enum.ScaleType.Fit,
			Parent = grid,
		})
		local ring = UI.Create("ImageLabel", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Image = UI.Icons.HexRing,
			ImageColor3 = UI.Colors.White,
			ImageTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
			Parent = button,
		})
		local dot = UI.Create("Frame", {
			Name = "Rarity",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.74, 0.76),
			Size = UDim2.fromScale(0.2, 0.2),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundColor3 = UI.Colors.White,
			Visible = false,
			ZIndex = 5,
			Parent = button,
		}, { UI.Round(), UI.Create("UIStroke", { Color = UI.Colors.White, Thickness = 2, Transparency = 0.1 }) })
		local spark = UI.Icon("Sparkles", {
			Name = "Mutation",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.26, 0.24),
			Size = UDim2.fromScale(0.28, 0.28),
			Visible = false,
			ZIndex = 5,
			Parent = button,
		})
		local lock = UI.Icon("Lock", {
			Name = "Lock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.42, 0.42),
			ImageTransparency = 0.35,
			Visible = false,
			ZIndex = 5,
			Parent = button,
		})
		local plus = UI.Icon("Egg", {
			Name = "Plus",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.4, 0.4),
			ImageTransparency = 0.3,
			Visible = false,
			ZIndex = 5,
			Parent = button,
		})
		Juice.Bind(button, { Hover = 1.12, Rotate = 3, Silent = true })
		button.Activated:Connect(function()
			C.Sound:Play("SoftPop", { Vary = 0.2 })
			self:_click(slot)
		end)
		button.MouseEnter:Connect(function()
			self:_hover(slot, button)
		end)
		button.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)
		cells[slot] = { Button = button, Ring = ring, Dot = dot, Spark = spark, Lock = lock, Plus = plus, Key = nil, Viewport = nil }
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	self:_layout()
end

function Hive:_hover(slot: number, button: GuiObject)
	local data = C.State.Data
	local record = data and data.Bees[tostring(slot)]
	if not record then
		tooltip.Visible = false
		return
	end
	local def = BeeData.Bees[record.Id]
	tooltip.Text = `{record.Mutation and (record.Mutation .. " ") or ""}{def.Name}  •  Lv {record.Level}`
	tooltip.Position = UDim2.fromOffset(button.AbsolutePosition.X - grid.AbsolutePosition.X + button.AbsoluteSize.X / 2, button.AbsolutePosition.Y - grid.AbsolutePosition.Y - 6)
	tooltip.Visible = true
end

function Hive:_paintCell(slot: number, data, unlocked: number, inCombo)
	local cell = cells[slot]
	local record = data.Bees[tostring(slot)]
	local key = record and (record.Id .. ":" .. tostring(record.Mutation)) or nil
	if key ~= cell.Key then
		cell.Key = key
		if cell.Viewport then
			cell.Viewport:Destroy()
			cell.Viewport = nil
		end
		if record then
			local model = C.BeeRenderer.Build(record.Id, record.Mutation)
			if model then
				cell.Viewport = Viewport.Model(cell.Button, model, {
					Mode = "sleep",
					Zoom = 0.9,
					Props = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.52),
						Size = UDim2.fromScale(0.86, 0.86),
						ZIndex = 3,
					},
				})
			end
		end
	end
	if record then
		local def = BeeData.Bees[record.Id]
		local rarity = Config.Rarities[def.Rarity]
		cell.Button.ImageColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.55)
		cell.Button.ImageTransparency = 0
		cell.Dot.Visible = true
		cell.Dot.BackgroundColor3 = rarity.Color
		local mutation = record.Mutation and Config.Mutations[record.Mutation]
		cell.Spark.Visible = mutation ~= nil
		if mutation then
			cell.Spark.ImageColor3 = mutation.Color
		end
		cell.Lock.Visible = false
		cell.Plus.Visible = false
	elseif slot <= unlocked then
		cell.Button.ImageColor3 = Color3.fromRGB(255, 236, 190)
		cell.Button.ImageTransparency = 0.15
		cell.Dot.Visible = false
		cell.Spark.Visible = false
		cell.Lock.Visible = false
		cell.Plus.Visible = hatchEgg ~= nil
	else
		cell.Button.ImageColor3 = Color3.fromRGB(110, 80, 50)
		cell.Button.ImageTransparency = 0.45
		cell.Dot.Visible = false
		cell.Spark.Visible = false
		cell.Lock.Visible = slot == unlocked + 1
		cell.Plus.Visible = false
	end
	local highlight = slot == selected or inCombo[slot]
	cell.Ring.ImageTransparency = highlight and 0 or 1
	cell.Ring.ImageColor3 = slot == selected and (moveMode and UI.Colors.Blue or UI.Colors.White) or UI.Colors.HoneyLight
end

function Hive:_paintGrid(data)
	local unlocked = unlockedSlots(data)
	local synergy = evaluate(data)
	local inCombo = {}
	for _, active in synergy.Active do
		for _, slot in active.Slots do
			inCombo[slot] = true
		end
	end
	for slot in cells do
		self:_paintCell(slot, data, unlocked, inCombo)
	end
	if hatchEgg then
		header.Text = `Pick an empty cell for your {Config.Eggs[hatchEgg].Name}`
	elseif moveMode then
		header.Text = "Pick a cell to swap with"
	else
		header.Text = `{C.State:BeeCount()} / {unlocked}`
	end
	self.ScoreLabel.Text = Format.Short(BeeClass.SwarmScore(data.Bees))
end

-- Detail card ---------------------------------------------------------------------------------------

local order = 0
local function row(parent: Instance, height: number)
	order += 1
	return UI.Create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = parent })
end

local function stat(parent: Instance, iconName: string, text: string)
	local r = row(parent, 30)
	UI.Icon(iconName, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, 1), Parent = r })
	UI.Label({ Text = text, Font = UI.Body, Position = UDim2.fromOffset(38, 3), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 17, Parent = r })
end

local function action(parent: Instance, iconName: string, text: string, color: Color3?, onClick)
	local r = row(parent, 46)
	return UI.Button({ Text = text, Icon = iconName, Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = color or UI.Colors.Honey, MaxTextSize = 18, Parent = r }, onClick)
end

-- Several compact buttons side by side in one row
local function actionRow(parent: Instance, buttons)
	local r = row(parent, 46)
	UI.List(6, true).Parent = r
	for i, b in buttons do
		UI.Button({
			LayoutOrder = i,
			Text = b.Text,
			Icon = b.Icon,
			Size = UDim2.new(1 / #buttons, -6 * (#buttons - 1) / #buttons, 1, -4),
			BackgroundColor3 = b.Color or UI.Colors.Honey,
			MaxTextSize = 17,
			Parent = r,
		}, b.OnClick)
	end
end

function Hive:_renderDetail(data)
	for _, child in detail.List:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- keep the 3D preview if the same bee is still selected (rebuilding it restarts its animation)
	local selectedRecord = selected and data.Bees[tostring(selected)]
	local detailKey = selectedRecord and `{selected}:{selectedRecord.Id}:{tostring(selectedRecord.Mutation)}` or nil
	if self.DetailViewport and self.DetailKey ~= detailKey then
		self.DetailViewport:Destroy()
		self.DetailViewport = nil
	end
	self.DetailKey = detailKey
	order = 0
	local list = detail.List
	local unlocked = unlockedSlots(data)
	local synergy = evaluate(data)
	detail.Preview.Visible = false

	if not selected then
		local r = row(list, 36)
		UI.Icon("Honeycomb", { Size = UDim2.fromOffset(34, 34), Parent = r })
		UI.Label({ Text = "Synergies", Position = UDim2.fromOffset(42, 2), Size = UDim2.new(1, -44, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = r })
		if #synergy.Active == 0 then
			local hint = row(list, 44)
			UI.Label({ Text = "Place matching bees side by side to unlock combos.", Font = UI.Body, TextColor3 = UI.Colors.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = hint })
		end
		for _, active in synergy.Active do
			local def = Synergy.ById[active.Id]
			local card = row(list, 58)
			local glass = UI.Glass({ Size = UDim2.fromScale(1, 1), Transparency = 0.2, Radius = 14, Parent = card })
			UI.Icon("Star", { Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(32, 32), Parent = glass })
			UI.Label({ Text = def.Name, Position = UDim2.fromOffset(48, 4), Size = UDim2.new(1, -54, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = glass })
			UI.Label({ Text = def.Description, Font = UI.Body, TextColor3 = UI.Colors.Muted, Position = UDim2.fromOffset(48, 28), Size = UDim2.new(1, -54, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 12, Parent = glass })
		end
		return
	end

	local record = data.Bees[tostring(selected)]
	if record then
		local def = BeeData.Bees[record.Id]
		local bee = BeeClass.new(selected, record, nil)
		bee:SetModifiers(synergy.BeeMods[selected])
		local stats = bee.Stats
		local rarity = Config.Rarities[def.Rarity]
		detail.Preview.Visible = true
		if not self.DetailViewport then
			local model = C.BeeRenderer.Build(record.Id, record.Mutation)
			if model then
				self.DetailViewport = Viewport.Model(detail.Preview, model, { Mode = "float", Zoom = 0.85 })
			end
		end
		local title = row(list, 34)
		UI.Label({ Text = def.Name, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = title })
		local tags = row(list, 26)
		local pillFrame = UI.Create("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = rarity.Color, Parent = tags }, {
			UI.Round(), UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
		UI.Create("TextLabel", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.Body, TextSize = 13, TextColor3 = UI.Colors.White, Text = def.Rarity:upper() .. (record.Mutation and ("  •  " .. record.Mutation:upper()) or ""), Parent = pillFrame })
		local maxed = record.Level >= Config.Levels.Max
		local xpRow = row(list, 26)
		local _, fill, text = UI.Bar({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 2), Color = UI.Colors.Blue, MaxTextSize = 14, Parent = xpRow })
		local need = BeeClass.XPToNext(record.Level)
		fill.Size = UDim2.fromScale(maxed and 1 or math.clamp(record.XP / need, 0.04, 1), 1)
		text.Text = maxed and `Lv {record.Level}  MAX` or `Lv {record.Level}   {record.XP} / {need}`
		stat(list, "Pollen", `{Format.Short(stats.Gather)} every {string.format("%.1f", stats.GatherTime)}s`)
		stat(list, "Honey", `{Format.Short(stats.Convert)} per trip`)
		stat(list, "Lightning", `Speed {string.format("%.0f", stats.Speed)}  •  Attack {string.format("%.0f", stats.Attack)}`)
		if def.Ability then
			stat(list, "Star", `{def.Ability.Name}  ({string.format("%.0f", stats.AbilityCooldown)}s)`)
		end
		local buttons = {}
		if not maxed then
			table.insert(buttons, { Icon = "Treat", Text = tostring(data.Treats), OnClick = function()
				Net.Event("FeedBee"):FireServer(selected, data.Treats >= 10 and 10 or 1)
			end })
		end
		table.insert(buttons, { Icon = "Serum", Text = tostring(data.Serums), Color = UI.Colors.Purple, OnClick = function()
			Net.Event("UseSerum"):FireServer(selected)
		end })
		table.insert(buttons, { Icon = "Honeycomb", Text = moveMode and "Cancel" or "Move", Color = UI.Colors.Blue, OnClick = function()
			moveMode = not moveMode
			self:Refresh()
		end })
		actionRow(list, buttons)
	elseif selected <= unlocked then
		local title = row(list, 34)
		UI.Label({ Text = "Empty cell", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = title })
		local any = false
		for _, eggId in Config.EggOrder do
			local count = data.Eggs[eggId] or 0
			if count > 0 then
				any = true
				action(list, "Egg", `{Config.Eggs[eggId].Name}  x{count}`, Config.Eggs[eggId].Color:Lerp(UI.Colors.Honey, 0.4), function()
					if not hatchBusy() then
						Net.Event("HatchEgg"):FireServer(eggId, selected)
					end
				end)
			end
		end
		if not any then
			local hint = row(list, 44)
			UI.Label({ Text = "Hatch eggs at the Golden Nests near spawn.", Font = UI.Body, TextColor3 = UI.Colors.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = hint })
		end
	else
		local title = row(list, 34)
		UI.Label({ Text = "Locked", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = title })
		if selected == unlocked + 1 and data.HiveSlots < Config.Hive.MaxHoneySlots then
			local price = slotPrice(data)
			action(list, "Honey", Format.Short(price), data.Honey >= price and UI.Colors.Honey or Color3.fromRGB(200, 180, 150), function()
				Net.Event("BuySlot"):FireServer()
			end)
		elseif data.HiveSlots >= Config.Hive.MaxHoneySlots then
			action(list, "Gift", "+2 Hive Slots", UI.Colors.Good, function()
				UI:Open("Store")
			end)
		end
	end
end

-- Interaction -------------------------------------------------------------------------------------------

function Hive:_click(slot: number)
	local data = C.State.Data
	if not data then
		return
	end
	local unlocked = unlockedSlots(data)
	if hatchEgg then
		if slot <= unlocked and not data.Bees[tostring(slot)] then
			if not hatchBusy() then
				Net.Event("HatchEgg"):FireServer(hatchEgg, slot)
			end
			hatchEgg = nil
			UI:Close()
		else
			Juice.Shake(cells[slot].Button, 5)
		end
		self:Refresh()
		return
	end
	if moveMode and selected then
		if slot <= unlocked and slot ~= selected then
			Net.Event("MoveBee"):FireServer(selected, slot)
			selected = slot
			C.Sound:Play("Pop")
		end
		moveMode = false
		self:Refresh()
		return
	end
	selected = (selected == slot) and nil or slot
	if selected then
		Juice.Punch(cells[slot].Button, 0.15)
	end
	self:Refresh()
end

function Hive:Refresh()
	local data = C.State.Data
	if not data or not grid then
		return
	end
	self:_paintGrid(data)
	self:_renderDetail(data)
end

function Hive:StartHatch(eggId: string)
	hatchEgg = eggId
	selected = nil
	moveMode = false
	UI:Open("Hive")
end

function Hive:Start()
	local content, panel = UI:Panel("Hive", "My Hive", "Honeycomb")
	local top = UI.Create("Frame", { Size = UDim2.new(0.56, -8, 0, 44), BackgroundTransparency = 1, Parent = content })
	UI.Icon("Bee", { Size = UDim2.fromOffset(40, 40), Parent = top })
	header = UI.Label({ Position = UDim2.fromOffset(46, 4), Size = UDim2.new(0.6, -46, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = top })
	UI.Icon("Star", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -90, 0, 2), Size = UDim2.fromOffset(38, 38), Parent = top })
	self.ScoreLabel = UI.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(86, 36), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = top })

	self:_buildGrid(content)
	tooltip = UI.Create("TextLabel", {
		Name = "Tooltip",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Ink,
		BackgroundTransparency = 0.25,
		Font = UI.Body,
		TextSize = 14,
		TextColor3 = UI.Colors.White,
		Visible = false,
		ZIndex = 30,
		Parent = grid,
	}, { UI.Round(), UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

	detail = UI.Glass({
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.43, -8, 1, 0),
		Transparency = 0.25,
		Radius = 20,
		Parent = content,
	})
	local preview = UI.Create("Frame", { Name = "Preview", Size = UDim2.new(1, 0, 0.34, 0), BackgroundTransparency = 1, Visible = false, Parent = detail })
	UI.Icon("Glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 1.1), ImageColor3 = UI.Colors.HoneyLight, ImageTransparency = 0.35, Parent = preview })
	local list = UI.Create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.new(0, 14, 0.34, 0),
		Size = UDim2.new(1, -28, 0.66, -12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = detail,
	}, { UI.List(6) })
	list.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	preview:GetPropertyChangedSignal("Visible"):Connect(function()
		list.Position = preview.Visible and UDim2.new(0, 14, 0.34, 0) or UDim2.fromOffset(14, 14)
		list.Size = preview.Visible and UDim2.new(1, -28, 0.66, -12) or UDim2.new(1, -28, 1, -28)
	end)

	panel.OnOpen = function()
		task.defer(function()
			self:_layout()
		end)
		self:Refresh()
	end
	panel.OnClose = function()
		hatchEgg = nil
		moveMode = false
	end

	-- refresh when something the panel shows changes; honey only matters for the unlock price,
	-- so auto-convert ticks (many per second) no longer rebuild the panel
	local RELEVANT = { Bees = true, HiveSlots = true, Eggs = true, Treats = true, Serums = true }
	local queued = false
	local lastAffordable = nil
	C.State.Changed:Connect(function(keys)
		local data = C.State.Data
		if UI.Current ~= "Hive" or not data then
			return
		end
		local relevant = false
		for key in keys do
			if RELEVANT[key] then
				relevant = true
			end
		end
		if keys.Honey then
			local affordable = (data.Honey or 0) >= slotPrice(data)
			if affordable ~= lastAffordable then
				lastAffordable = affordable
				relevant = true
			end
		end
		if relevant and not queued then
			queued = true
			task.delay(0.25, function()
				queued = false
				if UI.Current == "Hive" then
					self:Refresh()
				end
			end)
		end
	end)
	player:GetAttributeChangedSignal("Pass_ExtraSlots"):Connect(function()
		self:Refresh()
	end)
	Net.Event("HatchResult").OnClientEvent:Connect(function(result)
		selected = result.Slot
	end)
end

return Hive
