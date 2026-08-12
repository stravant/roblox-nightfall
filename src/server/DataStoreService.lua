local DataStore = game:GetService('DataStoreService')

local ServerStatistics = require(game.ServerScriptService.ServerStatistics)
local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
local NodeStats = require(game.ReplicatedStorage.NodeStats)
local MockDataStore = require(game.ServerScriptService.MockDataStore)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local DataStoreService = {}

-- test12: player datastores rekeyed from numeric UserId to the serialized
-- domain-scoped User identity (Player.User)
local PRODUCTION_VERSION = 'test12'

if DebugFlags:UseMockData() then
	DataStore = MockDataStore
end

local PREFIX = PRODUCTION_VERSION
local PLAYER_ORDERED_PREFIX = PREFIX..'_ordered'
local PLAYER_DATA_PREFIX = PREFIX..'_data'

local NODE_STATS_DATASTORE = PREFIX..'_nodestats'

local REPLAYS_DATASTORE = PREFIX..'_replays'

-- Datastores are keyed by the domain-scoped User identity (serialized to a
-- string), not the raw numeric UserId
local function playerKey(player)
	return player.User:ToString()
end

-- Returns: (Success, [ServerPlayerData])
function DataStoreService:LoadPlayerDataAsync(player)
	local key = playerKey(player)
	local st, a, b = pcall(function()
		local playerOrderedStore = DataStore:GetOrderedDataStore(PLAYER_ORDERED_PREFIX..'_'..key)
		local mostRecent = playerOrderedStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
		if mostRecent then
			local playerNormalStore = DataStore:GetDataStore(PLAYER_DATA_PREFIX..'_'..key)
			local data = playerNormalStore:GetAsync(''..mostRecent.value)
			if data then
				return true, ServerPlayerData.new(player, data)
			else
				warn("DataStoreService | OrderedDataStore for "..player.UserId.." had time "..mostRecent.value.." but data was missing.")
				return false, nil
			end
		else
			print("DataStoreService | Player "..player.UserId.." has no timestamp yet.")
			return true, nil
		end
	end)
	if st then
		return a, b
	else
		warn("DataStoreService | DataStore error `"..tostring(a).."` for player "..player.UserId)
		return false, nil
	end
end

-- Returns: (Success)
function DataStoreService:SavePlayerDataAsync(player, serverPlayerData)
	local key = playerKey(player)
	local data = serverPlayerData:Serialize()
	local tm = os.time()

	-- Fire off the normal store save
	local playerNormalStore = DataStore:GetDataStore(PLAYER_DATA_PREFIX..'_'..key)
	local dataStoreCompleted = false
	local dataStoreSucceeded = false
	local dataStoreError = nil
	local dataStoreCompletedSignal = Instance.new('BindableEvent')
	spawn(function()
		local st, err = pcall(function()
			playerNormalStore:SetAsync(''..tm, data)
		end)
		dataStoreError = err
		dataStoreSucceeded = st
		dataStoreCompleted = true
		dataStoreCompletedSignal:Fire()
	end)
	
	-- Synchronously fire off the timestamp save
	local st, err = pcall(function()
		local playerOrderedStore = DataStore:GetOrderedDataStore(PLAYER_ORDERED_PREFIX..'_'..key)
		playerOrderedStore:SetAsync(''..tm, tm)
	end)
	if not st then
		warn("DataStoreService | Failed to save player "..player.UserId.." timestamp because `"..tostring(err).."`.")
		return false
	end

	-- Successfully saved the timestamp, now wait until the data is saved
	if not dataStoreCompleted then
		dataStoreCompletedSignal.Event:wait()
	end
	if not dataStoreSucceeded then
		warn("DataStoreService | Saved player "..player.UserId.." timestamp "..tm.." but fail to save data because `"..tostring(dataStoreError).."`.")
		return false
	end
	
	return true
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

-- Write improved personal bests (improved = {turns=?, moves=?, units=?},
-- only the stats that got better). Fire-and-forget.
function DataStoreService:UpdateNodeRecords(nodeId, userId, improved)
	for _, stat in pairs(kRecordStats) do
		local value = improved[stat]
		if value then
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

-- World record for one node+stat: (value, userId) or nil. Session-cached.
local mWorldRecordCache = {}
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

-- Save a replay
local mReplaysDatastore = DataStore:GetDataStore(REPLAYS_DATASTORE)
function DataStoreService:SaveReplay(replayString)
	local id = game:GetService('HttpService'):GenerateGUID(false)
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


function DataStoreService:WaitForSavesToComplete()
	-- TODO:
end


return DataStoreService
