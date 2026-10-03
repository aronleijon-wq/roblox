-- Röktest av klienten: startar alla controllers i Lune, spelar upp exakt det servern skickade
-- till spelaren under servertestet (tillstånd, notiser, incidenter, skiftrapporten ...) och
-- klickar sedan på allt i gränssnittet. Fångar körfel i klientkoden som annars bara syns i Studio.

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = require("./harness")
local Mocks = require("./mocks")
local ClientMocks = require("./clientmocks")
local describe, check, equal = Harness.describe, Harness.check, Harness.equal

local Enum = roblox.Enum
local Vector3 = roblox.Vector3

local USER_ID = 101

return function(h)
	local recorded = Mocks.state -- från servertestet
	local errors, warnings = {}, {}
	h.extraGlobals.warn = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		table.insert(warnings, table.concat(parts, " "))
	end
	h.extraGlobals.print = function() end
	h.extraGlobals.task = ClientMocks.taskLibrary(errors)
	h.extraGlobals.Instance = ClientMocks.instanceLibrary()
	h.extraGlobals.TweenInfo = ClientMocks.TweenInfo
	h.extraGlobals.RaycastParams = ClientMocks.RaycastParams

	local game = h.game
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")

	local GameConfig = h.module("Shared.Config.GameConfig")
	local Constants = h.module("Shared.Constants")

	-- Staden behövs för ljuseffekterna (fönster, gatlyktor, nödljus, dörrar).
	local world = h.module("Server.World.CityBuilder").build(Workspace)

	local player = roblox.Instance.new("Player")
	player.Name = "Tester"
	player.DisplayName = "Tester"
	player.UserId = USER_ID
	player.Parent = Players
	local friend = roblox.Instance.new("Player")
	friend.Name = "Friend"
	friend.DisplayName = "Friend"
	friend.UserId = 202
	friend.Parent = Players

	local cstate = ClientMocks.install(game, player)
	game:GetService("UserInputService").TouchEnabled = true -- testa mobilknapparna också
	local character = Mocks.makeCharacter(player)
	character.Humanoid.MoveDirection = Vector3.zero
	character.Humanoid.Health = 100
	character.Parent = Workspace
	player.Character = character

	-- Väntar tills villkoret gäller (ljuseffekter sker i vågor över flera bildrutor).
	local function waitFor(condition: () -> boolean, timeout: number?): boolean
		local waited = 0
		while not condition() do
			if waited > (timeout or 5) then
				return false
			end
			waited += task.wait(0.05)
		end
		return true
	end

	local function pump(times: number?)
		for _ = 1, times or 3 do
			RunService.Heartbeat:Fire(0.25)
			task.wait()
		end
	end

	local gui
	describe("Klient: start", function()
		h.require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Main)
		task.wait(0.1)
		gui = player.PlayerGui:FindFirstChild("Afterhours")
		check(gui ~= nil, "gränssnittet skapas i PlayerGui")
		check(gui and gui.Root:FindFirstChild("Hud") ~= nil, "HUD:en finns")
		check(cstate.actions.AH_Dispatch ~= nil and cstate.actions.AH_Sprint ~= nil, "kontrollerna är bundna")
		check(player.PlayerGui:FindFirstChild("AfterhoursTouch") ~= nil, "mobilknapparna skapas på pekskärm")
		equal(#errors, 0, "inga fel vid start")
	end)
	if not gui then
		for _, e in errors do
			print("  fel: " .. e)
		end
		return
	end
	local root = gui.Root
	local remotes = ReplicatedStorage:FindFirstChild("AfterhoursRemotes")

	local function deliver(remoteName: string, payload)
		remotes:FindFirstChild(remoteName).OnClientEvent:Fire(payload)
	end
	local function sentToServer(remoteName: string)
		local list = {}
		for _, entry in cstate.toServer do
			if entry.remote == remoteName then
				table.insert(list, entry.args)
			end
		end
		return list
	end
	local function action(name: string, state)
		local bound = cstate.actions[name]
		bound.fn(name, state or Enum.UserInputState.Begin, nil)
	end

	describe("Klient: spelar upp hela serverns skift", function()
		local delivered, kinds = 0, {}
		for index, entry in recorded.sequence do
			if entry.player == nil or entry.player.UserId == USER_ID then
				deliver(entry.remote, entry.payload)
				delivered += 1
				kinds[entry.remote] = true
				if index % 25 == 0 then
					pump(1)
				end
			end
		end
		pump(4)
		check(delivered > 50, "många meddelanden spelades upp (" .. delivered .. ")")
		for _, name in { "StateSync", "Notify", "WorldEvent", "ShiftReport" } do
			check(kinds[name], name .. " kom fram")
		end
		equal(#errors, 0, "inga fel när allt spelades upp")
		for _, e in errors do
			print("    " .. e:sub(1, 600))
		end
	end)

	describe("Klient: HUD", function()
		ClientMocks.setAttribute(ReplicatedStorage, Constants.WorldAttributes.Phase, Constants.Phases.Night)
		ReplicatedStorage:SetAttribute(Constants.WorldAttributes.NightStartedAt, Workspace:GetServerTimeNow())
		ReplicatedStorage:SetAttribute(Constants.WorldAttributes.NightEndsAt, Workspace:GetServerTimeNow() + 720)
		pump(2)
		local clock = root.Hud.Clock.Time
		check(clock.Text:match("^%d%d:%d%d$") ~= nil, "klockan visar en tid (" .. clock.Text .. ")")
		deliver("StateSync", {
			contract = {
				active = true,
				id = "C1",
				title = "Repair the Power Box",
				tier = "Normal",
				tierLabel = "NORMAL",
				siteId = "PowerBox1",
				targetPosition = Vector3.new(100, 0, 100),
				step = { index = 1, total = 1, kind = "Work", text = "Repair the power box." },
				reward = 900,
			},
			heat = { value = 64, tier = "FAILING" },
		})
		pump(2)
		local texts = ClientMocks.texts(root.Hud)
		check(texts:find("Repair the Power Box") ~= nil, "kontraktet visas")
		check(texts:find("FAILING") ~= nil, "HEAT-nivån visas")
		check(texts:find("◆ %d+ m") ~= nil, "avstånd och riktning till målet visas")
		ClientMocks.setAttribute(ReplicatedStorage, Constants.WorldAttributes.Phase, Constants.Phases.Extraction)
		pump(2)
		check(ClientMocks.texts(root.Hud):find("SHIFT ENDING") ~= nil, "SHIFT ENDING visas efter 02:30")
		equal(#errors, 0, "inga fel i HUD:en")
	end)

	describe("Klient: kontraktsprompter och dörrar", function()
		local mine = roblox.Instance.new("ProximityPrompt")
		mine:SetAttribute("Action", Constants.Actions.ContractSite)
		mine:SetAttribute("Target", "PowerBox1")
		mine:AddTag(Constants.Tags.ContractPrompt)
		mine.Parent = Workspace
		local other = roblox.Instance.new("ProximityPrompt")
		other:SetAttribute("Action", Constants.Actions.ContractSite)
		other:SetAttribute("Target", "PowerBox2")
		other:AddTag(Constants.Tags.ContractPrompt)
		other.Parent = Workspace
		local added = game:GetService("CollectionService"):GetInstanceAddedSignal(Constants.Tags.ContractPrompt)
		added:Fire(mine)
		added:Fire(other)
		check(mine.Enabled and not other.Enabled, "bara prompten för ens eget kontrakt syns")

		local gate = world.gates.Maintenance7
		check(gate ~= nil and gate.parts[1].CanCollide, "B-7 är stängd från början")
		deliver("StateSync", { access = { "Maintenance7" } })
		task.wait()
		check(not gate.parts[1].CanCollide, "B-7 öppnas lokalt för den med tillträde")
		deliver("StateSync", { access = {} })
		task.wait()
		check(gate.parts[1].CanCollide, "och stängs igen")
	end)

	describe("Klient: DISPATCH", function()
		deliver("StateSync", { contract = { active = false } })
		action("AH_Dispatch")
		local window = root:FindFirstChild("Dispatch")
		check(window and window.Visible, "TAB öppnar DISPATCH")
		for _, tab in { "CONTRACTS", "SQUAD", "LOCKER", "PROFILE" } do
			local button = ClientMocks.buttons(window, "^" .. tab .. "$")[1]
			ClientMocks.click(button)
			task.wait()
			local text = ClientMocks.texts(window.Content)
			check(#text > 20, tab .. " visar innehåll")
			-- Klicka på allt i fliken
			for _, b in ClientMocks.buttons(window.Content) do
				ClientMocks.click(b)
			end
			task.wait()
			if not window.Visible then
				action("AH_Dispatch")
			end
		end
		check(#sentToServer("AcceptContract") + #sentToServer("RerollContracts") > 0, "jobb kan tas eller bytas")
		check(#sentToServer("SquadRequest") > 0, "spelare kan bjudas in")
		check(cstate.invites > 0, "vänner kan bjudas in")
		check(#sentToServer("ShopPurchase") + #sentToServer("Equip") > 0, "förrådet skickar köp/val")
		ClientMocks.click(ClientMocks.buttons(window, "^✕$")[1])
		check(not window.Visible, "✕ stänger")
		equal(#errors, 0, "inga fel i DISPATCH")
	end)

	describe("Klient: inventariet", function()
		deliver("StateSync", {
			inventory = {
				capacity = 6,
				items = {
					{ slot = 1, uid = "a", id = "OldRadio", contract = false },
					{ slot = 2, uid = "b", id = "UnmarkedPackage", contract = true },
					{ slot = 3, uid = "c", id = "TheObject", contract = false },
				},
			},
		})
		task.wait()
		local bar = root.Hud:FindFirstChild("Inventory")
		equal(#ClientMocks.buttons(bar), 6, "ett fack per plats")
		game:GetService("UserInputService").InputBegan:Fire({ KeyCode = Enum.KeyCode.One }, false)
		check(root.Hud.ItemInfo.Visible, "1 väljer första facket")
		action("AH_Drop")
		local drops = sentToServer("DropItem")
		check(#drops == 1 and drops[1][1] == 1, "G släpper det valda föremålet")
		ClientMocks.click(bar.Slot2)
		action("AH_Drop")
		equal(#sentToServer("DropItem"), 1, "kontraktsföremål kan inte släppas")
		action("AH_NextSlot")
		equal(#errors, 0, "inga fel i inventariet")
	end)

	describe("Klient: rörelse och knappar", function()
		action("AH_Sprint", Enum.UserInputState.Begin)
		character.Humanoid.MoveDirection = Vector3.new(1, 0, 0)
		pump(3)
		equal(character.Humanoid.WalkSpeed, GameConfig.Player.SprintSpeed, "Shift springer")
		pump(40)
		equal(character.Humanoid.WalkSpeed, GameConfig.Player.WalkSpeed, "uthålligheten tar slut")
		action("AH_Sprint", Enum.UserInputState.End)
		character.Humanoid.MoveDirection = Vector3.zero
		action("AH_Flashlight")
		equal(#sentToServer("ToggleFlashlight"), 1, "F tänder/släcker ficklampan")
		action("AH_Scan")
		action("AH_Ping")
		for _, b in ClientMocks.buttons(player.PlayerGui.AfterhoursTouch) do
			ClientMocks.click(b)
		end
		for _, fn in cstate.renderSteps do
			fn(1 / 60)
		end
		equal(#errors, 0, "inga fel i kontrollerna")
	end)

	describe("Klient: dialoger", function()
		deliver("SquadInvite", { fromUserId = 202, fromName = "Friend" })
		local join = ClientMocks.buttons(root.Dialogs, "^JOIN$")[1]
		check(join ~= nil, "inbjudan visas")
		ClientMocks.click(join)
		local last = sentToServer("SquadRequest")
		local args = last[#last]
		check(args[1] == "respond" and args[2].accept == true, "JOIN svarar ja")

		local keypad = roblox.Instance.new("ProximityPrompt")
		keypad:SetAttribute("Action", Constants.Actions.Keypad)
		game:GetService("ProximityPromptService").PromptTriggered:Fire(keypad, player)
		for _, key in { "3", "0", "1", "1", "OK" } do
			ClientMocks.click(ClientMocks.buttons(root.Dialogs.Keypad, "^" .. key .. "$")[1])
		end
		local codes = sentToServer("SubmitCode")
		check(#codes == 1 and codes[1][1] == "3011", "knappsatsen skickar koden")
		deliver("WorldEvent", { type = "Keypad", ok = false })
		task.wait(1)

		deliver("WorldEvent", {
			type = "TwistChoice",
			key = "T1",
			title = "SOMETHING INSIDE",
			text = "The lights came back on.",
			position = Vector3.new(0, 0, 0),
			options = { { id = "investigate", label = "Investigate" }, { id = "leave", label = "Leave" } },
		})
		ClientMocks.click(ClientMocks.buttons(root.Dialogs, "^INVESTIGATE$")[1])
		local choice = sentToServer("TwistChoice")[1]
		check(choice and choice[1] == "T1" and choice[2] == "investigate", "valet skickas till servern")
		equal(#errors, 0, "inga fel i dialogerna")
	end)

	describe("Klient: staden när något händer", function()
		local windows, tower = {}, {}
		for _, part in game:GetService("CollectionService"):GetTagged(Constants.Tags.WindowLight) do
			table.insert(windows, part)
			if part:GetAttribute("Group") == "Tower" then
				table.insert(tower, part)
			end
		end
		local columns = {}
		for _, part in tower do
			local face = part:GetAttribute("Face")
			columns[face] = math.max(columns[face] or 0, part:GetAttribute("Col"))
		end
		for face, count in columns do
			equal(count, 17, "tornets fasad " .. face .. " har 17 kolumner")
		end

		local function litCount(): (number, number)
			local towerLit, otherLit = 0, 0
			for _, part in windows do
				if part.Material == Enum.Material.Neon then
					if part:GetAttribute("Group") == "Tower" then
						towerLit += 1
					else
						otherLit += 1
					end
				end
			end
			return towerLit, otherLit
		end
		local function total(): number
			local a, b = litCount()
			return a + b
		end

		check(total() > 100, "många fönster lyser en vanlig natt (" .. total() .. ")")
		ClientMocks.setAttribute(ReplicatedStorage, "PowerOut", true)
		check(
			waitFor(function()
				return total() == 0
			end),
			"BLACKOUT släcker alla fönster"
		)
		local emergencyOn = 0
		for _, part in game:GetService("CollectionService"):GetTagged(Constants.Tags.EmergencyLight) do
			if part.Material == Enum.Material.Neon then
				emergencyOn += 1
			end
		end
		check(emergencyOn > 0, "nödljusen tänds")
		pump(2)

		ClientMocks.setAttribute(ReplicatedStorage, "OtherLights", true)
		waitFor(function()
			return (litCount()) == 49 * 4
		end)
		task.wait(0.3)
		local towerLit, otherLit = litCount()
		-- "03:00" i 3x5: 0 = 12 rutor, 3 = 11, kolon = 2  ->  12+11+2+12+12 = 49 per fasad
		equal(towerLit, 49 * 4, "THE OTHER LIGHTS ritar 03:00 på alla fyra fasader")
		equal(otherLit, 0, "resten av staden är mörk")

		ClientMocks.setAttribute(ReplicatedStorage, "OtherLights", false)
		ClientMocks.setAttribute(ReplicatedStorage, "PowerOut", false)
		ClientMocks.setAttribute(ReplicatedStorage, "RedSky", true)
		ClientMocks.setAttribute(ReplicatedStorage, "Silent", true)
		ClientMocks.setAttribute(ReplicatedStorage, "CommsDown", true)
		check(
			waitFor(function()
				return total() > 100
			end),
			"fönstren tänds igen när strömmen kommer tillbaka"
		)
		deliver("WorldEvent", { type = "StreetSurge", position = Vector3.new(0, 0, 0) })
		deliver("WorldEvent", { type = "Anomaly", position = Vector3.new(0, 0, 0) })
		deliver("WorldEvent", { type = "Followed", on = true })
		deliver("WorldEvent", { type = "Ping", from = "Friend", position = Vector3.new(5, 0, 5) })
		deliver("WorldEvent", { type = "SoftObjective", text = "Help Friend", position = Vector3.new(5, 0, 5) })
		deliver("Notify", { kind = "radio", title = "DISPATCH", text = "Comms are down.", duration = 1 })
		task.wait(0.2)
		for _, fn in cstate.renderSteps do
			fn(1 / 60)
		end
		ClientMocks.setAttribute(ReplicatedStorage, "RedSky", false)
		ClientMocks.setAttribute(ReplicatedStorage, "Silent", false)
		ClientMocks.setAttribute(ReplicatedStorage, "CommsDown", false)
		task.wait(0.2)
		equal(#errors, 0, "inga fel i ljuseffekterna")
	end)

	describe("Klient: skiftrapporten", function()
		local results = root:FindFirstChild("Results")
		deliver("ShiftReport", {
			title = "AFTERHOURS REPORT",
			shift = "SHIFT #12",
			survived = true,
			headline = "YOU SURVIVED 03:00",
			facts = { { label = "Contracts completed", value = "3" } },
			biggestIncident = "BLACKOUT - DOWNTOWN",
			lines = { { label = "Contract Earnings", value = 1500 }, { label = "Lost On The Street", value = -200 } },
			total = 1300,
			find = { itemId = "TheObject", name = "???", rarity = "Unknown" },
			discoveries = { "Calloway Roof" },
			titlesEarned = { "ThreeAM" },
		})
		task.wait(0.1)
		check(results.Visible, "rapporten visas")
		local text = ClientMocks.texts(results)
		check(text:find("YOU SURVIVED 03:00") ~= nil and text:find("1,300 cr") ~= nil, "rubrik och total stämmer")
		ClientMocks.click(ClientMocks.buttons(results, "^CONTINUE$")[1])
		check(not results.Visible and root.Hud.Visible, "CONTINUE stänger och visar HUD:en igen")
	end)

	describe("Klient: testpanelen", function()
		game:GetService("UserInputService").InputBegan:Fire({ KeyCode = Enum.KeyCode.F8 }, false)
		check(root.Debug.Visible, "F8 öppnar testpanelen i Studio")
		ClientMocks.click(ClientMocks.buttons(root.Debug, "^Blackout$")[1])
		local sent = sentToServer("DebugCommand")
		check(#sent == 1 and sent[1][1] == "incident" and sent[1][2] == "Blackout", "knappen skickar kommandot")
	end)

	describe("Klient: inga fel eller varningar", function()
		task.wait(1)
		equal(#errors, 0, "inga fel i trådar")
		for _, e in errors do
			print("    " .. e:sub(1, 800))
		end
		equal(#warnings, 0, "inga varningar")
		for _, w in warnings do
			print("    " .. w)
		end
	end)
end
