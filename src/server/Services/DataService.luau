--!strict
--[[
	SHOOTBLOX — Data Service (ProfileStore)
	Server-ledgered persistent data with migrations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProfileStore = require(ReplicatedStorage.Packages.ProfileStore)

local Types = require(ReplicatedStorage.Shared.Types)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local DataService = {}

function DataService.SetDependencies(deps)
	-- Store dependencies if needed
end

local ProfileStoreInstance = ProfileStore.New("PlayerData_v1", {
	Coins = 0,
	Keys = 0,
	XP = 0,
	Level = 1,
	RankedRating = 1000,
	RankedPlacement = nil,
	WeaponContracts = {},
	OwnedWeapons = { "AR_Standard", "Pistol_Standard", "Melee_Knife", "Utility_Frag" },
	OwnedSkins = {},
	EquippedSkin = {},
	DailyTasks = {},
	Streak = 0,
	LastLogin = 0,
	Banned = false,
	Strikes = 0,
	LastStrikeDecay = 0,
	Settings = {
		Sensitivity = 0.5,
		AutoFire = false,
		AimAssist = true,
		GraphicsQuality = 2,
	},
})

local LoadedProfiles: { [Player]: any } = {}
local AUTO_SAVE_INTERVAL = 60 -- seconds

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		DataService.LoadProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.ReleaseProfile(player)
	end)

	-- Auto-save loop
	task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			for player, profile in LoadedProfiles do
				if profile and profile:IsActive() then
					profile:Save()
				end
			end
		end
	end)

	print("[DataService] Initialized with ProfileStore")
end

