-- SecretService: stadens gemensamma mysterium.
-- Affischer (CityBuilder) visar symbolnyckeln i bitar. Väggen nere på stationen visar veckans
-- symbolföljd (sätts här). Rätt kod i knappsatsen vid Maintenance B-7 öppnar dörren.
-- Koden finns bara på servern och byts varje måndag, samma på alla servrar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local SecretConfig = require(script.Parent.Parent.Config.SecretConfig)
local SecretCode = require(script.Parent.Parent.Logic.SecretCode)

local SecretService = {}

local services
local currentWeek = -1
local currentCode = ""
local lastKeypad: { [Player]: number } = {}

local NOTE_B7 = "SHIFT LOG, B-7. 02:51 - lights on 19F again. There is no 19F. "
	.. "02:58 - he's on the plaza. Same spot. 03:00 - "

function SecretService.init(registry)
	services = registry
end

local function refresh()
	local week = SecretCode.weekIndex(os.time())
	if week == currentWeek then
		return
	end
	currentWeek = week
	currentCode = SecretCode.codeForWeek(week, SecretConfig.Salt, SecretConfig.CodeLength)
	local label = services.World.world.station.symbolLabel
	if label then
		label.Text = table.concat(SecretCode.symbolsFor(currentCode, SecretConfig.SymbolForDigit), "  ")
	end
end

local function onSubmit(player: Player, code: any)
	if type(code) ~= "string" or #code ~= SecretConfig.CodeLength or not code:match("^%d+$") then
		return
	end
	local keypad = services.World.world.keypad
	if not keypad or not lastKeypad[player] or os.clock() - lastKeypad[player] > 90 then
		return
	end
	if not services.Security.near(player, keypad.part.CFrame.Position, 12) then
		return
	end
	refresh()
	if code == currentCode then
		services.World.grant(player, keypad.gateId, SecretConfig.OpenSeconds)
		services.Progression.discover(player, "TheCode")
		services.Remotes.WorldEvent:FireClient(player, { type = "Keypad", ok = true })
		services.State.notify(player, "discovery", "ACCESS GRANTED", "Maintenance B-7 is open.", 5)
		services.Telemetry.event(player, "SecretCodeSolved", 1, { week = currentWeek })
	else
		services.Remotes.WorldEvent:FireClient(player, { type = "Keypad", ok = false })
	end
end

function SecretService.start()
	refresh()
	services.Interaction.register(Constants.Actions.Keypad, function(player)
		lastKeypad[player] = os.clock()
	end)
	services.Interaction.register(Constants.Actions.Investigate .. ":NoteB7", function(player)
		services.State.notify(player, "discovery", "SHIFT LOG", NOTE_B7, 10)
	end)
	-- Nödknappen på stationen: öppnar servicedörren inifrån för den som är därnere.
	services.Interaction.register(Constants.Actions.Investigate .. ":StationService", function(player)
		services.World.grant(player, "StationService", 60)
		services.State.notify(player, "info", nil, "Service door released. Get out.", 4)
	end)
	services.Security.on(services.Remotes.SubmitCode, "SubmitCode", onSubmit)
	services.Player.Leaving:Connect(function(player)
		lastKeypad[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(600)
			refresh()
		end
	end)
end

return SecretService
