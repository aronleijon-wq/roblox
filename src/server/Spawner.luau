-- Spawner: skapar spelarens karaktär vid rätt checkpoint och återupplivar dem när de dör.
-- Main stänger av Players.CharacterAutoLoads så att det bara är den här modulen som spawnar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Checkpoints = require(script.Parent.Checkpoints)
local PlayerData = require(script.Parent.PlayerData)

local Spawner = {}

local function respawnWhenGone(player: Player, character: Model)
	local scheduled = false
	local function respawnLater()
		if scheduled then
			return
		end
		scheduled = true
		task.delay(Config.RespawnTime, function()
			-- Om spelaren redan fått en ny karaktär (t.ex. "Play again") gör vi inget.
			if player.Character == character then
				Spawner.spawn(player)
			end
		end)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(respawnLater)
	end
	-- Om karaktären försvinner utan att dö (t.ex. faller ut ur världen).
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(Workspace) then
			respawnLater()
		end
	end)
end

function Spawner.spawn(player: Player)
	if player.Parent ~= Players then
		return
	end

	local spawnCFrame = Checkpoints.getSpawnCFrame(PlayerData.getStage(player) or 1)
	if spawnCFrame then
		-- Med StreamingEnabled måste banan hinna laddas in hos klienten innan vi flyttar dit dem.
		pcall(player.RequestStreamAroundAsync, player, spawnCFrame.Position)
	end
	if player.Parent ~= Players then
		return
	end

	local ok, err = pcall(player.LoadCharacter, player)
	if not ok then
		warn(`[Spawner] Kunde inte spawna {player.Name}:`, err)
		return
	end

	local character = player.Character
	if not character then
		return
	end
	if spawnCFrame then
		character:PivotTo(spawnCFrame)
	end
	respawnWhenGone(player, character)
end

return Spawner
