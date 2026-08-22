local Signal = require(game.ReplicatedStorage.Signal)
local Netmap = require(game.ReplicatedStorage.Netmap)
local Scripts = require(game.ReplicatedStorage.Scripts)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local LocalPlayerData = {}

LocalPlayerData.SkipsChanged = Signal.new()

local mNodeInfo = nil
local mUnitInventory = nil
local mCredits = nil
local mSettings = nil
local mSecurityLevel = nil
local mSkipsUsed = nil
local mSkipsAvailable = nil

local mIsFirstTimeUser = nil

-- Beat a node
function LocalPlayerData:SetNodeBeaten(id)
	print("Set node beaten:", id)
	mNodeInfo[id].Beaten = true
	for _, adjId in pairs(Netmap.ById[id].Links) do
		mNodeInfo[adjId].Accessible = true
		mNodeInfo[adjId].Seen = true
	end
end

-- Yielding function, wait for loaded from server
function LocalPlayerData:Load()
	print("Loading")
	local data = game.ReplicatedStorage.Remotes.Load:InvokeServer()
	if not data then
		print("Failed to load player data")
		return false
	end		
	
	mNodeInfo = data.NodeStatus or error("Missing node status")
	mCredits = data.Credits or error("Missing credits")
	mSecurityLevel = data.SecurityLevel or error("Missing security level")
	mUnitInventory = data.Units or error("Missing inventory")
	-- (was `#data.SkipsUsed or error(...)`: the `or` bound to the length
	-- result, so a missing list threw a raw length-of-nil error instead)
	mSkipsUsed = #(data.SkipsUsed or error("Missing skips used"))
	mSkipsAvailable = (data.SkipsPurchased or 0) - mSkipsUsed
	
	mIsFirstTimeUser = data.IsFirstTimeUser
	mSettings = data.Settings

	-- Fill in the missing nodes	
	for id, node in pairs(Netmap.ById) do
		if not mNodeInfo[id] then
			mNodeInfo[id] = {
				Beaten = false;
				Seen = false;
				Accessible = false;
			}
		end
	end
	
	-- Hook up listening for skips
	game.ReplicatedStorage.Remotes.PurchaseSkip.OnClientEvent:connect(function(amount)
		LocalPlayerData:AddSkips(amount)
	end)
	
	print("Loaded")
	
	-- Skips have been loaded
	LocalPlayerData.SkipsChanged:fire()
	
	return true
end

-- Modify skips
function LocalPlayerData:AddSkips(amount)
	mSkipsAvailable = mSkipsAvailable + amount
	LocalPlayerData.SkipsChanged:fire()
end
function LocalPlayerData:UseSkip()
	mSkipsAvailable = mSkipsAvailable - 1
	LocalPlayerData.SkipsChanged:fire()
end
-- Persisted client preference settings ({SoundVolume, MusicVolume}), nil
-- until loaded
function LocalPlayerData:GetSettings()
	return mSettings
end

function LocalPlayerData:GetSkips()
	return mSkipsAvailable, mSkipsUsed
end

-- Get how many credits the player has
function LocalPlayerData:GetCredits()
	return mCredits
end
function LocalPlayerData:AddCredits(amount)
	mCredits = mCredits + amount
end

-- Get the list of programs available
function LocalPlayerData:GetProgramList()
	return mUnitInventory
end

-- Has the player beaten a given node
function LocalPlayerData:HasBeatenNode(id)
	if DebugFlags:HasBeatenAllNodes() then
		return true
	else
		return mNodeInfo[id].Beaten
	end
end

-- Has the player seen a given node?
function LocalPlayerData:HasSeenNode(id)
	if DebugFlags:HasBeatenAllNodes() then
		return true
	else
		-- Normalized to a real boolean: callers assign this into boolean
		-- instance properties
		return (mNodeInfo[id].Seen or mNodeInfo[id].Warez) and true or false
	end
end

-- Reveal a node somewhere in the netmap
function LocalPlayerData:RevealNode(id)
	mNodeInfo[id].Seen = true
end

-- Can the player access a given node?
function LocalPlayerData:CanAccessNode(id)
	if DebugFlags:HasBeatenAllNodes() then
		return true
	else
		return mNodeInfo[id].Accessible and Netmap.ById[id].Level <= mSecurityLevel
	end
end

-- Does the player have a direct link to the node (an adjacent beaten node),
-- regardless of whether their security level suffices?
function LocalPlayerData:HasLinkToNode(id)
	if DebugFlags:HasBeatenAllNodes() then
		return true
	else
		return mNodeInfo[id].Accessible
	end
end

-- Record a finished (started, non-skipped) battle attempt locally, mirroring
-- what the server records from the replay, so the stats panel is fresh
-- within the session. stats = GameState:GetPlayStats() when won.
function LocalPlayerData:RecordNodeAttempt(id)
	local info = mNodeInfo[id]
	if info then
		info.AttemptCount = (info.AttemptCount or 0) + 1
	end
