--!strict
--[[
	SHOOTBLOX — CombatService Angle Validation Tests
	Tests the angle deviation check (Check 3)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)

local function createMockPlayer(name: string, headCFrame: CFrame)
	return {
		Name = name,
		Character = {
			FindFirstChild = function(self, childName: string)
				if childName == "Head" then
					return { CFrame = headCFrame }
				end
				return nil
			end,
		},
	}
end

local function createMockRequest(direction: Vector3)
	return {
		WeaponId = "AR_Standard",
		Origin = Vector3.new(0, 5, 0),
		Direction = direction,
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
	}
end

local function checkAngle(player, request)
	local character = player.Character
	if not character then
		return { Valid = false, RejectReason = "INVALID_ANGLE" }
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return { Valid = false, RejectReason = "INVALID_ANGLE" }
	end

	local actualDirection = head.CFrame.LookVector
	local claimedDirection = request.Direction
	local angle = math.deg(math.acos(math.clamp(actualDirection:Dot(claimedDirection), -1, 1)))

	if angle > CombatConfig.Tolerances.ClaimMaxAngleDeg then
		return { Valid = false, RejectReason = "INVALID_ANGLE" }
	end

	return { Valid = true }
end

local Tests = {}

Tests["Angle check passes when deviation within tolerance"] = function()
	-- Player looking straight forward (-Z)
	local player = createMockPlayer("TestPlayer", CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, 0))
	-- Request direction slightly off (2 degrees)
	local request = createMockRequest(Vector3.new(math.rad(2), 0, -1).Unit)
	
	local result = checkAngle(player, request)
	TestEZ.assert(result.Valid == true, "Should pass with angle < 4 degrees")
end

Tests["Angle check fails when deviation exceeds tolerance"] = function()
	local player = createMockPlayer("TestPlayer", CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, 0))
	-- Request direction way off (10 degrees)
	local request = createMockRequest(Vector3.new(math.rad(10), 0, -1).Unit)
	
	local result = checkAngle(player, request)
	TestEZ.assert(result.Valid == false, "Should fail with angle > 4 degrees")
	TestEZ.assert(result.RejectReason == "INVALID_ANGLE", "Should return INVALID_ANGLE code")
end

Tests["Angle check passes at exactly tolerance boundary"] = function()
	local player = createMockPlayer("TestPlayer", CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, 0))
	-- Exactly 4 degrees
	local request = createMockRequest(Vector3.new(math.rad(4), 0, -1).Unit)
	
	local result = checkAngle(player, request)
	TestEZ.assert(result.Valid == true, "Should pass at exactly 4 degrees")
end

Tests["Angle check fails when character missing"] = function()
	local player = { Name = "TestPlayer", Character = nil }
	local request = createMockRequest(Vector3.new(0, 0, -1))
	
	local result = checkAngle(player, request)
	TestEZ.assert(result.Valid == false, "Should fail when character missing")
	TestEZ.assert(result.RejectReason == "INVALID_ANGLE", "Should return INVALID_ANGLE code")
end

Tests["Angle check fails when head missing"] = function()
	local player = {
		Name = "TestPlayer",
		Character = {
			FindFirstChild = function(self, childName: string)
				return nil
			end,
		},
	}
	local request = createMockRequest(Vector3.new(0, 0, -1))
	
	local result = checkAngle(player, request)
	TestEZ.assert(result.Valid == false, "Should fail when head missing")
	TestEZ.assert(result.RejectReason == "INVALID_ANGLE", "Should return INVALID_ANGLE code")
end

Tests["Angle check handles 180 degree deviation"] = function()
	local player = createMockPlayer("TestPlayer", CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, 0))
	-- Request direction exactly opposite (180 degrees)
	local request = createMockRequest(Vector3.new(0, 0, 1)) -- +Z instead of -Z
	
	local result = checkAngle(player, request)
	TestEZ.assert(result.Valid == false, "Should fail with 180 degree deviation")
	TestEZ.assert(result.RejectReason == "INVALID_ANGLE", "Should return INVALID_ANGLE code")
end

return Tests