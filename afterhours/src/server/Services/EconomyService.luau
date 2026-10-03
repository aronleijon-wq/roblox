-- EconomyService: pengar och skiftets kassabok.
--
-- Under natten är allt osäkrat: slutförda kontrakt, upptäcktsbonusar och föremål man bär.
-- Det säkras i depåns lastkaj (när som helst) eller automatiskt om man är i depån 03:00.
-- Är man ute när klockan slår förloras föremålen och en del av kontraktspengarna.
-- Allt räknas med Rewards-formeln och siffrorna i GameConfig.Economy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Rewards = require(script.Parent.Parent.Logic.Rewards)

local EconomyService = {}

type ContractEntry = {
	templateId: string,
	title: string,
	tier: string,
	base: number,
	tierRisk: number,
	heat: number,
	incidentModifier: number,
	squadNearby: number,
	penalty: number,
}

type Ledger = {
	pending: { ContractEntry },
	pendingDiscovery: number,
	secured: { contracts: number, items: number, risk: number, discovery: number, survival: number, penalty: number },
	contractsCompleted: number,
	itemsSecured: number,
	itemsLost: number,
	bestFind: { itemId: string, name: string, rarity: string }?,
	discoveries: { string },
	titles: { string },
	peakHeat: number,
	lastSecuredAt: number,
}

local ledgers: { [Player]: Ledger } = {}
local services
local economy = GameConfig.Economy

local function newLedger(): Ledger
	return {
		pending = {},
		pendingDiscovery = 0,
		secured = { contracts = 0, items = 0, risk = 0, discovery = 0, survival = 0, penalty = 0 },
		contractsCompleted = 0,
		itemsSecured = 0,
		itemsLost = 0,
		bestFind = nil,
		discoveries = {},
		titles = {},
		peakHeat = 0,
		lastSecuredAt = 0,
	}
end

function EconomyService.init(registry)
	services = registry
end

function EconomyService.ledger(player: Player): Ledger?
	return ledgers[player]
end

local function addCredits(player: Player, amount: number, transaction: string)
	if amount <= 0 then
		return
	end
	local balance = 0
	services.Data.update(player, function(data)
		data.credits += amount
		data.stats.totalEarned += amount
		balance = data.credits
	end)
	services.Telemetry.economy(player, true, amount, balance, transaction)
	services.Telemetry.onboarding(player, "FirstReward")
	services.State.mark(player, "profile")
end

-- Tar krediter (köp). Returnerar false om spelaren inte har råd.
function EconomyService.spend(player: Player, amount: number, sku: string): boolean
	local data = services.Data.get(player)
	if not data or data.credits < amount then
		return false
	end
	local balance = 0
	services.Data.update(player, function(profile)
		profile.credits -= amount
		balance = profile.credits
	end)
	services.Telemetry.economy(player, false, amount, balance, "Shop", sku)
	services.State.mark(player, "profile")
	return true
end

function EconomyService.addContract(player: Player, entry: ContractEntry)
	local ledger = ledgers[player]
	if not ledger then
		return
	end
	table.insert(ledger.pending, entry)
	ledger.contractsCompleted += 1
	services.State.mark(player, "economy")
end

function EconomyService.addDiscovery(player: Player, name: string)
	local ledger = ledgers[player]
	if not ledger then
		return
	end
	table.insert(ledger.discoveries, name)
	ledger.pendingDiscovery += economy.DiscoveryBonus
	services.State.mark(player, "economy")
end

function EconomyService.noteTitle(player: Player, text: string)
	local ledger = ledgers[player]
	if ledger then
		table.insert(ledger.titles, text)
	end
end

function EconomyService.notePeakHeat(player: Player, heat: number)
	local ledger = ledgers[player]
	if ledger and heat > ledger.peakHeat then
		ledger.peakHeat = heat
	end
end

local function contractPay(entry: ContractEntry, extracted: boolean, extraFailure: number)
	return Rewards.contract({
		base = entry.base,
		tierRisk = entry.tierRisk,
		heat = entry.heat,
		incidentModifier = entry.incidentModifier,
		squadMembersNearby = entry.squadNearby,
		extracted = extracted,
		failureFraction = math.clamp(entry.penalty + extraFailure, 0, 1),
	}, economy)
end

-- Uppskattat värde om allt säkrades nu (visas i HUD:en).
function EconomyService.pendingValue(player: Player): number
	local ledger = ledgers[player]
	if not ledger then
		return 0
	end
	local total = ledger.pendingDiscovery
	for _, entry in ledger.pending do
		total += contractPay(entry, true, 0).total
	end
	return total
end

