--!strict
--[[
	SHOOTBLOX — Viewmodel Controller (Blueprint §6.1)
	Camera-parented rig, ordered offset composition (base/ADS → sway → bob →
	recoil), spring-driven sway and recoil, split camera/viewmodel recoil.

	Driven by RunService:BindToRenderStep at Camera priority + 1 — one tick
	after Roblox's own camera update, every frame. Updating at or before
	Camera priority is the classic "gun swims" bug: one frame of lag between
	where the camera is and where the viewmodel renders. The root CFrame is
	ALSO never lerped as a whole (that was the previous bug here — lerping
	camera.CFrame * offsets compounds smoothing on top of the offset chain's
	own springs/lerps, so the gun visibly trails the camera). Every frame:
	viewmodelRoot.CFrame = camera.CFrame * offsetChain, full stop; all
	smoothing happens inside the chain, not on top of it.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local Spring = require(ReplicatedStorage.Shared.Spring)

local ViewmodelController = {}

local camera = workspace.CurrentCamera

local COLLISION_GROUP = "NoCollisionViewModel"
local ok = pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
end)
if ok then
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", false)
end

-- Viewmodel components (created in Init; nil until then)
local viewmodel: Model
local viewmodelRoot: BasePart
local weaponModel: Model?
local currentWeapon: string?
local currentWeaponConfig: any?

-- ADS state
local isADS = false
local isReloading = false -- trap (§6.1.2#1): reload motion must not transfer into ADS wobble
local adsProgress = 0
local DEFAULT_ADS_SPEED = 25 -- frame-scaled lerp constant; high = reads as "instant"

-- Sway: mouse-delta spring (§6.1.1), critically damped — no overshoot
local swaySpring = Spring.new(1, 90, 10, 1)

-- Recoil: split into a viewmodel kickback spring (+ backward-push
-- accumulator) and a separate camera-kick spring, both under-damped so they
-- bounce; recovery only "starts" once shots (shoves) stop landing.
local recoilSpring = Spring.new(3, 120, 4, 10)
local recoilAmount = 0
local cameraKickSpring = Spring.new(2, 100, 5, 10)
local shotsSinceReset = 0 -- indexes into RecoilPattern; reset per weapon equip

local bobCycle = 0

-- Offsets. HIP_OFFSET/ADS_OFFSET stand in for "idle CFrameValue" and
-- "AimPart weld" until real weapon models exist to anchor an actual AimPart
-- to; a per-weapon ViewModelOffset already overrides ADS_OFFSET below.
local HIP_OFFSET = CFrame.new(1.2, -0.8, 1.5)
local ADS_OFFSET = CFrame.new(0, -0.2, 0.5)

-- FOV: two simultaneous lerps per §6.1.2 (viewmodel offset above, camera FOV
-- here), both driven by the same adsProgress so they land in lockstep.
local BASE_FOV = 70
local DEFAULT_ZOOM_FOV = 55
local fovKick = 0 -- 1-2 degree punch per shot on automatics, decays per frame

function ViewmodelController.Init()
	viewmodel = Instance.new("Model")
	viewmodel.Name = "Viewmodel"
	viewmodel.Parent = camera

	viewmodelRoot = Instance.new("Part")
	viewmodelRoot.Name = "Root"
	viewmodelRoot.Transparency = 1
	viewmodelRoot.Anchored = true
	viewmodelRoot.CanCollide = false
	viewmodelRoot.CanQuery = false
	viewmodelRoot.CastShadow = false
	viewmodelRoot.CollisionGroup = COLLISION_GROUP
	viewmodelRoot.Massless = true
	viewmodelRoot.Size = Vector3.new(0.1, 0.1, 0.1)
	viewmodelRoot.CFrame = camera.CFrame
	viewmodelRoot.Parent = viewmodel

	Net.ClientListen("WeaponEquipped", function(data: { WeaponId: string, Slot: string })
		ViewmodelController.EquipWeapon(data.WeaponId)
	end)

	Net.ClientListen("WeaponUnequipped", function(data: { Slot: string })
		ViewmodelController.UnequipWeapon()
	end)

	game:GetService("ContextActionService"):BindAction("ADS", function(_, state)
		if state == Enum.UserInputState.Begin then
			ViewmodelController.SetADS(true)
		elseif state == Enum.UserInputState.End then
			ViewmodelController.SetADS(false)
		end
	end, false, Enum.KeyCode.RightShift, Enum.UserInputType.MouseButton2)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local delta = input.Delta
		swaySpring:shove(Vector3.new(-delta.X / 500, delta.Y / 200, 0))
	end)

	RunService:BindToRenderStep("ShootbloxViewmodel", Enum.RenderPriority.Camera.Value + 1, ViewmodelController.Update)

	print("[ViewmodelController] Initialized")
end

function ViewmodelController.EquipWeapon(weaponId: string)
	ViewmodelController.UnequipWeapon()

	currentWeapon = weaponId
	currentWeaponConfig = Weapons.Get(weaponId)

	if not currentWeaponConfig then
		warn("[ViewmodelController] Unknown weapon: " .. weaponId)
		return
	end

	-- TODO: Load viewmodel model from ReplicatedStorage
	-- For now, create a placeholder
	local model = Instance.new("Model")
	model.Name = "Weapon_" .. weaponId
	model.Parent = viewmodel

	-- Create a simple visual placeholder
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 2)
	handle.Color = Color3.fromRGB(60, 60, 60)
	handle.Material = Enum.Material.Metal
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CastShadow = false
	handle.CollisionGroup = COLLISION_GROUP
	handle.Massless = true
	handle.CFrame = viewmodelRoot.CFrame * HIP_OFFSET
	handle.Parent = model
	model.PrimaryPart = handle

	weaponModel = model

	print("[ViewmodelController] Equipped " .. weaponId)
