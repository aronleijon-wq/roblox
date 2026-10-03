-- FALSE ALARM: ett larm går i en byggnad. Den som kollar panelen får veta om det var falskt.
-- Oftast är det det. Ibland är det inte det, och en dörr i närheten står plötsligt öppen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Helpers = require(script.Parent.IncidentHelpers)

local FalseAlarm = {}

local REAL_CHANCE = 0.3

function FalseAlarm.start(ctx)
	local panels = {}
	for _, panel in ctx.world.alarmPanels do
		table.insert(panels, panel)
	end
	table.sort(panels, function(a, b)
		return a.id < b.id
	end)
	local panel = ctx.rng:pick(panels)
	if not panel then
		return false
	end
	ctx.data.panel = panel
	ctx.data.siteLabel = panel.label
	ctx.client.position = panel.part.CFrame.Position
	ctx.client.label = panel.label
	panel.led.Color = Color3.fromRGB(255, 40, 40)
	panel.led:SetAttribute("Alarm", true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AlarmPrompt"
	prompt.ActionText = "Check alarm"
	prompt.ObjectText = "Alarm panel"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", Constants.Actions.Investigate)
	prompt:SetAttribute("Target", "FalseAlarm")
	prompt.Parent = panel.part
	ctx.data.prompt = prompt

	ctx.services.Interaction.register(Constants.Actions.Investigate .. ":FalseAlarm", function(player)
		if ctx.data.resolved then
			return
		end
		ctx.data.resolved = true
		local services = ctx.services
		services.Heat.add(player, GameConfig.Heat.Gain.AlarmTriggered, "alarm")
		if ctx.rng:chance(REAL_CHANCE) then
			local room = Helpers.nearestTwistRoom(ctx, panel.part.CFrame.Position, 400)
			if room then
				services.World.grant(player, room.gateId, 120)
				Helpers.setRoomLight(room, true, Color3.fromRGB(255, 80, 70))
				ctx.data.room = room
				for _ = 1, 2 do
					local itemId = services.Loot.roll("Interior", ctx.rng)
					if itemId then
						services.Loot.spawnDrop(
							itemId,
							room.center + Vector3.new(ctx.rng:number(-3, 3), 0, ctx.rng:number(-3, 3))
						)
					end
				end
				services.State.notify(
					player,
					"danger",
					"IT WASN'T FALSE",
					"Something tripped that alarm. The door to " .. room.label .. " is open.",
					7
				)
			end
		else
			services.Economy.addContract(player, {
				templateId = "AlarmCheck",
				title = "Alarm check",
				tier = "Safe",
				base = 150,
				tierRisk = 1,
				heat = services.Heat.get(player),
				incidentModifier = 1,
				squadNearby = 0,
				penalty = 0,
			})
			services.State.notify(
				player,
				"info",
				"FALSE ALARM",
				"Panel reset. Dispatch adds a callout fee (+150, unsecured).",
				5
			)
		end
		task.delay(1, function()
			services.Incidents.stop("FalseAlarm")
		end)
	end)
end

function FalseAlarm.stop(ctx)
	local panel = ctx.data.panel
	if panel then
		panel.led.Color = Color3.fromRGB(40, 255, 80)
		panel.led:SetAttribute("Alarm", false)
	end
	if ctx.data.prompt then
		ctx.data.prompt:Destroy()
	end
	if ctx.data.room then
		Helpers.setRoomLight(ctx.data.room, false)
	end
end

return FalseAlarm
