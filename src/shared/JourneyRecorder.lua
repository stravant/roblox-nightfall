--!strict
-- Client-side session journey recording: a timestamped stream of the
-- player's interactions (netmap clicks, dialogue pacing, shop, menu, battle
-- actions), batched to the server every few seconds. The point is UX study:
-- the gaps between events show where players hesitate. No cursor positions,
-- just discrete actions and their timing.
--
-- Views call Record from their interaction choke points; everything is
-- best-effort and inert outside a running client (tests, server requires).

local RunService = game:GetService("RunService")

local kFlushInterval = 8 -- seconds between batch uploads
local kMaxDetail = 80 -- keep event details short (server enforces too)

local JourneyRecorder = {}

local mStartClock: number? = nil
local mPending: { { any } } = {}
local mFlusherRunning = false
local mSuppressed = false

-- Journey playback drives the real views, which would record phantom
-- events into the WATCHER's own journey; it suppresses recording while
-- a playback runs
function JourneyRecorder:SetSuppressed(suppressed: boolean)
	mSuppressed = suppressed
end

local function isLiveClient(): boolean
	-- Studio playtests don't record: the journey log is for REAL sessions
	-- (the viewer still works from Studio, it just reads)
	return RunService:IsRunning() and RunService:IsClient() and not RunService:IsStudio()
end

local function flush()
	if #mPending == 0 then
		return
	end
	local batch = mPending
	mPending = {}
	local ok = pcall(function()
		game.ReplicatedStorage.Remotes.JourneyEvents:FireServer(batch)
	end)
	if not ok then
		-- Best effort: drop the batch rather than grow without bound
	end
end

function JourneyRecorder:Record(event: string, detail: string?)
	if not isLiveClient() or mSuppressed then
		return
	end
	if not mStartClock then
		mStartClock = os.clock()
	end
	local t = os.clock() - (mStartClock :: number)
	local entry: { any } = { math.floor(t * 10) / 10, event }
	if detail then
		entry[3] = detail:sub(1, kMaxDetail)
	end
	table.insert(mPending, entry)
	if not mFlusherRunning then
		mFlusherRunning = true
		task.spawn(function()
			while true do
				task.wait(kFlushInterval)
				flush()
			end
		end)
	end
end

return JourneyRecorder
