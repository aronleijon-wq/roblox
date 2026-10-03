-- ShopConfig: depåns förrådsskåp (Supply Locker). Allt köps för krediter man tjänat i spelet.
-- Inget här ger stridsfördelar: extra platser kräver licens (nivå), resten är utseende.

local ShopConfig = {}

ShopConfig.Items = {
	LockerSlot1 = {
		kind = "Upgrade",
		name = "Locker Expansion I",
		description = "+1 inventory slot.",
		price = 3000,
		requiresLicense = "LockerSlot1",
		slots = 1,
	},
	LockerSlot2 = {
		kind = "Upgrade",
		name = "Locker Expansion II",
		description = "+1 inventory slot.",
		price = 9000,
		requiresLicense = "LockerSlot2",
		requiresItem = "LockerSlot1",
		slots = 1,
	},
	LockerSlot3 = {
		kind = "Upgrade",
		name = "Locker Expansion III",
		description = "+1 inventory slot.",
		price = 20000,
		requiresLicense = "LockerSlot3",
		requiresItem = "LockerSlot2",
		slots = 1,
	},
}

-- Ficklampsfärger syns för alla spelare (ljuset skapas på servern).
ShopConfig.Flashlights = {
	Standard = { name = "Standard", color = Color3.fromRGB(255, 244, 222), price = 0 },
	Sodium = { name = "Sodium", color = Color3.fromRGB(255, 176, 84), price = 1500 },
	Halogen = { name = "Halogen Blue", color = Color3.fromRGB(150, 200, 255), price = 3500 },
	Signal = { name = "Signal Red", color = Color3.fromRGB(255, 90, 90), price = 6000 },
	Runner = { name = "Night Runner", color = Color3.fromRGB(170, 120, 255), requiresTitle = "NightRunner" },
	Unknown = { name = "???", color = Color3.fromRGB(110, 255, 214), requiresTitle = "FoundTheUnknown" },
}
ShopConfig.DefaultFlashlight = "Standard"

-- Färg på arbetsvästen alla kontraktörer bär.
ShopConfig.Vests = {
	HiVis = { name = "Hi-Vis", color = Color3.fromRGB(214, 255, 60), price = 0 },
	Orange = { name = "Safety Orange", color = Color3.fromRGB(255, 120, 30), price = 1000 },
	Graphite = { name = "Graphite", color = Color3.fromRGB(60, 64, 72), price = 2500 },
	Survivor = { name = "Blackout", color = Color3.fromRGB(255, 214, 90), requiresTitle = "BlackoutSurvivor" },
}
ShopConfig.DefaultVest = "HiVis"

return ShopConfig
