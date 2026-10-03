-- MarkerController: diskreta markörer i världen.
--   * En liten romb över målet för ens kontrakt (avståndet syns i HUD:en).
--   * Pingar från laget och "mjuka mål" från kontraktsvändningar.
--   * Lagkamrater får en svag kontur så man hittar varandra i mörkret.
--   * Skannern (licensen ScannerPing) visar föremål i närheten en kort stund.
-- Inget här gör spelet åt spelaren: markörer är små, och skannern har lång väntetid.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)

local MarkerController = {}

local C = Theme.Colors
local SCANNER_RANGE = 70
local SCANNER_SECONDS = 5
local SCANNER_COOLDOWN = 25
local PING_SECONDS = 8

local app
local folder: Folder
local contractMarker: BasePart
local contractGui: BillboardGui
local highlights: { [Player]: Highlight } = {}
local squadIds: { [number]: boolean } = {}
local lastScan = -math.huge

-- Nivån som ger licensen ScannerPing.
local SCANNER_LEVEL = 99
for _, entry in ProgressionConfig.Levels do
	if table.find(entry.unlocks, "ScannerPing") then
		SCANNER_LEVEL = entry.level
	end
end

local function anchorAt(name: string, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	return part
end

local function billboard(adornee: BasePart, symbol: string, color: Color3, caption: string?): BillboardGui
	local gui = Ui.new("BillboardGui", {
		Name = "Marker",
		Adornee = adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(140, 46),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		MaxDistance = 2000,
		ResetOnSpawn = false,
		Parent = adornee,
	})
	Ui.new("TextLabel", {
		Name = "Symbol",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.Fonts.Display,
		Text = symbol,
		TextSize = 22,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
		Parent = gui,
	})
	if caption then
		Ui.new("TextLabel", {
			Name = "Caption",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 18),
			Font = Theme.Fonts.Bold,
			Text = caption,
			TextSize = 13,
			TextColor3 = color,
			TextStrokeTransparency = 0.5,
			Parent = gui,
		})
	end
	return gui
end

-- Kontraktsmålet -----------------------------------------------------------------------------

local function updateContract(contract)
	local position = contract and contract.active and contract.targetPosition
	if typeof(position) ~= "Vector3" then
		contractGui.Enabled = false
		return
	end
	contractMarker.CFrame = CFrame.new(position)
	contractGui.Enabled = true
end

-- Pingar och mjuka mål -------------------------------------------------------------------------

function MarkerController.mark(position: Vector3, text: string, color: Color3?, seconds: number?)
	local part = anchorAt("Ping", position)
	local gui = billboard(part, "◇", color or C.Warning, text)
	task.delay(seconds or PING_SECONDS, function()
		gui.Enabled = false
		part:Destroy()
	end)
end

-- Pinga där kameran tittar (delas med laget).
function MarkerController.pingAtCrosshair()
	local camera = Workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: Instance, folder }
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 180, params)
	if not result then
		return
	end
	MarkerController.mark(result.Position, "PING", C.Dispatch)
	app.remotes.SquadRequest:FireServer("ping", result.Position)
end

-- Laget ---------------------------------------------------------------------------------------

local function refreshHighlights()
	for player, highlight in highlights do
		if not squadIds[player.UserId] or player.Parent == nil or highlight.Adornee ~= player.Character then
			highlight:Destroy()
			highlights[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		if
			player ~= Players.LocalPlayer
			and squadIds[player.UserId]
			and player.Character
			and not highlights[player]
		then
			highlights[player] = Ui.new("Highlight", {
				Name = "SquadOutline",
				Adornee = player.Character,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				FillTransparency = 1,
				OutlineColor = C.Dispatch,
				OutlineTransparency = 0.45,
				Parent = folder,
			})
		end
	end
end

-- Skannern ------------------------------------------------------------------------------------

function MarkerController.scan(): boolean
	local profile = app.state.get("profile")
	if not profile or profile.level < SCANNER_LEVEL then
		app.notify("info", "SCANNER", "The scanner unlocks at level " .. SCANNER_LEVEL .. ".", 3)
		return false
	end
	local now = os.clock()
	if now - lastScan < SCANNER_COOLDOWN then
		app.notify("info", "SCANNER", "Recharging: " .. math.ceil(SCANNER_COOLDOWN - (now - lastScan)) .. "s", 2)
		return false
	end
	lastScan = now
	local root = app.rootPosition()
	if not root then
		return false
	end
	local found = 0
	for _, drop in CollectionService:GetTagged(Constants.Tags.LootDrop) do
		if drop:IsA("BasePart") and (drop.CFrame.Position - root).Magnitude <= SCANNER_RANGE then
			local rarity = ItemConfig.Rarities[drop:GetAttribute("Rarity") or "Common"]
			local gui = billboard(drop, "•", rarity and rarity.color or C.Text, nil)
			gui.Size = UDim2.fromOffset(40, 30)
			task.delay(SCANNER_SECONDS, function()
				gui:Destroy()
			end)
			found += 1
		end
	end
	app.notify("info", "SCANNER", if found > 0 then found .. " signals nearby." else "Nothing nearby.", 3)
	return true
end

function MarkerController.start(appRef)
	app = appRef
	app.markers = MarkerController
	folder = Instance.new("Folder")
	folder.Name = "AfterhoursMarkers"
	folder.Parent = Workspace

	contractMarker = anchorAt("ContractTarget", Vector3.zero)
	contractGui = billboard(contractMarker, "◆", C.Dispatch, nil)
	contractGui.Enabled = false
	app.state.watch("contract", updateContract)

	app.state.watch("squad", function(squad)
		squadIds = {}
		for _, member in squad and squad.members or {} do
			squadIds[member.userId] = true
		end
		refreshHighlights()
	end)
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(refreshHighlights)
		end)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshHighlights)
	end)

	app.worldEvents:Connect(function(event)
		if event.type == "Ping" and typeof(event.position) == "Vector3" then
			MarkerController.mark(event.position, tostring(event.from or "PING"), C.Dispatch)
		elseif event.type == "SoftObjective" and typeof(event.position) == "Vector3" then
			MarkerController.mark(event.position, tostring(event.text or ""), C.Warning, 40)
		elseif event.type == "TwistChoice" and typeof(event.position) == "Vector3" then
			MarkerController.mark(event.position, "?", C.Warning, 20)
		end
	end)

	-- Kontraktsromben bleknar när man är framme.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local root = app.rootPosition()
			if contractGui.Enabled and root then
				local distance = (contractMarker.CFrame.Position - root).Magnitude
				local symbol = contractGui:FindFirstChild("Symbol") :: TextLabel?
				if symbol then
					symbol.TextTransparency = if distance < 14 then 0.75 else 0.1
				end
			end
		end
	end)
end

return MarkerController
