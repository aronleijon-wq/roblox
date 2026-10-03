-- LootConfig: vad som kan ligga var. Varje lootpunkt i staden har en zon (Street, Alley,
-- Interior, Restricted, Station, Secret). Högre HEAT flyttar chansen mot sällsyntare föremål
-- (se GameConfig.Loot.HeatRarityShift).

local LootConfig = {}

LootConfig.Tables = {
	Street = {
		{ item = "OldRadio", weight = 30 },
		{ item = "CopperSpool", weight = 30 },
		{ item = "VendingTokens", weight = 28 },
		{ item = "LostWallet", weight = 20 },
		{ item = "SealedLetter", weight = 5 },
		{ item = "BlankKeycard", weight = 4 },
		{ item = "Line3Token", weight = 1 },
	},
	Alley = {
		{ item = "CopperSpool", weight = 24 },
		{ item = "OldRadio", weight = 20 },
		{ item = "LostWallet", weight = 18 },
		{ item = "ServiceToolkit", weight = 12 },
		{ item = "SealedLetter", weight = 10 },
		{ item = "BlankKeycard", weight = 8 },
		{ item = "UndevelopedFilm", weight = 3 },
		{ item = "Line3Token", weight = 2 },
	},
	Interior = {
		{ item = "LostWallet", weight = 18 },
		{ item = "ServiceToolkit", weight = 18 },
		{ item = "BlankKeycard", weight = 16 },
		{ item = "SealedLetter", weight = 14 },
		{ item = "PrototypeScanner", weight = 6 },
		{ item = "UndevelopedFilm", weight = 6 },
		{ item = "SignalRecorder", weight = 1.5 },
	},
	Restricted = {
		{ item = "ServiceToolkit", weight = 20 },
		{ item = "BlankKeycard", weight = 16 },
		{ item = "PrototypeScanner", weight = 14 },
		{ item = "UndevelopedFilm", weight = 8 },
		{ item = "SignalRecorder", weight = 5 },
		{ item = "BrassKey19F", weight = 2 },
		{ item = "UnknownDevice", weight = 0.3 },
	},
	Station = {
		{ item = "Line3Token", weight = 30 },
		{ item = "PrototypeScanner", weight = 16 },
		{ item = "UndevelopedFilm", weight = 14 },
		{ item = "SignalRecorder", weight = 8 },
		{ item = "BrassKey19F", weight = 5 },
		{ item = "UnknownDevice", weight = 1 },
	},
	Secret = {
		{ item = "SignalRecorder", weight = 40 },
		{ item = "BrassKey19F", weight = 30 },
		{ item = "UnknownDevice", weight = 8 },
	},
	Anomaly = {
		{ item = "TheObject", weight = 1 },
	},
}

return LootConfig
