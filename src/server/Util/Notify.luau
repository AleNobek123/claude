--[[
	Notify
	Server → client toasts and world effects (popups, ability FX).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local NotifyEvent = Net.Event("Notify")
local FxEvent = Net.Event("Fx")

local Notify = {}

-- kind: "info" | "good" | "bad" | "rare"
function Notify.Player(player: Player, text: string, kind: string?)
	NotifyEvent:FireClient(player, text, kind or "info")
end

function Notify.All(text: string, kind: string?)
	NotifyEvent:FireAllClients(text, kind or "info")
end

-- Visual effect for everyone (ability bursts, meteors, level ups)
function Notify.Fx(kind: string, payload: { [string]: any })
	FxEvent:FireAllClients(kind, payload)
end

-- Visual effect only for one player (pollen popups)
function Notify.FxTo(player: Player, kind: string, payload: { [string]: any })
	FxEvent:FireClient(player, kind, payload)
end

return Notify
