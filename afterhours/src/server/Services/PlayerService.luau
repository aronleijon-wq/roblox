-- PlayerService: spelarens livscykel. Laddning, spawn i depån, kontraktörens väst och titel,
-- ficklampan, att bli nedslagen, zoner (säker/förbjuden/upptäckter) och skadan utomhus
-- under de sista minuterna före 03:00.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local PlayerService = {}

PlayerService.Ready = Signal.new() -- (player) data laddad, före första spawn
PlayerService.Spawned = Signal.new() -- (player, character)
PlayerService.Downed = Signal.new() -- (player, position) körs synkront innan föremål försvinner
PlayerService.Leaving = Signal.new() -- (player) körs synkront innan datan sparas
PlayerService.ZoneChanged = Signal.new() -- (player, kind, zoneName or nil)

local Attr = Constants.PlayerAttributes
local services

type Tracking = {
	zones: { [string]: string? },
	spawnPosition: Vector3?,
	moved: boolean,
	lastPosition: Vector3?,
	lastCheck: number,
	speedStrikes: number,
	downed: boolean,
}
local tracking: { [Player]: Tracking } = {}

function PlayerService.init(registry)
	services = registry
	Players.CharacterAutoLoads = false
end

-- Kosmetika ------------------------------------------------------------------------------

local function torsoOf(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

local function applyVest(player: Player, character: Model)
	local torso = torsoOf(character)
	if not torso then
		return
	end
	local old = character:FindFirstChild("ContractorVest")
	if old then
		old:Destroy()
	end
	local data = services.Data.get(player)
	local vestId = data and data.equipped.vest or ShopConfig.DefaultVest
	local vestDef = ShopConfig.Vests[vestId] or ShopConfig.Vests[ShopConfig.DefaultVest]

	local vest = Instance.new("Part")
	vest.Name = "ContractorVest"
	vest.Size = torso.Size + Vector3.new(0.12, -0.1, 0.12)
	vest.CFrame = torso.CFrame
	vest.Color = vestDef.color
	vest.Material = Enum.Material.SmoothPlastic
	vest.CanCollide = false
	vest.CanQuery = false
	vest.CanTouch = false
	vest.Massless = true
	vest.CastShadow = false
	local stripe = Instance.new("Part")
	stripe.Name = "Reflector"
	stripe.Size = Vector3.new(torso.Size.X + 0.16, 0.18, torso.Size.Z + 0.16)
	stripe.CFrame = torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.15, 0)
	stripe.Color = Color3.fromRGB(230, 230, 220)
	stripe.Material = Enum.Material.Neon
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.Massless = true
	stripe.CastShadow = false
	for _, part in { vest, stripe } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = part
		weld.Parent = part
	end
	stripe.Parent = vest
	vest.Parent = character
end

