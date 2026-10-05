--[[
	HUD
	Always-on screen elements: honey counter, pollen bar, menu buttons, the Make Honey
	button near your hive, boost timers and toasts from the server.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local HUD = {}

local C -- controllers
local UI

local MENU = {
	{ Name = "Hive", Label = "Hive", Color = Color3.fromRGB(255, 194, 46) },
	{ Name = "Shop", Label = "Shop", Color = Color3.fromRGB(120, 200, 110) },
	{ Name = "Eggs", Label = "Eggs", Color = Color3.fromRGB(245, 235, 210) },
	{ Name = "Codex", Label = "Codex", Color = Color3.fromRGB(150, 190, 255) },
	{ Name = "Store", Label = "R$ Store", Color = Color3.fromRGB(110, 230, 140) },
}

function HUD:Init(controllers)
	C = controllers
	UI = C.UI
end

function HUD:_build()
	local screen = UI:_screen()

	-- honey counter
	local honeyFrame = UI.Create("Frame", {
		Name = "Honey",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 54),
		BackgroundColor3 = UI.Colors.Honey,
		Parent = screen,
	}, { UI.Corner(16), UI.Stroke(UI.Colors.Brown, 3) })
	local hex = UI.Create("Frame", {
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = UI.Colors.HoneyDark,
		Rotation = 45,
		Parent = honeyFrame,
	}, { UI.Corner(8), UI.Stroke(UI.Colors.Brown, 2) })
	hex.Name = "Icon"
	self.HoneyLabel = UI.Label({
		Text = "0",
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -66, 1, -8),
		TextColor3 = UI.Colors.Brown,
		MaxTextSize = 34,
		Parent = honeyFrame,
	})
	self.HoneyScale = UI.Create("UIScale", { Parent = honeyFrame })

	-- pollen bar
	local bar, fill, text = UI.Bar({
		Size = UDim2.fromOffset(420, 34),
		Position = UDim2.new(0.5, 0, 1, -84), -- above the default tool hotbar
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Color3.fromRGB(255, 226, 90),
		MaxTextSize = 20,
		Parent = screen,
	})
	bar.Name = "PollenBar"
	UI.Stroke(UI.Colors.Brown, 3).Parent = bar
	UI.Create("UISizeConstraint", { MaxSize = Vector2.new(420, 34), Parent = bar })
	bar.Size = UDim2.new(0.6, 0, 0, 34)
	self.PollenFill = fill
	self.PollenText = text

	-- menu buttons
	local menu = UI.Create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(96, 330),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.List(8) })
	for i, item in MENU do
		UI.Button({
			Name = item.Name,
			Text = item.Label,
			LayoutOrder = i,
			Size = UDim2.fromOffset(96, 56),
			BackgroundColor3 = item.Color,
			MaxTextSize = 22,
			Parent = menu,
		}, function()
			UI:Toggle(item.Name)
		end)
	end

	-- make honey
	self.ConvertButton = UI.Button({
		Name = "MakeHoney",
		Text = "Make Honey",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -70),
		Size = UDim2.fromOffset(190, 64),
		BackgroundColor3 = UI.Colors.Honey,
		MaxTextSize = 28,
		Visible = false,
		Parent = screen,
	}, function()
		Net.Event("ToggleConvert"):FireServer(not player:GetAttribute("Converting"))
	end)

	-- boosts
	self.Boosts = UI.Label({
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -124),
		Size = UDim2.fromOffset(420, 22),
		TextColor3 = Color3.fromRGB(255, 240, 160),
		TextStrokeTransparency = 0.3,
		Font = UI.Body,
		MaxTextSize = 16,
		Parent = screen,
	})
end

function HUD:_refresh(data)
	local honey = data.Honey or 0
	local text = honey < 1e6 and Format.Commas(honey) or Format.Short(honey)
	if self.HoneyLabel.Text ~= text then
		self.HoneyLabel.Text = text
		self.HoneyScale.Scale = 1.08
		TweenService:Create(self.HoneyScale, TweenInfo.new(0.2), { Scale = 1 }):Play()
	end
	local capacity = C.State:Capacity()
	local pollen = math.floor(data.Pollen or 0)
	local ratio = capacity > 0 and math.clamp(pollen / capacity, 0, 1) or 0
	TweenService:Create(self.PollenFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
	self.PollenFill.BackgroundColor3 = ratio >= 1 and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(255, 226, 90)
	self.PollenText.Text = `Pollen  {Format.Short(pollen)} / {Format.Short(capacity)}`
end

function HUD:Start()
	self:_build()

	C.State:OnChange({ "Honey", "Pollen", "Backpack" }, function(data)
		self:_refresh(data)
	end)

	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		UI:Toast(text, kind)
	end)

	-- shop stands carry an OpenPanel attribute on their ProximityPrompt
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local panel = prompt:GetAttribute("OpenPanel")
		if panel then
			UI:Open(panel, prompt:GetAttribute("OpenArg"))
		end
	end)

	player:GetAttributeChangedSignal("Converting"):Connect(function()
		local on = player:GetAttribute("Converting")
		self.ConvertButton.Text = on and "Stop" or "Make Honey"
		self.ConvertButton.BackgroundColor3 = on and UI.Colors.Bad or UI.Colors.Honey
	end)

	-- proximity to own hive pad + boost timers (cheap, 4 Hz)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local index = player:GetAttribute("HiveIndex")
			local map = Workspace:FindFirstChild("Map")
			local hive = index and map and map:FindFirstChild("Hives") and map.Hives:FindFirstChild("Hive_" .. index)
			local pad = hive and hive:FindFirstChild("Pad")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local near = pad and root and (root.Position - pad.Position).Magnitude <= Config.Convert.Range
			self.ConvertButton.Visible = near == true or player:GetAttribute("Converting") == true

			local data = C.State.Data
			if data and data.Boosts then
				local parts = {}
				local now = os.time()
				for fieldId, expiry in data.Boosts do
					if expiry > now then
						local def = Config.FieldById[fieldId]
						table.insert(parts, `2x {def and def.Name or fieldId} {Format.Time(expiry - now)}`)
					end
				end
				self.Boosts.Text = table.concat(parts, "   ")
			end
		end
	end)
end

return HUD
