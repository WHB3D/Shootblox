--!strict
--[[
	SHOOTBLOX — Typed Network Layer
	Server validates every request; client sends intent only.

	Backed by RemoteEvents today. The public surface (ClientToServer.X:Connect,
	ServerFire, ClientFire, ClientListen, Broadcast) is Zap-shaped so the
	swap to generated Zap code later is a drop-in (Blueprint §5.2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

-- Every event the game speaks. Shape documented in Types.luau.
local CLIENT_TO_SERVER = {
	"Fire",
	"Reload",
	"SwapWeapon",
	"VoteMap",
	"QueueJoin",
	"QueueLeave",
	"AdminCommand",
	"MovementInput",
	"WeaponEquipRequest",
	"WeaponUnequipRequest",
}

local SERVER_TO_CLIENT = {
	"State",
	"HitConfirm",
	"KillFeed",
	"Scoreboard",
	"RoundStart",
	"RoundEnd",
	"MatchEnd",
	"Error",
	"WeaponEquipped",
	"WeaponUnequipped",
	"AmmoUpdate",
	"HealthUpdate",
	"Reloaded",
}

-- Remotes live under ReplicatedStorage/Net; the server creates them once.
local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Net")
	if folder then
		return folder :: Folder
	end
	if IS_SERVER then
		local created = Instance.new("Folder")
		created.Name = "Net"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Net") :: Folder
end

local function getRemote(folder: Folder, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if remote then
		return remote :: RemoteEvent
	end
	if IS_SERVER then
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local folder = getFolder()

-- Wraps a RemoteEvent in the Zap-like handle each side uses.
local function wrap(name: string)
	local remote = getRemote(folder, name)
	local handle = {}

	-- Server: handler(player, payload). Client: handler(payload).
	function handle.Connect(_, callback: (...any) -> ())
		if IS_SERVER then
			return remote.OnServerEvent:Connect(callback)
		end
		return remote.OnClientEvent:Connect(callback)
	end

	-- Client -> server
	function handle.Fire(_, ...: any)
		if IS_SERVER then
			-- Server-side Fire(player, ...) targets one client
			remote:FireClient(...)
		else
			remote:FireServer(...)
		end
	end

	function handle.FireAll(_, ...: any)
		remote:FireAllClients(...)
	end

	function handle.FireAllExcept(_, except: Player, ...: any)
		for _, player in game:GetService("Players"):GetPlayers() do
			if player ~= except then
				remote:FireClient(player, ...)
			end
		end
	end

	return handle
end

local Net = {}

Net.ClientToServer = {} :: { [string]: any }
for _, name in CLIENT_TO_SERVER do
	Net.ClientToServer[name] = wrap(name)
end

Net.ServerToClient = {} :: { [string]: any }
for _, name in SERVER_TO_CLIENT do
	Net.ServerToClient[name] = wrap(name)
end

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
