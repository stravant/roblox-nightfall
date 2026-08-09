local DataStore = game:GetService('DataStoreService')

local ServerStatistics = require(game.ServerScriptService.ServerStatistics)
local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
local NodeStats = require(game.ReplicatedStorage.NodeStats)
local MockDataStore = require(game.ServerScriptService.MockDataStore)
local __TEST = require(game.ReplicatedStorage.__TEST)

local DataStoreService = {}

local PRODUCTION_VERSION = 'test11'

if __TEST:UseMockData() then
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
	local cached = mNodeStatsCache[nodeId]
	if not cached then
		local sig = mNodeStatsRequests[nodeId]
		if sig then
			sig.Event:wait()
			return mNodeStatsRequests[nodeId]
		else
			-- Not sure how to handle a hung request here...
			-- I'm going with one person servers, so there's probably no need
			-- to have detailed error handling here, worse case stats just fail 
			-- to load for nodes
			sig = Instance.new('BindableEvent')
			mNodeStatsRequests[nodeId] = sig
			local dataEntry;
			local st, err = pcall(function()
				local data = mNodeStatsDatastore:GetAsync(nodeId)
				local dataEntry = NodeStats.new(data)
				mNodeStatsCache[nodeId] = dataEntry
				mNodeStatsRequests[nodeId] = nil
			end)
			if not st then 
				mNodeStatsRequests[nodeId] = nil
				dataEntry = NodeStats.new(nil)
				ServerStatistics:NodeStatsLoadFailed(err)
			end
			sig:Fire()
			return dataEntry
		end
	end	
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
		mReplaysDatastore:SetAsync(id, replayString)
	end)
	return id
end


function DataStoreService:WaitForSavesToComplete()
	-- TODO:
end


return DataStoreService
