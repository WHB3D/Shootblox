--!strict
--[[
	SHOOTBLOX — Bot Service
	Training bots for solo testing and fill-ins. A bot is a real R15 rig
	registered as a combatant (IsBot attribute + HitboxHistory), so player
	shots go through the full CombatService pipeline like any other target.
	Bots run on the server, so their shots apply damage directly — but only
	with line of sight, after a reaction delay, at a beatable hit chance, and
	never into spawn protection (ForceField).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local HitboxHistory = require(script.Parent.HitboxHistory)

local BotService = {}

type Bot = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Target: Model?,
	SeenAt: number?, -- when line of sight to the current target began
	NextFire: number,
	NextStrafe: number,
	StrafeSign: number,
}

local DIFFICULTY: { [string]: { HitChance: number, Reaction: number } } = {
	Easy = { HitChance = 0.2, Reaction = 0.9 },
	Normal = { HitChance = 0.35, Reaction = 0.6 },
	Hard = { HitChance = 0.55, Reaction = 0.35 },
}
local difficulty = "Normal"

local BOT_SPAWN = Vector3.new(0, 4, -45) -- across the arena from the player pad
local WALK_SPEED = 12
local ACQUIRE_RANGE = 120
local FIRE_RANGE = 80
local KEEP_DISTANCE = 25 -- stop closing in and strafe from here
local FIRE_INTERVAL = 0.5
local DAMAGE_MIN, DAMAGE_MAX = 10, 14
local RESPAWN_DELAY = 3
local THINK_INTERVAL = 0.1 -- AI decisions at 10 Hz

local bots: { Bot } = {}
local paused = false
local spawnCount = 0
local thinkAccumulator = 0
local rng = Random.new()

local function getPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Default R15 body; a welded block rig if avatar loading is unavailable
local function buildRig(): Model
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		return result
	end
	warn("[BotService] R15 rig unavailable, using block rig: " .. tostring(result))

	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	for _, def in
		{
			{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0) },
			{ "UpperTorso", Vector3.new(2, 1.2, 1), Vector3.new(0, 0.4, 0) },
			{ "LowerTorso", Vector3.new(2, 0.8, 1), Vector3.new(0, -0.6, 0) },
		}
	do
		local limb = Instance.new("Part")
		limb.Name = def[1]
		limb.Size = def[2]
		limb.CFrame = root.CFrame * CFrame.new(def[3])
		limb.Massless = true
		limb.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = limb
		weld.Parent = limb
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

function BotService.SetDependencies(_deps) end

function BotService.Init()
	RunService.Heartbeat:Connect(BotService.Update)

	-- Solo player? Give them something to shoot (own thread: Init never yields)
	Players.PlayerAdded:Connect(function()
		task.delay(2, BotService.MaybeSpawnSoloBot)
	end)
	if #Players:GetPlayers() > 0 then
		task.delay(2, BotService.MaybeSpawnSoloBot)
	end

	print("[BotService] Initialized")
end

function BotService.MaybeSpawnSoloBot()
	if #Players:GetPlayers() == 1 and #bots == 0 then
		local model = BotService.SpawnBot()
		print("[BotService] Solo bot spawned: " .. model.Name)
	end
end

function BotService.SpawnBot(): Model
	spawnCount += 1
	local model = buildRig()
	model.Name = "Bot_" .. spawnCount
	model:SetAttribute("IsBot", true)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = getPart(model, "HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.AutoRotate = false -- the AI faces its target itself
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn

	model:PivotTo(CFrame.new(BOT_SPAWN))
	model.Parent = workspace
	-- Server simulates bots: a nearby client must never own (and move) a hitbox
	root:SetNetworkOwner(nil)
	HitboxHistory.Track(model)

	local bot: Bot = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Target = nil,
		SeenAt = nil,
		NextFire = 0,
		NextStrafe = 0,
		StrafeSign = 1,
	}
	table.insert(bots, bot)

	humanoid.Died:Connect(function()
		BotService.OnBotDied(bot)
	end)
	return model
end

function BotService.OnBotDied(bot: Bot)
	local index = table.find(bots, bot)
	if index then
		table.remove(bots, index)
	end
	HitboxHistory.Untrack(bot.Model)
	task.delay(RESPAWN_DELAY, function()
		bot.Model:Destroy()
		BotService.MaybeSpawnSoloBot()
	end)
