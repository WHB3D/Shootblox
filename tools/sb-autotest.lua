-- sb-autotest: starts a real Play session (server + local client) for the
-- Shootblox self-test build. Installed temporarily by tools/sb-test.sh and
-- removed when it exits. The game's SelfTest module samples state, prints
-- SBDIAG lines, and calls StudioTestService:EndTest, which returns here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Plugins also load into the Play server/client DataModels; only the edit
-- DataModel may start a Play session
if not RunService:IsEdit() then
	return
end

local function diag(msg)
	print("SBDIAG plugin " .. msg)
end

task.spawn(function()
	if not game.Loaded then
		game.Loaded:Wait()
	end
	-- Only act on the self-test build; never auto-Play anything else
	if not ReplicatedStorage:FindFirstChild("SBSelfTest") then
		return
	end
	task.wait(2)
	diag("starting Play session")
	local ok, result = pcall(function()
		return game:GetService("StudioTestService"):ExecutePlayModeAsync({})
	end)
	diag("Play session ended -> " .. tostring(ok) .. " " .. tostring(result))
	diag("done")
end)
