-- UNKNOWN PACKAGE: en spelare får ett paket utan avsändare i inventariet. Det tar en plats.
-- En lapp säger vart det ska. Den som tar det dit får något sällsynt. Annars försvinner det.

local Players = game:GetService("Players")

local UnknownPackage = {}

local DELIVERY_RADIUS = 14

function UnknownPackage.start(ctx)
	local services = ctx.services
	local candidates = {}
	for _, player in Players:GetPlayers() do
		if services.Security.alive(player) and not services.Inventory.isFull(player) then
			table.insert(candidates, player)
		end
	end
	table.sort(candidates, function(a, b)
		return a.UserId < b.UserId
	end)
	local target = ctx.rng:pick(candidates)
	local site = services.World.site("TowerRelay")
	if not target or not site then
		return false
	end
	ctx.data.customRadio = true
	ctx.data.target = target
	ctx.data.contractId = "PKG" .. ctx.seed
	services.Inventory.add(target, "UnmarkedPackage", ctx.data.contractId)
	services.State.notify(
		target,
		"discovery",
		"UNKNOWN PACKAGE",
		"Something is in your bag that you didn't put there. A note: 'TOP OF CALLOWAY. BEFORE IT GETS LIGHT.'",
		10
	)

	ctx.data.running = true
	task.spawn(function()
		while ctx.data.running do
			task.wait(1)
			local position = services.Security.position(target)
			if position and (position - site.position).Magnitude <= DELIVERY_RADIUS then
				local taken = services.Inventory.take(target, function(item)
					return item.contractId == ctx.data.contractId
				end)
				if #taken > 0 then
					ctx.data.delivered = true
					local reward = services.Loot.roll("Secret", ctx.rng)
					if reward then
						services.Loot.spawnDrop(reward, site.position + Vector3.new(0, -1, 0))
					end
					services.Progression.discover(target, "PackageDelivered", "Delivered the unknown package")
					services.State.notify(
						target,
						"discovery",
						"DELIVERED",
						"The package is gone. Something was left in its place.",
						7
					)
					services.Incidents.stop("UnknownPackage")
				end
			end
		end
	end)
end

function UnknownPackage.stop(ctx)
	ctx.data.running = false
	local target = ctx.data.target
	if target and target.Parent and not ctx.data.delivered then
		local removed = ctx.services.Inventory.take(target, function(item)
			return item.contractId == ctx.data.contractId
		end)
		if #removed > 0 then
			ctx.services.State.notify(target, "info", nil, "The package is gone. You never heard it leave.", 6)
		end
	end
end

return UnknownPackage
