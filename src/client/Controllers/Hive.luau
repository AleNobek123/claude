--[[
	Hive
	The hive editor: a 2D hex grid mirroring the 37 cells of your hive.
	  - click a bee to see exact stats (same BeeClass math as the server), feed it,
	    apply a serum, or move it (swap with any other unlocked cell);
	  - click an empty cell to hatch an egg into it;
	  - click the next locked cell to buy it.
	Active synergies are evaluated locally with the shared Synergy module.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BeeData = require(Shared.BeeData)
local BeeClass = require(Shared.BeeClass)
local HexGrid = require(Shared.HexGrid)
local Synergy = require(Shared.Synergy)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Hive = {}

local C
local UI
local grid: Frame
local detail: ScrollingFrame
local banner: TextLabel
local cells = {} -- [slot] = TextButton
local selected: number? = nil
local moveMode = false
local hatchEgg: string? = nil

local RADIUS = Config.Hive.Radius
local COUNT = HexGrid.Get(RADIUS).count

function Hive:Init(controllers)
	C = controllers
	UI = C.UI
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

-- Grid ------------------------------------------------------------------------------------------

function Hive:_layout()
	local size = grid.AbsoluteSize
	local s = math.min(size.X / (math.sqrt(3) * 7.4), size.Y / 11.6)
	for slot, button in cells do
		local offset = HexGrid.ToOffset(RADIUS, slot, s)
		button.Size = UDim2.fromOffset(s * 1.62, s * 1.62)
		button.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	end
end

function Hive:_buildGrid(parent: Frame)
	grid = UI.Create("Frame", {
		Name = "Grid",
		BackgroundColor3 = Color3.fromRGB(120, 78, 36),
		Size = UDim2.new(0.56, -8, 1, -46),
		Position = UDim2.fromOffset(0, 46),
		Parent = parent,
	}, { UI.Corner(16), UI.Stroke(UI.Colors.Brown, 3) })
	for slot = 1, COUNT do
		local button = UI.Create("TextButton", {
			Name = "Cell" .. slot,
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			Font = UI.Font,
			TextScaled = true,
			TextColor3 = UI.Colors.Brown,
			Text = "",
			Parent = grid,
		}, {
			UI.Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UI.Create("UIStroke", { Name = "Stroke", Thickness = 2, Color = UI.Colors.Brown }),
			UI.Create("UITextSizeConstraint", { MaxTextSize = 14 }),
			UI.Create("UIPadding", { PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0) }),
		})
		button.Activated:Connect(function()
			self:_click(slot)
		end)
		cells[slot] = button
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	self:_layout()
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
	for slot, button in cells do
		local record = data.Bees[tostring(slot)]
		local stroke = button.Stroke
		if record then
			local def = BeeData.Bees[record.Id]
			button.BackgroundColor3 = Config.Rarities[def.Rarity].Color
			button.Text = def.Name:gsub(" Bee", ""):gsub("Queen's ", "Q.") .. "\n" .. record.Level
			local mutation = record.Mutation and Config.Mutations[record.Mutation]
			stroke.Color = mutation and mutation.Color or (inCombo[slot] and Color3.fromRGB(255, 255, 255) or UI.Colors.Brown)
			stroke.Thickness = (mutation or inCombo[slot]) and 3 or 2
		elseif slot <= unlocked then
			button.BackgroundColor3 = Color3.fromRGB(255, 214, 120)
			button.Text = hatchEgg and "+" or ""
			stroke.Color = UI.Colors.Brown
			stroke.Thickness = 2
		else
			button.BackgroundColor3 = Color3.fromRGB(80, 54, 30)
			button.Text = slot == unlocked + 1 and "Buy" or ""
			button.TextColor3 = UI.Colors.Cream
			stroke.Color = Color3.fromRGB(60, 40, 20)
			stroke.Thickness = 2
		end
		if record or slot <= unlocked then
			button.TextColor3 = UI.Colors.Brown
		end
		if slot == selected then
			stroke.Color = moveMode and UI.Colors.Blue or UI.Colors.White
			stroke.Thickness = 4
		end
	end
	if hatchEgg then
		banner.Text = `Hatching {Config.Eggs[hatchEgg].Name}: pick an empty cell`
	elseif moveMode then
		banner.Text = "Move: pick a cell to swap with"
	else
		banner.Text = `Bees {C.State:BeeCount()} / {unlocked} • Swarm Score {Format.Short(BeeClass.SwarmScore(data.Bees))}`
	end
end

-- Detail pane -------------------------------------------------------------------------------------

local function clearDetail()
	for _, child in detail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local order = 0
local function line(text: string, props)
	order += 1
	props = props or {}
	return UI.Label({
		Text = text,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, props.Height or 22),
		Font = props.Font or UI.Body,
		TextColor3 = props.Color or UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = props.Max or 16,
		Parent = detail,
	})
