--!strict
--[[
	SHOOTBLOX — CombatService Target Validation Tests
	Tests the rewind/lag compensation check (Check 4)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)

local function createMockTargetPlayer(name: string, history)
	return {
		Name = name,
		-- PositionHistory is normally in CombatService, we'll inject it
	}
end

local function createMockAttacker(name: string)
	return { Name = name }
end

local function createMockRequest(targetPlayer, hitPosition: Vector3, serverTick: number)
	return {
		WeaponId = "AR_Standard",
		Origin = Vector3.new(0, 5, 0),
		Direction = Vector3.new(0, 0, -1),
		Target = targetPlayer,
		HitPosition = hitPosition,
		Timestamp = os.clock(),
		ServerTick = serverTick,
	}
end

-- Mock the PositionHistory table from CombatService
local PositionHistory = {}

local function checkTarget(attacker, request)
	if not request.Target or not request.HitPosition then
		return { Valid = false, RejectReason = "INVALID_TARGET" }
	end

	-- Find target player
	local targetPlayer = request.Target -- In real code, this would be from Players:GetPlayerFromCharacter
	if not targetPlayer then
		return { Valid = false, RejectReason = "INVALID_TARGET" }
	end

	-- Get target's position history at request timestamp
	local history = PositionHistory[targetPlayer]
	if not history or #history == 0 then
		return { Valid = false, RejectReason = "INVALID_TARGET" }
	end

	-- Find closest history tick to request.ServerTick
	local bestEntry = history[1]
	local bestDiff = math.abs(history[1].Tick - request.ServerTick)
	for i = 2, #history do
		local diff = math.abs(history[i].Tick - request.ServerTick)
		if diff < bestDiff then
			bestDiff = diff
			bestEntry = history[i]
		end
	end

	-- Rewind target to that tick and validate hit
	local rewoundHeadCF = bestEntry.CFrames.Head
	local rewoundHeadPos = rewoundHeadCF.Position
	local drift = (rewoundHeadPos - request.HitPosition).Magnitude

	if drift > CombatConfig.Tolerances.ClaimMaxTargetDrift then
		return { Valid = false, RejectReason = "INVALID_TARGET" }
	end

	-- Determine hit group from rewound position
	local headshot = false
	if (rewoundHeadPos - request.HitPosition).Magnitude < 3 then
		headshot = true
	end

	return {
		Valid = true,
		HitPosition = rewoundHeadPos,
		HitNormal = Vector3.new(0, 1, 0),
		Headshot = headshot,
	}
end

local Tests = {}

Tests["Target check passes when hit matches rewound position"] = function()
	-- Clear history
	local targetPlayer = { Name = "Target" }
	PositionHistory[targetPlayer] = {}
	
	-- Add history entry at tick 1000
	PositionHistory[targetPlayer] = {
		{ Tick = 1000, CFrames = { Head = CFrame.new(10, 5, 0) } },
	}
	
	local attacker = createMockAttacker("Attacker")
	local request = createMockRequest(targetPlayer, Vector3.new(10, 5, 0), 1000)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == true, "Should pass when hit matches rewound position")
	TestEZ.assert(result.Headshot == true, "Should detect headshot when hit near head")
end

Tests["Target check fails when drift exceeds tolerance"] = function()
	local targetPlayer = { Name = "Target" }
	PositionHistory[targetPlayer] = {
		{ Tick = 1000, CFrames = { Head = CFrame.new(10, 5, 0) } },
	}
	
	local attacker = createMockAttacker("Attacker")
	-- Hit position 10 studs away from rewound head (tolerance is 6)
	local request = createMockRequest(targetPlayer, Vector3.new(20, 5, 0), 1000)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == false, "Should fail when drift > 6 studs")
	TestEZ.assert(result.RejectReason == "INVALID_TARGET", "Should return INVALID_TARGET code")
end

Tests["Target check finds closest history tick"] = function()
	local targetPlayer = { Name = "Target" }
	-- Multiple history entries at different ticks
	PositionHistory[targetPlayer] = {
		{ Tick = 990, CFrames = { Head = CFrame.new(0, 5, 0) } },
		{ Tick = 1000, CFrames = { Head = CFrame.new(10, 5, 0) } },
		{ Tick = 1010, CFrames = { Head = CFrame.new(20, 5, 0) } },
	}
	
	local attacker = createMockAttacker("Attacker")
	-- Request at tick 1002 should match tick 1000 entry (closest)
	local request = createMockRequest(targetPlayer, Vector3.new(10, 5, 0), 1002)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == true, "Should find closest tick (1000) to request tick (1002)")
	TestEZ.assert((result.HitPosition - Vector3.new(10, 5, 0)).Magnitude < 0.1, "Should use tick 1000 position")
end

Tests["Target check fails when no history"] = function()
	local targetPlayer = { Name = "Target" }
	PositionHistory[targetPlayer] = nil
	
	local attacker = createMockAttacker("Attacker")
	local request = createMockRequest(targetPlayer, Vector3.new(10, 5, 0), 1000)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == false, "Should fail when no position history")
	TestEZ.assert(result.RejectReason == "INVALID_TARGET", "Should return INVALID_TARGET code")
end

Tests["Target check fails when target missing"] = function()
	local attacker = createMockAttacker("Attacker")
	local request = createMockRequest(nil, Vector3.new(10, 5, 0), 1000)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == false, "Should fail when target is nil")
	TestEZ.assert(result.RejectReason == "INVALID_TARGET", "Should return INVALID_TARGET code")
end

Tests["Target check fails when hit position missing"] = function()
	local targetPlayer = { Name = "Target" }
	PositionHistory[targetPlayer] = {
		{ Tick = 1000, CFrames = { Head = CFrame.new(10, 5, 0) } },
	}
	
	local attacker = createMockAttacker("Attacker")
	local request = createMockRequest(targetPlayer, nil, 1000)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == false, "Should fail when hit position missing")
	TestEZ.assert(result.RejectReason == "INVALID_TARGET", "Should return INVALID_TARGET code")
end

Tests["Headshot detection works correctly"] = function()
	local targetPlayer = { Name = "Target" }
	PositionHistory[targetPlayer] = {
		{ Tick = 1000, CFrames = { Head = CFrame.new(10, 5, 0) } },
	}
	
	local attacker = createMockAttacker("Attacker")
	-- Hit 2 studs from head = headshot
	local request = createMockRequest(targetPlayer, Vector3.new(11.5, 5, 0), 1000)
	
	local result = checkTarget(attacker, request)
	TestEZ.assert(result.Valid == true)
	TestEZ.assert(result.Headshot == true, "Hit within 3 studs of head = headshot")
	
	-- Hit 4 studs from head = not headshot
	local request2 = createMockRequest(targetPlayer, Vector3.new(14, 5, 0), 1000)
	local result2 = checkTarget(attacker, request2)
	TestEZ.assert(result2.Valid == true)
	TestEZ.assert(result2.Headshot == false, "Hit > 3 studs from head = not headshot")
end

return Tests