--[[
	Viewport
	3D previews inside the UI (hive cells, bee details, codex, shop items).
	One shared RenderStepped loop animates only the viewports that are on screen.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Viewport = {}

local animated = {} -- [ViewportFrame] = { Model, Base, Mode, Phase }

local function makeFrame(parent: Instance, props)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(205, 190, 170)
	vp.LightColor = Color3.fromRGB(255, 245, 225)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
	vp.Size = UDim2.fromScale(1, 1)
	for key, value in props or {} do
		vp[key] = value
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera
	vp.Parent = parent
	return vp, camera
end

-- Frames a model so its bounding box fills the viewport; `angle` = yaw of the camera
local function frameModel(camera: Camera, model: Model, zoom: number?, pitch: number?)
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (zoom or 1.05)
	local dir = (CFrame.Angles(0, math.rad(-30), 0) * CFrame.Angles(math.rad(-(pitch or 12)), 0, 0)).LookVector
	camera.CFrame = CFrame.lookAt(cf.Position - dir * distance, cf.Position)
end

-- mode: "spin" (turntable), "float" (turntable + bob), "hover" (still; spins while the pointer
-- is over opts.HoverTarget, used for grids of cards), nil (static)
function Viewport.Model(parent: Instance, model: Model, opts)
	opts = opts or {}
	local vp, camera = makeFrame(parent, opts.Props)
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(opts.Yaw or 200), 0))
	model.Parent = vp
	frameModel(camera, model, opts.Zoom, opts.Pitch)
	local mode = opts.Mode
	if mode == "sleep" then
		mode = "hover" -- dozens of breathing hive cells cost more than they add
	end
	if mode then
		local entry = { Vp = vp, Model = model, Base = model:GetPivot(), Mode = mode, Angle = 0, Time = math.random() * 6, Hover = false }
		animated[vp] = entry
		if mode == "hover" then
			local target = opts.HoverTarget or parent
			if target:IsA("GuiObject") then
				target.MouseEnter:Connect(function()
					entry.Hover = true
				end)
				target.MouseLeave:Connect(function()
					entry.Hover = false
				end)
			end
		end
		vp.Destroying:Connect(function()
			animated[vp] = nil
		end)
	end
	return vp, camera
end

-- Silhouette for undiscovered entries
function Viewport.Silhouette(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(40, 30, 25)
			part.Material = Enum.Material.SmoothPlastic
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
		elseif part:IsA("ParticleEmitter") or part:IsA("Sparkles") or part:IsA("Smoke") or part:IsA("Light") then
			part:Destroy()
		end
	end
	return model
end

function Viewport.Clone(folderName: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	local clone = template:Clone()
	if clone:IsA("Tool") then
		-- tools cannot live in a viewport as tools: rehost the parts in a model
		local model = Instance.new("Model")
		for _, child in clone:GetChildren() do
			child.Parent = model
		end
		model.PrimaryPart = model:FindFirstChild("Handle")
		clone:Destroy()
		clone = model
	end
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	return clone
end

-- A viewport is worth animating only if it is really on screen: every ancestor visible,
-- its ScreenGui enabled and (inside scrolling lists) scrolled into view.
local function onScreen(vp: ViewportFrame): boolean
	if not vp.Visible or vp.AbsoluteSize.X <= 4 then
		return false
	end
	local pos, size = vp.AbsolutePosition, vp.AbsoluteSize
	local node = vp.Parent
	while node do
		if node:IsA("LayerCollector") then
			return node.Enabled
		elseif node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
			if node:IsA("ScrollingFrame") then
				local wp, ws = node.AbsolutePosition, node.AbsoluteSize
				if pos.Y + size.Y < wp.Y or pos.Y > wp.Y + ws.Y or pos.X + size.X < wp.X or pos.X > wp.X + ws.X then
					return false
				end
			end
		end
		node = node.Parent
	end
	return false
end

-- Only a few previews ever move at once (detail views, the hovered card), and each keeps its own
-- angle that advances with the frame time: motion is smooth, and a preview that scrolls away and
-- back continues where it stopped instead of snapping to a new pose.
local SPIN = { spin = 0.9, float = 0.7, hover = 1.6 }

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	for vp, entry in animated do
		if (entry.Mode ~= "hover" or entry.Hover) and entry.Model.Parent and onScreen(vp) then
			entry.Angle += dt * (SPIN[entry.Mode] or 0.9)
			entry.Time += dt
			local bob = entry.Mode == "float" and math.sin(entry.Time * 2) * 0.08 or 0
			entry.Model:PivotTo(entry.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, entry.Angle, 0))
		end
	end
end)

return Viewport
