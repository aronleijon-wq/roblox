-- ContractService: kontrakt från dispatch. Erbjudanden skapas från mallar i ContractConfig
-- och platser i staden; inget uppdrag är handskrivet. Ett kontrakt är en lista med steg
-- (Interact / Pickup / Deliver). Servern avgör allt: klienten kan bara be om att acceptera,
-- avbryta eller byta erbjudanden, och interagera via prompts som servern kontrollerar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ContractConfig = require(script.Parent.Parent.Config.ContractConfig)
local ContractLogic = require(script.Parent.Parent.Logic.ContractLogic)
local Rewards = require(script.Parent.Parent.Logic.Rewards)

local ContractService = {}

ContractService.Completed = Signal.new() -- (player, contract, template)

type Contract = {
	id: string,
	templateId: string,
	tier: string,
	siteId: string,
	overrideSiteId: string?,
	stepIndex: number,
	acceptedAt: number,
	grants: { string },
}

local active: { [Player]: Contract } = {}
local offers: { [Player]: { any } } = {}
local lastReroll: { [Player]: number } = {}
local siteOwner: { [string]: Player } = {}
local prompts: { [string]: ProximityPrompt } = {}
local idCounter = 0
local services

local DEPOT_PICKUP = "DepotShelf"

local function templateOf(contract: Contract)
	return ContractLogic.findTemplate(ContractConfig, contract.templateId)
end

local function stepOf(contract: Contract)
	return templateOf(contract).steps[contract.stepIndex]
end

local function contractSite(contract: Contract): string
	return contract.overrideSiteId or contract.siteId
end

-- Platsen för ett steg: depåns hylla, depåns lastkaj ("Depot") eller kontraktets plats.
local function siteForStep(contract: Contract, step): string
	if step.kind == "Pickup" and step.at == "Depot" then
		return DEPOT_PICKUP
	elseif step.kind == "Deliver" and step.to == "Depot" then
		return "Depot"
	end
	return contractSite(contract)
end

local function stepText(contract: Contract, step): string
	local site = services.World.site(contractSite(contract))
	local label = if site then site.label else "the site"
	local item = step.item and ItemConfig.get(step.item)
	local itemName = if item then item.name else "the item"
	if step.kind == "Interact" then
		return step.prompt .. " at " .. label
	elseif step.kind == "Pickup" then
		return if step.at == "Depot"
			then "Collect the " .. itemName .. " at the depot shelf"
			else "Pick up the " .. itemName .. " at " .. label
	elseif step.kind == "Deliver" then
		return if step.to == "Depot"
			then "Bring the " .. itemName .. " to the depot loading bay"
			else "Deliver the " .. itemName .. " to " .. label
	end
	return label
end

local function resetPrompt(siteId: string)
	local prompt = prompts[siteId]
	if prompt then
		prompt.ActionText = "Work"
		prompt.ObjectText = ""
		prompt.HoldDuration = 1
	end
end

local function configurePrompt(contract: Contract)
	local step = stepOf(contract)
	if not step then
		return
	end
	local siteId = siteForStep(contract, step)
	local prompt = prompts[siteId]
	if prompt and siteId ~= DEPOT_PICKUP then
		prompt.ActionText = step.prompt or "Work"
		prompt.ObjectText = templateOf(contract).title
		prompt.HoldDuration = step.hold or 1
	end
end

local function markAll(player: Player)
	services.State.mark(player, "contract")
	services.State.mark(player, "offers")
end

function ContractService.active(player: Player): Contract?
	return active[player]
end

function ContractService.generateOffers(player: Player)
	local busy = {}
	for siteId in siteOwner do
		busy[siteId] = true
	end
	offers[player] = ContractLogic.generateOffers(ContractConfig, services.World.world.sitesByType, {
		rng = Rng.new(player.UserId % 100000 + os.time() % 100000 + idCounter),
		hasLicense = function(license)
			return services.Progression.hasLicense(player, license)
		end,
		busySites = busy,
		nextId = function()
			idCounter += 1
			return "O" .. idCounter
		end,
	})
	services.State.mark(player, "offers")
end

