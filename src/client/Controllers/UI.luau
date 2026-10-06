--[[
	UI
	Visual language v2: soft, borderless, icon-first.
	  - no thick strokes, no solid text boxes: glass cards (semi-transparent + gradient + soft shadow)
	  - icons instead of labels; text only for numbers and on hover/details
	  - every button goes through Juice.Bind
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Juice = require(script.Parent.Juice)

local player = Players.LocalPlayer

local UI = {}

UI.Colors = {
	Honey = Color3.fromRGB(255, 196, 46),
	HoneyLight = Color3.fromRGB(255, 222, 110),
	HoneyDark = Color3.fromRGB(232, 140, 24),
	Brown = Color3.fromRGB(70, 44, 22),
	Cream = Color3.fromRGB(255, 250, 240),
	CreamDark = Color3.fromRGB(250, 236, 208),
	Text = Color3.fromRGB(70, 46, 26),
	Muted = Color3.fromRGB(150, 118, 86),
	Good = Color3.fromRGB(96, 206, 110),
	Bad = Color3.fromRGB(240, 96, 84),
	Blue = Color3.fromRGB(86, 166, 250),
	Purple = Color3.fromRGB(168, 110, 250),
	Ink = Color3.fromRGB(30, 22, 16),
	White = Color3.new(1, 1, 1),
}

UI.Font = Enum.Font.FredokaOne
UI.Body = Enum.Font.GothamBold
UI.Icons = Assets.Icons
UI.Juice = Juice

UI.Panels = {}
UI.Current = nil

-- Factories ---------------------------------------------------------------------------------

function UI.Create(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(radius: number?)
	return UI.Create("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function UI.Round()
	return UI.Create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

-- kept for compatibility: a barely visible inner highlight instead of a border
function UI.Stroke(_color: Color3?, _thickness: number?)
	return UI.Create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Transparency = 0.6,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.Gradient(top: Color3, bottom: Color3, rotation: number?)
	return UI.Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UI.Padding(px: number)
	local u = UDim.new(0, px)
	return UI.Create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.List(padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return UI.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Soft drop shadow behind a frame (9-sliced blurred rounded rect)
function UI.Shadow(parent: GuiObject, spread: number?, transparency: number?)
	spread = spread or 18
	return UI.Create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = Assets.Icons.Shadow,
		ImageColor3 = Color3.fromRGB(60, 35, 10),
		ImageTransparency = transparency or 0.55,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(80, 80, 176, 176),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 5),
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		ZIndex = math.max(0, parent.ZIndex - 1),
		Parent = parent,
	})
end

function UI.Label(props)
	props = props or {}
	local maxSize = props.MaxTextSize or 24
	props.MaxTextSize = nil
	local label = UI.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" then
			label[key] = value
		end
	end
	UI.Create("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

function UI.Icon(name: string, props)
	props = props or {}
	local image = UI.Create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets.Icons[name] or name,
		ScaleType = Enum.ScaleType.Fit,
	})
	for key, value in props do
		if key ~= "Parent" then
			image[key] = value
		end
	end
	if props.Parent then
		image.Parent = props.Parent
	end
	return image
end

-- Glass card: semi-transparent cream with a soft vertical gradient and shadow
function UI.Glass(props)
	props = props or {}
	local frame = UI.Create(props.ClassName or "Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = props.Transparency or 0.08,
	})
	for key, value in props do
		if key ~= "Parent" and key ~= "ClassName" and key ~= "Transparency" and key ~= "Radius" and key ~= "Top" and key ~= "Bottom" and key ~= "Shadow" then
			frame[key] = value
		end
	end
	UI.Corner(props.Radius or 18).Parent = frame
	UI.Gradient(props.Top or Color3.fromRGB(255, 253, 247), props.Bottom or Color3.fromRGB(252, 238, 210)).Parent = frame
	if props.Parent then
		frame.Parent = props.Parent
	end
	if props.Shadow and frame.Parent then
		-- sibling behind the card (a child would draw on top of the card's background)
		local shadow = UI.Create("ImageLabel", {
			Name = frame.Name .. "Shadow",
			BackgroundTransparency = 1,
			Image = Assets.Icons.Shadow,
			ImageColor3 = Color3.fromRGB(60, 35, 10),
			ImageTransparency = 0.6,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(80, 80, 176, 176),
			AnchorPoint = frame.AnchorPoint,
			Position = frame.Position + UDim2.fromOffset(0, 5),
			Size = frame.Size + UDim2.fromOffset(32, 32),
			ZIndex = math.max(0, frame.ZIndex - 1),
			Parent = frame.Parent,
		})
		if frame.AnchorPoint == Vector2.zero then
			shadow.Position = frame.Position + UDim2.fromOffset(-16, -11)
		end
		frame:GetPropertyChangedSignal("Visible"):Connect(function()
			shadow.Visible = frame.Visible
		end)
	end
	return frame
end

-- Pill button with gradient fill; optional icon on the left
function UI.Button(props, onClick)
	props = props or {}
	local maxSize = props.MaxTextSize or 22
	local icon = props.Icon
	local color = props.BackgroundColor3 or UI.Colors.Honey
	props.MaxTextSize = nil
	props.Icon = nil
	local button = UI.Create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = UI.Font,
		TextColor3 = UI.Colors.White,
		TextStrokeTransparency = 1,
		TextScaled = true,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" and key ~= "BackgroundColor3" then
			button[key] = value
		end
	end
	UI.Round().Parent = button
	-- outlined label stays readable on light gradients
	UI.Create("UIStroke", {
		Name = "TextOutline",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = color:Lerp(Color3.fromRGB(90, 45, 10), 0.75),
		Thickness = 2,
		Transparency = 0.1,
		Parent = button,
	})
	local light = color:Lerp(Color3.new(1, 1, 1), 0.28)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.08)
	UI.Gradient(light, dark).Parent = button
	UI.Create("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = button })
	UI.Create("UIPadding", {
		PaddingLeft = UDim.new(0, icon and 40 or 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0.12, 0),
		PaddingBottom = UDim.new(0.12, 0),
		Parent = button,
	})
	if icon then
		UI.Icon(icon, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -32, 0.5, 0),
			Size = UDim2.new(0, 28, 0, 28),
			Parent = button,
		})
	end
	Juice.Bind(button)
	if onClick then
		button.Activated:Connect(onClick)
	end
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function UI.SetButtonColor(button: GuiButton, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.28), color:Lerp(Color3.new(0, 0, 0), 0.08))
	end
	local outline = button:FindFirstChild("TextOutline")
	if outline then
		outline.Color = color:Lerp(Color3.fromRGB(90, 45, 10), 0.75)
	end