function DataService.LoadProfile(player: Player)
	local profile = ProfileStoreInstance:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
	if not profile then
		player:Kick("Failed to load profile. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- fill missing keys from template

	-- Handle migration
	DataService.MigrateProfile(profile)

	profile:ListenToRelease(function()
		LoadedProfiles[player] = nil
		player:Kick("Profile loaded on another server.")
	end)

	if player:IsDescendantOf(Players) then
		LoadedProfiles[player] = profile
		DataService.FireProfileLoaded(player, profile.Data)
		print(string.format("[DataService] Loaded profile for %s", player.Name))
	else
		profile:Release()
	end
end

function DataService.ReleaseProfile(player: Player)
	local profile = LoadedProfiles[player]
	if profile then
		profile:Release()
		LoadedProfiles[player] = nil
	end
end

function DataService.MigrateProfile(profile: any)
	local data = profile.Data
	local version = data._version or 1

	-- Migration v1 -> v2 (example)
	if version < 2 then
		-- Add new fields
		data.Glory = data.Glory or 0
		data._version = 2
	end

	-- Migration v2 -> v3
	if version < 3 then
		data.SeasonPass = data.SeasonPass or { Level = 0, Premium = false, Claimed = {} }
		data._version = 3
	end

	-- Add new migrations here incrementally
end

function DataService.FireProfileLoaded(player: Player, data: Types.PlayerProfile)
	-- Send to client
	-- Net.ServerFire(player, "ProfileLoaded", data)
end

function DataService.GetProfile(player: Player): Types.PlayerProfile?
	local profile = LoadedProfiles[player]
	return profile and profile.Data or nil
end

function DataService.Get(player: Player): Types.PlayerProfile?
	return DataService.GetProfile(player)
end

function DataService.Set(player: Player, key: string, value: any)
	local profile = LoadedProfiles[player]
	if profile then
		profile.Data[key] = value
	end
end

function DataService.Increment(player: Player, key: string, delta: number)
	local profile = LoadedProfiles[player]
	if profile then
		profile.Data[key] = (profile.Data[key] or 0) + delta
	end
end

-- Economy helpers
function DataService.AddCoins(player: Player, amount: number)
	DataService.Increment(player, "Coins", amount)
end

function DataService.AddKeys(player: Player, amount: number)
	DataService.Increment(player, "Keys", amount)
end

function DataService.AddXP(player: Player, amount: number)
	local profile = LoadedProfiles[player]
	if not profile then return end

	profile.Data.XP += amount
	-- Level up check
	local newLevel = math.floor(profile.Data.XP / 1000) + 1
	if newLevel > profile.Data.Level then
		profile.Data.Level = newLevel
		-- Level up rewards
		DataService.AddKeys(player, newLevel * 10)
	end
end

function DataService.OwnsWeapon(player: Player, weaponId: string): boolean
	local profile = LoadedProfiles[player]
	if not profile then return false end
	return table.find(profile.Data.OwnedWeapons, weaponId) ~= nil
end

function DataService.GrantWeapon(player: Player, weaponId: string)
	local profile = LoadedProfiles[player]
	if not profile then return false end

	if not table.find(profile.Data.OwnedWeapons, weaponId) then
		table.insert(profile.Data.OwnedWeapons, weaponId)
		return true
	end
	return false
end

function DataService.SpendKeys(player: Player, amount: number): boolean
	local profile = LoadedProfiles[player]
	if not profile then return false end

	if (profile.Data.Keys or 0) >= amount then
		profile.Data.Keys -= amount
		return true
	end
	return false
end

function DataService.GetDailyTasks(player: Player): { any }
	local profile = LoadedProfiles[player]
	if not profile then return {} end

	-- Generate new tasks if needed
	if not profile.Data.DailyTasks or #profile.Data.DailyTasks == 0 then
		DataService.GenerateDailyTasks(player)
	end

	return profile.Data.DailyTasks
end

function DataService.GenerateDailyTasks(player: Player)
	local profile = LoadedProfiles[player]
	if not profile then return end

	local tasks = Economy.DailyTasks
	local selected = {}
	local shuffled = {}
	for i, t in tasks do shuffled[i] = t end

	-- Fisher-Yates shuffle
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	for i = 1, 3 do
		table.insert(selected, {
			Id = shuffled[i].Id,
			Progress = 0,
			Claimed = false,
		})
	end

	profile.Data.DailyTasks = selected
end

function DataService.UpdateTaskProgress(player: Player, taskType: string, amount: number)
	local profile = LoadedProfiles[player]
	if not profile then return end

	for _, task in profile.Data.DailyTasks do
		if not task.Claimed then
			-- Map task types to our IDs
			local taskDef = Economy.DailyTasks[task.Id]
			if taskDef and taskDef.Type == taskType then
				task.Progress = math.min(task.Progress + amount, taskDef.Target)
			end
		end
	end
end

function DataService.ClaimTaskReward(player: Player, taskId: string)
	local profile = LoadedProfiles[player]
	if not profile then return end

	for i, task in profile.Data.DailyTasks do
		if task.Id == taskId and task.Progress >= Economy.DailyTasks[taskId].Target and not task.Claimed then
			task.Claimed = true
			DataService.AddKeys(player, Economy.DailyTasks[taskId].Reward.Keys)
			return true
		end
	end
	return false
end

-- Anti-cheat strike system
function DataService.AddStrike(player: Player, reason: string)
	local profile = LoadedProfiles[player]
	if not profile then return end

	profile.Data.Strikes = (profile.Data.Strikes or 0) + 1
	profile.Data.LastStrikeDecay = os.time()

	-- Auto-ban at 3 strikes
	if profile.Data.Strikes >= 3 then
		profile.Data.Banned = true
		player:Kick("Account banned: excessive integrity violations.")
	end

	warn(string.format("[DataService] Strike added to %s: %s (total: %d)", player.Name, reason, profile.Data.Strikes))
end

function DataService.DecayStrikes()
	for player, profile in LoadedProfiles do
		if profile.Data.Strikes and profile.Data.Strikes > 0 then
			local lastDecay = profile.Data.LastStrikeDecay or 0
			if os.time() - lastDecay > 86400 * 7 then -- 1 week decay
				profile.Data.Strikes = math.max(0, profile.Data.Strikes - 1)
				profile.Data.LastStrikeDecay = os.time()
			end
		end
	end
end

-- Run strike decay daily
task.spawn(function()
	while true do
		task.wait(86400) -- 24 hours
		DataService.DecayStrikes()
	end
end)

return DataService