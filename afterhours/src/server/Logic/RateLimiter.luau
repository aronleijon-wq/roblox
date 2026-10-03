-- RateLimiter: token bucket per spelare och typ av begäran. Ren logik, testbar.
-- Varje typ har en takt (tokens per sekund) och en burst (hur många som får skickas direkt).

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(limits: { [string]: { rate: number, burst: number } })
	return setmetatable({ limits = limits, buckets = {} }, RateLimiter)
end

function RateLimiter:allow(scope: any, key: string, now: number): boolean
	local limit = self.limits[key] or self.limits.Default
	local scopeBuckets = self.buckets[scope]
	if not scopeBuckets then
		scopeBuckets = {}
		self.buckets[scope] = scopeBuckets
	end

	local bucket = scopeBuckets[key]
	if not bucket then
		bucket = { tokens = limit.burst, updatedAt = now }
		scopeBuckets[key] = bucket
	end

	bucket.tokens = math.min(limit.burst, bucket.tokens + (now - bucket.updatedAt) * limit.rate)
	bucket.updatedAt = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:forget(scope: any)
	self.buckets[scope] = nil
end

return RateLimiter
