-- Constants: namn som server och klient måste vara överens om (remotes, taggar, attribut, faser).
-- Ändra inte värden här utan att uppdatera båda sidor; spelinnehåll hör hemma i Config/.

local Constants = {}

-- Klient -> server är alltid en *begäran*. Servern validerar allt.
Constants.Remotes = {
	Events = {
		"StateSync", -- S->C: spelarens tillstånd (krediter, HEAT, inventarie, kontrakt ...)
		"Notify", -- S->C: radio/dispatch-meddelanden och toasts
		"WorldEvent", -- S->C: incidenter och världshändelser (presentation på klienten)
		"ShiftReport", -- S->C: resultatkortet efter skiftet
		"SquadInvite", -- S->C: inbjudan till squad
		"AcceptContract", -- C->S
		"AbandonContract", -- C->S
		"RerollContracts", -- C->S
		"DropItem", -- C->S
		"SquadRequest", -- C->S: invite / respond / leave / ping
		"ShopPurchase", -- C->S
		"Equip", -- C->S: kosmetika och titlar
		"ToggleFlashlight", -- C->S
		"SubmitCode", -- C->S: knappsatsen vid hemliga dörrar
		"TwistChoice", -- C->S: val när ett kontrakt tar en oväntad vändning
		"DebugCommand", -- C->S: bara i Studio eller för spelets ägare
	},
	Functions = {
		"GetSnapshot", -- C->S: fullt tillstånd vid start
	},
}

Constants.Tags = {
	Interactable = "AH_Interactable",
	LootDrop = "AH_Loot",
	WindowLight = "AH_WindowLight",
	StreetLight = "AH_StreetLight",
	EmergencyLight = "AH_EmergencyLight",
	ContractSite = "AH_ContractSite",
	SafeZone = "AH_SafeZone",
	RestrictedZone = "AH_RestrictedZone",
	ExtractionZone = "AH_ExtractionZone",
	AccessGate = "AH_AccessGate", -- dörrar som öppnas per spelare (kontrakt/incident)
	Npc = "AH_Npc",
	AmbientSound = "AH_AmbientSound",
}

-- Attribut på ReplicatedStorage som alla klienter läser (billigt, replikeras automatiskt).
Constants.WorldAttributes = {
	Phase = "ShiftPhase",
	ShiftNumber = "ShiftNumber",
	PhaseEndsAt = "PhaseEndsAt",
	NightStartedAt = "NightStartedAt",
	NightEndsAt = "NightEndsAt",
	Forecast = "Forecast",
	ServerHeat = "ServerHeat",
	ActiveIncidents = "ActiveIncidents",
	TimeScale = "TimeScale",
}

Constants.Phases = {
	Hub = "Hub",
	Night = "Night",
	Extraction = "Extraction", -- 02:30 -> 03:00, natten fortsätter men "SHIFT ENDING"
	Results = "Results",
}

Constants.PlayerAttributes = {
	Heat = "Heat",
	Downed = "Downed",
	InSafeZone = "InSafeZone",
	Title = "Title",
	SquadId = "SquadId",
}

-- Interaktionstyper som servern känner igen på ProximityPrompts (attributet "Action").
Constants.Actions = {
	ContractSite = "ContractSite",
	PickupLoot = "PickupLoot",
	Secure = "Secure",
	Dispatch = "Dispatch",
	Locker = "Locker",
	Keypad = "Keypad",
	Investigate = "Investigate",
	Talk = "Talk",
}

return Constants
