--!strict
--[[
	SHOOTBLOX — Performance Monitor
	Sums script time spent inside Shootblox's own Heartbeat-connected handlers
	(HitboxHistory capture, movement validation, bot AI) each frame, and
	tracks it against the Blueprint Gate 4 budget (<= 8 ms). This is distinct
	from Roblox's own Heartbeat `dt`, which also includes physics and
	replication cost outside our control.

	Ordering assumption (not a documented Roblox guarantee, but consistent
	practical behavior): connections on one RBXScriptSignal fire in the order
	they were made. Main.server connects PerfMonitor.BeginFrame before any
	service Init() runs, and PerfMonitor.EndFrame after all of them, so every
	Track()-wrapped handler's time lands in the frame it ran in.
]]

local PerfMonitor = {}

local BUDGET_MS = 8
local REPORT_INTERVAL = 5 -- seconds

local frameTotal = 0
local windowMax = 0
local windowSum = 0
local windowSamples = 0
local windowOverBudget = 0
local lastReport = os.clock()

function PerfMonitor.BeginFrame()
	frameTotal = 0
end

-- Wrap a Heartbeat-connected handler; adds its elapsed time to this frame's total.
function PerfMonitor.Track(name: string, fn: (number) -> ()): (number) -> ()
	return function(dt: number)
		local start = os.clock()
		fn(dt)
		frameTotal += (os.clock() - start) * 1000
	end
end

local function flush()
	if windowSamples == 0 then
		return
	end
	print(
		string.format(
			"SBDIAG server perf heartbeat_budget avg=%.2fms max=%.2fms over_budget=%d/%d budget=%dms",
			windowSum / windowSamples,
			windowMax,
			windowOverBudget,
			windowSamples,
			BUDGET_MS
		)
	)
	windowSum, windowSamples, windowMax, windowOverBudget = 0, 0, 0, 0
end

function PerfMonitor.EndFrame()
	windowSum += frameTotal
	windowSamples += 1
	windowMax = math.max(windowMax, frameTotal)
	if frameTotal > BUDGET_MS then
		windowOverBudget += 1
	end
	if os.clock() - lastReport >= REPORT_INTERVAL then
		lastReport = os.clock()
		flush()
	end
end

-- SelfTest: force a report now even if REPORT_INTERVAL hasn't elapsed.
function PerfMonitor.FlushReport()
	flush()
end

return PerfMonitor
