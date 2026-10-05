--[[
	Signal
	Minimal synchronous signal for client-side state changes.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	local handlers = self._handlers
	table.insert(handlers, handler)
	return {
		Disconnect = function()
			local i = table.find(handlers, handler)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
