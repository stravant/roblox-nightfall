local Services = require(game.ReplicatedStorage.Services)

local ServerStatistics = require(game.ServerScriptService.ServerStatistics)
local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
local NodeStats = require(game.ReplicatedStorage.NodeStats)
local MockDataStore = require(game.ServerScriptService.MockDataStore)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local HttpService = Services:Get('HttpService')

-- A Services mock (a table) wins outright; otherwise the debug flag picks
-- between the in-memory mock and the real service
local DataStore = Services:Get('DataStoreService')
if typeof(DataStore) == "Instance" and DebugFlags:UseMockData() then
	DataStore = MockDataStore
end

local DataStoreService = {}

-- test12: player datastores rekeyed from numeric UserId to the serialized
-- domain-scoped User identity (Player.User)
local PRODUCTION_VERSION = 'test12'

local PREFIX = PRODUCTION_VERSION

-- Player data lives in ONE normal datastore under one key per player. The
-- ordered-store version index below is LEGACY: it predates datastore size
-- limits being lifted (every save wrote a new timestamped version key plus
-- an ordered index entry to find the newest). It is read as a fallback for
-- players who haven't saved since the switch, and never written.
local PLAYER_STORE = PREFIX..'_playerdata'
local LEGACY_ORDERED_PREFIX = PREFIX..'_ordered'
local LEGACY_DATA_PREFIX = PREFIX..'_data'

local NODE_STATS_DATASTORE = PREFIX..'_nodestats'

local REPLAYS_DATASTORE = PREFIX..'_replays'
-- Exposed for integration tests to inspect the (mock) stores
DataStoreService.ReplaysStoreName = REPLAYS_DATASTORE
DataStoreService.PlayerStoreName = PLAYER_STORE
DataStoreService.LegacyOrderedPrefix = LEGACY_ORDERED_PREFIX
DataStoreService.LegacyDataPrefix = LEGACY_DATA_PREFIX

-- Datastores are keyed by the domain-scoped User identity (serialized to a
-- string), not the raw numeric UserId
local function playerKey(player)
	return player.User:ToString()
end

local mPlayerStore = DataStore:GetDataStore(PLAYER_STORE)

-- Returns: (Success, [ServerPlayerData])
function DataStoreService:LoadPlayerDataAsync(player)
	local key = playerKey(player)
	local st, a, b = pcall(function()
		local data = mPlayerStore:GetAsync(key)
		if data then
			return true, ServerPlayerData.new(player, data)
		end
		-- Legacy fallback: the old versioned scheme (ordered index of
		-- timestamp keys). Read-only; the next save moves the player onto
		-- the modern key above.
		local orderedStore = DataStore:GetOrderedDataStore(LEGACY_ORDERED_PREFIX..'_'..key)
		local mostRecent = orderedStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
		if mostRecent then
			local legacyStore = DataStore:GetDataStore(LEGACY_DATA_PREFIX..'_'..key)
			local legacy = legacyStore:GetAsync(''..mostRecent.value)
			if legacy then
				return true, ServerPlayerData.new(player, legacy)
			end
			warn("DataStoreService | Legacy index for "..player.UserId.." had time "..mostRecent.value.." but data was missing.")
			return false, nil
		end
		print("DataStoreService | Player "..player.UserId.." has no data yet.")
		return true, nil
	end)
	if st then
		return a, b
	else
		warn("DataStoreService | DataStore error `"..tostring(a).."` for player "..player.UserId)
		return false, nil
	end
end

-- Saves are DEBOUNCED per player: the single fixed key would hit the ~6s
-- per-key write cooldown when e.g. buying several units back to back, so
-- rapid saves coalesce into one trailing write of the newest data. Saving
-- is best-effort fire-and-forget (nothing in the game is trade-critical);
-- the debounce is skipped entirely against the in-memory mock so tests
-- keep synchronous semantics.
local kSaveDebounceSeconds = if typeof(DataStore) == "Instance" then 6 else 0
local mSaveStates = {} -- playerKey -> {LastWrite, Pending, Writing}

