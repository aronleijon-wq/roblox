-- IncidentService: IncidentDirector, spelets viktigaste system.
--
-- Varje TickInterval under natten frågar regissören DirectorLogic om något ska hända
-- (baserat på klocka, server-HEAT, antal spelare, nedkylning, historik och kvällens prognos)
-- och väljer i så fall en incident med viktad slump. Varje val loggas med seed.
--
-- Varje incident är en egen modul i Server/Incidents med start(ctx) och stop(ctx).
-- Klienten får WorldEvent { type = "IncidentStart"/"IncidentEnd", id, ... } och sköter
-- presentationen (ljus, ljud, kamera) själv.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local IncidentConfig = require(script.Parent.Parent.Config.IncidentConfig)
local DirectorLogic = require(script.Parent.Parent.Logic.DirectorLogic)

local IncidentService = {}

type Context = {
	id: string,
	def: any,
	services: any,
	world: any,
	rng: any,
	seed: number,
	startedAt: number,
	endsAt: number,
	data: { [string]: any },
	client: { [string]: any },
	twist: any?,
	key: string,
}

local modules: { [string]: any } = {}
local active: { [string]: Context } = {} -- regissörens incidenter
local twists: { [string]: Context } = {} -- kontraktens vändningar
local lastStartedAt: { [string]: number } = {}
local history: { string } = {}
local thisShift: { [string]: boolean } = {}
local previousShiftMajors: { string } = {}
local incidentsThisNight = 0
local lastIncidentAt: number? = nil
local forecast: string? = nil
local twistCounter = 0
local directorRng = Rng.new(os.time())
local services

local config = GameConfig.Director

function IncidentService.init(registry)
	services = registry
	for id in IncidentConfig.Incidents do
		local moduleScript = script.Parent.Parent.Incidents:FindFirstChild(id)
		if moduleScript then
			modules[id] = require(moduleScript)
		else
			warn("[Director] incidenten saknar modul:", id)
		end
	end
end

local function now(): number
	return services.Shift.now()
end

local function publishActive()
	local ids = {}
	for id in active do
		table.insert(ids, id)
	end
	table.sort(ids)
	ReplicatedStorage:SetAttribute(Constants.WorldAttributes.ActiveIncidents, table.concat(ids, ","))
	services.State.markAll("world")
end

local function newContext(id: string, seed: number): Context
	local def = IncidentConfig.Incidents[id]
	return {
		id = id,
		def = def,
		services = services,
		world = services.World.world,
		rng = Rng.new(seed),
		seed = seed,
		startedAt = now(),
		endsAt = now() + def.duration,
		data = {},
		client = {},
		twist = nil,
		key = id,
	}
end

local function witness(id: string, def)
	for _, player in Players:GetPlayers() do
		if services.Data.isLoaded(player) then
			services.Telemetry.onboarding(player, "FirstIncident")
			services.Progression.discover(player, "inc_" .. id, def.name)
			services.Data.update(player, function(data)
				data.stats.incidentsWitnessed += 1
			end)
		end
	end
end

-- Startar en regissörsincident. opts.reason förklarar varför (i loggen).
function IncidentService.trigger(id: string, opts: { reason: string?, force: boolean? }?): boolean
	local def = IncidentConfig.Incidents[id]
	local module = modules[id]
	if not def or not module or active[id] then
		return false
	end
	local seed = directorRng:integer(1, 2147483646)
	local ctx = newContext(id, seed)
	local ok, result = pcall(module.start, ctx)
	if not ok then
		warn(`[Director] {id} kunde inte starta:`, result)
		return false
	end
	if result == false then
		return false -- modulen hittade inget att göra (t.ex. ingen spelare att följa)
	end
	active[id] = ctx
	lastStartedAt[id] = now()
	table.insert(history, id)
	while #history > config.HistorySize do
		table.remove(history, 1)
	end
	thisShift[id] = true
	incidentsThisNight += 1
	lastIncidentAt = now()
	print(
		string.format(
			"[Director] START %s (%s) seed=%d heat=%.0f clock=%.2f reason=%s",
			id,
			def.rarity,
			seed,
			services.Heat.serverHeat(),
			services.Shift.clock(),
			opts and opts.reason or "director"
		)
	)
	publishActive()
	services.Remotes.WorldEvent:FireAllClients({
		type = "IncidentStart",
		id = id,
		name = def.name,
		rarity = def.rarity,
		endsAt = ctx.endsAt,
		data = ctx.client,
	})
	if def.radio and not ctx.data.customRadio then
		services.State.notifyAll("radio", "DISPATCH", (def.radio:gsub("{site}", ctx.data.siteLabel or "a building")), 7)
	end
	witness(id, def)
	task.delay(def.duration, function()
		if active[id] == ctx then
			IncidentService.stop(id)
		end
	end)
	return true
end

function IncidentService.stop(id: string)
	local ctx = active[id]
	if not ctx then
		return
	end
	active[id] = nil
	local module = modules[id]
	local ok, err = pcall(module.stop, ctx)
	if not ok then
		warn(`[Director] {id} kunde inte städa upp:`, err)
	end
	publishActive()
	services.Remotes.WorldEvent:FireAllClients({ type = "IncidentEnd", id = id })
	print("[Director] END", id)
end

