-- Tester för världen: bygger hela Downtown i Lune och kontrollerar att allt spelsystemen
-- behöver finns, och att inget hamnat inuti väggar eller i luften.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Vector3 = roblox.Vector3

local Harness = require("./harness")
local describe, check, equal = Harness.describe, Harness.check, Harness.equal

local PART_BUDGET = 9000

local function inside(part, point: Vector3, margin: number): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(localPoint.X) < half.X - margin
		and math.abs(localPoint.Y) < half.Y - margin
		and math.abs(localPoint.Z) < half.Z - margin
end

return function(h)
	local ContractConfig = h.module("Server.Config.ContractConfig")
	local LootConfig = h.module("Server.Config.LootConfig")
	local ProgressionConfig = h.module("Shared.Config.ProgressionConfig")
	local SecretConfig = h.module("Server.Config.SecretConfig")
	local CityBuilder = h.module("Server.World.CityBuilder")

	local world
	describe("World: bygget", function()
		world = CityBuilder.build(h.game:GetService("Workspace"))
		check(world ~= nil and world.model.Parent ~= nil, "staden byggs och hamnar i Workspace")
	end)
	if not world then
		return
	end

	local parts, solid = {}, {}
	for _, d in world.model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d.CanCollide and d.Transparency < 1 then
				table.insert(solid, d)
			end
		end
	end

	describe("World: prestanda", function()
		check(#parts <= PART_BUDGET, string.format("%d delar (budget %d)", #parts, PART_BUDGET))
		local lights = 0
		for _, d in world.model:GetDescendants() do
			if d:IsA("Light") then
				lights += 1
			end
		end
		check(lights <= 260, string.format("%d ljuskällor", lights))
	end)

	local function blockedBy(point: Vector3, ignore)
		for _, part in solid do
			if part ~= ignore and inside(part, point, 0.05) then
				return part
			end
		end
		return nil
	end

	local function supported(point: Vector3, maxDrop: number): boolean
		for drop = 0.2, maxDrop, 0.4 do
			local p = point - Vector3.new(0, drop, 0)
			for _, part in solid do
				if inside(part, p, 0) then
					return true
				end
			end
		end
		return false
	end

	describe("World: kontraktsplatser", function()
		for _, template in ContractConfig.Templates do
			local sites = world.sitesByType[template.siteType]
			check(sites ~= nil and #sites > 0, template.id .. ": det finns platser av typen " .. template.siteType)
		end
		check(world.depot.pickup ~= nil, "depåns plockplats finns")
		for id, site in world.sites do
			local blocker = blockedBy(site.position, site.visual)
			check(
				blocker == nil,
				"plats "
					.. id
					.. " ligger fritt"
					.. (if blocker then " (inuti " .. blocker:GetFullName() .. ")" else "")
			)
			check(supported(site.position, 6), "plats " .. id .. " har golv under sig")
		end
	end)

	describe("World: loot", function()
		local byZone = {}
		for _, point in world.lootPoints do
			byZone[point.zone] = (byZone[point.zone] or 0) + 1
			check(LootConfig.Tables[point.zone] ~= nil, point.id .. ": zonen " .. point.zone .. " har en loottabell")
			local blocker = blockedBy(point.position, nil)
			check(
				blocker == nil,
				point.id
					.. " ("
					.. point.zone
					.. ") ligger fritt"
					.. (if blocker then " (inuti " .. blocker:GetFullName() .. ")" else "")
			)
			check(supported(point.position, 3), point.id .. " (" .. point.zone .. ") ligger på något")
		end
		check(#world.lootPoints >= 40, #world.lootPoints .. " lootpunkter")
		for _, zone in { "Street", "Alley", "Interior", "Restricted", "Station", "Secret" } do
			check((byZone[zone] or 0) > 0, "lootzonen " .. zone .. " används")
		end
	end)

	describe("World: dörrar, zoner och hemligheter", function()
		for _, gateId in
			{ "StationShutter", "StationService", "SubstationGate", "Maintenance7", "TheaterStage", "TowerMachineRoom" }
		do
			check(world.gates[gateId] ~= nil and #world.gates[gateId].parts > 0, "dörren " .. gateId .. " finns")
		end
		local twists = 0
		for id, room in world.twistRooms do
			twists += 1
			check(world.gates[room.gateId] ~= nil, "vändningsrummet " .. id .. " har en dörr")
		end
		equal(twists, 4, "fyra rum för SOMETHING INSIDE")
		check(#world.zones.Safe >= 2, "minst två säkra zoner")
		equal(#world.zones.Restricted, 3, "tre förbjudna zoner")
		equal(#world.zones.Extraction, 1, "en extraktionszon")
		check(
			world.depot.spawn ~= nil and blockedBy(world.depot.spawn.Position, nil) == nil,
			"spawn i depån ligger fritt"
		)
		check(
			world.depot.secure ~= nil and world.depot.dispatch ~= nil and world.depot.locker ~= nil,
			"depåns stationer finns"
		)
		check(world.station.symbolLabel ~= nil, "symbolväggen på stationen finns")
		check(world.keypad ~= nil, "knappsatsen vid B-7 finns")
		check(
			world.tower.windows and #world.tower.windows >= 200,
			"tornet har fönsterrutnät (" .. #(world.tower.windows or {}) .. ")"
		)
		check(world.npc.posts.Watcher ~= nil and world.npc.posts.Dispatcher ~= nil, "NPC-platser finns")
		check(#world.npc.nodes >= 36 and #world.npc.edges >= 48, "NPC-gångvägar finns")
		for _, node in world.npc.nodes do
			check(blockedBy(node + Vector3.new(0, 2.5, 0), nil) == nil, "NPC-nod fri vid " .. tostring(node))
		end
		check(#world.barriers >= 6, "spärrplatser för LOCKDOWN")
		local found = {}
		for _, d in world.discoveries do
			found[d.id] = true
		end
		for id, def in ProgressionConfig.Discoveries do
			if def.kind == "Location" then
				check(found[id], "upptäckten " .. id .. " har en plats i världen")
			end
		end
		for _, poster in SecretConfig.Posters do
			local target = world.posters[poster.anchor]
			check(
				target ~= nil and target.part:FindFirstChildOfClass("SurfaceGui") ~= nil,
				"affischen " .. poster.anchor .. " har text"
			)
		end
	end)

	describe("World: gatorna är fria", function()
		local layout = world.layout
		local blocked = 0
		for _, x in layout.avenueX do
			for z = -200, 200, 8 do
				if blockedBy(Vector3.new(x, 3, z), nil) then
					blocked += 1
				end
			end
		end
		for _, z in layout.streetZ do
			for x = -200, 200, 8 do
				if blockedBy(Vector3.new(x, 3, z), nil) then
					blocked += 1
				end
			end
		end
		equal(blocked, 0, "inga hinder mitt i körbanorna")
	end)

	-- Dumpa delarna så att staden kan ritas upp utanför Roblox (tests/render).
	local out = process.env.AFTERHOURS_DUMP
	if out then
		local dump = {}
		for _, part in parts do
			if part.Transparency < 1 then
				local cf = part.CFrame
				table.insert(dump, {
					n = part.Name,
					c = part.ClassName,
					p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
					s = { part.Size.X, part.Size.Y, part.Size.Z },
					r = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z },
					u = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z },
					l = { cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z },
					col = { part.Color.R, part.Color.G, part.Color.B },
					m = part.Material.Name,
					t = part.Transparency,
					sh = if part:IsA("Part") then part.Shape.Name else "Block",
					lit = part:GetAttribute("Lit"),
					g = part:GetAttribute("Group"),
					row = part:GetAttribute("Row"),
					cx = part:GetAttribute("Col"),
					tags = part:GetTags(),
				})
			end
		end
		local lights = {}
		for _, d in world.model:GetDescendants() do
			if d:IsA("PointLight") or d:IsA("SpotLight") then
				local p = (d.Parent :: any).CFrame.Position
				table.insert(lights, {
					k = d.ClassName,
					p = { p.X, p.Y, p.Z },
					col = { d.Color.R, d.Color.G, d.Color.B },
					range = d.Range,
					b = d.Brightness,
				})
			end
		end
		fs.writeFile(out, serde.encode("json", { parts = dump, lights = lights }))
		print("  (dumpade " .. #dump .. " delar till " .. out .. ")")
	end
end
