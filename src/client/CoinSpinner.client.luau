-- CoinSpinner: får alla mynt att snurra. Körs bara på klienten, så det kostar inget
-- för servern och ser mjukt ut oavsett nätverk.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SPIN_SPEED = math.rad(150) -- grader per sekund

local coins: { [BasePart]: true } = {}

local function onAdded(instance: Instance)
	if instance:IsA("BasePart") then
		coins[instance] = true
	end
end

local function onRemoved(instance: Instance)
	coins[instance :: BasePart] = nil
end

for _, instance in CollectionService:GetTagged(Config.Tags.Coin) do
	onAdded(instance)
end
CollectionService:GetInstanceAddedSignal(Config.Tags.Coin):Connect(onAdded)
CollectionService:GetInstanceRemovedSignal(Config.Tags.Coin):Connect(onRemoved)

RunService.RenderStepped:Connect(function(deltaTime)
	local rotation = CFrame.Angles(0, SPIN_SPEED * deltaTime, 0)
	for coin in coins do
		coin.CFrame *= rotation
	end
end)