local function applyTitle(player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local data = services.Data.get(player)
	local titleId = data and data.equippedTitle or ProgressionConfig.DefaultTitle
	local def = ProgressionConfig.Titles[titleId] or ProgressionConfig.Titles[ProgressionConfig.DefaultTitle]
	player:SetAttribute(Attr.Title, titleId)

	local gui = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not gui then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TitleTag"
		billboard.Size = UDim2.fromOffset(200, 22)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = 70
		billboard.LightInfluence = 0
		billboard.PlayerToHideFrom = player -- man ser inte sin egen titel (mindre skräp på skärmen)
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard
		billboard.Parent = head
		gui = billboard
	end
	local label = (gui :: BillboardGui):FindFirstChild("Title") :: TextLabel
	label.Text = def.text
	label.TextColor3 = def.color
end

local function applyFlashlight(player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local light = head:FindFirstChild("Flashlight") :: SpotLight?
	if not light then
		local spot = Instance.new("SpotLight")
		spot.Name = "Flashlight"
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 50
		spot.Brightness = 2.5
		spot.Shadows = true
		spot.Enabled = false
		spot.Parent = head
		light = spot
	end
	local data = services.Data.get(player)
	local id = data and data.equipped.flashlight or ShopConfig.DefaultFlashlight
	local def = ShopConfig.Flashlights[id] or ShopConfig.Flashlights[ShopConfig.DefaultFlashlight];
	(light :: SpotLight).Color = def.color
end

-- Uppdaterar väst, titel och ficklampa (t.ex. efter ett köp i förrådet).
function PlayerService.refreshCosmetics(player: Player)
	local character = player.Character
	if character then
		applyVest(player, character)
		applyTitle(player, character)
		applyFlashlight(player, character)
	end
end

-- Spawn och nedslagning -------------------------------------------------------------------

local function depotSpawn(): CFrame
	local base = services.World.world.depot.spawn
	local offset = Vector3.new(math.random(-12, 12), 0, math.random(-4, 6))
	return base + offset
end

local function onDowned(player: Player, character: Model)
	local track = tracking[player]
	if not track or track.downed or player.Character ~= character then
		return
	end
	track.downed = true
	player:SetAttribute(Attr.Downed, true)
	local root = character:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart") then root.CFrame.Position else services.World.world.depot.center
	PlayerService.Downed:FireSync(player, position)
	services.Data.update(player, function(data)
		data.stats.downed += 1
	end)
	task.delay(GameConfig.Player.RespawnDelay, function()
		if player.Parent == Players and player.Character == character then
			PlayerService.spawn(player)
		end
	end)
end

function PlayerService.spawn(player: Player)
	if player.Parent ~= Players then
		return
	end
	local spawnCFrame = depotSpawn()
	pcall(player.RequestStreamAroundAsync, player, spawnCFrame.Position, 5)
	local ok, err = pcall(player.LoadCharacterAsync, player)
	if not ok then
		warn(`[PlayerService] kunde inte spawna {player.Name}:`, err)
		return
	end
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(spawnCFrame)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.Player.WalkSpeed
		humanoid.MaxHealth = GameConfig.Player.MaxHealth
		humanoid.Health = GameConfig.Player.MaxHealth
		humanoid.BreakJointsOnDeath = false
		humanoid.Died:Connect(function()
			onDowned(player, character)
		end)
	end
	applyVest(player, character)
	applyTitle(player, character)
	applyFlashlight(player, character)

	local track = tracking[player]
	if track then
		track.downed = false
		track.spawnPosition = spawnCFrame.Position
		track.lastPosition = spawnCFrame.Position
		track.lastCheck = os.clock()
	end
	player:SetAttribute(Attr.Downed, false)
	PlayerService.Spawned:Fire(player, character)
end

-- Spelare som kommer och går ----------------------------------------------------------------

local function onPlayerAdded(player: Player)
	tracking[player] = {
		zones = {},
		spawnPosition = nil,
		moved = false,
		lastPosition = nil,
		lastCheck = os.clock(),
		speedStrikes = 0,
		downed = false,
	}
	if not services.Data.load(player) then
		tracking[player] = nil
		return
	end
	PlayerService.Ready:FireSync(player)
	services.Telemetry.onboarding(player, "GameJoined")
	PlayerService.spawn(player)
end

local function onPlayerRemoving(player: Player)
	if services.Data.isLoaded(player) then
		PlayerService.Leaving:FireSync(player)
	end
	tracking[player] = nil
	services.Data.release(player)
end

-- Zoner, upptäckter, rörelse och skada utomhus -----------------------------------------------

local ZONE_KINDS = { "Safe", "Restricted", "Extraction" }

local function exposureDamagePerSecond(): number
	if not services.Shift.isNight() then
		return 0
	end
	local clock = services.Shift.clock()
	local shift = GameConfig.Shift
	if clock < shift.ExposureClock then
		return 0
	end
	local t = math.clamp((clock - shift.ExposureClock) / (shift.EndClock - shift.ExposureClock), 0, 1)
	local exposure = GameConfig.Exposure
	return exposure.DamagePerSecondStart + (exposure.DamagePerSecondEnd - exposure.DamagePerSecondStart) * t
end

local function checkPlayer(player: Player, track: Tracking, dt: number)
	local _, humanoid, root = services.Security.alive(player)
	if not humanoid or not root then
		return
	end
	local position = root.CFrame.Position

	for _, kind in ZONE_KINDS do
		local zone = services.World.zoneAt(position, kind)
		if zone ~= track.zones[kind] then
			track.zones[kind] = zone
			if kind == "Safe" then
				player:SetAttribute(Attr.InSafeZone, zone ~= nil)
			end
			PlayerService.ZoneChanged:Fire(player, kind, zone)
		end
	end

	local discovery = services.World.discoveryAt(position)
	if discovery then
		services.Progression.discover(player, discovery)
	end

	-- Första rörelsen (onboarding)
	if not track.moved and track.spawnPosition and (position - track.spawnPosition).Magnitude > 12 then
		track.moved = true
		services.Telemetry.onboarding(player, "FirstMovement")
	end

	-- Orimlig fart loggas (ingen bestraffning, se SecurityService).
	if track.lastPosition then
		local horizontal = Vector3.new(position.X - track.lastPosition.X, 0, position.Z - track.lastPosition.Z)
		local speed = horizontal.Magnitude / math.max(dt, 0.05)
		if speed > GameConfig.Player.SprintSpeed * 2.2 then
			track.speedStrikes += 1
			if track.speedStrikes >= 3 then
				services.Security.flag(player, string.format("orimlig fart %.0f", speed))
				track.speedStrikes = 0
			end
		else
			track.speedStrikes = math.max(0, track.speedStrikes - 1)
		end
	end
	track.lastPosition = position

	-- Ramlat ur världen
	if position.Y < -60 then
		humanoid.Health = 0
		return
	end

	-- Utomhus de sista minuterna
	if not track.zones.Safe then
		local damage = exposureDamagePerSecond() * dt
		if damage > 0 then
			humanoid:TakeDamage(damage)
		end
	end
end

function PlayerService.inZone(player: Player, kind: string): boolean
	local track = tracking[player]
	return track ~= nil and track.zones[kind] ~= nil
end

function PlayerService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	services.Security.on(services.Remotes.ToggleFlashlight, "ToggleFlashlight", function(player, on)
		if type(on) ~= "boolean" then
			return
		end
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local light = head and head:FindFirstChild("Flashlight")
		if light and light:IsA("SpotLight") then
			light.Enabled = on
		end
	end)

	task.spawn(function()
		local interval = 0.5
		while true do
			task.wait(interval)
			for player, track in tracking do
				local dt = os.clock() - track.lastCheck
				track.lastCheck = os.clock()
				local ok, err = pcall(checkPlayer, player, track, dt)
				if not ok then
					warn("[PlayerService] zonkontroll:", err)
				end
			end
		end
	end)
end

return PlayerService
