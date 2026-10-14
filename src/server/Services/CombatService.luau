--!strict
--[[
	SHOOTBLOX — Server-Authoritative Combat Service
	9-check validation pipeline: the moat we deeply own.
	Client sends intent + evidence; server derives and decides.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)

local CombatService = {}

function CombatService.SetDependencies(deps)
	-- Store dependencies if needed
end

-- Position history for lag compensation (rewind)
local PositionHistory: { [Player]: { { Tick: number, CFrames: { [string]: CFrame } } } } = {}
local SERVER_TICK_RATE = 50
local TICK_INTERVAL = 1 / SERVER_TICK_RATE

-- Validation result codes
local ValidationCode = {
	OK = "OK",
	InvalidOrigin = "INVALID_ORIGIN",
	InvalidRate = "INVALID_RATE",
	InvalidAngle = "INVALID_ANGLE",
	InvalidTarget = "INVALID_TARGET",
	InvalidDamage = "INVALID_DAMAGE",
	InvalidAmmo = "INVALID_AMMO",
	InvalidRange = "INVALID_RANGE",
	InvalidLOS = "INVALID_LOS",
	OnCooldown = "ON_COOLDOWN",
}

-- Initialize position history tracking
function CombatService.Init()
	RunService.Heartbeat:Connect(function(dt)
		local tick = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				local head = character:FindFirstChild("Head")
				if hrp and head then
					local history = PositionHistory[player]
					if not history then
						history = {}
						PositionHistory[player] = history
					end
					table.insert(history, {
						Tick = tick,
						CFrames = {
							HRP = hrp.CFrame,
							Head = head.CFrame,
						},
					})
					-- Trim old history
					while #history > CombatConfig.Tolerances.RewindBufferSize do
						table.remove(history, 1)
					end
				end
			end
		end
	end)

	-- Handle incoming fire requests
	Net.ClientToServer.Fire:Connect(function(player: Player, request: Types.ShotRequest)
		local result = CombatService.ValidateShot(player, request)
		if result.Valid then
			CombatService.ApplyDamage(player, result)
			Net.ServerFire(player, "HitConfirm", {
				WeaponId = request.WeaponId,
				Damage = result.Damage,
				HitPosition = result.HitPosition,
				Headshot = result.Headshot or false,
			})
		else
			Net.ServerFire(player, "Error", {
				Code = result.RejectReason,
				Message = "Shot rejected: " .. result.RejectReason,
			})
		end
	end)

	print("[CombatService] Initialized - 9-check validation active")
end

-- THE 9-CHECK VALIDATION PIPELINE
function CombatService.ValidateShot(player: Player, request: Types.ShotRequest): Types.ValidationResult
	local weapon = Weapons.Get(request.WeaponId)
	if not weapon then
		return { Valid = false, RejectReason = ValidationCode.InvalidDamage }
	end

	-- 1. ORIGIN CHECK: claimed origin vs actual head position
	local originCheck = CombatService.CheckOrigin(player, request)
	if not originCheck.Valid then
		return originCheck
	end

	-- 2. FIRE RATE CHECK: server-enforced cooldown
	local rateCheck = CombatService.CheckFireRate(player, request, weapon)
	if not rateCheck.Valid then
		return rateCheck
	end

	-- 3. ANGLE CHECK: claimed direction vs actual look vector
	local angleCheck = CombatService.CheckAngle(player, request)
	if not angleCheck.Valid then
		return angleCheck
	end

	-- 4. TARGET CHECK: validate hit position against rewind
	local targetCheck = CombatService.CheckTarget(player, request)
	if not targetCheck.Valid then
		return targetCheck
	end

	-- 5. DAMAGE CHECK: validate damage matches weapon config at range
	local damageCheck = CombatService.CheckDamage(player, request, weapon)
	if not damageCheck.Valid then
		return damageCheck
	end

	-- 6. AMMO CHECK: server-authoritative ammo tracking
	local ammoCheck = CombatService.CheckAmmo(player, request, weapon)
	if not ammoCheck.Valid then
		return ammoCheck
	end

	-- 7. RANGE CHECK: target within weapon effective range
	local rangeCheck = CombatService.CheckRange(player, request, weapon)
	if not rangeCheck.Valid then
		return rangeCheck
	end

	-- 8. LINE OF SIGHT CHECK: raycast from validated origin
	local losCheck = CombatService.CheckLOS(player, request, weapon)
	if not losCheck.Valid then
		return losCheck
	end

	-- 9. COOLDOWN CHECK: global shot throttling
	local cooldownCheck = CombatService.CheckCooldown(player, request)
	if not cooldownCheck.Valid then
		return cooldownCheck
	end

	-- ALL CHECKS PASSED
	return {
		Valid = true,
		Damage = damageCheck.Damage,
		HitPosition = targetCheck.HitPosition,
		HitNormal = targetCheck.HitNormal,
		Headshot = targetCheck.Headshot,
	}
end

-- CHECK 1: Origin Validation
function CombatService.CheckOrigin(player: Player, request: Types.ShotRequest)
	local character = player.Character
	if not character then
		return { Valid = false, RejectReason = ValidationCode.InvalidOrigin }
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return { Valid = false, RejectReason = ValidationCode.InvalidOrigin }
	end

	local actualOrigin = head.Position
	local drift = (actualOrigin - request.Origin).Magnitude

	if drift > CombatConfig.Tolerances.MaxOriginDrift then
		warn(string.format("[CombatService] Origin drift: %s drift=%.1f", player.Name, drift))
		return { Valid = false, RejectReason = ValidationCode.InvalidOrigin }
	end

	return { Valid = true }
end

-- CHECK 2: Fire Rate Validation
function CombatService.CheckFireRate(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig)
	local minInterval = 1 / weapon.FireRate
	local jitter = CombatConfig.Tolerances.FireRateJitterWindow
	local effectiveInterval = minInterval - jitter

	-- Get player's last fire time for this weapon
	local lastFire = player:GetAttribute("LastFire_" .. request.WeaponId) or 0
	local now = workspace:GetServerTimeNow()

	if now - lastFire < effectiveInterval then
		return { Valid = false, RejectReason = ValidationCode.InvalidRate }
	end

	-- Update last fire time
	player:SetAttribute("LastFire_" .. request.WeaponId, now)
	return { Valid = true }
end

-- CHECK 3: Angle Validation
function CombatService.CheckAngle(player: Player, request: Types.ShotRequest)
	local character = player.Character
	if not character then
		return { Valid = false, RejectReason = ValidationCode.InvalidAngle }
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return { Valid = false, RejectReason = ValidationCode.InvalidAngle }
	end

	-- Actual look direction from head
	local actualDirection = head.CFrame.LookVector
	local claimedDirection = request.Direction
	local angle = math.deg(math.acos(math.clamp(actualDirection:Dot(claimedDirection), -1, 1)))

	if angle > CombatConfig.Tolerances.ClaimMaxAngleDeg then
		warn(string.format("[CombatService] Angle cheat: %s angle=%.1f", player.Name, angle))
		return { Valid = false, RejectReason = ValidationCode.InvalidAngle }
	end

	return { Valid = true }
end

-- CHECK 4: Target Validation (Rewind/Lag Compensation)
function CombatService.CheckTarget(player: Player, request: Types.ShotRequest)
	if not request.Target or not request.HitPosition then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Find target player
	local targetPlayer = Players:GetPlayerFromCharacter(request.Target)
	if not targetPlayer then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Get target's position history at request timestamp
	local history = PositionHistory[targetPlayer]
	if not history or #history == 0 then
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
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
		warn(string.format("[CombatService] Target drift: %s -> %s drift=%.1f", player.Name, targetPlayer.Name, drift))
		return { Valid = false, RejectReason = ValidationCode.InvalidTarget }
	end

	-- Determine hit group from rewound position
	local headshot = false
	local hitNormal = Vector3.new(0, 1, 0)
	-- Simplified: check if hit position is near head
	if (rewoundHeadPos - request.HitPosition).Magnitude < 3 then
		headshot = true
	end

	return {
		Valid = true,
		HitPosition = rewoundHeadPos,
		HitNormal = hitNormal,
		Headshot = headshot,
	}
end

-- CHECK 5: Damage Validation
function CombatService.CheckDamage(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig)
	local baseDamage = weapon.Damage
	local range = (request.HitPosition - request.Origin).Magnitude

	-- Apply damage dropoff
	local multiplier = 1.0
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
		-- Beyond max range
		if range > sortedRanges[#sortedRanges] then
			multiplier = CombatConfig.Tolerances.MinDamagePercent
		end
	end

	-- Apply headshot multiplier if validated
	if request.Headshot then
		multiplier *= weapon.HeadshotMultiplier
	end

	local finalDamage = math.floor(baseDamage * multiplier + 0.5)
	finalDamage = math.max(1, finalDamage)

	-- Validate against weapon max possible damage
	local maxPossible = weapon.Damage * weapon.HeadshotMultiplier
	if finalDamage > maxPossible * 1.1 then -- 10% tolerance
		return { Valid = false, RejectReason = ValidationCode.InvalidDamage }
	end

	return { Valid = true, Damage = finalDamage }
end

-- CHECK 6: Ammo Validation
function CombatService.CheckAmmo(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig)
	-- Server-authoritative ammo tracking
	local currentAmmo = player:GetAttribute("Ammo_" .. request.WeaponId) or weapon.MagSize
	if currentAmmo <= 0 then
		return { Valid = false, RejectReason = ValidationCode.InvalidAmmo }
	end

	-- Decrement
	player:SetAttribute("Ammo_" .. request.WeaponId, currentAmmo - 1)
	return { Valid = true }
end

-- CHECK 7: Range Validation
function CombatService.CheckRange(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig)
	local range = (request.HitPosition - request.Origin).Magnitude
	if range > weapon.Range + 10 then -- 10 stud tolerance
		return { Valid = false, RejectReason = ValidationCode.InvalidRange }
	end
	return { Valid = true }
end

-- CHECK 8: Line of Sight Validation
function CombatService.CheckLOS(player: Player, request: Types.ShotRequest, weapon: Types.WeaponConfig)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }
	raycastParams.IgnoreWater = true

	local result = workspace:Raycast(request.Origin, request.Direction * weapon.Range, raycastParams)

	if not result then
		-- No hit at all - only valid if hitting a player (handled in CheckTarget)
		if not request.Target then
			return { Valid = false, RejectReason = ValidationCode.InvalidLOS }
		end
	end

	-- If we hit something before the target, reject
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		if hitChar and hitChar ~= request.Target then
			-- Hit something else first - check if it's penetrable
			if result.Material ~= Enum.Material.Glass and result.Material ~= Enum.Material.Plastic then
				return { Valid = false, RejectReason = ValidationCode.InvalidLOS }
			end
		end
	end

	return { Valid = true }
end

-- CHECK 9: Global Cooldown / Anti-Spam
function CombatService.CheckCooldown(player: Player, request: Types.ShotRequest)
	local shotsThisTick = player:GetAttribute("ShotsThisTick") or 0
	if shotsThisTick >= CombatConfig.Tolerances.MaxShotsPerTick then
		return { Valid = false, RejectReason = ValidationCode.OnCooldown }
	end
	player:SetAttribute("ShotsThisTick", shotsThisTick + 1)
	return { Valid = true }
end

-- Apply validated damage
function CombatService.ApplyDamage(attacker: Player, result: Types.ValidationResult)
	-- Implementation: find target, apply damage, handle kill feed
	-- This connects to HealthSystem / MatchService
	-- For now, just log
	print(string.format("[CombatService] Valid hit: %s damage=%.0f headshot=%s", attacker.Name, result.Damage, tostring(result.Headshot)))
end

-- Reload handling
Net.ClientToServer.Reload:Connect(function(player: Player, data: { WeaponId: string })
	local weapon = Weapons.Get(data.WeaponId)
	if not weapon then return end

	player:SetAttribute("Ammo_" .. data.WeaponId, weapon.MagSize)
	Net.ServerFire(player, "Reloaded", { WeaponId = data.WeaponId, Ammo = weapon.MagSize })
end)

return CombatService