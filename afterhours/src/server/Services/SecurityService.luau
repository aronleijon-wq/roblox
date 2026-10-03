-- SecurityService: allt som kommer från klienten passerar här.
--
-- Klienten skickar bara "jag försökte göra X". Servern kontrollerar:
--   * att spelaren har laddad data och lever
--   * hur ofta begäran skickas (token bucket per spelare och typ)
--   * argumentens typer (varje hanterare validerar sina egna värden)
--   * avstånd till det man interagerar med
-- Avvisade begäranden räknas; vid många loggas spelaren (ingen automatisk bestraffning,
-- så att ärliga spelare med lagg inte drabbas av falsklarm).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RateLimiter = require(script.Parent.Parent.Logic.RateLimiter)

local SecurityService = {}

local limiter = RateLimiter.new(GameConfig.Security.RateLimits)
local strikes: { [Player]: number } = {}
local services

function SecurityService.init(registry)
	services = registry
end

function SecurityService.start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		strikes[player] = nil
	end)
end

function SecurityService.flag(player: Player, reason: string)
	strikes[player] = (strikes[player] or 0) + 1
	if strikes[player] == GameConfig.Security.SuspicionLogThreshold then
		warn(`[Security] {player.Name} ({player.UserId}) har många avvisade begäranden. Senast: {reason}`)
		services.Telemetry.event(player, "SuspiciousActivity", strikes[player], { reason = reason })
	end
end

function SecurityService.allow(player: Player, key: string): boolean
	if limiter:allow(player, key, os.clock()) then
		return true
	end
	SecurityService.flag(player, "rate limit: " .. key)
	return false
end

-- Kopplar en RemoteEvent med rate limit, kontroll av laddad data och felhantering.
function SecurityService.on(remote: RemoteEvent, key: string, handler: (Player, ...any) -> ())
	remote.OnServerEvent:Connect(function(player: Player, ...)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if not services.Data.isLoaded(player) then
			return
		end
		if not SecurityService.allow(player, key) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`[Security] Fel i {key} från {player.Name}:`, err)
		end
	end)
end

-- Samma för RemoteFunction. Returnerar fallback om något går fel.
function SecurityService.onInvoke(remote: RemoteFunction, key: string, handler: (Player, ...any) -> any, fallback: any)
	remote.OnServerInvoke = function(player: Player, ...)
		if not services.Data.isLoaded(player) or not SecurityService.allow(player, key) then
			return fallback
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[Security] Fel i {key} från {player.Name}:`, result)
			return fallback
		end
		return result
	end
end

-- Karaktär, Humanoid och rotdel om spelaren lever, annars nil.
function SecurityService.alive(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character or not character.Parent then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

function SecurityService.position(player: Player): Vector3?
	local _, _, root = SecurityService.alive(player)
	return root and root.CFrame.Position
end

-- Är spelaren inom maxDistance från position (plus marginal för lagg)?
function SecurityService.near(player: Player, position: Vector3, maxDistance: number): boolean
	local here = SecurityService.position(player)
	if not here then
		return false
	end
	local ok = (here - position).Magnitude <= maxDistance + GameConfig.Security.InteractDistanceTolerance
	if not ok then
		SecurityService.flag(player, "för långt bort")
	end
	return ok
end

-- Typkontroller för argument från klienten.
function SecurityService.isString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

function SecurityService.isInteger(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

return SecurityService
