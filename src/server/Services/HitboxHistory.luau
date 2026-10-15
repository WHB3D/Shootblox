--!strict
--[[
	SHOOTBLOX — Hitbox History (60 Hz ring buffer)
	Per-combatant hitbox CFrames for lag-compensated rewind (Hindsight /
	SecureCast pattern). Keyed by character Model, so it covers players AND
	bots, and a respawn naturally starts a fresh history.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local HitboxHistory = {}

local TICK_RATE = 60 -- Hz
local RETENTION = 1.0 -- seconds
local BUFFER_SIZE = math.ceil(TICK_RATE * RETENTION)

local HITBOX_PARTS = {
	R15 = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" },
	R6 = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" },
}

type Entry = { Tick: number, CFrames: { [string]: CFrame } }

-- Ring buffer per model: entries in write order, Head index = next write slot
local History: { [Model]: { Entries: { Entry }, Next: number } } = {}

-- Non-player combatants (bots) registered by BotService
local Tracked: { [Model]: true } = {}

function HitboxHistory.Track(model: Model)
	Tracked[model] = true
end

function HitboxHistory.Untrack(model: Model)
	Tracked[model] = nil
	History[model] = nil
end

local function captureModel(model: Model, now: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local partNames = HITBOX_PARTS[humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"]

	local cframes: { [string]: CFrame } = {}
	for _, name in partNames do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			cframes[name] = part.CFrame
		end
	end

	local ring = History[model]
	if not ring then
		ring = { Entries = {}, Next = 1 }
		History[model] = ring
	end
	ring.Entries[ring.Next] = { Tick = now, CFrames = cframes }
	ring.Next = ring.Next % BUFFER_SIZE + 1
end

function HitboxHistory.Capture()
	local now = workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			captureModel(character, now)
		end
	end
	for model in Tracked do
		if model.Parent then
			captureModel(model, now)
		else
			HitboxHistory.Untrack(model)
		end
	end

	-- Drop histories of characters that no longer exist (respawn, leave)
	for model in History do
		if not model.Parent then
			History[model] = nil
		end
	end
end

-- Hitbox CFrames of `model` closest to time `atTime`, or nil if none recorded.
-- Linear scan over ≤60 entries; the ring isn't sorted by index, so binary
-- search would be wrong after the buffer wraps.
function HitboxHistory.RewindTo(model: Model, atTime: number): { [string]: CFrame }?
	local ring = History[model]
	if not ring then
		return nil
	end
	local best: Entry? = nil
	local bestDiff = math.huge
	for _, entry in ring.Entries do
		local diff = math.abs(entry.Tick - atTime)
		if diff < bestDiff then
			best, bestDiff = entry, diff
		end
	end
	return best and best.CFrames
end

function HitboxHistory.Init()
	RunService.Heartbeat:Connect(HitboxHistory.Capture)
	print("[HitboxHistory] Initialized - 60Hz ring buffer, " .. BUFFER_SIZE .. " entries")
end

return HitboxHistory
