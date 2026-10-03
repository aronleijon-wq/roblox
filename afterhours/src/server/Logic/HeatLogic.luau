-- HeatLogic: HEAT-värdets regler. Ren logik, testbar.

local HeatLogic = {}

function HeatLogic.add(current: number, amount: number, heatConfig, dangerModifier: number?): number
	local scaled = if amount > 0 then amount * (dangerModifier or 1) else amount
	return math.clamp(current + scaled, 0, heatConfig.Max)
end

function HeatLogic.tier(heat: number, heatConfig)
	local current = heatConfig.Tiers[1]
	for _, tier in heatConfig.Tiers do
		if heat >= tier.min then
			current = tier
		end
	end
	return current
end

-- Serverns HEAT: blandning av medel och max, så att en enda vågad spelare märks
-- men inte ensam bestämmer allt för tolv andra.
function HeatLogic.serverHeat(values: { number }): number
	if #values == 0 then
		return 0
	end
	local sum, highest = 0, 0
	for _, value in values do
		sum += value
		highest = math.max(highest, value)
	end
	return (sum / #values) * 0.6 + highest * 0.4
end

return HeatLogic
