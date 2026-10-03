-- DistrictConfig: stadens mått, gatunamn och färger. CityBuilder bygger staden från detta.
-- Koordinater: X = öster, Z = söder, Y = upp. Marken ligger på Y = 0.
--
-- Downtown är ett 3 x 3-rutnät av kvarter. Kvarter (kolumn, rad) räknas från nordväst.
-- Vad som står i varje kvarter bestäms av Landmarks (se World/Landmarks).

local DistrictConfig = {}

DistrictConfig.Downtown = {
	id = "Downtown",
	name = "Downtown",
	blockSize = 112,
	streetWidth = 32, -- körbana + trottoarer
	roadWidth = 20,
	sidewalkHeight = 0.6,
	columns = 3,
	rows = 3,
	-- Gator i nord-sydlig riktning (väst -> öst) och öst-västlig (norr -> söder).
	avenues = { "Harlow Ave", "Mercer St", "Quay St", "Vance Ave" },
	streets = { "Northgate Rd", "Fifth St", "Lumen St", "Depot Rd" },
	-- Vilket landmärke som står i vilket kvarter.
	blocks = {
		{ "Site9", "Substation", "Theater" },
		{ "Tower", "Plaza", "Garage" },
		{ "Store", "Offices", "RowHouses" },
	},
	streetLightSpacing = 48,
	lootPointsPerStreetSegment = 1,
}

-- Depån (hubben) ligger söder om Depot Rd.
DistrictConfig.Depot = {
	width = 200,
	depth = 120,
	gap = 0, -- avstånd från stadens södra kant
}

DistrictConfig.Palette = {
	Asphalt = Color3.fromRGB(38, 40, 46),
	Sidewalk = Color3.fromRGB(92, 94, 100),
	Curb = Color3.fromRGB(120, 122, 128),
	LaneWhite = Color3.fromRGB(200, 200, 190),
	LaneYellow = Color3.fromRGB(214, 170, 60),
	Concrete = Color3.fromRGB(110, 112, 118),
	ConcreteDark = Color3.fromRGB(70, 72, 80),
	Brick = Color3.fromRGB(122, 64, 52),
	BrickDark = Color3.fromRGB(84, 48, 42),
	Plaster = Color3.fromRGB(150, 140, 128),
	Steel = Color3.fromRGB(80, 86, 96),
	SafetyYellow = Color3.fromRGB(230, 190, 40),
	WindowDark = Color3.fromRGB(22, 28, 38),
	WindowWarm = Color3.fromRGB(255, 196, 120),
	WindowCool = Color3.fromRGB(180, 214, 255),
	StreetLamp = Color3.fromRGB(255, 186, 110),
	Emergency = Color3.fromRGB(255, 40, 40),
	NeonPink = Color3.fromRGB(255, 70, 170),
	NeonCyan = Color3.fromRGB(60, 230, 255),
	Grass = Color3.fromRGB(46, 70, 42),
}

-- Andel tända fönster en vanlig natt (resten är mörka).
DistrictConfig.LitWindowChance = 0.32

return DistrictConfig
