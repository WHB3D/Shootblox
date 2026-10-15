--!strict
--[[
	SHOOTBLOX — CombatService Line of Sight Validation Tests
	Tests the raycast/line-of-sight check (Check 8)
]]

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Combat)
local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

-- Mock workspace for raycasting
local MockWorkspace = {}
local raycastResults = {}

MockWorkspace.Raycast = function(origin: Vector3, direction: Vector3, params: RaycastParams)
	local key = origin.X
		.. ","
		.. origin.Y
		.. ","
		.. origin.Z
		.. "->"
		.. direction.X
		.. ","
		.. direction.Y
		.. ","
		.. direction.Z
	return raycastResults[key] or nil
end

local originalWorkspace = workspace
workspace = MockWorkspace

local function createMockPlayer(name: string)
	return { Name = name, Character = { Name = name .. "_Char" } }
end

local function createMockTarget(name: string)
	return {
		Name = name .. "_Char",
		FindFirstAncestorOfClass = function(self, className)
			if className == "Model" then
				return self
			end
			return nil
		end,
	}
end

local function createMockRequest(weaponId: string, target, hitPosition: Vector3?)
	return {
		WeaponId = weaponId,
		Origin = Vector3.new(0, 5, 0),
		Direction = Vector3.new(0, 0, -1),
		Target = target,
		HitPosition = hitPosition,
		Timestamp = os.clock(),
		ServerTick = workspace:GetServerTimeNow(),
		ShotId = "test",
	}
end

local function checkLOS(player, request, weapon)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }
	raycastParams.IgnoreWater = true

	local result = workspace:Raycast(request.Origin, request.Direction * weapon.Range, raycastParams)

	if not result then
		if not request.Target then
			return { Valid = false, RejectReason = "INVALID_LOS" }
		end
	end

	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		if hitChar and hitChar ~= request.Target then
			if result.Material ~= Enum.Material.Glass and result.Material ~= Enum.Material.Plastic then
				return { Valid = false, RejectReason = "INVALID_LOS" }
			end
		end
	end

	return { Valid = true }
end

local function resetRaycasts()
	raycastResults = {}
end

local Tests = {}

Tests["LOS passes when clear shot to target"] = function()
	resetRaycasts()
	-- No raycast hit = clear path
	local player = createMockPlayer("Attacker")
	local target = createMockTarget("Target")
	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", target, Vector3.new(0, 5, -50))

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass with clear LOS")
end

Tests["LOS fails when hitting another player first"] = function()
	resetRaycasts()
	local player = createMockPlayer("Attacker")
	local target = createMockTarget("Target")
	local blocker = createMockTarget("Blocker")

	-- Raycast hits blocker first
	raycastResults["0,5,0->0,0,-1"] = {
		Instance = blocker,
		Material = Enum.Material.Plastic, -- Not glass/plastic
	}

	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", target, Vector3.new(0, 5, -50))

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == false, "Should fail when hitting another player first")
	TestEZ.assert(result.RejectReason == "INVALID_LOS", "Should return INVALID_LOS code")
end

Tests["LOS passes when hitting glass first (penetrable)"] = function()
	resetRaycasts()
	local player = createMockPlayer("Attacker")
	local target = createMockTarget("Target")

	raycastResults["0,5,0->0,0,-1"] = {
		Instance = createMockTarget("GlassWall"),
		Material = Enum.Material.Glass,
	}

	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", target, Vector3.new(0, 5, -50))

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass through glass")
end

Tests["LOS passes when hitting plastic first (penetrable)"] = function()
	resetRaycasts()
	local player = createMockPlayer("Attacker")
	local target = createMockTarget("Target")

	raycastResults["0,5,0->0,0,-1"] = {
		Instance = createMockTarget("PlasticWall"),
		Material = Enum.Material.Plastic,
	}

	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", target, Vector3.new(0, 5, -50))

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass through plastic")
end

Tests["LOS fails when no target and no hit"] = function()
	resetRaycasts()
	local player = createMockPlayer("Attacker")
	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", nil, nil)

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == false, "Should fail when no target and no hit")
	TestEZ.assert(result.RejectReason == "INVALID_LOS", "Should return INVALID_LOS code")
end

Tests["LOS passes when raycast hits target directly"] = function()
	resetRaycasts()
	local player = createMockPlayer("Attacker")
	local target = createMockTarget("Target")

	raycastResults["0,5,0->0,0,-1"] = {
		Instance = target,
		Material = Enum.Material.Plastic,
	}

	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", target, Vector3.new(0, 5, -50))

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == true, "Should pass when raycast hits target directly")
end

Tests["LOS fails when hitting concrete wall"] = function()
	resetRaycasts()
	local player = createMockPlayer("Attacker")
	local target = createMockTarget("Target")

	raycastResults["0,5,0->0,0,-1"] = {
		Instance = createMockTarget("ConcreteWall"),
		Material = Enum.Material.Concrete,
	}

	local weapon = Weapons.Get("AR_Standard")
	local request = createMockRequest("AR_Standard", target, Vector3.new(0, 5, -50))

	local result = checkLOS(player, request, weapon)
	TestEZ.assert(result.Valid == false, "Should fail when hitting concrete")
	TestEZ.assert(result.RejectReason == "INVALID_LOS", "Should return INVALID_LOS code")
end

-- Restore workspace
workspace = originalWorkspace

return Tests
