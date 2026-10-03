-- NpcService: stadens folk. Enkla men trovärdiga beteenden, billiga för servern.
--
--   * Nattarbetare promenerar längs trottoarernas gångnät (WALKING/IDLE).
--   * Dispatchern i depån ger tips. Mannen på Mercer Plaza står där varje natt.
--   * Incidenter ändrar beteendet (react): BLACKOUT -> några flyr, några blir stående och en
--     går mot en förbjuden dörr. SILENT CITY -> alla fryser. "Stare" -> alla vänder sig mot
--     närmaste spelare.
--   * THE FOLLOWER är en egen NPC som följer en spelare.
--
-- Animationerna är Robloxs standardanimationer för R15 (AnimationConfig nedan). Om de eller
-- avatarresurserna inte går att ladda används en enkel blockfigur utan animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local NpcService = {}

local AnimationConfig = {
	Walk = "rbxassetid://507777826",
	Idle = "rbxassetid://507766666",
}

local WALKERS = 8

local LOOKS = {
	Worker = {
		skin = Color3.fromRGB(204, 142, 105),
		torso = Color3.fromRGB(60, 80, 110),
		legs = Color3.fromRGB(40, 44, 52),
		vest = Color3.fromRGB(255, 140, 30),
	},
	Guard = {
		skin = Color3.fromRGB(150, 100, 70),
		torso = Color3.fromRGB(30, 34, 46),
		legs = Color3.fromRGB(30, 34, 46),
		vest = nil,
	},
	Cleaner = {
		skin = Color3.fromRGB(230, 190, 150),
		torso = Color3.fromRGB(90, 120, 110),
		legs = Color3.fromRGB(70, 80, 80),
		vest = nil,
	},
	Courier = {
		skin = Color3.fromRGB(120, 80, 60),
		torso = Color3.fromRGB(170, 40, 40),
		legs = Color3.fromRGB(40, 40, 46),
		vest = Color3.fromRGB(214, 255, 60),
	},
	Dispatcher = {
		skin = Color3.fromRGB(240, 200, 170),
		torso = Color3.fromRGB(40, 60, 70),
		legs = Color3.fromRGB(40, 40, 46),
		vest = Color3.fromRGB(80, 230, 255),
	},
	Watcher = {
		skin = Color3.fromRGB(200, 196, 190),
		torso = Color3.fromRGB(70, 66, 60),
		legs = Color3.fromRGB(50, 48, 46),
		vest = nil,
	},
	MissingWorker = {
		skin = Color3.fromRGB(190, 130, 95),
		torso = Color3.fromRGB(60, 80, 110),
		legs = Color3.fromRGB(40, 44, 52),
		vest = Color3.fromRGB(214, 255, 60),
	},
	Follower = {
		skin = Color3.fromRGB(8, 8, 10),
		torso = Color3.fromRGB(8, 8, 10),
		legs = Color3.fromRGB(8, 8, 10),
		vest = nil,
	},
}

local DISPATCHER_LINES = {
	"Pick a contract on the board. Higher pay, higher risk. Your call.",
	"Bring anything you find to the loading bay. If it's still in your bag at 03:00, it's not yours.",
	"Restricted areas raise your HEAT. HEAT pays. HEAT also attracts things.",
	"If the lights go out, the old stage door at the Lumen opens. Don't ask me why.",
	"Squads earn more when they finish jobs together. Form one on the board.",
	"There's a man on Mercer Plaza every night. I don't know who he is. Nobody does.",
	"Seen a strange poster? Write it down. Someone always asks about the posters.",
}

local WATCHER_LINES = {
	"...",
	"You're new. They're always new.",
	"Count the windows. Then count them again.",
	"The trains still run. Just not for us.",
	"Nineteen. There are nineteen. They say eighteen.",
	"It's almost three.",
	"Did you lock it behind you?",
}

