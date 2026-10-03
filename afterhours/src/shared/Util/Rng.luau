-- Rng: deterministisk slumpgenerator (Park–Miller, "minimal standard").
-- Samma seed ger alltid samma följd, både i Roblox och i testerna, så att en
-- incident eller ett kontrakt kan återskapas från seeden i loggen.

local MODULUS = 2147483647
local MULTIPLIER = 48271

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number, seed: number }, Rng))

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MODULUS
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state, seed = seed }, Rng)
end

-- Gör ett heltal av en sträng (t.ex. JobId) så att den kan blandas in i en seed.
function Rng.hashString(text: string): number
	local hash = 5381
	for i = 1, #text do
		hash = (hash * 33 + string.byte(text, i)) % MODULUS
	end
	return hash
end

function Rng:nextRaw(): number
	self.state = (self.state * MULTIPLIER) % MODULUS
	return self.state
end

-- Flyttal i [0, 1) eller [min, max).
function Rng:number(min: number?, max: number?): number
	local unit = (self:nextRaw() - 1) / (MODULUS - 1)
	if min and max then
		return min + unit * (max - min)
	end
	return unit
end

-- Heltal i [min, max] (båda inklusive).
function Rng:integer(min: number, max: number): number
	if max <= min then
		return min
	end
	return math.min(max, min + math.floor(self:number() * (max - min + 1)))
end

function Rng:chance(probability: number): boolean
	return self:number() < probability
end

function Rng:pick<T>(list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[self:integer(1, #list)]
end

-- Väljer ett element med sannolikhet proportionell mot weightOf(element).
-- Element med vikt <= 0 kan aldrig väljas. Returnerar nil om inget kan väljas.
function Rng:weighted<T>(list: { T }, weightOf: (T) -> number): (T?, number?)
	local total = 0
	for _, entry in list do
		local weight = weightOf(entry)
		if weight > 0 then
			total += weight
		end
	end
	if total <= 0 then
		return nil, nil
	end

	local roll = self:number() * total
	local lastValid, lastIndex = nil, nil
	for index, entry in list do
		local weight = weightOf(entry)
		if weight > 0 then
			roll -= weight
			lastValid, lastIndex = entry, index
			if roll < 0 then
				return entry, index
			end
		end
	end
	return lastValid, lastIndex -- avrundningsfel: ta sista giltiga
end

-- Blandar en kopia av listan (Fisher–Yates).
function Rng:shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = self:integer(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

return Rng
