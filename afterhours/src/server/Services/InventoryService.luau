-- InventoryService: vad spelaren bär på under skiftet (6 platser från start).
-- Allt som bärs är osäkrat tills det lämnats i depåns lastkaj. Servern äger inventariet;
-- klienten får bara en kopia att visa och kan bara be om att släppa något.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local InventoryLogic = require(script.Parent.Parent.Logic.InventoryLogic)

local InventoryService = {}

InventoryService.Changed = Signal.new() -- (player)

local inventories: { [Player]: InventoryLogic.Inventory } = {}
local uidCounter = 0
local services

local function newUid(): string
	uidCounter += 1
	return "i" .. uidCounter
end

local function changed(player: Player)
	services.State.mark(player, "inventory")
	services.State.mark(player, "economy")
	InventoryService.Changed:Fire(player)
end

function InventoryService.capacityFor(player: Player): number
	local data = services.Data.get(player)
	local slots = 0
	if data then
		for shopId, owned in data.purchases do
			local def = owned and ShopConfig.Items[shopId]
			if def and def.slots then
				slots += def.slots
			end
		end
	end
	return InventoryLogic.capacityFor(slots, GameConfig.Inventory)
end

function InventoryService.init(registry)
	services = registry
end

function InventoryService.get(player: Player): InventoryLogic.Inventory?
	return inventories[player]
end

-- Lägger till ett föremål. Returnerar platsen, eller nil om inventariet är fullt.
function InventoryService.add(player: Player, itemId: string, contractId: string?): number?
	local inventory = inventories[player]
	if not inventory or not ItemConfig.get(itemId) then
		return nil
	end
	local slot = InventoryLogic.add(inventory, { uid = newUid(), id = itemId, contractId = contractId })
	if slot then
		changed(player)
	end
	return slot
end

function InventoryService.isFull(player: Player): boolean
	local inventory = inventories[player]
	return inventory == nil or InventoryLogic.isFull(inventory)
end

function InventoryService.has(player: Player, predicate: (InventoryLogic.Item) -> boolean): boolean
	local inventory = inventories[player]
	return inventory ~= nil and InventoryLogic.find(inventory, predicate) ~= nil
end

-- Tar bort och returnerar alla föremål som uppfyller predicate.
function InventoryService.take(player: Player, predicate: (InventoryLogic.Item) -> boolean): { InventoryLogic.Item }
	local inventory = inventories[player]
	if not inventory then
		return {}
	end
	local removed = InventoryLogic.removeWhere(inventory, predicate)
	if #removed > 0 then
		changed(player)
	end
	return removed
end

function InventoryService.items(player: Player): { InventoryLogic.Item }
	local inventory = inventories[player]
	return if inventory then InventoryLogic.items(inventory) else {}
end

-- Summan av vad osäkrade föremål är värda (kontraktsföremål räknas inte).
function InventoryService.carriedValue(player: Player): number
	local total = 0
	for _, item in InventoryService.items(player) do
		local def = ItemConfig.get(item.id)
		if def and not def.contractItem then
			total += def.value
		end
	end
	return total
end

-- Efter ett köp i förrådet: ny kapacitet (föremål som inte får plats släpps vid fötterna).
function InventoryService.refreshCapacity(player: Player)
	local inventory = inventories[player]
	if not inventory then
		return
	end
	local overflow = InventoryLogic.resize(inventory, InventoryService.capacityFor(player))
	local position = services.Security.position(player)
	for _, item in overflow do
		if position then
			services.Loot.spawnDrop(
				item.id,
				position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)),
				{ droppedBy = player }
			)
		end
	end
	changed(player)
end

function InventoryService.clear(player: Player)
	local inventory = inventories[player]
	if inventory then
		inventory.slots = {}
		changed(player)
	end
end

function InventoryService.start()
	services.Player.Ready:Connect(function(player)
		inventories[player] = InventoryLogic.new(InventoryService.capacityFor(player))
		services.State.mark(player, "inventory")
	end)
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)

	services.State.register("inventory", function(player)
		local inventory = inventories[player]
		if not inventory then
			return { capacity = GameConfig.Inventory.BaseSlots, items = {} }
		end
		local items = {}
		for slot = 1, inventory.capacity do
			local item = inventory.slots[slot]
			if item then
				table.insert(items, { slot = slot, uid = item.uid, id = item.id, contract = item.contractId ~= nil })
			end
		end
		return { capacity = inventory.capacity, items = items }
	end)

	-- Släpp ett föremål på marken (andra spelare kan plocka upp det).
	services.Security.on(services.Remotes.DropItem, "DropItem", function(player, slot)
		local inventory = inventories[player]
		if not inventory or not services.Security.isInteger(slot, 1, inventory.capacity) then
			return
		end
		local item = inventory.slots[slot]
		if not item then
			return
		end
		if item.contractId then
			services.State.notify(
				player,
				"warning",
				nil,
				"Contract items can't be dropped. Abandon the contract in DISPATCH instead."
			)
			return
		end
		local character = services.Security.alive(player)
		if not character then
			return
		end
		local pivot = character:GetPivot()
		InventoryLogic.removeAt(inventory, slot)
		changed(player)
		services.Loot.spawnDrop(
			item.id,
			pivot.Position + pivot.LookVector * 3 - Vector3.new(0, 2, 0),
			{ droppedBy = player }
		)
	end)

	-- Nedslagen: föremålen hamnar på gatan där man föll.
	services.Player.Downed:Connect(function(player, position)
		if not GameConfig.Economy.Downed.DropsCarriedItems then
			return
		end
		local dropped = InventoryService.take(player, function(item)
			return item.contractId == nil
		end)
		for index, item in dropped do
			local angle = index / math.max(#dropped, 1) * math.pi * 2
			services.Loot.spawnDrop(item.id, position + Vector3.new(math.cos(angle) * 3, -1.5, math.sin(angle) * 3), {
				droppedBy = player,
			})
		end
		if #dropped > 0 then
			services.State.notify(
				player,
				"danger",
				"YOU WENT DOWN",
				#dropped .. " item(s) are lying where you fell. Go get them back.",
				6
			)
		end
	end)
end

return InventoryService
