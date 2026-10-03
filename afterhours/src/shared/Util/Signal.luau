-- Signal: enkel händelse mellan moduler (utan BindableEvent, så den kan testas i Lune).
-- Lyssnare körs i egna trådar så att en lyssnare som väntar inte blockerar de andra.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> (), connected: boolean }

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	local connection = { connected = true }
	function connection.Disconnect()
		connection.connected = false
		local index = table.find(self.handlers, connection)
		if index then
			table.remove(self.handlers, index)
		end
	end
	connection.handler = handler
	table.insert(self.handlers, connection)
	return connection
end

function Signal:Fire(...: any)
	for _, connection in table.clone(self.handlers) do
		if connection.connected then
			task.spawn(connection.handler, ...)
		end
	end
end

-- Kör lyssnarna direkt i samma tråd (för när ordningen spelar roll).
function Signal:FireSync(...: any)
	for _, connection in table.clone(self.handlers) do
		if connection.connected then
			connection.handler(...)
		end
	end
end

return Signal
