--!strict
--[[
	SHOOTBLOX — Rate Limiter (Token Bucket)
	Per-player, per-event-type spam protection.
	Pattern: Blueprint §5.1.1 RateLimiter module.
]]

local Players = game:GetService("Players")

local RateLimiter = {}

-- Token buckets: [player][eventType] = { tokens: number, lastRefill: number }
local Buckets: { [Player]: { [string]: { tokens: number, lastRefill: number } } } = {}

-- Configuration
local MAX_TOKENS = 5 -- burst capacity
local REFILL_RATE = 10 -- tokens per second

function RateLimiter.SetDependencies(deps)
	-- No dependencies needed
end

function RateLimiter.Init()
	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.CleanupPlayer(player)
	end)
	print("[RateLimiter] Initialized")
end

-- Check if a shot is allowed (fire rate validation)
function RateLimiter.AcceptShot(player: Player, fireInterval: number): boolean
	local now = workspace:GetServerTimeNow()
	local bucket = RateLimiter.GetBucket(player, "Fire")

	-- Refill tokens based on time elapsed
	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(MAX_TOKENS, bucket.tokens + elapsed * REFILL_RATE)
	bucket.lastRefill = now

	-- Check if enough tokens for this shot
	local cost = 1 / fireInterval -- tokens per shot
	if bucket.tokens >= cost then
		bucket.tokens -= cost
		return true
	end

	return false
end

-- Generic token check for any event type
function RateLimiter.Check(player: Player, eventType: string, cost: number): boolean
	local now = workspace:GetServerTimeNow()
	local bucket = RateLimiter.GetBucket(player, eventType)

	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(MAX_TOKENS, bucket.tokens + elapsed * REFILL_RATE)
	bucket.lastRefill = now

	if bucket.tokens >= cost then
		bucket.tokens -= cost
		return true
	end

	return false
end

-- Get or create a bucket for a player/event
function RateLimiter.GetBucket(player: Player, eventType: string)
	local playerBuckets = Buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		Buckets[player] = playerBuckets
	end

	local bucket = playerBuckets[eventType]
	if not bucket then
		bucket = { tokens = MAX_TOKENS, lastRefill = workspace:GetServerTimeNow() }
		playerBuckets[eventType] = bucket
	end

	return bucket
end

-- Manual token deduction (for anti-cheat strikes)
function RateLimiter.Consume(player: Player, eventType: string, amount: number)
	local bucket = RateLimiter.GetBucket(player, eventType)
	bucket.tokens = math.max(0, bucket.tokens - amount)
end

function RateLimiter.CleanupPlayer(player: Player)
	Buckets[player] = nil
end

return RateLimiter