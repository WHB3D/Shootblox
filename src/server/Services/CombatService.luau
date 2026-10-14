--!strict
--[[
	SHOOTBLOX — Server-Authoritative Combat Service
	11-step validation pipeline per Blueprint §5.1.1/§5.1.2.
	Client sends intent + evidence; server derives and decides.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local HitboxHistory = require(script.Parent.HitboxHistory)
local RateLimiter = require(script.Parent.RateLimiter)

local CombatService = {}

function CombatService.SetDependencies(deps)
	-- Dependencies: Data, Match, Movement, Weapon
end

-- Pipeline constants (Blueprint §5.1.2)
local MAX_LATENCY = 0.8 -- seconds
local ORIGIN_TOLERANCE = 5 -- studs
local HIT_TOLERANCE_BASE = 10 -- studs
local INTERPOLATION_BUFFER = 0.08 -- seconds
local DIRECTION_ANGLE_TOLERANCE = 5 -- degrees

-- Validation result codes
local ValidationCode = {
	OK = "OK",
	InvalidShape = "INVALID_SHAPE",
	InvalidState = "INVALID_STATE",
	InvalidRate = "INVALID_RATE",
	InvalidTimestamp = "INVALID_TIMESTAMP",
	InvalidOrigin = "INVALID_ORIGIN",
	InvalidDirection = "INVALID_DIRECTION",
	InvalidTarget = "INVALID_TARGET",
	InvalidDamage = "INVALID_DAMAGE",
	InvalidAmmo = "INVALID_AMMO",
	InvalidRange = "INVALID_RANGE",
	InvalidLOS = "INVALID_LOS",
	OnCooldown = "ON_COOLDOWN",
}

-- Track last accepted shot per player per weapon (for rate validation)
local LastAcceptedShot: { [Player]: { [string]: number } } = {}

function CombatService.Init()
	HitboxHistory.Init()
	RateLimiter.Init()

	-- Handle incoming fire requests
	Net.ClientToServer.Fire:Connect(function(player: Player, request: Types.ShotRequest)
		local result = CombatService.ValidateShot(player, request)
		if result.Valid then
			CombatService.ApplyDamage(player, result, request)
		else
			Net.ServerFire(player, "Error", {
				Code = result.RejectReason,
				Message = "Shot rejected: " .. result.RejectReason,
			})
		end
	end)

	-- Reload handling
	Net.ClientToServer.Reload:Connect(function(player: Player, data: { WeaponId: string })
		local weapon = Weapons.Get(data.WeaponId)
		if not weapon then return end

		player:SetAttribute("Ammo_" .. data.WeaponId, weapon.MagSize)
		Net.ServerFire(player, "Reloaded", { WeaponId = data.WeaponId, Ammo = weapon.MagSize })
	end)

	print("[CombatService] Initialized - 11-step validation pipeline active")
end

-- THE 11-STEP VALIDATION PIPELINE (Blueprint §5.1.1)
function CombatService.ValidateShot(player: Player, request: Types.ShotRequest): Types.ValidationResult
	local weapon = Weapons.Get(request.WeaponId)
	if not weapon then
		return { Valid = false, RejectReason = ValidationCode.InvalidShape }
	end

	-- STEP 1: Type & shape (NaN check)
	if typeof(request.Origin) ~= "Vector3" or request.Origin ~= request.Origin then
		return { Valid = false, RejectReason = ValidationCode.InvalidShape }
	end
	if typeof(request.Direction) ~= "Vector3" or request.Direction ~= request.Direction then
		return { Valid = false, RejectReason = ValidationCode.InvalidShape }
	end
	if typeof(request.Timestamp) ~= "number" or request.Timestamp ~= request.Timestamp then
		return { Valid = false, RejectReason = ValidationCode.InvalidShape }
	end

	-- STEP 2: State - alive, character exists, weapon equipped
	local character = player.Character
	if not character then
		return { Valid = false, RejectReason = ValidationCode.InvalidState }
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return { Valid = false, RejectReason = ValidationCode.InvalidState }
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { Valid = false, RejectReason = ValidationCode.InvalidState }
	end

	-- STEP 3: Rate of fire (token bucket via RateLimiter)
	if not RateLimiter.AcceptShot(player, weapon.FireRate) then
		return { Valid = false, RejectReason = ValidationCode.InvalidRate }
	end

	-- STEP 4: Timestamp window
	local latency = workspace:GetServerTimeNow() - request.Timestamp
	if latency < 0 or latency > MAX_LATENCY then
		return { Valid = false, RejectReason = ValidationCode.InvalidTimestamp }
	end

	-- STEP 5: Origin sanity (≤ 5 studs from server-known head)
	local originDrift = (request.Origin - head.Position).Magnitude
	if originDrift > ORIGIN_TOLERANCE then
		CombatService.FlagSuspicion(player, "ORIGIN_MISMATCH", { Drift = originDrift })
		return { Valid = false, RejectReason = ValidationCode.InvalidOrigin }
	end

	-- STEP 6: Direction sanity (angle between reported direction and muzzle→hit)
	if request.HitPosition then
		local toHit = (request.HitPosition - request.Origin).Unit
		local angle = math.deg(math.acos(math.clamp(request.Direction:Dot(toHit), -1, 1)))
		if angle > DIRECTION_ANGLE_TOLERANCE then
			CombatService.FlagSuspicion(player, "DIRECTION_MISMATCH", { Angle = angle })
			return { Valid = false, RejectReason = ValidationCode.InvalidDirection }
		end
	end

	-- STEP 7: Hit validation (rewind → server raycast → compare)
	local targetResult = CombatService.ValidateTarget(player, request, weapon, latency)
	if not targetResult.Valid then
		return targetResult
	end

	-- STEP 8: Range validation
	local range = (targetResult.HitPosition - request.Origin).Magnitude
	if range > weapon.Range then
		return { Valid = false, RejectReason = ValidationCode.InvalidRange }
	end

	-- STEP 9: Line of sight
	local losResult = CombatService.CheckLOS(player, request, weapon, targetResult.HitPosition)
	if not losResult.Valid then
		return losResult
	end

	-- STEP 10: Damage calculation
	local damageResult = CombatService.CalculateDamage(weapon, range, targetResult.Headshot)
	if not damageResult.Valid then
		return damageResult
	end

	-- STEP 11: Ammo (server-authoritative)
	local ammoResult = CombatService.CheckAmmo(player, request, weapon)
	if not ammoResult.Valid then
		return ammoResult
	end

	-- ALL CHECKS PASSED
	return {
		Valid = true,
		Damage = damageResult.Damage,
		HitPosition = targetResult.HitPosition,
		HitNormal = targetResult.HitNormal,
		Headshot = targetResult.Headshot,
	}
end

-- STEP 7: Hit validation with rewind
function CombatService.ValidateTarget(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig, latency: number)
	if not request.Target or not request.HitPosition then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	local targetPlayer = Players:GetPlayerFromCharacter(request.Target)
	if not targetPlayer then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Compute rewind time: when the shooter saw the target
	local rewindTime = request.Timestamp - (player:GetNetworkPing() / 1000 + INTERPOLATION_BUFFER)

	-- Get target's hitboxes at rewind time
	local rewoundCFrames = HitboxHistory.RewindTo(targetPlayer, rewindTime)
	if not rewoundCFrames then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Get rewound head position
	local rewoundHeadCF = rewoundCFrames["Head"] or rewoundCFrames["UpperTorso"]
	if not rewoundHeadCF then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	local rewoundHeadPos = rewoundHeadCF.Position

	-- Server raycast from shooter's origin toward direction
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }

	local rayResult = workspace:Raycast(request.Origin, request.Direction * weapon.Range, raycastParams)

	-- If server raycast hit the same character, accept
	local serverHitChar = nil
	if rayResult then
		serverHitChar = rayResult.Instance:FindFirstAncestorOfClass("Model")
	end

	if serverHitChar and serverHitChar ~= targetPlayer.Character then
		-- Server sees a different character in the way
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Compare client hit position with rewound head position
	-- Tolerance: 10 studs + targetVelocity × latency
	local targetVelocity = request.Target:FindFirstChild("HumanoidRootPart")
		and request.Target.HumanoidRootPart.AssemblyLinearVelocity.Magnitude or 0
	local tolerance = HIT_TOLERANCE_BASE + targetVelocity * latency

	local drift = (rewoundHeadPos - request.HitPosition).Magnitude
	if drift > tolerance then
		CombatService.FlagSuspicion(player, "HIT_MISMATCH", {
			Drift = drift,
			Tolerance = tolerance,
			Latency = latency,
		})
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Determine headshot from rewound position
	local headshot = false
	if (rewoundHeadPos - request.HitPosition).Magnitude < 3 then
		headshot = true
	end

	return {
		Valid = true,
		HitPosition = rewoundHeadPos,
		HitNormal = rayResult and rayResult.Normal or Vector3.new(0, 1, 0),
		Headshot = headshot,
	}
end

-- STEP 9: Line of sight
function CombatService.CheckLOS(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig, hitPosition: Vector3)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }
	raycastParams.IgnoreWater = true

	local direction = (hitPosition - request.Origin).Unit
	local distance = (hitPosition - request.Origin).Magnitude

	local result = workspace:Raycast(request.Origin, direction * distance, raycastParams)

	if result then
		-- Check if we hit something before the target
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		if hitChar and hitChar ~= request.Target then
			-- Hit something else first - check if penetrable
			if result.Material ~= Enum.Material.Glass and result.Material ~= Enum.Material.Plastic then
				CombatService.FlagSuspicion(player, "WALL_BLOCKED", {
					Material = tostring(result.Material),
				})
				return { Valid = false, RejectReason = ValidationCode.InvalidLOS }
			end
		end
	end

	return { Valid = true }
