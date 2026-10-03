-- LootService: föremål på marken. Vid varje natts början läggs loot ut på en del av
-- stadens lootpunkter (tabell per zon), och spelare kan släppa saker som andra kan plocka upp.
-- Utseendet visar sällsynthet direkt: färgad kant, och sällsynta saker lyser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local LootConfig = require(script.Parent.Parent.Config.LootConfig)
local LootLogic = require(script.Parent.Parent.Logic.LootLogic)

local LootService = {}

type Drop = { id: string, itemId: string, part: BasePart, createdAt: number, droppedBy: Player?, despawns: boolean }

local drops: { [string]: Drop } = {}
local folder: Folder
local dropCounter = 0
local services

local LOOK = {
	Common = {
		size = Vector3.new(1.6, 1.1, 1.2),
		color = Color3.fromRGB(150, 120, 84),
		material = Enum.Material.Cardboard,
	},
	Uncommon = {
		size = Vector3.new(1.8, 1.1, 1.3),
		color = Color3.fromRGB(46, 52, 60),
		material = Enum.Material.SmoothPlastic,
	},
	Rare = { size = Vector3.new(2, 1.2, 1.4), color = Color3.fromRGB(70, 76, 86), material = Enum.Material.Metal },
	Epic = { size = Vector3.new(2, 1.2, 1.4), color = Color3.fromRGB(40, 32, 52), material = Enum.Material.Metal },
	Legendary = {
		size = Vector3.new(1.6, 1.6, 1.6),
		color = Color3.fromRGB(60, 46, 20),
		material = Enum.Material.Metal,
	},
	Unknown = { size = Vector3.new(1.3, 1.3, 1.3), color = Color3.fromRGB(10, 12, 14), material = Enum.Material.Glass },
}

function LootService.init(registry)
	services = registry
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = Workspace
end

-- Lägger ett föremål på marken. Returnerar drop-id.
function LootService.spawnDrop(
	itemId: string,
	position: Vector3,
	options: { droppedBy: Player?, despawns: boolean? }?
): string?
	local def = ItemConfig.get(itemId)
	if not def then
		warn("[LootService] okänt föremål:", itemId)
		return nil
	end
	local opts = options or {}
	local rarity = ItemConfig.Rarities[def.rarity]
	local look = LOOK[def.rarity] or LOOK.Common
	dropCounter += 1
	local id = "D" .. dropCounter

	local part = Instance.new("Part")
	part.Name = "LootDrop"
	part.Size = look.size
	part.CFrame = CFrame.new(position + Vector3.new(0, look.size.Y / 2, 0))
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	part.Color = look.color
	part.Material = look.material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("ItemId", itemId)
	part:SetAttribute("Rarity", def.rarity)
	part:SetAttribute("DropId", id)

	local band = Instance.new("Part")
	band.Name = "RarityBand"
	band.Size = Vector3.new(look.size.X + 0.06, 0.18, look.size.Z + 0.06)
	band.CFrame = part.CFrame * CFrame.new(0, look.size.Y / 2 - 0.3, 0)
	band.Color = rarity.color
	band.Material = Enum.Material.Neon
	band.Anchored = true
	band.CanCollide = false
	band.CanTouch = false
	band.CanQuery = false
	band.CastShadow = false
	band.Parent = part

	if ItemConfig.rarityRank(def.rarity) >= ItemConfig.rarityRank("Rare") then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = if def.rarity == "Unknown" then 14 else 9
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = part
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = if def.rarity == "Unknown" then "???" else def.name
	prompt.HoldDuration = if ItemConfig.rarityRank(def.rarity) >= ItemConfig.rarityRank("Rare") then 0.8 else 0.3
	prompt.MaxActivationDistance = GameConfig.Loot.PickupDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Action", Constants.Actions.PickupLoot)
	prompt:SetAttribute("Target", id)
	prompt.Parent = part

	part:AddTag(Constants.Tags.LootDrop)
	part.Parent = folder
	drops[id] = {
		id = id,
		itemId = itemId,
		part = part,
		createdAt = os.clock(),
		droppedBy = opts.droppedBy,
		despawns = if opts.despawns == nil then opts.droppedBy ~= nil else opts.despawns,
	}
	return id
end

function LootService.removeDrop(id: string)
	local drop = drops[id]
	if drop then
		drop.part:Destroy()
		drops[id] = nil
	end
end

function LootService.clearAll()
	for id in drops do
		LootService.removeDrop(id)
	end
end

local function itemRank(itemId: string): number
	local def = ItemConfig.get(itemId)
	return if def then ItemConfig.rarityRank(def.rarity) else 1
end

-- Slår fram ett föremål ur en zons tabell vid aktuell server-HEAT.
function LootService.roll(zone: string, rng): string?
	local lootTable = LootConfig.Tables[zone]
	if not lootTable then
		return nil
	end
	return LootLogic.roll(lootTable, services.Heat.serverHeat(), GameConfig.Loot.HeatRarityShift, itemRank, rng)
end

local function populate(shiftNumber: number)
	local seed = shiftNumber * 7919 + os.time() % 100000
	print(`[LootService] skift {shiftNumber}: lägger ut loot (seed {seed})`)
	local rng = Rng.new(seed)
	local world = services.World.world
	for _, point in world.lootPoints do
		local chance = GameConfig.Loot.SpawnFraction
		if point.zone == "Secret" or point.zone == "Station" then
			chance = 0.8 -- belöna den som hittar dit
		end
		if rng:chance(chance) then
			local itemId = LootService.roll(point.zone, rng)
			if itemId then
				LootService.spawnDrop(itemId, point.position - Vector3.new(0, 0.5, 0), { despawns = false })
			end
		end
	end
end

local function onPickup(player: Player, _prompt: ProximityPrompt, target: string?)
	local drop = target and drops[target]
	if not drop then
		return
	end
	if services.Shift.phase() == Constants.Phases.Results then
		return
	end
	local def = ItemConfig.get(drop.itemId)
	if services.Inventory.isFull(player) then
		services.State.notify(player, "warning", "INVENTORY FULL", GameConfig.Onboarding.InventoryFullHint)
		return
	end
	if not services.Inventory.add(player, drop.itemId) then
		return
	end
	LootService.removeDrop(drop.id)

	local rank = ItemConfig.rarityRank(def.rarity)
	if rank >= ItemConfig.rarityRank("Rare") then
		services.Heat.add(player, GameConfig.Heat.Gain.RareLoot, "rare loot")
		services.Telemetry.onboarding(player, "FirstRareItem")
		services.Telemetry.event(player, "RareItemFound", rank, { item = drop.itemId })
	end
	local title = if def.rarity == "Unknown" then "WHAT IS THIS?" else ItemConfig.Rarities[def.rarity].label
	services.State.notify(
		player,
		"loot",
		title,
		(if def.rarity == "Unknown" then "???" else def.name) .. "  ·  " .. def.value .. " cr",
		3
	)
end

function LootService.start()
	services.Interaction.register(Constants.Actions.PickupLoot, onPickup)
	services.Shift.NightStarted:Connect(populate)
	services.Shift.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Hub then
			LootService.clearAll()
		end
	end)
	-- Släppta föremål försvinner efter ett tag så att gatan inte fylls.
	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.clock()
			for id, drop in drops do
				if drop.despawns and now - drop.createdAt > GameConfig.Loot.DropDespawnSeconds then
					LootService.removeDrop(id)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, drop in drops do
			if drop.droppedBy == player then
				drop.droppedBy = nil
			end
		end
	end)
end

return LootService
