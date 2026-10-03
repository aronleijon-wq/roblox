-- ExtractionService: att komma hem.
--
--   * Lastkajen i depån (SECURE): lämna kontraktsföremål och säkra allt man bär och har tjänat.
--     Går att göra när som helst, så man kan välja att gå ut igen (risk mot belöning).
--   * 02:30 "SHIFT ENDING": alla får veta att de ska hem.
--   * 03:00: den som är i depån säkrar allt och får överlevnadsbonus. Den som är ute förlorar
--     sina föremål och en del av kontraktspengarna. Alla får sin skiftrapport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local StoryCard = require(script.Parent.Parent.Logic.StoryCard)

local ExtractionService = {}

local services
local LAST_ONE_OUT_SECONDS = 20

function ExtractionService.init(registry)
	services = registry
end

local function onSecure(player: Player)
	if services.Shift.phase() == Constants.Phases.Results then
		return
	end
	local delivered = services.Contracts.deliverToDepot(player)
	local secured = services.Economy.secure(player)
	if secured > 0 then
		services.State.notify(player, "good", "SECURED", "+" .. secured .. " credits", 4)
		services.Telemetry.event(player, "Secured", secured)
		local untilEnd = services.Shift.isNight()
			and (GameConfig.Shift.EndClock - services.Shift.clock())
				/ (GameConfig.Shift.EndClock - GameConfig.Shift.StartClock)
				* GameConfig.Shift.NightDuration
		if untilEnd and untilEnd <= LAST_ONE_OUT_SECONDS then
			services.Progression.grantTitle(player, "LastOneOut")
		end
	elseif not delivered then
		services.State.notify(player, "info", nil, "Nothing to secure. Go earn something.")
	end
end

local function shiftRecord(player: Player, survived: boolean, squadSize: number, squadSurvived: number)
	local ledger = services.Economy.ledger(player)
	local data = services.Data.get(player)
	local s = ledger.secured
	return {
		shiftNumber = (data and data.stats.shifts or 0) + 1,
		survived = survived,
		contractsCompleted = ledger.contractsCompleted,
		peakHeat = ledger.peakHeat,
		itemsSecured = ledger.itemsSecured,
		itemsLost = ledger.itemsLost,
		squadSize = squadSize,
		squadSurvived = squadSurvived,
		biggestIncident = services.Incidents.biggestThisShift(),
		earnings = {
			contracts = s.contracts,
			items = s.items,
			risk = s.risk,
			discovery = s.discovery,
			survival = s.survival,
			penalty = s.penalty,
		},
		discoveries = ledger.discoveries,
		bestFind = ledger.bestFind,
		titlesEarned = ledger.titles,
	}
end

local function onShiftEnded()
	local results: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if services.Data.isLoaded(player) and services.Economy.ledger(player) then
			local safe = services.Security.alive(player) ~= nil and services.Player.inZone(player, "Extraction")
			results[player] = safe
			if safe then
				services.Economy.survive(player)
				services.Progression.addReputation(player, "SuccessfulExtraction")
				services.Data.update(player, function(data)
					data.stats.extractions += 1
				end)
				services.Telemetry.onboarding(player, "FirstExtraction")
				local data = services.Data.get(player)
				if data.stats.extractions >= 5 then
					services.Progression.grantTitle(player, "NightRunner")
				end
				if
					services.Incidents.happenedThisShift("Blackout")
					or services.Incidents.happenedThisShift("CascadeFailure")
				then
					services.Progression.grantTitle(player, "BlackoutSurvivor")
				end
			else
				services.Economy.fail(player)
				services.Progression.addReputation(player, "FailedShift")
				services.Data.update(player, function(data)
					data.stats.failures += 1
				end)
				services.Telemetry.event(player, "FirstFailure", 1)
			end
		end
	end

	for player, survived in results do
		local squadSize, squadSurvived = 1, if survived then 1 else 0
		local members = services.Squads.membersOf(player)
		if #members > 1 then
			squadSize, squadSurvived = #members, 0
			for _, member in members do
				if results[member] then
					squadSurvived += 1
				end
			end
		end
		local record = shiftRecord(player, survived, squadSize, squadSurvived)
		local card = StoryCard.build(record, GameConfig.Heat)
		services.Remotes.ShiftReport:FireClient(player, card)
		services.Data.update(player, function(data)
			data.stats.shifts += 1
			data.stats.bestShift = math.max(data.stats.bestShift, card.total)
		end)
		services.Telemetry.event(player, "ShiftEnded", card.total, {
			survived = survived,
			heat = math.floor(record.peakHeat),
			contracts = record.contractsCompleted,
		})
		services.State.mark(player, "profile")
	end
end

function ExtractionService.start()
	services.Interaction.register(Constants.Actions.Secure, onSecure)
	services.Shift.ShiftEnding:Connect(function()
		services.State.notifyAll("danger", "SHIFT ENDING", GameConfig.Onboarding.ShiftEndingHint, 8)
	end)
	services.Shift.ShiftEnded:Connect(onShiftEnded)
	-- När hubben öppnar igen hämtas alla som inte kom hem till depån.
	services.Shift.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Hub then
			for _, player in Players:GetPlayers() do
				if services.Data.isLoaded(player) and not services.Player.inZone(player, "Extraction") then
					task.spawn(services.Player.spawn, player)
				end
			end
		end
	end)
end

return ExtractionService
