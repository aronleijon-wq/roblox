-- ProgressionService: rykte och nivåer (licenser), upptäckter, samlingar och titlar.
-- Progression ger nya möjligheter och status, inte råstyrka.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)

local ProgressionService = {}

local services
local discoveredThisSession: { [Player]: { [string]: boolean } } = {}

function ProgressionService.init(registry)
	services = registry
end

function ProgressionService.level(player: Player)
	local data = services.Data.get(player)
	return ProgressionConfig.levelFor(if data then data.reputation else 0)
end

function ProgressionService.hasLicense(player: Player, license: string): boolean
	local data = services.Data.get(player)
	return data ~= nil and ProgressionConfig.hasLicense(data.reputation, license)
end

function ProgressionService.addReputation(player: Player, gainKey: string)
	local amount = ProgressionConfig.ReputationGain[gainKey]
	if not amount then
		return
	end
	local before = ProgressionService.level(player)
	services.Data.update(player, function(data)
		data.reputation += amount
	end)
	local after = ProgressionService.level(player)
	if after.level > before.level then
		local unlocks = {}
		for _, license in after.unlocks do
			local def = ProgressionConfig.Licenses[license]
			table.insert(unlocks, if def then def.name else license)
		end
		services.State.notify(
			player,
			"good",
			"PROMOTED: " .. after.name,
			"Unlocked: " .. table.concat(unlocks, ", "),
			7
		)
		services.Telemetry.event(player, "LevelUp", after.level)
		services.Contracts.refreshOffers(player)
		services.Inventory.refreshCapacity(player)
	end
	services.State.mark(player, "profile")
end

function ProgressionService.grantTitle(player: Player, titleId: string)
	local def = ProgressionConfig.Titles[titleId]
	local data = services.Data.get(player)
	if not def or not data or data.titles[titleId] then
		return
	end
	services.Data.update(player, function(profile)
		profile.titles[titleId] = true
	end)
	services.State.notify(player, "discovery", "NEW TITLE", def.text, 6)
	services.Telemetry.event(player, "TitleEarned", 1, { title = titleId })
	services.State.mark(player, "profile")
	services.Economy.noteTitle(player, def.text)
end

-- Upptäckter (platser, personer, hemligheter, incidenter). Första gången ger rykte och bonus.
function ProgressionService.discover(player: Player, id: string, name: string?)
	local session = discoveredThisSession[player]
	if not session then
		session = {}
		discoveredThisSession[player] = session
	end
	if session[id] then
		return
	end
	session[id] = true
	local data = services.Data.get(player)
	if not data or data.discoveries[id] then
		return
	end
	local def = ProgressionConfig.Discoveries[id]
	local display = name or (def and def.name) or id
	services.Data.update(player, function(profile)
		profile.discoveries[id] = os.time()
	end)
	ProgressionService.addReputation(player, "Discovery")
	services.Economy.addDiscovery(player, display)
	services.State.notify(player, "discovery", "DISCOVERY", display, 5)
	services.Telemetry.event(player, "Discovery", 1, { id = id })
	services.State.mark(player, "profile")
end

-- Ett föremål säkrades: räkna det i samlingen (första exemplaret är en upptäckt).
function ProgressionService.recordItem(player: Player, itemId: string)
	local def = ItemConfig.get(itemId)
	if not def then
		return
	end
	local first = false
	services.Data.update(player, function(data)
		first = (data.collection[itemId] or 0) == 0
		data.collection[itemId] = (data.collection[itemId] or 0) + 1
	end)
	if first and ItemConfig.rarityRank(def.rarity) >= ItemConfig.rarityRank("Rare") then
		ProgressionService.discover(player, "item_" .. itemId, def.name)
	end
	if itemId == "TheObject" then
		ProgressionService.grantTitle(player, "FoundTheUnknown")
	end
end

function ProgressionService.start()
	services.State.register("profile", function(player)
		local data = services.Data.get(player)
		if not data then
			return nil
		end
		local level = ProgressionConfig.levelFor(data.reputation)
		local nextLevel = ProgressionConfig.nextLevel(data.reputation)
		local discoveries = 0
		local discovered = {}
		for id in data.discoveries do
			discoveries += 1
			table.insert(discovered, id)
		end
		return {
			credits = data.credits,
			reputation = data.reputation,
			level = level.level,
			levelName = level.name,
			levelFloor = level.reputation,
			nextLevelAt = nextLevel and nextLevel.reputation,
			titles = data.titles,
			equippedTitle = data.equippedTitle,
			cosmetics = data.cosmetics,
			equipped = data.equipped,
			purchases = data.purchases,
			discoveries = discoveries,
			discovered = discovered,
			collection = data.collection,
			stats = data.stats,
			temporary = services.Data.isTemporary(player),
		}
	end)
	services.Player.Ready:Connect(function(player)
		services.State.mark(player, "profile")
	end)
	services.Player.Leaving:Connect(function(player)
		discoveredThisSession[player] = nil
	end)
end

return ProgressionService
