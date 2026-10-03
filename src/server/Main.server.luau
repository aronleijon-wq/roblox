-- Main: startpunkten för servern. Bygger banan, startar alla system och tar hand om spelare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Checkpoints = require(script.Parent.Checkpoints)
local Coins = require(script.Parent.Coins)
local CourseBuilder = require(script.Parent.CourseBuilder)
local Hazards = require(script.Parent.Hazards)
local PlayerData = require(script.Parent.PlayerData)
local Spawner = require(script.Parent.Spawner)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local RestartCourse = Remotes:WaitForChild("RestartCourse") :: RemoteEvent

-- Vi spawnar spelarna själva (se Spawner) så att de hamnar vid sin checkpoint.
Players.CharacterAutoLoads = false

if Config.Course.Enabled then
	CourseBuilder.build()
end
Checkpoints.start()
Hazards.start()
Coins.start()
PlayerData.startAutosave()

local function onPlayerAdded(player: Player)
	PlayerData.load(player)
	if not PlayerData.isLoaded(player) then
		return -- spelaren lämnade medan datan laddades
	end

	-- Om banan har blivit kortare sedan sist hamnar man på sista checkpointen.
	local stage = PlayerData.getStage(player) or 1
	local finalStage = Checkpoints.getFinalStage()
	if finalStage > 0 and stage > finalStage then
		stage = finalStage
		PlayerData.setStage(player, stage)
	end

	Spawner.spawn(player)

	if stage > 1 and stage < finalStage then
		Notify:FireClient(player, "info", `Welcome back! Continuing from stage {stage}.`)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(PlayerData.release)
game:BindToClose(PlayerData.saveAll)

-- Knappen "Play again" i klientens HUD. Servern kollar att spelaren faktiskt har gått i mål.
RestartCourse.OnServerEvent:Connect(function(player)
	local stage = PlayerData.getStage(player)
	local finalStage = Checkpoints.getFinalStage()
	if stage and finalStage > 0 and stage >= finalStage then
		PlayerData.setStage(player, 1)
		Spawner.spawn(player)
	end
end)
