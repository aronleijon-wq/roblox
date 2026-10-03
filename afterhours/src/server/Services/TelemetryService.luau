-- TelemetryService: tunt lager ovanpå Robloxs AnalyticsService.
-- Allt spelet mäter går via de här tre funktionerna, så att mätningen kan bytas ut eller
-- stängas av på ett ställe. Fel i analysen får aldrig påverka spelet (allt i pcall).
--
-- Onboarding-tratten (spec 45): varje steg loggas en gång per spelare, någonsin.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local TelemetryService = {}

TelemetryService.Onboarding = {
	"GameJoined",
	"FirstMovement",
	"FirstContractAccepted",
	"FirstContractCompleted",
	"FirstReward",
	"FirstIncident",
	"FirstRareItem",
	"FirstExtraction",
}

local services
local verbose = false

function TelemetryService.init(registry)
	services = registry
	verbose = RunService:IsStudio()
end

local function debugPrint(...)
	if verbose then
		print("[Telemetry]", ...)
	end
end

function TelemetryService.event(player: Player, name: string, value: number?, fields: { [string]: any }?)
	if verbose then
		local parts = {}
		for k, v in fields or {} do
			table.insert(parts, k .. "=" .. tostring(v))
		end
		debugPrint(player.Name, name, value or "", table.concat(parts, " "))
	end
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1, fields or {})
end

-- Ett steg i onboarding-tratten. Hoppar över steg som redan loggats för spelaren.
function TelemetryService.onboarding(player: Player, stepName: string)
	local step = table.find(TelemetryService.Onboarding, stepName)
	if not step then
		return
	end
	local data = services.Data.get(player)
	if not data or data.onboarding.step >= step then
		return
	end
	services.Data.update(player, function(profile)
		profile.onboarding.step = step
	end)
	debugPrint(player.Name, "onboarding", step, stepName)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, stepName, {})
end

function TelemetryService.economy(
	player: Player,
	source: boolean,
	amount: number,
	balance: number,
	transaction: string,
	sku: string?
)
	debugPrint(player.Name, if source then "+" else "-", amount, transaction, sku or "")
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
		"Credits",
		amount,
		balance,
		transaction,
		sku or transaction,
		{}
	)
end

return TelemetryService
