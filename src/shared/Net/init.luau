--!strict
--[[
	SHOOTBLOX — Typed Network Layer (Zap)
	Server validates every request; client sends intent only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Zap = require(ReplicatedStorage.Packages.Zap)

local Net = {}

-- Define the network schema
Net.ClientToServer = Zap.defineEvent("ClientToServer", {
	Fire = Zap.Schema({
		WeaponId = Zap.string,
		Origin = Zap.Vector3,
		Direction = Zap.Vector3,
		Target = Zap.Instance.optional(),
		HitPosition = Zap.Vector3.optional(),
		HitNormal = Zap.Vector3.optional(),
		Timestamp = Zap.number,
		ServerTick = Zap.number,
	}),
	Reload = Zap.Schema({
		WeaponId = Zap.string,
	}),
	SwapWeapon = Zap.Schema({
		Slot = Zap.string,
	}),
	VoteMap = Zap.Schema({
		MapId = Zap.string,
	}),
	QueueJoin = Zap.Schema({
		Mode = Zap.string,
	}),
	QueueLeave = Zap.Schema({}),
	AdminCommand = Zap.Schema({
		Command = Zap.string,
		Args = Zap.array(Zap.string),
	}),
	MovementInput = Zap.Schema({
		State = Zap.string,
		MoveDirection = Zap.Vector3,
		IsSprinting = Zap.boolean,
		IsCrouching = Zap.boolean,
		IsSliding = Zap.boolean,
		SlideVelocity = Zap.Vector3,
		Timestamp = Zap.number,
	}),
	WeaponEquipRequest = Zap.Schema({
		WeaponId = Zap.string,
		Slot = Zap.string,
	}),
	WeaponUnequipRequest = Zap.Schema({
		Slot = Zap.string,
	}),
})

Net.ServerToClient = Zap.defineEvent("ServerToClient", {
	State = Zap.Schema({
		State = Zap.string,
		Data = Zap.any,
	}),
	HitConfirm = Zap.Schema({
		WeaponId = Zap.string,
		Damage = Zap.number,
		HitPosition = Zap.Vector3,
		Headshot = Zap.boolean,
	}),
	KillFeed = Zap.Schema({
		Killer = Zap.string,
		Victim = Zap.string,
		Weapon = Zap.string,
		Headshot = Zap.boolean,
	}),
	Scoreboard = Zap.Schema({
		Players = Zap.array(Zap.any),
	}),
	RoundStart = Zap.Schema({
		Round = Zap.number,
		Map = Zap.string,
		FreezeEnd = Zap.number,
	}),
	RoundEnd = Zap.Schema({
		Winner = Zap.number.optional(),
		Scores = Zap.array(Zap.number),
	}),
	MatchEnd = Zap.Schema({
		Winner = Zap.number.optional(),
		Stats = Zap.array(Zap.any),
	}),
	Error = Zap.Schema({
		Code = Zap.string,
		Message = Zap.string,
	}),
	WeaponEquipped = Zap.Schema({
		WeaponId = Zap.string,
		Slot = Zap.string,
	}),
	WeaponUnequipped = Zap.Schema({
		Slot = Zap.string,
	}),
})

-- Server-side helpers
function Net.ServerFire(player: Player, event: string, ...: any)
	Net.ServerToClient[event]:Fire(player, ...)
end

function Net.Broadcast(event: string, ...: any)
	Net.ServerToClient[event]:FireAll(...)
end

function Net.BroadcastExcept(except: Player, event: string, ...: any)
	Net.ServerToClient[event]:FireAllExcept(except, ...)
end

-- Client-side helpers
function Net.ClientFire(event: string, ...: any)
	Net.ClientToServer[event]:Fire(...)
end

function Net.ClientListen(event: string, callback: (...any) -> ())
	return Net.ServerToClient[event]:Connect(callback)
end

return Net