end

local function findTarget(bot: Bot): Model?
	local best: Model? = nil
	local bestDistance = ACQUIRE_RANGE
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and getPart(character, "HumanoidRootPart")
		if character and humanoid and humanoid.Health > 0 and root then
			local distance = (root.Position - bot.Root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = character, distance
			end
		end
	end
	return best
end

local function hasLineOfSight(bot: Bot, target: Model): boolean
	local from = getPart(bot.Model, "Head")
	local to = getPart(target, "Head")
	if not from or not to then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.Model }
	local result = workspace:Raycast(from.Position, to.Position - from.Position, params)
	return result ~= nil and result.Instance:IsDescendantOf(target)
end

-- Brief visible tracer so the player can see where fire comes from
local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 200, 80)
	beam.Size = Vector3.new(0.08, 0.08, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.06)
end

function BotService.Update(dt: number)
	thinkAccumulator += dt
	if thinkAccumulator < THINK_INTERVAL or paused then
		return
	end
	thinkAccumulator = 0
	local now = os.clock()
	for _, bot in bots do
		if bot.Humanoid.Health > 0 and bot.Model.Parent then
			BotService.Think(bot, now)
		end
	end
end

function BotService.Think(bot: Bot, now: number)
	local target = findTarget(bot)
	if target ~= bot.Target then
		bot.Target = target
		bot.SeenAt = nil
	end
	local targetRoot = target and getPart(target, "HumanoidRootPart")
	if not target or not targetRoot then
		bot.Humanoid:Move(Vector3.zero)
		return
	end

	local toTarget = targetRoot.Position - bot.Root.Position
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local forward = flat.Unit
	local visible = hasLineOfSight(bot, target)

	-- Close in until KEEP_DISTANCE (or until visible), then strafe
	if now >= bot.NextStrafe then
		bot.StrafeSign = -bot.StrafeSign
		bot.NextStrafe = now + rng:NextNumber(0.8, 1.6)
	end
	if flat.Magnitude > KEEP_DISTANCE or not visible then
		bot.Humanoid:Move(forward)
	else
		bot.Humanoid:Move(forward:Cross(Vector3.yAxis) * bot.StrafeSign)
	end
	bot.Root.CFrame = CFrame.lookAt(bot.Root.Position, bot.Root.Position + forward)

	-- Fire: needs sight, a human reaction delay, range, and an unprotected target
	if not visible then
		bot.SeenAt = nil
		return
	end
	bot.SeenAt = bot.SeenAt or now
	local settings = DIFFICULTY[difficulty]
	if now - (bot.SeenAt :: number) < settings.Reaction or now < bot.NextFire then
		return
	end
	if toTarget.Magnitude > FIRE_RANGE or target:FindFirstChildOfClass("ForceField") then
		return
	end
	bot.NextFire = now + FIRE_INTERVAL

	local botHead = getPart(bot.Model, "Head")
	local targetHead = getPart(target, "Head")
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not botHead or not targetHead or not humanoid then
		return
	end
	local hit = rng:NextNumber() <= settings.HitChance
	local aimPoint = if hit then targetHead.Position else targetHead.Position + rng:NextUnitVector() * 3
	tracer(botHead.Position, aimPoint)
	if hit then
		humanoid:TakeDamage(rng:NextInteger(DAMAGE_MIN, DAMAGE_MAX))
		if humanoid.Health <= 0 then
			Net.Broadcast(
				"KillFeed",
				{ Killer = bot.Model.Name, Victim = target.Name, Weapon = "AR_Standard", Headshot = false }
			)
		end
	end
end

-- Freeze all bot AI (SelfTest uses this to probe combat deterministically)
function BotService.SetPaused(value: boolean)
	paused = value
	for _, bot in bots do
		bot.Humanoid:Move(Vector3.zero)
	end
end

function BotService.GetBots(): { Model }
	local models = {}
	for _, bot in bots do
		table.insert(models, bot.Model)
	end
	return models
end

function BotService.SetDifficulty(level: string)
	if DIFFICULTY[level] then
		difficulty = level
	end
end

function BotService.Cleanup()
	for _, bot in bots do
		HitboxHistory.Untrack(bot.Model)
		bot.Model:Destroy()
	end
	bots = {}
end

return BotService
