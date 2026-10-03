-- Coins: mynt som spelare kan plocka upp. De försvinner en stund och kommer sedan tillbaka.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Util = require(script.Parent.Util)

local Coins = {}

local function setupCoin(part: BasePart)
	local value = part:GetAttribute("Value") or Config.Coins.Value
	local originalTransparency = part.Transparency
	local available = true

	part.Touched:Connect(function(hit)
		if not available then
			return
		end
		local player = Util.getPlayerFromPart(hit)
		if not player or not PlayerData.isLoaded(player) then
			return
		end

		available = false
		part.Transparency = 1
		PlayerData.addCoins(player, value)

		task.delay(Config.Coins.RespawnTime, function()
			part.Transparency = originalTransparency
			available = true
		end)
	end)
end

function Coins.start()
	Util.bindTag(Config.Tags.Coin, setupCoin)
end

return Coins
