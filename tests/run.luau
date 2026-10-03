-- Tester som körs utanför Roblox med Lune (https://lune-org.github.io/docs).
-- Kör från projektmappen:  lune run tests/run.luau
--
-- Roblox-tjänster som DataStore, Players och Touched-events är fejkade här,
-- så testerna kollar spelets logik och att banan går att klara, inte fysiken.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local ROOT = process.args[1] or "."
local Instance = roblox.Instance

-- Fejkade signaler
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

local touched = {}
roblox.implementProperty("Part", "Touched", function(part)
	touched[part] = touched[part] or signal()
	return touched[part]
end)
roblox.implementProperty("Part", "Destroying", function()
	return signal()
end)

-- Fejkad DataStore
local saved = {}
local failGets = 0
local dataStore = {}
function dataStore:GetAsync(key)
	if failGets > 0 then
		failGets -= 1
		error("simulerat DataStore-fel")
	end
	return saved[key]
end
function dataStore:UpdateAsync(key, fn)
	saved[key] = fn(saved[key])
	return saved[key]
end

local game = Instance.new("DataModel")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local tagged = {}

roblox.implementMethod("DataStoreService", "GetDataStore", function()
	return dataStore
end)
roblox.implementMethod("RunService", "IsStudio", function()
	return false
end)
roblox.implementMethod("Players", "GetPlayerFromCharacter", function(_, character)
	for _, p in Players:GetChildren() do
		if p:GetAttribute("CharacterName") == character.Name then
			return p
		end
	end
	return nil
end)
roblox.implementMethod("CollectionService", "GetTagged", function(_, tag)
	return tagged[tag] or {}
end)
roblox.implementMethod("CollectionService", "GetInstanceAddedSignal", function()
	return signal()
end)

for _, className in { "ReplicatedStorage", "Folder" } do
	roblox.implementMethod(className, "WaitForChild", function(self, name)
		return assert(self:FindFirstChild(name), name)
	end)
end

local fired = {}
roblox.implementMethod("RemoteEvent", "FireClient", function(_, player, kind, text)
	table.insert(fired, { player = player.Name, kind = kind, text = text })
end)

-- Moduler
local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
for _, name in { "Notify", "RestartCourse" } do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
local server = Instance.new("Folder")
server.Name = "Server"
server.Parent = game:GetService("ServerScriptService")

local paths = {}
local function module(parent, name, path)
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Parent = parent
	paths[m] = path
	return m
end
module(shared, "Config", ROOT .. "/src/shared/Config.luau")
for _, name in { "PlayerData", "Util", "Checkpoints", "CourseBuilder" } do
	module(server, name, ROOT .. "/src/server/" .. name .. ".luau")
end

local cache = {}
local function fakeRequire(m)
	if cache[m] == nil then
		local env = { game = game, script = m, require = fakeRequire, task = task }
		for k, v in roblox :: any do
			env[k] = v
		end
		cache[m] = luau.load(fs.readFile(paths[m]), { debugName = m.Name, environment = env })()
	end
	return cache[m]
end

local Config = fakeRequire(shared.Config)
local PlayerData = fakeRequire(server.PlayerData)
local Checkpoints = fakeRequire(server.Checkpoints)
local CourseBuilder = fakeRequire(server.CourseBuilder)

local function newPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p:SetAttribute("CharacterName", name .. "Char")
	p.UserId = userId
	p.Parent = Players
	return p
end
-- Player.UserId går inte att sätta i Lune; låt PlayerData läsa attributet istället.
roblox.implementProperty("Player", "UserId", function(p)
	return p:GetAttribute("UserId")
end)

local function newCharacter(player)
	local char = Instance.new("Model")
	char.Name = player.Name .. "Char"
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = char
	local leg = Instance.new("Part")
	leg.Name = "LeftLeg"
	leg.Parent = char
	char.Parent = Workspace
	return char, leg
end

local function check(cond, msg)
	if not cond then
		error("MISSLYCKADES: " .. msg, 2)
	end
	print("ok - " .. msg)
end

-- 1. Bygg banan och starta checkpoints
local folder = CourseBuilder.build()
for _, part in folder:GetChildren() do
	for _, tag in part:GetTags() do
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], part)
	end
end
Checkpoints.start()
task.wait() -- bindTag använder task.spawn
check(Checkpoints.getFinalStage() == 10, "sista nivån är 10")
check(ReplicatedStorage:GetAttribute("FinalStage") == 10, "FinalStage-attributet replikeras till klienten")
local cf3 = Checkpoints.getSpawnCFrame(3)
local pad3 = folder:FindFirstChild("Checkpoint3")
check(
	cf3 ~= nil and math.abs(cf3.Position.Y - (pad3.CFrame.Position.Y + 0.5 + 3.5)) < 1e-4,
	"spawn-CFrame ligger ovanpå checkpoint 3"
)
check(
	Checkpoints.getSpawnCFrame(99).Position == Checkpoints.getSpawnCFrame(10).Position,
	"för hög nivå -> sista checkpointen"
)

-- 2. Ny spelare utan sparad data
local alice = newPlayer("Alice", 1)
PlayerData.load(alice)
check(PlayerData.getStage(alice) == 1, "ny spelare börjar på nivå 1")
local stats = alice:FindFirstChild("leaderstats")
check(
	stats and stats:FindFirstChild("Nivå").Value == 1 and stats:FindFirstChild("Mynt").Value == 0,
	"leaderstats skapas"
)

local _, leg = newCharacter(alice)
local function touch(stage)
	touched[folder:FindFirstChild("Checkpoint" .. stage)]:Fire(leg)
