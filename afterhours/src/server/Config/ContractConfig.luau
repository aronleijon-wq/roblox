-- ContractConfig: kontraktsmallar. ContractService skapar konkreta kontrakt från dessa
-- genom att välja en plats (site) av rätt typ i staden. Inga uppdrag skrivs för hand.
--
-- Steg (steps) som finns:
--   Interact  - håll in vid platsen (prompt, hold)
--   Pickup    - plocka upp ett kontraktsföremål vid platsen eller depån (item, at = "Site" | "Depot")
--   Deliver   - lämna föremålet vid platsen eller depån (item, to = "Site" | "Depot")
-- Twists är oväntade vändningar som kan hända när kontraktet slutförs (se IncidentConfig).

local ContractConfig = {}

-- Risknivåer. Erbjudandet visar bas x riskMultiplier. HEAT och bonusar läggs på senare.
ContractConfig.Tiers = {
	Safe = {
		label = "SAFE",
		riskLabel = "Low",
		riskMultiplier = 1.0,
		heatOnAccept = "AcceptSafe",
		license = "ContractsSafe",
		reputation = "ContractSafe",
		color = Color3.fromRGB(110, 220, 150),
	},
	Normal = {
		label = "NORMAL",
		riskLabel = "Medium",
		riskMultiplier = 1.25,
		heatOnAccept = "AcceptNormal",
		license = "ContractsNormal",
		reputation = "ContractNormal",
		color = Color3.fromRGB(255, 200, 80),
	},
	HighRisk = {
		label = "HIGH RISK",
		riskLabel = "Extreme",
		riskMultiplier = 1.5,
		heatOnAccept = "AcceptHighRisk",
		license = "ContractsHighRisk",
		reputation = "ContractHighRisk",
		color = Color3.fromRGB(255, 90, 80),
	},
}
ContractConfig.TierOrder = { "Safe", "Normal", "HighRisk" }

ContractConfig.Templates = {
	-- SAFE --------------------------------------------------------------------
	{
		id = "RepairPowerBox",
		title = "Repair power box",
		tier = "Safe",
		siteType = "PowerBox",
		baseReward = 400,
		brief = "Grid fault reported at {site}. Restore power.",
		steps = { { kind = "Interact", prompt = "Repair", hold = 4 } },
		twists = { { id = "LightsReturn", chance = 0.35 } },
	},
	{
		id = "DeliverParcel",
		title = "Deliver a parcel",
		tier = "Safe",
		siteType = "Doorstep",
		baseReward = 360,
		brief = "Overnight parcel for {site}. Pick it up at the depot.",
		steps = {
			{ kind = "Pickup", at = "Depot", item = "DispatchParcel", prompt = "Take parcel" },
			{ kind = "Deliver", to = "Site", item = "DispatchParcel", prompt = "Deliver", hold = 1.5 },
		},
		twists = { { id = "WrongAddress", chance = 0.2, onStep = 1 } },
	},
	{
		id = "StockCheck",
		title = "Night stock check",
		tier = "Safe",
		siteType = "StoreBackroom",
		baseReward = 340,
		brief = "Inventory count requested at {site}.",
		steps = { { kind = "Interact", prompt = "Count stock", hold = 3 } },
	},
	-- NORMAL ------------------------------------------------------------------
	{
		id = "RetrieveScanner",
		title = "Retrieve industrial scanner",
		tier = "Normal",
		siteType = "GarageBay",
		baseReward = 880,
		brief = "A grid scanner was left at {site}. Bring it to the depot.",
		steps = {
			{ kind = "Pickup", at = "Site", item = "IndustrialScanner", prompt = "Take scanner" },
			{ kind = "Deliver", to = "Depot", item = "IndustrialScanner", prompt = "Return scanner", hold = 1 },
		},
	},
	{
		id = "PhotographWindow",
		title = "Photograph an unusual window",
		tier = "Normal",
		siteType = "TowerView",
		baseReward = 760,
		brief = "Residents report a lit window that shouldn't be there. Photograph it from {site}.",
		steps = { { kind = "Interact", prompt = "Take photo", hold = 3 } },
		twists = { { id = "LightsReturn", chance = 0.15 } },
	},
	{
		id = "RestoreRelay",
		title = "Restore communication relay",
		tier = "Normal",
		siteType = "Rooftop",
		baseReward = 920,
		brief = "Dispatch relay offline on {site}. Get up there and reset it.",
		steps = { { kind = "Interact", prompt = "Reset relay", hold = 5 } },
	},
	-- HIGH RISK ---------------------------------------------------------------
	{
		id = "InvestigateStation",
		title = "Investigate abandoned transit station",
		tier = "HighRisk",
		siteType = "StationSignal",
		baseReward = 3000,
		brief = "Signal detected inside closed Line 3. Service door access granted. Find the source at {site}.",
		grantsAccess = { "StationService" },
		steps = { { kind = "Interact", prompt = "Trace signal", hold = 5 } },
		twists = { { id = "LightsReturn", chance = 0.2 } },
	},
	{
		id = "SearchSite9",
		title = "Search restricted construction site",
		tier = "HighRisk",
		siteType = "SiteOffice",
		baseReward = 2800,
		brief = "Equipment went missing at Site 9. Search {site}. Authorized personnel only.",
		steps = {
			{ kind = "Pickup", at = "Site", item = "IndustrialScanner", prompt = "Recover equipment" },
			{ kind = "Deliver", to = "Depot", item = "IndustrialScanner", prompt = "Return equipment", hold = 1 },
		},
	},
	{
		id = "SubstationCore",
		title = "Repair substation core",
		tier = "HighRisk",
		siteType = "SubstationCore",
		baseReward = 3200,
		brief = "Halden Substation is failing. Repair the core at {site} before the district goes dark.",
		grantsAccess = { "SubstationGate" },
		steps = { { kind = "Interact", prompt = "Repair core", hold = 6 } },
		twists = { { id = "Overload", chance = 0.45 } },
	},
}

return ContractConfig
