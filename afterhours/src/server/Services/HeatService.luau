-- HeatService: HEAT per spelare (0-100) och serverns sammanvägda HEAT.
--
-- HEAT stiger av risker: förbjudna zoner, HIGH RISK-kontrakt, larm, avvikelser, att vara ute
-- sent. Den sjunker långsamt i säkra zoner. Hög HEAT ger bättre betalt men gör farligare
-- incidenter troligare (se IncidentDirector). Nollställs vid varje nytt skift.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HeatLogic = require(script.Parent.Parent.Logic.HeatLogic)

local HeatService = {}

local heat: { [Player]: number } = {}
local services
local config = GameConfig.Heat

function HeatService.init(registry)
	services = registry
end

function HeatService.get(player: Player): number
	return heat[player] or 0
end

function HeatService.add(player: Player, amount: number, _reason: string?)
	if heat[player] == nil then
		return
	end
	local before = heat[player]
	local after = HeatLogic.add(before, amount, config, services.Incidents.dangerModifier())
	heat[player] = after
	player:SetAttribute(Constants.PlayerAttributes.Heat, math.floor(after + 0.5))
	services.Economy.notePeakHeat(player, after)
	local tierBefore = HeatLogic.tier(before, config)
	local tierAfter = HeatLogic.tier(after, config)
	if tierAfter.min > tierBefore.min then
		services.State.mark(player, "heat")
		if tierBefore.min == 0 then
			services.State.notify(player, "warning", "HEAT RISING", GameConfig.Onboarding.FirstHeatHint, 6)
		end
	elseif math.floor(after) ~= math.floor(before) then
		services.State.mark(player, "heat")
	end
end

function HeatService.serverHeat(): number
	local values = {}
	for player, value in heat do
		if player.Parent == Players then
			table.insert(values, value)
		end
	end
	return HeatLogic.serverHeat(values)
end

function HeatService.hottestPlayer(filter: ((Player) -> boolean)?): Player?
	local best, bestHeat = nil, -1
	for player, value in heat do
		if value > bestHeat and (not filter or filter(player)) then
			best, bestHeat = player, value
		end
	end
	return best
end

local function tick(dt: number)
	local night = services.Shift.isNight()
	local clock = services.Shift.clock()
	for _, player in Players:GetPlayers() do
		if heat[player] ~= nil and services.Security.alive(player) then
			if services.Player.inZone(player, "Restricted") then
				HeatService.add(player, config.Gain.RestrictedPerSecond * dt, "restricted")
			elseif services.Player.inZone(player, "Safe") then
				HeatService.add(player, -config.SafeZoneDecayPerSecond * dt, "safe")
			elseif night and clock >= config.Gain.LateClock then
				HeatService.add(player, config.Gain.OutsideLatePerSecond * dt, "late")
			end
		end
	end
	ReplicatedStorage:SetAttribute(Constants.WorldAttributes.ServerHeat, math.floor(HeatService.serverHeat() + 0.5))
end

function HeatService.start()
	services.Player.Ready:Connect(function(player)
		heat[player] = 0
		player:SetAttribute(Constants.PlayerAttributes.Heat, 0)
		services.State.mark(player, "heat")
	end)
	Players.PlayerRemoving:Connect(function(player)
		heat[player] = nil
	end)
	services.Shift.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Hub and config.ResetEachShift then
			for player in heat do
				heat[player] = 0
				player:SetAttribute(Constants.PlayerAttributes.Heat, 0)
				services.State.mark(player, "heat")
			end
		end
	end)
	services.Player.ZoneChanged:Connect(function(player, kind, zone)
		if kind == "Restricted" and zone then
			services.State.notify(player, "warning", "RESTRICTED AREA", zone .. ". HEAT rises while you're in here.", 4)
		end
	end)
	services.State.register("heat", function(player)
		local value = heat[player] or 0
		return { value = math.floor(value + 0.5), tier = HeatLogic.tier(value, config).name }
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick, 1)
			if not ok then
				warn("[HeatService]", err)
			end
		end
	end)
end

return HeatService
