--!strict
--[[
	SHOOTBLOX — Combat Configuration & Validation Constants
	Pure data: no Roblox globals, no requires.
]]

local Combat = {}

-- Validation tolerances (tunable, evidence-based)
Combat.Tolerances = {
	MaxOriginDrift = 12, -- studs between claimed origin and actual head position
	FireRateJitterWindow = 0.12, -- seconds of network jitter forgiven
	ClaimMaxAngleDeg = 4, -- max angle between claimed and actual direction
	ClaimMaxTargetDrift = 6, -- studs between claimed hit and validated hit
	MaxPenetrationDepth = 4, -- studs for wallbang
	MaxDamageDropoffRange = 500, -- studs
	MinDamagePercent = 0.1, -- minimum damage at max range
	MaxShotsPerTick = 3, -- anti-spam
	RewindBufferSize = 10, -- ticks of position history (200ms at 50Hz)
}

-- Damage types
Combat.DamageType = {
	Ballistic = "Ballistic",
	Explosive = "Explosive",
	Melee = "Melee",
	Environmental = "Environmental",
}

-- Hit group multipliers
Combat.HitGroupMultiplier = {
	Head = 2.0,
	Torso = 1.0,
	LeftArm = 0.9,
	RightArm = 0.9,
	LeftLeg = 0.7,
	RightLeg = 0.7,
}

-- Team configuration
Combat.Teams = {
	Team1 = { Name = "Alpha", Color = Color3.fromRGB(0, 180, 255) },
	Team2 = { Name = "Omega", Color = Color3.fromRGB(255, 60, 60) },
	FFA = { Name = "FreeForAll", Color = Color3.fromRGB(255, 255, 255) },
}

-- Match constants
Combat.Match = {
	DefaultRoundsToWin = 5,
	DefaultRoundTime = 90, -- seconds
	DefaultFreezeTime = 3, -- seconds
	DefaultRespawnDelay = 3, -- seconds
	MaxPlayers = 10,
	MinPlayersToStart = 2,
}

-- Economy rewards
Combat.Rewards = {
	Elimination = 10,
	Headshot = 5,
	RoundWin = 15,
	MatchWin = 50,
	MatchPlayed = 20,
	DailyTask = 25,
	StreakBonus = { 0, 5, 10, 20, 50 }, -- days 1-5+
}

return Combat
