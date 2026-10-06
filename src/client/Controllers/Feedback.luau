--[[
	Feedback
	In-game bug reporter and review form: pick Bug or Review, rate 1-5 stars (reviews), type up
	to Config.Feedback.MaxLength characters and send. Validation and storage are server-side
	(FeedbackService); the panel shows a live character counter and the server's answer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ShopJuicer = require(script.Parent.ShopJuicer)

local Feedback = {}

local C
local UI
local Juice
local kind = "Bug"
local rating = 5

function Feedback:Init(controllers)
	C = controllers
	UI = C.UI
	Juice = UI.Juice
end

function Feedback:Start()
	local content = UI:Panel("Feedback", "Feedback", "Speaker")
	local column = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content }, { UI.List(12) })
	column.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	column.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- kind toggle
	local toggles = UI.Create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = column }, { UI.List(12, true, Enum.HorizontalAlignment.Center) })
	local kindButtons = {}
	local starsRow
	local function paintKinds()
		for id, button in kindButtons do
			UI.SetButtonColor(button, id == kind and (id == "Bug" and UI.Colors.Bad or UI.Colors.Good) or Color3.fromRGB(215, 200, 175))
		end
		starsRow.Visible = kind == "Review"
	end
	for i, info in { { Id = "Bug", Text = "BUG REPORT", Icon = "Close" }, { Id = "Review", Text = "REVIEW", Icon = "Star" } } do
		kindButtons[info.Id] = UI.Button({ Text = info.Text, Icon = info.Icon, LayoutOrder = i, Size = UDim2.fromOffset(210, 44), MaxTextSize = 18, Parent = toggles }, function()
			kind = info.Id
			paintKinds()
		end)
	end

	-- star rating (reviews only)
	starsRow = UI.Create("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = column }, { UI.List(8, true, Enum.HorizontalAlignment.Center) })
	local stars = {}
	local function paintStars()
		for i, star in stars do
			star.ImageTransparency = i <= rating and 0 or 0.7
			star.ImageColor3 = i <= rating and Color3.new(1, 1, 1) or Color3.fromRGB(120, 110, 100)
		end
	end
	for i = 1, 5 do
		local star = UI.Create("ImageButton", { LayoutOrder = i, Size = UDim2.fromOffset(42, 42), BackgroundTransparency = 1, Image = UI.Icons.Star, Parent = starsRow })
		Juice.Bind(star, { Hover = 1.15 })
		star.Activated:Connect(function()
			rating = i
			paintStars()
			Juice.Punch(star, 0.3)
		end)
		stars[i] = star
	end
	paintStars()

	-- text box
	local box = UI.Glass({ LayoutOrder = 3, Size = UDim2.new(1, -20, 0, 170), Transparency = 0.1, Radius = 18, Parent = column })
	local input = UI.Create("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 1, -36),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = UI.Body,
		TextSize = 17,
		TextColor3 = UI.Colors.Text,
		PlaceholderText = "What happened? What would make the game better?",
		PlaceholderColor3 = UI.Colors.Muted,
		Text = "",
		Parent = box,
	})
	local counter = UI.Label({ Font = UI.Body, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -6), Size = UDim2.fromOffset(120, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Colors.Muted, MaxTextSize = 14, Text = `0 / {Config.Feedback.MaxLength}`, Parent = box })
	input:GetPropertyChangedSignal("Text"):Connect(function()
		if #input.Text > Config.Feedback.MaxLength then
			input.Text = input.Text:sub(1, Config.Feedback.MaxLength)
		end
		counter.Text = `{#input.Text} / {Config.Feedback.MaxLength}`
		counter.TextColor3 = #input.Text >= Config.Feedback.MinLength and UI.Colors.Good or UI.Colors.Muted
	end)

	-- send
	local send
	send = UI.Button({ LayoutOrder = 4, Text = "SEND", Icon = "Check", BackgroundColor3 = UI.Colors.Honey, Size = UDim2.fromOffset(240, 50), MaxTextSize = 22, Parent = column }, function()
		local ok, success, message = pcall(function()
			return Net.Function("SubmitFeedback"):InvokeServer(kind, rating, input.Text)
		end)
		if not ok then
			return
		end
		C.NotificationCenter:Push(message or "", success and "good" or "bad")
		if success then
			input.Text = ""
			ShopJuicer.Burst(send, 12)
			C.Sound:Play("Purchase")
		else
			Juice.Shake(box, 5)
		end
	end)
	ShopJuicer.Shine(send, { Period = 0.8, Pause = 2.4 })
	paintKinds()
end

return Feedback
