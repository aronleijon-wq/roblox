-- AFTERHOURS: 03:00, klientens startpunkt.
-- Bygger gränssnittets rot (en ScreenGui som skalas efter skärmen) och startar alla
-- controllers i ordning. Controllers pratar med varandra via tabellen `app`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(script.Parent.UI.Theme)
local Ui = require(script.Parent.UI.Ui)

local Controllers = script.Parent.Controllers
local ClientState = require(Controllers.ClientState)

local player = Players.LocalPlayer

-- Roblox egen ryggsäck och spelarlista behövs inte (eget inventarie, laget i DISPATCH).
local function hideCoreGui()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end
task.spawn(hideCoreGui)

-- Rot: allt ritas i "designpixlar" (1280x720) och skalas till skärmen med UIScale.
-- Rotens storlek delas med skalan så att 1.0 i skala fortfarande betyder hela skärmen.
local screen = Ui.new("ScreenGui", {
	Name = "Afterhours",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	Parent = player:WaitForChild("PlayerGui"),
})
local root = Ui.new("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	Parent = screen,
})
local scale = Ui.new("UIScale", { Parent = root })

local function rescale()
	local viewport = screen.AbsoluteSize
	if viewport.X <= 0 then
		viewport = Workspace.CurrentCamera.ViewportSize
	end
	local s = Theme.scaleFor(viewport)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
rescale()

local app = {
	remotes = Remotes.get(),
	state = ClientState,
	root = root,
	screen = screen,
	worldEvents = Signal.new(),
}

function app.rootPosition(): Vector3?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part.CFrame.Position else nil
end

-- Tills NotificationController är igång
function app.notify(_kind: string, _title: string?, text: string)
	print("[Afterhours]", text)
end

-- WorldEvent delas ut till alla controllers som lyssnar.
app.remotes.WorldEvent.OnClientEvent:Connect(function(event)
	if type(event) == "table" and type(event.type) == "string" then
		app.worldEvents:Fire(event)
	end
end)

-- Ordningen spelar roll: HUD:en skapar lagret som andra lägger saker i, ljudet behövs
-- av notiserna, dispatch och inventariet behövs av kontrollerna.
local ORDER = {
	"HudController",
	"AudioController",
	"NotificationController",
	"InventoryController",
	"DispatchController",
	"ResultsController",
	"DialogController",
	"OnboardingController",
	"MarkerController",
	"GateController",
	"PromptController",
	"WorldFxController",
	"InputController",
	"DebugController",
}

for _, name in ORDER do
	app[name] = require(Controllers:FindFirstChild(name))
end
app.hud = app.HudController
for _, name in ORDER do
	local ok, err = pcall(app[name].start, app)
	if not ok then
		warn("[Afterhours] " .. name .. " kunde inte starta:", err)
	end
end

-- Tillståndet börjar strömma in först när alla lyssnar.
ClientState.start(app.remotes)

-- Välkomstskylt
task.delay(1.5, function()
	app.NotificationController.banner(
		"AFTERHOURS",
		"DOWNTOWN NEVER SLEEPS. BE BACK BEFORE 03:00.",
		Theme.Colors.Clock,
		4.5
	)
end)
