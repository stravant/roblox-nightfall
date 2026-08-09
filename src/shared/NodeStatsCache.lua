local NodeStats = require(game.ReplicatedStorage.NodeStats)

local NodeStatsCache = {}

local mWaitingForStats = {}
local mStatsForNode = {}

local mGetNodeStatsRemote = game.ReplicatedStorage.Remotes.GetNodeStats

function NodeStatsCache:Get(nodeId)
	local stats = mStatsForNode[nodeId]
	
	-- We already have a local copy of the stats
	if stats then
		return stats
	else
		-- See if we're already waiting for a local copy
		local sig = mWaitingForStats[nodeId]
		if sig then
			-- Wait for it
			sig.Event:wait()
			return mStatsForNode[nodeId]
		else
			-- We need to get a local copy
			sig = Instance.new('BindableEvent')
			mWaitingForStats[nodeId] = sig
			local data = mGetNodeStatsRemote:InvokeServer(nodeId)
			stats = NodeStats.new(data)
			mStatsForNode[nodeId] = stats
			mWaitingForStats[nodeId] = nil
			sig:Fire()
			return stats
		end
	end
end

return NodeStatsCache