end

-- Round icon button (sidebar, close buttons) with an optional hover tooltip
function UI.IconButton(iconName: string, size: number, props, onClick)
	props = props or {}
	local tooltip = props.Tooltip
	props.Tooltip = nil
	local bg = props.BackgroundColor3 or Color3.new(1, 1, 1)
	props.BackgroundColor3 = nil
	local button = UI.Create("ImageButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = props.BackgroundTransparency or 0.05,
		Size = UDim2.fromOffset(size, size),
		Image = "",
	})
	for key, value in props do
		if key ~= "Parent" then
			button[key] = value
		end
	end
	UI.Round().Parent = button
	UI.Gradient(bg:Lerp(Color3.new(1, 1, 1), 0.35), bg:Lerp(Color3.fromRGB(250, 225, 180), 0.25)).Parent = button
	UI.Icon(iconName, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		Parent = button,
	})
	if tooltip then
		local tip = UI.Create("TextLabel", {
			Name = "Tooltip",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 12, 0.5, 0),
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = UI.Colors.Ink,
			BackgroundTransparency = 0.25,
			Font = UI.Body,
			TextSize = 15,
			TextColor3 = UI.Colors.White,
			Text = tooltip,
			Visible = false,
			ZIndex = 20,
			Parent = button,
		}, { UI.Round(), UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
		button.MouseEnter:Connect(function()
			tip.Visible = true
			tip.TextTransparency = 1
			tip.BackgroundTransparency = 1
			TweenService:Create(tip, TweenInfo.new(0.15), { TextTransparency = 0, BackgroundTransparency = 0.25 }):Play()
		end)
		button.MouseLeave:Connect(function()
			tip.Visible = false
		end)
	end
	Juice.Bind(button, { Rotate = 4 })
	if onClick then
		button.Activated:Connect(onClick)
	end
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function UI.Bar(props)
	local back = UI.Create("Frame", {
		BackgroundColor3 = props.Back or Color3.fromRGB(60, 40, 20),
		BackgroundTransparency = props.BackTransparency or 0.45,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = props.Parent,
	}, { UI.Round() })
	local fill = UI.Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		Parent = back,
	}, { UI.Round(), UI.Gradient((props.Color or UI.Colors.Honey):Lerp(Color3.new(1, 1, 1), 0.3), props.Color or UI.Colors.Honey) })
	local label = UI.Label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = UI.Colors.White,
		TextStrokeTransparency = 0.55,
		ZIndex = 3,
		MaxTextSize = props.MaxTextSize or 20,
		Parent = back,
	})
	return back, fill, label
