-- ShiftClock: räknar om verklig servertid till spelklockan (00:00 -> 03:00).
-- Används av både servern och klienten, så att alla ser exakt samma klocka.

local ShiftClock = {}

-- Klocktimmar vid tidpunkten `now`, givet när natten började och slutar (servertid).
function ShiftClock.clock(startClock: number, endClock: number, startedAt: number, endsAt: number, now: number): number
	local length = math.max(endsAt - startedAt, 1e-3)
	local fraction = math.clamp((now - startedAt) / length, 0, 1)
	return startClock + (endClock - startClock) * fraction
end

-- Servertiden då klockan visar `clock`.
function ShiftClock.timeAt(
	startClock: number,
	endClock: number,
	startedAt: number,
	endsAt: number,
	clock: number
): number
	local fraction = (clock - startClock) / (endClock - startClock)
	return startedAt + (endsAt - startedAt) * fraction
end

return ShiftClock
