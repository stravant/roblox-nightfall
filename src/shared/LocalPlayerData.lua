local Signal = require(game.ReplicatedStorage.Signal)
local Netmap = require(game.ReplicatedStorage.Netmap)
local Scripts = require(game.ReplicatedStorage.Scripts)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local LocalPlayerData = {}

LocalPlayerData.SkipsChanged = Signal.new()

local mNodeInfo = nil
local mUnitInventory = nil
local mCredits = nil
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
		return mNodeInfo[id].Seen or mNodeInfo[id].Warez
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

-- Security level
function LocalPlayerData:SetSecurityLevel(level)
	mSecurityLevel = level
end

function LocalPlayerData:GetSecurityLevel()
	return mSecurityLevel
end

return LocalPlayerData