-- Returns: (Success) -- always true; the write itself is asynchronous
function DataStoreService:SavePlayerDataAsync(player, serverPlayerData)
	local key = playerKey(player)
	local state = mSaveStates[key]
	if not state then
		state = { LastWrite = -math.huge, Pending = nil, Writing = false }
		mSaveStates[key] = state
	end
	state.Pending = serverPlayerData:Serialize()
	if not state.Writing then
		state.Writing = true
		task.spawn(function()
			while state.Pending do
				-- Debounce in short steps so a flush (player leaving) can
				-- cut the wait short
				while os.clock() - state.LastWrite < kSaveDebounceSeconds and not state.Flush do
					task.wait(0.25)
				end
				state.Flush = false
				local data = state.Pending
				state.Pending = nil
				local st, err = pcall(function()
					mPlayerStore:SetAsync(key, data)
				end)
				state.LastWrite = os.clock()
				if not st then
					warn("DataStoreService | Failed to save player "..player.UserId.." because `"..tostring(err).."`.")
				end
			end
			state.Writing = false
		end)
	end
	return true
end

-- Skip any remaining debounce on the player's pending save (called as they
-- leave): a quick rejoin - same server especially - must read the state
-- they just left with, not a snapshot from before the debounce window
function DataStoreService:FlushPlayerSave(player)
	local st, key = pcall(playerKey, player)
	if not st then
		return
	end
	local state = mSaveStates[key]
	if state and state.Pending then
		state.Flush = true
	end
end

-- Node stats datastores
local mNodeStatsDatastore = DataStore:GetDataStore(NODE_STATS_DATASTORE)

-- Get the stats for a node
local mNodeStatsCache = {}
local mNodeStatsRequests = {} -- In progress fetches of node stats
function DataStoreService:GetStatsForNode(nodeId)
	-- (This function used to return nil on a cache hit, return the request
	-- signal to waiters, and shadow its result local on a successful fetch —
	-- stats never actually made it back to the caller.)
	local cached = mNodeStatsCache[nodeId]
	if cached then
		return cached
	end
	local sig = mNodeStatsRequests[nodeId]
	if sig then
		sig.Event:Wait()
		-- The fetch may have failed; fall back to fresh stats
		return mNodeStatsCache[nodeId] or NodeStats.new(nil)
	end
	sig = Instance.new('BindableEvent')
	mNodeStatsRequests[nodeId] = sig
	local dataEntry
	local st, err = pcall(function()
		local data = mNodeStatsDatastore:GetAsync(nodeId)
		dataEntry = NodeStats.new(data)
		mNodeStatsCache[nodeId] = dataEntry
	end)
	mNodeStatsRequests[nodeId] = nil
	if not st then
		dataEntry = NodeStats.new(nil)
		ServerStatistics:NodeStatsLoadFailed(err)
	end
	sig:Fire()
	return dataEntry
end

-- Update the cached copy of the stats for a node and update the main copy too
function DataStoreService:UpdateStatsForNode(nodeId, playerId, firstTime, replayString, replayResult)
	-- We're doing the update either way, so update the cached copy while we're
	-- at it using the copy we see when doing the UpdateAsync
	-- No need for error handling on here as UpdateAsync inherently does error handling
	-- retries / etc
	mNodeStatsDatastore:UpdateAsync(nodeId, function(oldData)
		-- Construct a temporary nodeStats to call update on
		-- This will work even if the old data is nil because
		-- the default constructor for NodeStats takes nil to construct
		-- a fresh stats
		local data = NodeStats.new(oldData)
		
		-- Record the play
		data:RecordPlay(playerId, firstTime, replayString, replayResult)
		
		-- Save to the cache
		mNodeStatsCache[nodeId] = data
		
		-- Save the new data to the data store
		return data:Serialize()
	end)
end

--------------------------------------------------------------------------------
-- Per-node record leaderboards: one OrderedDataStore per node x stat holding
-- each player's personal best (ascending: smallest = the record). Keyed by
-- GLOBAL UserId (not the domain User string) deliberately: friend comparisons
-- must address OFFLINE players, and GetFriendsAsync only yields global ids.
--------------------------------------------------------------------------------

local kRecordStats = { "turns", "moves", "units" }
DataStoreService.RecordStats = kRecordStats

local function recordStoreName(nodeId, stat)
	return PREFIX .. "_rec_" .. stat .. "_" .. nodeId
end

