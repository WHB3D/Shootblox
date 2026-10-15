--!strict
--[[
	SHOOTBLOX — World Service
	Builds the test arena at boot. Rojo syncs code only, so the place file has
	no geometry; until real maps land (Week 9), this is the ground to stand on.
	Also hands every spawning player the default loadout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local WorldService = {}

local ARENA_SIZE = 200
local WALL_HEIGHT = 20
local COVER_COUNT = 10

local weaponService: any

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

function WorldService.SetDependencies(deps: { Weapon: any })
	weaponService = deps.Weapon
end

function WorldService.BuildArena()
	if workspace:FindFirstChild("Arena") then
		return
	end

	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	-- Floor
	part({
		Name = "Floor",
		Size = Vector3.new(ARENA_SIZE, 2, ARENA_SIZE),
		Position = Vector3.new(0, -1, 0),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(235, 235, 240),
	}, arena)

	-- Walls
	local half = ARENA_SIZE / 2
	for _, def in
		{
			{ Vector3.new(0, WALL_HEIGHT / 2, -half), Vector3.new(ARENA_SIZE, WALL_HEIGHT, 2) },
			{ Vector3.new(0, WALL_HEIGHT / 2, half), Vector3.new(ARENA_SIZE, WALL_HEIGHT, 2) },
			{ Vector3.new(-half, WALL_HEIGHT / 2, 0), Vector3.new(2, WALL_HEIGHT, ARENA_SIZE) },
			{ Vector3.new(half, WALL_HEIGHT / 2, 0), Vector3.new(2, WALL_HEIGHT, ARENA_SIZE) },
		}
	do
		part({
			Name = "Wall",
			Position = def[1],
			Size = def[2],
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(60, 60, 70),
		}, arena)
	end

	-- Cover blocks in a deterministic ring so playtests are repeatable
	local rng = Random.new(42)
	for i = 1, COVER_COUNT do
		local angle = (i / COVER_COUNT) * math.pi * 2
		local radius = 30 + rng:NextNumber(0, 40)
		local h = rng:NextNumber(4, 9)
		part({
			Name = "Cover",
			Size = Vector3.new(rng:NextNumber(6, 12), h, rng:NextNumber(4, 8)),
			Position = Vector3.new(math.cos(angle) * radius, h / 2, math.sin(angle) * radius),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(120, 125, 135),
		}, arena)
	end

	-- Spawn pad
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 3 -- spawn protection: ForceField blocks TakeDamage; bots hold fire
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(0, 180, 255)
	spawn.Parent = arena

	arena.Parent = workspace
	print("[WorldService] Arena built")
end

local function onCharacterAdded(player: Player, character: Model)
	-- Accessory handles must not eat rays (Blueprint §5.1.2)
	for _, desc in character:GetDescendants() do
		if desc:IsA("Accessory") then
			local handle = desc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.CanQuery = false
			end
		end
	end

	-- Give the default loadout once the character is fully loaded
	character:WaitForChild("HumanoidRootPart", 10)
	if not weaponService then
		return
	end
	for slot, weaponId in Weapons.DefaultLoadout do
		weaponService.GrantWeapon(player, weaponId, slot)
	end
	weaponService.EquipSlot(player, "Primary")
end

function WorldService.Init()
	WorldService.BuildArena()

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	-- Players who joined before this service initialized
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	print("[WorldService] Initialized")
end

return WorldService
