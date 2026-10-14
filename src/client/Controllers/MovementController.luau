--!strict
--[[
	SHOOTBLOX — Client Movement Controller
	Mobile-native: auto-sprint, auto-slide, auto-vault, swipe gestures.
	Server-authoritative: sends input intent, server validates.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Config.Movement)
local Net = require(ReplicatedStorage.Shared.Net)

local MovementController = {}

local player = Players.LocalPlayer
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?

-- State
local currentState = "Idle"
local moveDirection = Vector3.zero
local isSprinting = false
local isCrouching = false
local isSliding = false
local slideStartTime = 0
local slideVelocity = Vector3.zero
local lastCrouchTime = 0
local lastSlideTime = 0
local vaultCooldown = 0
local autoSprintTimer = 0
local touchStartPos: Vector2?

-- Touch input tracking
local activeTouches = {}

function MovementController.Init()
	player.CharacterAdded:Connect(MovementController.OnCharacterAdded)
	if player.Character then
		MovementController.OnCharacterAdded(player.Character)
	end

	MovementController.BindInputs()

	if UserInputService.TouchEnabled then
		MovementController.BindTouchInputs()
	end

	task.spawn(function()
		while true do
			task.wait(1/30)
			if character and humanoid then
				MovementController.SendInputState()
			end
		end
	end)

	print("[MovementController] Initialized")
end

function MovementController.OnCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")

	humanoid.WalkSpeed = MovementConfig.Base.WalkSpeed
	humanoid.JumpPower = MovementConfig.Base.JumpPower
	humanoid.AutoRotate = true

	humanoid.StateChanged:Connect(function(_, newState)
		MovementController.OnStateChanged(newState)
	end)

	currentState = "Idle"
	isSprinting = false
	isCrouching = false
	isSliding = false
end

function MovementController.BindInputs()
	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			MovementController.SetSprinting(true)
		elseif state == Enum.UserInputState.End then
			MovementController.SetSprinting(false)
		end
	end, false, Enum.KeyCode.LeftShift)

	ContextActionService:BindAction("Crouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			MovementController.SetCrouching(true)
		elseif state == Enum.UserInputState.End then
			MovementController.SetCrouching(false)
		end
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl)

	ContextActionService:BindAction("Jump", function(_, state)
		if state == Enum.UserInputState.Begin then
			MovementController.TryJump()
		end
	end, false, Enum.KeyCode.Space)

	ContextActionService:BindAction("Slide", function(_, state)
		if state == Enum.UserInputState.Begin then
			MovementController.TrySlide()
		end
	end, false, Enum.KeyCode.C)

	RunService.RenderStepped:Connect(function()
		MovementController.UpdateMovementInput()
	end)
end

function MovementController.BindTouchInputs()
	UserInputService.TouchStarted:Connect(function(touch, processed)
		if processed then return end
		activeTouches[touch] = tick()
		touchStartPos = touch.Position
	end)

	UserInputService.TouchMoved:Connect(function(touch, processed)
		if processed then return end
		if activeTouches[touch] then
			local delta = touch.Position - (touchStartPos or touch.Position)
			if delta.Magnitude > MovementConfig.MobileAssist.SwipeThreshold then
				MovementController.HandleSwipe(delta)
				activeTouches[touch] = nil
			end
		end
	end)

	UserInputService.TouchEnded:Connect(function(touch, processed)
		activeTouches[touch] = nil
	end)
end

function MovementController.HandleSwipe(delta: Vector2)
	if delta.Y < -MovementConfig.MobileAssist.SwipeThreshold then
		MovementController.TryJump()
	elseif delta.Y > MovementConfig.MobileAssist.SwipeThreshold then
		if isSprinting then
			MovementController.TrySlide()
		else
			MovementController.SetCrouching(true)
		end
	end
end

function MovementController.UpdateMovementInput()
	if not humanoid or not rootPart then return end

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude > 0 then
		moveDirection = moveDir
	else
		moveDirection = Vector3.zero
	end

	if MovementConfig.MobileAssist.AutoSprint and UserInputService.TouchEnabled then
		if moveDirection.Magnitude > 0 then
			autoSprintTimer += 1/60
			if autoSprintTimer > 0.5 and not isSprinting then
				MovementController.SetSprinting(true)
			end
		else
			autoSprintTimer = 0
			MovementController.SetSprinting(false)
		end
	end

	if MovementConfig.MobileAssist.AutoCrouchSlide and isCrouching and isSprinting and not isSliding then
		MovementController.TrySlide()
	end

	if MovementConfig.MobileAssist.AutoVault and moveDirection.Magnitude > 0 then
		MovementController.CheckVault()
	end

	MovementController.UpdateState()
end

function MovementController.SetSprinting(sprinting: boolean)
	if not humanoid then return end
	isSprinting = sprinting
	humanoid.WalkSpeed = sprinting and MovementConfig.Base.SprintSpeed or MovementConfig.Base.WalkSpeed
