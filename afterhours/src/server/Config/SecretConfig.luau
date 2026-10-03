-- SecretConfig: stadens gemensamma hemlighet. Bara servern ser den här filen.
-- Ändra Salt om koden någon gång läcker, så får alla servrar en ny kodserie.

local SecretConfig = {}

SecretConfig.Salt = 30311
SecretConfig.CodeLength = 4

-- Vilken symbol som betyder vilken siffra. Detta står (i bitar) på affischer i staden.
SecretConfig.SymbolForDigit = {
	["0"] = "◇",
	["1"] = "▲",
	["2"] = "☾",
	["3"] = "●",
	["4"] = "✕",
	["5"] = "■",
	["6"] = "◐",
	["7"] = "★",
	["8"] = "✚",
	["9"] = "◆",
}

-- Affischerna. Ingen enskild affisch har hela nyckeln; man måste hitta flera.
SecretConfig.Posters = {
	{ anchor = "PosterStore", title = "NITE OWL REWARDS", digits = { "1", "4", "7", "0" } },
	{ anchor = "PosterDepot", title = "SHIFT ROTA CODES", digits = { "2", "5", "8" } },
	{ anchor = "PosterTheater", title = "NOW SHOWING: NOTHING", digits = { "3", "6", "9", "0" } },
}

-- Hur länge B-7 står öppen för den som skrev rätt kod.
SecretConfig.OpenSeconds = 120

return SecretConfig
