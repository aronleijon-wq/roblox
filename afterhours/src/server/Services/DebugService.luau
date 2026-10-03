-- DebugService: verktyg för att testa (starta incidenter, hoppa i tiden, ge HEAT ...).
-- Fungerar bara i Studio, eller för spelets ägare och de UserIds som står i
-- GameConfig.Debug.AllowedUserIds. Allt valideras på servern som vanligt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local IncidentConfig = require(script.Parent.Parent.Config.IncidentConfig)

local DebugService = {}

local services

function DebugService.init(registry)
	services = registry
end

function DebugService.allowed(player: Player): boolean
	if RunService:IsStudio() and GameConfig.Debug.EnabledInStudio then
		return true
	end
	if table.find(GameConfig.Debug.AllowedUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

local COMMANDS = {
	incident = function(_player, id)
		if IncidentConfig.Incidents[id] and IncidentConfig.Incidents[id].scope ~= "Twist" then
			return services.Incidents.trigger(id, { reason = "debug" })
		end
		return false
	end,
	twist = function(player, id)
		local contract = services.Contracts.active(player)
		services.Incidents.startTwist(id, { player = player, siteId = contract and contract.siteId or "PowerBox1" })
		return true
	end,
	clock = function(_player, value)
		local hours = tonumber(value)
		if hours then
			services.Shift.debugSetClock(math.clamp(hours, 0, 2.99))
			return true
		end
		return false
	end,
	skip = function()
		services.Shift.debugSkip()
		return true
	end,
	heat = function(player, value)
		local amount = tonumber(value) or 20
		services.Heat.add(player, amount - services.Heat.get(player), "debug")
		return true
	end,
	credits = function(player, value)
		local amount = tonumber(value) or 5000
		services.Data.update(player, function(data)
			data.credits += amount
		end)
		services.State.mark(player, "profile")
		return true
	end,
	rep = function(player, value)
		local amount = tonumber(value) or 300
		services.Data.update(player, function(data)
			data.reputation += amount
		end)
		services.Contracts.refreshOffers(player)
		services.Inventory.refreshCapacity(player)
		services.State.mark(player, "profile")
		return true
	end,
	give = function(player, itemId)
		if ItemConfig.get(itemId) and not ItemConfig.get(itemId).contractItem then
			return services.Inventory.add(player, itemId) ~= nil
		end
		return false
	end,
}

function DebugService.start()
	services.Security.on(services.Remotes.DebugCommand, "DebugCommand", function(player, command, argument)
		if not DebugService.allowed(player) or type(command) ~= "string" then
			return
		end
		local handler = COMMANDS[command]
		if not handler then
			return
		end
		local ok = handler(player, if type(argument) == "string" then argument else tostring(argument))
		print(`[Debug] {player.Name}: {command} {tostring(argument)} -> {ok}`)
		services.State.notify(
			player,
			"info",
			"DEBUG",
			command .. " " .. tostring(argument) .. (if ok then " ✓" else " ✗"),
			3
		)
	end)
end

return DebugService