end
touch(3)
check(PlayerData.getStage(alice) == 1, "kan inte hoppa över checkpoints (3 när man är på 1)")
touch(2)
check(PlayerData.getStage(alice) == 2 and stats:FindFirstChild("Nivå").Value == 2, "checkpoint 2 tas")
check(fired[#fired].kind == "checkpoint" and fired[#fired].text == "Checkpoint 2!", "klienten får meddelande")
touch(2)
check(#fired == 1, "samma checkpoint igen ger inget nytt meddelande")
touch(1)
check(PlayerData.getStage(alice) == 2, "man går inte bakåt av att nudda en gammal checkpoint")
for s = 3, 10 do
	touch(s)
end
check(PlayerData.getStage(alice) == 10, "alla checkpoints i ordning -> nivå 10")
check(fired[#fired].kind == "finish", "mål ger finish-meddelande")
check(stats:FindFirstChild("Vinster").Value == 1, "en vinst registrerad")
check(stats:FindFirstChild("Mynt").Value == Config.Coins.FinishBonus, "målbonus ges")

-- Död spelare kan inte ta checkpoints
local bob = newPlayer("Bob", 2)
PlayerData.load(bob)
local bobChar, bobLeg = newCharacter(bob)
bobChar:FindFirstChildOfClass("Humanoid").Health = 0
touched[folder:FindFirstChild("Checkpoint2")]:Fire(bobLeg)
check(PlayerData.getStage(bob) == 1, "död spelare tar inte checkpoints")

-- 3. Spara och ladda
PlayerData.addCoins(alice, 7)
PlayerData.release(alice)
check(
	saved["player_1"].stage == 10 and saved["player_1"].coins == Config.Coins.FinishBonus + 7,
	"data sparas när spelaren lämnar"
)
check(PlayerData.getStage(alice) == nil, "profilen släpps")

local alice2 = newPlayer("Alice2", 1)
PlayerData.load(alice2)
check(PlayerData.getStage(alice2) == 10, "sparad nivå laddas igen")

-- Gammal/trasig sparfil fylls på med standardvärden
saved["player_3"] = { stage = 4, coins = "trasig" }
local carl = newPlayer("Carl", 3)
PlayerData.load(carl)
check(PlayerData.getStage(carl) == 4, "giltiga fält behålls")
check(
	carl.leaderstats["Mynt"].Value == 0 and carl.leaderstats["Vinster"].Value == 0,
	"saknade/felaktiga fält får standardvärden"
)

-- Inget ändrat -> ingen sparning
saved["player_3"] = "orörd"
PlayerData.save(carl)
check(saved["player_3"] == "orörd", "sparar inte när inget ändrats")

-- 4. Laddning misslyckas helt -> spela vidare men skriv inte över riktig data
saved["player_4"] = { stage = 8, coins = 100, wins = 3 }
failGets = 99
local dana = newPlayer("Dana", 4)
PlayerData.load(dana)
failGets = 0
check(PlayerData.getStage(dana) == 1, "spelaren kan spela trots DataStore-fel")
PlayerData.addCoins(dana, 5)
PlayerData.release(dana)
check(
	saved["player_4"].stage == 8 and saved["player_4"].coins == 100,
	"riktig data skrivs inte över efter misslyckad laddning"
)

-- 5. Spelaren lämnar under laddning
local eve = newPlayer("Eve", 5)
eve.Parent = nil
PlayerData.load(eve)
check(not PlayerData.isLoaded(eve), "ingen profil skapas om spelaren redan lämnat")

-- 6. Banan går att klara: inga hopp längre eller högre än en karaktär klarar
-- (standardkaraktär: WalkSpeed 16, JumpHeight 7.2 -> ca 8.7 studs framåt).
local JUMP_MAX = 8.5
local RISE_MAX = 2
local origin = Config.Course.Origin
local walkable = {}
for _, part in folder:GetChildren() do
	if part.CanCollide and not part:HasTag("KillBrick") and part.Name ~= "SpinnerHub" then
		table.insert(walkable, part)
	end
end

-- Delens utsträckning i banans egna koordinater (x = sidled, z = framåt).
local function extent(part)
	local center = origin:PointToObjectSpace(part.CFrame.Position)
	local half = part.Size / 2
	local minX, maxX = center.X - half.X, center.X + half.X
	local offset = part:GetAttribute("MoveOffset")
	if offset then
		local localOffset = origin:VectorToObjectSpace(offset)
		minX = math.min(minX, minX + localOffset.X)
		maxX = math.max(maxX, maxX + localOffset.X)
	end
	return {
		minX = minX,
		maxX = maxX,
		nearZ = -center.Z - half.Z,
		farZ = -center.Z + half.Z,
		top = center.Y + half.Y,
	}
end

local longest, highest = 0, 0
for i = 1, #walkable - 1 do
	local a, b = walkable[i], walkable[i + 1]
	if a.ClassName ~= "TrussPart" and b.ClassName ~= "TrussPart" then
		local ea, eb = extent(a), extent(b)
		local gapZ = math.max(0, eb.nearZ - ea.farZ)
		local gapX = math.max(0, math.max(ea.minX, eb.minX) - math.min(ea.maxX, eb.maxX))
		local gap = math.sqrt(gapZ * gapZ + gapX * gapX)
		local rise = eb.top - ea.top
		if gap > JUMP_MAX or rise > RISE_MAX then
			error(`MISSLYCKADES: hoppet {a.Name} -> {b.Name} är {gap} studs långt och {rise} studs högt`)
		end
		longest = math.max(longest, gap)
		highest = math.max(highest, rise)
	end
end
check(true, `alla hopp går att klara (längsta {math.round(longest * 10) / 10} studs, högsta {highest} studs)`)

print("\nAlla tester gick igenom!")
