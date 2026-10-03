-- Meridian Offices: kontorshus med upplyst lobby (larmpanel), brandtrappa till taket,
-- arkivrummet åt Mercer St och ett nattöppet dinerfönster.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Builder = require(script.Parent.Parent.Builder)
local Buildings = require(script.Parent.Parent.Buildings)

local Offices = {}

function Offices.build(ctx, c: Vector3, _layout)
	local palette = ctx.palette
	local root = Builder.model(ctx.root, "MeridianBlock")
	local top = ctx.config.sidewalkHeight

	local tower = Buildings.build(ctx, root, {
		name = "MeridianOffices",
		center = Vector3.new(c.X, 0, c.Z - 22),
		size = Vector3.new(60, 70, 36),
		color = Color3.fromRGB(64, 72, 84),
		material = Enum.Material.Concrete,
		floorHeight = 10,
		windows = { style = "Office", warm = false, litChance = 0.22 },
		fireEscape = "East",
	})
	local logo = Builder.decor(
		root,
		"MeridianLogo",
		Vector3.new(20, 3, 0.4),
		CFrame.new(c.X, 16, c.Z - 40.4),
		Color3.fromRGB(20, 24, 30),
		Enum.Material.SmoothPlastic
	)
	Builder.sign(
		logo,
		Enum.NormalId.Front,
		"MERIDIAN",
		{ color = Color3.fromRGB(150, 210, 255), lit = true, font = Enum.Font.GothamBlack }
	)

	-- Lobbyn ------------------------------------------------------------------------------
	local lobbyCenter = Vector3.new(c.X, top + 0.1, c.Z - 47)
	local lobbySize = Vector3.new(32, 10, 14)
	local lobby = Buildings.room(ctx, root, "Lobby", lobbyCenter, lobbySize, {
		wallColor = Color3.fromRGB(56, 62, 72),
		floorColor = Color3.fromRGB(180, 182, 186),
		floorMaterial = Enum.Material.Marble,
		doors = { { face = "North", width = 6, height = 8, offset = 0 } },
	})
	local front = lobbyCenter.Z - lobbySize.Z / 2 - 0.25
	for _, x in { c.X - 10.5, c.X + 10.5 } do
		local pane = Builder.decor(
			lobby,
			"LobbyGlass",
			Vector3.new(9, 7, 0.3),
			CFrame.new(x, top + 4, front),
			Color3.fromRGB(200, 226, 255),
			Enum.Material.Neon,
			{ Transparency = 0.4 }
		)
		pane:SetAttribute("Lit", true)
		pane:AddTag(Constants.Tags.WindowLight)
	end
	Builder.box(
		lobby,
		"ReceptionDesk",
		Vector3.new(10, 3.4, 3),
		CFrame.new(c.X + 6, top + 1.8, lobbyCenter.Z + 2),
		Color3.fromRGB(40, 44, 52),
		Enum.Material.Marble
	)
	Builder.decor(
		lobby,
		"ElevatorDoors",
		Vector3.new(6, 8, 0.2),
		CFrame.new(c.X - 8, top + 4, lobbyCenter.Z + 5.9),
		Color3.fromRGB(150, 156, 164),
		Enum.Material.Metal
	)
	local ceiling = Builder.decor(
		lobby,
		"LobbyLight",
		Vector3.new(10, 0.2, 2),
		CFrame.new(c.X, top + 9.8, lobbyCenter.Z),
		Color3.fromRGB(230, 240, 255),
		Enum.Material.Neon
	)
	ceiling:AddTag("AH_InteriorLight")
	Builder.pointLight(ceiling, Color3.fromRGB(220, 235, 255), 22, 1, false)
	local alarm = Builder.box(
		lobby,
		"AlarmPanel",
		Vector3.new(0.4, 2.4, 1.8),
		CFrame.new(c.X - 14.8, top + 4.5, lobbyCenter.Z),
		Color3.fromRGB(200, 200, 196),
		Enum.Material.SmoothPlastic
	)
	local alarmLed = Builder.decor(
		lobby,
		"AlarmLed",
		Vector3.new(0.3, 0.3, 0.3),
		alarm.CFrame * CFrame.new(0.25, 0.8, 0),
		Color3.fromRGB(40, 255, 80),
		Enum.Material.Neon
	)
	ctx.addAlarmPanel("AlarmOffices", "the Meridian Offices lobby", alarm, alarmLed)
	ctx.addLoot("Interior", Vector3.new(c.X - 10, top + 0.6, lobbyCenter.Z + 3))

	-- Relä på taket (Rooftop-kontrakt), nås via brandtrappan
	local roofY = 70
	local relay = Builder.box(
		root,
		"RelayBox",
		Vector3.new(3, 4, 2),
		CFrame.new(c.X + 18, roofY + 2, c.Z - 12),
		Color3.fromRGB(70, 76, 84),
		Enum.Material.Metal
	)
	ctx.addSite("Rooftop", "OfficeRelay", "the Meridian Offices roof", relay.CFrame * CFrame.new(0, 0, -2.5), relay)
	ctx.addLoot("Interior", Vector3.new(c.X - 20, roofY + 0.5, c.Z - 30))
	local _ = tower

	-- Arkivet (rum för SOMETHING INSIDE)
	local archive = Buildings.annex(ctx, root, {
		name = "Archive",
		center = Vector3.new(c.X - 45, top, c.Z - 25),
		size = Vector3.new(14, 9, 14),
		doorFace = "West",
		gateId = "Twist_Archive",
		sign = "MERIDIAN ARCHIVE",
		wallColor = Color3.fromRGB(64, 72, 84),
		wallMaterial = Enum.Material.Concrete,
	})
	ctx.addTwistRoom("Archive", "the Meridian archive room", archive)

	-- Södra halvan av kvarteret -------------------------------------------------------------
	Buildings.build(ctx, root, {
		name = "SouthResidences",
		center = Vector3.new(c.X - 28, 0, c.Z + 31),
		size = Vector3.new(48, 50, 46),
		color = palette.Plaster,
		material = Enum.Material.Concrete,
		windows = { faces = { "South", "West", "North" }, style = "Residential" },
	})
	Buildings.build(ctx, root, {
		name = "Diner",
		center = Vector3.new(c.X + 28, 0, c.Z + 31),
		size = Vector3.new(48, 30, 46),
		color = Color3.fromRGB(150, 60, 50),
		material = Enum.Material.Brick,
		windows = { faces = { "East", "South" }, style = "Residential" },
		storefront = { face = "North", sign = "ALL NIGHT DINER", signColor = Color3.fromRGB(255, 120, 90), lit = true },
	})
	Builder.box(
		root,
		"Dumpster",
		Vector3.new(6, 4, 3.5),
		CFrame.new(c.X + 10, top + 2, c.Z + 2),
		Color3.fromRGB(40, 70, 52),
		Enum.Material.Metal
	)
	ctx.addLoot("Alley", Vector3.new(c.X - 12, top + 0.5, c.Z + 2))
	return root
end

return Offices