end

function ViewmodelController.UnequipWeapon()
	if weaponModel then
		weaponModel:Destroy()
		weaponModel = nil
	end
	currentWeapon = nil
	currentWeaponConfig = nil
	isADS = false
	isReloading = false
	adsProgress = 0
	shotsSinceReset = 0
end

function ViewmodelController.SetADS(ads: boolean)
	if not currentWeapon then
		return
	end
	isADS = ads
end

-- GunController calls this around Net "Reload"/"Reloaded": ADS is forced to
-- the hip position for the duration so reload motion (once real reload
-- animations exist) can never read as camera wobble while aiming.
function ViewmodelController.SetReloading(reloading: boolean)
	isReloading = reloading
end

function ViewmodelController.Update(dt: number)
	if not viewmodel or not viewmodelRoot or not camera then
		return
	end
	if not currentWeapon or not currentWeaponConfig then
		return
	end

	-- ADS: frame-scaled alpha, not a fixed lerp factor, so speed doesn't
	-- vary with framerate. Suppressed to 0 while reloading (trap §6.1.2#1).
	local adsSpeed = currentWeaponConfig.ADSSpeed or DEFAULT_ADS_SPEED
	local targetProgress = (isADS and not isReloading) and 1 or 0
	local adsAlpha = 1 - math.exp(-adsSpeed * dt)
	adsProgress += (targetProgress - adsProgress) * adsAlpha

	local adsOffset = currentWeaponConfig.ViewModelOffset or ADS_OFFSET
	local aimCF = HIP_OFFSET:Lerp(adsOffset, adsProgress)

	-- Ordered offset array (§6.1.1): base/ADS → sway → bob → recoil. An
	-- array, not a dict — pairs()-order is undefined and recoil must apply
	-- after sway.
	local swaySuppression = 1 - adsProgress * 0.85
	local sway = swaySpring:update(dt) * swaySuppression
	local swayCF = CFrame.Angles(sway.Y, sway.X, 0)

	local bobCF = ViewmodelController.CalculateBob(dt)

	local recoil = recoilSpring:update(dt)
	recoilAmount *= math.exp(-15 * dt)
	local recoilCF = CFrame.Angles(recoil.X, recoil.Y, 0) * CFrame.new(0, 0, recoilAmount * 0.05)

	local offsets: { CFrame } = { aimCF, swayCF, bobCF, recoilCF }
	local chain = CFrame.identity
	for _, offset in offsets do
		chain *= offset
	end

	-- Position pinned exactly to the camera every frame; every smoothing
	-- step already lives inside `chain` (springs/ADS lerp) — lerping this
	-- top-level CFrame on top of that is the "gun swims" bug.
	viewmodelRoot.CFrame = camera.CFrame * chain
	if weaponModel then
		weaponModel:PivotTo(viewmodelRoot.CFrame)
	end

	-- Camera kick: a second, independent spring nudges the live camera
	-- CFrame after Roblox's own update (same Camera+1 priority tick), never
	-- touching position — only a small rotational punch that the spring
	-- recovers from once shots stop landing.
	local cameraKick = cameraKickSpring:update(dt)
	if cameraKick.Magnitude > 1e-5 then
		camera.CFrame *= CFrame.Angles(cameraKick.X, cameraKick.Y, 0)
	end

	-- FOV: ADS zoom lerp (same adsProgress as the viewmodel offset above)
	-- plus a small decaying per-shot punch on top.
	fovKick *= math.exp(-10 * dt)
	local zoomFov = currentWeaponConfig.ZoomFOV or DEFAULT_ZOOM_FOV
	camera.FieldOfView = BASE_FOV + (zoomFov - BASE_FOV) * adsProgress + fovKick
end

-- 0 (hip) .. 1 (fully aimed); GunController uses this to fold ADS into the
-- live spread-bloom readout.
function ViewmodelController.GetADSProgress(): number
	return adsProgress
end

-- Local character's Humanoid + root, or nil if not spawned
local function getLocalRig(): (Humanoid?, BasePart?)
	local character = game:GetService("Players").LocalPlayer.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and not rootPart:IsA("BasePart") then
		rootPart = nil
	end
	return humanoid, rootPart :: BasePart?
end

function ViewmodelController.CalculateBob(dt: number): CFrame
	local humanoid, rootPart = getLocalRig()

	if not humanoid or not rootPart then
		return CFrame.identity
	end

	local moveDir = humanoid.MoveDirection
	local moveSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	local isMoving = moveDir.Magnitude > 0.1

	if isMoving then
		bobCycle += dt * (moveSpeed / 6)

		local bobX = math.sin(bobCycle) * 0.03 * (moveSpeed / 20)
		local bobY = math.abs(math.sin(bobCycle * 2)) * 0.02 * (moveSpeed / 20)

		-- Reduce bob when ADS
		local adsMult = 1 - adsProgress * 0.7
		bobX *= adsMult
		bobY *= adsMult

		return CFrame.new(bobX, bobY, 0)
	end

	return CFrame.identity
end

-- GunController calls this on every accepted shot. recoilPattern cycles
-- through the weapon's stages (one per shot since the last reset) rather
-- than always reading stage 1, so sustained fire climbs the pattern.
function ViewmodelController.ApplyRecoil(recoilPattern: { Vector2 }?)
	if not recoilPattern or #recoilPattern == 0 then
		return
	end
	shotsSinceReset += 1
	local stage = recoilPattern[math.min(shotsSinceReset, #recoilPattern)]
	local pitch = math.rad(-stage.Y * 0.5) -- up
	local yaw = math.rad(stage.X * 0.3) -- side

	recoilSpring:shove(Vector3.new(pitch, yaw, 0))
	cameraKickSpring:shove(Vector3.new(pitch * 1.5, yaw * 1.5, 0))
	recoilAmount = math.min(recoilAmount + 1, 10)
	fovKick = math.min(fovKick + 1.5, 6) -- §6.1.2: 1-2 deg FOV punch per shot, caps under sustained fire
end

function ViewmodelController.ResetRecoil()
	shotsSinceReset = 0
end

return ViewmodelController
