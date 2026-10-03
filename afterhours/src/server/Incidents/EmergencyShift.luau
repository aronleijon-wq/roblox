-- EMERGENCY SHIFT: alla kontrakt som slutförs nu betalar dubbelt (rewardModifier i config),
-- men HEAT stiger också mycket snabbare (dangerModifier). Själva effekten räknas i
-- IncidentService.rewardModifier/dangerModifier; modulen behöver bara säga till.

local EmergencyShift = {}

function EmergencyShift.start(ctx)
	ctx.client.multiplier = ctx.def.rewardModifier
	for _, player in game:GetService("Players"):GetPlayers() do
		ctx.services.State.mark(player, "contract")
	end
end

function EmergencyShift.stop(ctx)
	ctx.services.State.notifyAll("radio", "DISPATCH", "Emergency rates are over. Back to normal pay.", 4)
end

return EmergencyShift
