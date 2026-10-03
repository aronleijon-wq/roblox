-- SOMETHING INSIDE (vändning efter t.ex. en reparation): ljuset kommer tillbaka på gatan,
-- och en byggnad i närheten som alltid varit stängd står plötsligt öppen. Ett ljud inifrån.
-- Spelaren väljer: undersöka, gå därifrån, ringa in squaden eller strunta i det.
-- Dörren är öppen för alla, så någon annan kan hinna före.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Helpers = require(script.Parent.IncidentHelpers)

local LightsReturn = {}

local function outcome(ctx, player: Player)
	local services = ctx.services
	local room = ctx.data.room
	local roll = ctx.rng:number()
	if roll < 0.45 then
		for _ = 1, 2 do
			local itemId = services.Loot.roll("Restricted", ctx.rng)
			if itemId then
				services.Loot.spawnDrop(
					itemId,
					room.center + Vector3.new(ctx.rng:number(-3, 3), 0, ctx.rng:number(-3, 3))
				)
			end
		end
		services.State.notify(
			player,
			"good",
			"SOMEONE LEFT IN A HURRY",
			"Whatever they were doing in here, they left things behind.",
			6
		)
	elseif roll < 0.7 then
		services.Npcs.spawnStatic("MissingWorker", CFrame.new(room.center + Vector3.new(2, 3, 2)), 25)
		services.Economy.addContract(player, {
			templateId = "MissingWorker",
			title = "Found a missing worker",
			tier = "Normal",
			base = 400,
			tierRisk = 1,
			heat = services.Heat.get(player),
			incidentModifier = 1,
			squadNearby = 0,
			penalty = 0,
		})
		services.Progression.addReputation(player, "ContractNormal")
		services.State.notify(
			player,
			"good",
			"MISSING WORKER",
			"A night worker was hiding in here. Dispatch is sending a car. (+400, unsecured)",
			7
		)
	elseif roll < 0.9 then
		services.Heat.add(player, GameConfig.Heat.Gain.Anomaly, "anomaly")
		services.Remotes.WorldEvent:FireAllClients({ type = "Anomaly", position = room.center })
		Helpers.setRoomLight(room, true, Color3.fromRGB(255, 40, 40))
		task.delay(2.5, function()
			Helpers.setRoomLight(room, false)
		end)
		local itemId = services.Loot.roll("Restricted", ctx.rng)
		if itemId then
			services.Loot.spawnDrop(itemId, room.center)
		end
		services.State.notify(player, "danger", "WHAT WAS THAT?", "The light went red. Then out. Your HEAT spiked.", 6)
	else
		services.Loot.spawnDrop("SealedLetter", room.center)
		services.Progression.discover(player, "NoteFromThreeAM", "A note from the 3am shift")
		services.State.notify(
			player,
			"discovery",
			"JUST A NOTE",
			"Nothing here but an envelope with your shift on it.",
			6
		)
	end
end

function LightsReturn.start(ctx)
	local services = ctx.services
	local player = ctx.twist.player
	local site = services.World.site(ctx.twist.siteId)
	if not site then
		return false
	end
	local room = Helpers.nearestTwistRoom(ctx, site.position, 260)
	if not room or room.busy then
		return false
	end
	room.busy = true
	ctx.data.room = room
	services.World.setOpenForAll(room.gateId, true)
	Helpers.setRoomLight(room, true)
	services.Remotes.WorldEvent:FireAllClients({ type = "StreetSurge", position = site.position })
	services.Remotes.WorldEvent:FireAllClients({ type = "Sound", cue = "Knock", position = room.center })

	local anchor = Instance.new("Part")
	anchor.Name = "InvestigateAnchor"
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = CFrame.new(room.center + Vector3.new(0, 2, 0))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = room.door.Parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Investigate"
	prompt.ObjectText = "The source"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", Constants.Actions.Investigate)
	prompt:SetAttribute("Target", ctx.key)
	prompt.Parent = anchor
	ctx.data.anchor = anchor
	services.Interaction.register(Constants.Actions.Investigate .. ":" .. ctx.key, function(investigator)
		if ctx.data.resolved then
			return
		end
		ctx.data.resolved = true
		prompt.Enabled = false
		outcome(ctx, investigator)
	end)

	services.Remotes.WorldEvent:FireClient(player, {
		type = "TwistChoice",
		key = ctx.key,
		title = "SOMETHING INSIDE",
		text = "The lights came back on. The door to " .. room.label .. " just opened. Something is moving in there.",
		position = room.center,
		options = {
			{ id = "investigate", label = "Investigate" },
			{ id = "leave", label = "Leave" },
			{ id = "call", label = "Call team" },
			{ id = "ignore", label = "Ignore" },
		},
	})
end

function LightsReturn.choice(ctx, player: Player, choice: string)
	local services = ctx.services
	local room = ctx.data.room
	if choice == "investigate" then
		services.Remotes.WorldEvent:FireClient(
			player,
			{ type = "SoftObjective", text = "Investigate the source", position = room.center }
		)
	elseif choice == "call" then
		local members = services.Squads.membersOf(player)
		local called = 0
		for _, member in members do
			if member ~= player then
				called += 1
				services.State.notify(
					member,
					"radio",
					player.DisplayName,
					"Get over here. Something's inside " .. room.label .. ".",
					7
				)
				services.Remotes.WorldEvent:FireClient(
					member,
					{ type = "SoftObjective", text = "Help " .. player.DisplayName, position = room.center }
				)
			end
		end
		if called == 0 then
			services.State.notify(
				player,
				"info",
				nil,
				"No squad to call. Form one in DISPATCH. You're on your own tonight."
			)
		end
	end
end

function LightsReturn.stop(ctx)
	local room = ctx.data.room
	if not room then
		return
	end
	Helpers.letOut(ctx, CFrame.new(room.center + Vector3.new(0, 4, 0)), room.size, room.gateId, 30)
	ctx.services.World.setOpenForAll(room.gateId, false)
	Helpers.setRoomLight(room, false)
	if ctx.data.anchor then
		ctx.data.anchor:Destroy()
	end
	room.busy = false
end

return LightsReturn