-- Säkrar allt spelaren bär och har osäkrat. Returnerar hur mycket som blev krediter.
function EconomyService.secure(player: Player): number
	local ledger = ledgers[player]
	if not ledger then
		return 0
	end
	local total = 0
	for _, entry in ledger.pending do
		local pay = contractPay(entry, true, 0)
		total += pay.total
		ledger.secured.contracts += pay.contractPay + pay.extractionBonus
		ledger.secured.risk += pay.riskBonus
		ledger.secured.penalty += pay.penalty
	end
	ledger.pending = {}

	if ledger.pendingDiscovery > 0 then
		total += ledger.pendingDiscovery
		ledger.secured.discovery += ledger.pendingDiscovery
		ledger.pendingDiscovery = 0
	end

	local items = services.Inventory.take(player, function(item)
		return item.contractId == nil
	end)
	for _, item in items do
		local def = ItemConfig.get(item.id)
		if def then
			total += def.value
			ledger.secured.items += def.value
			ledger.itemsSecured += 1
			services.Progression.recordItem(player, item.id)
			local best = ledger.bestFind
			if not best or ItemConfig.rarityRank(def.rarity) > ItemConfig.rarityRank(best.rarity) then
				ledger.bestFind = { itemId = item.id, name = def.name, rarity = def.rarity }
			end
		end
	end
	if #items > 0 then
		services.Data.update(player, function(data)
			data.stats.itemsSecured += #items
		end)
	end

	addCredits(player, total, "Secure")
	if total > 0 then
		ledger.lastSecuredAt = os.clock()
	end
	services.State.mark(player, "economy")
	return total
end

-- 03:00 i säkerhet: säkra allt och få överlevnadsbonus.
function EconomyService.survive(player: Player): number
	local ledger = ledgers[player]
	if not ledger then
		return 0
	end
	local secured = EconomyService.secure(player)
	ledger.secured.survival += economy.SurvivalBonus
	addCredits(player, economy.SurvivalBonus, "Survival")
	return secured + economy.SurvivalBonus
end

-- 03:00 ute på gatan: föremålen förloras och en del av kontraktspengarna.
function EconomyService.fail(player: Player): number
	local ledger = ledgers[player]
	if not ledger then
		return 0
	end
	local total = 0
	for _, entry in ledger.pending do
		local pay = contractPay(entry, false, economy.FailedShift.PendingLossFraction)
		total += pay.total
		ledger.secured.contracts += pay.contractPay
		ledger.secured.risk += pay.riskBonus
		ledger.secured.penalty += pay.penalty
	end
	ledger.pending = {}
	ledger.pendingDiscovery = 0 -- upptäckter ger status ändå, men bonusen kräver att man kommer hem

	local lost = services.Inventory.take(player, function(item)
		return item.contractId == nil
	end)
	local keepCount = math.floor(#lost * (1 - economy.FailedShift.LootLossFraction))
	for index, item in lost do
		if index <= keepCount then
			local def = ItemConfig.get(item.id)
			total += def.value
			ledger.secured.items += def.value
			ledger.itemsSecured += 1
		else
			ledger.itemsLost += 1
		end
	end
	addCredits(player, total, "FailedShift")
	services.State.mark(player, "economy")
	return total
end

-- Nedslagen: osäkrade kontraktspengar minskar.
function EconomyService.onDowned(player: Player)
	local ledger = ledgers[player]
	if not ledger then
		return
	end
	for _, entry in ledger.pending do
		entry.penalty = math.clamp(entry.penalty + economy.Downed.PendingLossFraction, 0, 1)
	end
	services.State.mark(player, "economy")
end

function EconomyService.secondsSinceSecured(player: Player): number
	local ledger = ledgers[player]
	return if ledger and ledger.lastSecuredAt > 0 then os.clock() - ledger.lastSecuredAt else math.huge
end

function EconomyService.reset(player: Player)
	ledgers[player] = newLedger()
	services.State.mark(player, "economy")
end

function EconomyService.start()
	services.Player.Ready:Connect(function(player)
		ledgers[player] = newLedger()
	end)
	services.Player.Downed:Connect(EconomyService.onDowned)
	Players.PlayerRemoving:Connect(function(player)
		ledgers[player] = nil
	end)
	services.Shift.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Hub then
			for player in ledgers do
				EconomyService.reset(player)
			end
		end
	end)
	services.State.register("economy", function(player)
		local ledger = ledgers[player]
		return {
			pendingContracts = if ledger then #ledger.pending else 0,
			pendingValue = EconomyService.pendingValue(player),
			carriedValue = services.Inventory.carriedValue(player),
		}
	end)
end

return EconomyService
