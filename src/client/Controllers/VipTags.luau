--[[
	VipTags
	Premium gold look for VIP players:
	  - sweeps the metallic "VipGold" gradients the server puts on overhead tags and leaderboards
	  - prefixes VIP chat messages with a bold gold [VIP] tag (TextChatService)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local VipStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VipStyle"))

local VipTags = {}

function VipTags:Start()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local offset = Vector2.new(math.sin(t * 1.6) * 0.65, 0)
		for _, gradient in CollectionService:GetTagged(VipStyle.Tag) do
			gradient.Offset = offset
		end
	end)
	pcall(function()
		TextChatService.OnIncomingMessage = function(message)
			local properties = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			local speaker = source and Players:GetPlayerByUserId(source.UserId)
			if speaker and speaker:GetAttribute("VIP") then
				properties.PrefixText = `<font color="#FFD447"><b>[VIP]</b></font> ` .. message.PrefixText
			end
			return properties
		end
	end)
end

return VipTags
