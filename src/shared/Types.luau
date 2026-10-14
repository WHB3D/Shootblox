--!strict
--[[
	SHOOTBLOX — Core Type Definitions
	Pure module: no Roblox globals, no requires. Unit-testable with Lune.
]]

-- Weapon configuration
export type WeaponConfig = {
	Id: string,
	Name: string,
	Slot: "Primary" | "Secondary" | "Melee" | "Utility",
	Damage: number,
	FireRate: number, -- rounds per second
	Range: number, -- studs
	Spread: number, -- degrees
	HeadshotMultiplier: number,
	DamageDropoff: { [number]: number }?, -- range -> multiplier
	MagSize: number,
	ReloadTime: number,
	ProjectileSpeed: number?,
	ProjectileType: "Hitscan" | "Projectile" | "Beam",
	RecoilPattern: { Vector2 }?,
	ViewModelOffset: CFrame?,
	Sounds: {
		Fire: string?,
		Reload: string?,
		Empty: string?,
	},
	Visuals: {
		MuzzleFlash: string?,
		Tracer: string?,
		ImpactEffect: string?,
	},
}

-- Weapon data for runtime
export type WeaponData = WeaponConfig & {
	CurrentAmmo: number,
	ReserveAmmo: number,
	LastFireTime: number,
	IsReloading: boolean,
}

-- Map specification
export type MapSpec = {
	Id: string,
	Name: string,
	Symmetrical: boolean?,
	Modes: { string },
	Size: "Small" | "Medium" | "Large",
	Spawns: { Vector3 },
	Bounds: { Min: Vector3, Max: Vector3 },
	Cover: { { Position: Vector3, Size: Vector3 } }?,
}

-- Player profile data (ProfileStore)
export type PlayerProfile = {
	UserId: number,
	Username: string,
	Coins: number,
	Keys: number,
	XP: number,
	Level: number,
	RankedRating: number,
	RankedPlacement: number?,
	WeaponContracts: { [string]: { Progress: number, Completed: boolean } },
	OwnedWeapons: { string },
	OwnedSkins: { string },
	EquippedSkin: { [string]: string }?, -- WeaponId -> SkinId
	DailyTasks: { { Id: string, Progress: number, Claimed: boolean } },
	Streak: number,
	LastLogin: number,
	Banned: boolean?,
	Strikes: number,
	LastStrikeDecay: number,
	Settings: {
		Sensitivity: number,
		AutoFire: boolean,
		AimAssist: boolean,
		GraphicsQuality: number,
	},
}

-- Match state
export type MatchState = "Lobby" | "Queueing" | "Countdown" | "Round" | "RoundEnd" | "MatchEnd"

export type MatchConfig = {
	Mode: "1v1" | "2v2" | "5v5" | "FFA",
	MapId: string,
	RoundsToWin: number,
	RoundTime: number,
	FreezeTime: number,
	Respawn: boolean,
	RespawnDelay: number,
	Ranked: boolean,
	Region: string,
}

export type MatchPlayer = {
	UserId: number,
	Team: number, -- 1 or 2 (0 for FFA)
	Loadout: { Primary: string, Secondary: string, Melee: string, Utility: string },
	Stats: {
		Kills: number,
		Deaths: number,
		Damage: number,
		Headshots: number,
	},
	Alive: boolean,
}

-- Combat validation
export type ShotRequest = {
	WeaponId: string,
	Origin: Vector3,
	Direction: Vector3,
	Target: Instance?, -- optional for hitscan
	HitPosition: Vector3?,
	HitNormal: Vector3?,
	Timestamp: number, -- client tick
	ServerTick: number,
	ShotId: string, -- unique per-shot identifier
}

export type ValidationResult = {
	Valid: boolean,
	RejectReason: string?,
	Damage: number?,
	HitPosition: Vector3?,
	HitNormal: Vector3?,
}

-- Network remotes (Zap schema)
export type ClientToServer = {
	Fire: ShotRequest,
	Reload: { WeaponId: string },
	SwapWeapon: { Slot: string },
	VoteMap: { MapId: string },
	QueueJoin: { Mode: string },
	QueueLeave: {},
	AdminCommand: { Command: string, Args: { string } },
}

export type ServerToClient = {
	State: { State: MatchState, Data: any },
	HitConfirm: { WeaponId: string, Damage: number, HitPosition: Vector3, Headshot: boolean },
	KillFeed: { Killer: string, Victim: string, Weapon: string, Headshot: boolean },
	Scoreboard: { Players: { MatchPlayer } },
	RoundStart: { Round: number, Map: string, FreezeEnd: number },
	RoundEnd: { Winner: number?, Scores: { number } },
	MatchEnd: { Winner: number?, Stats: { MatchPlayer } },
	Error: { Code: string, Message: string },
}

return {}