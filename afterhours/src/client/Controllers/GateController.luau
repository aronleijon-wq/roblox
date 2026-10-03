-- GateController: dörrar som bara vissa spelare får gå igenom (kontrakt, nyckelkod, incident).
-- Servern skickar listan över dörrar spelaren har tillträde till (state "access"); klienten
-- gör dem genomskinliga och genomgångbara lokalt. Rörelse är klientstyrd i Roblox, så det
-- här räcker; servern kontrollerar ändå avstånd och tillträde vid allt som spelar roll.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local GateController = {}

local app
local allowed: { [string]: boolean } = {}
local originals: { [BasePart]: { transparency: number, collide: boolean } } = {}

local function apply(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local gateId = part:GetAttribute("GateId")
	if type(gateId) ~= "string" then
		return
	end
	-- Öppen för alla sköts av servern; rör inte de delarna.
	if part:GetAttribute("OpenForAll") then
		return
	end
	local original = originals[part]
	if not original then
		original = { transparency = part.Transparency, collide = part.CanCollide }
		originals[part] = original
	end
	if allowed[gateId] then
		part.CanCollide = false
		part.Transparency = math.max(original.transparency, 0.8)
	else
		part.CanCollide = original.collide
		part.Transparency = original.transparency
	end
end

local function applyAll()
	for _, part in CollectionService:GetTagged(Constants.Tags.AccessGate) do
		apply(part)
	end
end

function GateController.start(appRef)
	app = appRef
	CollectionService:GetInstanceAddedSignal(Constants.Tags.AccessGate):Connect(apply)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.AccessGate):Connect(function(part)
		originals[part] = nil
	end)
	app.state.watch("access", function(list)
		allowed = {}
		for _, gateId in list or {} do
			allowed[gateId] = true
		end
		applyAll()
	end)
	applyAll()
end

return GateController
