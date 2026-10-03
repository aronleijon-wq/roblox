-- AFTERHOURS: 03:00 - serverns startpunkt.
-- Alla system är moduler i Services/. De får först init(registry) i ordning (bygger saker,
-- skapar prompts) och sedan start() (kopplar händelser, startar loopar). Ordningen nedan
-- är viktig: t.ex. måste världen finnas innan kontrakten skapar sina prompts, och
-- PlayerService startar sist så att alla system hunnit lyssna på nya spelare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ORDER = {
	"Telemetry",
	"Security",
	"Data",
	"World",
	"State",
	"Interaction",
	"Shift",
	"Heat",
	"Inventory",
	"Economy",
	"Progression",
	"Loot",
	"Contracts",
	"Extraction",
	"Squads",
	"Shop",
	"Secrets",
	"Incidents",
	"Npcs",
	"Debug",
	"Player",
}

local MODULE_NAMES = {
	Contracts = "ContractService",
	Squads = "SquadService",
	Secrets = "SecretService",
	Incidents = "IncidentService",
	Npcs = "NpcService",
}

local registry = { Remotes = Remotes.get() }
local folder = script.Parent.Services
for _, name in ORDER do
	local moduleName = MODULE_NAMES[name] or (name .. "Service")
	registry[name] = require(folder:WaitForChild(moduleName))
end

for _, name in ORDER do
	local service = registry[name]
	if service.init then
		service.init(registry)
	end
end

for _, name in ORDER do
	local service = registry[name]
	if service.start then
		service.start()
	end
end

print("[AFTERHOURS] server ready")
