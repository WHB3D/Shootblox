--!strict
--[[
	SHOOTBLOX — Global Type Definitions for luau-lsp
	Provides Roblox API types and project-specific type aliases.
	Used by luau-lsp analyze via --definitions flag.
]]

--- @alias Vector3 { X: number, Y: number, Z: number }
--- @alias CFrame { Position: Vector3, LookVector: Vector3, RightVector: Vector3, UpVector: Vector3 }
--- @alias Color3 { R: number, G: number, B: number }
--- @alias UDim2 { X: { Scale: number, Offset: number }, Y: { Scale: number, Offset: number } }
--- @alias RaycastParams { FilterType: Enum.RaycastFilterType, FilterDescendantsInstances: { Instance }, IgnoreWater: boolean }
--- @alias RaycastResult { Instance: Instance, Position: Vector3, Normal: Vector3, Material: Enum.Material, Distance: number }

-- Roblox Services
declare global
	interface Game {
		GetService: (self: Game, className: string) => any
		PlaceId: number
		JobId: string
	}
	interface Workspace {
		GetServerTimeNow: (self: Workspace) => number
		Raycast: (self: Workspace, origin: Vector3, direction: Vector3, params: RaycastParams?) => RaycastResult?
		FilteringEnabled: boolean
		Gravity: number
	}
	interface Players {
		GetPlayers: (self: Players) => { Player }
		GetPlayerFromCharacter: (self: Players, character: Model) => Player?
		PlayerAdded: RBXScriptSignal<(player: Player) => ()>
		PlayerRemoving: RBXScriptSignal<(player: Player) => ()>
	}
	interface Player {
		UserId: number
		Name: string
		Character: Model?
		Backpack: Backpack
		PlayerGui: PlayerGui
		GetAttribute: (self: Player, name: string) => any
		SetAttribute: (self: Player, name: string, value: any?) => ()
		Kick: (self: Player, message: string?) => ()
		IsDescendantOf: (self: Player, ancestor: Instance) => boolean
	}
	interface Model {
		FindFirstChild: (self: Model, name: string, recursive?: boolean) => Instance?
		FindFirstAncestorOfClass: (self: Instance, className: string) => Instance?
		GetBoundingBox: (self: Model) => (CFrame, Vector3)
		PivotTo: (self: Model, cframe: CFrame) => ()
		GetPivot: (self: Model) => CFrame
	}
	interface BasePart {
		Position: Vector3
		CFrame: CFrame
		Size: Vector3
		Material: Enum.Material
		Color: Color3
		Anchored: boolean
		CanCollide: boolean
		Transparency: number
		AssemblyLinearVelocity: Vector3
		FindFirstChild: (self: Instance, name: string) => Instance?
	}
	interface Humanoid {
		Health: number
		MaxHealth: number
		WalkSpeed: number
		JumpPower: number
	}
	interface Instance {
		Name: string
		Parent: Instance?
		FindFirstChild: (self: Instance, name: string, recursive?: boolean) => Instance?
		FindFirstAncestorOfClass: (self: Instance, className: string) => Instance?
		IsA: (self: Instance, className: string) => boolean
		Destroy: (self: Instance) => ()
		Clone: (self: Instance) => Instance
		GetAttribute: (self: Instance, name: string) => any
		SetAttribute: (self: Instance, name: string, value: any?) => ()
	}
	interface RBXScriptSignal<T...> {
		Connect: (self: RBXScriptSignal<T...>, callback: (T...) => ()) => RBXScriptConnection
		Once: (self: RBXScriptSignal<T...>, callback: (T...) => ()) => RBXScriptConnection
		Wait: (self: RBXScriptSignal<T...>) => T...
	}
	interface RBXScriptConnection {
		Disconnect: (self: RBXScriptConnection) => ()
		Connected: boolean
	}
	interface Task {
		wait: (seconds?: number) => (number, number)
		spawn: (callback: () => ()) => thread
		delay: (seconds: number, callback: () => ()) => thread
	}
	interface Math {
		clamp: (x: number, min: number, max: number) => number
		deg: (rad: number) => number
		rad: (deg: number) => number
		acos: (x: number) => number
		floor: (x: number) => number
		max: (a: number, b: number) => number
		min: (a: number, b: number) => number
		abs: (x: number) => number
		random: (m: number?, n: number?) => number
	}
	interface String {
		sub: (s: string, i: number, j?: number) => string
		lower: (s: string) => string
		upper: (s: string) => string
		split: (s: string, sep: string) => { string }
	}
	interface Table {
		insert: <T>(t: { T }, value: T) => ()
		remove: <T>(t: { T }, pos?: number) => T?
		sort: <T>(t: { T }, comp?: (a: T, b: T) => boolean) => ()
		find: <T>(t: { T }, value: T, init?: number) => number?
		clone: <T>(t: { T }) => { T }
	}
	interface Os {
		time: () => number
		clock: () => number
	}
	interface Coroutine {
		create: (f: () => ()) => thread
		resume: (co: thread, ...any) => (boolean, ...any)
		status: (co: thread) => string
		wrap: (f: () => ()) => () => ()
	}
	interface Debug {
		traceback: (co?: thread, msg?: string, level?: number) => string
	}
	interface Enum {
		RaycastFilterType: { Exclude: Enum.RaycastFilterType, Include: Enum.RaycastFilterType }
		Material: { Glass: Enum.Material, Plastic: Enum.Material, Concrete: Enum.Material }
		NormalId: { Top: Enum.NormalId, Bottom: Enum.NormalId, Left: Enum.NormalId, Right: Enum.NormalId, Front: Enum.NormalId, Back: Enum.NormalId }
		SurfaceType: { Smooth: Enum.SurfaceType }
	}
end

-- Module types for our codebase
declare module "src/shared/Types" {
	export type WeaponConfig = {
		Id: string,
		Name: string,
		Slot: "Primary" | "Secondary" | "Melee" | "Utility",
		Damage: number,
		FireRate: number,
		Range: number,
		Spread: number,
		HeadshotMultiplier: number,
		DamageDropoff: { [number]: number }?,
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
		EquippedSkin: { [string]: string }?,
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
	export type ShotRequest = {
		WeaponId: string,
		Origin: Vector3,
		Direction: Vector3,
		Target: Instance?,
		HitPosition: Vector3?,
		HitNormal: Vector3?,
		Timestamp: number,
		ServerTick: number,
	}
	export type ValidationResult = {
		Valid: boolean,
		RejectReason: string?,
		Damage: number?,
		HitPosition: Vector3?,
		HitNormal: Vector3?,
		Headshot: boolean?,
	}
}