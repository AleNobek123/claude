--[[
	FeedbackService
	In-game bug reports and reviews from the Feedback panel.
	  - validated (kind, 1-5 stars, length) and rate-limited per player
	  - stored in the "BeeTycoon_Feedback_v1" DataStore under "<unix>_<userId>"
	  - optionally forwarded as JSON to Config.Feedback.Webhook (leave empty to disable)
	In Studio without API access the report is printed to the output instead.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local FeedbackService = {}
FeedbackService.Name = "FeedbackService"

local S
local store
local lastSent: { [Player]: number } = {}

local KINDS = { Bug = true, Review = true }

function FeedbackService:Submit(player: Player, kind: string, rating: number?, text: string)
	if typeof(kind) ~= "string" or not KINDS[kind] or typeof(text) ~= "string" then
		return false, "Invalid report"
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text < Config.Feedback.MinLength then
		return false, `Please write at least {Config.Feedback.MinLength} characters`
	end
	text = text:sub(1, Config.Feedback.MaxLength)
	local last = lastSent[player]
	if last and os.clock() - last < Config.Feedback.Cooldown then
		return false, `Please wait {math.ceil(Config.Feedback.Cooldown - (os.clock() - last))}s before sending again`
	end
	lastSent[player] = os.clock()
	local stars = typeof(rating) == "number" and math.clamp(math.floor(rating), 1, 5) or nil
	local data = S.DataService and S.DataService:Get(player)
	local report = {
		Kind = kind,
		Rating = kind == "Review" and stars or nil,
		Text = text,
		UserId = player.UserId,
		Name = player.Name,
		Bees = data and S.HiveService:CountBees(data) or 0,
		TotalHoney = data and data.TotalHoney or 0,
		PlaceVersion = game.PlaceVersion,
		Time = os.time(),
	}
	local stored = false
	if store then
		stored = pcall(store.SetAsync, store, `{report.Time}_{player.UserId}`, report)
	end
	if not stored then
		print("[Feedback]", HttpService:JSONEncode(report))
	end
	if Config.Feedback.Webhook ~= "" then
		task.spawn(pcall, HttpService.PostAsync, HttpService, Config.Feedback.Webhook, HttpService:JSONEncode(report), Enum.HttpContentType.ApplicationJson)
	end
	return true, kind == "Bug" and "Bug report sent. Thank you!" or "Thanks for your review!"
end

function FeedbackService:Init(services)
	S = services
	self.Remote = Net.Function("SubmitFeedback")
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "BeeTycoon_Feedback_v1")
	store = ok and result or nil
end

function FeedbackService:Start()
	self.Remote.OnServerInvoke = function(player, kind, rating, text)
		if not Net.Allow(player, "SubmitFeedback", 2) then
			return false, "Slow down"
		end
		return self:Submit(player, kind, rating, text)
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
end

return FeedbackService
