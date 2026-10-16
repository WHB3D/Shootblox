--!strict
--[[
	SHOOTBLOX — Server Movement Validation
	Validates client movement input, prevents speed hacks, teleport exploits.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Config.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local PerfMonitor = require(script.Parent.PerfMonitor)

local MovementService = {}

function MovementService.SetDependencies(deps)
	-- Store dependencies if needed
end

-- Track last known good state per player
local PlayerMovementState: {
	[Player]: {
		Position: Vector3,
		Velocity: Vector3,
		State: string,
		LastUpdate: number,
		Sprinting: boolean,
		Crouching: boolean,
		Sliding: boolean,
		SlideVelocity: Vector3,
	},
} =
	{}

-- Validation tolerances
local TOLERANCE = {
	MaxPositionDrift = 6, -- studs per 30Hz update
	MaxVelocity = 30, -- studs/sec max legitimate
	MaxSlideSpeed = 35,
	MaxTeleportDistance = 15,
	UpdateInterval = 1 / 30, -- 30Hz
}

function MovementService.Init()
	Net.ClientToServer.MovementInput:Connect(function(
		player: Player,
		data: {
			State: string,
			MoveDirection: Vector3,
			IsSprinting: boolean,
			IsCrouching: boolean,
			IsSliding: boolean,
			SlideVelocity: Vector3,
			Timestamp: number,
		}
	)
		MovementService.ValidateInput(player, data)
	end)

	-- Periodic position validation
	RunService.Heartbeat:Connect(PerfMonitor.Track("MovementService", function(dt)
		MovementService.ValidatePositions(dt)
	end))

	print("[MovementService] Initialized")
end

function MovementService.ValidateInput(player: Player, data: any)
	-- Basic structure validation
	if not data.State or not data.MoveDirection then
		Net.ServerFire(player, "Error", { Code = "INVALID_MOVEMENT_INPUT", Message = "Missing required fields" })
		return
	end

	-- Validate state enum
	local validStates = {
		Idle = true,
		Walking = true,
		Sprinting = true,
		Crouching = true,
		CrouchWalking = true,
		Sliding = true,
		Jumping = true,
		Falling = true,
		Vaulting = true,
	}
	if not validStates[data.State] then
		Net.ServerFire(
			player,
			"Error",
			{ Code = "INVALID_MOVEMENT_STATE", Message = "Invalid state: " .. tostring(data.State) }
		)
		return
	end

	-- Validate move direction magnitude
	if data.MoveDirection.Magnitude > 1.01 then
		Net.ServerFire(player, "Error", { Code = "INVALID_MOVE_DIRECTION", Message = "Move direction not normalized" })
		return
	end

	-- Store validated input
	local state = PlayerMovementState[player]
	if not state then
		state = {
			Position = Vector3.zero,
			Velocity = Vector3.zero,
			State = "Idle",
			LastUpdate = workspace:GetServerTimeNow(),
			Sprinting = false,
			Crouching = false,
			Sliding = false,
			SlideVelocity = Vector3.zero,
		}
		PlayerMovementState[player] = state
	end

	state.State = data.State
	state.Sprinting = data.IsSprinting
	state.Crouching = data.IsCrouching
	state.Sliding = data.IsSliding
	state.SlideVelocity = data.SlideVelocity
	state.LastUpdate = data.Timestamp

	-- Forward to other systems (combat, match, etc.)
	-- Net.Broadcast("PlayerMovementUpdate", player, data)
end

function MovementService.ValidatePositions(dt: number)
	for player, state in PlayerMovementState do
		local character = player.Character
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootPart or not rootPart:IsA("BasePart") or not humanoid then
			continue
		end

		-- Skip if dead
		if humanoid.Health <= 0 then
			continue
		end

		local actualPos = rootPart.Position
		local actualVel = rootPart.AssemblyLinearVelocity

		-- Predict position based on last known input
		local predictedPos = state.Position + state.Velocity * dt

		-- Check position drift
		local drift = (actualPos - predictedPos).Magnitude
		if drift > TOLERANCE.MaxPositionDrift + (dt * 10) then
			-- Position mismatch - potential teleport/speed hack
			MovementService.FlagSuspicious(player, "PositionDrift", {
				Actual = actualPos,
				Predicted = predictedPos,
				Drift = drift,
			})
		end

		-- Check velocity
		local speed = actualVel.Magnitude
		local maxAllowed = MovementConfig.Base.WalkSpeed
		if state.Sprinting then
			maxAllowed = MovementConfig.Base.SprintSpeed
		end
		if state.Sliding then
			maxAllowed = TOLERANCE.MaxSlideSpeed
		end

		if speed > maxAllowed + 5 then -- 5 studs tolerance
			MovementService.FlagSuspicious(player, "ExcessiveSpeed", {
				Speed = speed,
				MaxAllowed = maxAllowed,
				State = state.State,
			})
		end

		-- Update stored state
		state.Position = actualPos
		state.Velocity = actualVel
	end
end

function MovementService.FlagSuspicious(player: Player, reason: string, details: any)
	warn(string.format("[MovementService] Suspicious: %s - %s (%s)", player.Name, reason, details))
	-- Could integrate with strike system here
	-- DataService.AddStrike(player, "Movement: " .. reason)
end

function MovementService.GetPlayerState(player: Player)
	return PlayerMovementState[player]
end

function MovementService.CleanupPlayer(player: Player)
	PlayerMovementState[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	MovementService.CleanupPlayer(player)
end)

return MovementService
