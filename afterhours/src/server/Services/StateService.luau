-- StateService: skickar spelarens tillstånd till klienten.
--
-- Varje system registrerar en "sektion" (t.ex. "inventory") med en funktion som bygger den.
-- När något ändras markeras sektionen som smutsig, och högst tio gånger per sekund skickas
-- bara de ändrade sektionerna. Klienten får aldrig mer än den behöver om sig själv.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StateService = {}

local providers: { [string]: (Player) -> any } = {}
local dirty: { [Player]: { [string]: boolean } } = {}
local services
local FLUSH_INTERVAL = 0.1

function StateService.init(registry)
	services = registry
end

function StateService.register(section: string, provider: (Player) -> any)
	providers[section] = provider
end

function StateService.mark(player: Player, section: string)
	if not services.Data.isLoaded(player) then
		return
	end
	dirty[player] = dirty[player] or {}
	dirty[player][section] = true
end

function StateService.markAll(section: string)
	for _, player in Players:GetPlayers() do
		StateService.mark(player, section)
	end
end

function StateService.snapshot(player: Player)
	local snapshot = {}
	for section, provider in providers do
		local ok, value = pcall(provider, player)
		if ok then
			snapshot[section] = value
		else
			warn("[StateService] sektionen " .. section .. " misslyckades:", value)
		end
	end
	return snapshot
end

-- Radio/dispatch-meddelande. kind: "radio", "info", "good", "warning", "danger", "discovery"
function StateService.notify(player: Player, kind: string, title: string?, text: string, duration: number?)
	services.Remotes.Notify:FireClient(player, { kind = kind, title = title, text = text, duration = duration })
end

function StateService.notifyAll(kind: string, title: string?, text: string, duration: number?)
	services.Remotes.Notify:FireAllClients({ kind = kind, title = title, text = text, duration = duration })
end

local function flush()
	for player, sections in dirty do
		if player.Parent == Players and next(sections) then
			local payload = {}
			for section in sections do
				local provider = providers[section]
				if provider then
					local ok, value = pcall(provider, player)
					if ok then
						payload[section] = value
					else
						warn("[StateService] sektionen " .. section .. " misslyckades:", value)
					end
				end
			end
			services.Remotes.StateSync:FireClient(player, payload)
		end
		dirty[player] = nil
	end
end

function StateService.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= FLUSH_INTERVAL then
			elapsed = 0
			flush()
		end
	end)
	services.Security.onInvoke(services.Remotes.GetSnapshot, "GetSnapshot", function(player)
		return StateService.snapshot(player)
	end, nil)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
end

return StateService
