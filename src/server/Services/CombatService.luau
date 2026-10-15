--!strict
--[[
	SHOOTBLOX — Server-Authoritative Combat Service
	11-step validation pipeline per Blueprint §5.1.1/§5.1.2.
	Client sends intent + evidence; server derives and decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local HitboxHistory = require(script.Parent.HitboxHistory)
local RateLimiter = require(script.Parent.RateLimiter)

type ShotRequest = Types.ShotRequest
type ValidationResult = Types.ValidationResult
type WeaponConfig = Types.WeaponConfig

local CombatService = {}

function CombatService.SetDependencies(_deps)
	-- Dependencies: Data, Match, Movement, Weapon
end

-- Pipeline constants (Blueprint §5.1.2)
local MAX_LATENCY = 0.8 -- seconds
local ORIGIN_TOLERANCE = 5 -- studs
local HIT_TOLERANCE_BASE = 10 -- studs
local INTERPOLATION_BUFFER = 0.08 -- seconds
local DIRECTION_ANGLE_TOLERANCE = 5 -- degrees
local HEADSHOT_RADIUS = 3 -- studs from rewound head center

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

local function reject(code: string): ValidationResult
	return { Valid = false, RejectReason = code }
end

local function isNaN(n: number): boolean
	return n ~= n
end

function CombatService.Init()
	HitboxHistory.Init()
	RateLimiter.Init()

	-- Handle incoming fire requests
	Net.ClientToServer.Fire:Connect(function(player: Player, request: ShotRequest)
		local result = CombatService.ValidateShot(player, request)
		if result.Valid then
			CombatService.ApplyDamage(player, result, request)
		else
			local code = result.RejectReason or "UNKNOWN"
			Net.ServerFire(player, "Error", {
				Code = code,
				Message = "Shot rejected: " .. code,
			})
		end
	end)

	-- Reload handling
	Net.ClientToServer.Reload:Connect(function(player: Player, data: { WeaponId: string })
		local weapon = Weapons.Get(data.WeaponId)
		if not weapon then
			return
		end

		player:SetAttribute("Ammo_" .. data.WeaponId, weapon.MagSize)
		Net.ServerFire(player, "Reloaded", { WeaponId = data.WeaponId, Ammo = weapon.MagSize })
	end)

	print("[CombatService] Initialized - 11-step validation pipeline active")
end

-- THE 11-STEP VALIDATION PIPELINE (Blueprint §5.1.1)
function CombatService.ValidateShot(player: Player, request: ShotRequest): ValidationResult
	local weapon = Weapons.Get(request.WeaponId)
	if not weapon then
		return reject(ValidationCode.InvalidShape)
	end

	-- STEP 1: Type & shape (NaN check)
	if typeof(request.Origin) ~= "Vector3" or isNaN(request.Origin.X) then
		return reject(ValidationCode.InvalidShape)
	end
	if typeof(request.Direction) ~= "Vector3" or isNaN(request.Direction.X) then
		return reject(ValidationCode.InvalidShape)
	end
	if typeof(request.Timestamp) ~= "number" or isNaN(request.Timestamp) then
		return reject(ValidationCode.InvalidShape)
	end

	-- STEP 2: State - alive, character exists, weapon equipped
	local character = player.Character
	if not character then
		return reject(ValidationCode.InvalidState)
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return reject(ValidationCode.InvalidState)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return reject(ValidationCode.InvalidState)
	end

	-- STEP 3: Rate of fire (token bucket via RateLimiter)
	if not RateLimiter.AcceptShot(player, weapon.FireRate) then
		return reject(ValidationCode.InvalidRate)
	end

	-- STEP 4: Timestamp window
	local latency = workspace:GetServerTimeNow() - request.Timestamp
	if latency < 0 or latency > MAX_LATENCY then
		return reject(ValidationCode.InvalidTimestamp)
	end

	-- STEP 5: Origin sanity (≤ 5 studs from server-known head)
	local originDrift = (request.Origin - head.Position).Magnitude
	if originDrift > ORIGIN_TOLERANCE then
		CombatService.FlagSuspicion(player, "ORIGIN_MISMATCH", { Drift = originDrift })
		return reject(ValidationCode.InvalidOrigin)
	end

	-- STEP 6: Direction sanity (angle between reported direction and muzzle→hit)
	if request.HitPosition then
		local toHit = (request.HitPosition - request.Origin).Unit
		local angle = math.deg(math.acos(math.clamp(request.Direction:Dot(toHit), -1, 1)))
		if angle > DIRECTION_ANGLE_TOLERANCE then
			CombatService.FlagSuspicion(player, "DIRECTION_MISMATCH", { Angle = angle })
			return reject(ValidationCode.InvalidDirection)
		end
	end

	-- STEP 7: Hit validation (rewind → server raycast → compare)
	local targetResult = CombatService.ValidateTarget(player, request, weapon, latency)
	if not targetResult.Valid or not targetResult.HitPosition then
		return targetResult
	end
	local hitPosition = targetResult.HitPosition

	-- STEP 8: Range validation
	local range = (hitPosition - request.Origin).Magnitude
	if range > weapon.Range then
		return reject(ValidationCode.InvalidRange)
	end

	-- STEP 9: Line of sight
	local losResult = CombatService.CheckLOS(player, request, hitPosition)
	if not losResult.Valid then
		return losResult
	end

	-- STEP 10: Damage calculation
	local damageResult = CombatService.CalculateDamage(weapon, range, targetResult.Headshot == true)
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
		HitPosition = hitPosition,
		HitNormal = targetResult.HitNormal,
		Headshot = targetResult.Headshot,
	}
end

-- STEP 7: Hit validation with rewind
function CombatService.ValidateTarget(
	player: Player,
	request: ShotRequest,
	weapon: WeaponConfig,
	latency: number
): ValidationResult
	local target = request.Target
	local claimedHit = request.HitPosition
	if not target or not claimedHit then
		return reject(ValidationCode.InvalidTarget)
	end

	local targetModel = target:FindFirstAncestorOfClass("Model") or (target:IsA("Model") and target or nil)
	if not targetModel then
		return reject(ValidationCode.InvalidTarget)
	end
	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if not targetPlayer then
		return reject(ValidationCode.InvalidTarget)
	end

	-- Compute rewind time: when the shooter saw the target
	local rewindTime = request.Timestamp - (player:GetNetworkPing() + INTERPOLATION_BUFFER)

	-- Get target's hitboxes at rewind time
	local rewoundCFrames = HitboxHistory.RewindTo(targetPlayer, rewindTime)
	if not rewoundCFrames then
		return reject(ValidationCode.InvalidTarget)
	end

	local rewoundHeadCF = rewoundCFrames["Head"] or rewoundCFrames["UpperTorso"]
	if not rewoundHeadCF then
		return reject(ValidationCode.InvalidTarget)
	end
	local rewoundHeadPos = rewoundHeadCF.Position

	-- Server raycast from shooter's origin toward direction
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character :: any }

	local rayResult = workspace:Raycast(request.Origin, request.Direction * weapon.Range, raycastParams)

	-- If server raycast hit a different character, something is in the way
	if rayResult then
		local serverHitChar = rayResult.Instance:FindFirstAncestorOfClass("Model")
		if serverHitChar and serverHitChar ~= targetModel then
			return reject(ValidationCode.InvalidTarget)
		end
	end

	-- Compare client hit position with rewound head position
	-- Tolerance: 10 studs + targetVelocity × latency (favor the shooter)
	local targetVelocity = 0
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
	if targetRoot and targetRoot:IsA("BasePart") then
		targetVelocity = targetRoot.AssemblyLinearVelocity.Magnitude
	end
	local tolerance = HIT_TOLERANCE_BASE + targetVelocity * latency

	local drift = (rewoundHeadPos - claimedHit).Magnitude
	if drift > tolerance then
		CombatService.FlagSuspicion(player, "HIT_MISMATCH", {
			Drift = drift,
			Tolerance = tolerance,
			Latency = latency,
		})
		return reject(ValidationCode.InvalidTarget)
	end

	return {
		Valid = true,
		HitPosition = rewoundHeadPos,
		HitNormal = if rayResult then rayResult.Normal else Vector3.new(0, 1, 0),
		Headshot = drift < HEADSHOT_RADIUS,
	}