-- World record session cache (nodeId_stat -> {Value, UserId}); declared
-- here so record WRITES can keep it honest (see UpdateNodeRecords)
local mWorldRecordCache = {}

-- Write improved personal bests (improved = {turns=?, moves=?, units=?},
-- only the stats that got better). Fire-and-forget.
function DataStoreService:UpdateNodeRecords(nodeId, userId, improved)
	for _, stat in pairs(kRecordStats) do
		local value = improved[stat]
		if value then
			-- Keep the session world-record cache honest: it never expires,
			-- so without this a player who just set the record still saw the
			-- old one on this server (even after rejoining it)
			local cacheKey = nodeId .. "_" .. stat
			local cached = mWorldRecordCache[cacheKey]
			if not cached or value < cached.Value then
				mWorldRecordCache[cacheKey] = { Value = value, UserId = userId }
			end
			spawn(function()
				local st, err = pcall(function()
					DataStore:GetOrderedDataStore(recordStoreName(nodeId, stat))
						:SetAsync(tostring(userId), value)
				end)
				if not st then
					warn("DataStoreService | Failed to record "..stat.." best for node "..nodeId..": "..tostring(err))
				end
			end)
		end
	end
end

-- The already-cached world record for one node+stat: (value, userId) or
-- nil, NEVER fetching - for eagerly sharing what this server happens to
-- know without burning datastore requests
function DataStoreService:GetCachedWorldRecord(nodeId, stat)
	local cached = mWorldRecordCache[nodeId .. "_" .. stat]
	if cached then
		return cached.Value, cached.UserId
	end
	return nil
end

-- World record for one node+stat: (value, userId) or nil. Session-cached
-- (the cache lives above UpdateNodeRecords, which patches it on writes).
function DataStoreService:GetWorldRecord(nodeId, stat)
	local cacheKey = nodeId .. "_" .. stat
	local cached = mWorldRecordCache[cacheKey]
	if cached then
		return cached.Value, cached.UserId
	end
	local st, value, userId = pcall(function()
		local top = DataStore:GetOrderedDataStore(recordStoreName(nodeId, stat))
			:GetSortedAsync(--[[ascending=]] true, 1):GetCurrentPage()[1]
		if top then
			return top.value, tonumber(top.key)
		end
		return nil, nil
	end)
	if not st then
		warn("DataStoreService | Failed to read world record for "..nodeId.." "..stat)
		return nil, nil
	end
	if value then
		mWorldRecordCache[cacheKey] = { Value = value, UserId = userId }
	end
	return value, userId
end

-- One user's recorded best for a node+stat (nil if they never won it)
function DataStoreService:GetUserRecord(nodeId, stat, userId)
	local st, value = pcall(function()
		return DataStore:GetOrderedDataStore(recordStoreName(nodeId, stat))
			:GetAsync(tostring(userId))
	end)
	if st then
		return value
	end
	return nil
end

--------------------------------------------------------------------------------
-- Session journeys (the UX study tool): a rolling log of session event
-- streams, one record per session under a time-prefixed key. Deliberately
-- versioned SEPARATELY from the player data stores: bump the version here
-- to clear the log without touching any persistent player data. Records
-- aren't tied to player storage at all — they're just diagnostics to read.
--------------------------------------------------------------------------------

local JOURNEY_DATASTORE = 'journeys_v1'
DataStoreService.JourneyStoreName = JOURNEY_DATASTORE

-- Diagnostics stores (journeys, failed replays) deliberately BYPASS
-- UseMockData when the real service works: records from Studio playtests
-- must survive the playtest (the in-memory mock dies with the server), and
-- Studio can then also browse the LIVE game's records. Falls back to the
-- mock when the real service is unavailable (integration tests via the
-- Services mock; Studio without API access enabled).
local function openDiagnosticsStore(name)
	local raw = Services:Get('DataStoreService')
	if typeof(raw) == "Instance" then
		local st, store = pcall(function()
			return raw:GetDataStore(name)
		end)
		if st then
			return store
		end
		warn("DataStoreService | " .. name .. " using the in-memory mock (enable"
			.. " 'Studio Access to API Services' to persist it): " .. tostring(store))
		return MockDataStore:GetDataStore(name)
	end
	return DataStore:GetDataStore(name)
end
local mJourneyStore = openDiagnosticsStore(JOURNEY_DATASTORE)

