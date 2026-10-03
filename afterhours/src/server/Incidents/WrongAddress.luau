-- WRONG ADDRESS (vändning när man hämtat ett paket): etiketten visar en annan adress än den
-- dispatch gav. Är det ett systemfel? Oftast leder den till biografens scendörr, som
-- plötsligt är olåst för just dig.

local WrongAddress = {}

function WrongAddress.start(ctx)
	local services = ctx.services
	local player = ctx.twist.player
	local candidates = {}
	for _, site in services.World.world.sitesByType.StageDoor or {} do
		table.insert(candidates, site)
	end
	if #candidates == 0 or not ctx.rng:chance(0.7) then
		for _, site in services.World.world.sitesByType.Doorstep or {} do
			if site.id ~= ctx.twist.siteId then
				table.insert(candidates, site)
			end
		end
	end
	local site = ctx.rng:pick(candidates)
	if not site or not services.Contracts.redirect(player, site.id) then
		return false
	end
	if site.siteType == "StageDoor" then
		services.World.grant(player, "TheaterStage", 240)
	end
	services.State.notify(
		player,
		"radio",
		"DISPATCH",
		"Correction... the label says " .. site.label .. ". That's not what I have. System error? Your call.",
		8
	)
end

function WrongAddress.stop(_ctx) end

return WrongAddress
