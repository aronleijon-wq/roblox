-- CityBuilder: bygger Downtown och depån, och returnerar ett register (World) med allt
-- som spelsystemen behöver: kontraktsplatser, lootpunkter, zoner, dörrar, NPC-vägar ...
--
-- Staden byggs med en fast seed, så den ser exakt likadan ut på alla servrar. Det gör att
-- spelare kan prata om platser ("mannen på Mercer St", "hålet i stängslet vid Site 9").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local DistrictConfig = require(script.Parent.Parent.Config.DistrictConfig)
local SecretConfig = require(script.Parent.Parent.Config.SecretConfig)
local Builder = require(script.Parent.Builder)
local Streets = require(script.Parent.Streets)

local Landmarks = {
	Site9 = require(script.Parent.Landmarks.Site9),
	Substation = require(script.Parent.Landmarks.Substation),
	Theater = require(script.Parent.Landmarks.Theater),
	Tower = require(script.Parent.Landmarks.Tower),
	Plaza = require(script.Parent.Landmarks.Plaza),
	Garage = require(script.Parent.Landmarks.Garage),
	Store = require(script.Parent.Landmarks.Store),
	Offices = require(script.Parent.Landmarks.Offices),
	RowHouses = require(script.Parent.Landmarks.RowHouses),
}
local Depot = require(script.Parent.Landmarks.Depot)

local CITY_SEED = 30003

local CityBuilder = {}

local ZONE_TAGS = {
	Safe = Constants.Tags.SafeZone,
	Restricted = Constants.Tags.RestrictedZone,
	Extraction = Constants.Tags.ExtractionZone,
}

function CityBuilder.newWorld(root: Model, config)
	return {
		model = root,
		district = { id = config.id, name = config.name },
		sites = {},
		sitesByType = {},
		lootPoints = {},
		zones = { Safe = {}, Restricted = {}, Extraction = {} },
		gates = {},
		barriers = {},
		npc = { nodes = {}, edges = {}, posts = {} },
		tower = {},
		station = {},
		theater = {},
		substation = {},
		depot = {},
		twistRooms = {},
		alarmPanels = {},
		posters = {},
		discoveries = {},
		keypad = nil,
		maintenance7 = nil,
	}
end

function CityBuilder.build(parent: Instance?)
	local config = DistrictConfig.Downtown
	local root = Instance.new("Model")
	root.Name = "Downtown"
	local world = CityBuilder.newWorld(root, config)
	local sitesFolder = Builder.folder(root, "Sites")
	local zonesFolder = Builder.folder(root, "Zones")
	local lootCount = 0

	local ctx = {
		root = root,
		rng = Rng.new(CITY_SEED),
		config = config,
		palette = DistrictConfig.Palette,
		litChance = DistrictConfig.LitWindowChance,
		world = world,
		customGround = { Plaza = true },
		depotHalfWidth = DistrictConfig.Depot.width / 2,
	}

	function ctx.addSite(siteType: string, id: string, label: string, cframe: CFrame, visual: BasePart?)
		assert(world.sites[id] == nil, "två platser med samma id: " .. id)
		local anchor = Builder.anchor(sitesFolder, "Site_" .. id, Vector3.new(2, 2, 2), cframe, {
			Attributes = { SiteId = id, SiteType = siteType, SiteLabel = label },
			Tags = { Constants.Tags.ContractSite },
		})
		local site =
			{ id = id, siteType = siteType, label = label, part = anchor, visual = visual, position = cframe.Position }
		world.sites[id] = site
		world.sitesByType[siteType] = world.sitesByType[siteType] or {}
		table.insert(world.sitesByType[siteType], site)
		return site
	end

	function ctx.addLoot(zone: string, position: Vector3)
		lootCount += 1
		table.insert(world.lootPoints, { id = "L" .. lootCount, zone = zone, position = position })
	end

	function ctx.addZone(kind: string, name: string, cframe: CFrame, size: Vector3)
		local part = Builder.anchor(zonesFolder, kind .. "Zone", size, cframe, {
			Attributes = { ZoneName = name, ZoneKind = kind },
			Tags = { ZONE_TAGS[kind] },
		})
		table.insert(world.zones[kind], { name = name, cframe = cframe, size = size, part = part })
	end

	function ctx.addGate(gateId: string, part: BasePart)
		part:SetAttribute("GateId", gateId)
		part:AddTag(Constants.Tags.AccessGate)
		world.gates[gateId] = world.gates[gateId] or { id = gateId, parts = {} }
		table.insert(world.gates[gateId].parts, part)
	end

	function ctx.addDiscovery(id: string, cframe: CFrame, size: Vector3)
		table.insert(world.discoveries, { id = id, cframe = cframe, size = size })
	end

	function ctx.addTwistRoom(id: string, label: string, annex)
		world.twistRooms[id] = {
			id = id,
			label = label,
			gateId = "Twist_" .. id,
			door = annex.door,
			doorCFrame = annex.doorCFrame,
			center = annex.center,
			size = annex.size,
			bulb = annex.bulb,
		}
	end

	function ctx.addAlarmPanel(id: string, label: string, part: BasePart, led: BasePart)
		local outward = led.CFrame.Position - part.CFrame.Position
		outward = Vector3.new(outward.X, 0, outward.Z)
		outward = if outward.Magnitude > 0.01 then outward.Unit else Vector3.zAxis
		local site = ctx.addSite("AlarmPanel", id, label, CFrame.new(part.CFrame.Position + outward * 2.5), part)
		world.alarmPanels[id] = { id = id, label = label, part = part, led = led, site = site }
	end

	function ctx.addPoster(anchor: string, part: BasePart, face: Enum.NormalId)
		world.posters[anchor] = { part = part, face = face }
	end

	local layout = Streets.layout(config)
	world.layout = layout
	Streets.build(ctx, layout)
	for row = 1, config.rows do
		for col = 1, config.columns do
			local name = config.blocks[row][col]
			local landmark = Landmarks[name]
			assert(landmark, "okänt landmärke: " .. tostring(name))
			landmark.build(ctx, layout.blockCenters[col][row], layout)
		end
	end
	Depot.build(ctx, layout)
	CityBuilder.writePosters(world)

	root.Parent = parent or Workspace
	return world
end

-- Affischerna med symbolnyckeln. Varje affisch visar bara några av symbolerna.
function CityBuilder.writePosters(world)
	for _, poster in SecretConfig.Posters do
		local target = world.posters[poster.anchor]
		if target then
			local lines = { poster.title, "" }
			for _, digit in poster.digits do
				table.insert(lines, SecretConfig.SymbolForDigit[digit] .. "  =  " .. digit)
			end
			Builder.sign(target.part, target.face, table.concat(lines, "\n"), {
				color = Color3.fromRGB(40, 30, 30),
				background = Color3.fromRGB(240, 232, 214),
				font = Enum.Font.Code,
				pixelsPerStud = 40,
			})
		end
	end
end

return CityBuilder