end

-- STEP 9: Line of sight
function CombatService.CheckLOS(player: Player, request: ShotRequest, hitPosition: Vector3): ValidationResult
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character :: any }
	raycastParams.IgnoreWater = true

	local offset = hitPosition - request.Origin
	local result = workspace:Raycast(request.Origin, offset, raycastParams)

	if result then
		-- Hit something before the target — only glass/plastic are penetrable
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		local targetModel = request.Target and request.Target:FindFirstAncestorOfClass("Model")
		if hitChar ~= targetModel then
			if result.Material ~= Enum.Material.Glass and result.Material ~= Enum.Material.Plastic then
				CombatService.FlagSuspicion(player, "WALL_BLOCKED", {
					Material = tostring(result.Material),
				})
				return reject(ValidationCode.InvalidLOS)
			end
		end
	end

	return { Valid = true }
end

-- STEP 10: Damage calculation
function CombatService.CalculateDamage(weapon: WeaponConfig, range: number, headshot: boolean): ValidationResult
	local baseDamage = weapon.Damage
	local multiplier = 1.0

	-- Apply damage dropoff
	local dropoff = weapon.DamageDropoff
	if dropoff then
		local sortedRanges: { number } = {}
		for r in dropoff do
			table.insert(sortedRanges, r)
		end
		table.sort(sortedRanges)

		local matched = false
		for _, r in sortedRanges do
			if range <= r then
				multiplier = dropoff[r]
				matched = true
				break
			end
		end
		if not matched then
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
		return reject(ValidationCode.InvalidDamage)
	end

	return { Valid = true, Damage = finalDamage }