-- Fire-and-forget (diagnostics, not player data), but tracked so
-- WaitForSavesToComplete can drain them at shutdown
local mDiagnosticSavesInFlight = 0
local function saveDiagnostic(store, kind, key, record)
	mDiagnosticSavesInFlight += 1
	task.spawn(function()
		local st, err = pcall(function()
			store:SetAsync(key, record)
		end)
		mDiagnosticSavesInFlight -= 1
		if not st then
			warn("DataStoreService | Failed to save "..kind.." "..key.." because `"..tostring(err).."`.")
		end
	end)
end

function DataStoreService:SaveJourney(key, record)
	saveDiagnostic(mJourneyStore, "journey", key, record)
end

function DataStoreService:GetJourney(key)
	local st, result = pcall(function()
		return mJourneyStore:GetAsync(key)
	end)
	return if st then result else nil
end

-- Newest-first diagnostics keys, capped. Keys embed a zero-padded time:
-- reverse lexicographic = newest first.
local function listDiagnosticKeys(store, kind, prefix, maxCount)
	local keys = {}
	local st, err = pcall(function()
		local pages = store:ListKeysAsync(prefix, 100)
		while true do
			for _, item in pairs(pages:GetCurrentPage()) do
				table.insert(keys, item.KeyName)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not st then
		warn("DataStoreService | Failed to list "..kind.." because `"..tostring(err).."`.")
	end
	table.sort(keys, function(a, b)
		return a > b
	end)
	while #keys > maxCount do
		table.remove(keys)
	end
	return keys
end

function DataStoreService:ListJourneyKeys(maxCount)
	return listDiagnosticKeys(mJourneyStore, "journeys", "j_", maxCount)
end

--------------------------------------------------------------------------------
-- Failed replays: replays the server re-simulation REJECTED, kept with the
-- failure reason so the divergence can be re-run and diagnosed offline
-- (ReplayChecker is deterministic: the stored string reproduces the failure
-- in a spec). Same rolling-diagnostics-log character as the journeys.
--------------------------------------------------------------------------------

local FAILED_REPLAY_DATASTORE = 'failed_replays_v1'
DataStoreService.FailedReplayStoreName = FAILED_REPLAY_DATASTORE
local mFailedReplayStore = openDiagnosticsStore(FAILED_REPLAY_DATASTORE)

-- record: { Replay, Reason, UserId, Name, Time }. Returns the generated
-- key (the "replay id" stamped onto the InvalidReplay analytics event).
function DataStoreService:SaveFailedReplay(record)
	-- Time-prefixed like journey keys: reverse-lexicographic = newest first
	local key = string.format("fr_%012d_%04d", os.time(), math.random(0, 9999))
	saveDiagnostic(mFailedReplayStore, "failed replay", key, record)
	return key
end

function DataStoreService:GetFailedReplay(key)
	local st, result = pcall(function()
		return mFailedReplayStore:GetAsync(key)
	end)
	return if st then result else nil
end

function DataStoreService:ListFailedReplayKeys(maxCount)
	return listDiagnosticKeys(mFailedReplayStore, "failed replays", "fr_", maxCount)
end

-- Save a replay
local mReplaysDatastore = DataStore:GetDataStore(REPLAYS_DATASTORE)

function DataStoreService:GetReplay(id)
	local st, result = pcall(function()
		return mReplaysDatastore:GetAsync(id)
	end)
	return if st then result else nil
end

function DataStoreService:SaveReplay(replayString)
	local id = HttpService:GenerateGUID(false)
	spawn(function()
		local st, err = pcall(function()
			mReplaysDatastore:SetAsync(id, replayString)
		end)
		if not st then
			warn("DataStoreService | Failed to save replay "..id.." because `"..tostring(err).."`.")
		end
	end)
	return id
end


-- Server shutdown (BindToClose): wait out any debounced player writes and
-- in-flight journey writes. Bounded well under BindToClose's 30s allowance.
function DataStoreService:WaitForSavesToComplete()
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		local busy = mDiagnosticSavesInFlight > 0
		for _, state in pairs(mSaveStates) do
			if state.Pending ~= nil or state.Writing then
				busy = true
				break
			end
		end
		if not busy then
			return
		end
		task.wait(0.1)
	end
end


return DataStoreService