end

local function button(text: string, color: Color3?, onClick)
	order += 1
	return UI.Button({
		Text = text,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 38),
		BackgroundColor3 = color or UI.Colors.Honey,
		Parent = detail,
	}, onClick)
end

function Hive:_renderDetail(data)
	clearDetail()
	order = 0
	local unlocked = unlockedSlots(data)
	local synergy = evaluate(data)

	if not selected then
		line("Your Hive", { Font = UI.Font, Max = 26, Height = 32 })
		line("Click a bee to manage it, or an empty cell to hatch an egg.", { Color = UI.Colors.Muted, Height = 40 })
		line(`Treats: {data.Treats}   Serums: {data.Serums}`)
		line("Active synergies", { Font = UI.Font, Max = 20, Height = 28 })
		if #synergy.Active == 0 then
			line("None yet. Place same-tag bees next to each other!", { Color = UI.Colors.Muted, Height = 40 })
		end
		for _, active in synergy.Active do
			local def = Synergy.ById[active.Id]
			line(def.Name, { Color = UI.Colors.HoneyDark })
			line(def.Description, { Color = UI.Colors.Muted, Height = 34, Max = 13 })
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
		line(def.Name, { Font = UI.Font, Max = 28, Height = 34, Color = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.45) })
		line(`{def.Rarity}{record.Mutation and (" • " .. record.Mutation) or ""} • {def.Color} • {table.concat(def.Tags, ", ")}`, {
			Color = UI.Colors.Muted,
		})
		local maxed = record.Level >= Config.Levels.Max
		local need = BeeClass.XPToNext(record.Level)
		line(maxed and `Level {record.Level} (max)` or `Level {record.Level}  •  XP {record.XP} / {need}`)
		line(`Gather {Format.Short(stats.Gather)} every {string.format("%.1f", stats.GatherTime)}s`)
		line(`Speed {string.format("%.1f", stats.Speed)}  •  Convert {Format.Short(stats.Convert)}/trip`)
		line(`Attack {string.format("%.1f", stats.Attack)}`)
		if def.Ability then
			line(`{def.Ability.Name} ({string.format("%.0f", stats.AbilityCooldown)}s)`, { Color = UI.Colors.HoneyDark })
		end
		line(def.Description, { Color = UI.Colors.Muted, Height = 36, Max = 13 })
		for _, active in synergy.Active do
			if table.find(active.Slots, selected) then
				line("Synergy: " .. Synergy.ById[active.Id].Name, { Color = UI.Colors.Good })
			end
		end
		if not maxed then
			button(`Feed 1 Treat (have {data.Treats})`, nil, function()
				Net.Event("FeedBee"):FireServer(selected, 1)
			end)
			button("Feed 10 Treats", nil, function()
				Net.Event("FeedBee"):FireServer(selected, 10)
			end)
		end
		button(`Use Mutation Serum (have {data.Serums})`, Color3.fromRGB(200, 160, 255), function()
			Net.Event("UseSerum"):FireServer(selected)
		end)
		button(moveMode and "Cancel move" or "Move bee", UI.Colors.Blue, function()
			moveMode = not moveMode
			self:Refresh()
		end)
	elseif selected <= unlocked then
		line(`Empty cell #{selected}`, { Font = UI.Font, Max = 26, Height = 32 })
		local any = false
		for _, eggId in Config.EggOrder do
			local count = data.Eggs[eggId] or 0
			if count > 0 then
				any = true
				button(`Hatch {Config.Eggs[eggId].Name} (x{count})`, Config.Eggs[eggId].Color, function()
					Net.Event("HatchEgg"):FireServer(eggId, selected)
				end)
			end
		end
		if not any then
			line("No eggs. Buy one in the Egg shop.", { Color = UI.Colors.Muted })
			button("Open Egg shop", nil, function()
				UI:Open("Eggs")
			end)
		end
	else
		line(`Locked cell #{selected}`, { Font = UI.Font, Max = 26, Height = 32 })
		if selected == unlocked + 1 and data.HiveSlots < Config.Hive.MaxHoneySlots then
			local price = slotPrice(data)
			button(`Unlock for {Format.Short(price)} honey`, data.Honey >= price and UI.Colors.Honey or UI.Colors.CreamDark, function()
				Net.Event("BuySlot"):FireServer()
			end)
		elseif data.HiveSlots >= Config.Hive.MaxHoneySlots then
			line("The last cells come with the +2 Hive Slots pass.", { Color = UI.Colors.Muted, Height = 36 })
			button("Open Store", Color3.fromRGB(110, 230, 140), function()
				UI:Open("Store")
			end)
		else
			line("Unlock the cells before this one first.", { Color = UI.Colors.Muted })
		end
	end
