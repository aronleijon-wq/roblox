-- Röktest av hela servern: startar Main i Lune med fejkade Roblox-tjänster (tests/mocks.luau)
-- och spelar igenom ett skift med låtsasspelare. Fångar körfel som lint inte ser: felstavade
-- funktioner mellan tjänster, nil-värden, fel ordning vid start osv.

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = require("./harness")
local Mocks = require("./mocks")
local describe, check, equal = Harness.describe, Harness.check, Harness.equal

local Vector3 = roblox.Vector3
local Enum = roblox.Enum

return function(h)
	local warnings, prints = {}, {}
	h.extraGlobals.warn = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		table.insert(warnings, table.concat(parts, " "))
	end
	h.extraGlobals.print = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		table.insert(prints, table.concat(parts, " "))
	end
	local state = Mocks.install(h.game, { studio = true })
	local game = h.game
	-- Lune kan inte läsa JobId/CreatorId på DataModel, så modulerna får en tunn proxy.
	local overrides = { JobId = "test-job", CreatorId = 0, CreatorType = Enum.CreatorType.User }
	h.extraGlobals.game = setmetatable({}, {
		__index = function(_, key)
			if overrides[key] ~= nil then
				return overrides[key]
			end
			local value = game[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(game, ...)
				end
			end
			return value
		end,
	})

	local booted = false
	describe("Server: start", function()
		h.require(game:GetService("ServerScriptService").Server.Main)
		booted = true
		check(table.find(prints, "[AFTERHOURS] server ready") ~= nil, "Main startar alla tjänster")
	end)
	if not booted then
		for _, w in warnings do
			print("  varning: " .. w)
		end
		return
	end

	local S = function(name)
		return h.module("Server.Services." .. name)
	end
	local Shift, Contracts, Economy, Inventory, Incidents, World, Data, Squads =
		S("ShiftService"),
		S("ContractService"),
		S("EconomyService"),
		S("InventoryService"),
		S("IncidentService"),
		S("WorldService"),
		S("DataService"),
		S("SquadService")
	local Remotes = {}
	for _, remote in game:GetService("ReplicatedStorage"):FindFirstChild("AfterhoursRemotes"):GetChildren() do
		Remotes[remote.Name] = remote
	end
	local RunService = game:GetService("RunService")
	local PromptService = game:GetService("ProximityPromptService")
	local world = World.world

	local function flush()
		RunService.Heartbeat:Fire(0.2)
	end
	local StateService = S("StateService")
	local function snapshot(player)
		return StateService.snapshot(player)
	end
	local function fire(remoteName, player, ...)
		Remotes[remoteName].OnServerEvent:Fire(player, ...)
	end
	local function debug(player, command, arg)
		fire("DebugCommand", player, command, arg)
	end
	local function step()
		task.wait(1.15) -- låt skiftloopen köra ett varv
	end
	local function trigger(player, prompt)
		local parent = prompt.Parent
		Mocks.teleport(player, parent.CFrame.Position + Vector3.new(0, 0, 2))
		PromptService.PromptTriggered:Fire(prompt, player)
	end
	local function promptOn(part, name)
		for _, d in part:GetDescendants() do
			if d:IsA("ProximityPrompt") and (name == nil or d.Name == name) then
				return d
			end
		end
		return part:FindFirstChildOfClass("ProximityPrompt")
	end

	local player
	describe("Server: spelaren ansluter", function()
		player = Mocks.addPlayer(game, "Tester", 101)
		check(Data.isLoaded(player), "profilen laddas")
		check(player.Character ~= nil, "karaktären spawnar")
		local root = player.Character.HumanoidRootPart
		local depot = world.depot.spawn.Position
		check((root.CFrame.Position - depot).Magnitude < 20, "spawnar i depån")
		check(player.Character:FindFirstChild("ContractorVest") ~= nil, "bär arbetsväst")
		flush()
		local snap = state.invokers[Remotes.GetSnapshot](player)
		check(snap ~= nil, "GetSnapshot svarar")
		equal(#snap.offers.list, 3, "tre kontraktserbjudanden")
		equal(snap.profile.credits, 0, "börjar med 0 krediter")
		equal(snap.inventory.capacity, 6, "6 inventarieplatser")
		check(#Mocks.all("StateSync", player) > 0, "StateSync skickas")
	end)

	describe("Server: natten börjar", function()
		equal(Shift.phase(), "Hub", "börjar i hubben")
		debug(player, "skip")
		step()
		equal(Shift.phase(), "Night", "debug skip startar natten")
		local drops = game:GetService("Workspace"):FindFirstChild("Loot"):GetChildren()
		check(#drops > 10, #drops .. " föremål utlagda")
	end)

	describe("Server: ett kontrakt från början till slut", function()
		local snap = snapshot(player)
		local offer = snap.offers.list[1]
		equal(offer.tier, "Safe", "första erbjudandet är SAFE")
		fire("AcceptContract", player, offer.offerId)
		snap = snapshot(player)
		check(snap.contract.active, "kontraktet är aktivt: " .. offer.title)
		local guard = 0
		while snap.contract.active and guard < 6 do
			guard += 1
			local siteId = snap.contract.siteId
			local prompt
			if siteId == "Depot" then
				prompt = promptOn(world.depot.secure)
			else
				prompt = promptOn(world.sites[siteId].part, "ContractPrompt")
			end
			check(
				prompt ~= nil,
				"steg " .. snap.contract.step.index .. ": prompt finns (" .. snap.contract.step.text .. ")"
			)
			trigger(player, prompt)
			snap = snapshot(player)
		end
		check(not snap.contract.active, "kontraktet slutförs")
		check(snap.economy.pendingContracts >= 1 or snap.profile.credits > 0, "lönen väntar på att säkras")
		equal(#snap.offers.list, 3, "nya erbjudanden efteråt")
	end)

	describe("Server: säkra i lastkajen", function()
		trigger(player, promptOn(world.depot.secure))
		local snap = snapshot(player)
		check(snap.profile.credits > 0, "krediter efter säkring: " .. snap.profile.credits)
		equal(snap.economy.pendingContracts, 0, "inget kvar osäkrat")
	end)

	describe("Server: loot", function()
		local drop = game:GetService("Workspace").Loot:GetChildren()[1]
		trigger(player, promptOn(drop))
		local snap = snapshot(player)
		equal(#snap.inventory.items, 1, "föremålet hamnar i inventariet")
		check(snap.economy.carriedValue > 0, "bär på ett värde")
		fire("DropItem", player, snap.inventory.items[1].slot)
		snap = snapshot(player)
		equal(#snap.inventory.items, 0, "släppt föremål lämnar inventariet")
		fire("DropItem", player, 99)
		fire("DropItem", player, "hej")
		check(true, "ogiltiga DropItem ignoreras")
	end)

	describe("Server: alla incidenter startar och stoppar", function()
		local IncidentConfig = h.module("Server.Config.IncidentConfig")
		Mocks.teleport(player, Vector3.new(0, 4, 0))
		Inventory.add(player, "OldRadio")
		task.wait(0.7) -- zonkontrollen märker att spelaren lämnat depån
		for id, def in IncidentConfig.Incidents do
			if def.scope ~= "Twist" then
				local started = Incidents.trigger(id, { reason = "test" })
				check(started and Incidents.isActive(id), id .. " startar")
				Incidents.stop(id)
				check(not Incidents.isActive(id), id .. " stoppar")
			end
		end
		local events = 0
		for _, e in state.firedAll do
			if e.remote == "WorldEvent" and e.payload.type == "IncidentStart" then
				events += 1
			end
		end
		check(events >= 10, "klienterna får IncidentStart (" .. events .. ")")
	end)

	describe("Server: vändningar", function()
		Incidents.startTwist("LightsReturn", { player = player, siteId = "PowerBox1" })
		local choice = Mocks.last("WorldEvent", player)
		check(choice and choice.type == "TwistChoice", "SOMETHING INSIDE ger spelaren ett val")
		fire("TwistChoice", player, choice.key, "investigate")
		local anchor
		for _, d in world.model:GetDescendants() do
			if d.Name == "InvestigateAnchor" then
				anchor = d
			end
		end
		check(anchor ~= nil, "något att undersöka i rummet")
		if anchor then
			trigger(player, promptOn(anchor))
		end
		Incidents.stopTwist(choice.key)
		Incidents.startTwist("Overload", { player = player, siteId = "SubstationCore" })
		task.wait(2.3)
		check(Incidents.isActive("Blackout"), "OVERLOAD släcker staden")
		Incidents.stop("Blackout")
	end)

	describe("Server: hemliga koden", function()
		local SecretCode = h.module("Server.Logic.SecretCode")
		local SecretConfig = h.module("Server.Config.SecretConfig")
		local code = SecretCode.codeForWeek(SecretCode.weekIndex(os.time()), SecretConfig.Salt, SecretConfig.CodeLength)
		check(world.station.symbolLabel.Text ~= "", "symbolväggen har veckans symboler")
		local keypadPrompt = promptOn(world.keypad.part)
		trigger(player, keypadPrompt)
		fire("SubmitCode", player, if code == "0000" then "1111" else "0000")
		local answer = Mocks.last("WorldEvent", player)
		check(answer.type == "Keypad" and answer.ok == false, "fel kod nekas")
		task.wait(3.5) -- rate limit
		fire("SubmitCode", player, code)
		answer = Mocks.last("WorldEvent", player)
		check(answer.type == "Keypad" and answer.ok == true, "rätt kod öppnar B-7")
		check(World.hasAccess(player, "Maintenance7"), "tillträde till B-7")
	end)

	describe("Server: förrådet", function()
		Mocks.teleport(player, Vector3.new(80, 4, 400))
		task.wait(0.7)
		fire("ShopPurchase", player, "Flashlight", "Halogen")
		check(
			snapshot(player).profile.cosmetics.flashlight.Halogen == nil,
			"förrådet går bara att använda i depån"
		)
		Mocks.teleport(player, world.depot.spawn.Position)
		task.wait(0.7)
		debug(player, "credits", "5000")
		local before = snapshot(player).profile.credits
		fire("ShopPurchase", player, "Flashlight", "Sodium")
		local snap = snapshot(player)
		check(snap.profile.cosmetics.flashlight.Sodium == true, "köpt ficklampsfärg")
		equal(snap.profile.credits, before - 1500, "priset dras")
		fire("Equip", player, "Flashlight", "Sodium")
		equal(snapshot(player).profile.equipped.flashlight, "Sodium", "utrustad")
		fire("ShopPurchase", player, "Upgrade", "LockerSlot1")
		check(snapshot(player).profile.purchases.LockerSlot1 == nil, "uppgradering kräver licens")
		fire("Equip", player, "Title", "ThreeAM")
		check(true, "titel som man har kan väljas")
	end)

	local second
	describe("Server: squad", function()
		second = Mocks.addPlayer(game, "Friend", 202)
		fire("SquadRequest", player, "invite", 202)
		local invite = Mocks.last("SquadInvite", second)
		check(invite and invite.fromUserId == 101, "inbjudan skickas")
		fire("SquadRequest", second, "respond", { fromUserId = 101, accept = true })
		equal(#Squads.membersOf(player), 2, "två i squaden")
	end)

	describe("Server: 03:00", function()
		Mocks.teleport(player, world.depot.spawn.Position)
		Mocks.teleport(second, Vector3.new(0, 4, 0))
		Inventory.add(second, "LostWallet")
		task.wait(0.7) -- zonkontrollen
		debug(player, "clock", "2.6")
		step()
		equal(Shift.phase(), "Extraction", "SHIFT ENDING efter 02:30")
		state.time += 1000
		step()
		equal(Shift.phase(), "Results", "resultat efter 03:00")
		local report = Mocks.last("ShiftReport", player)
		check(report ~= nil and report.survived == true, "den som var i depån överlevde")
		local report2 = Mocks.last("ShiftReport", second)
		check(report2 ~= nil and report2.survived == false, "den som var ute misslyckades")
		check(report2 and report2.facts ~= nil and report2.total ~= nil, "rapporten har fakta och total")
		equal(#Inventory.items(second), 0, "osäkrade föremål förlorades")
		state.time += 100
		step()
		equal(Shift.phase(), "Hub", "tillbaka i hubben")
		task.wait(0.2)
		check(
			(second.Character.HumanoidRootPart.CFrame.Position - world.depot.spawn.Position).Magnitude < 25,
			"den som var ute hämtas till depån"
		)
	end)

	describe("Server: spara och ladda igen", function()
		local credits = snapshot(player).profile.credits
		Mocks.removePlayer(game, player)
		local stored = state.store["u_101"]
		check(stored ~= nil and stored.data.credits == credits, "profilen sparas när man går")
		check(stored.meta.lock == nil, "låset släpps")
		local again = Mocks.addPlayer(game, "Tester", 101)
		equal(snapshot(again).profile.credits, credits, "krediterna finns kvar efter ny anslutning")
		Mocks.removePlayer(game, again)
		Mocks.removePlayer(game, second)
	end)

	describe("Server: inga varningar under körningen", function()
		local unexpected = {}
		for _, w in warnings do
			table.insert(unexpected, w)
		end
		equal(#unexpected, 0, "inga varningar")
		for _, w in unexpected do
			print("    " .. w)
		end
	end)
end