type Npc = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	node: number?,
	previous: number?,
	tracks: { [string]: AnimationTrack },
	override: string?,
	gotoTarget: Vector3?,
	alive: boolean,
}

local npcs: { [Model]: Npc } = {}
local folder: Folder
local mode = "Normal"
local adjacency: { [number]: { number } } = {}
local services

function NpcService.init(registry)
	services = registry
	folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = Workspace
	local world = services.World.world
	for _, edge in world.npc.edges do
		adjacency[edge[1]] = adjacency[edge[1]] or {}
		adjacency[edge[2]] = adjacency[edge[2]] or {}
		table.insert(adjacency[edge[1]], edge[2])
		table.insert(adjacency[edge[2]], edge[1])
	end
end

-- Figurer ----------------------------------------------------------------------------------

local function blockRig(look): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	local function limb(name: string, size: Vector3, offset: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.CFrame = root.CFrame * CFrame.new(offset)
		part.CanCollide = name == "Torso"
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	limb("Torso", Vector3.new(2, 2, 1), Vector3.zero, look.torso)
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), look.skin)
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), look.skin)
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), look.skin)
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), look.legs)
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), look.legs)
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function createRig(kind: string): Model
	local look = LOOKS[kind] or LOOKS.Worker
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.torso
	description.LeftLegColor = look.legs
	description.RightLegColor = look.legs
	local ok, model = pcall(
		Players.CreateHumanoidModelFromDescriptionAsync,
		Players,
		description,
		Enum.HumanoidRigType.R15,
		Enum.AssetTypeVerification.Default
	)
	if not ok or not model then
		model = blockRig(look)
	end
	model.Name = kind
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 7
	if kind == "Follower" then
		local head = model:FindFirstChild("Head")
		local face = head and head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy() -- inget ansikte
		end
	end
	if look.vest then
		local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			local vest = Instance.new("Part")
			vest.Name = "Vest"
			vest.Size = torso.Size + Vector3.new(0.12, -0.1, 0.12)
			vest.CFrame = torso.CFrame
			vest.Color = look.vest
			vest.CanCollide = false
			vest.CanQuery = false
			vest.CanTouch = false
			vest.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = vest
			weld.Parent = vest
			vest.Parent = model
		end
	end
	model:AddTag(Constants.Tags.Npc)
	model:SetAttribute("Kind", kind)
	return model
end

local function loadTracks(humanoid: Humanoid): { [string]: AnimationTrack }
	local tracks = {}
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for name, id in AnimationConfig do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall((animator :: Animator).LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			tracks[name] = track
		end
	end
	return tracks
end

local function play(npc: Npc, name: string)
	for trackName, track in npc.tracks do
		if trackName == name then
			if not track.IsPlaying then
				track:Play(0.2)
			end
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

local function spawnNpc(kind: string, cframe: CFrame, anchored: boolean): Npc?
	local model = createRig(kind)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if not humanoid or not root then
		model:Destroy()
		return nil
	end
	model:PivotTo(cframe)
	root.Anchored = anchored
	model.Parent = folder
	if not anchored then
		pcall(root.SetNetworkOwner, root, nil)
	end
	local npc: Npc = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = kind,
		node = nil,
		previous = nil,
		tracks = loadTracks(humanoid),
		override = nil,
		gotoTarget = nil,
		alive = true,
	}
	npcs[model] = npc
	play(npc, "Idle")
	humanoid.Running:Connect(function(speed)
		play(npc, if speed > 0.5 then "Walk" else "Idle")
	end)
	return npc
end

function NpcService.despawn(model: Model)
	local npc = npcs[model]
	if npc then
		npc.alive = false
		npcs[model] = nil
	end
	model:Destroy()
end

-- En stillastående NPC (dispatchern, mannen på torget, en hittad arbetare).
function NpcService.spawnStatic(kind: string, cframe: CFrame, lifetime: number?): Model?
	local npc = spawnNpc(kind, cframe, true)
	if not npc then
		return nil
	end
	if lifetime then
		task.delay(lifetime, function()
			NpcService.despawn(npc.model)
		end)
	end
	return npc.model
