--!strict
--[[
	SHOOTBLOX — Movement Configuration (Mobile-native from Day 1)
	Pure data: no Roblox globals.
]]

local Movement = {}

-- Base movement constants
Movement.Base = {
	WalkSpeed = 16,
	SprintSpeed = 22,
	CrouchWalkSpeed = 8,
	JumpPower = 50,
	JumpHeight = 7.5,
	Gravity = 196.2,
}

-- Slide parameters
Movement.Slide = {
	Enabled = true,
	Speed = 28, -- initial slide velocity
	Duration = 1.2, -- seconds
	Cooldown = 1.5, -- seconds
	CrouchSlideBonus = 1.2, -- speed multiplier when sliding from crouch
	MomentumPreservation = 0.85, -- per-tick velocity retention
	MinSlopeAngle = 5, -- degrees, minimum slope to auto-slide
	MaxSlopeAngle = 45, -- degrees, max slope for slide
}

-- Crouch parameters
Movement.Crouch = {
	Enabled = true,
	SpeedMultiplier = 0.5,
	HeightMultiplier = 0.6,
	TransitionTime = 0.15, -- seconds
	HeadOffset = Vector3.new(0, -2, 0),
}

-- Vault/Mantle parameters
Movement.Vault = {
	Enabled = true,
	MaxHeight = 5, -- studs
	MaxDistance = 3, -- studs
	Duration = 0.5, -- seconds
	Cooldown = 0.5,
	MinApproachSpeed = 8, -- studs/sec
}

-- Wall-run parameters (mobile: auto-wallrun)
Movement.WallRun = {
	Enabled = true,
	MaxDuration = 2, -- seconds
	MinSpeed = 16,
	PushForce = 50,
	GraceTime = 0.15,
}

-- Ledge grab (manual on mobile, auto on PC)
Movement.LedgeGrab = {
	Enabled = true,
	MaxReach = 4, -- studs
	MinHeight = 2, -- studs above feet
	PullUpDuration = 0.4,
}

-- Mobile-specific assist
Movement.MobileAssist = {
	AutoSprint = true, -- auto-sprint when moving forward > 0.5s
	AutoCrouchSlide = true, -- crouch + sprint = slide
	AutoVault = true, -- auto-vault low obstacles
	AutoWallRun = true, -- auto-detect wall run
	TouchDeadzone = 0.15, -- joystick deadzone
	SwipeThreshold = 50, -- pixels for swipe gestures
}

-- Animation names (server-authoritative, client plays)
Movement.Animations = {
	Idle = "rbxassetid://0",
	Walk = "rbxassetid://0",
	Run = "rbxassetid://0",
	CrouchWalk = "rbxassetid://0",
	CrouchIdle = "rbxassetid://0",
	Slide = "rbxassetid://0",
	SlideLoop = "rbxassetid://0",
	SlideEnd = "rbxassetid://0",
	Jump = "rbxassetid://0",
	Fall = "rbxassetid://0",
	Land = "rbxassetid://0",
	Vault = "rbxassetid://0",
	Mantle = "rbxassetid://0",
	WallRun = "rbxassetid://0",
	LedgeGrab = "rbxassetid://0",
	LedgePullUp = "rbxassetid://0",
}

-- State machine states
Movement.States = {
	"Idle",
	"Walking",
	"Sprinting",
	"Crouching",
	"CrouchWalking",
	"Sliding",
	"Jumping",
	"Falling",
	"Vaulting",
	"Mantling",
	"WallRunning",
	"LedgeGrabbing",
	"LedgePullingUp",
}

return Movement
