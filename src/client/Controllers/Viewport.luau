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

-- mode: "spin" (slow turntable), "float" (bob + gentle sway), "sleep" (slow breathing), nil (static)
function Viewport.Model(parent: Instance, model: Model, opts)
	opts = opts or {}
	local vp, camera = makeFrame(parent, opts.Props)
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(opts.Yaw or 200), 0))
	model.Parent = vp
	frameModel(camera, model, opts.Zoom, opts.Pitch)
	if opts.Mode then
		animated[vp] = { Model = model, Base = model:GetPivot(), Mode = opts.Mode, Phase = math.random() * 6 }
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

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for vp, entry in animated do
		if vp.Parent and vp.Visible and vp.AbsoluteSize.X > 4 then
			local model = entry.Model
			local base = entry.Base
			if entry.Mode == "spin" then
				model:PivotTo(base * CFrame.Angles(0, t * 0.9, 0))
			elseif entry.Mode == "float" then
				model:PivotTo(base * CFrame.new(0, math.sin(t * 2 + entry.Phase) * 0.12, 0) * CFrame.Angles(0, math.sin(t * 0.8 + entry.Phase) * 0.35, math.sin(t * 1.6 + entry.Phase) * 0.06))
			elseif entry.Mode == "sleep" then
				model:PivotTo(base * CFrame.new(0, math.sin(t * 1.4 + entry.Phase) * 0.04, 0) * CFrame.Angles(math.rad(8 + math.sin(t * 1.4 + entry.Phase) * 3), 0, 0))
			end
		end
	end
end)

return Viewport
