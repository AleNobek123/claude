--[[
	Tutorial
	Live, state-driven guidance. Every 0.25 s the current objective is re-picked from the player's
	state (in a field? backpack full? converting? owns an egg?), so the guide always points at the
	next useful thing even when the player wanders off-script:
	  Field -> Collect -> Convert (when the bag is full) -> Hatch (after the first honey)
	Visuals: a bouncing 3D arrow over the goal, bouncing chevron arrows along the ground route,
	a 2D arrow at the screen edge when the goal is off-screen, and a floating hint above the head.
	Milestones are saved on the server (TutorialStep): 3 = first honey, 5 = first hatch (done).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local Tutorial = {}

local C
local UI
local folder: Folder
local arrow: Model?
local chevrons = {} -- { Left, Right }
local hint: BillboardGui?
local hintText: string? = nil
local edgeArrow: Frame
local savedStep = 1
local honeyAtStart = 0
local beesAtStart = 0
local objective = nil -- { Id, Target, Text, Trail }
local temporary: { Until: number, Position: Vector3 }? = nil

local SPACING = 6
local MAX_CHEVRONS = 64
local GOLD = Color3.fromRGB(255, 200, 40)
local MILESTONE_HONEY = 3
local MILESTONE_DONE = #Config.Tutorial + 1

function Tutorial:Init(controllers)
	C = controllers
	UI = C.UI
end

-- World lookups -------------------------------------------------------------------------------------

local function sunflower()
	return Config.FieldById.Sunflower
end

local function hivePad(): Vector3?
	local index = player:GetAttribute("HiveIndex")
	local map = Workspace:FindFirstChild("Map")
	local hive = index and map and map.Hives:FindFirstChild("Hive_" .. index)
	local pad = hive and hive:FindFirstChild("Pad")
	return pad and pad.Position
end

local function nestPosition(index: number): Vector3
	local map = Workspace:FindFirstChild("Map")
	local nest = map and map:FindFirstChild("Nests") and map.Nests:FindFirstChild("Nest_" .. index)
	return nest and nest:GetPivot().Position or Config.Nests[index].Position
end

local function inField(position: Vector3)
	for _, def in Config.Fields do
		local half = def.Tiles * Config.Tiles.Size / 2 + 1
		local d = position - def.Center
		if math.abs(d.X) <= half and math.abs(d.Z) <= half and d.Y > -5 and d.Y < 30 then
			return def
		end
	end
	return nil
end

local function eggPrice(eggId: string): number
	local egg = Config.Eggs[eggId]
	if egg.BasePrice then
		return math.floor(egg.BasePrice * egg.Growth ^ C.State:BeeCount())
	end
	return egg.HoneyPrice or math.huge
end

-- Objective picker ----------------------------------------------------------------------------------

function Tutorial:_pick(root: BasePart)
	local data = C.State.Data
	if not data or savedStep >= MILESTONE_DONE then
		return nil
	end
	local pad = hivePad()
	local capacity = C.State:Capacity()
	local pollen = math.floor(data.Pollen or 0)
	local nearPad = pad and (root.Position - pad).Magnitude <= Config.Convert.Range

	if player:GetAttribute("Converting") then
		return { Id = "Converting", Target = pad, Text = "Making honey... stay on your pad!", Trail = false }
	end
	if pad and (pollen >= capacity * 0.98 or (pollen > 0 and nearPad)) then
		return { Id = "Convert", Target = pad, Text = nearPad and "Press MAKE HONEY!" or Config.Tutorial[3].Text, Trail = true }
	end
	if savedStep >= MILESTONE_HONEY then
		-- first honey made: hatch an owned egg, or buy one at the nest once honey allows
		for index, nest in Config.Nests do
			if (data.Eggs[nest.Egg] or 0) > 0 then
				return { Id = "Hatch", Target = nestPosition(index), Text = Config.Tutorial[4].Text, Trail = true }
			end
		end
		if (data.Honey or 0) >= eggPrice("Basic") then
			return { Id = "Hatch", Target = nestPosition(1), Text = "Buy a Basic Egg at the Golden Nest", Trail = true }
		end
	end
	local field = inField(root.Position)
	if not field then
		return { Id = "Field", Target = sunflower().Center, Text = Config.Tutorial[1].Text, Trail = true }
	end
	return { Id = "Collect", Target = field.Center, Text = `{Config.Tutorial[2].Text}  {pollen}/{capacity}`, Trail = false }
end

function Tutorial:_save(step: number)
	if step <= savedStep then
		return
	end
	savedStep = step
	Net.Event("TutorialStep"):FireServer(step)
	C.Sound:Play("LevelUp", { Volume = 0.7 })
end

function Tutorial:_milestones()
	local data = C.State.Data
	if not data then
		return
	end
	if savedStep < MILESTONE_HONEY and (data.TotalHoney or 0) - honeyAtStart >= 50 then
		self:_save(MILESTONE_HONEY)
		C.NotificationCenter:Push("Nice! Your first honey.", "honey")
	end
	if savedStep >= MILESTONE_HONEY and savedStep < MILESTONE_DONE and C.State:BeeCount() > beesAtStart then
		beesAtStart = math.huge
		-- wait for the hatch cutscene before celebrating
		task.delay(4, function()
			self:_save(MILESTONE_DONE)
			C.NotificationCenter:Push("Tutorial complete! Go build your honey empire.", "rare")
			self:_hint(nil)
			self:_clear()
		end)
	end
end

-- Visuals ---------------------------------------------------------------------------------------------

function Tutorial:_arrow(): Model
	if arrow then
		return arrow
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Raw") and assets.Raw:FindFirstChild("Arrow3D")
	if template then
		arrow = template:Clone()
	else
		arrow = Instance.new("Model")
		local head = Instance.new("WedgePart")
		head.Name = "Head"
		head.Size = Vector3.new(1, 3, 3)
		head.Parent = arrow
		arrow.PrimaryPart = head
	end
	for _, part in arrow:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = GOLD
		end
	end
	arrow:ScaleTo(arrow:GetScale() * 1.8)
	arrow.Parent = folder
	return arrow
end

-- A chevron ">" lying on the ground: two neon bars meeting at the tip
function Tutorial:_chevron(i: number)
	local c = chevrons[i]
	if not c then
		local function bar()
			local part = Instance.new("Part")
			part.Size = Vector3.new(0.45, 0.2, 2.2)
			part.Material = Enum.Material.Neon
			part.Color = GOLD
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Parent = folder
			return part
		end
		c = { Left = bar(), Right = bar() }
		chevrons[i] = c
	end
	return c
end

function Tutorial:_hint(text: string?)
	if text == hintText and hint and hint.Parent then
		return
	end
	-- same objective with new numbers (pollen counter): just update the label
	if text and hint and hint.Parent and hintText and text:match("^[^%d]+") == hintText:match("^[^%d]+") then
		hintText = text
		local label = hint:FindFirstChild("Text", true)
		if label then
			label.Text = text
		end
		return
	end
	hintText = text
	if hint then
		local old = hint
		hint = nil
		for _, obj in old:GetDescendants() do
			if obj:IsA("TextLabel") then
				TweenService:Create(obj, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			elseif obj:IsA("ImageLabel") then
				TweenService:Create(obj, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.3, function()
			old:Destroy()
		end)
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not text or not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TutorialHint"
	gui.Size = UDim2.fromOffset(440, 50)
	gui.StudsOffset = Vector3.new(0, 4.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local row = UI.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui }, { UI.List(8, true, Enum.HorizontalAlignment.Center) })
	local icon = UI.Icon("Bee", { LayoutOrder = 1, Size = UDim2.fromOffset(40, 40), ImageTransparency = 1, Parent = row })
	local label = UI.Create("TextLabel", {
		Name = "Text",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		Text = text,
		Parent = row,
	})
	local stroke = UI.Create("UIStroke", { Color = Color3.fromRGB(90, 46, 6), Thickness = 3, Transparency = 1, Parent = label })
	TweenService:Create(icon, TweenInfo.new(0.35), { ImageTransparency = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 0 }):Play()
	UI.Juice.Float(row, 4, 2)
	hint = gui
end

function Tutorial:_hideChevrons()
	for _, c in chevrons do
		c.Left.Parent = nil
		c.Right.Parent = nil
	end
end

function Tutorial:_clear()
	if arrow then
		arrow.Parent = nil
	end
	self:_hideChevrons()
	edgeArrow.Visible = false
end

-- 2D ">" arrow from two rounded, outlined bars (no image asset needed); rotated to point at the goal
local function buildEdgeArrow(parent: Instance): Frame
	local holder = UI.Create("Frame", {
		Name = "TutorialEdgeArrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(70, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	local length, tip = 40, Vector2.new(56, 35)
	for _, angle in { 40, -40 } do
		-- GUI rotation pivots on the centre, so place each centre so its right end sits on the tip
		local a = math.rad(angle)
		local center = tip - Vector2.new(math.cos(a), math.sin(a)) * (length / 2)
		UI.Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(length, 15),
			Rotation = angle,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = holder,
		}, { UI.Round(), UI.Gradient(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 160, 20)), UI.Create("UIStroke", { Color = Color3.fromRGB(110, 50, 0), Thickness = 3 }) })
	end
	return holder
end

-- Ground route: follow the roads between the hive row and the plaza
local function route(from: Vector3, to: Vector3): { Vector3 }
	local points = { from }
	local function via(x: number, z: number)
		table.insert(points, Vector3.new(x, from.Y, z))
	end
	if from.Z < -55 and to.Z > -30 then
		if math.abs(from.X) > 20 then
			via(0, -78)
		end
		via(0, -18)
	elseif from.Z > -30 and to.Z < -55 then
		via(0, -18)
		if math.abs(to.X) > 20 then
			via(0, -78)
		end
	end
	table.insert(points, to)
	return points
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local trail = {} -- { Position, Direction }
local lastTrail = 0

function Tutorial:_updateTrail(from: Vector3, to: Vector3)
	local now = os.clock()
	if now - lastTrail > 0.2 then
		lastTrail = now
		table.clear(trail)
		local exclude = { folder }
		if player.Character then
			table.insert(exclude, player.Character)
		end
		rayParams.FilterDescendantsInstances = exclude
		local points = route(from, to)
		local carry = SPACING
		for k = 1, #points - 1 do
			local a, b = points[k], points[k + 1]
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local length = flat.Magnitude
			if length < 0.1 then
				continue
			end
			local dir = flat.Unit
			local d = carry
			while d <= length and #trail < MAX_CHEVRONS do
				local p = a + dir * d
				local hit = Workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), rayParams)
				table.insert(trail, { Position = Vector3.new(p.X, (hit and hit.Position.Y or from.Y - 3) + 0.4, p.Z), Direction = dir })
				d += SPACING
			end
			carry = d - length
		end
	end
	local parts, cframes = {}, {}
	local spread = math.rad(38)
	for i = 1, MAX_CHEVRONS do
		local c = self:_chevron(i)
		local entry = trail[i]
		if entry then
			c.Left.Parent = folder
			c.Right.Parent = folder
			-- a bounce wave runs along the chevrons towards the goal
			local wave = (math.sin(now * 7 - i * 0.7) + 1) / 2
			local at = entry.Position + Vector3.new(0, wave * 0.9, 0)
			local base = CFrame.lookAt(at, at + entry.Direction)
			table.insert(parts, c.Left)
			table.insert(cframes, base * CFrame.Angles(0, spread, 0) * CFrame.new(0, 0, 1))
			table.insert(parts, c.Right)
			table.insert(cframes, base * CFrame.Angles(0, -spread, 0) * CFrame.new(0, 0, 1))
			local transparency = 0.1 + (1 - wave) * 0.45
			c.Left.Transparency = transparency
			c.Right.Transparency = transparency
		else
			c.Left.Parent = nil
			c.Right.Parent = nil
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Screen-edge arrow pointing at an off-screen goal (bounces toward it)
function Tutorial:_updateEdgeArrow(goal: Vector3)
	local camera = Workspace.CurrentCamera
	local screenPos, onScreen = camera:WorldToViewportPoint(goal)
	if onScreen and screenPos.Z > 0 then
		edgeArrow.Visible = false
		return
	end
	local viewport = camera.ViewportSize
	local center = viewport / 2
	local dir = Vector2.new(screenPos.X, screenPos.Y) - center
	if screenPos.Z < 0 then
		dir = -dir
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, 1)
	end
	dir = dir.Unit
	local half = center - Vector2.new(80, 80)
	local reach = math.min(math.abs(half.X / (dir.X ~= 0 and dir.X or 1e-6)), math.abs(half.Y / (dir.Y ~= 0 and dir.Y or 1e-6)))
	local bounce = math.abs(math.sin(os.clock() * 5)) * 14
	local pos = center + dir * (reach + bounce - 14)
	edgeArrow.Visible = true
	edgeArrow.Position = UDim2.fromOffset(pos.X, pos.Y)
	edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
