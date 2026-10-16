--!strict
--[[
	SHOOTBLOX — Damped Spring (Blueprint §6.1.1)
	Sub-stepped (8 iterations), semi-implicit Euler. Naive single-step dt
	integration explodes or changes behavior with framerate; the inner loop
	keeps this stable at high FPS (240 Hz+ with an FPS unlocker). Pure
	Vector3 math: callers fold the result into CFrame.Angles/CFrame.new
	themselves (e.g. two rotation axes packed as Vector3.new(pitch, yaw, 0)).
]]

local ITERATIONS = 8

local Spring = {}
Spring.__index = Spring

export type Spring = typeof(setmetatable(
	{} :: {
		Mass: number,
		Force: number,
		Damping: number,
		Speed: number,
		Position: Vector3,
		Velocity: Vector3,
		Target: Vector3,
	},
	Spring
))

function Spring.new(mass: number?, force: number?, damping: number?, speed: number?): Spring
	return setmetatable({
		Mass = mass or 5,
		Force = force or 50,
		Damping = damping or 4,
		Speed = speed or 4,
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Target = Vector3.zero,
	}, Spring)
end

-- An impulse (mouse delta, shot kick). Repeated shoves while the spring
-- hasn't settled compound naturally — recovery only "starts" once they stop.
function Spring.shove(self: Spring, velocity: Vector3)
	self.Velocity += velocity
end

function Spring.update(self: Spring, dt: number): Vector3
	local scaledDeltaTime = dt * self.Speed / ITERATIONS
	for _ = 1, ITERATIONS do
		local force = self.Target - self.Position
		local accel = (force * self.Force) / self.Mass
		accel -= self.Velocity * self.Damping
		self.Velocity += accel * scaledDeltaTime
		self.Position += self.Velocity * scaledDeltaTime
	end
	return self.Position
end

return Spring
