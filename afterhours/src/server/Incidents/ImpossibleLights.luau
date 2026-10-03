-- THE OTHER LIGHTS (Legendary): alla fönster i staden slocknar utom i Calloway Residences,
-- där de tänds i ett mönster som inte borde gå (klienterna ritar "03:00" i fasaden).
-- All kommunikation tystnar. Maskinrummet på taket, "19F", öppnas. Därinne ligger något.
-- Alla som var på servern kan säga: "jag var där" (titeln 03:00).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Helpers = require(script.Parent.IncidentHelpers)

local ImpossibleLights = {}

function ImpossibleLights.start(ctx)
	local services = ctx.services
	local tower = ctx.world.tower
	if not tower or not tower.machineRoom then
		return false
	end
	ReplicatedStorage:SetAttribute("OtherLights", true)
	ReplicatedStorage:SetAttribute("CommsDown", true)
	services.World.setOpenForAll("TowerMachineRoom", true)
	Helpers.setRoomLight(tower.machineRoom, true, Color3.fromRGB(110, 255, 214))
	ctx.data.drop =
		services.Loot.spawnDrop("TheObject", tower.objectCFrame.Position + Vector3.new(0, 0.4, 0), { despawns = false })
	ctx.client.position = tower.objectCFrame.Position
	for _, player in Players:GetPlayers() do
		if services.Data.isLoaded(player) then
			services.Progression.grantTitle(player, "ThreeAM")
		end
	end
	services.Npcs.react("Stare")
end

function ImpossibleLights.stop(ctx)
	local services = ctx.services
	local tower = ctx.world.tower
	ReplicatedStorage:SetAttribute("OtherLights", false)
	ReplicatedStorage:SetAttribute("CommsDown", false)
	if tower and tower.machineRoom then
		local room = tower.machineRoom
		Helpers.letOut(ctx, CFrame.new(room.center + Vector3.new(0, 4, 0)), room.size, "TowerMachineRoom", 30)
		Helpers.setRoomLight(room, false)
	end
	services.World.setOpenForAll("TowerMachineRoom", false)
	if ctx.data.drop then
		services.Loot.removeDrop(ctx.data.drop) -- om ingen tog det är det borta
	end
	services.Npcs.react("Normal")
end

return ImpossibleLights
