-- Hud: visar nivå, framsteg och mynt högst upp på skärmen, meddelanden från servern
-- och en "Play again"-knapp när man har gått i mål.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local RestartCourse = Remotes:WaitForChild("RestartCourse") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local TOAST_COLORS = {
	checkpoint = Color3.fromRGB(120, 230, 140),
	finish = Color3.fromRGB(255, 210, 60),
	info = Color3.fromRGB(255, 255, 255),
}

local function corner(parent: GuiObject, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

-- Bygg gränssnittet ----------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHud"
gui.ResetOnSpawn = false

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 8)
panel.Size = UDim2.fromOffset(300, 64)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.25
panel.Parent = gui
corner(panel, 12)

local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "Stage"
stageLabel.Position = UDim2.fromOffset(14, 6)
stageLabel.Size = UDim2.new(0.6, -14, 0, 30)
stageLabel.BackgroundTransparency = 1
stageLabel.Font = FONT
stageLabel.TextSize = 26
stageLabel.TextColor3 = Color3.new(1, 1, 1)
stageLabel.TextXAlignment = Enum.TextXAlignment.Left
stageLabel.Text = "Loading..."
stageLabel.Parent = panel

local coinLabel = Instance.new("TextLabel")
coinLabel.Name = "Coins"
coinLabel.AnchorPoint = Vector2.new(1, 0)
coinLabel.Position = UDim2.new(1, -14, 0, 6)
coinLabel.Size = UDim2.new(0.4, -14, 0, 30)
coinLabel.BackgroundTransparency = 1
coinLabel.Font = FONT
coinLabel.TextSize = 26
coinLabel.TextColor3 = Config.Course.Colors.Coin
coinLabel.TextXAlignment = Enum.TextXAlignment.Right
coinLabel.Text = ""
coinLabel.Parent = panel

local coinScale = Instance.new("UIScale")
coinScale.Parent = coinLabel

local progressBack = Instance.new("Frame")
progressBack.Name = "Progress"
progressBack.Position = UDim2.fromOffset(14, 42)
progressBack.Size = UDim2.new(1, -28, 0, 12)
progressBack.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
progressBack.Parent = panel
corner(progressBack, 6)

local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Config.Course.Colors.Start
progressFill.Parent = progressBack
corner(progressFill, 6)

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.fromScale(0.5, 0.25)
toast.Size = UDim2.fromOffset(600, 50)
toast.BackgroundTransparency = 1
toast.Font = FONT
toast.TextSize = 36
toast.TextStrokeTransparency = 1
toast.TextTransparency = 1
toast.TextStrokeColor3 = Color3.new(0, 0, 0)
toast.Parent = gui

local restartButton = Instance.new("TextButton")
restartButton.Name = "Restart"
restartButton.AnchorPoint = Vector2.new(0.5, 1)
restartButton.Position = UDim2.new(0.5, 0, 1, -40)
restartButton.Size = UDim2.fromOffset(240, 56)
restartButton.BackgroundColor3 = Config.Course.Colors.Finish
restartButton.Font = FONT
restartButton.TextSize = 28
restartButton.TextColor3 = Color3.fromRGB(40, 30, 0)
restartButton.Text = "Play again"
restartButton.Visible = false
restartButton.Parent = gui
corner(restartButton, 12)

gui.Parent = playerGui

-- Meddelanden ----------------------------------------------------------------

local toastId = 0

local function showToast(kind: string, text: string)
	toastId += 1
	local myId = toastId

	toast.Text = text
	toast.TextColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4

	task.delay(2.5, function()
		if toastId == myId then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

Notify.OnClientEvent:Connect(showToast)

restartButton.Activated:Connect(function()
	restartButton.Visible = false
	RestartCourse:FireServer()
end)

-- Koppla till spelarens leaderstats -------------------------------------------

local leaderstats = player:WaitForChild("leaderstats")
local stageValue = leaderstats:WaitForChild(Config.Stats.Stage) :: IntValue
local coinsValue = leaderstats:WaitForChild(Config.Stats.Coins) :: IntValue

local function refreshStage()
	local stage = stageValue.Value
	local finalStage = ReplicatedStorage:GetAttribute("FinalStage")
	if type(finalStage) ~= "number" or finalStage < 1 then
		stageLabel.Text = `{Config.Stats.Stage} {stage}`
		restartButton.Visible = false
		return
	end
	stageLabel.Text = `{Config.Stats.Stage} {stage} / {finalStage}`

	local progress = if finalStage > 1 then (stage - 1) / (finalStage - 1) else 1
	TweenService:Create(progressFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1),
	}):Play()

	restartButton.Visible = stage >= finalStage
end

local function refreshCoins()
	coinLabel.Text = `{Config.Stats.Coins}: {coinsValue.Value}`
	coinScale.Scale = 1.3
	TweenService:Create(coinScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

stageValue.Changed:Connect(refreshStage)
ReplicatedStorage:GetAttributeChangedSignal("FinalStage"):Connect(refreshStage)
coinsValue.Changed:Connect(refreshCoins)
refreshStage()
refreshCoins()
