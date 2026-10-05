--[[
	Nests
	The physical Golden Nests: floating price cards above each nest, a slowly turning
	display egg inside, and the "Hatch" prompt that sends NestHatch to the server.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Nests = {}

local C
local UI
local nests = {} -- [index] = { Model, Prompt, Price, Owned, Egg, EggBase }

function Nests:Init(controllers)
	C = controllers
	UI = C.UI
end

local function price(eggId: string): number
	local egg = Config.Eggs[eggId]
	if egg.BasePrice then
		return math.floor(egg.BasePrice * egg.Growth ^ C.State:BeeCount())
	end
	return egg.HoneyPrice
end

function Nests:_card(model: Model, eggId: string)
	local egg = Config.Eggs[eggId]
	local anchor = model:FindFirstChild("CardAnchor") or model.PrimaryPart
	local gui = Instance.new("BillboardGui")
	gui.Name = "NestCard"
	-- sized in studs so the card shrinks with distance instead of covering the HUD up close
	gui.Size = UDim2.fromScale(9, 4.1)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.Parent = anchor
	local card = UI.Glass({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 110),
		Transparency = 0.12,
		Radius = 24,
		Parent = gui,
	})
	local fit = Instance.new("UIScale")
	fit.Parent = card
	local function refit()
		fit.Scale = math.max(gui.AbsoluteSize.X / 240, 0.01)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()
	UI.Icon("Egg", { Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(70, 70), ImageColor3 = egg.Color:Lerp(Color3.new(1, 1, 1), 0.2), Parent = card })
	UI.Label({ Text = egg.Name, Position = UDim2.fromOffset(88, 10), Size = UDim2.new(1, -96, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = card })
	UI.Icon("Honey", { Position = UDim2.fromOffset(86, 52), Size = UDim2.fromOffset(34, 34), Parent = card })
	local priceLabel = UI.Label({ Position = UDim2.fromOffset(124, 54), Size = UDim2.new(1, -132, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = card })
	local owned = UI.Label({ Font = UI.Body, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(1, -20, 0, 18), TextColor3 = UI.Colors.Good, MaxTextSize = 14, Parent = card })
	return priceLabel, owned
end

function Nests:_refresh()
	local data = C.State.Data
	if not data then
		return
	end
	for _, entry in nests do
		local eggId = entry.EggId
		local cost = price(eggId)
		local have = data.Eggs[eggId] or 0
		entry.Price.Text = Format.Short(cost)
		entry.Price.TextColor3 = (have > 0 or data.Honey >= cost) and UI.Colors.Text or UI.Colors.Bad
		entry.Owned.Text = have > 0 and `You own {have} - hatch free!` or ""
		if entry.Prompt then
			entry.Prompt.ObjectText = Config.Eggs[eggId].Name
			entry.Prompt.ActionText = have > 0 and "Hatch (owned)" or `Hatch for {Format.Short(cost)}`
		end
	end
end

function Nests:Start()
	local map = Workspace:WaitForChild("Map", 30)
	local folder = map and map:WaitForChild("Nests", 10)
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		local index = model:GetAttribute("NestIndex")
		local eggId = model:GetAttribute("Egg")
		if index and eggId then
			local priceLabel, owned = self:_card(model, eggId)
			local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
			local display = model:FindFirstChild("DisplayEgg")
			nests[index] = {
				Model = model,
				EggId = eggId,
				Prompt = prompt,
				Price = priceLabel,
				Owned = owned,
				Egg = display,
				EggBase = display and display:GetPivot(),
			}
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local index = prompt:GetAttribute("NestIndex")
		if index then
			Net.Event("NestHatch"):FireServer(index)
		end
	end)

	C.State:OnChange({ "Honey", "Eggs", "Bees" }, function()
		self:_refresh()
	end)

	-- display eggs slowly turn and bob
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for index, entry in nests do
			if entry.Egg and entry.EggBase then
				entry.Egg:PivotTo(entry.EggBase * CFrame.new(0, math.sin(t * 1.5 + index) * 0.25, 0) * CFrame.Angles(0, t * 0.6 + index, math.sin(t * 2 + index) * 0.05))
			end
		end
	end)
end

return Nests
