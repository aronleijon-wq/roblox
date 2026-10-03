-- Config: här ändrar du det mesta i spelet utan att behöva röra resten av koden.
-- Modulen ligger i ReplicatedStorage så att både servern och klienten kan läsa den.

local Config = {}

-- Namnen som syns i topplistan (leaderstats) uppe till höger i spelet.
Config.Stats = {
	Stage = "Nivå",
	Coins = "Mynt",
	Wins = "Vinster",
}

-- CollectionService-taggar. Sätt samma taggar på egna delar i Studio
-- (Properties -> Tags) så får de automatiskt rätt beteende.
Config.Tags = {
	Checkpoint = "Checkpoint", -- behöver attributet Stage (heltal)
	KillBrick = "KillBrick", -- dödar spelare som nuddar den
	Coin = "Coin", -- mynt som kan plockas upp
	MovingPlatform = "MovingPlatform", -- behöver attributet MoveOffset (Vector3)
	Spinner = "Spinner", -- snurrar runt sin egen Y-axel
	FadingPlatform = "FadingPlatform", -- försvinner en stund efter att någon nuddat den
}

-- Sekunder från att man dör tills man dyker upp vid sin checkpoint igen.
Config.RespawnTime = 1.5

Config.Data = {
	-- Byt namn (t.ex. till "ObbyData_v2") om du vill nollställa allas sparade data.
	StoreName = "ObbyData_v1",
	AutosaveInterval = 120,
	MaxRetries = 3,
}

Config.Coins = {
	Value = 1, -- hur mycket ett mynt är värt
	RespawnTime = 20, -- sekunder innan ett upplockat mynt kommer tillbaka
	FinishBonus = 25, -- extra mynt när man klarar hela banan
}

-- Standardvärden för hinder. Kan skrivas över per del med attribut med samma namn.
Config.Hazards = {
	MoveTime = 2.5, -- sekunder för en rörlig plattform att åka från ena änden till andra
	MovePause = 0.6, -- sekunder den står still i varje ände
	SpinSpeed = 1.5, -- radianer per sekund
	FadeTime = 0.5, -- sekunder innan en försvinnande plattform är borta
	ReappearTime = 3, -- sekunder innan den kommer tillbaka
}

Config.Course = {
	-- Sätt till false om du hellre bygger hela banan själv i Studio.
	Enabled = true,

	-- Var banan börjar. Banan byggs "framåt" (åt -Z) från den här punkten.
	-- Vrid eller flytta den här CFramen så följer hela banan med.
	Origin = CFrame.new(0, 50, 0),

	-- Storlek på checkpoint-plattformarna.
	PadSize = Vector3.new(14, 1, 14),

	-- Hur långt under startplattformen lavahavet ligger.
	LavaDepth = 30,

	Colors = {
		Start = Color3.fromRGB(80, 200, 120),
		Checkpoint = Color3.fromRGB(235, 235, 240),
		Finish = Color3.fromRGB(255, 200, 40),
		KillBrick = Color3.fromRGB(255, 40, 40),
		Lava = Color3.fromRGB(255, 90, 20),
		Coin = Color3.fromRGB(255, 210, 50),
		Truss = Color3.fromRGB(120, 120, 130),
		-- Varje hindersektion får nästa färg i listan.
		Sections = {
			Color3.fromRGB(0, 170, 255),
			Color3.fromRGB(255, 85, 170),
			Color3.fromRGB(120, 220, 90),
			Color3.fromRGB(170, 110, 255),
			Color3.fromRGB(255, 150, 40),
			Color3.fromRGB(40, 210, 200),
		},
	},

	-- Banans sektioner i ordning. Efter varje sektion kommer en checkpoint,
	-- och efter den sista kommer målet. Lägg till, ta bort eller byt ordning fritt!
	--
	-- Tillgängliga typer (kind):
	--   Jumps          - hopp mellan plattformar
	--   KillBricks     - gångbana med lavastreck man måste hoppa över
	--   Moving         - plattformar som åker fram och tillbaka i sidled
	--   Fading         - plattformar som försvinner när man står på dem
	--   Truss          - en klätterstege uppåt
	--   Spinner        - en snurrande lavabom man måste hoppa över
	--
	-- Tips: en vanlig Roblox-karaktär kan hoppa ungefär 8 studs framåt,
	-- så håll "gap" under det.
	Sections = {
		{ kind = "Jumps", count = 5, gap = 4, rise = 1, sway = 2, platformSize = Vector3.new(6, 1, 6) },
		{ kind = "KillBricks", length = 40, width = 6, strips = 4, stripHeight = 1, stripDepth = 2 },
		{ kind = "Moving", count = 3, gap = 3, travel = 10, platformSize = Vector3.new(6, 1, 6) },
		{ kind = "Fading", count = 6, gap = 3, platformSize = Vector3.new(5, 1, 5) },
		{ kind = "Truss", gap = 3, height = 14 },
		{ kind = "Spinner", size = 26, speed = 1.5 },
		{ kind = "Jumps", count = 6, gap = 5, rise = 0, sway = 3, platformSize = Vector3.new(4, 1, 4) },
		{ kind = "KillBricks", length = 48, width = 3, strips = 6, stripHeight = 1, stripDepth = 2 },
		{ kind = "Spinner", size = 30, speed = 2.5 },
	},
}

return Config
