--!strict
--[[
	SHOOTBLOX — CombatService Origin Validation Tests
	Tests the origin drift check (Check 1)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)

local function createMockPlayer(name: string, headPosition: Vector3)
	return {
		Name = name,
		Character = {
			FindFirstChild = function(self, childName: string)
				if childName == "Head" then
					return { Position = headPosition }
				end
				return nil
			end,
		},
	}
end

local function createMockRequest(origin: Vector3)
	return {
		WeaponId = "AR_Standard",
		Origin = origin,
		Direction = Vector3.new(0, 0, -1),
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
	}
end

local Tests = {}

-- Helper to run the origin check logic (extracted from CombatService)
local function checkOrigin(player, request)
	local character = player.Character
	if not character then
		return { Valid = false, RejectReason = "INVALID_ORIGIN" }
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return { Valid = false, RejectReason = "INVALID_ORIGIN" }
	end

	local actualOrigin = head.Position
	local drift = (actualOrigin - request.Origin).Magnitude

	if drift > CombatConfig.Tolerances.MaxOriginDrift then
		return { Valid = false, RejectReason = "INVALID_ORIGIN" }
	end

	return { Valid = true }
end

Tests["Origin check passes when drift is within tolerance"] = function()
	local player = createMockPlayer("TestPlayer", Vector3.new(0, 5, 0))
	local request = createMockRequest(Vector3.new(0.5, 5, 0.5)) -- ~0.7 stud drift
	local result = checkOrigin(player, request)
	TestEZ.assert(result.Valid == true, "Should pass with drift < 12 studs")
end

Tests["Origin check fails when drift exceeds tolerance"] = function()
	local player = createMockPlayer("TestPlayer", Vector3.new(0, 5, 0))
	local request = createMockRequest(Vector3.new(20, 5, 0)) -- 20 stud drift > 12
	local result = checkOrigin(player, request)
	TestEZ.assert(result.Valid == false, "Should fail with drift > 12 studs")
	TestEZ.assert(result.RejectReason == "INVALID_ORIGIN", "Should return INVALID_ORIGIN code")
end

Tests["Origin check fails when character missing"] = function()
	local player = { Name = "TestPlayer", Character = nil }
	local request = createMockRequest(Vector3.new(0, 5, 0))
	local result = checkOrigin(player, request)
	TestEZ.assert(result.Valid == false, "Should fail when character missing")
	TestEZ.assert(result.RejectReason == "INVALID_ORIGIN", "Should return INVALID_ORIGIN code")
end

Tests["Origin check fails when head missing"] = function()
	local player = {
		Name = "TestPlayer",
		Character = {
			FindFirstChild = function(self, childName: string)
				return nil
			end,
		},
	}
	local request = createMockRequest(Vector3.new(0, 5, 0))
	local result = checkOrigin(player, request)
	TestEZ.assert(result.Valid == false, "Should fail when head missing")
	TestEZ.assert(result.RejectReason == "INVALID_ORIGIN", "Should return INVALID_ORIGIN code")
end

Tests["Origin check passes at exactly tolerance boundary"] = function()
	local player = createMockPlayer("TestPlayer", Vector3.new(0, 5, 0))
	local request = createMockRequest(Vector3.new(12, 5, 0)) -- exactly 12 studs
	local result = checkOrigin(player, request)
	TestEZ.assert(result.Valid == true, "Should pass at exactly 12 studs")
end

return Tests