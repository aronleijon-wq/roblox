-- PlayerData: laddar och sparar spelarnas framsteg (nivå, mynt, vinster) i en DataStore,
-- och visar dem i topplistan via leaderstats.
--
-- OBS: För att spara i Studio måste du publicera spelet och slå på
-- Game Settings -> Security -> "Enable Studio Access to API Services".
-- Utan det fungerar spelet ändå, men inget sparas.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

export type Data = {
	stage: number,
	coins: number,
	wins: number,
}

type Profile = {
	data: Data,
	canSave: boolean, -- false om laddningen misslyckades, så vi inte skriver över riktig data
	dirty: boolean, -- true om något ändrats sedan senaste sparningen
	stats: { [string]: IntValue },
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.Data.StoreName)
	if ok then
		store = result
	else
		warn("[PlayerData] Kunde inte öppna DataStore, inget kommer sparas:", result)
	end
end

local function defaultData(): Data
	return { stage = 1, coins = 0, wins = 0 }
end

-- Tar sparad data och fyller i det som saknas med standardvärden.
local function reconcile(saved: any): Data
	local data = defaultData()
	if type(saved) == "table" then
		for key, value in data :: any do
			if type(saved[key]) == type(value) then
				(data :: any)[key] = saved[key]
			end
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function loadData(player: Player): Data?
	if not store then
		return nil
	end
	for attempt = 1, Config.Data.MaxRetries do
		local ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			return reconcile(result)
		end
		warn(`[PlayerData] Laddning misslyckades för {player.Name} (försök {attempt}):`, result)
		if RunService:IsStudio() then
			-- I Studio beror det nästan alltid på att API-åtkomst är avstängd; vänta inte i onödan.
			warn(
				"[PlayerData] Inget sparas. Slå på Game Settings -> Security -> Enable Studio Access to API Services."
			)
			break
		end
		if attempt < Config.Data.MaxRetries then
			task.wait(attempt * 2)
		end
	end
	return nil
end

local function createLeaderstats(player: Player, data: Data): { [string]: IntValue }
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local stats = {}
	local function addStat(key: string, name: string, value: number)
		local intValue = Instance.new("IntValue")
		intValue.Name = name
		intValue.Value = value
		intValue.Parent = leaderstats
		stats[key] = intValue
	end
	addStat("stage", Config.Stats.Stage, data.stage)
	addStat("coins", Config.Stats.Coins, data.coins)
	addStat("wins", Config.Stats.Wins, data.wins)

	leaderstats.Parent = player
	return stats
end

-- Laddar spelarens data. Yieldar (väntar) tills laddningen är klar.
function PlayerData.load(player: Player)
	local loaded = loadData(player)
	if player.Parent ~= Players then
		return -- spelaren hann lämna medan vi laddade
	end

	local data = loaded or defaultData()
	profiles[player] = {
		data = data,
		canSave = loaded ~= nil,
		dirty = false,
		stats = createLeaderstats(player, data),
	}
end

function PlayerData.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

local function update(player: Player, key: string, value: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	(profile.data :: any)[key] = value
	profile.stats[key].Value = value
	profile.dirty = true
end

function PlayerData.getStage(player: Player): number?
	local profile = profiles[player]
	return profile and profile.data.stage
end

function PlayerData.setStage(player: Player, stage: number)
	update(player, "stage", stage)
end

function PlayerData.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		update(player, "coins", profile.data.coins + amount)
	end
end

function PlayerData.addWin(player: Player)
	local profile = profiles[player]
	if profile then
		update(player, "wins", profile.data.wins + 1)
	end
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not profile.dirty or not store then
		return
	end

	local snapshot = table.clone(profile.data)
	profile.dirty = false
	for attempt = 1, Config.Data.MaxRetries do
		local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function()
			return snapshot
		end)
		if ok then
			return
		end
		warn(`[PlayerData] Sparning misslyckades för {player.Name} (försök {attempt}):`, err)
		if attempt < Config.Data.MaxRetries then
			task.wait(attempt * 2)
		end
	end
	profile.dirty = true -- försök igen vid nästa autosparning
end

-- Sparar och glömmer spelaren. Anropas när spelaren lämnar.
function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
end

-- Sparar alla spelare och väntar (max ~25 s) tills det är klart. Används när servern stängs.
function PlayerData.saveAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			PlayerData.save(player)
			pending -= 1
		end)
	end

	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function PlayerData.startAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player in profiles do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
end

return PlayerData