end

-- Screen & panels ------------------------------------------------------------------------------

function UI:_screen()
	if self.Screen then
		return self.Screen
	end
	self.Screen = UI.Create("ScreenGui", {
		Name = "BeeTycoonUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- dim layer behind open panels
	self.Dim = UI.Create("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 25, 10),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 8,
		Parent = self.Screen,
	})
	return self.Screen
end

-- Creates a modal panel and returns its content frame
function UI:Panel(name: string, title: string, iconName: string?)
	local holder = UI.Create("Frame", {
		Name = "Panel_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.72, 0.76),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = self:_screen(),
	}, { UI.Create("UISizeConstraint", { MaxSize = Vector2.new(1000, 680), MinSize = Vector2.new(340, 280) }) })
	UI.Shadow(holder, 28, 0.45)
	local frame = UI.Create("CanvasGroup", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 10,
		Parent = holder,
	}, { UI.Corner(26), UI.Gradient(Color3.fromRGB(255, 252, 245), Color3.fromRGB(251, 236, 206)) })
	local header = UI.Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 10,
		Parent = frame,
	}, { UI.Gradient(UI.Colors.HoneyLight, UI.Colors.Honey) })
	if iconName then
		UI.Icon(iconName, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(48, 48), ZIndex = 11, Parent = header })
	end
	UI.Label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -150, 1, -16),
		Position = UDim2.fromOffset(iconName and 74 or 20, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.White,
		TextStrokeColor3 = Color3.fromRGB(150, 85, 15),
		TextStrokeTransparency = 0.5,
		MaxTextSize = 34,
		ZIndex = 11,
		Parent = header,
	})
	local close = UI.IconButton("Close", 44, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		BackgroundColor3 = UI.Colors.Bad,
		BackgroundTransparency = 0,
		ZIndex = 12,
		Parent = header,
	}, function()
		self:Close()
	end)
	close.Icon.ZIndex = 13
	local content = UI.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 76),
		Size = UDim2.new(1, -36, 1, -92),
		ZIndex = 10,
		Parent = frame,
	})
	self.Panels[name] = { Frame = holder, Body = frame, Content = content, Title = header.Title, OnOpen = nil }
	return content, self.Panels[name]
end

function UI:Open(name: string, ...)
	local panel = self.Panels[name]
	if not panel then
		return
	end
	if self.Current and self.Current ~= name then
		local old = self.Panels[self.Current]
		old.Frame.Visible = false
		if old.OnClose then
			task.spawn(old.OnClose)
		end
	end
	self.Current = name
	self.Dim.Visible = true
	TweenService:Create(self.Dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.65 }):Play()
	panel.Frame.Visible = true
	Juice.Open(panel.Frame)
	if panel.Body:IsA("CanvasGroup") then
		panel.Body.GroupTransparency = 1
		TweenService:Create(panel.Body, TweenInfo.new(0.18), { GroupTransparency = 0 }):Play()
	end
	if panel.OnOpen then
		task.spawn(panel.OnOpen, ...)
	end
end

function UI:Close()
	local name = self.Current
	if not name then
		return
	end
	local panel = self.Panels[name]
	self.Current = nil
	TweenService:Create(self.Dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	task.delay(0.2, function()
		if not self.Current then
			self.Dim.Visible = false
		end
	end)
	Juice.Close(panel.Frame)
	if panel.OnClose then
		task.spawn(panel.OnClose)
	end
end

function UI:Toggle(name: string, ...)
	if self.Current == name then
		self:Close()
	else
		self:Open(name, ...)
	end
end

-- Messages go to the NotificationCenter (top-center, borderless); set in its Start
function UI:Toast(text: string, kind: string?)
	if UI.Notify then
		UI.Notify(text, kind)
	end
end

-- Warm the content cache so tools, backpacks, bees and icons show their textures immediately
-- on spawn or when equipment changes (no grey, untextured first frames)
local function preload()
	local ContentProvider = game:GetService("ContentProvider")
	local list = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Collectors", "Backpacks", "Boots", "Bees", "Eggs", "Monsters" } do
		local folder = assets and assets:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	for _, id in Assets.Icons do
		table.insert(list, id)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, list)
end

function UI:Init()
	self:_screen()
	task.spawn(preload)
end

return UI
