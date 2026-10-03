-- WorldService: bygger staden och svarar på frågor om den (zoner, platser, upptäckter),
-- och styr dörrar (AccessGate). Dörrar kan öppnas för alla (servern ändrar dem) eller för
-- en enskild spelare (klienten öppnar dem lokalt när servern säger att man har tillträde).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CityBuilder = require(script.Parent.Parent.World.CityBuilder)
local WorldLighting = require(script.Parent.Parent.World.WorldLighting)

local WorldService = {}

WorldService.world = nil :: any
WorldService.AccessChanged = Signal.new() -- (player)

local access: { [Player]: { [string]: number } } = {}
local openForAll: { [string]: boolean } = {}
local originalTransparency: { [BasePart]: number } = {}
local services

function WorldService.init(registry)
	services = registry
	WorldService.world = CityBuilder.build(Workspace)
	WorldLighting.apply()
	for _, gate in WorldService.world.gates do
		for _, part in gate.parts do
			originalTransparency[part] = part.Transparency
		end
	end
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end
WorldService.insideBox = insideBox

-- Namnet på zonen av typen kind (Safe/Restricted/Extraction) som position ligger i, annars nil.
function WorldService.zoneAt(position: Vector3, kind: string): string?
	for _, zone in WorldService.world.zones[kind] do
		if insideBox(zone.cframe, zone.size, position) then
			return zone.name
		end
	end
	return nil
end

function WorldService.discoveryAt(position: Vector3): string?
	for _, discovery in WorldService.world.discoveries do
		if insideBox(discovery.cframe, discovery.size, position) then
			return discovery.id
		end
	end
	return nil
end

function WorldService.site(siteId: string)
	return WorldService.world.sites[siteId]
end

-- Tillträde för en spelare ------------------------------------------------------------

function WorldService.grant(player: Player, gateId: string, seconds: number?)
	access[player] = access[player] or {}
	access[player][gateId] = if seconds then os.clock() + seconds else math.huge
	WorldService.AccessChanged:Fire(player)
end

function WorldService.revoke(player: Player, gateId: string)
	if access[player] and access[player][gateId] then
		access[player][gateId] = nil
		WorldService.AccessChanged:Fire(player)
	end
end

function WorldService.hasAccess(player: Player, gateId: string): boolean
	if openForAll[gateId] then
		return true
	end
	local expires = access[player] and access[player][gateId]
	return expires ~= nil and expires > os.clock()
end

function WorldService.accessList(player: Player): { string }
	local list = {}
	for gateId, expires in access[player] or {} do
		if expires > os.clock() then
			table.insert(list, gateId)
		end
	end
	table.sort(list)
	return list
end

function WorldService.clearAccess(player: Player)
	if access[player] and next(access[player]) then
		access[player] = {}
		WorldService.AccessChanged:Fire(player)
	end
end

-- Öppnar eller stänger en dörr för alla (t.ex. stationens galler under CLOSED STATION).
function WorldService.setOpenForAll(gateId: string, open: boolean)
	local gate = WorldService.world.gates[gateId]
	if not gate then
		warn("[WorldService] okänd dörr:", gateId)
		return
	end
	openForAll[gateId] = open or nil
	for _, part in gate.parts do
		part.CanCollide = not open
		part.Transparency = if open then 0.85 else (originalTransparency[part] or 0)
		part:SetAttribute("OpenForAll", open)
	end
end

function WorldService.isOpenForAll(gateId: string): boolean
	return openForAll[gateId] == true
end

function WorldService.start()
	-- Ta bort utgånget tillträde en gång per sekund.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, gates in access do
				local changed = false
				for gateId, expires in gates do
					if expires <= now then
						gates[gateId] = nil
						changed = true
					end
				end
				if changed then
					WorldService.AccessChanged:Fire(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		access[player] = nil
	end)
	local _ = services
end

return WorldService
