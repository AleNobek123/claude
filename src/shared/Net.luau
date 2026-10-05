--[[
	Net
	Single place that creates (server) or waits for (client) remotes, so names never drift.
	Server code also gets a tiny per-player rate limiter for incoming requests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local Net = {}

local folder: Folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string, className: string)
	if IS_SERVER then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	end
	return folder:WaitForChild(name, 30)
end

function Net.Event(name: string): RemoteEvent
	return get(name, "RemoteEvent")
end

function Net.Unreliable(name: string): UnreliableRemoteEvent
	return get(name, "UnreliableRemoteEvent")
end

function Net.Function(name: string): RemoteFunction
	return get(name, "RemoteFunction")
end

-- Server: returns true if `player` may call `key` now (at most once per `interval` seconds).
local lastCall: { [Player]: { [string]: number } } = {}
function Net.Allow(player: Player, key: string, interval: number): boolean
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[key]
	if last and now - last < interval then
		return false
	end
	calls[key] = now
	return true
end

function Net.Forget(player: Player)
	lastCall[player] = nil
end

return Net