function ContractService.refreshOffers(player: Player)
	if not active[player] then
		ContractService.generateOffers(player)
	end
end

-- Släpper kontraktet: plats, prompt, tillträde och kontraktsföremål.
local function release(player: Player, revokeDelay: number?)
	local contract = active[player]
	if not contract then
		return
	end
	active[player] = nil
	for _, siteId in { contract.siteId, contract.overrideSiteId } do
		if siteId and siteOwner[siteId] == player then
			siteOwner[siteId] = nil
			resetPrompt(siteId)
		end
	end
	services.Inventory.take(player, function(item)
		return item.contractId == contract.id
	end)
	local grants = contract.grants
	local function revoke()
		for _, gateId in grants do
			services.World.revoke(player, gateId)
		end
	end
	if revokeDelay and revokeDelay > 0 then
		task.delay(revokeDelay, revoke)
	else
		revoke()
	end
	markAll(player)
end

-- En vändning (WRONG ADDRESS) kan skicka kontraktet till en annan plats.
function ContractService.redirect(player: Player, siteId: string): boolean
	local contract = active[player]
	if not contract or siteOwner[siteId] then
		return false
	end
	local previous = contractSite(contract)
	if siteOwner[previous] == player then
		siteOwner[previous] = nil
		resetPrompt(previous)
	end
	contract.overrideSiteId = siteId
	siteOwner[siteId] = player
	configurePrompt(contract)
	markAll(player)
	return true
end

local function maybeTwist(player: Player, contract: Contract, completedStep: number?)
	local template = templateOf(contract)
	for _, twist in template.twists or {} do
		if twist.onStep == completedStep and math.random() < twist.chance then
			services.Incidents.startTwist(twist.id, {
				player = player,
				contract = contract,
				template = template,
				siteId = contractSite(contract),
			})
		end
	end
end

local function complete(player: Player)
	local contract = active[player]
	if not contract then
		return
	end
	local template = templateOf(contract)
	local tier = ContractConfig.Tiers[contract.tier]
	local heat = services.Heat.get(player)
	local entry = {
		templateId = template.id,
		title = template.title,
		tier = contract.tier,
		base = template.baseReward,
		tierRisk = tier.riskMultiplier,
		heat = heat,
		incidentModifier = services.Incidents.rewardModifier(),
		squadNearby = services.Squads.nearbyCount(player, GameConfig.Economy.SquadBonusRadius),
		penalty = 0,
	}
	services.Economy.addContract(player, entry)
	services.Progression.addReputation(player, tier.reputation)
	services.Data.update(player, function(data)
		data.stats.contracts += 1
		if contract.tier == "HighRisk" then
			data.stats.highRiskContracts += 1
		end
	end)
	services.Telemetry.onboarding(player, "FirstContractCompleted")
	services.Telemetry.event(player, "ContractCompleted", entry.base, { tier = contract.tier, template = template.id })
	if services.Incidents.anyActive() then
		services.Progression.grantTitle(player, "FirstResponder")
	end
	if contract.tier == "HighRisk" and heat >= 80 then
		services.Progression.grantTitle(player, "DeepShift")
	end

	local preview = Rewards.contract({
		base = entry.base,
		tierRisk = entry.tierRisk,
		heat = entry.heat,
		incidentModifier = entry.incidentModifier,
		squadMembersNearby = entry.squadNearby,
		extracted = true,
	}, GameConfig.Economy).total
	services.State.notify(
		player,
		"good",
		"CONTRACT COMPLETE",
		"+" .. preview .. " cr (unsecured). Secure it at the depot.",
		6
	)

	maybeTwist(player, contract, nil)
	ContractService.Completed:Fire(player, contract, template)
	release(player, 60)
	ContractService.generateOffers(player)
end

local function advance(player: Player, contract: Contract)
	local finished = contract.stepIndex
	contract.stepIndex += 1
	maybeTwist(player, contract, finished)
	if active[player] ~= contract then
		return -- vändningen avslutade kontraktet
	end
	if contract.stepIndex > #templateOf(contract).steps then
		complete(player)
		return
	end
	configurePrompt(contract)
	services.State.notify(player, "radio", "DISPATCH", stepText(contract, stepOf(contract)), 5)
	markAll(player)
