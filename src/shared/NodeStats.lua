--!strict
local Copy = require(game.ReplicatedStorage.Copy)
local Services = require(game.ReplicatedStorage.Services)

local NodeStats = {}

function NodeStats.new(data)
	local this = {}
	
	local mData;
	if data then
		mData = data
	else
		mData = {
			-- How many plays have been made on the map / how many succeeded
			Attempts = 0;
			Successes = 0;
			
			-- first try tracking
			FirstTryCount = 0;
			FirstTrySuccess = 0;
			
			-- How many turns taken / moves taken on successes
			TotalMoves = 0;
			TotalTurns = 0;
			
			-- Person who beat the level in the least turns
			LeastTurns = {
				PlayerId = nil; -- The player who made the play
				ReplayString = nil;
				PrimaryTurns = 99999;
				SecondaryMoves = 99999;
			};
			
			-- Person who beat the level in the least moves
			LeastMoves = {
				PlayerId = nil;
				ReplayString = nil;
				PrimaryMoves = 99999;
				SecondaryUnits = 99999;
			};
			
			-- Person who beat the level using the least units
			LeastUnits = {
				PlayerId = nil;
				ReplayString = nil;
				PrimaryUnits = 99999;
				SecondaryMoves = 99999;
			};
		}
	end	
	
	local mNameCache = {}
	local function getName(id)
		if not id then
			-- No record holder yet (fresh node); indexing the cache with nil
			-- would throw
			return "<nobody>"
		end
		local name = mNameCache[id]
		if not name then
			local st, p = pcall(function()
				-- Records hold either a legacy numeric UserId or a serialized
				-- domain-scoped User string; engine user-id APIs accept both
				local lookup = id
				if type(id) == "string" then
					lookup = User.fromString(id)
				end
				return Services:Get("Players"):GetNameFromUserIdAsync(lookup)
			end)
			if st then
				name = p
			else
				warn("NodeStats | Failed to get name for player #"..tostring(id))
				name = "<unknown>"
			end
			mNameCache[id] = name
		end
		return name
	end
	
	-- Average moves
	function this:GetAverageMoves()
		if mData.Successes > 0 then
			return math.floor((mData.TotalMoves / mData.Successes)*10) / 10
		else
			return 0
		end
	end

	-- Average turns
	function this:GetAverageTurns()
		if mData.Successes > 0 then
			return math.floor((mData.TotalTurns / mData.Successes)*10) / 10
		else
			return 0
		end		
	end
	
	-- Get least turns info
	function this:GetLeastTurns()
		return getName(mData.LeastTurns.PlayerId), mData.LeastTurns.PrimaryTurns
	end
	
	-- Get least moves info
	function this:GetLeastMoves()
		return getName(mData.LeastMoves.PlayerId), mData.LeastMoves.PrimaryMoves
	end
	
	-- Get least units info
	function this:GetLeastUnits()
		return getName(mData.LeastUnits.PlayerId), mData.LeastUnits.PrimaryUnits
	end
	
	-- Record a replay
	function this:RecordPlay(playerId, firstTime, replayString, replayResult)		
		-- Always increment attempts, we only make it here if it wasn't an early quit
		mData.Attempts = mData.Attempts + 1
		-- If it was a first time, add it to that
		if firstTime then
			mData.FirstTryCount = mData.FirstTryCount + 1		
		end
		
		-- If they won, then add to the rest of the stats
		if replayResult.Won then
			-- Success
			mData.Successes = mData.Successes + 1
			if firstTime then
				mData.FirstTrySuccess = mData.FirstTrySuccess + 1
			end
			
			-- Move / turn count
			mData.TotalMoves = mData.TotalMoves + replayResult.MoveCount
			mData.TotalTurns = mData.TotalTurns + replayResult.TurnCount
			
			-- Check for bests: strictly better on the primary metric always
			-- wins; ties fall to the secondary metric. (The old logic
			-- required improving BOTH, so a strictly-better primary with a
			-- worse secondary was wrongly rejected.)
			if replayResult.TurnCount < mData.LeastTurns.PrimaryTurns
				or (replayResult.TurnCount == mData.LeastTurns.PrimaryTurns
					and replayResult.MoveCount < mData.LeastTurns.SecondaryMoves) then
				-- Have a new best turns
				mData.LeastTurns.PrimaryTurns = replayResult.TurnCount
				mData.LeastTurns.SecondaryMoves = replayResult.MoveCount
				mData.LeastTurns.ReplayString = replayString
				mData.LeastTurns.PlayerId = playerId
			end

			if replayResult.MoveCount < mData.LeastMoves.PrimaryMoves
				or (replayResult.MoveCount == mData.LeastMoves.PrimaryMoves
					and replayResult.UnitCount < mData.LeastMoves.SecondaryUnits) then
				-- have a new best moves
				mData.LeastMoves.PrimaryMoves = replayResult.MoveCount
				mData.LeastMoves.SecondaryUnits = replayResult.UnitCount
				mData.LeastMoves.ReplayString = replayString
				mData.LeastMoves.PlayerId = playerId
			end

			if replayResult.UnitCount < mData.LeastUnits.PrimaryUnits
				or (replayResult.UnitCount == mData.LeastUnits.PrimaryUnits
					and replayResult.MoveCount < mData.LeastUnits.SecondaryMoves) then
				-- have a new best unit count
				mData.LeastUnits.PrimaryUnits = replayResult.UnitCount
				mData.LeastUnits.SecondaryMoves = replayResult.MoveCount
				mData.LeastUnits.ReplayString = replayString
				mData.LeastUnits.PlayerId = playerId
			end
		end
	end
	
	-- Serialize
	function this:Serialize()
		return Copy.Deep(mData)
	end
	
	return this	
end

return NodeStats
