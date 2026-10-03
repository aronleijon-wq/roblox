-- Fejkade Roblox-tjänster för röktestet av servern (tests/server.spec.luau).
-- Lune har riktiga instanser och datatyper men inga händelser, ingen fysik och inga
-- nätverkstjänster. Här lägger vi till precis så mycket som servern behöver.

local roblox = require("@lune/roblox")

local Mocks = {}

local signals = setmetatable({}, { __mode = "k" })

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		local connection = { connected = true }
		function connection.Disconnect()
			connection.connected = false
		end
		table.insert(self.handlers, { fn = fn, connection = connection })
		return connection
	end
	function signal:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.connection.connected then
				h.fn(...)
			end
		end
	end
	function signal:Wait()
		error("Wait stöds inte i mocken")
	end
	return signal
end
Mocks.newSignal = newSignal

local function eventProperty(className: string, name: string)
	roblox.implementProperty(className, name, function(instance)
		signals[instance] = signals[instance] or {}
		local signal = signals[instance][name]
		if not signal then
			signal = newSignal()
			signals[instance][name] = signal
		end
		return signal
	end)
end

function Mocks.install(game, options)
	local state = {
		time = 1000,
		fired = {}, -- { remote, player, payload }
		firedAll = {},
		store = {},
		analytics = 0,
		invokers = {},
	}
	Mocks.state = state

	for _, spec in
		{
			{ "Players", "PlayerAdded" },
			{ "Players", "PlayerRemoving" },
			{ "RemoteEvent", "OnServerEvent" },
			{ "ProximityPromptService", "PromptTriggered" },
			{ "RunService", "Heartbeat" },
			{ "Humanoid", "Died" },
			{ "Humanoid", "MoveToFinished" },
			{ "Humanoid", "Running" },
		}
	do
		eventProperty(spec[1], spec[2])
	end

	roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(instance)
		return state.invokers[instance]
	end, function(instance, value)
		state.invokers[instance] = value
	end)
	roblox.implementProperty("DataModel", "JobId", function()
		return "test-job"
	end)
	roblox.implementProperty("DataModel", "CreatorId", function()
		return 0
	end)

	-- WaitForChild: i testet finns allt redan, så den returnerar direkt (eller fel om det saknas).
	for _, className in
		{
			"Instance",
			"Folder",
			"Model",
			"ReplicatedStorage",
			"Workspace",
			"Player",
			"Part",
			"Humanoid",
			"ServerScriptService",
		}
	do
		roblox.implementMethod(className, "WaitForChild", function(self, name)
			local child = self:FindFirstChild(name)
			if not child then
				error("WaitForChild: " .. self:GetFullName() .. " saknar " .. tostring(name))
			end
			return child
		end)
	end
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return state.time
	end)
	roblox.implementMethod("RunService", "IsStudio", function()
		return options.studio
	end)
	roblox.implementMethod("RunService", "IsServer", function()
		return true
	end)
	roblox.implementMethod("DataModel", "BindToClose", function() end)

	local Players = game:GetService("Players")
	roblox.implementMethod("Players", "GetPlayers", function(self)
		return self:GetChildren()
	end)
	roblox.implementMethod("Players", "GetPlayerByUserId", function(self, userId)
		for _, p in self:GetChildren() do
			if p.UserId == userId then
				return p
			end
		end
		return nil
	end)
	roblox.implementMethod("Players", "GetPlayerFromCharacter", function(self, character)
		for _, p in self:GetChildren() do
			if p.Character == character then
				return p
			end
		end
		return nil
	end)
	roblox.implementMethod("Players", "CreateHumanoidModelFromDescriptionAsync", function()
		error("avatarer kan inte laddas i testet") -- tvingar fram reservfiguren
	end)

	local function makeCharacter(player)
		local character = roblox.Instance.new("Model")
		character.Name = player.Name
		local root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = roblox.Vector3.new(2, 2, 1)
		root.Parent = character
		local torso = roblox.Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Size = roblox.Vector3.new(2, 1.6, 1)
		torso.Parent = character
		local head = roblox.Instance.new("Part")
		head.Name = "Head"
		head.Size = roblox.Vector3.new(1.2, 1.2, 1.2)
		head.Parent = character
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Parent = character
		character.PrimaryPart = root
		return character
	end
	Mocks.makeCharacter = makeCharacter

	roblox.implementMethod("Player", "LoadCharacterAsync", function(player)
		local old = player.Character
		if old then
			old:Destroy()
		end
		local character = makeCharacter(player)
		character.Parent = game:GetService("Workspace")
		player.Character = character
	end)
	roblox.implementMethod("Player", "RequestStreamAroundAsync", function() end)

	roblox.implementMethod("Model", "PivotTo", function(model, cframe)
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if root then
			local delta = cframe * root.CFrame:Inverse()
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = delta * d.CFrame
				end
			end
		end
	end)
	roblox.implementMethod("Model", "GetPivot", function(model)
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		return if root then root.CFrame else roblox.CFrame.new()
	end)
	roblox.implementMethod("Humanoid", "MoveTo", function() end)
	roblox.implementMethod("Humanoid", "TakeDamage", function(humanoid, amount)
		humanoid.Health = math.max(0, humanoid.Health - amount)
		if humanoid.Health <= 0 then
			humanoid.Died:Fire()
		end
	end)
	roblox.implementMethod("Animator", "LoadAnimation", function()
		local track = { IsPlaying = false, Looped = false }
		function track:Play()
			self.IsPlaying = true
		end
		function track:Stop()
			self.IsPlaying = false
		end
		return track
	end)
	roblox.implementMethod("BasePart", "SetNetworkOwner", function() end)
	for _, className in { "Part", "TrussPart" } do
		roblox.implementMethod(className, "SetNetworkOwner", function() end)
	end

	roblox.implementMethod("RemoteEvent", "FireClient", function(remote, player, payload)
		table.insert(state.fired, { remote = remote.Name, player = player, payload = payload })
	end)
	roblox.implementMethod("RemoteEvent", "FireAllClients", function(remote, payload)
		table.insert(state.firedAll, { remote = remote.Name, payload = payload })
	end)

	local store = {}
	function store:UpdateAsync(key, fn)
		local result = fn(state.store[key])
		if result ~= nil then
			state.store[key] = result
		end
		return result
	end
	function store:GetAsync(key)
		return state.store[key]
	end
	roblox.implementMethod("DataStoreService", "GetDataStore", function()
		return store
	end)
	for _, method in { "LogCustomEvent", "LogOnboardingFunnelStepEvent", "LogEconomyEvent", "LogFunnelStepEvent" } do
		roblox.implementMethod("AnalyticsService", method, function()
			state.analytics += 1
		end)
	end
	return state
end

-- Hjälp för testet: lägg till en spelare och vänta tills den laddats.
function Mocks.addPlayer(game, name: string, userId: number)
	local Players = game:GetService("Players")
	local player = roblox.Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end

function Mocks.removePlayer(game, player)
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

-- Flyttar spelarens karaktär (som att gå dit).
function Mocks.teleport(player, position)
	local character = player.Character
	if character then
		character:PivotTo(roblox.CFrame.new(position))
	end
end

-- Senaste payloaden som skickats till en spelare på en viss remote.
function Mocks.last(remoteName: string, player)
	for i = #Mocks.state.fired, 1, -1 do
		local entry = Mocks.state.fired[i]
		if entry.remote == remoteName and entry.player == player then
			return entry.payload
		end
	end
	return nil
end

function Mocks.all(remoteName: string, player)
	local list = {}
	for _, entry in Mocks.state.fired do
		if entry.remote == remoteName and (player == nil or entry.player == player) then
			table.insert(list, entry.payload)
		end
	end
	return list
end

return Mocks
