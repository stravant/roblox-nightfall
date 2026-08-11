local DataStore = game:GetService('DataStoreService')

local ServerStatistics = require(game.ServerScriptService.ServerStatistics)
local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
local NodeStats = require(game.ReplicatedStorage.NodeStats)
local MockDataStore = require(game.ServerScriptService.MockDataStore)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local DataStoreService = {}

local PRODUCTION_VERSION = 'test11'

if DebugFlags:UseMockData() then
	DataStore = MockDataStore
end

local PREFIX = PRODUCTION_VERSION
local PLAYER_ORDERED_PREFIX = PREFIX..'_ordered'
local PLAYER_DATA_PREFIX = PREFIX..'_data'

local NODE_STATS_DATASTORE = PREFIX..'_nodestats'

local REPLAYS_DATASTORE = PREFIX..'_replays'

-- Returns: (Success, [ServerPlayerData])
function DataStoreService:LoadPlayerDataAsync(id)
	local st, a, b = pcall(function()
		local playerOrderedStore = DataStore:GetOrderedDataStore(PLAYER_ORDERED_PREFIX..'_'..id)
		local mostRecent = playerOrderedStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
		if mostRecent then
			local playerNormalStore = DataStore:GetDataStore(PLAYER_DATA_PREFIX..'_'..id)
			local data = playerNormalStore:GetAsync(''..mostRecent.value)
			if data then
				return true, ServerPlayerData.new(id, data)
			else
				warn("DataStoreService | OrderedDataStore for "..id.." had time "..mostRecent.value.." but data was missing.")
				return false, nil
			end
		else
			print("DataStoreService | Player "..id.." has no timestamp yet.")
			return true, nil
		end
	end)
	if st then
		return a, b
	else
		warn("DataStoreService | DataStore error `"..a.."` for player "..id)
		return false, nil
	end
end

-- Returns: (Success)
function DataStoreService:SavePlayerDataAsync(id, serverPlayerData)
	local data = serverPlayerData:Serialize()
	local tm = os.time()
	
	-- Fire off the normal store save
	local playerNormalStore = DataStore:GetDataStore(PLAYER_DATA_PREFIX..'_'..id)
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
		local playerOrderedStore = DataStore:GetOrderedDataStore(PLAYER_ORDERED_PREFIX..'_'..id)
		playerOrderedStore:SetAsync(''..tm, tm)
	end)
	if not st then
		warn("DataStoreService | Failed to save player "..id.." timestamp because `"..err.."`.")
		return false
	end
	
	-- Successfully saved the timestamp, now wait until the data is saved
	if not dataStoreCompleted then
		dataStoreCompletedSignal.Event:wait()
	end
	if not dataStoreSucceeded then
		warn("DataStoreService | Saved player "..id.." timestamp "..tm.." but fail to save data because `"..dataStoreError.."`.")
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
