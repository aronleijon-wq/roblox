-- LOCKDOWN: polisen spärrar av flera gator. Vägen hem är kanske inte längre den kortaste.

local Helpers = require(script.Parent.IncidentHelpers)

local Lockdown = {}

local BARRIERS = 4

-- Delas med CASCADE FAILURE.
function Lockdown.apply(ctx, count: number)
	local barriers = ctx.rng:shuffled(ctx.world.barriers)
	ctx.data.barriers = {}
	local names = {}
	for index = 1, math.min(count, #barriers) do
		local spec = barriers[index]
		table.insert(ctx.data.barriers, Helpers.barrier(spec))
		table.insert(names, spec.name)
	end
	ctx.client.streets = names
	return names
end

function Lockdown.remove(ctx)
	for _, model in ctx.data.barriers or {} do
		model:Destroy()
	end
	ctx.data.barriers = {}
end

function Lockdown.start(ctx)
	Lockdown.apply(ctx, BARRIERS)
end

function Lockdown.stop(ctx)
	Lockdown.remove(ctx)
	ctx.services.State.notifyAll("radio", "DISPATCH", "Lockdown lifted. Streets are open.", 4)
end

return Lockdown
