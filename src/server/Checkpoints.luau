-- Checkpoints: håller koll på alla checkpoint-delar och flyttar fram spelarens nivå
-- när de når nästa checkpoint. Den sista checkpointen är målet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Util = require(script.Parent.Util)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Checkpoints = {}

local byStage: { [number]: BasePart } = {}
local finalStage = 0

-- Den högsta nivån är målet. Klienten läser attributet för att visa "Nivå x / y".
local function refreshFinalStage()
	local highest = 0
	for stage in byStage do
		highest = math.max(highest, stage)
	end
	finalStage = highest
	ReplicatedStorage:SetAttribute("FinalStage", finalStage)
end

local function onTouched(stage: number, hit: BasePart)
	local player = Util.getPlayerFromPart(hit)
	if not player then
		return
	end

	-- Man måste ta checkpoints i ordning, så man inte kan fuska förbi nivåer.
	local current = PlayerData.getStage(player)
	if current == nil or stage ~= current + 1 then
		return
	end

	PlayerData.setStage(player, stage)
	if stage >= finalStage then
		PlayerData.addWin(player)
		PlayerData.addCoins(player, Config.Coins.FinishBonus)
		Notify:FireClient(player, "finish", `You beat the obby! +{Config.Coins.FinishBonus} coins`)
	else
		Notify:FireClient(player, "checkpoint", `Checkpoint {stage}!`)
	end
end

local function setupCheckpoint(part: BasePart)
	local stage = part:GetAttribute("Stage")
	if type(stage) ~= "number" then
		warn(`[Checkpoints] {part:GetFullName()} saknar attributet Stage (ett heltal)`)
		return
	end

	byStage[stage] = part
	refreshFinalStage()

	part.Touched:Connect(function(hit)
		onTouched(stage, hit)
	end)
	part.Destroying:Connect(function()
		if byStage[stage] == part then
			byStage[stage] = nil
			refreshFinalStage()
		end
	end)
end

function Checkpoints.start()
	Util.bindTag(Config.Tags.Checkpoint, setupCheckpoint)
end

function Checkpoints.getFinalStage(): number
	return finalStage
end

-- Var en spelare på nivå `stage` ska dyka upp. Om checkpointen saknas används
-- närmaste lägre checkpoint. Returnerar nil om det inte finns några checkpoints.
function Checkpoints.getSpawnCFrame(stage: number): CFrame?
	for s = stage, 1, -1 do
		local part = byStage[s]
		if part then
			return part.CFrame * CFrame.new(0, part.Size.Y / 2 + 3.5, 0)
		end
	end
	return nil
end

return Checkpoints
