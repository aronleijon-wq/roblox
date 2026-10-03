-- Fejkade klienttjänster för klienttestet (tests/client.spec.luau). Bygger på tests/mocks.luau:
-- händelser (Activated, OnClientEvent ...), tangentbord/handkontroll, tweens, taggar och en
-- LocalPlayer. Allt som ritas på skärmen skapas som riktiga instanser, så testet kan leta
-- upp knappar och texter och "klicka" på dem.

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Mocks = require("./mocks")

local ClientMocks = {}

local signalsFor = setmetatable({}, { __mode = "k" })

-- En signal per instans och nyckel (t.ex. "attr:PowerOut" eller "prop:ViewportSize").
local function keyed(instance, key: string)
	signalsFor[instance] = signalsFor[instance] or {}
	local signal = signalsFor[instance][key]
	if not signal then
		signal = Mocks.newSignal()
		signalsFor[instance][key] = signal
	end
	return signal
end
ClientMocks.keyed = keyed

-- Sätter ett attribut och avfyrar GetAttributeChangedSignal (Lune har inga riktiga händelser).
function ClientMocks.setAttribute(instance, name: string, value)
	instance:SetAttribute(name, value)
	keyed(instance, "attr:" .. name):Fire()
end

function ClientMocks.install(game, player)
	local state = {
		toServer = {}, -- { remote, args }
		actions = {}, -- ContextActionService
		renderSteps = {},
		taskErrors = {},
		tweens = 0,
		invites = 0,
	}
	ClientMocks.state = state

	for _, spec in
		{
			{ "RemoteEvent", "OnClientEvent" },
			{ "GuiButton", "Activated" },
			{ "Instance", "Changed" },
			{ "Instance", "ChildAdded" },
			{ "Instance", "DescendantAdded" },
			{ "Sound", "Ended" },
			{ "Player", "CharacterAdded" },
			{ "UserInputService", "InputBegan" },
			{ "UserInputService", "LastInputTypeChanged" },
		}
	do
		Mocks.eventProperty(spec[1], spec[2])
	end

	roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
		return keyed(self, "attr:" .. name)
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, name)
		return keyed(self, "prop:" .. name)
	end)

	-- Taggar
	roblox.implementMethod("CollectionService", "GetTagged", function(_, tag)
		local list = {}
		for _, descendant in game:GetDescendants() do
			if descendant:HasTag(tag) then
				table.insert(list, descendant)
			end
		end
		return list
	end)
	roblox.implementMethod("CollectionService", "GetInstanceAddedSignal", function(self, tag)
		return keyed(self, "added:" .. tag)
	end)
	roblox.implementMethod("CollectionService", "GetInstanceRemovedSignal", function(self, tag)
		return keyed(self, "removed:" .. tag)
	end)

	-- Inmatning
	roblox.implementMethod("UserInputService", "GetLastInputType", function()
		return roblox.Enum.UserInputType.MouseMovement
	end)
	roblox.implementMethod("UserInputService", "GetFocusedTextBox", function()
		return nil
	end)
	roblox.implementMethod("ContextActionService", "BindAction", function(_, name, fn, _createButton, ...)
		state.actions[name] = { fn = fn, inputs = { ... } }
	end)
	roblox.implementMethod("RunService", "BindToRenderStep", function(_, name, _priority, fn)
		state.renderSteps[name] = fn
	end)
	roblox.implementMethod("StarterGui", "SetCoreGuiEnabled", function() end)
	roblox.implementMethod("Camera", "ViewportPointToRay", function(camera)
		return { Origin = camera.CFrame.Position, Direction = camera.CFrame.LookVector }
	end)
	roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction)
		return { Position = origin + direction * 0.5, Instance = nil, Normal = roblox.Vector3.yAxis }
	end)
	roblox.implementMethod("SocialService", "PromptGameInvite", function()
		state.invites += 1
	end)
	roblox.implementMethod("GuiService", "GetGuiInset", function()
		return roblox.Vector2.zero, roblox.Vector2.zero
	end)

	-- Ljud och tweens gör inget i testet (tweens hoppar direkt till målet).
	roblox.implementMethod("Sound", "Play", function() end)
	roblox.implementMethod("Sound", "Stop", function() end)
	roblox.implementMethod("TweenService", "Create", function(_, instance, _info, goals)
		state.tweens += 1
		local tween = { Completed = Mocks.newSignal() }
		function tween:Play()
			for key, value in goals do
				instance[key] = value
			end
			task.defer(function()
				tween.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function tween:Cancel() end
		return tween
	end)

	-- Klient -> server
	roblox.implementMethod("RemoteEvent", "FireServer", function(remote, ...)
		table.insert(state.toServer, { remote = remote.Name, args = { ... } })
	end)
	roblox.implementMethod("RemoteFunction", "InvokeServer", function(remote)
		table.insert(state.toServer, { remote = remote.Name, args = {} })
		return state.snapshot
	end)

	-- Spelaren, kameran och skärmen
	local Players = game:GetService("Players")
	Players.LocalPlayer = player
	local playerGui = roblox.Instance.new("PlayerGui")
	playerGui.Parent = player
	local camera = roblox.Instance.new("Camera")
	camera.ViewportSize = roblox.Vector2.new(1280, 720)
	camera.Parent = game:GetService("Workspace")
	game:GetService("Workspace").CurrentCamera = camera
	local uis = game:GetService("UserInputService")
	uis.TouchEnabled = false
	return state
end

-- Instance.new som ger GUI-objekt de storlekar Lune saknar standardvärden för.
function ClientMocks.instanceLibrary()
	local wrapped = table.clone(roblox.Instance)
	function wrapped.new(className: string, ...)
		local instance = roblox.Instance.new(className, ...)
		if instance:IsA("GuiBase2d") then
			instance.AbsoluteSize = if instance:IsA("ScreenGui")
				then roblox.Vector2.new(1280, 720)
				else roblox.Vector2.new(100, 40)
			instance.AbsolutePosition = roblox.Vector2.zero
		elseif instance:IsA("Humanoid") then
			instance.MoveDirection = roblox.Vector3.zero
		elseif instance:IsA("Camera") then
			instance.ViewportSize = roblox.Vector2.new(1280, 720)
		end
		return instance
	end
	return wrapped
end

-- task som fångar fel i trådar (annars skrivs de bara ut och testet märker inget).
function ClientMocks.taskLibrary(errors)
	local function guard(fn)
		if type(fn) ~= "function" then
			return fn
		end
		return function(...)
			local ok, err = xpcall(fn, function(message)
				return tostring(message) .. "\n" .. debug.traceback()
			end, ...)
			if not ok then
				table.insert(errors, tostring(err))
			end
		end
	end
	local wrapped = table.clone(task)
	function wrapped.spawn(fn, ...)
		return task.spawn(guard(fn), ...)
	end
	function wrapped.defer(fn, ...)
		return task.defer(guard(fn), ...)
	end
	function wrapped.delay(seconds, fn, ...)
		return task.delay(seconds, guard(fn), ...)
	end
	return wrapped
end

-- Datatyper som Lune saknar.
ClientMocks.TweenInfo = {
	new = function(time, style, direction, repeats, reverses, delay)
		return {
			Time = time or 1,
			EasingStyle = style,
			EasingDirection = direction,
			RepeatCount = repeats or 0,
			Reverses = reverses or false,
			DelayTime = delay or 0,
		}
	end,
}
ClientMocks.RaycastParams = {
	new = function()
		return { FilterType = nil, FilterDescendantsInstances = {} }
	end,
}

-- Alla knappar under en GUI-rot vars text matchar (exakt eller mönster).
function ClientMocks.buttons(root, pattern: string?)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and (pattern == nil or d.Text:match(pattern)) then
			table.insert(list, d)
		end
	end
	return list
end

function ClientMocks.click(button)
	button.Activated:Fire()
end

-- Text i alla synliga TextLabels under en rot (för att kontrollera vad som visas).
function ClientMocks.texts(root): string
	local parts = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(parts, d.Text)
		end
	end
	return table.concat(parts, " | ")
end

return ClientMocks
