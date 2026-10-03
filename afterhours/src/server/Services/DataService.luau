-- DataService: laddar och sparar spelarprofiler.
--
-- Skydd:
--   * Sessionslås: en profil kan bara vara öppen på en server åt gången (undviker dubbletter).
--     Ett lås från en krashad server räknas som gammalt efter SessionLockTimeout.
--   * Om laddningen misslyckas spelar man vidare med en tillfällig profil som ALDRIG sparas,
--     så riktig data inte skrivs över.
--   * Alla DataStore-anrop har omförsök; inget antar att ett anrop lyckas.
--   * Profilerna migreras via DataSchema (versionsnummer).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataSchema = require(script.Parent.Parent.Logic.DataSchema)

local DataService = {}

local RECORD_FORMAT = "AH1"

type Profile = {
	data: any,
	canSave: boolean,
	dirty: boolean,
	lastLockRefresh: number,
	temporary: boolean,
}

local profiles: { [Player]: Profile } = {}
local store = nil
local jobId = ""

DataService.Loaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, data)

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
DataService.deepCopy = deepCopy

-- Gör om vad som än ligger i DataStore till { format, data, meta }.
local function normalize(old: any)
	if type(old) == "table" and old.format == RECORD_FORMAT then
		old.meta = if type(old.meta) == "table" then old.meta else {}
		return old
	end
	return { format = RECORD_FORMAT, data = old, meta = {} }
end

local function isStudioAccessError(err: any): boolean
	local text = tostring(err)
	return RunService:IsStudio() and (text:find("403") ~= nil or text:find("API") ~= nil or text:find("publish") ~= nil)
end

function DataService.init(_services)
	jobId = if game.JobId ~= "" then game.JobId else "studio"
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, GameConfig.Data.StoreName)
	if ok then
		store = result
	else
		warn("[DataService] DataStore saknas, inget sparas:", result)
	end
end

local function temporaryProfile(player: Player, reason: string)
	warn(`[DataService] {player.Name} spelar med en tillfällig profil ({reason}). Inget sparas.`)
	return { data = DataSchema.default(), canSave = false, dirty = false, lastLockRefresh = 0, temporary = true }
end

-- Laddar profilen (yieldar). Returnerar true om spelaren fortfarande är kvar.
function DataService.load(player: Player): boolean
	local profile: Profile? = nil
	if not store then
		profile = temporaryProfile(player, "ingen DataStore")
	else
		local config = GameConfig.Data
		local attempts = math.max(config.MaxRetries, config.LockRetries + 1)
		for attempt = 1, attempts do
			local lockedElsewhere = false
			local loadedRaw = nil
			local ok, err = pcall(store.UpdateAsync, store, key(player), function(old)
				local record = normalize(old)
				local lock = record.meta.lock
				local fresh = type(lock) == "table"
					and lock.server ~= jobId
					and type(lock.at) == "number"
					and os.time() - lock.at < config.SessionLockTimeout
				if fresh and attempt <= config.LockRetries then
					lockedElsewhere = true
					return nil -- avbryt skrivningen, försök igen strax
				end
				record.meta.lock = { server = jobId, at = os.time() }
				loadedRaw = record.data
				return record
			end)
			if ok and not lockedElsewhere then
				local data, changed = DataSchema.migrate(loadedRaw)
				profile =
					{ data = data, canSave = true, dirty = changed, lastLockRefresh = os.clock(), temporary = false }
				break
			elseif ok and lockedElsewhere then
				-- Den andra servern sparar troligen just nu (t.ex. när man byter server).
				task.wait(5)
			else
				warn(`[DataService] Laddning misslyckades för {player.Name} (försök {attempt}):`, err)
				if isStudioAccessError(err) then
					break
				end
				task.wait(attempt * 2)
			end
			if player.Parent ~= Players then
				break
			end
		end
		if not profile then
			profile = temporaryProfile(player, "laddningen misslyckades")
		end
	end

	if player.Parent ~= Players then
		-- Spelaren hann gå: släpp låset vi kanske tog.
		if profile and profile.canSave then
			profiles[player] = profile
			DataService.release(player)
		end
		return false
	end

	local finalProfile = profile :: Profile
	local now = os.time()
	if finalProfile.data.firstJoin == 0 then
		finalProfile.data.firstJoin = now
	end
	finalProfile.data.lastJoin = now
	finalProfile.dirty = true
	profiles[player] = finalProfile
	DataService.Loaded:Fire(player, finalProfile.data)
	return true
end

function DataService.get(player: Player): any
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.isTemporary(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.temporary
end

-- Ändrar profilen. fn får datan och får ändra den direkt.
function DataService.update(player: Player, fn: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	fn(profile.data)
	profile.dirty = true
	DataService.Changed:Fire(player, profile.data)
	return true
end

function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	local needsLockRefresh = os.clock() - profile.lastLockRefresh > 600
	if not profile.dirty and not release and not needsLockRefresh then
		return true
	end

	local snapshot = deepCopy(profile.data)
	profile.dirty = false
	local stolen = false
	for attempt = 1, GameConfig.Data.MaxRetries do
		local ok, err = pcall(store.UpdateAsync, store, key(player), function(old)
			local record = normalize(old)
			local lock = record.meta.lock
			if type(lock) == "table" and lock.server ~= jobId then
				stolen = true -- en annan server har tagit över; skriv inte över dess data
				return nil
			end
			record.data = snapshot
			record.meta.lock = if release then nil else { server = jobId, at = os.time() }
			record.meta.savedAt = os.time()
			return record
		end)
		if ok then
			if stolen then
				warn(`[DataService] {player.Name}s profil öppnades på en annan server; slutar spara här.`)
				profile.canSave = false
				return false
			end
			profile.lastLockRefresh = os.clock()
			return true
		end
		warn(`[DataService] Sparning misslyckades för {player.Name} (försök {attempt}):`, err)
		if isStudioAccessError(err) then
			break
		end
		task.wait(attempt * 2)
	end
	profile.dirty = true
	return false
end

function DataService.release(player: Player)
	if profiles[player] then
		DataService.save(player, true)
		profiles[player] = nil
	end
end

function DataService.saveAll(release: boolean?)
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.save(player, release)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		DataService.saveAll(true)
	end)
end

return DataService
