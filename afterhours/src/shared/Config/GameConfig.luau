-- GameConfig: alla tal som styr hur spelet känns. Allt som kan behöva balanseras
-- eller A/B-testas ligger här, inte utspritt i spelkoden.
-- Ligger i ReplicatedStorage eftersom klienten behöver tider och rörelse. Inget här
-- är hemligt; hemligheter och händelsetabeller ligger på servern (Server/Config).

local GameConfig = {}

GameConfig.GameName = "AFTERHOURS"
GameConfig.Subtitle = "03:00"

-- Ett skift: HUB -> NIGHT (00:00 -> 02:30) -> EXTRACTION (02:30 -> 03:00) -> RESULTS -> HUB
GameConfig.Shift = {
	HubDuration = 40, -- sekunder att förbereda sig mellan skiften
	NightDuration = 720, -- verkliga sekunder för 00:00 -> 03:00 (12 min)
	ResultsDuration = 14,
	StartClock = 0, -- 00:00
	EndClock = 3, -- 03:00
	ShiftEndingClock = 2.5, -- 02:30: "SHIFT ENDING", extraktionen börjar
	ExposureClock = 2.75, -- 02:45: att vara ute börjar skada
}

GameConfig.Player = {
	WalkSpeed = 14,
	SprintSpeed = 22,
	StaminaSeconds = 6,
	StaminaRegenPerSecond = 1.5,
	MaxHealth = 100,
	RespawnDelay = 4, -- sekunder efter att man blivit nedslagen
}

-- Skada per sekund utanför säkra zoner under de sista minuterna. Ökar mot 03:00.
GameConfig.Exposure = {
	DamagePerSecondStart = 2,
	DamagePerSecondEnd = 9,
}

GameConfig.Inventory = {
	BaseSlots = 6,
	MaxSlots = 9,
}

GameConfig.Economy = {
	ExtractionBonus = 0.20, -- +20 % på kontraktets (bas x risk) när det säkras
	DiscoveryBonus = 500, -- per ny upptäckt under skiftet
	SurvivalBonus = 250, -- för att vara i säkerhet när klockan slår 03:00
	SquadBonusPerMember = 0.10, -- per extra squadmedlem i närheten när kontraktet slutförs
	SquadBonusRadius = 80,
	HeatRiskPerPoint = 0.005, -- HEAT 100 ger x1.5 på kontrakt
	FailedShift = {
		PendingLossFraction = 0.5, -- osäkrade kontraktspengar som förloras om man inte hann hem
		LootLossFraction = 1.0, -- osäkrade föremål som förloras
	},
	Downed = {
		PendingLossFraction = 0.25,
		DropsCarriedItems = true, -- föremålen hamnar på marken, andra kan plocka upp dem
	},
	StartingCredits = 0,
}

-- HEAT: 0-100 per spelare. Mer HEAT = farligare händelser men högre belöning.
GameConfig.Heat = {
	Max = 100,
	Tiers = {
		{ min = 0, name = "CALM" },
		{ min = 20, name = "UNEASY" },
		{ min = 40, name = "TENSE" },
		{ min = 60, name = "FAILING" },
		{ min = 80, name = "CRITICAL" },
	},
	Gain = {
		AcceptSafe = 0,
		AcceptNormal = 4,
		AcceptHighRisk = 15,
		RestrictedPerSecond = 1.2,
		OutsideLatePerSecond = 0.15, -- efter 01:30 utanför säkra zoner
		LateClock = 1.5,
		AlarmTriggered = 10,
		Anomaly = 18,
		RareLoot = 4,
		IncidentNearby = 5,
	},
	SafeZoneDecayPerSecond = 1.5,
	ResetEachShift = true,
}

