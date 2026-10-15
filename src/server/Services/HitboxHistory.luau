--!strict
--[[
	SHOOTBLOX — Hitbox History (60Hz Ring Buffer)
	Stores per-character hitbox CFrames for lag-compensated rewind.
	Pattern: Hindsight Rollback + SecureCast Snapshots.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local HitboxHistory = {}

-- Configuration
local TICK_RATE = 60 -- Hz
local RETENTION = 1.0 -- seconds
local BUFFER_SIZE = math.ceil(TICK_RATE * RETENTION) -- 60 entries

-- Ring buffer: per-player array of { Tick: number, CFrames: { [string]: CFrame } }
local History: { [Player]: { { Tick: number, CFrames: { [string]: CFrame } } } } = {}
local WriteIndex: { [Player]: number } = {}

-- Hitbox part names per rig (R15 default)
local HITBOX_PARTS = {
	R15 = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLeg", "RightLeg" },
	R6 = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" },
}

-- Snapshot all players' hitboxes into the ring buffer
function HitboxHistory.Capture()
	local tick = workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			continue
		end

		-- Determine rig type
		local rigType = humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
		local partNames = HITBOX_PARTS[rigType]

		-- Capture CFrames
		local cframes = {}
		for _, partName in partNames do
			local part = character:FindFirstChild(partName)
			if part then
				cframes[partName] = part.CFrame
			end
		end

		-- Write to ring buffer
		local buffer = History[player]
		if not buffer then
			buffer = {}
			History[player] = buffer
			WriteIndex[player] = 1
		end

		local idx = WriteIndex[player]
		buffer[idx] = { Tick = tick, CFrames = cframes }
		WriteIndex[player] = idx % BUFFER_SIZE + 1
	end
end

-- Get the CFrame of a specific hitbox part at a given time (binary search)
function HitboxHistory.GetPartAt(player: Player, partName: string, atTime: number): CFrame?
	local buffer = History[player]
	if not buffer or #buffer == 0 then
		return nil
	end

	-- Binary search for closest tick
	local left, right = 1, #buffer
	while left < right do
		local mid = math.floor((left + right) / 2)
		if buffer[mid].Tick < atTime then
			left = mid + 1
		else
			right = mid
		end
	end

	-- Find closest entry
	local closest = buffer[left]
	local closestDiff = math.abs(closest.Tick - atTime)

	-- Check neighbor
	if left > 1 then
		local prev = buffer[left - 1]
		local prevDiff = math.abs(prev.Tick - atTime)
		if prevDiff < closestDiff then
			closest = prev
			closestDiff = prevDiff
		end
	end
	if left < #buffer then
		local next = buffer[left + 1]
		local nextDiff = math.abs(next.Tick - atTime)
		if nextDiff < closestDiff then
			closest = next
		end
	end

	return closest.CFrames[partName]
end

-- Get all hitbox CFrames at a given time
function HitboxHistory.GetAllAt(player: Player, atTime: number): { [string]: CFrame }?
	local buffer = History[player]
	if not buffer or #buffer == 0 then
		return nil
	end

	-- Binary search
	local left, right = 1, #buffer
	while left < right do
		local mid = math.floor((left + right) / 2)
		if buffer[mid].Tick < atTime then
			left = mid + 1
		else
			right = mid
		end
	end

	-- Find closest
	local closest = buffer[left]
	local closestDiff = math.abs(closest.Tick - atTime)

	if left > 1 then
		local prev = buffer[left - 1]
		if math.abs(prev.Tick - atTime) < closestDiff then
			closest = prev
		end
	end
	if left < #buffer then
		local next = buffer[left + 1]
		if math.abs(next.Tick - atTime) < closestDiff then
			closest = next
		end
	end

	return closest.CFrames
end

-- Rewind a character's hitboxes to a given time (for validation)
function HitboxHistory.RewindTo(player: Player, atTime: number): { [string]: CFrame }?
	return HitboxHistory.GetAllAt(player, atTime)
end

-- Restore is a no-op for this implementation (we don't actually move parts)
-- In a full implementation, you'd temporarily move parts, raycast, then restore
function HitboxHistory.Restore(player: Player)
	-- No-op: we use CFrames for validation without moving parts
end

-- Start the capture loop
function HitboxHistory.Init()
	RunService.Heartbeat:Connect(function()
		HitboxHistory.Capture()
	end)
	print("[HitboxHistory] Initialized - 60Hz ring buffer, " .. BUFFER_SIZE .. " entries")
end

-- Cleanup
function HitboxHistory.CleanupPlayer(player: Player)
	History[player] = nil
	WriteIndex[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	HitboxHistory.CleanupPlayer(player)
end)

return HitboxHistory
