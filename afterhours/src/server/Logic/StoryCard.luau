-- StoryCard: bygger skiftrapporten som visas efter 03:00 ("AFTERHOURS REPORT").
-- Ren logik: tar emot vad som hände under skiftet och returnerar exakt vad kortet ska visa.

local HeatLogic = require(script.Parent.HeatLogic)

local StoryCard = {}

export type ShiftRecord = {
	shiftNumber: number,
	survived: boolean,
	contractsCompleted: number,
	peakHeat: number,
	itemsSecured: number,
	itemsLost: number,
	squadSize: number,
	squadSurvived: number,
	biggestIncident: { name: string, district: string }?,
	earnings: {
		contracts: number,
		items: number,
		risk: number,
		discovery: number,
		survival: number,
		penalty: number,
	},
	discoveries: { string },
	bestFind: { itemId: string, name: string, rarity: string }?,
	titlesEarned: { string },
}

function StoryCard.build(record: ShiftRecord, heatConfig)
	local e = record.earnings
	local total = e.contracts + e.items + e.risk + e.discovery + e.survival - e.penalty

	local lines = {
		{ label = "Contract Earnings", value = e.contracts },
		{ label = "Recovered Items", value = e.items },
		{ label = "Risk Bonus", value = e.risk },
	}
	if e.discovery > 0 then
		table.insert(lines, { label = "Discovery", value = e.discovery })
	end
	if e.survival > 0 then
		table.insert(lines, { label = "Made It Home", value = e.survival })
	end
	if e.penalty > 0 then
		table.insert(lines, { label = "Lost On The Street", value = -e.penalty })
	end

	local facts = {
		{ label = "Contracts completed", value = tostring(record.contractsCompleted) },
		{ label = "Risk level", value = HeatLogic.tier(record.peakHeat, heatConfig).name },
		{ label = "Items recovered", value = tostring(record.itemsSecured) },
		{ label = "Rare discovery", value = if record.bestFind or #record.discoveries > 0 then "YES" else "NO" },
	}
	if record.squadSize > 1 then
		table.insert(facts, { label = "Squad survival", value = record.squadSurvived .. "/" .. record.squadSize })
	end
	if record.itemsLost > 0 then
		table.insert(facts, { label = "Items lost", value = tostring(record.itemsLost) })
	end

	return {
		title = "AFTERHOURS REPORT",
		shift = "SHIFT #" .. record.shiftNumber,
		survived = record.survived,
		headline = if record.survived then "YOU SURVIVED 03:00" else "YOU DIDN'T MAKE IT BACK",
		facts = facts,
		biggestIncident = record.biggestIncident
			and (record.biggestIncident.name .. " - " .. string.upper(record.biggestIncident.district)),
		lines = lines,
		total = math.max(0, total),
		find = record.bestFind,
		discoveries = record.discoveries,
		titlesEarned = record.titlesEarned,
	}
end

return StoryCard
