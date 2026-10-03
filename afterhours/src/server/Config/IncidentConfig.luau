-- IncidentConfig: alla incidenter som IncidentDirector kan starta.
-- Varje incident har en egen modul i Server/Incidents med samma namn (serverlogik + städning).
-- Klientens presentation styrs av "presentation"-nyckeln och skickas i WorldEvent.
--
-- Fält:
--   rarity          Common | Uncommon | Rare | Major | Extreme | Legendary (vikter i GameConfig.Director)
--   weight          extra vikt inom sin sällsynthet (standard 1)
--   minHeat/maxHeat serverns HEAT-intervall där incidenten kan hända
--   minClock/maxClock spelklockan (timmar efter midnatt) där den kan hända
--   duration        sekunder
--   cooldown        sekunder innan samma incident kan hända igen på servern
--   rewardModifier  multiplikator på kontrakt som slutförs medan incidenten pågår
--   dangerModifier  multiplikator på HEAT-ökning medan den pågår
--   scope           "District" (hela området), "Player" (riktar sig mot en spelare) eller
--                   "Twist" (startas bara av kontrakt, aldrig av regissören)
--   minPlayers      minsta antal spelare på servern

local IncidentConfig = {}

IncidentConfig.Incidents = {
	Blackout = {
		name = "BLACKOUT",
		rarity = "Common",
		minHeat = 0,
		maxHeat = 100,
		minClock = 0.35,
		duration = 80,
		cooldown = 240,
		rewardModifier = 1.15,
		dangerModifier = 1.2,
		scope = "District",
		radio = "Grid failure across Downtown. Emergency lighting only.",
	},
	FalseAlarm = {
		name = "FALSE ALARM",
		rarity = "Common",
		minHeat = 0,
		maxHeat = 100,
		duration = 120,
		cooldown = 150,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "District",
		radio = "Alarm triggered at {site}. Anyone nearby, check it out.",
	},
	EmergencyShift = {
		name = "EMERGENCY SHIFT",
		rarity = "Uncommon",
		minHeat = 10,
		maxHeat = 100,
		minClock = 0.5,
		maxClock = 2.3,
		duration = 100,
		cooldown = 420,
		rewardModifier = 2.0,
		dangerModifier = 1.6,
		scope = "District",
		radio = "Emergency rates in effect. All active contracts pay double. Stay sharp.",
	},
	SilentCity = {
		name = "SILENT CITY",
		rarity = "Uncommon",
		minHeat = 25,
		maxHeat = 100,
		minClock = 0.75,
		duration = 40,
		cooldown = 360,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "District",
		radio = nil, -- ingen radio. Det är poängen.
	},
	ClosedStation = {
		name = "CLOSED STATION",
		rarity = "Rare",
		minHeat = 15,
		maxHeat = 100,
		minClock = 0.75,
		maxClock = 2.4,
		duration = 90,
		cooldown = 600,
		rewardModifier = 1.0,
		dangerModifier = 1.3,
		scope = "District",
		radio = "Mercer St Station gates are reading OPEN. That station has been closed for years.",
	},
	TheFollower = {
		name = "THE FOLLOWER",
		rarity = "Rare",
		minHeat = 35,
		maxHeat = 100,
		minClock = 0.6,
		duration = 120,
		cooldown = 420,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "Player",
		radio = nil,
	},
	UnknownPackage = {
		name = "UNKNOWN PACKAGE",
		rarity = "Rare",
		minHeat = 10,
		maxHeat = 100,
		minClock = 0.5,
		maxClock = 2.2,
		duration = 300,
		cooldown = 900,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "Player",
		radio = nil,
	},
	Lockdown = {
		name = "LOCKDOWN",
		rarity = "Major",
		minHeat = 45,
		maxHeat = 100,
		minClock = 0.8,
		maxClock = 2.6,
		duration = 100,
		cooldown = 600,
		rewardModifier = 1.25,
		dangerModifier = 1.3,
		scope = "District",
		radio = "Police lockdown on several streets. Find another way around.",
	},
	CascadeFailure = {
		name = "CASCADE FAILURE",
		rarity = "Extreme",
		minHeat = 65,
		maxHeat = 100,
		minClock = 1.0,
		maxClock = 2.6,
		duration = 110,
		cooldown = 1200,
		rewardModifier = 1.6,
		dangerModifier = 1.8,
		scope = "District",
		radio = "Multiple system failures. Grid down. Streets sealed. This is not a drill.",
	},
	ImpossibleLights = {
		name = "THE OTHER LIGHTS",
		rarity = "Legendary",
		minHeat = 40,
		maxHeat = 100,
		minClock = 1.0,
		maxClock = 2.4,
		duration = 150,
		cooldown = 3600,
		rewardModifier = 1.5,
		dangerModifier = 1.0,
		scope = "District",
		radio = nil, -- all kommunikation tystnar
	},

	-- Twists: startas av kontrakt, aldrig av regissören -----------------------
	LightsReturn = {
		name = "SOMETHING INSIDE",
		rarity = "Uncommon",
		duration = 120,
		cooldown = 60,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "Twist",
	},
	Overload = {
		name = "OVERLOAD",
		rarity = "Uncommon",
		duration = 1,
		cooldown = 120,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "Twist",
	},
	WrongAddress = {
		name = "WRONG ADDRESS",
		rarity = "Uncommon",
		duration = 1,
		cooldown = 60,
		rewardModifier = 1.0,
		dangerModifier = 1.0,
		scope = "Twist",
	},
}

return IncidentConfig
