--[[
	State
	Client copy of the player's profile. Filled once by GetData, then patched by
	StateUpdate deltas (top-level keys only). Controllers subscribe with OnChange.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local State = {}
State.Data = nil
State.Changed = Signal.new() -- (keysSet)
State.Loaded = false

local pending = {}

local function apply(payload)
	local keys = {}
	for key, value in payload do
		State.Data[key] = value
		keys[key] = true
	end
	State.Changed:Fire(keys)
end

function State:Get(key: string)
	return self.Data and self.Data[key]
end

-- Calls handler(data) now (if loaded) and whenever one of `keys` changes (nil = any key)
function State:OnChange(keys: { string }?, handler)
	local watch
	if keys then
		watch = {}
		for _, key in keys do
			watch[key] = true
		end
	end
	if self.Loaded then
		task.spawn(handler, self.Data)
	end
	return self.Changed:Connect(function(changed)
		if not watch then
			handler(self.Data)
			return
		end
		for key in changed do
			if watch[key] then
				handler(self.Data)
				return
			end
		end
	end)
end

function State:Capacity(): number
	local backpack = self.Data and Config.BackpackById[self.Data.Backpack]
	return backpack and backpack.Capacity or 0
end

function State:BeeCount(): number
	local n = 0
	if self.Data then
		for _ in self.Data.Bees do
			n += 1
		end
	end
	return n
end

function State:Init()
	Net.Event("StateUpdate").OnClientEvent:Connect(function(payload)
		if self.Data then
			apply(payload)
		else
			table.insert(pending, payload)
		end
	end)
end

function State:Start()
	local getData = Net.Function("GetData")
	local data
	repeat
		local ok, result = pcall(getData.InvokeServer, getData)
		data = ok and result or nil
		if not data then
			task.wait(1)
		end
	until data
	self.Data = data
	for _, payload in pending do
		for key, value in payload do
			self.Data[key] = value
		end
	end
	table.clear(pending)
	self.Loaded = true
	local all = {}
	for key in self.Data do
		all[key] = true
	end
	self.Changed:Fire(all)
end

return State
