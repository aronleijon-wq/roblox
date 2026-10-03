-- Rewards: belöningsformeln. Ren logik utan Roblox-anrop så att den kan testas.
--
--   kontraktslön   = bas x svårighet x risknivå
--   riskbonus      = kontraktslön x (HEAT-faktor x incidentfaktor x squadfaktor - 1)
--   delsumma       = kontraktslön + riskbonus
--   extraktion     = delsumma x ExtractionBonus (bara om pengarna säkras)
--   total          = delsumma + extraktion + upptäckter + valfria mål - straff
--
-- Exempel från specen: bas 1000, risk x1.5, upptäckt +500, extraktion +20 % -> 2300.

local Rewards = {}

export type ContractPayParams = {
	base: number,
	difficulty: number?,
	tierRisk: number?,
	heat: number?,
	incidentModifier: number?,
	squadMembersNearby: number?,
	extracted: boolean,
	discoveries: number?,
	optionalBonus: number?,
	failureFraction: number?, -- 0..1, andel som förloras (misslyckat skift, nedslagen)
}

export type Breakdown = {
	contractPay: number,
	riskBonus: number,
	extractionBonus: number,
	discoveryBonus: number,
	optionalBonus: number,
	penalty: number,
	total: number,
}

function Rewards.heatFactor(heat: number, economy): number
	return 1 + math.clamp(heat, 0, 100) * economy.HeatRiskPerPoint
end

function Rewards.contract(params: ContractPayParams, economy): Breakdown
	local contractPay = params.base * (params.difficulty or 1) * (params.tierRisk or 1)
	local multiplier = Rewards.heatFactor(params.heat or 0, economy)
		* (params.incidentModifier or 1)
		* (1 + (params.squadMembersNearby or 0) * economy.SquadBonusPerMember)
	local riskBonus = contractPay * (multiplier - 1)
	local subtotal = contractPay + riskBonus
	local extractionBonus = if params.extracted then subtotal * economy.ExtractionBonus else 0
	local discoveryBonus = (params.discoveries or 0) * economy.DiscoveryBonus
	local optionalBonus = params.optionalBonus or 0

	local gross = subtotal + extractionBonus + discoveryBonus + optionalBonus
	local penalty = gross * math.clamp(params.failureFraction or 0, 0, 1)

	return {
		contractPay = math.floor(contractPay + 0.5),
		riskBonus = math.floor(riskBonus + 0.5),
		extractionBonus = math.floor(extractionBonus + 0.5),
		discoveryBonus = math.floor(discoveryBonus + 0.5),
		optionalBonus = math.floor(optionalBonus + 0.5),
		penalty = math.floor(penalty + 0.5),
		total = math.floor(gross - penalty + 0.5),
	}
end

-- Vad ett kontrakt visas som i erbjudandet (innan HEAT och bonusar).
function Rewards.offerValue(base: number, tierRisk: number): number
	return math.floor(base * tierRisk + 0.5)
end

return Rewards
