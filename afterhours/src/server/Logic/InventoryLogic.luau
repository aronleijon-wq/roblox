-- InventoryLogic: inventariets regler (platser, lägga till, ta bort). Ren logik, testbar.
-- Ett inventarie är { capacity = n, slots = { [index] = item } } där item är
-- { uid = string, id = string, contractId = string? }.

local InventoryLogic = {}

export type Item = { uid: string, id: string, contractId: string? }
export type Inventory = { capacity: number, slots: { [number]: Item } }

function InventoryLogic.new(capacity: number): Inventory
	return { capacity = capacity, slots = {} }
end

function InventoryLogic.capacityFor(upgradeSlots: number, inventoryConfig): number
	return math.clamp(inventoryConfig.BaseSlots + upgradeSlots, inventoryConfig.BaseSlots, inventoryConfig.MaxSlots)
end

function InventoryLogic.firstFree(inventory: Inventory): number?
	for index = 1, inventory.capacity do
		if inventory.slots[index] == nil then
			return index
		end
	end
	return nil
end

function InventoryLogic.count(inventory: Inventory): number
	local n = 0
	for index = 1, inventory.capacity do
		if inventory.slots[index] then
			n += 1
		end
	end
	return n
end

function InventoryLogic.isFull(inventory: Inventory): boolean
	return InventoryLogic.firstFree(inventory) == nil
end

-- Lägger föremålet på första lediga plats. Returnerar platsen, eller nil om det är fullt.
function InventoryLogic.add(inventory: Inventory, item: Item): number?
	local index = InventoryLogic.firstFree(inventory)
	if index then
		inventory.slots[index] = item
	end
	return index
end

function InventoryLogic.removeAt(inventory: Inventory, index: number): Item?
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > inventory.capacity then
		return nil
	end
	local item = inventory.slots[index]
	inventory.slots[index] = nil
	return item
end

function InventoryLogic.find(inventory: Inventory, predicate: (Item) -> boolean): (Item?, number?)
	for index = 1, inventory.capacity do
		local item = inventory.slots[index]
		if item and predicate(item) then
			return item, index
		end
	end
	return nil, nil
end

-- Tar bort och returnerar alla föremål som uppfyller predicate.
function InventoryLogic.removeWhere(inventory: Inventory, predicate: (Item) -> boolean): { Item }
	local removed = {}
	for index = 1, inventory.capacity do
		local item = inventory.slots[index]
		if item and predicate(item) then
			inventory.slots[index] = nil
			table.insert(removed, item)
		end
	end
	return removed
end

function InventoryLogic.items(inventory: Inventory): { Item }
	local list = {}
	for index = 1, inventory.capacity do
		local item = inventory.slots[index]
		if item then
			table.insert(list, item)
		end
	end
	return list
end

-- Ändrar kapaciteten. Föremål på platser som försvinner flyttas till lediga platser om det går;
-- returnerar de som inte fick plats (anroparen avgör vad som händer med dem).
function InventoryLogic.resize(inventory: Inventory, capacity: number): { Item }
	local items = InventoryLogic.items(inventory)
	inventory.capacity = capacity
	inventory.slots = {}
	local overflow = {}
	for _, item in items do
		if not InventoryLogic.add(inventory, item) then
			table.insert(overflow, item)
		end
	end
	return overflow
end

return InventoryLogic
