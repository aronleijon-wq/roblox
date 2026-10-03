-- SecretCode: veckans kod till Maintenance B-7.
--
-- Pusslet: affischer runt om i staden visar vilken siffra varje symbol betyder (alltid samma).
-- Väggen nere på den stängda stationen visar veckans symbolföljd. Den som pusslar ihop dem
-- får fram koden. Koden byts varje måndag 00:00 UTC, samma på alla servrar, så att spelare
-- kan lösa den tillsammans. Ligger bara på servern så att den inte kan läsas från klienten.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rng = require(ReplicatedStorage.Shared.Util.Rng)

local SecretCode = {}

local WEEK = 604800
local FIRST_MONDAY = 345600 -- 1970-01-05 00:00 UTC

function SecretCode.weekIndex(unixTime: number): number
	return math.floor((unixTime - FIRST_MONDAY) / WEEK)
end

-- Fyrsiffrig kod för en vecka. salt gör att koden inte går att räkna ut utan serverns config.
function SecretCode.codeForWeek(week: number, salt: number, length: number): string
	local rng = Rng.new(week * 7919 + salt)
	local digits = {}
	for _ = 1, length do
		table.insert(digits, tostring(rng:integer(0, 9)))
	end
	return table.concat(digits)
end

-- Översätter koden till symboler med mappningen symbol -> siffra.
function SecretCode.symbolsFor(code: string, symbolForDigit: { [string]: string }): { string }
	local symbols = {}
	for i = 1, #code do
		table.insert(symbols, symbolForDigit[code:sub(i, i)])
	end
	return symbols
end

return SecretCode
