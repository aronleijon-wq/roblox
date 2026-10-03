-- ClientState: klientens kopia av spelarens tillstånd. Servern skickar ändrade sektioner
-- (StateSync); här slås de ihop och andra controllers kan lyssna på en sektion.
-- Inget här är auktoritativt: allt viktigt avgörs på servern.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ClientState = {}

ClientState.data = {} :: { [string]: any }
ClientState.Changed = Signal.new() -- (section, value)

local listeners: { [string]: { (any) -> () } } = {}

function ClientState.get(section: string): any
	return ClientState.data[section]
end

-- Kör fn nu (om sektionen finns) och varje gång den ändras.
function ClientState.watch(section: string, fn: (any) -> ())
	listeners[section] = listeners[section] or {}
	table.insert(listeners[section], fn)
	if ClientState.data[section] ~= nil then
		task.spawn(fn, ClientState.data[section])
	end
end

local function apply(section: string, value: any)
	ClientState.data[section] = value
	for _, fn in listeners[section] or {} do
		task.spawn(fn, value)
	end
	ClientState.Changed:Fire(section, value)
end

function ClientState.start(remotes)
	remotes.StateSync.OnClientEvent:Connect(function(payload)
		for section, value in payload do
			apply(section, value)
		end
	end)
	-- Hela tillståndet en gång vid start (om servern hunnit ladda profilen).
	task.spawn(function()
		for _ = 1, 10 do
			local ok, snapshot = pcall(remotes.GetSnapshot.InvokeServer, remotes.GetSnapshot)
			if ok and snapshot and snapshot.profile then
				for section, value in snapshot do
					if ClientState.data[section] == nil then
						apply(section, value)
					end
				end
				return
			end
			task.wait(2)
		end
	end)
end

return ClientState
