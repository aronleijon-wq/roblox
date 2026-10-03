-- CASCADE FAILURE (Extreme): strömmen går OCH gator spärras samtidigt. Himlen blir röd.
-- Betalar mycket bra (rewardModifier), men HEAT rusar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blackout = require(script.Parent.Blackout)
local Lockdown = require(script.Parent.Lockdown)

local CascadeFailure = {}

function CascadeFailure.start(ctx)
	Blackout.apply(ctx)
	Lockdown.apply(ctx, 3)
	ReplicatedStorage:SetAttribute("RedSky", true)
end

function CascadeFailure.stop(ctx)
	Lockdown.remove(ctx)
	Blackout.remove(ctx)
	ReplicatedStorage:SetAttribute("RedSky", false)
	ctx.services.State.notifyAll("radio", "DISPATCH", "Systems are stabilizing. Anyone still out there, check in.", 5)
end

return CascadeFailure
