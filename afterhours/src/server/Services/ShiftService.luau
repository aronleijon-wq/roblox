-- ShiftService: skiftets tillståndsmaskin och spelklockan.
--
--   HUB (förbered dig) -> NIGHT (00:00-02:30) -> EXTRACTION (02:30-03:00, "SHIFT ENDING")
--   -> RESULTS (skiftrapporten) -> HUB ...
--
-- Allt klienten behöver (fas, när fasen slutar, när natten började/slutar) ligger som attribut
-- på ReplicatedStorage, så att varje klient räknar ut exakt samma klocka själv.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ShiftClock = require(ReplicatedStorage.Shared.Logic.ShiftClock)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ShiftService = {}

ShiftService.PhaseChanged = Signal.new() -- (phase, previous)
ShiftService.NightStarted = Signal.new() -- (shiftNumber)
ShiftService.ShiftEnding = Signal.new() -- 02:30
ShiftService.ShiftEnded = Signal.new() -- 03:00, före resultaten (körs synkront)
ShiftService.Tick = Signal.new() -- (clock, nightElapsed) varje sekund under natten

local Phases = Constants.Phases
local Attr = Constants.WorldAttributes
local config = GameConfig.Shift

local state = {
	phase = Phases.Hub,
	shiftNumber = 0,
	phaseEndsAt = 0,
	nightStartedAt = 0,
	nightEndsAt = 0,
}

function ShiftService.now(): number
	return Workspace:GetServerTimeNow()
end

function ShiftService.phase(): string
	return state.phase
end

function ShiftService.shiftNumber(): number
	return state.shiftNumber
end

function ShiftService.isNight(): boolean
	return state.phase == Phases.Night or state.phase == Phases.Extraction
end

function ShiftService.clock(): number
	if not ShiftService.isNight() then
		return if state.phase == Phases.Results then config.EndClock else config.StartClock
	end
	return ShiftClock.clock(
		config.StartClock,
		config.EndClock,
		state.nightStartedAt,
		state.nightEndsAt,
		ShiftService.now()
	)
end

function ShiftService.nightElapsed(): number
	if not ShiftService.isNight() then
		return 0
	end
	return ShiftService.now() - state.nightStartedAt
end

function ShiftService.timeLeftInPhase(): number
	return math.max(0, state.phaseEndsAt - ShiftService.now())
end

local function publish()
	ReplicatedStorage:SetAttribute(Attr.Phase, state.phase)
	ReplicatedStorage:SetAttribute(Attr.ShiftNumber, state.shiftNumber)
	ReplicatedStorage:SetAttribute(Attr.PhaseEndsAt, state.phaseEndsAt)
	ReplicatedStorage:SetAttribute(Attr.NightStartedAt, state.nightStartedAt)
	ReplicatedStorage:SetAttribute(Attr.NightEndsAt, state.nightEndsAt)
end

local function setPhase(phase: string, endsAt: number)
	local previous = state.phase
	state.phase = phase
	state.phaseEndsAt = endsAt
	publish()
	ShiftService.PhaseChanged:FireSync(phase, previous)
end

local function enterHub()
	setPhase(Phases.Hub, ShiftService.now() + config.HubDuration)
end

local function startNight()
	local now = ShiftService.now()
	state.shiftNumber += 1
	state.nightStartedAt = now
	state.nightEndsAt = now + config.NightDuration
	setPhase(
		Phases.Night,
		ShiftClock.timeAt(config.StartClock, config.EndClock, now, state.nightEndsAt, config.ShiftEndingClock)
	)
	ShiftService.NightStarted:FireSync(state.shiftNumber)
end

local function step()
	local now = ShiftService.now()
	if state.phase == Phases.Hub then
		if now >= state.phaseEndsAt then
			if #Players:GetPlayers() == 0 then
				state.phaseEndsAt = now + config.HubDuration -- vänta på spelare
				publish()
			else
				startNight()
			end
		end
	elseif state.phase == Phases.Night then
		if now >= state.phaseEndsAt then
			setPhase(Phases.Extraction, state.nightEndsAt)
			ShiftService.ShiftEnding:FireSync()
		end
	elseif state.phase == Phases.Extraction then
		if now >= state.nightEndsAt then
			ShiftService.ShiftEnded:FireSync(state.shiftNumber)
			setPhase(Phases.Results, now + config.ResultsDuration)
		end
	elseif state.phase == Phases.Results then
		if now >= state.phaseEndsAt then
			enterHub()
		end
	end

	if ShiftService.isNight() then
		ShiftService.Tick:Fire(ShiftService.clock(), ShiftService.nightElapsed())
	end
end

function ShiftService.init(_services) end

function ShiftService.start()
	enterHub()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(step)
			if not ok then
				warn("[ShiftService] fel i skiftloopen:", err)
			end
		end
	end)
end

-- Felsökning ------------------------------------------------------------------------------

-- Hoppar till en viss klocka under natten (t.ex. 2.4 för att testa extraktionen).
function ShiftService.debugSetClock(hours: number)
	if not ShiftService.isNight() then
		startNight()
	end
	local now = ShiftService.now()
	local fraction = (hours - config.StartClock) / (config.EndClock - config.StartClock)
	state.nightStartedAt = now - fraction * config.NightDuration
	state.nightEndsAt = state.nightStartedAt + config.NightDuration
	if hours >= config.ShiftEndingClock then
		state.phase = Phases.Night -- låt step() göra övergången till Extraction
		state.phaseEndsAt = now
	else
		state.phase = Phases.Night
		state.phaseEndsAt = ShiftClock.timeAt(
			config.StartClock,
			config.EndClock,
			state.nightStartedAt,
			state.nightEndsAt,
			config.ShiftEndingClock
		)
	end
	publish()
end

-- Avslutar nuvarande fas direkt.
function ShiftService.debugSkip()
	state.phaseEndsAt = ShiftService.now()
	if state.phase == Phases.Extraction then
		state.nightEndsAt = ShiftService.now()
	end
	publish()
end

return ShiftService
