--[[
	VipStyle
	Metallic gold look for VIP names (overhead tag, leaderboards). The server attaches a
	"VipGold" UIGradient (tagged with CollectionService); clients sweep its offset every frame.
]]

local CollectionService = game:GetService("CollectionService")

local VipStyle = {}

VipStyle.Tag = "VipGold"
VipStyle.Gold = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 40)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 236, 140)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 235)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 220, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 140, 20)),
})

-- Adds (or removes) the animated gold gradient on a text label
function VipStyle.Apply(label: TextLabel, enabled: boolean)
	local gradient = label:FindFirstChild("VipGold")
	if enabled and not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = "VipGold"
		gradient.Color = VipStyle.Gold
		gradient.Rotation = 15
		gradient.Parent = label
		CollectionService:AddTag(gradient, VipStyle.Tag)
		label.TextColor3 = Color3.new(1, 1, 1)
	elseif not enabled and gradient then
		gradient:Destroy()
	end
end

return VipStyle
