--[[
	UI
	Small UI kit: palette, element factories, modal panels and toasts.
	Every screen in the game is built from these helpers so the look stays consistent.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local UI = {}

UI.Colors = {
	Honey = Color3.fromRGB(255, 194, 46),
	HoneyDark = Color3.fromRGB(214, 136, 20),
	Brown = Color3.fromRGB(72, 45, 22),
	Cream = Color3.fromRGB(255, 249, 232),
	CreamDark = Color3.fromRGB(246, 230, 196),
	Text = Color3.fromRGB(64, 40, 20),
	Muted = Color3.fromRGB(140, 108, 76),
	Good = Color3.fromRGB(84, 190, 90),
	Bad = Color3.fromRGB(228, 78, 68),
	Blue = Color3.fromRGB(66, 146, 236),
	Purple = Color3.fromRGB(150, 90, 230),
	White = Color3.new(1, 1, 1),
}

UI.Font = Enum.Font.FredokaOne
UI.Body = Enum.Font.GothamBold

UI.Panels = {}
UI.Current = nil

-- Factories ------------------------------------------------------------------------------

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
	return UI.Create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.Stroke(color: Color3?, thickness: number?)
	return UI.Create("UIStroke", {
		Color = color or UI.Colors.Brown,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.Padding(px: number)
	local u = UDim.new(0, px)
	return UI.Create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.List(padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return UI.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
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

function UI.Button(props, onClick)
	props = props or {}
	local color = props.BackgroundColor3 or UI.Colors.Honey
	local maxSize = props.MaxTextSize or 22
	props.MaxTextSize = nil
	local button = UI.Create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = UI.Font,
		TextColor3 = UI.Colors.Brown,
		TextScaled = true,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" then
			button[key] = value
		end
	end
	UI.Corner(10).Parent = button
	UI.Stroke(UI.Colors.Brown, 2).Parent = button
	UI.Create("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = button })
	UI.Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = button })
	local scale = UI.Create("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
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
		BackgroundColor3 = props.Back or UI.Colors.Brown,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = props.Parent,
	}, { UI.Corner(props.Radius or 10) })
	local fill = UI.Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or UI.Colors.Honey,
		Size = UDim2.fromScale(0, 1),
		Parent = back,
	}, { UI.Corner(props.Radius or 10) })
	local label = UI.Label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = UI.Colors.White,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
		MaxTextSize = props.MaxTextSize or 20,
		Parent = back,
	})
	return back, fill, label
end

-- Screen & panels -----------------------------------------------------------------------------

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
	return self.Screen
end

-- Creates a modal panel and returns its content frame
function UI:Panel(name: string, title: string)
	local frame = UI.Create("Frame", {
		Name = "Panel_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.72, 0.76),
		BackgroundColor3 = UI.Colors.Cream,
		Visible = false,
		ZIndex = 10,
		Parent = self:_screen(),
	}, {
		UI.Corner(18),
		UI.Stroke(UI.Colors.Brown, 4),
		UI.Create("UISizeConstraint", { MaxSize = Vector2.new(980, 660), MinSize = Vector2.new(320, 260) }),
	})
	local header = UI.Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = UI.Colors.Honey,
		ZIndex = 10,
		Parent = frame,
	}, { UI.Corner(18) })
	UI.Label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -120, 1, -12),
		Position = UDim2.fromOffset(18, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Brown,
		MaxTextSize = 32,
		ZIndex = 11,
		Parent = header,
	})
	UI.Button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -48, 0, 6),
		BackgroundColor3 = UI.Colors.Bad,
		TextColor3 = UI.Colors.White,
		ZIndex = 12,
		Parent = header,
	}, function()
		self:Close()
	end)
	local content = UI.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -76),
		ZIndex = 10,
		Parent = frame,
	})
	self.Panels[name] = { Frame = frame, Content = content, Title = header.Title, OnOpen = nil }
	return content, self.Panels[name]
end

function UI:Open(name: string, ...)
	local panel = self.Panels[name]
	if not panel then
		return
	end
	if self.Current and self.Current ~= name then
		self.Panels[self.Current].Frame.Visible = false
	end
	self.Current = name
	panel.Frame.Visible = true
	local scale = panel.Frame:FindFirstChildOfClass("UIScale") or UI.Create("UIScale", { Parent = panel.Frame })
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if panel.OnOpen then
		task.spawn(panel.OnOpen, ...)
	end
end

function UI:Close()
	if self.Current then
		local panel = self.Panels[self.Current]
		panel.Frame.Visible = false
		if panel.OnClose then
			task.spawn(panel.OnClose)
		end
	end
	self.Current = nil
end

function UI:Toggle(name: string, ...)
	if self.Current == name then
		self:Close()
	else
		self:Open(name, ...)
	end
end

-- Toasts -----------------------------------------------------------------------------------------

local TOAST_COLORS = {
	info = UI.Colors.Cream,
	good = Color3.fromRGB(214, 246, 200),
	bad = Color3.fromRGB(255, 214, 206),
	rare = Color3.fromRGB(255, 228, 140),
}

function UI:Toast(text: string, kind: string?)
	local screen = self:_screen()
	local holder = screen:FindFirstChild("Toasts")
	if not holder then
		holder = UI.Create("Frame", {
			Name = "Toasts",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 76),
			Size = UDim2.fromOffset(340, 400),
			BackgroundTransparency = 1,
			Parent = screen,
		}, { UI.List(6, false, Enum.HorizontalAlignment.Right) })
	end
	local toast = UI.Create("Frame", {
		Size = UDim2.fromOffset(330, 46),
		BackgroundColor3 = TOAST_COLORS[kind or "info"] or UI.Colors.Cream,
		BackgroundTransparency = 0.05,
		Parent = holder,
	}, { UI.Corner(12), UI.Stroke(kind == "rare" and UI.Colors.HoneyDark or UI.Colors.Brown, 2), UI.Padding(6) })
	UI.Label({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		Font = UI.Body,
		MaxTextSize = 16,
		Parent = toast,
	})
	local children = holder:GetChildren()
	local frames = {}
	for _, child in children do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 5 then
		frames[1]:Destroy()
	end
	task.delay(kind == "rare" and 7 or 4.5, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			toast:Destroy()
		end
	end)
end

function UI:Init()
	self:_screen()
end

return UI
