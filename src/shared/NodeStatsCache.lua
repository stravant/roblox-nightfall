--!strict
local NodeStats = require(game.ReplicatedStorage.NodeStats)

local NodeStatsCache = {}

local mWaitingForStats: { [string]: BindableEvent } = {}
local mStatsForNode: { [string]: any } = {}

local mGetNodeStatsRemote = game.ReplicatedStorage.Remotes.GetNodeStats

function NodeStatsCache:Get(nodeId: string)
	local stats = mStatsForNode[nodeId]

	-- We already have a local copy of the stats
	if stats then
		return stats
	else
		-- See if we're already waiting for a local copy
		local sig = mWaitingForStats[nodeId]
		if sig then
			-- Wait for it
			sig.Event:Wait()
			return mStatsForNode[nodeId]
		else
			-- We need to get a local copy. The invoke can throw (server
			-- shutting down etc.); ALWAYS fulfil the cache entry or every
			-- concurrent waiter would hang forever
			sig = Instance.new('BindableEvent')
			mWaitingForStats[nodeId] = sig
			local st, data = pcall(function()
				return mGetNodeStatsRemote:InvokeServer(nodeId)
			end)
			if not st then
				warn("NodeStatsCache | Failed to fetch stats for " .. nodeId)
				data = nil
			end
			stats = NodeStats.new(data)
			mStatsForNode[nodeId] = stats
			mWaitingForStats[nodeId] = nil
			sig:Fire()
			return stats
		end
	end
end

return NodeStatsCache
