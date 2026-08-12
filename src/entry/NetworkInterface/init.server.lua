
local MarketplaceService = game:GetService('MarketplaceService')

local DataStoreService = require(game.ServerScriptService.DataStoreService)
local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
local ReplayChecker = require(game.ServerScriptService.ReplayChecker)
local GameState = require(game.ReplicatedStorage.GameState)
local DeveloperProduct = require(game.ReplicatedStorage.DeveloperProduct)
local ServerStatistics = require(game.ServerScriptService.ServerStatistics)

local Scripts = require(game.ReplicatedStorage.Scripts)
local Netmap = require(game.ReplicatedStorage.Netmap)
local OnboardingSteps = require(game.ReplicatedStorage.OnboardingSteps)

local Remotes = game.ReplicatedStorage.Remotes

local PlayerDataCache = {}

-- Client-reported onboarding funnel detail steps. Only whitelisted step
-- numbers are accepted; Roblox itself dedupes repeats and backfills skips.
Remotes.FunnelStep.OnServerEvent:connect(function(player, step)
	if type(step) ~= "number" or not OnboardingSteps.ClientReportable[step] then
		return
	end
	ServerStatistics:OnboardingStep(player, step)
end)

Remotes.BeatTutorial.OnServerEvent:connect(function(player)
	-- Get the player data if it exist
	local playerData = PlayerDataCache[player]
	if not playerData then
		warn("NetworkInterface | Missing PlayerData for "..player.UserId.." to beat tutorial.")
		return
	end
	
	-- Process
	local result = playerData:ProcessBeatTutorial()

	-- If we successfully processed it, save
	if result then
		ServerStatistics:PlayerBeatTutorial(player)
		DataStoreService:SavePlayerDataAsync(player, playerData)
	end
end)

script.Check.Changed:connect(function()
	local result = ReplayChecker:Check(script.Check.Value, GameState.ServerDelayFunc)
	print("Checking, valid=", result.Valid, "won=", result.Won)
end)

Remotes.ProcessReplay.OnServerEvent:connect(function(player, replayStr)
	-- Client-provided: a non-string would throw in the concats/parsing below
	if type(replayStr) ~= "string" then
		warn("NetworkInterface | Non-string replay from "..player.UserId)
		return
	end
	local playerData = PlayerDataCache[player]
	if not playerData then
		-- Notify of fail
		warn("NetworkInterface | Missing PlayerData for "..player.UserId.." to submit a replay.")
		Remotes.ProcessReplay:FireClient(player, false)
		return
	end
	
	print("Processing replay: "..replayStr)
	
	-- Process it. Note that this will yield until the play is fully processed
	local result = playerData:ProcessReplay(replayStr)
	
	-- Stat tracking
	if result.Valid then
		if not result.EarlyQuit then
			ServerStatistics:PlayerPlayedLevel(player, result.NodeId, result.Won)
		else
			ServerStatistics:PlayerQuitLevelEarly(player, result.NodeId)
		end
	else
		ServerStatistics:PlayerCheated(player)
	end
	
	-- Let the client know we finished processing it
	Remotes.ProcessReplay:FireClient(player, result.Valid)
	
	-- If we successfully processed it, save
	if result.Valid then
		print("Replay was good, saving player data")
		DataStoreService:SavePlayerDataAsync(player, playerData)		
	end
end)

Remotes.SkipLevel.OnServerEvent:connect(function(player, nodeId)
	-- Check param
	if type(nodeId) ~= "string" or not Netmap.ById[nodeId] then
		warn("NetworkInterface | Bad nodeId `"..tostring(nodeId).."` from player "..player.UserId)
		return
	end

	-- Get the player data if it exists
	local playerData = PlayerDataCache[player]
	if not playerData then
		warn("NetworkInterface | Missing PlayerData for "..player.UserId.." to skip node "..nodeId)
		return
	end

	-- Process
	local result = playerData:SkipLevel(nodeId)

	-- Save the player data
	if result then
		ServerStatistics:PlayerSkippedLevel(player, nodeId)
		DataStoreService:SavePlayerDataAsync(player, playerData)
	end
end)