end

local function talkPrompt(model: Model, target: string, objectText: string)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", Constants.Actions.Talk)
	prompt:SetAttribute("Target", target)
	prompt.Parent = head
end

-- Promenerande nattarbetare --------------------------------------------------------------------

local function walkTo(npc: Npc, position: Vector3, timeout: number): boolean
	npc.humanoid:MoveTo(position)
	local reached = false
	local connection = npc.humanoid.MoveToFinished:Connect(function(ok)
		reached = ok
	end)
	local started = os.clock()
	while npc.alive and not reached and os.clock() - started < timeout do
		task.wait(0.25)
		if npc.override == "Freeze" then
			break
		end
	end
	connection:Disconnect()
	return reached
end

local function walkerLoop(npc: Npc)
	local nodes = services.World.world.npc.nodes
	while npc.alive and npc.model.Parent do
		if npc.override == "Freeze" or npc.override == "Stare" or npc.override == "Hold" then
			npc.humanoid:MoveTo(npc.root.CFrame.Position)
			task.wait(0.5)
		elseif npc.override == "Goto" and npc.gotoTarget then
			walkTo(npc, npc.gotoTarget, 30)
			npc.override = "Hold"
		else
			local options = adjacency[npc.node or 1] or {}
			local choices = {}
			for _, option in options do
				if option ~= npc.previous then
					table.insert(choices, option)
				end
			end
			if #choices == 0 then
				choices = options
			end
			local nextNode = choices[math.random(1, math.max(#choices, 1))]
			if nextNode then
				npc.previous = npc.node
				npc.node = nextNode
				walkTo(npc, nodes[nextNode] + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)), 25)
			end
			if npc.override == nil and math.random() < 0.25 then
				task.wait(math.random(2, 6)) -- står och väntar en stund
			end
		end
	end
end

local function spawnWalker(index: number)
	local nodes = services.World.world.npc.nodes
	if #nodes == 0 then
		return
	end
	local kinds = { "Worker", "Guard", "Cleaner", "Courier" }
	local start = ((index * 7) % #nodes) + 1
	local npc = spawnNpc(kinds[(index % #kinds) + 1], CFrame.new(nodes[start] + Vector3.new(0, 3, 0)), false)
	if npc then
		npc.node = start
		task.spawn(walkerLoop, npc)
	end
end

-- Reaktioner på incidenter -------------------------------------------------------------------

local function nearestPlayerPosition(position: Vector3): Vector3?
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local p = services.Security.position(player)
		if p and (p - position).Magnitude < bestDistance then
			best, bestDistance = p, (p - position).Magnitude
		end
	end
	return best
end

function NpcService.react(newMode: string)
	mode = newMode
	local walkers = {}
	for _, npc in npcs do
		if npc.kind ~= "Follower" and not npc.root.Anchored then
			table.insert(walkers, npc)
		end
	end
	if newMode == "Silent" then
		for _, npc in walkers do
			npc.override = "Freeze"
			npc.humanoid:MoveTo(npc.root.CFrame.Position)
			play(npc, "None")
		end
	elseif newMode == "Stare" then
		for _, npc in npcs do
			if npc.kind ~= "Follower" then
				local target = nearestPlayerPosition(npc.root.CFrame.Position)
				if target then
					npc.override = "Stare"
					npc.humanoid.AutoRotate = false
					local from = npc.root.CFrame.Position
					npc.root.CFrame = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
					play(npc, "Idle")
				end
			end
		end
	elseif newMode == "Blackout" then
		local theaterDoor = services.World.site("TheaterStageDoor")
		local chosen = nil
		if theaterDoor then
			local bestDistance = math.huge
			for _, npc in walkers do
				local distance = (npc.root.CFrame.Position - theaterDoor.position).Magnitude
				if distance < bestDistance then
					chosen, bestDistance = npc, distance
				end
			end
		end
		for _, npc in walkers do
			npc.humanoid.AutoRotate = true
			if npc == chosen then
				-- en går mot den förbjudna dörren och står kvar där
				npc.override = "Goto"
				npc.gotoTarget = theaterDoor.position
				npc.humanoid.WalkSpeed = 6
			elseif math.random() < 0.5 then
				npc.override = nil
				npc.humanoid.WalkSpeed = 15 -- skyndar sig därifrån
			else
				npc.override = "Hold" -- står kvar och tittar sig omkring
			end
		end
	else
		for _, npc in npcs do
			if npc.kind ~= "Follower" then
				npc.override = nil
				npc.humanoid.AutoRotate = true
				npc.humanoid.WalkSpeed = 7
			end
		end
	end
end

function NpcService.mode(): string
	return mode
end

-- THE FOLLOWER --------------------------------------------------------------------------------

function NpcService.spawnFollower(target: Player, callbacks: { onReach: () -> (), onLost: () -> () }): Model?
	local _, _, targetRoot = services.Security.alive(target)
	if not targetRoot then
		return nil
	end
	local behind = targetRoot.CFrame * CFrame.new(0, 0, 40)
	local npc = spawnNpc("Follower", CFrame.new(behind.Position), false)
	if not npc then
		return nil
	end
	npc.humanoid.WalkSpeed = 9
	task.spawn(function()
		local lastTargetPosition = targetRoot.CFrame.Position
		while npc.alive and npc.model.Parent do
			task.wait(0.4)
			if not npc.alive then
				return -- incidenten tog slut medan vi väntade
			end
			local _, _, root = services.Security.alive(target)
			if not root or services.Player.inZone(target, "Safe") then
				callbacks.onLost()
				return
			end
			local targetPosition = root.CFrame.Position
			local moving = (targetPosition - lastTargetPosition).Magnitude > 0.8
			lastTargetPosition = targetPosition
			local offset = npc.root.CFrame.Position - targetPosition
			local distance = offset.Magnitude
			if distance < 4 then
				callbacks.onReach()
				return
			elseif distance > 110 then
				-- den är alltid bakom dig
				npc.model:PivotTo(root.CFrame * CFrame.new(0, 0, 45))
			elseif moving then
				npc.humanoid.WalkSpeed = 15
				npc.humanoid:MoveTo(targetPosition + offset.Unit * 22)
			else
				npc.humanoid.WalkSpeed = 8
				npc.humanoid:MoveTo(targetPosition)
			end
		end
	end)
	return npc.model
end

-- Start ------------------------------------------------------------------------------------------

function NpcService.start()
	local world = services.World.world
	task.spawn(function()
		local dispatcher = world.npc.posts.Dispatcher
			and NpcService.spawnStatic("Dispatcher", world.npc.posts.Dispatcher)
		if dispatcher then
			talkPrompt(dispatcher, "Dispatcher", "Dispatcher")
		end
		local watcher = world.npc.posts.Watcher and NpcService.spawnStatic("Watcher", world.npc.posts.Watcher)
		if watcher then
			talkPrompt(watcher, "Watcher", "???")
		end
		for index = 1, WALKERS do
			spawnWalker(index)
		end
	end)

	services.Interaction.register(Constants.Actions.Talk .. ":Dispatcher", function(player)
		services.State.notify(player, "radio", "DISPATCHER", DISPATCHER_LINES[math.random(1, #DISPATCHER_LINES)], 6)
	end)
	local watcherIndex = 0
	services.Interaction.register(Constants.Actions.Talk .. ":Watcher", function(player)
		watcherIndex = watcherIndex % #WATCHER_LINES + 1
		services.State.notify(player, "discovery", "THE MAN ON MERCER ST", WATCHER_LINES[watcherIndex], 6)
		services.Progression.discover(player, "Watcher")
	end)
end

return NpcService
