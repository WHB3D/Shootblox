--!strict
--[[
	SHOOTBLOX — Server-Authoritative Combat Service
	Validation pipeline per Blueprint §5.1.1/§5.1.2.
	The client predicts cosmetically and sends intent + evidence (origin,
	direction, server-clock timestamp, claimed hit); the server decides.

	Accepted misses (no Target) still pass the cheap checks and spend ammo,
	so server ammo stays truth — they just deal no damage.
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

function CombatService.SetDependencies(_deps) end

-- Pipeline constants (Blueprint §5.1.2)
local MAX_LATENCY = 0.8 -- seconds
local CLOCK_SKEW = 0.05 -- seconds a client's synced clock may lead the server's
local ORIGIN_TOLERANCE = 5 -- studs from server-known head
local HIT_TOLERANCE_BASE = 10 -- studs, + targetVelocity × latency
local INTERPOLATION_BUFFER = 0.08 -- seconds (tunable per §5.1.3)
local DIRECTION_ANGLE_TOLERANCE = 5 -- degrees
local HEADSHOT_RADIUS = 2.5 -- studs from rewound head center

local ValidationCode = {
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
}
CombatService.Codes = ValidationCode

-- Server clock (os.clock) time each player's reload finishes
local ReloadingUntil: { [Player]: number } = {}

local function reject(code: string): ValidationResult
	return { Valid = false, RejectReason = code }
end

local function isNaN(n: number): boolean
	return n ~= n
end

-- The character Model a hit instance belongs to, if it's a live combatant
-- (a player's character or a registered bot).
function CombatService.ResolveCombatant(instance: Instance?): Model?
	if not instance then
		return nil
	end
	local model: Instance? = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
			if isPlayer or model:GetAttribute("IsBot") == true then
				return model
			end
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function CombatService.Init()
	HitboxHistory.Init()
	RateLimiter.Init()

	Net.ClientToServer.Fire:Connect(function(player: Player, request: ShotRequest)
		if typeof(request) == "table" then
			CombatService.HandleFire(player, request)
		end
	end)

	Net.ClientToServer.Reload:Connect(function(player: Player, data: { WeaponId: string })
		if typeof(data) ~= "table" or typeof(data.WeaponId) ~= "string" then
			return
		end
		local weapon = Weapons.Get(data.WeaponId)
		if not weapon or (ReloadingUntil[player] or 0) > os.clock() then
			return
		end
		-- The magazine is refilled only after the weapon's reload time; shots
		-- in between are rejected by CheckAmmo
		ReloadingUntil[player] = os.clock() + weapon.ReloadTime
		task.delay(weapon.ReloadTime, function()
			ReloadingUntil[player] = nil
			if player.Parent then
				player:SetAttribute("Ammo_" .. data.WeaponId, weapon.MagSize)
				Net.ServerFire(player, "Reloaded", { WeaponId = data.WeaponId, Ammo = weapon.MagSize })
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ReloadingUntil[player] = nil
	end)

	print("[CombatService] Initialized - 11-step validation pipeline active")
end

-- One Fire remote, end to end (also driven directly by SelfTest)
function CombatService.HandleFire(player: Player, request: ShotRequest): ValidationResult
	local result = CombatService.ValidateShot(player, request)
	if result.Valid then
		if result.Damage then
			CombatService.ApplyDamage(player, result, request)
		end
	else
		local code = result.RejectReason or "UNKNOWN"
		Net.ServerFire(player, "Error", { Code = code, Message = "Shot rejected: " .. code })
	end
	return result
end

-- THE VALIDATION PIPELINE (Blueprint §5.1.1): cheap rejects first
function CombatService.ValidateShot(player: Player, request: ShotRequest): ValidationResult
	-- STEP 1: Type & shape (NaN check)
	if typeof(request.WeaponId) ~= "string" then
		return reject(ValidationCode.InvalidShape)
	end
	local weapon = Weapons.Get(request.WeaponId)
	if not weapon then
		return reject(ValidationCode.InvalidShape)
	end
	if typeof(request.Origin) ~= "Vector3" or isNaN(request.Origin.X) then
		return reject(ValidationCode.InvalidShape)
	end
	if typeof(request.Direction) ~= "Vector3" or isNaN(request.Direction.X) then
		return reject(ValidationCode.InvalidShape)
	end
	if typeof(request.Timestamp) ~= "number" or isNaN(request.Timestamp) then
		return reject(ValidationCode.InvalidShape)
	end

	-- STEP 2: State — alive, has a head
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return reject(ValidationCode.InvalidState)
	end
	-- ...and actually holding the weapon it claims to fire
	local held = character and character:FindFirstChildOfClass("Tool")
	if not held or held:GetAttribute("WeaponId") ~= request.WeaponId then
		return reject(ValidationCode.InvalidState)
	end

	-- STEP 3: Rate of fire (time since last ACCEPTED shot)
	if not RateLimiter.CheckShot(player, request.WeaponId, weapon.FireRate, request.Timestamp) then
		return reject(ValidationCode.InvalidRate)
	end

	-- STEP 4: Timestamp window (client must stamp with GetServerTimeNow; its
	-- synced estimate can run a few ms ahead of the server's)
	local latency = workspace:GetServerTimeNow() - request.Timestamp
	if latency < -CLOCK_SKEW or latency > MAX_LATENCY then
		return reject(ValidationCode.InvalidTimestamp)
	end
	latency = math.max(latency, 0)

	-- STEP 5: Origin sanity (≤ 5 studs from server-known head)
	local originDrift = (request.Origin - head.Position).Magnitude
	if originDrift > ORIGIN_TOLERANCE then
		CombatService.FlagSuspicion(player, "ORIGIN_MISMATCH", { Drift = originDrift })
		return reject(ValidationCode.InvalidOrigin)
	end

	-- A miss: valid, spends ammo, no damage
	if request.Target == nil then
		local ammo = CombatService.CheckAmmo(player, request, weapon)
		if not ammo.Valid then
			return ammo
		end
		RateLimiter.RecordShot(player, request.WeaponId, weapon.FireRate, request.Timestamp)
		return { Valid = true }
	end

	local claimedHit = request.HitPosition
	if typeof(claimedHit) ~= "Vector3" or isNaN(claimedHit.X) then
		return reject(ValidationCode.InvalidShape)
	end

	-- STEP 6: Direction sanity (reported direction vs muzzle → claimed hit)
	local toHit = (claimedHit - request.Origin).Unit
	local angle = math.deg(math.acos(math.clamp(request.Direction.Unit:Dot(toHit), -1, 1)))
	if angle > DIRECTION_ANGLE_TOLERANCE then
		CombatService.FlagSuspicion(player, "DIRECTION_MISMATCH", { Angle = angle })
		return reject(ValidationCode.InvalidDirection)
	end

	-- STEP 7: Hit validation against the rewound target
	local target = CombatService.ValidateTarget(player, request, weapon, latency)
	if not target.Valid then
		return target
	end
	local targetModel = CombatService.ResolveCombatant(request.Target) :: Model

	-- STEP 8: Range
	local range = (claimedHit - request.Origin).Magnitude
	if range > weapon.Range then
		return reject(ValidationCode.InvalidRange)
	end

	-- STEP 9: Line of sight to the claimed hit point
	local los = CombatService.CheckLOS(player, request.Origin, claimedHit, targetModel)
	if not los.Valid then
		return los
	end

	-- STEP 10: Damage
	local damage = CombatService.CalculateDamage(weapon, range, target.Headshot == true)
	if not damage.Valid then
		return damage
	end

	-- STEP 11: Ammo (server-authoritative)
	local ammo = CombatService.CheckAmmo(player, request, weapon)
	if not ammo.Valid then
		return ammo
	end

	RateLimiter.RecordShot(player, request.WeaponId, weapon.FireRate, request.Timestamp)
	return {
		Valid = true,
		Damage = damage.Damage,
		HitPosition = claimedHit,
		HitNormal = target.HitNormal,
		Headshot = target.Headshot,
	}
end

-- STEP 7: rewind the target to what the shooter saw and compare
function CombatService.ValidateTarget(
	player: Player,
	request: ShotRequest,
	weapon: WeaponConfig,
	latency: number
): ValidationResult
	local targetModel = CombatService.ResolveCombatant(request.Target)
	local claimedHit = request.HitPosition
	if not targetModel or not claimedHit or targetModel == player.Character then
		return reject(ValidationCode.InvalidTarget)
	end
	local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return reject(ValidationCode.InvalidTarget)
	end

	-- Favor the shooter: rewind to when they saw the target
	local rewindTime = request.Timestamp - (player:GetNetworkPing() + INTERPOLATION_BUFFER)
	local rewound = HitboxHistory.RewindTo(targetModel, rewindTime)
	if not rewound then
		return reject(ValidationCode.InvalidTarget)
	end

	-- Distance from the claimed hit to the claimed part (or the nearest part)
	local claimedPart = request.HitPart
	local partCF = if typeof(claimedPart) == "string" then rewound[claimedPart] else nil
	local drift = math.huge
	if partCF then
		drift = (partCF.Position - claimedHit).Magnitude
	else
		for _, cf in rewound do
			drift = math.min(drift, (cf.Position - claimedHit).Magnitude)
		end
	end

	local targetVelocity = 0
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
	if targetRoot and targetRoot:IsA("BasePart") then
		targetVelocity = targetRoot.AssemblyLinearVelocity.Magnitude
	end
	local tolerance = HIT_TOLERANCE_BASE + targetVelocity * latency
	if drift > tolerance then
		CombatService.FlagSuspicion(player, "HIT_MISMATCH", { Drift = drift, Tolerance = tolerance })
		return reject(ValidationCode.InvalidTarget)
	end

	-- Body-blocking: the server's own ray must not hit a different combatant first
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any }
	local ray = workspace:Raycast(request.Origin, request.Direction.Unit * weapon.Range, params)
	if ray then
		local blocker = CombatService.ResolveCombatant(ray.Instance)
		if blocker and blocker ~= targetModel then
			return reject(ValidationCode.InvalidTarget)
		end
	end

	local rewoundHead: CFrame? = rewound["Head"]
	local headshot = claimedPart == "Head"
		and rewoundHead ~= nil
		and (rewoundHead.Position - claimedHit).Magnitude <= HEADSHOT_RADIUS

	return {
		Valid = true,
		HitPosition = claimedHit,
		HitNormal = if ray then ray.Normal else Vector3.yAxis,
		Headshot = headshot,
	}
end

-- STEP 9: no map geometry between muzzle and hit point. Only Glass is
-- penetrable for now (Plastic is every Part's default — it can't be).
function CombatService.CheckLOS(
	player: Player,
	origin: Vector3,
	hitPosition: Vector3,
	targetModel: Model
): ValidationResult
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, hitPosition - origin, params)
	if result and not result.Instance:IsDescendantOf(targetModel) then
		if result.Material ~= Enum.Material.Glass then
			CombatService.FlagSuspicion(player, "WALL_BLOCKED", {
				Part = result.Instance:GetFullName(),
				Material = tostring(result.Material),
			})
			return reject(ValidationCode.InvalidLOS)
		end
	end
	return { Valid = true }
end

-- STEP 10: falloff brackets read as "from this range onward"
function CombatService.CalculateDamage(weapon: WeaponConfig, range: number, headshot: boolean): ValidationResult
	local multiplier = 1.0
	local dropoff = weapon.DamageDropoff
	if dropoff then
		local bestKey = -1
		for r, mult in dropoff do
			if r <= range and r > bestKey then
				bestKey, multiplier = r, mult
			end
		end
	end
	multiplier = math.max(multiplier, CombatConfig.Tolerances.MinDamagePercent)

	if headshot then
		multiplier *= weapon.HeadshotMultiplier
	end

	local finalDamage = math.max(1, math.floor(weapon.Damage * multiplier + 0.5))
	if finalDamage > weapon.Damage * weapon.HeadshotMultiplier * 1.1 then
		return reject(ValidationCode.InvalidDamage)
	end
	return { Valid = true, Damage = finalDamage }
end

-- STEP 11: ammo lives on a player attribute (set by WeaponService)
function CombatService.CheckAmmo(player: Player, request: ShotRequest, weapon: WeaponConfig): ValidationResult
	if (ReloadingUntil[player] or 0) > os.clock() then
		return reject(ValidationCode.InvalidAmmo)
	end
	local stored = player:GetAttribute("Ammo_" .. request.WeaponId)
	local currentAmmo = if typeof(stored) == "number" then stored else weapon.MagSize
	if currentAmmo <= 0 then
		return reject(ValidationCode.InvalidAmmo)
	end
	player:SetAttribute("Ammo_" .. request.WeaponId, currentAmmo - 1)
	return { Valid = true }
end

function CombatService.ApplyDamage(attacker: Player, result: ValidationResult, request: ShotRequest)
	local targetChar = CombatService.ResolveCombatant(request.Target)
	local damage = result.Damage
	if not targetChar or not damage then
		return
	end
	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local headshot = result.Headshot == true

	humanoid:TakeDamage(damage)

	Net.ServerFire(attacker, "HitConfirm", {
		WeaponId = request.WeaponId,
		Damage = damage,
		HitPosition = result.HitPosition,
		Headshot = headshot,
	})

	local victim = Players:GetPlayerFromCharacter(targetChar)
	if victim then
		Net.ServerFire(victim, "HealthUpdate", { Current = humanoid.Health, Max = humanoid.MaxHealth })
	end

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

function CombatService.FlagSuspicion(player: Player, reason: string, details: { [string]: any })
	local parts = {}
	for k, v in details do
		table.insert(parts, k .. "=" .. tostring(v))
	end
	warn(string.format("[CombatService] Suspicion: %s - %s (%s)", player.Name, reason, table.concat(parts, ", ")))
end

return CombatService