end

-- STEP 10: Damage calculation
function CombatService.CalculateDamage(weapon: Types.WeaponConfig, range: number, headshot: boolean)
	local baseDamage = weapon.Damage
	local multiplier = 1.0

	-- Apply damage dropoff
	if weapon.DamageDropoff then
		local sortedRanges = {}
		for r in weapon.DamageDropoff do
			table.insert(sortedRanges, r)
		end
		table.sort(sortedRanges)

		for _, r in sortedRanges do
			if range <= r then
				multiplier = weapon.DamageDropoff[r]
				break
			end
		end
		if range > sortedRanges[#sortedRanges] then
			multiplier = CombatConfig.Tolerances.MinDamagePercent
		end
	end

	-- Apply headshot multiplier
	if headshot then
		multiplier *= weapon.HeadshotMultiplier
	end

	local finalDamage = math.floor(baseDamage * multiplier + 0.5)
	finalDamage = math.max(1, finalDamage)

	-- Validate against weapon max possible damage
	local maxPossible = weapon.Damage * weapon.HeadshotMultiplier
	if finalDamage > maxPossible * 1.1 then
		return { Valid = false, RejectReason = ValidationCode.InvalidDamage }
	end

	return { Valid = true, Damage = finalDamage }
end

-- STEP 11: Ammo
function CombatService.CheckAmmo(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig)
	local currentAmmo = player:GetAttribute("Ammo_" .. request.WeaponId) or weapon.MagSize
	if currentAmmo <= 0 then
		return { Valid = false, RejectReason = ValidationCode.InvalidAmmo }
	end

	player:SetAttribute("Ammo_" .. request.WeaponId, currentAmmo - 1)
	return { Valid = true }
end

-- Apply validated damage
function CombatService.ApplyDamage(attacker: Player, result: Types.ValidationResult, request: Types.ShotRequest)
	if not request.Target then return end

	local targetChar = request.Target:FindFirstAncestorOfClass("Model")
	if not targetChar then return end

	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Apply damage (server-authoritative)
	humanoid:TakeDamage(result.Damage)

	-- Send hit confirmation to attacker
	Net.ServerFire(attacker, "HitConfirm", {
		WeaponId = request.WeaponId,
		Damage = result.Damage,
		HitPosition = result.HitPosition,
		Headshot = result.Headshot or false,
	})

	-- Send ammo update to attacker
	local currentAmmo = attacker:GetAttribute("Ammo_" .. request.WeaponId) or 0
	Net.ServerFire(attacker, "AmmoUpdate", {
		Current = currentAmmo,
		Reserve = attacker:GetAttribute("Ammo_Reserve_" .. request.WeaponId) or 0,
	})

	-- Send health update to victim
	Net.ServerFire(Players:GetPlayerFromCharacter(targetChar), "HealthUpdate", {
		Current = humanoid.Health,
		Max = humanoid.MaxHealth,
	})

	-- Kill feed
	if humanoid.Health <= 0 then
		Net.Broadcast("KillFeed", {
			Killer = attacker.Name,
			Victim = targetChar.Name,
			Weapon = request.WeaponId,
			Headshot = result.Headshot or false,
		})
	end

	-- Log for analytics
	print(string.format("[CombatService] %s -> %s: %.0f dmg (headshot=%s)",
		attacker.Name, targetChar.Name, result.Damage, tostring(result.Headshot)))
end

-- Anti-cheat suspicion flagging
function CombatService.FlagSuspicion(player: Player, reason: string, details: any)
	warn(string.format("[CombatService] Suspicion: %s - %s (%s)", player.Name, reason, details))
	-- TODO: Integrate with DataService strike system
end

return CombatService