local Copy = require(game.ReplicatedStorage.Copy)
local Scripts = require(game.ReplicatedStorage.Scripts)
local Netmap = require(game.ReplicatedStorage.Netmap)
local ServerStatistics = require(game.ServerScriptService.ServerStatistics)
local BadgeAwarder = require(game.ServerScriptService.BadgeAwarder)
local ReplayChecker = require(game.ServerScriptService.ReplayChecker)
local GameState = require(game.ReplicatedStorage.GameState)
local Places = require(game.ReplicatedStorage.Places)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local ServerPlayerData = {}

function ServerPlayerData.new(player, serialized)
	local this = {}

	-- Identity: the domain-scoped User string keys stats records; the label
	-- is only for log output
	local mUserKey = player.User:ToString()
	local mPlayerLabel = player.Name .. " (" .. player.UserId .. ")"
	
	local mCredits;
	local mSecurityLevel;
	local mSettings;
	local mUnitInventory;
	local mNodeStatus;	
	local mSkipsPurchased;
	local mSkipPurchaseIds;
	local mSkipsUsed;
	
	local mIsFirstTimeUser;
	
	if serialized then
		mNodeStatus = Copy.Deep(serialized.NodeStatus)
		mCredits = serialized.Credits
		if DebugFlags:LotsOfCredits() then
			-- Debug: top existing saves up too, not just fresh data. NOTE:
			-- the boosted balance persists on the next save, so don't flip
			-- this on against a real datastore save you care about.
			mCredits = math.max(mCredits, DebugFlags:GetInitialCredits())
		end
		mSecurityLevel = serialized.SecurityLevel
		mUnitInventory = Copy.Deep(serialized.Units)
		mSkipsPurchased = serialized.SkipsPurchased or 0
		mSkipsUsed = Copy.Deep(serialized.SkipsUsed or {})
		mSkipPurchaseIds = Copy.Deep(serialized.SkipPurchaseIds or {})
		mSettings = Copy.Deep(serialized.Settings or { SoundVolume = 1, MusicVolume = 1 })
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
		mSettings = { SoundVolume = 1, MusicVolume = 1 }
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
		tb.Settings = Copy.Deep(mSettings)
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

	-- Client preference settings (volumes, netmap camera). Fields MERGE so a
	-- partial payload never clobbers the others. Returns whether anything
	-- changed (the caller only saves when it did).
	local kSettingsFields = {
		{ Key = "SoundVolume", Min = 0, Max = 3 },
		{ Key = "MusicVolume", Min = 0, Max = 3 },
		{ Key = "NetmapX", Min = -1000, Max = 1000 },
		{ Key = "NetmapZ", Min = -1000, Max = 1000 },
		-- Range covers the FOV-30 zoom band (65-163) with slack; old FOV-10
		-- era saves (200-500) still pass and get clamped client-side
		{ Key = "NetmapZoom", Min = 40, Max = 500 },
		-- Battle pacing: 0 slow (original), 1 medium, 2 fast
		{ Key = "GameSpeed", Min = 0, Max = 2 },
	}
	function this:ProcessSaveSettings(settings)
		if type(settings) ~= "table" then
			return false
		end
		local changed = false
		for _, field in pairs(kSettingsFields) do
			local value = settings[field.Key]
			if type(value) == "number" then
				value = math.clamp(value, field.Min, field.Max)
				if mSettings[field.Key] ~= value then
					mSettings[field.Key] = value
					changed = true
				end
			end
		end
		return changed
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
		BadgeAwarder:Award(player, "PluggedIn")
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
				ServerStatistics:SecurityLevelReached(player, f.Level)
				if f.Level >= 2 and f.Level <= 5 then
					BadgeAwarder:Award(player, "SecurityClearance" .. f.Level)
				end
			elseif f.Type == 'getProgram' then
				addUnit(f.Id)
			elseif f.Type == 'getCredits' then
				mCredits = mCredits + f.Amount
				ServerStatistics:CreditsEarned(player, f.Amount, mCredits, "StoryReward")
			elseif f.Type == 'beginNightfall' then
				-- Nightfall's arrival is the level 5 "upgrade". The nightfall
				-- state itself needs no save field: it's derived from the
				-- level + the final node's beaten flag (both saved here), see
				-- LocalPlayerData:IsNightfallActive
				mSecurityLevel = 5
				ServerStatistics:SecurityLevelReached(player, 5)
				BadgeAwarder:Award(player, "SecurityClearance5")
			elseif f.Type == 'endNightfall' then
				-- Ending nightfall is fully derived too ('end' becomes beaten)
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

			-- Completion badges
			if nodeId == 'end' then
				BadgeAwarder:Award(player, "MidnightAverted")
			end
			local allBeaten = true
			for id, def in pairs(Netmap.ById) do
				if not def.Warez and not (mNodeStatus[id] and mNodeStatus[id].Beaten) then
					allBeaten = false
					break
				end
			end
			if allBeaten then
				BadgeAwarder:Award(player, "NodeSweeper")
			end
		end
	end
	
	-- Add the stats for the replay to the stats tracking for the user,
	-- such as number of attempts and best attempt on the level
	-- securityLevelAtBattle: the level BEFORE this win's triggers, so a win
	-- that itself upgrades security still counts as played at the old level
	local function processStats(replayString, replayResult, securityLevelAtBattle)
		local DataStoreService = require(game.ServerScriptService.DataStoreService)
		
		-- Add an attempt to our player data
		local data = getNodeStatus(replayResult.NodeId)
		data.AttemptCount = data.AttemptCount + 1

		-- Per-node personal records (persisted with the node status), and the
		-- set of stats that improved for the record leaderboards
		if replayResult.Won then
			data.Wins = (data.Wins or 0) + 1
			local improved = {}
			if not data.BestTurns or replayResult.TurnCount < data.BestTurns then
				data.BestTurns = replayResult.TurnCount
				improved.turns = replayResult.TurnCount
			end
			if not data.BestMoves or replayResult.MoveCount < data.BestMoves then
				data.BestMoves = replayResult.MoveCount
				improved.moves = replayResult.MoveCount
			end
			if not data.BestUnits or replayResult.UnitCount < data.BestUnits then
				data.BestUnits = replayResult.UnitCount
				improved.units = replayResult.UnitCount
			end
			if next(improved) then
				-- World-record check against the pre-write leaderboard values
				local isWorldRecord = false
				for stat, value in pairs(improved) do
					local worldValue = DataStoreService:GetWorldRecord(replayResult.NodeId, stat)
					if not worldValue or value < worldValue then
						isWorldRecord = true
					end
				end
				if isWorldRecord then
					BadgeAwarder:Award(player, "WorldRecordHolder")
				end
				DataStoreService:UpdateNodeRecords(replayResult.NodeId, player.UserId, improved)
			end

			-- Skill and flavor badges for the winning play
			BadgeAwarder:EvaluateWinBadges(player, replayResult, data.AttemptCount, securityLevelAtBattle)
		end
		
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
			mUserKey, 
			firstTime, 
			replayString, 
			replayResult)
	end
	
	function this:ProcessReplay(replayString)
		-- The replay string is client-provided: a malformed one must read as
		-- invalid, not throw out of the remote handler
		local st, result = pcall(function()
			return ReplayChecker:Check(replayString, GameState.ServerDelayFunc)
		end)
		if not st then
			warn("ServerPlayerData | Replay from "..mPlayerLabel.." threw while checking: "..tostring(result))
			result = { Valid = false, FailureReason = "Threw: " .. tostring(result) }
		end
		if result.Valid then
			-- The security level the battle was fought at (a winning node's
			-- triggers below may raise it)
			local securityLevelAtBattle = mSecurityLevel
			-- Potentially process triggers for the node
			if result.Won then
				print("ServerPlayerData: Won replay")
				-- Give them the credits
				mCredits = mCredits + result.Credits
				ServerStatistics:CreditsEarned(player, result.Credits, mCredits, "BattleReward")

				-- Mark the node as beaten
				setNodeBeaten(result.NodeId)
			else
				print("ServerPlayerData: Did not win replay")
			end
			
			-- Process aggregate statistics about plays on levels
			-- for the player and the node overall
			processStats(replayString, result, securityLevelAtBattle)
		else
			-- Persist the failing replay: the checker is deterministic, so
			-- the stored string re-runs the exact divergence in a spec. The
			-- key doubles as the replay id on the InvalidReplay analytics
			-- event (see NetworkController). warn (not print) both lines so
			-- live error reports capture the repro.
			-- Lazy require, matching processStats above (DataStoreService is
			-- deliberately not a module-level require here)
			local DataStoreService = require(game.ServerScriptService.DataStoreService)
			result.FailedReplayKey = DataStoreService:SaveFailedReplay({
				Replay = replayString,
				Reason = result.FailureReason or "Unknown",
				UserId = player.UserId,
				Name = player.Name,
				Time = os.time(),
			})
			warn("ServerPlayerData | Got invalid replay from "..mPlayerLabel
				.." ("..tostring(result.FailureReason)..") saved as "..result.FailedReplayKey)
			-- print, NOT warn: every replay string is unique, so warning it
			-- would spawn one error-report entry per rejection. The store
			-- holds the string under the key warned above; this is just a
			-- live-console fallback in case that write fails.
			print(replayString)
		end
		return result
	end
	
	function this:ProcessPurchase(warezId, programId)
		-- Both ids are client-provided
		local node = Netmap.ById[warezId]
		if not node or not node.Warez then
			warn("ServerPlayerData | "..mPlayerLabel.." tried to purchase from non-Warez node "..tostring(warezId))
			return false
		end
		local price = node.Warez[programId]
		if not price then
			warn("ServerPlayerData | "..mPlayerLabel.." tried to purchase "..programId.." from node "..warezId.." that doesn't have it.")
			return false
		end
		if mCredits < price then
			warn("ServerPlayerData | "..mPlayerLabel.." tried to purchase program "..programId.." for "..price.." when only having "..mCredits.." credits.")
			return false
		end
		
		-- Success, actualy buy the program
		mCredits = mCredits - price
		addUnit(programId)
		ServerStatistics:UnitPurchased(player, programId, price, mCredits)

		-- Purchase badges (ConsumerGrade + FullyLoaded vs the purchasable set)
		BadgeAwarder:EvaluatePurchaseBadges(player, mUnitInventory)
		return true
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
		-- Client-provided id: don't let a bad one throw in getNodeStatus
		if not Netmap.ById[nodeId] then
			warn("ServerPlayerData | "..mPlayerLabel.." tried to skip unknown node "..tostring(nodeId))
			return false
		end
		local found = false
		for _, usedSkip in pairs(mSkipsUsed) do
			if usedSkip == nodeId then
				found = true
			end
		end
		if found then
			warn("ServerPlayerData | "..mPlayerLabel.." tried to skip node "..nodeId.." twice.")
			return false
		end
		if #mSkipsUsed >= mSkipsPurchased then
			warn("ServerPlayerData | "..mPlayerLabel.." tried to use a skip they don't have.")
			return false
		end
		table.insert(mSkipsUsed, nodeId)
		setNodeBeaten(nodeId)
		return true
	end
	
	return this
end

return ServerPlayerData
