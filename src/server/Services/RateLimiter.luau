--!strict
--[[
	SHOOTBLOX — Rate Limiter
	Blueprint §5.1.2 check 3 (time since the last ACCEPTED shot ≥ interval ×
	0.9), made jitter-proof with two clocks:
	  • spacing is measured on the shooter's timestamps (already bounded by the
	    timestamp-window check), so packets bunched by the network still pass;
	  • a server-clock token bucket caps the sustained rate, so forged
	    timestamps can't exceed the weapon's fire rate.
	Check and record are separate so a shot rejected later in the pipeline
	doesn't burn the slot. Also a generic token bucket for non-shot spam.
]]

local Players = game:GetService("Players")

local RateLimiter = {}

local FIRE_INTERVAL_TOLERANCE = 0.9
local BURST_SHOTS = 3 -- shots a jittery connection may deliver back-to-back

type ShotState = { LastClientTime: number, Tokens: number, LastRefill: number }

-- [player][weaponId]
local ShotStates: { [Player]: { [string]: ShotState } } = {}

-- Generic token buckets: [player][eventType]
local Buckets: { [Player]: { [string]: { tokens: number, lastRefill: number } } } = {}
local MAX_TOKENS = 5
local REFILL_RATE = 10 -- tokens per second

function RateLimiter.SetDependencies(_deps) end

function RateLimiter.Init()
	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.CleanupPlayer(player)
	end)
	print("[RateLimiter] Initialized")
end

local function refilled(state: ShotState, fireRate: number, now: number): number
	return math.min(BURST_SHOTS, state.Tokens + (now - state.LastRefill) * fireRate)
end

-- May this shot fire? fireRate is rounds per second; clientTime is the
-- shot's server-clock timestamp as stamped by the shooter.
function RateLimiter.CheckShot(player: Player, weaponId: string, fireRate: number, clientTime: number): boolean
	local shots = ShotStates[player]
	local state = shots and shots[weaponId]
	if not state then
		return true
	end
	if clientTime - state.LastClientTime < (1 / fireRate) * FIRE_INTERVAL_TOLERANCE then
		return false
	end
	return refilled(state, fireRate, workspace:GetServerTimeNow()) >= 1
end

-- Call once a shot is fully accepted (hit or miss)
function RateLimiter.RecordShot(player: Player, weaponId: string, fireRate: number, clientTime: number)
	local now = workspace:GetServerTimeNow()
	local shots = ShotStates[player]
	if not shots then
		shots = {}
		ShotStates[player] = shots
	end
	local state = shots[weaponId]
	if not state then
		state = { LastClientTime = clientTime, Tokens = BURST_SHOTS, LastRefill = now }
		shots[weaponId] = state
	end
	state.Tokens = refilled(state, fireRate, now) - 1
	state.LastRefill = now
	state.LastClientTime = clientTime
end

-- Generic token check for any event type
function RateLimiter.Check(player: Player, eventType: string, cost: number): boolean
	local now = workspace:GetServerTimeNow()
	local playerBuckets = Buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		Buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[eventType]
	if not bucket then
		bucket = { tokens = MAX_TOKENS, lastRefill = now }
		playerBuckets[eventType] = bucket
	end

	bucket.tokens = math.min(MAX_TOKENS, bucket.tokens + (now - bucket.lastRefill) * REFILL_RATE)
	bucket.lastRefill = now
	if bucket.tokens >= cost then
		bucket.tokens -= cost
		return true
	end
	return false
end

function RateLimiter.CleanupPlayer(player: Player)
	ShotStates[player] = nil
	Buckets[player] = nil
end

return RateLimiter