end

local function onSite(player: Player, _prompt: ProximityPrompt, siteId: string?)
	local contract = active[player]
	if not contract or not siteId or services.Shift.phase() == Constants.Phases.Results then
		return
	end
	local step = stepOf(contract)
	if not step or siteForStep(contract, step) ~= siteId then
		return
	end
	if step.kind == "Interact" then
		advance(player, contract)
	elseif step.kind == "Pickup" then
		if services.Inventory.add(player, step.item, contract.id) then
			advance(player, contract)
		else
			services.State.notify(player, "warning", "INVENTORY FULL", GameConfig.Onboarding.InventoryFullHint)
		end
	elseif step.kind == "Deliver" then
		local delivered = services.Inventory.take(player, function(item)
			return item.contractId == contract.id and item.id == step.item
		end)
		if #delivered > 0 then
			advance(player, contract)
		else
			services.State.notify(
				player,
				"warning",
				nil,
				"You don't have the " .. ItemConfig.get(step.item).name .. "."
			)
		end
	end
end

-- Anropas av lastkajen: lämnar ett kontraktsföremål som ska till depån.
function ContractService.deliverToDepot(player: Player): boolean
	local contract = active[player]
	local step = contract and stepOf(contract)
	if not contract or not step or step.kind ~= "Deliver" or step.to ~= "Depot" then
		return false
	end
	local delivered = services.Inventory.take(player, function(item)
		return item.contractId == contract.id and item.id == step.item
	end)
	if #delivered == 0 then
		return false
	end
	advance(player, contract)
	return true
end

local function accept(player: Player, offerId: any)
	if not services.Security.isString(offerId, 24) then
		return
	end
	if services.Shift.phase() == Constants.Phases.Results then
		return
	end
	if active[player] then
		services.State.notify(player, "warning", nil, "Finish or abandon your current contract first.")
		return
	end
	local offer
	for _, candidate in offers[player] or {} do
		if candidate.offerId == offerId then
			offer = candidate
		end
	end
	if not offer or offer.locked then
		return
	end
	if siteOwner[offer.siteId] then
		ContractService.generateOffers(player)
		services.State.notify(player, "warning", nil, "Someone else just took that job. Dispatch sent new offers.")
		return
	end
	local template = ContractLogic.findTemplate(ContractConfig, offer.templateId)
	local tier = ContractConfig.Tiers[offer.tier]
	idCounter += 1
	local contract: Contract = {
		id = "C" .. idCounter,
		templateId = offer.templateId,
		tier = offer.tier,
		siteId = offer.siteId,
		overrideSiteId = nil,
		stepIndex = 1,
		acceptedAt = os.clock(),
		grants = template.grantsAccess or {},
	}
	active[player] = contract
	siteOwner[offer.siteId] = player
	offers[player] = {}
	for _, gateId in contract.grants do
		services.World.grant(player, gateId)
	end
	services.Heat.add(player, GameConfig.Heat.Gain[tier.heatOnAccept] or 0, "accept " .. offer.tier)
	configurePrompt(contract)
	markAll(player)
	services.Telemetry.onboarding(player, "FirstContractAccepted")
	services.Telemetry.event(
		player,
		"ContractAccepted",
		offer.reward,
		{ tier = offer.tier, template = offer.templateId }
	)
	services.State.notify(player, "radio", "DISPATCH", offer.brief, 7)
end

function ContractService.init(registry)
	services = registry
	-- En prompt per kontraktsplats. Klienten visar bara prompten för sitt eget kontrakt.
	local used = { [DEPOT_PICKUP] = true, StageDoor = true }
	for _, template in ContractConfig.Templates do
		used[template.siteType] = true
	end
	for siteId, site in services.World.world.sites do
		if used[site.siteType] or used[siteId] then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ContractPrompt"
			prompt.ActionText = if siteId == DEPOT_PICKUP then "Take parcel" else "Work"
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = GameConfig.Contracts.InteractDistance
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt:SetAttribute("Action", Constants.Actions.ContractSite)
			prompt:SetAttribute("Target", siteId)
			prompt.Parent = site.part
			prompts[siteId] = prompt
		end
	end
