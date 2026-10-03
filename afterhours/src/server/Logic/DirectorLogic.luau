-- DirectorLogic: besluten bakom IncidentDirector, som ren logik.
-- 1) shouldTrigger: ska något hända nu?  2) choose: i så fall vad?
--
-- Valet är kontrollerad slump: först väljs en sällsynthetsklass enligt
-- GameConfig.Director.RarityWeights (bland klasser som har möjliga incidenter), sedan en
-- incident i klassen. Nyliga incidenter straffas, kvällens prognos förstärks och Major+
-- får inte upprepas två skift i rad. Varje val loggas med seed så att det kan återskapas.

local DirectorLogic = {}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Major", "Extreme", "Legendary" }

export type Context = {
	now: number, -- servertid
	nightElapsed: number, -- sekunder sedan natten började
	clock: number, -- spelklockan i timmar
	serverHeat: number,
	playerCount: number,
	active: { [string]: boolean },
	lastStartedAt: { [string]: number },
	history: { string }, -- senaste incidenterna, nyast sist
	previousShiftMajors: { string }, -- Major+ från förra skiftet
	incidentsThisNight: number,
	lastIncidentAt: number?,
	forecast: string?,
}

function DirectorLogic.rarityRank(rarity: string): number
	return table.find(RARITY_ORDER, rarity) or 1
end

local function activeCount(context: Context): number
	local n = 0
	for _ in context.active do
		n += 1
	end
	return n
end

-- Sannolikheten att en incident startar vid den här ticken (0..1).
function DirectorLogic.triggerChance(context: Context, config): number
	if activeCount(context) >= config.MaxConcurrent then
		return 0
	end
	if context.clock >= config.NoIncidentsAfterClock then
		return 0
	end

	local windowStart, windowEnd = config.FirstIncidentWindow[1], config.FirstIncidentWindow[2]
	if context.incidentsThisNight == 0 then
		if context.nightElapsed < windowStart then
			return 0
		elseif context.nightElapsed >= windowEnd then
			return 1 -- varje skift ska ha minst ett minnesvärt ögonblick
		end
		-- ökar linjärt genom fönstret
		return math.clamp((context.nightElapsed - windowStart) / (windowEnd - windowStart), 0.15, 1)
	end

	if context.lastIncidentAt and context.now - context.lastIncidentAt < config.MinGap then
		return 0
	end
	return math.clamp(config.BaseChancePerTick + config.HeatChanceBonus * context.serverHeat / 100, 0, 1)
end

-- Kan just den här incidenten hända nu?
function DirectorLogic.isEligible(id: string, def, context: Context, config): boolean
	if def.scope == "Twist" then
		return false
	end
	if context.active[id] then
		return false
	end
	if context.serverHeat < (def.minHeat or 0) or context.serverHeat > (def.maxHeat or 100) then
		return false
	end
	if context.clock < (def.minClock or 0) or context.clock > (def.maxClock or math.huge) then
		return false
	end
	if context.playerCount < (def.minPlayers or 1) then
		return false
	end
	local last = context.lastStartedAt[id]
	if last and context.now - last < (def.cooldown or 0) then
		return false
	end
	if
		config.MajorRepeatBlock
		and DirectorLogic.rarityRank(def.rarity) >= DirectorLogic.rarityRank("Major")
		and table.find(context.previousShiftMajors, id)
	then
		return false
	end
	if context.incidentsThisNight == 0 and config.FirstIncidentMaxRarity then
		if DirectorLogic.rarityRank(def.rarity) > DirectorLogic.rarityRank(config.FirstIncidentMaxRarity) then
			return false
		end
	end
	return true
end

-- Vikten för en möjlig incident inom sin klass.
local function incidentWeight(id: string, def, context: Context, config): number
	local weight = def.weight or 1
	if table.find(context.history, id) then
		weight *= config.RepeatPenalty
	end
	if context.forecast == id then
		weight *= config.ForecastBoost
	end
	return weight
end

export type Candidate = { id: string, def: any, weight: number }

-- Alla möjliga incidenter med sin slutliga sannolikhetsvikt (för val och för felsökning).
function DirectorLogic.candidates(definitions, context: Context, config): { Candidate }
	local byRarity: { [string]: { Candidate } } = {}
	local ids = {}
	for id in definitions do
		table.insert(ids, id)
	end
	table.sort(ids) -- stabil ordning = samma seed ger samma val

	for _, id in ids do
		local def = definitions[id]
		if DirectorLogic.isEligible(id, def, context, config) then
			byRarity[def.rarity] = byRarity[def.rarity] or {}
			table.insert(
				byRarity[def.rarity],
				{ id = id, def = def, weight = incidentWeight(id, def, context, config) }
			)
		end
	end

	-- Klassens vikt fördelas på incidenterna i klassen efter deras inbördes vikt.
	local result = {}
	for _, rarity in RARITY_ORDER do
		local list = byRarity[rarity]
		if list then
			local classWeight = config.RarityWeights[rarity] or 0
			local inner = 0
			for _, candidate in list do
				inner += candidate.weight
			end
			for _, candidate in list do
				local share = if inner > 0 then candidate.weight / inner else 0
				-- straff och prognos får påverka klassen lite, så upprepningar blir ovanligare
				local classScale = candidate.weight / (candidate.def.weight or 1)
				table.insert(result, {
					id = candidate.id,
					def = candidate.def,
					weight = classWeight * share * math.clamp(classScale, 0.25, config.ForecastBoost),
				})
			end
		end
	end
	return result
end

function DirectorLogic.choose(definitions, context: Context, config, rng): Candidate?
	local list = DirectorLogic.candidates(definitions, context, config)
	local chosen = rng:weighted(list, function(candidate)
		return candidate.weight
	end)
	return chosen
end

return DirectorLogic
