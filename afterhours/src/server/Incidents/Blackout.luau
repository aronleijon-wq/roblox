-- BLACKOUT: strömmen går i Downtown. Klienterna släcker fönster och gatlyktor och tänder
-- nödljusen. Biografens scendörr (som drivs av el) går upp: en ny väg öppnas.
-- NPC:erna reagerar (se NpcService.react).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Helpers = require(script.Parent.IncidentHelpers)

local Blackout = {}

-- Delas med CASCADE FAILURE.
function Blackout.apply(ctx)
	ReplicatedStorage:SetAttribute("PowerOut", true)
	ctx.services.World.setOpenForAll("TheaterStage", true)
	local substation = ctx.world.substation
	if substation and substation.glow then
		substation.glow.Material = Enum.Material.SmoothPlastic
		substation.glow.Color = Color3.fromRGB(30, 34, 40)
		local light = substation.glow:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
	end
	ctx.services.Npcs.react("Blackout")
end

function Blackout.remove(ctx)
	ReplicatedStorage:SetAttribute("PowerOut", false)
	local theater = ctx.world.theater
	if theater and theater.center then
		Helpers.letOut(
			ctx,
			CFrame.new(theater.center + Vector3.new(0, 13, 0)),
			Vector3.new(80, 26, 50),
			"TheaterStage",
			45
		)
	end
	ctx.services.World.setOpenForAll("TheaterStage", false)
	local substation = ctx.world.substation
	if substation and substation.glow then
		substation.glow.Material = Enum.Material.Neon
		substation.glow.Color = Color3.fromRGB(80, 170, 255)
		local light = substation.glow:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
	end
	ctx.services.Npcs.react("Normal")
end

function Blackout.start(ctx)
	Blackout.apply(ctx)
end

function Blackout.stop(ctx)
	Blackout.remove(ctx)
	ctx.services.State.notifyAll(
		"radio",
		"DISPATCH",
		"Power is coming back on. Whatever you saw in the dark, log it.",
		5
	)
end

return Blackout