-- Kontraktsvändning (SOMETHING INSIDE, OVERLOAD, WRONG ADDRESS). Flera kan pågå samtidigt.
function IncidentService.startTwist(id: string, twist)
	local def = IncidentConfig.Incidents[id]
	local module = modules[id]
	if not def or not module then
		return
	end
	twistCounter += 1
	local ctx = newContext(id, directorRng:integer(1, 2147483646))
	ctx.twist = twist
	ctx.key = id .. ":" .. twistCounter
	local ok, result = pcall(module.start, ctx)
	if not ok then
		warn(`[Director] vändningen {id} kunde inte starta:`, result)
		return
	end
	if result == false then
		return
	end
	print(
		string.format("[Director] TWIST %s seed=%d player=%s", id, ctx.seed, twist.player and twist.player.Name or "?")
	)
	twists[ctx.key] = ctx
	if twist.player then
		services.Progression.discover(twist.player, "inc_" .. id, def.name)
	end
	task.delay(def.duration, function()
		IncidentService.stopTwist(ctx.key)
	end)
end

function IncidentService.stopTwist(key: string)
	local ctx = twists[key]
	if not ctx then
		return
	end
	twists[key] = nil
	local ok, err = pcall(modules[ctx.id].stop, ctx)
	if not ok then
		warn(`[Director] vändningen {ctx.id} kunde inte städa upp:`, err)
	end
end

function IncidentService.twistFor(player: Player, id: string?)
	for _, ctx in twists do
		if ctx.twist and ctx.twist.player == player and (id == nil or ctx.id == id) then
			return ctx
		end
	end
	return nil
end

-- Frågor från andra system -------------------------------------------------------------------

function IncidentService.isActive(id: string): boolean
	return active[id] ~= nil
end

function IncidentService.anyActive(): boolean
	return next(active) ~= nil
end

function IncidentService.rewardModifier(): number
	local modifier = 1
	for _, ctx in active do
		modifier *= ctx.def.rewardModifier or 1
	end
	return modifier
end

function IncidentService.dangerModifier(): number
	local modifier = 1
	for _, ctx in active do
		modifier *= ctx.def.dangerModifier or 1
	end
	return modifier
end

function IncidentService.happenedThisShift(id: string): boolean
	return thisShift[id] == true
end

function IncidentService.biggestThisShift()
	local best, bestRank = nil, 0
	for id in thisShift do
		local def = IncidentConfig.Incidents[id]
		if def and def.scope ~= "Twist" then
			local rank = DirectorLogic.rarityRank(def.rarity)
			if rank > bestRank then
				best, bestRank = def, rank
			end
		end
	end
	return if best then { name = best.name, district = services.World.world.district.name } else nil
end

function IncidentService.forecast(): string?
	return forecast
end

-- Regissören ----------------------------------------------------------------------------------

local function directorContext()
	local activeSet = {}
	for id in active do
		activeSet[id] = true
	end
	return {
		now = now(),
		nightElapsed = services.Shift.nightElapsed(),
		clock = services.Shift.clock(),
		serverHeat = services.Heat.serverHeat(),
		playerCount = #Players:GetPlayers(),
		active = activeSet,
		lastStartedAt = lastStartedAt,
		history = history,
		previousShiftMajors = previousShiftMajors,
		incidentsThisNight = incidentsThisNight,
		lastIncidentAt = lastIncidentAt,
		forecast = forecast,
	}
end

local function directorTick()
	if not services.Shift.isNight() or #Players:GetPlayers() == 0 then
		return
	end
	local context = directorContext()
	local chance = DirectorLogic.triggerChance(context, config)
	if chance <= 0 or not directorRng:chance(chance) then
		return
	end
	local choice = DirectorLogic.choose(IncidentConfig.Incidents, context, config, directorRng)
	if choice then
		IncidentService.trigger(choice.id)
	end
end

local function chooseForecast()
	-- Kvällens prognos: en vanlig eller ovanlig incident som blir lite mer trolig i natt.
	local candidates = {}
	for id, def in IncidentConfig.Incidents do
		if def.scope == "District" and DirectorLogic.rarityRank(def.rarity) <= DirectorLogic.rarityRank("Rare") then
			table.insert(candidates, id)
		end
	end
	table.sort(candidates)
	forecast = directorRng:pick(candidates)
	local def = forecast and IncidentConfig.Incidents[forecast]
	ReplicatedStorage:SetAttribute(Constants.WorldAttributes.Forecast, if def then def.name else "")
end

function IncidentService.start()
	services.Security.on(services.Remotes.TwistChoice, "TwistChoice", function(player, key, choice)
		if not services.Security.isString(key, 40) or not services.Security.isString(choice, 20) then
			return
		end
		local ctx = twists[key]
		local module = ctx and modules[ctx.id]
		if ctx and ctx.twist and ctx.twist.player == player and module.choice then
			module.choice(ctx, player, choice)
			services.Telemetry.event(player, "TwistChoice", 1, { twist = ctx.id, choice = choice })
		end
	end)
	services.State.register("world", function()
		local list = {}
		for id, ctx in active do
			table.insert(list, { id = id, name = ctx.def.name, endsAt = ctx.endsAt, data = ctx.client })
		end
		return { incidents = list }
	end)
	services.Shift.NightStarted:Connect(function()
		incidentsThisNight = 0
		lastIncidentAt = nil
		directorRng = Rng.new(os.time() + services.Shift.shiftNumber() * 104729)
	end)
	services.Shift.ShiftEnded:Connect(function()
		for id in active do
			IncidentService.stop(id)
		end
		for key in twists do
			IncidentService.stopTwist(key)
		end
		previousShiftMajors = {}
		for id in thisShift do
			local def = IncidentConfig.Incidents[id]
			if def and DirectorLogic.rarityRank(def.rarity) >= DirectorLogic.rarityRank("Major") then
				table.insert(previousShiftMajors, id)
			end
		end
	end)
	services.Shift.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Hub then
			thisShift = {}
			chooseForecast()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(config.TickInterval)
			local ok, err = pcall(directorTick)
			if not ok then
				warn("[Director]", err)
			end
		end
	end)
end

return IncidentService
