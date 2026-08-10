local Copy = require(game.ReplicatedStorage.Copy)
local Scripts = require(game.ReplicatedStorage.Scripts)
local Netmap = require(game.ReplicatedStorage.Netmap)
local ReplayChecker = require(game.ServerScriptService.ReplayChecker)
local GameState = require(game.ReplicatedStorage.GameState)
local Places = require(game.ReplicatedStorage.Places)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local ServerPlayerData = {}

function ServerPlayerData.new(playerId, serialized)
	local this = {}
	
	local mCredits;
	local mSecurityLevel;
	local mUnitInventory;
	local mNodeStatus;	
	local mSkipsPurchased;
	local mSkipPurchaseIds;
	local mSkipsUsed;
	
	local mIsFirstTimeUser;
	
	if serialized then
		mNodeStatus = Copy.Deep(serialized.NodeStatus)
		mCredits = serialized.Credits
		mSecurityLevel = serialized.SecurityLevel
		mUnitInventory = Copy.Deep(serialized.Units)
		mSkipsPurchased = serialized.SkipsPurchased or 0
		mSkipsUsed = Copy.Deep(serialized.SkipsUsed or {})
		mSkipPurchaseIds = Copy.Deep(serialized.SkipPurchaseIds or {})
		mIsFirstTimeUser = false
	else
		mCredits = DebugFlags:GetInitialCredits()
		mSecurityLevel = 1
		mUnitInventory = {
			{Id = 'slingshot'; Count = 1};
			{Id = 'hack'; Count = 1};
		}
		mNodeStatus = {
			hq = {
				Beaten = false;
				Seen = true;
				Accessible = true;
				AttemptCount = 0;
				WinningPlayId = nil;
			};
		}
		mSkipsPurchased = 0
		mSkipsUsed = {}
		mSkipPurchaseIds = {}
		mIsFirstTimeUser = true
	end
	
	do -- Ensure that node status has stats
		for id, data in pairs(mNodeStatus) do
			data.AttemptCount = data.AttemptCount or 0
			data.WinningPlayId = nil -- The first time that we beat the node
		end
	end
	
	function this:Serialize(forClient)
		local tb = {}
		tb.NodeStatus = Copy.Deep(mNodeStatus)
		tb.Credits = mCredits
		tb.SecurityLevel = mSecurityLevel
		tb.Units = Copy.Deep(mUnitInventory)
		tb.SkipsPurchased = mSkipsPurchased
		tb.SkipsUsed = Copy.Deep(mSkipsUsed)
		tb.SkipPurchaseIds = Copy.Deep(mSkipPurchaseIds)
		if forClient then
			tb.IsFirstTimeUser = mIsFirstTimeUser
		end
		--[[
		local toggle = false
		for id, unit in pairs(Scripts) do
			toggle = not toggle
			if not unit.Enemy and toggle then
				table.insert(tb.Units, {Id = id; Count = 2})
			end
		end	
		]]
		return tb
	end
	
	function this:IsNewPlayer()
		return mIsFirstTimeUser
	end
	
	local function addUnit(id)
		for _, entry in pairs(mUnitInventory) do
			if entry.Id == id then
				entry.Count = entry.Count + 1
				return true
			end
		end
		table.insert(mUnitInventory, {
			Id = id;
			Count = 1;
		})
	end
	
	local function getNodeStatus(id)
		if not Netmap.ById[id] then
			-- Debug check, should never happen
			error("Attempt to access node "..id)
		end
		local tb = mNodeStatus[id]
		if not tb then
			tb = {
				Beaten = false;
				Seen = false;
				Accessible = false;
				AttemptCount = 0;
			}
			mNodeStatus[id] = tb
		end
		return tb
	end
	
	function this:ProcessBeatTutorial()
		local nodeHqDef = Netmap.ById['hq']
		local myNodeHq = mNodeStatus['hq']
		if myNodeHq.Beaten then
			warn("ServerPlayerData | User tried to beat tutorial again??")
			return false
		end
		myNodeHq.Beaten = true
		for _, adj in pairs(nodeHqDef.Links) do
			local status = getNodeStatus(adj)
			status.Accessible = true
			status.Seen = true
			-- Automatically beat revealed Warez nodes
			if Netmap.ById[adj].Warez then
				status.Beaten = true
			end
		end
		mCredits = mCredits + Places.tutorial.CreditReward
		return true
	end	
	
	local function processTriggers(nodeId)
		local nodeDef = Netmap.ById[nodeId]
		local conversation = nodeDef.Conversation
		if conversation and conversation.Function then
			-- Process the result
			local f = conversation.Function
			if f.Type == 'revealNode' then
				getNodeStatus(f.Id).Seen = true
			elseif f.Type == 'upgradeSecurity' then
				mSecurityLevel = f.Level
			elseif f.Type == 'getProgram' then
				addUnit(f.Id)
			elseif f.Type == 'getCredits' then
				mCredits = mCredits + f.Amount
			elseif f.Type == 'beginNightfall' then
				mSecurityLevel = 5
				-- TODO:
			elseif f.Type == 'endNightfall' then
				-- TODO:
			else
				error("Bad function type: "..tostring(f.Type))
			end
		end
	end
	
	local function setNodeBeaten(nodeId)
		local node = getNodeStatus(nodeId)
		if node.Beaten then
			print("ServerPlayerData: Node already beaten")
		else
			print("ServerPlayerData: Updating nodes")
			node.Beaten = true
			for _, adjId in pairs(Netmap.ById[nodeId].Links) do
				local adjNode = getNodeStatus(adjId)
				adjNode.Seen = true
				adjNode.Accessible = true
				-- Automatically beat revealed Warez nodes
				if Netmap.ById[adjId].Warez then
					adjNode.Beaten = true
				end
			end
			
			processTriggers(nodeId)
		end		
	end
	
	-- Add the stats for the replay to the stats tracking for the user,
	-- such as number of attempts and best attempt on the level
	local function processStats(replayString, replayResult)
		local DataStoreService = require(game.ServerScriptService.DataStoreService)
		
		-- Add an attempt to our player data
		local data = getNodeStatus(replayResult.NodeId)
		data.AttemptCount = data.AttemptCount + 1
		
		-- If this is a win, and we don't have a recorded replay for the node yet
		-- then record it. We have to record a replay Id only because there isn't
		-- space for all the nodes replays in the single player data key.
		if replayResult.Won and not data.WinningPlayId then
			-- Note, this returns right away
			data.WinningPlayId = DataStoreService:SaveReplay(replayString)
		end

		-- Update the overall node stats synchronously
		-- Do this synchronously because it's worse to potentially lose new record
		-- plays on a node than lose passes by a player.
		local firstTime = (data.AttemptCount == 1)
		DataStoreService:UpdateStatsForNode(
			replayResult.NodeId,
			playerId, 
			firstTime, 
			replayString, 
			replayResult)
	end
	
	function this:ProcessReplay(replayString)
		local result = ReplayChecker:Check(replayString, GameState.ServerDelayFunc)
		if result.Valid then
			-- Potentially process triggers for the node
			if result.Won then
				print("ServerPlayerData: Won replay")
				-- Give them the credits
				mCredits = mCredits + result.Credits
				
				-- Mark the node as beaten
				setNodeBeaten(result.NodeId)
			else
				print("ServerPlayerData: Did not win replay")
			end
			
			-- Process aggregate statistics about plays on levels
			-- for the player and the node overall			
			processStats(replayString, result)
		else
			warn("ServerPlayerData | Got invalid replay from "..playerId)
			print(replayString)
		end
		return result
	end
	
	function this:ProcessPurchase(warezId, programId)
		local node = Netmap.ById[warezId]
		if not node.Warez then
			warn("ServerPlayerData | "..playerId.." tried to purchase from non-Warez node "..warezId)
			return false
		end
		local price = node.Warez[programId]
		if not price then
			warn("ServerPlayerData | "..playerId.." tried to purchase "..programId.." from node "..warezId.." that doesn't have it.")
			return false
		end
		if mCredits < price then
			warn("ServerPlayerData | "..playerId.." tried to purchase program "..programId.." for "..price.." when only having "..mCredits.." credits.")
			return false
		end
		
		-- Success, actualy buy the program
		mCredits = mCredits - price
		addUnit(programId)
	end
	
	function this:HasProcessedPurchase(purchaseId)
		for _, id in pairs(mSkipPurchaseIds) do
			if id == purchaseId then
				return true
			end
		end
		return false
	end
	
	function this:AddSkips(purchaseId, amount)
		table.insert(mSkipPurchaseIds, purchaseId)
		mSkipsPurchased = mSkipsPurchased + amount
	end
	
	function this:GetSkipsPurchased()
		return mSkipsPurchased
	end
	
	function this:HasBeatenTutorial()
		return mNodeStatus.hq.Beaten
	end
	
	function this:SkipLevel(nodeId)
		local found = false
		for _, usedSkip in pairs(mSkipsUsed) do
			if usedSkip == nodeId then
				found = true
			end
		end
		if found then
			warn("ServerPlayerData | "..playerId.." tried to skip node "..nodeId.." twice.")
			return false
		end
		if #mSkipsUsed >= mSkipsPurchased then
			warn("ServerPlayerData | "..playerId.." tried to use a skip they don't have.")
			return false
		end
		table.insert(mSkipsUsed, nodeId)
		setNodeBeaten(nodeId)
		return true
	end
	
	return this
end

return ServerPlayerData
