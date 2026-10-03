-- THE FOLLOWER: en okänd gestalt börjar följa spelaren med högst HEAT som är ute på gatan.
-- Den håller avstånd. Står man still kommer den närmare. Når den fram tar den något man bär
-- och är borta. I en säker zon tappar den intresset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)

local TheFollower = {}

function TheFollower.start(ctx)
	local services = ctx.services
	local target = services.Heat.hottestPlayer(function(player)
		return services.Security.alive(player) ~= nil and not services.Player.inZone(player, "Safe")
	end)
	if not target then
		return false
	end
	ctx.data.target = target
	local npc = services.Npcs.spawnFollower(target, {
		onReach = function()
			local stolen = services.Inventory.take(target, function(item)
				local def = ItemConfig.get(item.id)
				return item.contractId == nil and def ~= nil
			end)
			-- Den tar bara en sak; resten läggs tillbaka.
			for index, item in stolen do
				if index > 1 then
					services.Inventory.add(target, item.id)
				end
			end
			local taken = stolen[1] and ItemConfig.get(stolen[1].id)
			if taken then
				services.State.notify(target, "danger", "IT TOOK SOMETHING", "Your " .. taken.name .. " is gone.", 6)
			else
				services.State.notify(target, "danger", nil, "It was right behind you. Then it wasn't.", 6)
			end
			services.Incidents.stop("TheFollower")
		end,
		onLost = function()
			services.Incidents.stop("TheFollower")
		end,
	})
	if not npc then
		return false
	end
	ctx.data.npc = npc
	-- Bara målet får den obehagliga presentationen (radiobrus, vinjett).
	services.Remotes.WorldEvent:FireClient(target, { type = "Followed", on = true })
end

function TheFollower.stop(ctx)
	if ctx.data.npc then
		ctx.services.Npcs.despawn(ctx.data.npc)
	end
	if ctx.data.target and ctx.data.target.Parent then
		ctx.services.Remotes.WorldEvent:FireClient(ctx.data.target, { type = "Followed", on = false })
	end
end

return TheFollower
