-- ItemConfig: alla föremål och sällsyntheter. Delas med klienten så att inventariet
-- kan visa namn, färger och värden. Var föremål dyker upp styrs av Server/Config/LootConfig.
--
-- Sällsynthet betyder inte "starkare". Ett föremål kan vara värt pengar, ingå i en
-- samling, berätta något om världen, eller bara vara något andra spelare inte har.

local ItemConfig = {}

ItemConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Unknown" }

ItemConfig.Rarities = {
	Common = { label = "COMMON", color = Color3.fromRGB(176, 184, 196) },
	Uncommon = { label = "UNCOMMON", color = Color3.fromRGB(96, 214, 132) },
	Rare = { label = "RARE", color = Color3.fromRGB(78, 160, 255) },
	Epic = { label = "EPIC", color = Color3.fromRGB(186, 110, 255) },
	Legendary = { label = "LEGENDARY", color = Color3.fromRGB(255, 186, 64) },
	Unknown = { label = "???", color = Color3.fromRGB(110, 255, 214) },
}

-- value = krediter när föremålet säkras. collection = samlingen det räknas till.
-- contractItem = tillhör ett kontrakt (kan inte säljas, försvinner om kontraktet avbryts).
ItemConfig.Items = {
	-- Vanliga saker man hittar på gatan
	OldRadio = {
		name = "Old Radio",
		rarity = "Common",
		value = 120,
		collection = "NightSalvage",
		lore = "Still warm. Tuned to a station that doesn't exist.",
	},
	CopperSpool = { name = "Copper Spool", rarity = "Common", value = 90, collection = "NightSalvage" },
	LostWallet = {
		name = "Lost Wallet",
		rarity = "Common",
		value = 150,
		collection = "NightSalvage",
		lore = "The ID photo is blank.",
	},
	VendingTokens = { name = "Vending Tokens", rarity = "Common", value = 70, collection = "NightSalvage" },
	-- Ovanliga
	BlankKeycard = {
		name = "Blank Keycard",
		rarity = "Uncommon",
		value = 320,
		collection = "Access",
		lore = "No company name. The magnetic strip is new.",
	},
	ServiceToolkit = { name = "Service Toolkit", rarity = "Uncommon", value = 400, collection = "NightSalvage" },
	SealedLetter = {
		name = "Sealed Letter",
		rarity = "Uncommon",
		value = 260,
		collection = "Documents",
		lore = "Addressed to 'whoever works the 3am shift'.",
	},
	-- Sällsynta
	PrototypeScanner = { name = "Prototype Scanner", rarity = "Rare", value = 1200, collection = "Equipment" },
	Line3Token = {
		name = "Line 3 Token",
		rarity = "Rare",
		value = 900,
		collection = "Transit",
		lore = "Line 3 closed in 1987. The token is dated next year.",
	},
	UndevelopedFilm = {
		name = "Undeveloped Film",
		rarity = "Rare",
		value = 800,
		collection = "Documents",
		lore = "Label: 'CALLOWAY 19F - DO NOT PRINT'.",
	},
	-- Episka
	SignalRecorder = {
		name = "Signal Recorder",
		rarity = "Epic",
		value = 2600,
		collection = "Equipment",
		lore = "The last recording is 3 minutes of breathing in sync.",
	},
	BrassKey19F = {
		name = "Brass Key - 19F",
		rarity = "Epic",
		value = 2200,
		collection = "Access",
		lore = "Calloway Residences only has 18 floors.",
	},
	-- Legendariska och okända
	UnknownDevice = {
		name = "Unknown Device",
		rarity = "Legendary",
		value = 9000,
		collection = "Anomalies",
		lore = "It counts down. It has been counting down since before you found it.",
	},
	TheObject = {
		name = "???",
		rarity = "Unknown",
		value = 20000,
		collection = "Anomalies",
		lore = "It hums when nobody is looking at it.",
	},
	-- Kontraktsföremål (ger inga krediter i sig; kontraktet betalar)
	IndustrialScanner = {
		name = "Industrial Scanner",
		rarity = "Uncommon",
		value = 0,
		contractItem = true,
		lore = "Property of Halden Grid Services.",
	},
	DispatchParcel = { name = "Dispatch Parcel", rarity = "Common", value = 0, contractItem = true },
	UnmarkedPackage = {
		name = "Unmarked Package",
		rarity = "Unknown",
		value = 0,
		contractItem = true,
		lore = "No sender. No address. It is heavier when you walk away from the tower.",
	},
}

ItemConfig.Collections = {
	NightSalvage = { name = "Night Salvage" },
	Access = { name = "Access" },
	Documents = { name = "Documents" },
	Equipment = { name = "Equipment" },
	Transit = { name = "Transit" },
	Anomalies = { name = "Anomalies" },
}

function ItemConfig.get(itemId: string)
	return ItemConfig.Items[itemId]
end

function ItemConfig.rarityRank(rarity: string): number
	return table.find(ItemConfig.RarityOrder, rarity) or 1
end

return ItemConfig
