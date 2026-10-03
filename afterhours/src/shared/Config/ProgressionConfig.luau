-- ProgressionConfig: rykte (reputation), nivåer, licenser, titlar och upptäckter.
-- Progression låser upp nya möjligheter och status, aldrig "100x starkare".

local ProgressionConfig = {}

-- Rykte man får för olika saker.
ProgressionConfig.ReputationGain = {
	ContractSafe = 20,
	ContractNormal = 45,
	ContractHighRisk = 120,
	SuccessfulExtraction = 30,
	Discovery = 40,
	FailedShift = 5, -- även ett misslyckat skift lär en något
}

-- Nivåer. unlocks = licenser som nivån ger.
ProgressionConfig.Levels = {
	{ level = 1, reputation = 0, name = "PROBATIONARY", unlocks = { "ContractsSafe", "ContractsNormal" } },
	{ level = 2, reputation = 250, name = "CONTRACTOR", unlocks = { "ContractsHighRisk" } },
	{ level = 3, reputation = 900, name = "NIGHT CONTRACTOR", unlocks = { "LockerSlot1" } },
	{ level = 4, reputation = 2200, name = "SENIOR CONTRACTOR", unlocks = { "ScannerPing" } },
	{ level = 5, reputation = 4500, name = "SHIFT LEAD", unlocks = { "LockerSlot2" } },
	{ level = 6, reputation = 8000, name = "AFTERHOURS VETERAN", unlocks = { "LockerSlot3" } },
}

ProgressionConfig.Licenses = {
	ContractsSafe = { name = "Safe contracts" },
	ContractsNormal = { name = "Normal contracts" },
	ContractsHighRisk = { name = "High-risk license" },
	LockerSlot1 = { name = "Locker expansion I" },
	LockerSlot2 = { name = "Locker expansion II" },
	LockerSlot3 = { name = "Locker expansion III" },
	ScannerPing = { name = "Scanner ping" },
}

-- Titlar visas över huvudet. Ingen ger fördelar; de visar vad man varit med om.
ProgressionConfig.Titles = {
	NewHire = { text = "NEW HIRE", color = Color3.fromRGB(200, 205, 215) },
	NightRunner = { text = "NIGHT RUNNER", color = Color3.fromRGB(120, 200, 255), hint = "Extract safely 5 times." },
	FirstResponder = {
		text = "FIRST RESPONDER",
		color = Color3.fromRGB(255, 120, 110),
		hint = "Finish a contract while an incident is active.",
	},
	BlackoutSurvivor = {
		text = "BLACKOUT SURVIVOR",
		color = Color3.fromRGB(255, 214, 90),
		hint = "Make it home from a shift that went dark.",
	},
	LastOneOut = {
		text = "LAST ONE OUT",
		color = Color3.fromRGB(255, 160, 60),
		hint = "Secure your pay in the final seconds.",
	},
	DeepShift = {
		text = "DEEP SHIFT",
		color = Color3.fromRGB(200, 120, 255),
		hint = "Finish a high-risk contract at CRITICAL heat.",
	},
	FoundTheUnknown = { text = "FOUND THE UNKNOWN", color = Color3.fromRGB(110, 255, 214), hidden = true },
	ThreeAM = { text = "03:00", color = Color3.fromRGB(255, 255, 255), hidden = true },
}
ProgressionConfig.DefaultTitle = "NewHire"

-- Platser, personer och hemligheter man kan upptäcka. hidden = visas inte i listan förrän man hittat det.
-- Incidenter och föremål blir automatiskt upptäckter första gången man ser dem.
ProgressionConfig.Discoveries = {
	StationPlatform = { name = "Mercer St Platform", kind = "Location" },
	Maintenance7 = { name = "Maintenance B-7", kind = "Location", hidden = true },
	TowerRoof = { name = "Calloway Roof", kind = "Location" },
	CraneTop = { name = "Top of the Crane", kind = "Location" },
	TheaterStage = { name = "Lumen Theater Stage", kind = "Location", hidden = true },
	Watcher = { name = "The Man on Mercer St", kind = "Person", hidden = true },
	TheCode = { name = "The Code", kind = "Secret", hidden = true },
}

function ProgressionConfig.levelFor(reputation: number)
	local current = ProgressionConfig.Levels[1]
	for _, entry in ProgressionConfig.Levels do
		if reputation >= entry.reputation then
			current = entry
		end
	end
	return current
end

function ProgressionConfig.nextLevel(reputation: number)
	for _, entry in ProgressionConfig.Levels do
		if reputation < entry.reputation then
			return entry
		end
	end
	return nil
end

function ProgressionConfig.hasLicense(reputation: number, license: string): boolean
	for _, entry in ProgressionConfig.Levels do
		if reputation >= entry.reputation and table.find(entry.unlocks, license) then
			return true
		end
	end
	return false
end

return ProgressionConfig