end

function MovementController.SetCrouching(crouching: boolean)
	if not humanoid or not rootPart then return end
	isCrouching = crouching

	if crouching then
		humanoid.WalkSpeed = MovementConfig.Base.CrouchWalkSpeed
	else
		humanoid.WalkSpeed = isSprinting and MovementConfig.Base.SprintSpeed or MovementConfig.Base.WalkSpeed
	end
	lastCrouchTime = tick()
end

function MovementController.TryJump()
	if not humanoid or not rootPart then return end
	if humanoid:GetState() == Enum.HumanoidStateType.Jumping then return end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then return end

	if MovementController.CheckVault() then
		return
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

function MovementController.TrySlide()
	if not humanoid or not rootPart then return end
	if isSliding then return end
	if not isSprinting then return end
	if tick() - lastSlideTime < MovementConfig.Slide.Cooldown then return end

	if moveDirection.Magnitude < 0.1 then return end

	isSliding = true
	lastSlideTime = tick()
	slideStartTime = tick()

	slideVelocity = moveDirection * MovementConfig.Slide.Speed
	if isCrouching then
		slideVelocity *= MovementConfig.Slide.CrouchSlideBonus
	end

	rootPart.AssemblyLinearVelocity = Vector3.new(slideVelocity.X, rootPart.AssemblyLinearVelocity.Y, slideVelocity.Z)

	MovementController.PlayAnimation("Slide")

	task.delay(MovementConfig.Slide.Duration, function()
		if isSliding then
			MovementController.EndSlide()
		end
	end)
end

function MovementController.EndSlide()
	isSliding = false
	slideVelocity = Vector3.zero
	MovementController.PlayAnimation("SlideEnd")
end

function MovementController.CheckVault(): boolean
	if not humanoid or not rootPart then return false end
	if tick() - vaultCooldown < MovementConfig.Vault.Cooldown then return false end
	if moveDirection.Magnitude < MovementConfig.Vault.MinApproachSpeed then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(rootPart.Position, moveDirection * MovementConfig.Vault.MaxDistance, params)
	if not result then return false end

	local height = result.Position.Y - rootPart.Position.Y
	if height > MovementConfig.Vault.MaxHeight then return false end
	if height < 1 then return false end

	vaultCooldown = tick()
	MovementController.DoVault(result)
	return true
end

function MovementController.DoVault(result: RaycastResult)
	MovementController.PlayAnimation("Vault")

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Velocity = moveDirection * 20 + Vector3.new(0, 30, 0)
	bodyVelocity.Parent = rootPart

	game:GetService("Debris"):AddItem(bodyVelocity, MovementConfig.Vault.Duration)

	task.delay(MovementConfig.Vault.Duration, function()
		if humanoid then
			humanoid.WalkSpeed = isSprinting and MovementConfig.Base.SprintSpeed or MovementConfig.Base.WalkSpeed
			humanoid.JumpPower = MovementConfig.Base.JumpPower
		end
	end)
end

function MovementController.OnStateChanged(newState: Enum.HumanoidStateType)
	local stateMap = {
		[Enum.HumanoidStateType.Jumping] = "Jumping",
		[Enum.HumanoidStateType.Freefall] = "Falling",
		[Enum.HumanoidStateType.Landed] = "Idle",
		[Enum.HumanoidStateType.Running] = isSprinting and "Sprinting" or "Walking",
		[Enum.HumanoidStateType.RunningNoPhysics] = isSprinting and "Sprinting" or "Walking",
	}

	currentState = stateMap[newState] or "Idle"
end

function MovementController.UpdateState()
	if isSliding then
		currentState = "Sliding"
		slideVelocity *= MovementConfig.Slide.MomentumPreservation
		rootPart.AssemblyLinearVelocity = Vector3.new(slideVelocity.X, rootPart.AssemblyLinearVelocity.Y, slideVelocity.Z)

		if slideVelocity.Magnitude < 5 then
			MovementController.EndSlide()
		end
	elseif moveDirection.Magnitude > 0 then
		if isSprinting then
			currentState = "Sprinting"
		elseif isCrouching then
			currentState = "CrouchWalking"
		else
			currentState = "Walking"
		end
	elseif isCrouching then
		currentState = "Crouching"
	else
		currentState = "Idle"
	end
end

function MovementController.SendInputState()
	Net.ClientFire("MovementInput", {
		State = currentState,
		MoveDirection = moveDirection,
		IsSprinting = isSprinting,
		IsCrouching = isCrouching,
		IsSliding = isSliding,
		SlideVelocity = slideVelocity,
		Timestamp = workspace:GetServerTimeNow(),
	})
end

function MovementController.PlayAnimation(name: string)

end

return MovementController