Remotes.PurchaseUnit.OnServerEvent:connect(function(player, warezId, programId)
	-- Check for invalid parameters
	if type(warezId) ~= "string" or type(programId) ~= "string" then
		warn("NetworkInterface | Non-string purchase args from player "..player.UserId)
		return
	end
	if not Netmap.ById[warezId] then
		warn("NetworkInterface | Bad warezId `"..tostring(warezId).."` from player "..player.UserId)
		return
	end
	if not Scripts[programId] then
		warn("NetworkInterface | Bad programId `"..tostring(programId).."` from player "..player.UserId)
		return
	end

	-- Get the player data if it exist
	local playerData = PlayerDataCache[player]
	if not playerData then
		warn("NetworkInterface | Missing PlayerData for "..player.UserId.." to purchase "..programId.." from "..warezId)
		return
	end
	
	-- Process the purchase (economy analytics are logged inside, where the
	-- price and resulting balance are known)
	local result = playerData:ProcessPurchase(warezId, programId)

	-- Save the player data
	if result then
		DataStoreService:SavePlayerDataAsync(player, playerData)
	end
end)

Remotes.Load.OnServerInvoke = function(player)
	local success, playerData = DataStoreService:LoadPlayerDataAsync(player)
	if success then
		-- New player
		if not playerData then
			playerData = ServerPlayerData.new(player)
		end
		
		-- If they're still in the game, cache the data
		if player.Parent ~= nil then
			PlayerDataCache[player] = playerData
		end
		
		-- Record the stat
		ServerStatistics:PlayerJoined(player, playerData:IsNewPlayer())
		
		-- Return it
		return playerData:Serialize(--[[forClient=]]true)
	else
		ServerStatistics:PlayerLoadFailed(player)
		return nil
	end	
end

game.Players.PlayerRemoving:connect(function(player)
	local playerData = PlayerDataCache[player]
	if playerData then
		ServerStatistics:PlayerLeft(player, playerData:HasBeatenTutorial())
		PlayerDataCache[player] = nil
	else
		ServerStatistics:PlayerBounced(player)
	end
end)

game:BindToClose(function()
	DataStoreService:WaitForSavesToComplete()
end)

function MarketplaceService.ProcessReceipt(info)
	local playerId = info.PlayerId
	
	-- Get player
	local player = game.Players:GetPlayerByUserId(playerId)
	if not player then
		warn("NetworkInterface | ProcessReceipt for player "..playerId.." who is not in game.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- Get player data
	local playerData = PlayerDataCache[player]
	if not playerData then
		warn("NetworkInterface | ProcessReceipt missing player data for "..playerId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- See if we've processed the purchase
	local purchaseId = info.PurchaseId
	if playerData:HasProcessedPurchase(purchaseId) then
		warn("NetworkInterface | ProcessReceipt already processed purchase "..purchaseId.." by player "..playerId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	-- Figure out what we purchased
	local productId = info.ProductId
	local amount;
	if productId == DeveloperProduct.Skip1 then
		amount = 1
	elseif productId == DeveloperProduct.Skip3 then
		amount = 3
	elseif productId == DeveloperProduct.Skip5 then
		amount = 5
	else
		warn("NetworkInterface | ProcessReceipt for unknown product "..productId.." by player "..playerId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- Process the purchase
	playerData:AddSkips(purchaseId, amount)

	-- Notify the client
	Remotes.PurchaseSkip:FireClient(player, amount)

	-- Save the changes
	local saved = DataStoreService:SavePlayerDataAsync(player, playerData)

	-- Save stat
	ServerStatistics:PlayerBoughtSkips(player, amount)

	-- Only tell Roblox the purchase is done once it's durably recorded; on a
	-- failed save the receipt retries later and HasProcessedPurchase dedupes
	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end
