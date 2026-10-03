-- Format: text som visas för spelaren (siffror, klockslag, tider).

local Format = {}

-- 12345 -> "12,345"
function Format.credits(amount: number): string
	local negative = amount < 0
	local digits = tostring(math.floor(math.abs(amount) + 0.5))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (if negative then "-" else "") .. formatted
end

-- Klocktimmar (t.ex. 2.5) -> "02:30"
function Format.clock(hours: number): string
	local totalMinutes = math.floor(math.max(0, hours) * 60 + 1e-6)
	local h = math.floor(totalMinutes / 60) % 24
	local m = totalMinutes % 60
	return string.format("%02d:%02d", h, m)
end

-- Sekunder -> "1:05"
function Format.duration(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- Avstånd i studs -> "120 m" (1 stud ≈ 0.28 m, men "m" läses lättare än "studs").
function Format.distance(studs: number): string
	return string.format("%d m", math.floor(studs * 0.28 + 0.5))
end

return Format