end

function ContractService.start()
	services.Interaction.register(Constants.Actions.ContractSite, onSite)
	services.Security.on(services.Remotes.AcceptContract, "AcceptContract", accept)
	services.Security.on(services.Remotes.AbandonContract, "AbandonContract", function(player)
		if active[player] then
			release(player, 0)
			ContractService.generateOffers(player)
			services.State.notify(player, "info", "DISPATCH", "Contract abandoned. New offers are on the board.")
		end
	end)
	services.Security.on(services.Remotes.RerollContracts, "RerollContracts", function(player)
		local now = os.clock()
		if
			active[player] or (lastReroll[player] and now - lastReroll[player] < GameConfig.Contracts.RerollCooldown)
		then
			return
		end
		lastReroll[player] = now
		ContractService.generateOffers(player)
	end)

	services.Player.Ready:Connect(function(player)
		ContractService.generateOffers(player)
	end)
	services.Player.Leaving:Connect(function(player)
		release(player, 0)
		offers[player] = nil
		lastReroll[player] = nil
	end)
	-- Nedslagen: kontraktsföremålet går tillbaka dit det hämtades och steget börjar om.
	services.Player.Downed:Connect(function(player)
		local contract = active[player]
		if not contract then
			return
		end
		local lost = services.Inventory.take(player, function(item)
			return item.contractId == contract.id
		end)
		if #lost > 0 then
			for index, step in templateOf(contract).steps do
				if step.kind == "Pickup" and step.item == lost[1].id then
					contract.stepIndex = index
				end
			end
			configurePrompt(contract)
			markAll(player)
			services.State.notify(
				player,
				"warning",
				"DISPATCH",
				"You lost the " .. ItemConfig.get(lost[1].id).name .. ". It went back where you found it."
			)
		end
	end)
	-- Vid 03:00 misslyckas ofärdiga kontrakt. Nya erbjudanden när hubben öppnar.
	services.Shift.ShiftEnded:Connect(function()
		for player in active do
			release(player, 0)
		end
	end)
	services.Shift.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Hub then
			for _, player in Players:GetPlayers() do
				if services.Data.isLoaded(player) then
					release(player, 0)
					ContractService.generateOffers(player)
				end
			end
		end
	end)

	services.State.register("offers", function(player)
		local list = {}
		for _, offer in offers[player] or {} do
			local tier = ContractConfig.Tiers[offer.tier]
			table.insert(list, {
				offerId = offer.offerId,
				title = offer.title,
				brief = offer.brief,
				tier = offer.tier,
				tierLabel = tier.label,
				riskLabel = offer.riskLabel,
				reward = offer.reward,
				siteLabel = offer.siteLabel,
				locked = offer.locked,
				lockReason = offer.lockReason,
			})
		end
		local cooldown = 0
		if lastReroll[player] then
			cooldown = math.max(0, GameConfig.Contracts.RerollCooldown - (os.clock() - lastReroll[player]))
		end
		return { list = list, rerollCooldown = cooldown }
	end)
	services.State.register("contract", function(player)
		local contract = active[player]
		if not contract then
			return { active = false }
		end
		local template = templateOf(contract)
		local step = stepOf(contract)
		local siteId = siteForStep(contract, step)
		local position
		if siteId == "Depot" then
			position = services.World.world.depot.secure.CFrame.Position
		else
			local site = services.World.site(siteId)
			position = site and site.position
		end
		return {
			active = true,
			id = contract.id,
			title = template.title,
			tier = contract.tier,
			tierLabel = ContractConfig.Tiers[contract.tier].label,
			siteId = siteId,
			targetPosition = position,
			step = {
				index = contract.stepIndex,
				total = #template.steps,
				kind = step.kind,
				text = stepText(contract, step),
			},
			reward = Rewards.offerValue(template.baseReward, ContractConfig.Tiers[contract.tier].riskMultiplier),
		}
	end)
end

return ContractService
