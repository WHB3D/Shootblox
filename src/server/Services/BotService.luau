--!strict
--[[
	SHOOTBLOX — Bot Service
	AI opponents for solo testing and fill-in matches.
	States: Spawn -> Idle -> AcquireTarget -> Aim -> Fire -> Cooldown -> Repeat
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BotService = {}

-- Typed lookup: a character's named BasePart, or nil
local function getPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local BotCharacters: { Model } = {}
local BotStates: { [Model]: string } = {}
local BotTarget: { [Model]: Player } = {}
local BotLastFire: { [Model]: number } = {}
local BotReactionTime: { [Model]: number } = {}
local BotAimError: { [Model]: number } = {}
local BotDifficulty = { Easy = 0.3, Normal = 0.6, Hard = 0.9 }
local BotDifficultySetting = "Normal"

-- Configuration
local BOT_WALK_SPEED = 12
local BOT_ACQUISITION_RANGE = 80
local BOT_FIRE_RANGE = 60
local BOT_AIM_SPEED = 5 -- radians per second

function BotService.SetDependencies(_deps)
	-- Store dependencies if needed
end

function BotService.Init()
	print("[BotService] Initialized")

	-- Spawn bots for testing when no players are present
	RunService.Heartbeat:Connect(function(dt)
		BotService.UpdateBots(dt)
	end)

	-- Auto-spawn solo bot when testing
	task.wait(2)
	BotService.MaybeSpawnSoloBot()
end

function BotService.MaybeSpawnSoloBot()
	if #Players:GetPlayers() == 1 then
		local player = Players:GetPlayers()[1]
		if not BotService.HasBot(player) then
			local botChar = BotService.SpawnBot()
			if botChar then
				BotService.AssignToPlayer(botChar, player)
				print("[BotService] Solo bot spawned for " .. player.Name)
			end
		end
	end
end

function BotService.SpawnBot(): Model?
	local character = Instance.new("Model")
	character.Name = "Bot_" .. tostring(#BotCharacters + 1)

	-- Create humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = BOT_WALK_SPEED
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = character

	-- Create parts (R15-style)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Position = Vector3.new(0, 5, 0)
	hrp.CanCollide = true
	hrp.Parent = character

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Position = Vector3.new(0, 6, 0)
	head.CanCollide = true
	head.Parent = character

	-- Simple arms/legs
	for i, name in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Torso" }) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(1, 2, 1)
		part.Position = Vector3.new(0, 4 - i, 0)
		part.CanCollide = true
		part.Parent = character
	end

	character.PrimaryPart = hrp
	character.Parent = workspace

	table.insert(BotCharacters, character)
	BotStates[character] = "Idle"
	BotReactionTime[character] = 0.5 / BotDifficulty[BotDifficultySetting]
	BotAimError[character] = 0.1 * (1 - BotDifficulty[BotDifficultySetting])

	return character
end

function BotService.AssignToPlayer(botChar: Model, player: Player)
	BotTarget[botChar] = player
	BotStates[botChar] = "Idle"
	BotLastFire[botChar] = 0
end

function BotService.HasBot(player: Player): boolean
	for bot, target in BotTarget do
		if target == player then
			return true
		end
	end
	return false
end

function BotService.UpdateBots(dt: number)
	for botChar, state in BotStates do
		-- Skip dead bots
		local humanoid = botChar:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			BotStates[botChar] = "Dead"
			continue
		end

		-- State machine
		if state == "Idle" then
			BotService.BotIdle(botChar, dt)
		elseif state == "AcquireTarget" then
			BotService.BotAcquireTarget(botChar, dt)
		elseif state == "Aim" then
			BotService.BotAim(botChar, dt)
		elseif state == "Fire" then
			BotService.BotFire(botChar, dt)
		elseif state == "Cooldown" then
			BotService.BotCooldown(botChar, dt)
		end
	end
end

function BotService.BotIdle(botChar: Model, dt: number)
	-- Find nearest enemy player
	local nearestPlayer = BotService.FindNearestEnemy(botChar)
	if nearestPlayer then
		BotTarget[botChar] = nearestPlayer
		BotStates[botChar] = "AcquireTarget"
	end
end

function BotService.BotAcquireTarget(botChar: Model, dt: number)
	local target = BotTarget[botChar]
	if not target or not target.Character then
		BotStates[botChar] = "Idle"
		return
	end

	local targetChar = target.Character
	local targetHRP = getPart(targetChar, "HumanoidRootPart")
	local botHRP = getPart(botChar, "HumanoidRootPart")

	if not targetHRP or not botHRP then
		BotStates[botChar] = "Idle"
		return
	end

	local distance = (targetHRP.Position - botHRP.Position).Magnitude
	if distance > BOT_ACQUISITION_RANGE then
		BotTarget[botChar] = nil
		BotStates[botChar] = "Idle"
		return
	end

	-- Move toward target
	local humanoid = botChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(targetHRP.Position)
	end

	-- Transition to aim after reaction time
	BotReactionTime[botChar] -= dt
	if BotReactionTime[botChar] <= 0 then
		BotStates[botChar] = "Aim"
	end
end

function BotService.BotAim(botChar: Model, dt: number)
	local target = BotTarget[botChar]
	if not target or not target.Character then
		BotStates[botChar] = "Idle"
		return
	end

	local targetHRP = getPart(target.Character, "HumanoidRootPart")
	local botHRP = getPart(botChar, "HumanoidRootPart")

	if not targetHRP or not botHRP then
		BotStates[botChar] = "Idle"
		return
	end

	-- Aim toward target (with error)
	local direction = (targetHRP.Position - botHRP.Position).Unit
	local errorAngle = BotAimError[botChar] * math.pi * 2
	local aimDirection = CFrame.Angles(math.random() * errorAngle, math.random() * errorAngle, 0) * direction

	-- Smooth aim (simplified)
	local currentLook = botHRP.CFrame.LookVector
	local newLook = currentLook:Lerp(aimDirection, BOT_AIM_SPEED * dt)

	-- Rotate character toward aim
	botHRP.CFrame = CFrame.lookAt(botHRP.Position, botHRP.Position + newLook)

	-- Transition to fire if close enough and aimed
	local distance = (targetHRP.Position - botHRP.Position).Magnitude
	if distance < BOT_FIRE_RANGE then
		BotStates[botChar] = "Fire"
	end
end

function BotService.BotFire(botChar: Model, dt: number)
	local target = BotTarget[botChar]
	if not target or not target.Character then
		BotStates[botChar] = "Idle"
		return
	end

	local now = workspace:GetServerTimeNow()
	if now - (BotLastFire[botChar] or 0) < 0.5 then -- fire rate limit
		return
	end
	BotLastFire[botChar] = now

	-- Simulate fire (damage target directly for testing)
	local targetChar = target.Character
	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local damage = math.random(15, 35)
		humanoid:TakeDamage(damage)

		-- Fire visual/sound (simplified)
		print(string.format("[BotService] Bot fires at %s for %d damage", target.Name, damage))
	end

	BotStates[botChar] = "Cooldown"
end

function BotService.BotCooldown(botChar: Model, dt: number)
	-- Brief cooldown, then back to acquire
	BotStates[botChar] = "AcquireTarget"
end

function BotService.FindNearestEnemy(botChar: Model): Player?
	local botHRP = getPart(botChar, "HumanoidRootPart")
	if not botHRP then
		return nil
	end

	local nearest: Player? = nil
	local nearestDist = math.huge

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and getPart(character, "HumanoidRootPart")
		if hrp then
			local dist = (hrp.Position - botHRP.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = player
			end
		end
	end

	return nearest
end

function BotService.SetDifficulty(difficulty: string)
	if BotDifficulty[difficulty] then
		BotDifficultySetting = difficulty
	end
end

function BotService.Cleanup()
	for _, botChar in BotCharacters do
		if botChar.Parent then
			botChar:Destroy()
		end
	end
	BotCharacters = {}
	BotStates = {}
	BotTarget = {}
	BotLastFire = {}
	BotReactionTime = {}
	BotAimError = {}
end

return BotService