GameConfig.Director = {
	TickInterval = 12, -- sekunder mellan varje gång regissören funderar
	FirstIncidentWindow = { 150, 210 }, -- första incidenten kommer garanterat i detta fönster (s in i natten)
	FirstIncidentMaxRarity = "Uncommon", -- natten börjar med något konstigt, inte med det värsta
	MinGap = 70, -- minsta tid mellan två incidenter
	MaxConcurrent = 2,
	BaseChancePerTick = 0.22,
	HeatChanceBonus = 0.30, -- extra chans per tick vid HEAT 100
	-- Sannolikhet per sällsynthet (normaliseras över de incidenter som är möjliga just då).
	RarityWeights = {
		Common = 35,
		Uncommon = 25,
		Rare = 15,
		Major = 15,
		Extreme = 8,
		Legendary = 2,
	},
	HistorySize = 8, -- senaste incidenterna som minskar chansen för upprepning
	RepeatPenalty = 0.25, -- vikt-multiplikator för en incident som nyligen hänt
	MajorRepeatBlock = true, -- samma Major+ får inte hända två skift i rad
	ForecastBoost = 2.5, -- kvällens "prognos"-incident är vanligare
	NoIncidentsAfterClock = 2.85, -- låt slutet handla om att ta sig hem
}

GameConfig.Loot = {
	SpawnFraction = 0.55, -- andel av lootpunkterna som får något varje skift
	HeatRarityShift = 0.6, -- vid HEAT 100 flyttas vikterna mot sällsyntare saker
	DropDespawnSeconds = 180,
	PickupDistance = 10,
}

GameConfig.Contracts = {
	OffersPerPlayer = 3,
	RerollCooldown = 20,
	InteractDistance = 10,
}

GameConfig.Squad = {
	MaxSize = 4,
	InviteTimeout = 30,
}

GameConfig.Data = {
	StoreName = "AfterhoursProfiles_v1",
	AutosaveInterval = 120,
	MaxRetries = 4,
	SessionLockTimeout = 1800, -- sekunder innan ett lås från en krashad server räknas som gammalt
	LockRetries = 4,
}

-- Hur ofta en spelare får skicka varje typ av begäran (token bucket).
GameConfig.Security = {
	RateLimits = {
		Default = { rate = 2, burst = 5 },
		AcceptContract = { rate = 1, burst = 3 },
		AbandonContract = { rate = 0.5, burst = 2 },
		RerollContracts = { rate = 0.2, burst = 2 },
		DropItem = { rate = 3, burst = 6 },
		SquadRequest = { rate = 1, burst = 4 },
		ShopPurchase = { rate = 1, burst = 3 },
		Equip = { rate = 2, burst = 4 },
		ToggleFlashlight = { rate = 4, burst = 8 },
		SubmitCode = { rate = 0.3, burst = 3 },
		TwistChoice = { rate = 1, burst = 3 },
		GetSnapshot = { rate = 0.5, burst = 3 },
		ClientReady = { rate = 0.2, burst = 2 },
		DebugCommand = { rate = 4, burst = 10 },
		Interact = { rate = 4, burst = 8 },
	},
	InteractDistanceTolerance = 6, -- extra marginal för lagg
	SuspicionLogThreshold = 5, -- antal avvisade begäranden innan vi loggar spelaren
}

-- Små textrader som lär ut spelet i rätt ögonblick i stället för en tutorial.
GameConfig.Onboarding = {
	FirstContractHint = "Open DISPATCH to pick your first contract.",
	FirstSiteHint = "Find the site. Hold the prompt to work.",
	FirstSecureHint = "Bring it back to the DEPOT loading bay to secure your pay.",
	FirstHeatHint = "HEAT rises when you take risks. Risk pays more. It also invites trouble.",
	ShiftEndingHint = "Shift ending. Get back to the DEPOT before 03:00.",
	InventoryFullHint = "Inventory full. Drop something to make room.",
}

GameConfig.Debug = {
	EnabledInStudio = true,
	AllowedUserIds = {}, -- lägg till UserIds för testare i live-servrar
}

return GameConfig
