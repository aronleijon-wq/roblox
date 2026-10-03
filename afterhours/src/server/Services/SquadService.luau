-- SquadService: lag på upp till fyra. Man bjuder in från DISPATCH och svarar på inbjudan.
-- Ensam går lika bra. I lag syns man för varandra, får bonus på kontrakt man slutför nära
-- varandra och kan ringa in hjälp (SOMETHING INSIDE).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local SquadService = {}

type Squad = { id: string, members: { Player } }

local squads: { [string]: Squad } = {}
local squadOf: { [Player]: string } = {}
local invites: { [Player]: { from: Player, expires: number } } = {}
local counter = 0
local services

function SquadService.init(registry)
	services = registry
end

function SquadService.membersOf(player: Player): { Player }
	local id = squadOf[player]
	local squad = id and squads[id]
	return if squad then table.clone(squad.members) else { player }
end

function SquadService.nearbyCount(player: Player, radius: number): number
	local here = services.Security.position(player)
	if not here then
		return 0
	end
	local count = 0
	for _, member in SquadService.membersOf(player) do
		if member ~= player then
			local there = services.Security.position(member)
			if there and (there - here).Magnitude <= radius then
				count += 1
			end
		end
	end
	return count
end

local function markSquad(id: string?)
	local squad = id and squads[id]
	if squad then
		for _, member in squad.members do
			services.State.mark(member, "squad")
		end
	end
end

local function leave(player: Player)
	local id = squadOf[player]
	if not id then
		return
	end
	squadOf[player] = nil
	player:SetAttribute(Constants.PlayerAttributes.SquadId, nil)
	local squad = squads[id]
	if squad then
		local index = table.find(squad.members, player)
		if index then
			table.remove(squad.members, index)
		end
		if #squad.members <= 1 then
			for _, member in squad.members do
				squadOf[member] = nil
				member:SetAttribute(Constants.PlayerAttributes.SquadId, nil)
				services.State.mark(member, "squad")
				services.State.notify(member, "info", "SQUAD", "Your squad disbanded.")
			end
			squads[id] = nil
		else
			markSquad(id)
			for _, member in squad.members do
				services.State.notify(member, "info", "SQUAD", player.DisplayName .. " left the squad.")
			end
		end
	end
	services.State.mark(player, "squad")
end

local function join(player: Player, leader: Player): boolean
	local id = squadOf[leader]
	if not id then
		counter += 1
		id = "S" .. counter
		squads[id] = { id = id, members = { leader } }
		squadOf[leader] = id
		leader:SetAttribute(Constants.PlayerAttributes.SquadId, id)
	end
	local squad = squads[id]
	if #squad.members >= GameConfig.Squad.MaxSize then
		return false
	end
	if squadOf[player] then
		leave(player)
	end
	table.insert(squad.members, player)
	squadOf[player] = id
	player:SetAttribute(Constants.PlayerAttributes.SquadId, id)
	markSquad(id)
	for _, member in squad.members do
		services.State.notify(member, "good", "SQUAD", player.DisplayName .. " joined the squad.")
		services.Telemetry.event(member, "FirstSquadPlay", #squad.members)
	end
	return true
end

local function onRequest(player: Player, action: any, arg: any)
	if action == "invite" then
		if type(arg) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(arg)
		if not target or target == player or not services.Data.isLoaded(target) then
			return
		end
		if squadOf[target] and squadOf[target] == squadOf[player] then
			return
		end
		if #SquadService.membersOf(player) >= GameConfig.Squad.MaxSize then
			services.State.notify(
				player,
				"warning",
				"SQUAD",
				"Your squad is full (max " .. GameConfig.Squad.MaxSize .. ")."
			)
			return
		end
		invites[target] = { from = player, expires = os.clock() + GameConfig.Squad.InviteTimeout }
		services.Remotes.SquadInvite:FireClient(target, { fromUserId = player.UserId, fromName = player.DisplayName })
		services.State.notify(player, "info", "SQUAD", "Invite sent to " .. target.DisplayName .. ".")
	elseif action == "respond" then
		if type(arg) ~= "table" or type(arg.accept) ~= "boolean" or type(arg.fromUserId) ~= "number" then
			return
		end
		local invite = invites[player]
		invites[player] = nil
		if
			not invite
			or invite.expires < os.clock()
			or invite.from.UserId ~= arg.fromUserId
			or invite.from.Parent ~= Players
		then
			return
		end
		if arg.accept then
			if not join(player, invite.from) then
				services.State.notify(player, "warning", "SQUAD", "That squad is full.")
			end
		else
			services.State.notify(invite.from, "info", "SQUAD", player.DisplayName .. " declined.")
		end
	elseif action == "leave" then
		leave(player)
	elseif action == "ping" then
		if typeof(arg) ~= "Vector3" then
			return
		end
		local here = services.Security.position(player)
		if not here or (arg - here).Magnitude > 200 then
			return
		end
		for _, member in SquadService.membersOf(player) do
			if member ~= player then
				services.Remotes.WorldEvent:FireClient(
					member,
					{ type = "Ping", from = player.DisplayName, position = arg }
				)
			end
		end
	end
end

function SquadService.start()
	services.Security.on(services.Remotes.SquadRequest, "SquadRequest", onRequest)
	services.Player.Leaving:Connect(function(player)
		leave(player)
		invites[player] = nil
	end)
	services.State.register("squad", function(player)
		local id = squadOf[player]
		local squad = id and squads[id]
		if not squad then
			return { id = nil, members = {} }
		end
		local members = {}
		for _, member in squad.members do
			local status = "Out"
			if member:GetAttribute(Constants.PlayerAttributes.Downed) then
				status = "Down"
			elseif services.Player.inZone(member, "Safe") then
				status = "Safe"
			end
			table.insert(members, {
				userId = member.UserId,
				name = member.DisplayName,
				heat = math.floor(services.Heat.get(member) + 0.5),
				carrying = #services.Inventory.items(member),
				status = status,
			})
		end
		return { id = id, members = members }
	end)
	-- Lagstatus uppdateras med jämna mellanrum (billigt, få spelare per lag).
	task.spawn(function()
		while true do
			task.wait(2)
			for id in squads do
				markSquad(id)
			end
		end
	end)
end

return SquadService
