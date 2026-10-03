-- LootLogic: väljer föremål ur en loottabell. Högre HEAT flyttar vikterna mot sällsyntare saker.

local LootLogic = {}

-- itemRank(itemId) -> 1..6 (sällsynthetens plats i ordningen)
function LootLogic.weightFor(entry, heat: number, heatShift: number, itemRank: (string) -> number): number
	local rank = itemRank(entry.item)
	return entry.weight * (1 + heatShift * math.clamp(heat, 0, 100) / 100 * (rank - 1))
end

function LootLogic.roll(lootTable, heat: number, heatShift: number, itemRank: (string) -> number, rng): string?
	local entry = rng:weighted(lootTable, function(e)
		return LootLogic.weightFor(e, heat, heatShift, itemRank)
	end)
	return entry and entry.item
end

return LootLogic