end

-- STEP 11: Ammo
function CombatService.CheckAmmo(player: Player, request: ShotRequest, weapon: WeaponConfig): ValidationResult
	local stored = player:GetAttribute("Ammo_" .. request.WeaponId)
	local currentAmmo = if typeof(stored) == "number" then stored else weapon.MagSize
	if currentAmmo <= 0 then
		return reject(ValidationCode.InvalidAmmo)
	end

	player:SetAttribute("Ammo_" .. request.WeaponId, currentAmmo - 1)
	return { Valid = true }
end

-- Apply validated damage
function CombatService.ApplyDamage(attacker: Player, result: ValidationResult, request: ShotRequest)
	local target = request.Target
	local damage = result.Damage
	if not target or not damage then
		return
	end

	local targetChar = target:FindFirstAncestorOfClass("Model") or (target:IsA("Model") and target or nil)
	if not targetChar then
		return
	end

	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local headshot = result.Headshot == true

	-- Apply damage (server-authoritative)
	humanoid:TakeDamage(damage)

	-- Hit confirmation to attacker
	Net.ServerFire(attacker, "HitConfirm", {
		WeaponId = request.WeaponId,
		Damage = damage,
		HitPosition = result.HitPosition,
		Headshot = headshot,
	})

	-- Ammo update to attacker
	local currentAmmo = attacker:GetAttribute("Ammo_" .. request.WeaponId)
	Net.ServerFire(attacker, "AmmoUpdate", {
		Current = if typeof(currentAmmo) == "number" then currentAmmo else 0,
		Reserve = 0,
	})

	-- Health update to victim (bots have no Player)
	local victim = Players:GetPlayerFromCharacter(targetChar)
	if victim then
		Net.ServerFire(victim, "HealthUpdate", {
			Current = humanoid.Health,
			Max = humanoid.MaxHealth,
		})
	end

	-- Kill feed
	if humanoid.Health <= 0 then
		Net.Broadcast("KillFeed", {
			Killer = attacker.Name,
			Victim = targetChar.Name,
			Weapon = request.WeaponId,
			Headshot = headshot,
		})
	end

	print(
		string.format(
			"[CombatService] %s -> %s: %d dmg (headshot=%s)",
			attacker.Name,
			targetChar.Name,
			damage,
			tostring(headshot)
		)
	)
end

-- Anti-cheat suspicion flagging
function CombatService.FlagSuspicion(player: Player, reason: string, details: { [string]: any })
	local parts = {}
	for k, v in details do
		table.insert(parts, k .. "=" .. tostring(v))
	end
	warn(string.format("[CombatService] Suspicion: %s - %s (%s)", player.Name, reason, table.concat(parts, ", ")))
	-- TODO: Integrate with DataService strike system
end

return CombatService
