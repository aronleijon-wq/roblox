-- OVERLOAD (vändning efter att man reparerat ställverkets kärna): reparationen gick för bra.
-- Kärnan överbelastas och Downtown släcks (startar BLACKOUT).

local Overload = {}

function Overload.start(ctx)
	local services = ctx.services
	if services.Incidents.isActive("Blackout") or services.Incidents.isActive("CascadeFailure") then
		return false
	end
	services.State.notify(ctx.twist.player, "danger", "OVERLOAD", "The core is screaming. Get clear.", 4)
	task.delay(2, function()
		services.Incidents.trigger("Blackout", { reason = "Overload" })
	end)
end

function Overload.stop(_ctx) end

return Overload