end
-- The client-known personal bests for a node ({Turns, Moves, Units}), or
-- nil before the first recorded win (skip-beaten nodes have none)
function LocalPlayerData:GetNodeBests(id)
	local info = mNodeInfo[id]
	if info and info.BestTurns then
		return {
			Turns = info.BestTurns,
			Moves = info.BestMoves,
			Units = info.BestUnits,
		}
	end
	return nil
end

function LocalPlayerData:RecordNodeCompletion(id, stats)
	local info = mNodeInfo[id]
	if not info then
		return
	end
	info.AttemptCount = (info.AttemptCount or 0) + 1
	info.Wins = (info.Wins or 0) + 1
	if not info.BestTurns or stats.Turns < info.BestTurns then
		info.BestTurns = stats.Turns
	end
	if not info.BestMoves or stats.Moves < info.BestMoves then
		info.BestMoves = stats.Moves
	end
	if not info.BestUnits or stats.Units < info.BestUnits then
		info.BestUnits = stats.Units
	end
end

-- Aggregated progression/battle statistics for the menu's stats panel
function LocalPlayerData:GetProgressStats()
	local stats = {
		BattleNodesTotal = 0,
		BattleNodesBeaten = 0,
		Wins = 0,
		Attempts = 0,
		-- { Id, BestTurns?, BestMoves?, BestUnits?, Wins, Attempts } for
		-- every node with any history (bests only present after a replay
		-- win; a node beaten via skip has none)
		Nodes = {},
	}
	for id, node in pairs(Netmap.ById) do
		if not node.Warez then
			stats.BattleNodesTotal += 1
			local info = mNodeInfo[id]
			if info then
				if info.Beaten then
					stats.BattleNodesBeaten += 1
				end
				stats.Wins += info.Wins or 0
				stats.Attempts += info.AttemptCount or 0
				if info.Beaten or info.BestTurns or (info.AttemptCount or 0) > 0 then
					table.insert(stats.Nodes, {
						Id = id,
						BestTurns = info.BestTurns,
						BestMoves = info.BestMoves,
						BestUnits = info.BestUnits,
						Wins = info.Wins or 0,
						Attempts = info.AttemptCount or 0,
					})
				end
			end
		end
	end
	table.sort(stats.Nodes, function(a, b)
		return a.Id < b.Id
	end)
	return stats
end

-- Add a program to the inventory
function LocalPlayerData:AddUnit(id)
	for _, dat in pairs(mUnitInventory) do
		if dat.Id == id then
			dat.Count = dat.Count + 1
			return
		end
	end
	table.insert(mUnitInventory, {
		Id = id;
		Count = 1;
	})
end

-- Debug checkpoint: jump the local progression to the first entry of the
-- given security level — every lower-level battle node beaten (with its
-- credit reward banked), adjacency revealed, warez shops open. Client-side
-- only; intended for the DebugFlags:ShowDebugCheckpoints() title-screen
-- picker.
function LocalPlayerData:ApplyDebugCheckpoint(level)
	local Places = require(game.ReplicatedStorage.Places)

	mSecurityLevel = level

	-- Beat every battle node below the target level
	for id, node in pairs(Netmap.ById) do
		if not node.Warez and node.Level < level then
			local info = mNodeInfo[id]
			if not info.Beaten then
				info.Beaten = true
				local place = Places[node.PlaceId]
				if place and place.CreditReward then
					mCredits = mCredits + place.CreditReward
				end
			end
			info.Seen = true
			info.Accessible = true
		end
	end

	-- Reveal neighbors of everything beaten
	for id, node in pairs(Netmap.ById) do
		if mNodeInfo[id].Beaten then
			for _, adjId in pairs(node.Links) do
				mNodeInfo[adjId].Seen = true
				mNodeInfo[adjId].Accessible = true
			end
		end
	end

	-- Revealed warez shops count as beaten (matching normal progression)
	for id, node in pairs(Netmap.ById) do
		if node.Warez and mNodeInfo[id].Seen then
			mNodeInfo[id].Beaten = true
		end
	end

	-- Stock up: one of every script sold at the PREVIOUS security level's
	-- warez shops, approximating the loadout a player would arrive with
	for id, node in pairs(Netmap.ById) do
		if node.Warez and node.Level == level - 1 then
			for unitId, _cost in pairs(node.Warez) do
				self:AddUnit(unitId)
			end
		end
	end
end

-- Security level
function LocalPlayerData:SetSecurityLevel(level)
	mSecurityLevel = level
end

function LocalPlayerData:GetSecurityLevel()
	return mSecurityLevel
end

-- Nightfall is live between the booby-trapped node springing it (the
-- beginNightfall trigger raises the security level to 5) and Dignity's
-- final node being beaten. Derived rather than stored, so it needs no
-- save-data field and stays correct on rejoin.
function LocalPlayerData:IsNightfallActive()
	return mSecurityLevel >= 5 and not self:HasBeatenNode('end')
end

return LocalPlayerData
