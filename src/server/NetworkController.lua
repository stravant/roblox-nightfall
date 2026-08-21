-- All of the game's server network handlers. The NetworkInterface entry
-- script installs this onto the real ReplicatedStorage.Remotes; integration
-- tests install it onto mock remote objects instead and drive the handlers
-- exactly like a client would. Roblox services are fetched through the
-- Services locator so tests can mock them.

local Services = require(game.ReplicatedStorage.Services)

local MarketplaceService = Services:Get('MarketplaceService')
local PlayersService = Services:Get('Players')

local BadgeService = Services:Get('BadgeService')

local DataStoreService = require(game.ServerScriptService.DataStoreService)
local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
local BadgeAwarder = require(game.ServerScriptService.BadgeAwarder)
local JourneyService = require(game.ServerScriptService.JourneyService)
local Badges = require(game.ReplicatedStorage.Badges)
local DeveloperProduct = require(game.ReplicatedStorage.DeveloperProduct)
local ServerStatistics = require(game.ServerScriptService.ServerStatistics)

local Scripts = require(game.ReplicatedStorage.Scripts)
local Netmap = require(game.ReplicatedStorage.Netmap)
local OnboardingSteps = require(game.ReplicatedStorage.OnboardingSteps)

local NetworkController = {}

-- remotes: the ReplicatedStorage.Remotes folder in production, or a table of
-- mock remote objects in tests
function NetworkController.install(remotes)
	local PlayerDataCache = {}

	-- Session journey recording (the UX study tool)
	JourneyService.install(remotes)

	-- Client-reported onboarding funnel detail steps. Only whitelisted step
	-- numbers are accepted; Roblox itself dedupes repeats and backfills skips.
	remotes.FunnelStep.OnServerEvent:connect(function(player, step)
		if type(step) ~= "number" or not OnboardingSteps.ClientReportable[step] then
			return
		end
		ServerStatistics:OnboardingStep(player, step)
	end)

	remotes.BeatTutorial.OnServerEvent:connect(function(player)
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

	remotes.ProcessReplay.OnServerEvent:connect(function(player, replayStr)
		-- Client-provided: a non-string would throw in the concats/parsing below
		if type(replayStr) ~= "string" then
			warn("NetworkInterface | Non-string replay from "..player.UserId)
			return
		end
		local playerData = PlayerDataCache[player]
		if not playerData then
			-- Notify of fail
			warn("NetworkInterface | Missing PlayerData for "..player.UserId.." to submit a replay.")
			remotes.ProcessReplay:FireClient(player, false)
			return
		end
	
		print("Processing replay: "..replayStr)
	
		-- Process it. Note that this will yield until the play is fully processed
		local result = playerData:ProcessReplay(replayStr)
	
		-- Stat tracking
		if result.Valid then
			if not result.EarlyQuit then
				ServerStatistics:PlayerPlayedLevel(player, result.NodeId, result.Won)
				-- One UnitUsed event per fielded unit, split by outcome.
				-- The tutorial's scripted fixed loadout is excluded: legit
				-- clients never submit a tutorial replay (the tutorial ends
				-- via BeatTutorial instead), but don't trust that here.
				if result.PlaceId ~= 'tutorial' then
					for _, unitId in pairs(result.UnitsUsed or {}) do
						ServerStatistics:UnitUsed(player, unitId, result.Won)
					end
				end
			else
				ServerStatistics:PlayerQuitLevelEarly(player, result.NodeId)
			end
		else
			ServerStatistics:PlayerCheated(player, result.FailedReplayKey, result.FailureReason,
				string.format("%s turns=%s len=%d",
					tostring(result.PlaceId), tostring(result.TurnCount), #tostring(replayStr)))
		end
	
		-- Let the client know we finished processing it
		remotes.ProcessReplay:FireClient(player, result.Valid)
	
		-- If we successfully processed it, save
		if result.Valid then
			print("Replay was good, saving player data")
			DataStoreService:SavePlayerDataAsync(player, playerData)		
		end
	end)

	remotes.SkipLevel.OnServerEvent:connect(function(player, nodeId)
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

	remotes.PurchaseUnit.OnServerEvent:connect(function(player, warezId, programId)
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

	-- Script placement gesture analytic (drag vs click flows). Whitelisted
	-- values; capped LOW per session so one marathon session can't skew the
	-- gesture split (and a spammy client can't burn the budget).
	local kPlacementMethods = { drag = true, clickUnit = true, clickZone = true }
	local kMaxPlacementReports = 10
	local PlacementReportCounts = {}
	remotes.PlacementMethod.OnServerEvent:connect(function(player, method)
		if type(method) ~= "string" or not kPlacementMethods[method] then
			return
		end
		local count = PlacementReportCounts[player] or 0
		if count >= kMaxPlacementReports then
			return
		end
		PlacementReportCounts[player] = count + 1
		ServerStatistics:PlacementMethod(player, method)
	end)

	-- Post-tutorial wrap-up choice, for the explore-vs-battle split chart.
	-- Whitelisted values, one report per player per session.
	local kPostTutorialChoices = { explore = true, battle = true }
	local PostTutorialChoiceReported = {}
	remotes.PostTutorialChoice.OnServerEvent:connect(function(player, choice)
		if type(choice) ~= "string" or not kPostTutorialChoices[choice] then
			return
		end
		if PostTutorialChoiceReported[player] then
			return
		end
		PostTutorialChoiceReported[player] = true
		ServerStatistics:PostTutorialChoice(player, choice)
	end)

	-- Client preference settings (volumes), stored with the save. The client
	-- throttles sends; the debounced save coalesces the writes.
	remotes.SaveSettings.OnServerEvent:connect(function(player, settings)
		local playerData = PlayerDataCache[player]
		if not playerData then
			return
		end
		if playerData:ProcessSaveSettings(settings) then
			DataStoreService:SavePlayerDataAsync(player, playerData)
		end
	end)

	remotes.Load.OnServerInvoke = function(player)
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

	--------------------------------------------------------------------------------
	-- Node record comparison (my best / best friend / world best)
	--------------------------------------------------------------------------------

	-- Cap on how many friends we check records for (each costs datastore reads)
	local kMaxFriendsChecked = 20

	-- Cached friends list per player: { {Id, Name}, ... }
	local FriendsCache = {}
	local function getFriends(player)
		local cached = FriendsCache[player]
		if cached then
			return cached
		end
		local friends = {}
		local st, err = pcall(function()
			local pages = PlayersService:GetFriendsAsync(player.User)
			for _, item in pages:GetCurrentPage() do
				if #friends >= kMaxFriendsChecked then
					break
				end
				table.insert(friends, { Id = item.Id, Name = item.DisplayName or item.Username })
			end
		end)
		if not st then
			warn("NetworkInterface | Failed to fetch friends for "..player.UserId..": "..tostring(err))
		end
		FriendsCache[player] = friends
		return friends
	end

	-- Cached username lookups for record holders
	local NameCache = {}
	local function nameForUserId(userId)
		if not userId then
			return nil
		end
		local name = NameCache[userId]
		if not name then
			local st, result = pcall(function()
				return PlayersService:GetNameFromUserIdAsync(userId)
			end)
			name = if st then result else "<unknown>"
			NameCache[userId] = name
		end
		return name
	end

	-- Per-player cache of assembled node records (the friend sweep is the
	-- expensive part; one assembly per node per session is plenty)
	local NodeRecordsCache = {}
	remotes.GetNodeRecords.OnServerInvoke = function(player, nodeId)
		if type(nodeId) ~= "string" or not Netmap.ById[nodeId] then
			return nil
		end
		NodeRecordsCache[player] = NodeRecordsCache[player] or {}
		local cached = NodeRecordsCache[player][nodeId]
		if cached then
			return cached
		end

		local result = { World = {}, Friend = {} }

		-- World records: the top of each ordered store
		for _, stat in pairs(DataStoreService.RecordStats) do
			local value, userId = DataStoreService:GetWorldRecord(nodeId, stat)
			if value then
				result.World[stat] = { Value = value, Name = nameForUserId(userId) }
			end
		end

		-- Friend records: best over the (capped) friends list. Friends who never
		-- won the node simply have no entry. The turns store doubles as the
		-- "has played" check: winners always have all three stats recorded.
		local friends = getFriends(player)
		for _, friend in pairs(friends) do
			local turns = DataStoreService:GetUserRecord(nodeId, "turns", friend.Id)
			if turns then
				local records = {
					turns = turns,
					moves = DataStoreService:GetUserRecord(nodeId, "moves", friend.Id),
					units = DataStoreService:GetUserRecord(nodeId, "units", friend.Id),
				}
				for stat, value in pairs(records) do
					local best = result.Friend[stat]
					if not best or value < best.Value then
						result.Friend[stat] = { Value = value, Name = friend.Name }
					end
				end
			end
		end

		NodeRecordsCache[player][nodeId] = result
		return result
	end

	--------------------------------------------------------------------------------
	-- Badge listing (no stored data: ownership and badge info come from the
	-- badge web APIs, cached server-side)
	--------------------------------------------------------------------------------

	-- Badge name/description/icon per badge id, cached for the server's
	-- lifetime (it's static product info). Failed fetches aren't cached so a
	-- flaky call retries on the next request.
	local BadgeInfoCache = {}
	local function getBadgeInfo(badgeId)
		local info = BadgeInfoCache[badgeId]
		if not info then
			local st, result = pcall(function()
				return BadgeService:GetBadgeInfoAsync(badgeId)
			end)
			if not st then
				warn("NetworkInterface | Failed to fetch badge info for "..badgeId..": "..tostring(result))
				return nil
			end
			info = {
				Name = result.Name,
				Description = result.Description,
				IconImageId = result.IconImageId,
			}
			BadgeInfoCache[badgeId] = info
		end
		return info
	end

	-- Ownership fetched once per player per session (chunked: the API takes at
	-- most 10 badge ids per call); badges awarded after that are unioned in
	-- from BadgeAwarder's session record, so the cache never goes stale.
	local BadgeOwnershipCache = {}
	local function getOwnedBadges(player)
		local cached = BadgeOwnershipCache[player]
		if cached then
			return cached
		end
		local ids = {}
		for _, badgeId in pairs(Badges.Ids) do
			if badgeId ~= 0 then
				table.insert(ids, badgeId)
			end
		end
		local owned = {}
		for i = 1, #ids, 10 do
			local chunk = table.move(ids, i, math.min(i + 9, #ids), 1, {})
			local st, result = pcall(function()
				return BadgeService:CheckUserBadgesAsync(player.UserId, chunk)
			end)
			if st then
				for _, badgeId in pairs(result) do
					owned[badgeId] = true
				end
			else
				warn("NetworkInterface | Failed to check badges for "..player.UserId..": "..tostring(result))
			end
		end
		BadgeOwnershipCache[player] = owned
		return owned
	end

	remotes.GetBadges.OnServerInvoke = function(player)
		local owned = getOwnedBadges(player)
		local sessionAwards = BadgeAwarder:GetSessionAwards(player)
		local result = { Total = 0, Earned = {}, Unearned = {} }
		for _, key in pairs(Badges.DisplayOrder) do
			local badgeId = Badges.Ids[key]
			if badgeId ~= 0 then
				result.Total += 1
				local info = getBadgeInfo(badgeId)
				local entry = {
					Key = key,
					Name = if info then info.Name else key,
					Description = if info then info.Description else "",
					IconImageId = if info then info.IconImageId else 0,
				}
				if owned[badgeId] or sessionAwards[key] then
					table.insert(result.Earned, entry)
				else
					table.insert(result.Unearned, entry)
				end
			end
		end
		return result
	end

	PlayersService.PlayerRemoving:connect(function(player)
		local playerData = PlayerDataCache[player]
		if playerData then
			ServerStatistics:PlayerLeft(player, playerData:HasBeatenTutorial())
			PlayerDataCache[player] = nil
		else
			ServerStatistics:PlayerBounced(player)
		end
		FriendsCache[player] = nil
		NodeRecordsCache[player] = nil
		BadgeOwnershipCache[player] = nil
		PostTutorialChoiceReported[player] = nil
		PlacementReportCounts[player] = nil
	end)

	function MarketplaceService.ProcessReceipt(info)
		local playerId = info.PlayerId
	
		-- Get player
		local player = PlayersService:GetPlayerByUserId(playerId)
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
		remotes.PurchaseSkip:FireClient(player, amount)

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
end

return NetworkController
