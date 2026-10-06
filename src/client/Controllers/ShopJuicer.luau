--[[
	ShopJuicer
	Attention effects for Robux tiles and promo banners:
	  Shine(gui, opts)    looping light sweep (UIGradient offset animation, clipped to the tile)
	  Rays(gui, opts)     rotating glow rays behind the tile
	  Sparkle(gui, opts)  stars that twinkle around the tile at a steady rate
	  Burst(gui, count)   one-shot star burst (purchase, click)
	  NeonBorder(gui)     animated neon outline (rotating rainbow/gold gradient on a UIStroke)
	  ValueTag(gui, text) flashing golden ribbon ("BEST VALUE!", "INFINITE STACKING!")
	  Juice(gui, opts)    all of the above; returns a cleanup function

	One RenderStepped loop drives every effect; entries remove themselves when their gui is gone.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Assets"))

local ShopJuicer = {}

local shines = {} -- { Gradient, Period, Pause, Phase, Gui }
local rays = {} -- { Holder, Speed, Gui, Glow }
local sparkles = {} -- { Gui, Rate, Color, Acc }
local borders = {} -- { Gradient, Speed, Gui }
local tags = {} -- { Label, Scale, Gui, Phase }
local running = false

local SHINE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 1),
	NumberSequenceKeypoint.new(0.47, 0.55),
	NumberSequenceKeypoint.new(0.5, 0.25),
	NumberSequenceKeypoint.new(0.53, 0.55),
	NumberSequenceKeypoint.new(0.6, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function alive(gui: Instance): boolean
	return gui.Parent ~= nil
end

local function spawnStar(gui: GuiObject, color: Color3, big: boolean?)
	local size = big and math.random(22, 34) or math.random(12, 22)
	local star = Instance.new("ImageLabel")
	star.Name = "Star"
	star.BackgroundTransparency = 1
	star.Image = Assets.Icons.Sparkles
	star.ImageColor3 = color
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.new(math.random(), 0, math.random(), 0)
	star.Size = UDim2.fromOffset(0, 0)
	star.Rotation = math.random(0, 90)
	star.ZIndex = gui.ZIndex + 3
	star.Parent = gui
	local life = big and 0.7 or 0.9
	local grow = TweenService:Create(star, TweenInfo.new(life * 0.4, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(size, size), Rotation = star.Rotation + 45 })
	grow:Play()
	grow.Completed:Once(function()
		local fade = TweenService:Create(star, TweenInfo.new(life * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(0, 0), ImageTransparency = 1, Rotation = star.Rotation + 45 })
		fade:Play()
		fade.Completed:Once(function()
			star:Destroy()
		end)
	end)
	return star
end

local function step(dt: number)
	local t = os.clock()
	for i = #shines, 1, -1 do
		local s = shines[i]
		if not alive(s.Gui) then
			table.remove(shines, i)
			continue
		end
		-- sweep for Period seconds, then rest for Pause seconds
		local cycle = s.Period + s.Pause
		local local_t = (t + s.Phase) % cycle
		local alpha = math.clamp(local_t / s.Period, 0, 1)
		local eased = alpha < 0.5 and 2 * alpha * alpha or 1 - (-2 * alpha + 2) ^ 2 / 2
		s.Gradient.Offset = Vector2.new(-1.1 + eased * 2.2, 0)
	end
	for i = #rays, 1, -1 do
		local r = rays[i]
		if not alive(r.Gui) then
			r.Holder:Destroy()
			table.remove(rays, i)
			continue
		end
		r.Holder.Visible = r.Gui.Visible
		r.Holder.Rotation = (r.Holder.Rotation + dt * r.Speed) % 360
		if r.Glow then
			r.Glow.ImageTransparency = 0.35 + math.sin(t * 2.4) * 0.15
		end
	end
	for i = #borders, 1, -1 do
		local b = borders[i]
		if not alive(b.Gui) then
			table.remove(borders, i)
			continue
		end
		b.Gradient.Rotation = (b.Gradient.Rotation + dt * b.Speed) % 360
	end
	for i = #tags, 1, -1 do
		local tag = tags[i]
		if not alive(tag.Gui) then
			table.remove(tags, i)
			continue
		end
		local pulse = (math.sin(t * 5 + tag.Phase) + 1) / 2
		tag.Scale.Scale = 1 + pulse * 0.12
		tag.Label.TextColor3 = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(255, 236, 120), pulse)
	end
	for i = #sparkles, 1, -1 do
		local s = sparkles[i]
		if not alive(s.Gui) then
			table.remove(sparkles, i)
			continue
		end
		if s.Gui.Visible then
			s.Acc += dt * s.Rate
			while s.Acc >= 1 do
				s.Acc -= 1
				spawnStar(s.Gui, s.Color)
			end
		end
	end
end

local function ensureLoop()
	if running then
		return
	end
	running = true
	RunService.RenderStepped:Connect(step)
end

-- Light sweep across the tile. opts: Period, Pause, Color, Rotation, Transparency
function ShopJuicer.Shine(gui: GuiObject, opts)
	opts = opts or {}
	ensureLoop()
	local overlay = Instance.new("Frame")
	overlay.Name = "Shine"
	overlay.BackgroundColor3 = opts.Color or Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = opts.Transparency or 0
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = gui.ZIndex + 2
	local corner = gui:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = overlay
	end
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = SHINE_TRANSPARENCY
	gradient.Rotation = opts.Rotation or 20
	gradient.Offset = Vector2.new(-1.1, 0)
	gradient.Parent = overlay
	overlay.Parent = gui
	-- buttons with UIPadding would inset the overlay: cancel the padding so the sweep covers the tile
	local padding = gui:FindFirstChildOfClass("UIPadding")
	if padding then
		local function fit()
			local size = gui.AbsoluteSize
			local left = padding.PaddingLeft.Scale * size.X + padding.PaddingLeft.Offset
			local top = padding.PaddingTop.Scale * size.Y + padding.PaddingTop.Offset
			overlay.Position = UDim2.fromOffset(-left, -top)
			overlay.Size = UDim2.fromOffset(size.X, size.Y)
		end
		fit()
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	table.insert(shines, { Gradient = gradient, Period = opts.Period or 0.9, Pause = opts.Pause or 1.6, Phase = math.random() * 2, Gui = gui })
	return overlay
end

-- Rotating rays + breathing glow behind the tile (a sibling, so it is drawn underneath)
function ShopJuicer.Rays(gui: GuiObject, opts)
	opts = opts or {}
	-- a sibling inside a layout would become a layout cell: wrap such tiles in a plain frame first
	if not gui.Parent or gui.Parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return nil
	end
	ensureLoop()
	local color = opts.Color or Color3.fromRGB(255, 220, 90)
	local size = opts.Size or 2.1
	local holder = Instance.new("Frame")
	holder.Name = gui.Name .. "Rays"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.ZIndex = math.max(1, gui.ZIndex - 1)
	local function follow()
		local center = gui.AbsolutePosition + gui.AbsoluteSize / 2 - (gui.Parent :: GuiObject).AbsolutePosition
		local d = math.max(gui.AbsoluteSize.X, gui.AbsoluteSize.Y) * size
		holder.Position = UDim2.fromOffset(center.X, center.Y)
		holder.Size = UDim2.fromOffset(d, d)
	end
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = Assets.Icons.Glow
	glow.ImageColor3 = color
	glow.ImageTransparency = 0.35
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.75, 0.75)
	glow.ZIndex = holder.ZIndex
	glow.Parent = holder
	for i = 0, (opts.Count or 8) - 1 do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(1, 0, 0.07, 0)
		ray.Rotation = i * (180 / (opts.Count or 8))
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.ZIndex = holder.ZIndex
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.7, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = holder
	end
	holder.Parent = gui.Parent
	follow()
	gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(follow)
	table.insert(rays, { Holder = holder, Speed = opts.Speed or 40, Gui = gui, Glow = glow })
	return holder
