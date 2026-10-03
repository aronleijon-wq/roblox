-- ShopService: depåns förrådsskåp. Allt kostar krediter man tjänat i spelet. Uppgraderingar
-- kräver licens (nivå); resten är utseende som andra spelare ser. Inga Robux, inget
-- pay-to-win. Servern kontrollerar pris, krav och ägande; klienten kan bara be om ett köp.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local ShopService = {}

local services

local CATEGORIES = {
	Flashlight = { list = ShopConfig.Flashlights, cosmetic = "flashlight" },
	Vest = { list = ShopConfig.Vests, cosmetic = "vest" },
}

function ShopService.init(registry)
	services = registry
end

local function owns(data, kind: string, id: string): boolean
	if kind == "Upgrade" then
		return data.purchases[id] == true
	end
	local category = CATEGORIES[kind]
	local def = category and category.list[id]
	if not def then
		return false
	end
	if data.cosmetics[category.cosmetic][id] then
		return true
	end
	if def.price == 0 then
		return true
	end
	return def.requiresTitle ~= nil and data.titles[def.requiresTitle] == true
end

local function purchase(player: Player, kind: any, id: any)
	if not services.Security.isString(kind, 20) or not services.Security.isString(id, 40) then
		return
	end
	local data = services.Data.get(player)
	if not data then
		return
	end
	local def
	if kind == "Upgrade" then
		def = ShopConfig.Items[id]
	elseif CATEGORIES[kind] then
		def = CATEGORIES[kind].list[id]
	end
	if not def or def.price == nil then
		return -- finns inte, eller går inte att köpa (t.ex. titelbelöningar)
	end
	if owns(data, kind, id) then
		services.State.notify(player, "info", "SUPPLY LOCKER", "You already own that.")
		return
	end
	if def.requiresLicense and not services.Progression.hasLicense(player, def.requiresLicense) then
		services.State.notify(player, "warning", "SUPPLY LOCKER", "You need a higher level for that.")
		return
	end
	if def.requiresItem and not data.purchases[def.requiresItem] then
		services.State.notify(player, "warning", "SUPPLY LOCKER", "Buy the previous expansion first.")
		return
	end
	services.Telemetry.event(player, "PurchaseStarted", def.price, { item = id })
	if not services.Economy.spend(player, def.price, id) then
		services.State.notify(player, "warning", "SUPPLY LOCKER", "Not enough credits.")
		return
	end
	services.Data.update(player, function(profile)
		if kind == "Upgrade" then
			profile.purchases[id] = true
		else
			profile.cosmetics[CATEGORIES[kind].cosmetic][id] = true
		end
	end)
	services.Telemetry.event(player, "PurchaseCompleted", def.price, { item = id })
	services.State.notify(player, "good", "SUPPLY LOCKER", def.name .. " is yours.")
	if kind == "Upgrade" then
		services.Inventory.refreshCapacity(player)
	end
	services.State.mark(player, "profile")
end

local function equip(player: Player, kind: any, id: any)
	if not services.Security.isString(kind, 20) or not services.Security.isString(id, 40) then
		return
	end
	local data = services.Data.get(player)
	if not data then
		return
	end
	if kind == "Title" then
		if not data.titles[id] then
			return
		end
		services.Data.update(player, function(profile)
			profile.equippedTitle = id
		end)
	elseif CATEGORIES[kind] then
		if not owns(data, kind, id) then
			return
		end
		services.Data.update(player, function(profile)
			profile.equipped[CATEGORIES[kind].cosmetic] = id
		end)
	else
		return
	end
	services.Player.refreshCosmetics(player)
	services.State.mark(player, "profile")
end

function ShopService.start()
	services.Security.on(services.Remotes.ShopPurchase, "ShopPurchase", purchase)
	services.Security.on(services.Remotes.Equip, "Equip", equip)
end

return ShopService