end

-- Public: show a temporary route to a nest (Eggs panel "Find nest")
function Tutorial:Guide(kind: string, index: number)
	if kind == "Nest" then
		temporary = { Until = os.clock() + 25, Position = nestPosition(index) }
	end
end

function Tutorial:Start()
	folder = Instance.new("Folder")
	folder.Name = "TutorialGuide"
	folder.Parent = Workspace
	local gui = UI.Create("ScreenGui", { Name = "TutorialArrows", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
	edgeArrow = buildEdgeArrow(gui)

	while not C.State.Loaded do
		task.wait(0.2)
	end
	local saved = C.State.Data.Tutorial
	savedStep = saved and saved.Step or 1
	honeyAtStart = C.State.Data.TotalHoney or 0
	beesAtStart = C.State:BeeCount()

	Net.Event("HatchResult").OnClientEvent:Connect(function()
		if savedStep >= MILESTONE_HONEY and savedStep < MILESTONE_DONE then
			beesAtStart = -1 -- the next milestone check completes the tutorial
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		acc += dt
		if acc >= 0.25 then
			acc = 0
			self:_milestones()
			objective = self:_pick(root)
			self:_hint(objective and objective.Text or nil)
		end
		local goal, showTrail
		if temporary and os.clock() < temporary.Until then
			goal, showTrail = temporary.Position, true
			if (root.Position - goal).Magnitude < 16 then
				temporary = nil
			end
		elseif objective then
			goal, showTrail = objective.Target, objective.Trail
		end
		if not goal then
			self:_clear()
			return
		end
		local a = self:_arrow()
		a.Parent = folder
		local t = os.clock()
		-- cartoony bounce: snappy at the bottom, floaty at the top
		local bounce = math.abs(math.sin(t * 3.2)) ^ 0.6 * 3
		a:PivotTo(CFrame.new(goal + Vector3.new(0, 11 + bounce, 0)) * CFrame.Angles(0, t * 1.8, 0))
		local near = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(goal.X, 0, goal.Z)).Magnitude < 18
		if near or not showTrail then
			self:_hideChevrons()
		else
			self:_updateTrail(root.Position, goal)
		end
		self:_updateEdgeArrow(goal + Vector3.new(0, 6, 0))
	end)
end

return Tutorial