end

-- Steady twinkles. opts: Rate (stars per second), Color
function ShopJuicer.Sparkle(gui: GuiObject, opts)
	opts = opts or {}
	ensureLoop()
	table.insert(sparkles, { Gui = gui, Rate = opts.Rate or 2.5, Color = opts.Color or Color3.fromRGB(255, 250, 210), Acc = 0 })
end

function ShopJuicer.Burst(gui: GuiObject, count: number?, color: Color3?)
	for _ = 1, count or 12 do
		spawnStar(gui, color or Color3.fromRGB(255, 240, 150), true)
	end
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 160)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 120)),
})
local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 40)),
})

-- Animated neon outline. opts: Style ("Rainbow" | "Gold"), Thickness, Speed
function ShopJuicer.NeonBorder(gui: GuiObject, opts)
	opts = opts or {}
	ensureLoop()
	local stroke = Instance.new("UIStroke")
	stroke.Name = "NeonBorder"
	stroke.Thickness = opts.Thickness or 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = opts.Style == "Gold" and GOLD or RAINBOW
	gradient.Parent = stroke
	table.insert(borders, { Gradient = gradient, Speed = opts.Speed or 90, Gui = gui })
	return stroke
end

-- Flashing golden ribbon in the top-right corner of a tile
function ShopJuicer.ValueTag(gui: GuiObject, text: string)
	ensureLoop()
	local ribbon = Instance.new("Frame")
	ribbon.Name = "ValueTag"
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.new(1, -18, 0, 10)
	ribbon.Size = UDim2.fromOffset(0, 24)
	ribbon.AutomaticSize = Enum.AutomaticSize.X
	ribbon.Rotation = 8
	ribbon.BackgroundColor3 = Color3.new(1, 1, 1)
	ribbon.ZIndex = gui.ZIndex + 5
	ribbon.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ribbon
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 70, 70), Color3.fromRGB(220, 20, 60))
	gradient.Rotation = 90
	gradient.Parent = ribbon
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = ribbon
	local scale = Instance.new("UIScale")
	scale.Parent = ribbon
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(0, 24)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 15
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = ribbon.ZIndex + 1
	label.Parent = ribbon
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(110, 0, 20)
	stroke.Thickness = 2
	stroke.Parent = label
	table.insert(tags, { Label = label, Scale = scale, Gui = gui, Phase = math.random() * 6 })
	return ribbon
end

function ShopJuicer.Juice(gui: GuiObject, opts)
	opts = opts or {}
	local shine = ShopJuicer.Shine(gui, opts)
	local ray = opts.Rays ~= false and ShopJuicer.Rays(gui, opts) or nil
	ShopJuicer.Sparkle(gui, opts)
	return function()
		shine:Destroy()
		if ray then
			ray:Destroy()
		end
		for i = #sparkles, 1, -1 do
			if sparkles[i].Gui == gui then
				table.remove(sparkles, i)
			end
		end
	end
end

return ShopJuicer
