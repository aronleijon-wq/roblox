-- CLOSED STATION: rullgallret till Line 3 står öppet i 90 sekunder. Därnere ligger sällsynt
-- loot. När gallret går ner igen är den som är kvar inne instängd, tills hen hittar
-- nödknappen vid servicetrappan.

local Helpers = require(script.Parent.IncidentHelpers)

local ClosedStation = {}

function ClosedStation.start(ctx)
	ctx.services.World.setOpenForAll("StationShutter", true)
	local station = ctx.world.station
	ctx.data.drops = {}
	if station and station.center then
		for k = 1, 3 do
			local itemId = ctx.services.Loot.roll("Station", ctx.rng)
			if itemId then
				local offset = Vector3.new(-50 + k * 25, 0.5, ctx.rng:number(-8, 0))
				table.insert(ctx.data.drops, ctx.services.Loot.spawnDrop(itemId, station.center + offset))
			end
		end
		ctx.client.position = station.center
	end
end

function ClosedStation.stop(ctx)
	ctx.services.World.setOpenForAll("StationShutter", false)
	local station = ctx.world.station
	if station and station.center then
		for _, player in
			Helpers.playersIn(ctx, CFrame.new(station.center + Vector3.new(0, 7, 0)), Vector3.new(142, 16, 64))
		do
			ctx.services.State.notify(
				player,
				"danger",
				"THE GATES CLOSED",
				"You're locked in. Find another way out.",
				7
			)
		end
	end
end

return ClosedStation
