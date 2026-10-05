--[[
	Settings
	Music / SFX toggles, graphics quality and promo codes. Saved to the profile.
	Low graphics: no shadows, bloom, sun rays, depth of field or decorative particles.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Settings = {}

local C
local UI
local Juice
local values = { Music = true, Sfx = true, Graphics = "High" }
local toggles = {}

Settings.Values = values

function Settings:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

function Settings:Low(): boolean
	return values.Graphics == "Low"
end

function Settings:_applyGraphics()
	local low = values.Graphics == "Low"
	Lighting.GlobalShadows = not low
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") then
			effect.Enabled = not low
		end
	end
end

function Settings:_save()
	Net.Event("SaveSettings"):FireServer(values)
end

local function switch(parent: Instance, order: number, iconName: string, label: string, key: string)
	local row = UI.Glass({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 64), Transparency = 0.25, Radius = 18, Parent = parent })
	UI.Icon(iconName, { Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(44, 44), ImageColor3 = UI.Colors.HoneyDark, Parent = row })
	UI.Label({ Text = label, Position = UDim2.fromOffset(70, 14), Size = UDim2.new(1, -170, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = row })
	local track = UI.Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(78, 38),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = UI.Colors.Good,
		Parent = row,
	}, { UI.Round() })
	local knob = UI.Create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -36, 0.5, 0), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = UI.Colors.White, Parent = track }, { UI.Round() })
	local function paint()
		local on = values[key]
		Juice.Tween(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Position = on and UDim2.new(1, -36, 0.5, 0) or UDim2.new(0, 4, 0.5, 0) })
		Juice.Tween(track, TweenInfo.new(0.2), { BackgroundColor3 = on and UI.Colors.Good or Color3.fromRGB(190, 170, 150) })
	end
	Juice.Bind(track, { Rotate = 0 })
	track.Activated:Connect(function()
		values[key] = not values[key]
		paint()
		if key == "Music" then
			C.Sound:SetMusic(values.Music)
		elseif key == "Sfx" then
			C.Sound:SetSfx(values.Sfx)
		end
		Settings:_save()
	end)
	toggles[key] = paint
	return row
end

function Settings:Start()
	local content, panel = UI:Panel("Settings", "Settings", "Gear")
	local list = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content }, { UI.List(12) })
	list.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	switch(list, 1, "Music", "Music", "Music")
	switch(list, 2, "Speaker", "Sound effects", "Sfx")

	-- graphics: two-state segmented control
	local gfx = UI.Glass({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 64), Transparency = 0.25, Radius = 18, Parent = list })
	UI.Icon("Sparkles", { Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(44, 44), ImageColor3 = UI.Colors.HoneyDark, Parent = gfx })
	UI.Label({ Text = "Graphics", Position = UDim2.fromOffset(70, 14), Size = UDim2.new(1, -330, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = gfx })
	local high, low
	local function paintGfx()
		UI.SetButtonColor(high, values.Graphics == "High" and UI.Colors.Honey or Color3.fromRGB(205, 185, 160))
		UI.SetButtonColor(low, values.Graphics == "Low" and UI.Colors.Honey or Color3.fromRGB(205, 185, 160))
	end
	high = UI.Button({ Text = "HIGH", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -130, 0.5, 0), Size = UDim2.fromOffset(110, 42), Parent = gfx }, function()
		values.Graphics = "High"
		paintGfx()
		self:_applyGraphics()
		self:_save()
	end)
	low = UI.Button({ Text = "LOW", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(110, 42), Parent = gfx }, function()
		values.Graphics = "Low"
		paintGfx()
		self:_applyGraphics()
		self:_save()
	end)

	-- promo codes
	local codes = UI.Glass({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 120), Transparency = 0.25, Radius = 18, Parent = list })
	UI.Icon("Ticket", { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(44, 44), Parent = codes })
	UI.Label({ Text = "Codes", Position = UDim2.fromOffset(70, 16), Size = UDim2.new(1, -90, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = codes })
	local box = UI.Create("TextBox", {
		Position = UDim2.new(0, 16, 0, 66),
		Size = UDim2.new(1, -180, 0, 42),
		BackgroundColor3 = UI.Colors.White,
		BackgroundTransparency = 0.1,
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = UI.Colors.Text,
		PlaceholderText = "Enter code",
		PlaceholderColor3 = UI.Colors.Muted,
		Text = "",
		ClearTextOnFocus = false,
		Parent = codes,
	}, { UI.Round(), UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 16) }) })
	local result = UI.Label({ Text = "", Font = UI.Body, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 20), Size = UDim2.new(0.5, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Right, MaxTextSize = 15, Parent = codes })
	UI.Button({ Text = "REDEEM", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 66), Size = UDim2.fromOffset(150, 42), BackgroundColor3 = UI.Colors.Good, Parent = codes }, function()
		local ok, message = Net.Function("RedeemCode"):InvokeServer(box.Text)
		result.Text = message or ""
		result.TextColor3 = ok and UI.Colors.Good or UI.Colors.Bad
		if ok then
			C.Sound:Play("Purchase")
			box.Text = ""
			Juice.Punch(codes, 0.06)
		else
			Juice.Shake(box, 6)
		end
	end)

	panel.OnOpen = function()
		for _, paint in toggles do
			paint()
		end
		paintGfx()
	end

	C.State:OnChange({ "Settings" }, function(data)
		local saved = data.Settings or {}
		for key in values do
			if saved[key] ~= nil then
				values[key] = saved[key]
			end
		end
		self:_applyGraphics()
	end)
end

return Settings