end

-- Interaction ----------------------------------------------------------------------------------------

function Hive:_click(slot: number)
	local data = C.State.Data
	if not data then
		return
	end
	local unlocked = unlockedSlots(data)
	if hatchEgg then
		if slot <= unlocked and not data.Bees[tostring(slot)] then
			Net.Event("HatchEgg"):FireServer(hatchEgg, slot)
			hatchEgg = nil
		else
			UI:Toast("Pick an empty, unlocked cell.", "bad")
		end
		self:Refresh()
		return
	end
	if moveMode and selected then
		if slot <= unlocked and slot ~= selected then
			Net.Event("MoveBee"):FireServer(selected, slot)
			selected = slot
		end
		moveMode = false
		self:Refresh()
		return
	end
	selected = (selected == slot) and nil or slot
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

-- Hatch reveal ------------------------------------------------------------------------------------------

function Hive:_reveal(result)
	local record = result.Record
	local def = BeeData.Bees[record.Id]
	local rarity = Config.Rarities[def.Rarity]
	local screen = UI:_screen()
	local card = UI.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(360, 230),
		BackgroundColor3 = UI.Colors.Cream,
		ZIndex = 50,
		Parent = screen,
	}, { UI.Corner(20), UI.Stroke(rarity.Color, 6) })
	local scale = UI.Create("UIScale", { Scale = 0.2, Parent = card })
	UI.Label({ Text = def.Rarity:upper(), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 14), TextColor3 = rarity.Color, MaxTextSize = 34, ZIndex = 51, Parent = card })
	UI.Label({ Text = def.Name, Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 58), MaxTextSize = 40, ZIndex = 51, Parent = card })
	local sub = {}
	if record.Mutation then
		table.insert(sub, record.Mutation .. " mutation!")
	end
	if result.New then
		table.insert(sub, "NEW in your Codex")
	end
	if result.Pity then
		table.insert(sub, "Pity reward")
	end
	UI.Label({ Text = table.concat(sub, "  •  "), Font = UI.Body, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 112), TextColor3 = UI.Colors.HoneyDark, MaxTextSize = 18, ZIndex = 51, Parent = card })
	UI.Label({ Text = def.Description, Font = UI.Body, Size = UDim2.new(1, -30, 0, 50), Position = UDim2.fromOffset(15, 146), TextColor3 = UI.Colors.Muted, MaxTextSize = 15, ZIndex = 51, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3.5, function()
		local tween = TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 })
		tween:Play()
		tween.Completed:Wait()
		card:Destroy()
	end)
end

function Hive:StartHatch(eggId: string)
	hatchEgg = eggId
	selected = nil
	moveMode = false
	UI:Open("Hive")
end

function Hive:Start()
	local content, panel = UI:Panel("Hive", "My Hive")
	banner = UI.Label({
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = content,
	})
	self:_buildGrid(content)
	detail = UI.Create("ScrollingFrame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 46),
		Size = UDim2.new(0.44, -8, 1, -46),
		BackgroundColor3 = UI.Colors.CreamDark,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UI.Corner(14), UI.Padding(10), UI.List(4) })

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

	C.State:OnChange({ "Bees", "HiveSlots", "Eggs", "Treats", "Serums", "Honey" }, function()
		if UI.Current == "Hive" then
			self:Refresh()
		end
	end)
	player:GetAttributeChangedSignal("Pass_ExtraSlots"):Connect(function()
		self:Refresh()
	end)
	Net.Event("HatchResult").OnClientEvent:Connect(function(result)
		selected = result.Slot
		self:_reveal(result)
	end)
end

return Hive
