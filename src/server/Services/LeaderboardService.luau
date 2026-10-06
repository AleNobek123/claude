--[[
	LeaderboardService
	Two holographic boards at spawn:
	  - Top Honey Producers Today: OrderedDataStore per UTC day, written with IncrementAsync
	    from in-memory deltas every 120 s (keeps well inside DataStore request budgets).
	  - Rarest Swarm Score: OrderedDataStore, SetAsync when a player's score changed.
	Boards refresh every 60 s. Without DataStore access (Studio) they show this server.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VipStyle = require(Shared.VipStyle)
local Format = require(Shared.Format)

local LeaderboardService = {}
LeaderboardService.Name = "LeaderboardService"

local FLUSH_INTERVAL = 120
local REFRESH_INTERVAL = 60
local ROWS = 10

local S
local pendingHoney: { [number]: number } = {}
local sessionHoney: { [number]: number } = {}
local swarmScores: { [number]: { Score: number, Dirty: boolean } } = {}
local names: { [number]: string } = {}
local online = false

local function dayKey(): string
	return "HoneyDaily_" .. os.date("!%Y%m%d")
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

function LeaderboardService:SetSwarmScore(player: Player, score: number)
	local entry = swarmScores[player.UserId]
	if entry and entry.Score == score then
		return
	end
	swarmScores[player.UserId] = { Score = score, Dirty = true }
end

-- Board rendering ------------------------------------------------------------------------------

local function boardRows(boardName: string)
	local map = Workspace:FindFirstChild("Map")
	local boards = map and map:FindFirstChild("Leaderboards")
	local board = boards and boards:FindFirstChild(boardName)
	local gui = board and board:FindFirstChildWhichIsA("SurfaceGui", true)
	return gui and gui:FindFirstChild("Rows", true)
end

local function render(boardName: string, entries: { { UserId: number, Value: number } })
	local rows = boardRows(boardName)
	if not rows then
		return
	end
	for i = 1, ROWS do
		local row = rows:FindFirstChild("Row" .. i)
		if row then
			local entry = entries[i]
			if entry then
				row.Text = `{i}.  {nameOf(entry.UserId)}  —  {Format.Short(entry.Value)}`
				local online = Players:GetPlayerByUserId(entry.UserId)
				VipStyle.Apply(row, online ~= nil and online:GetAttribute("VIP") == true)
			else
				row.Text = `{i}.  ---`
				VipStyle.Apply(row, false)
			end
		end
	end
end

local function fetchTop(store): { { UserId: number, Value: number } }
	local ok, pages = pcall(store.GetSortedAsync, store, false, ROWS)
	if not ok then
		warn("[Leaderboard] GetSortedAsync failed:", pages)
		return {}
	end
	local list = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(list, { UserId = userId, Value = item.value })
		end
	end
	return list
end

local function localTop(source): { { UserId: number, Value: number } }
	local list = {}
	for userId, value in source do
		local v = type(value) == "table" and value.Score or value
		table.insert(list, { UserId = userId, Value = v })
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	return list
end

function LeaderboardService:_flush()
	if not online then
		return
	end
	local honeyStore = DataStoreService:GetOrderedDataStore(dayKey())
	for userId, amount in pendingHoney do
		local value = math.floor(amount)
		if value > 0 then
			local ok, err = pcall(honeyStore.IncrementAsync, honeyStore, tostring(userId), value)
			if ok then
				pendingHoney[userId] = nil
			else
				warn("[Leaderboard] Increment failed:", err)
			end
		end
	end
	local swarmStore = DataStoreService:GetOrderedDataStore("SwarmScore_v1")
	for userId, entry in swarmScores do
		if entry.Dirty then
			local ok = pcall(swarmStore.SetAsync, swarmStore, tostring(userId), math.floor(entry.Score))
			if ok then
				entry.Dirty = false
			end
		end
	end
end

function LeaderboardService:_refresh()
	if online then
		render("HoneyBoard", fetchTop(DataStoreService:GetOrderedDataStore(dayKey())))
		render("SwarmBoard", fetchTop(DataStoreService:GetOrderedDataStore("SwarmScore_v1")))
	else
		render("HoneyBoard", localTop(sessionHoney))
		render("SwarmBoard", localTop(swarmScores))
	end
end

function LeaderboardService:Init(services)
	S = services
end

function LeaderboardService:Start()
	online = not S.DataService:IsMock()

	S.DataService.HoneyEarned:Connect(function(player, amount)
		pendingHoney[player.UserId] = (pendingHoney[player.UserId] or 0) + amount
		sessionHoney[player.UserId] = (sessionHoney[player.UserId] or 0) + amount
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.spawn(self._flush, self)
		if not online then
			sessionHoney[player.UserId] = nil
			swarmScores[player.UserId] = nil
		end
	end)

	game:BindToClose(function()
		self:_flush()
	end)

	task.spawn(function()
		local sinceFlush = 0
		while true do
			self:_refresh()
			task.wait(online and REFRESH_INTERVAL or 5)
			sinceFlush += online and REFRESH_INTERVAL or 5
			if sinceFlush >= FLUSH_INTERVAL then
				sinceFlush = 0
				self:_flush()
			end
		end
	end)
end

return LeaderboardService
