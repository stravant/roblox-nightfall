-- Integration test of the real server stack driven through the NETWORK
-- surface: the actual NetworkController handlers are installed onto mock
-- remotes and driven exactly like clients would drive them, down to real
-- (mock) DataStore requests, the social API, marketplace receipts, and
-- analytics.
--
-- IMPORTANT: mocks must be installed BEFORE the modules under test are first
-- required (they capture their services at require time), so the SetMock
-- calls run at the top of this spec body.
return function(t)
	local Services = require(game.ReplicatedStorage.Services)

	----------------------------------------------------------------------
	-- Service mocks
	----------------------------------------------------------------------

	local analyticsLog = {}
	-- Mirror the real AnalyticsService's restrictions so tests catch what
	-- the live service would reject: custom field values must not contain
	-- comma or quote characters, and must be at most 50 characters long.
	-- Violations accumulate and a final test asserts none happened anywhere
	-- in the run.
	local analyticsViolations = {}
	local function logEvent(kind)
		return function(_self, player, ...)
			for _, arg in pairs({ ... }) do
				if type(arg) == "table" then
					for key, value in pairs(arg) do
						if type(value) == "string" and (value:find("[,\"']") or #value > 50) then
							table.insert(analyticsViolations,
								kind .. " " .. tostring(key) .. " = `" .. value .. "`")
						end
					end
				end
			end
			table.insert(analyticsLog, { Kind = kind, Player = player, Args = { ... } })
		end
	end
	Services:SetMock("AnalyticsService", {
		LogOnboardingFunnelStepEvent = logEvent("onboarding"),
		LogProgressionStartEvent = logEvent("progressionStart"),
		LogProgressionCompleteEvent = logEvent("progressionComplete"),
		LogProgressionFailEvent = logEvent("progressionFail"),
		LogEconomyEvent = logEvent("economy"),
		LogCustomEvent = logEvent("custom"),
	})

	-- Players service: registry of mock players, a PlayerRemoving signal, and
	-- a friends graph
	local mockPlayers = {} -- userId -> mock player
	local friendsGraph = {} -- userId -> { {Id, Username, DisplayName} }
	local removingHandlers = {}
	Services:SetMock("Players", {
		PlayerRemoving = {
			connect = function(_self, fn)
				table.insert(removingHandlers, fn)
				return { Disconnect = function() end }
			end,
		},
		GetPlayerByUserId = function(_self, id)
			return mockPlayers[id]
		end,
		GetNameFromUserIdAsync = function(_self, id)
			return "User" .. tostring(id)
		end,
		GetFriendsAsync = function(_self, user)
			local list = friendsGraph[user.OwnerId] or {}
			return {
				GetCurrentPage = function()
					return list
				end,
			}
		end,
	})

	-- Marketplace: the controller assigns ProcessReceipt onto it
	local marketplaceMock = {}
	Services:SetMock("MarketplaceService", marketplaceMock)

	-- Deterministic GUIDs (used by the winning-replay archive)
	local guidCounter = 0
	Services:SetMock("HttpService", {
		GenerateGUID = function(_self, _wrap)
			guidCounter += 1
			return "guid-" .. guidCounter
		end,
	})

	-- Datastores: explicitly route to the in-memory mock. (A Services mock
	-- wins outright — the tests must not depend on DebugFlags:UseMockData,
	-- which is false in the production configuration.)
	Services:SetMock("DataStoreService", require(game.ServerScriptService.MockDataStore))

	-- Badge awards land here; the query APIs answer from the same record (like
	-- the real badge web APIs would) plus synthetic product info
	local badgeAwards = {} -- { {UserId, BadgeId} }
	Services:SetMock("BadgeService", {
		AwardBadge = function(_self, userId, badgeId)
			table.insert(badgeAwards, { UserId = userId, BadgeId = badgeId })
			return true
		end,
		CheckUserBadgesAsync = function(_self, userId, badgeIds)
			assert(#badgeIds <= 10, "CheckUserBadgesAsync takes at most 10 badge ids")
			local owned = {}
			for _, badgeId in pairs(badgeIds) do
				for _, award in pairs(badgeAwards) do
					if award.UserId == userId and award.BadgeId == badgeId then
						table.insert(owned, badgeId)
						break
					end
				end
			end
			return owned
		end,
		GetBadgeInfoAsync = function(_self, badgeId)
			return {
				Name = "Badge " .. badgeId,
				Description = "Description " .. badgeId,
				IconImageId = badgeId + 5000,
				IsEnabled = true,
			}
		end,
	})

	----------------------------------------------------------------------
	-- Remote mocks (the network itself), emulating engine semantics:
	-- - Arguments and return values are SERIALIZED across the boundary:
	--   tables deep-copied with metatables stripped, functions/threads
	--   dropped to nil, and mixed-key / sparse / cyclic tables rejected —
	--   so any unserializable payload the game tries to send fails here
	--   like it would in production, and no table is ever shared by
	--   reference across the "network".
	-- - Server event handlers run fire-and-forget in their own threads and
	--   their errors don't propagate to the firer (they warn, like the
	--   engine). FireServer_TEST still waits for the handlers to finish so
	--   tests read naturally.
	----------------------------------------------------------------------

	local function serializeValue(value, seen)
		local vt = typeof(value)
		if vt == "table" then
			if seen[value] then
				error("Mock remote: cannot serialize a cyclic table", 0)
			end
			seen[value] = true
			local copy = {}
			local hasString, hasNumber = false, false
			local count = 0
			for k, v in pairs(value) do
				local kt = typeof(k)
				if kt == "string" then
					hasString = true
				elseif kt == "number" then
					hasNumber = true
				else
					error("Mock remote: unserializable table key of type " .. kt, 0)
				end
				copy[k] = serializeValue(v, seen)
				count += 1
			end
			if hasString and hasNumber then
				error("Mock remote: cannot serialize a mixed-key table", 0)
			end
			if hasNumber and #value ~= count then
				error("Mock remote: cannot serialize a sparse array", 0)
			end
			seen[value] = nil
			return copy -- metatable deliberately stripped
		elseif vt == "function" or vt == "thread" then
			return nil -- the engine drops these
		else
			-- Primitives, Instances (by reference) and Roblox datatypes pass
			return value
		end
	end
	local function serializeArgs(...)
		local args = table.pack(...)
		for i = 1, args.n do
			args[i] = serializeValue(args[i], {})
		end
		return args
	end

	-- Run fn in its own thread (fire-and-forget semantics: errors warn, the
	-- firer is unaffected) but wait for it to finish so tests stay linear
	local function runHandler(fn, player, args)
		local done = false
		task.spawn(function()
			local ok, err = pcall(function()
				fn(player, table.unpack(args, 1, args.n))
			end)
			done = true
			if not ok then
				warn("Mock remote handler error: " .. tostring(err))
			end
		end)
		local waited = 0
		while not done do
			waited += task.wait()
			if waited > 5 then
				error("Mock remote handler did not complete within 5 seconds")
			end
		end
	end

	local function mockRemoteEvent(name)
		local handlers = {}
		local remote = {
			Name = name,
			FiredToClients = {},
		}
		remote.OnServerEvent = {
			connect = function(_self, fn)
				table.insert(handlers, fn)
				return { Disconnect = function() end }
			end,
		}
		-- Simulates a client firing the remote: args serialized once, every
		-- handler runs in its own thread
		function remote:FireServer_TEST(player, ...)
			local args = serializeArgs(...)
			for _, fn in pairs(handlers) do
				runHandler(fn, player, args)
			end
		end
		function remote:FireClient(player, ...)
			-- Client-bound payloads must serialize too
			table.insert(self.FiredToClients, { Player = player, Args = serializeArgs(...) })
		end
		return remote
	end
	local function mockRemoteFunction(name)
		local remote = { Name = name, OnServerInvoke = nil }
		-- Invokes block the calling client, so this stays synchronous; both
		-- the arguments and the RETURN values cross the serialization
		-- boundary (the client can never share a table with the server)
		function remote:InvokeServer_TEST(player, ...)
			local args = serializeArgs(...)
			local results = serializeArgs(self.OnServerInvoke(player, table.unpack(args, 1, args.n)))
			return table.unpack(results, 1, results.n)
		end
		return remote
	end

	local remotes = {
		Load = mockRemoteFunction("Load"),
		BeatTutorial = mockRemoteEvent("BeatTutorial"),
		ProcessReplay = mockRemoteEvent("ProcessReplay"),
		SkipLevel = mockRemoteEvent("SkipLevel"),
		PurchaseUnit = mockRemoteEvent("PurchaseUnit"),
		PurchaseSkip = mockRemoteEvent("PurchaseSkip"),
		FunnelStep = mockRemoteEvent("FunnelStep"),
		ServerError = mockRemoteEvent("ServerError"),
		GetNodeRecords = mockRemoteFunction("GetNodeRecords"),
		GetNodeReplay = mockRemoteFunction("GetNodeReplay"),
		GetBadges = mockRemoteFunction("GetBadges"),
		SaveSettings = mockRemoteEvent("SaveSettings"),
		PostTutorialChoice = mockRemoteEvent("PostTutorialChoice"),
		PlacementMethod = mockRemoteEvent("PlacementMethod"),
		StatsPageOutcome = mockRemoteEvent("StatsPageOutcome"),
		JourneyEvents = mockRemoteEvent("JourneyEvents"),
		GetJourneyList = mockRemoteFunction("GetJourneyList"),
		GetJourney = mockRemoteFunction("GetJourney"),
	}

	----------------------------------------------------------------------
	-- The real server stack, wired to the mocks
	----------------------------------------------------------------------

	local NetworkController = require(game.ServerScriptService.NetworkController)
	local DataStoreService = require(game.ServerScriptService.DataStoreService)
	local Places = require(game.ReplicatedStorage.Places)
	local DebugFlags = require(game.ReplicatedStorage.DebugFlags)
	local GameState = require(game.ReplicatedStorage.GameState)
	local Scripts = require(game.ReplicatedStorage.Scripts)
	local OnboardingSteps = require(game.ReplicatedStorage.OnboardingSteps)
	local DeveloperProduct = require(game.ReplicatedStorage.DeveloperProduct)
	local Netmap = require(game.ReplicatedStorage.Netmap)
	local Badges = require(game.ReplicatedStorage.Badges)
	local BadgeAwarder = require(game.ServerScriptService.BadgeAwarder)

	-- Configure EVERY manifest id so awarding is observable (0 = disabled)
	do
		local nextId = 100
		for key in pairs(Badges.Ids) do
			nextId += 1
			Badges.Ids[key] = nextId
		end
	end

	local function badgeAwarded(userId, badgeKey)
		local badgeId = Badges.Ids[badgeKey]
		for _, award in pairs(badgeAwards) do
			if award.UserId == userId and award.BadgeId == badgeId then
				return true
			end
		end
		return false
	end

	NetworkController.install(remotes)

	local function makePlayer(id, name)
		local player = {
			UserId = id,
			Name = name,
			Parent = game,
			User = {
				OwnerId = id, -- test-side backref for the friends mock
				ToString = function()
					return "mockuser_" .. id
				end,
			},
		}
		mockPlayers[id] = player
		return player
	end

	local function playerLeaves(player)
		for _, fn in pairs(removingHandlers) do
			fn(player)
		end
		mockPlayers[player.UserId] = nil
	end

	local function countAnalytics(kind, player)
		local n = 0
		for _, event in pairs(analyticsLog) do
			-- Compare by UserId: rejoining creates a fresh player object
			if event.Kind == kind
				and (player == nil or (event.Player and event.Player.UserId == player.UserId)) then
				n += 1
			end
		end
		return n
	end

	-- Play L12 for real through the game logic and return the winning replay
	-- string: proves the client simulation and ReplayChecker agree on rules
	local function generateWinningReplay(uploadIds)
		uploadIds = uploadIds or { "golemstone", "golemstone" }
		local inventory = {}
		for id, unit in pairs(Scripts) do
			if not unit.Enemy then
				table.insert(inventory, { Id = id, Count = 2 })
			end
		end
		local gs = GameState.new(Places.L12, inventory, GameState.ServerDelayFunc)
		local zones = gs:GetUploadZones()
		for i, unitId in pairs(uploadIds) do
			gs:UploadUnit(zones[i].x, zones[i].y, Scripts[unitId])
		end
		gs:StartGame()
		for _turn = 1, 60 do
			if gs:HasWon() or gs:HasLost() then
				break
			end
			local friendly = {}
			for unit in pairs(gs:GetUnits()) do
				if not unit.Enemy then
					table.insert(friendly, unit)
				end
			end
			for _, unit in ipairs(friendly) do
				if gs:HasWon() or gs:HasLost() then
					break
				end
				if not unit.Done and #unit.Tail > 0 then
					local cmdId = unit.Definition.CommandList[#unit.Definition.CommandList].Id
					local points, attackFrom = gs:GetMovementAndCommandRange(unit, cmdId)
					local target, from = nil, nil
					for tgt, f in pairs(attackFrom) do
						local victim = gs:GetUnit(tgt.x, tgt.y)
						if victim and victim.Enemy then
							target, from = tgt, f
							break
						end
					end
					if target then
						if from.x ~= unit.Tail[1].x or from.y ~= unit.Tail[1].y then
							gs:UnitMove(unit, from.x, from.y)
						end
						if not gs:HasWon() then
							gs:UnitExecute(unit, cmdId, target.x, target.y)
						end
					else
						local enemyHead = nil
						for other in pairs(gs:GetUnits()) do
							if other.Enemy then
								enemyHead = other.Tail[1]
								break
							end
						end
						if enemyHead then
							local best, bestD = nil, math.huge
							for _, p in pairs(points) do
								local d = math.abs(p.x - enemyHead.x) + math.abs(p.y - enemyHead.y)
								if d < bestD then
									best, bestD = p, d
								end
							end
							if best then
								gs:UnitMove(unit, best.x, best.y)
							end
						end
					end
				end
			end
			if not gs:HasWon() and not gs:HasLost() then
				gs:EndTurn()
			end
		end
		assert(gs:HasWon(), "auto-player failed to win L12")
		assert(not gs:HasErrors(), "auto-player performed invalid actions")
		return gs:GetReplay()
	end
	local kL12WinningReplay = generateWinningReplay()

	----------------------------------------------------------------------

	t.test("a new player joins and plays through the scripted tutorial", function()
		local player = makePlayer(3003, "TutorialPlayer")

		-- Join: the client bootstrap invokes Load
		local clientData = remotes.Load:InvokeServer_TEST(player)
		t.expect(clientData.IsFirstTimeUser).toBeTruthy()

		-- Play the tutorial battle CLIENT-SIDE exactly as Tutorial.lua
		-- scripts it, using the inventory the server just handed us. This
		-- guards the tutorial map and the script's hard-coded coordinates
		-- staying in sync: if either changes, this fails before a player
		-- ever hits a stuck tutorial.
		local gs = GameState.new(Places.tutorial, clientData.Units, GameState.ServerDelayFunc)
		gs:UploadUnit(4, 5, Scripts.hack)
		gs:UploadUnit(3, 3, Scripts.slingshot)
		gs:StartGame()

		-- Hack: two moves in, then the auto-selected Slice on the enemy
		local hack = gs:GetUnit(4, 5)
		gs:UnitMove(hack, 5, 5)
		gs:UnitMove(hack, 6, 5)
		gs:UnitExecute(hack, "slice", 7, 5)
		t.expect(gs:HasWon()).toBeFalsy() -- not dead yet: slingshot finishes it

		-- Slingshot: move up, then Stone at range
		local slingshot = gs:GetUnit(3, 3)
		gs:UnitMove(slingshot, 4, 3)
		gs:UnitExecute(slingshot, "stone", 7, 3)

		-- The tutorial polls HasWon right after this attack
		t.expect(gs:HasWon()).toBeTruthy()
		t.expect(gs:HasErrors()).toBeFalsy()

		-- The client then reports the funnel milestones and BeatTutorial
		remotes.FunnelStep:FireServer_TEST(player, OnboardingSteps.TutorialEntered)
		remotes.FunnelStep:FireServer_TEST(player, OnboardingSteps.ScriptPlaced)
		remotes.FunnelStep:FireServer_TEST(player, OnboardingSteps.BattleStarted)
		remotes.FunnelStep:FireServer_TEST(player, OnboardingSteps.FirstAttack)
		remotes.BeatTutorial:FireServer_TEST(player)

		-- Rejoin: the completed tutorial persisted with its reward
		playerLeaves(player)
		player = makePlayer(3003, "TutorialPlayer")
		local rejoined = remotes.Load:InvokeServer_TEST(player)
		t.expect(rejoined.NodeStatus.hq.Beaten).toBeTruthy()
		t.expect(rejoined.Credits).toBe(DebugFlags:GetInitialCredits() + Places.tutorial.CreditReward)
		-- Joined + 4 detail steps + TutorialBeaten
		t.expect(countAnalytics("onboarding", player) >= 5).toBeTruthy()

		-- Completing the tutorial awarded the Plugged In badge
		task.wait() -- awards are fire-and-forget
		t.expect(badgeAwarded(3003, "PluggedIn")).toBeTruthy()
	end)

	t.test("full journey over the network: join, tutorial, rejoin, win, buy, skip", function()
		local player = makePlayer(1001, "IntegrationTester")

		-- Session 1: joining invokes Load like the client bootstrap does
		local clientData = remotes.Load:InvokeServer_TEST(player)
		t.expect(clientData ~= nil).toBeTruthy()
		t.expect(clientData.IsFirstTimeUser).toBeTruthy()
		t.expect(clientData.Credits).toBe(DebugFlags:GetInitialCredits())
		t.expect(clientData.NodeStatus.hq.Accessible).toBeTruthy()
		t.expect(countAnalytics("onboarding", player)).toBe(1) -- Joined

		-- Serialization isolation: the client's copy crossed the boundary by
		-- value, so mutating it cannot touch server state (the rejoin
		-- assertions below would catch it)
		clientData.Credits = 999999
		clientData.NodeStatus.hq.Beaten = true

		-- Mid-tutorial detail steps arrive over the funnel remote (a bogus
		-- one is rejected by the whitelist)
		remotes.FunnelStep:FireServer_TEST(player, OnboardingSteps.TutorialEntered)
		remotes.FunnelStep:FireServer_TEST(player, OnboardingSteps.TutorialBeaten) -- server-authoritative: rejected
		remotes.FunnelStep:FireServer_TEST(player, "garbage")
		t.expect(countAnalytics("onboarding", player)).toBe(2)

		-- They beat the tutorial
		remotes.BeatTutorial:FireServer_TEST(player)
		t.expect(countAnalytics("onboarding", player)).toBe(3) -- TutorialBeaten

		-- They leave, and rejoin: everything came back through the datastore
		playerLeaves(player)
		player = makePlayer(1001, "IntegrationTester")
		local rejoined = remotes.Load:InvokeServer_TEST(player)
		t.expect(rejoined.IsFirstTimeUser).toBeFalsy()
		t.expect(rejoined.Credits).toBe(DebugFlags:GetInitialCredits() + Places.tutorial.CreditReward)
		t.expect(rejoined.NodeStatus.hq.Beaten).toBeTruthy()
		t.expect(rejoined.NodeStatus.lm12.Accessible).toBeTruthy()
		t.expect(rejoined.NodeStatus.wz1.Beaten).toBeTruthy()

		-- They win the first real battle; the server confirms over the remote
		remotes.ProcessReplay:FireServer_TEST(player, kL12WinningReplay)
		local reply = remotes.ProcessReplay.FiredToClients[#remotes.ProcessReplay.FiredToClients]
		t.expect(reply.Player).toBe(player)
		t.expect(reply.Args[1]).toBe(true)
		t.expect(countAnalytics("progressionComplete", player)).toBe(1)
		t.expect(countAnalytics("economy", player) >= 1).toBeTruthy() -- battle reward
		-- One UnitUsed event per fielded unit (the winning replay uploads
		-- two golemstone), tagged with the unit and the outcome
		local unitUsed = {}
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Player == player and event.Args[1] == "UnitUsed" then
				table.insert(unitUsed, event.Args[3])
			end
		end
		t.expect(#unitUsed).toBe(2)
		for _, fields in pairs(unitUsed) do
			t.expect(fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]).toBe("golemstone")
			t.expect(fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name]).toBe("win")
		end

		-- The first win archived the winning replay under the (mock) GUID —
		-- read it back straight out of the mock datastore
		task.wait(0.1) -- the archive write is fire-and-forget
		local MockDataStore = require(game.ServerScriptService.MockDataStore)
		local archived = MockDataStore:GetDataStore(DataStoreService.ReplaysStoreName):GetAsync("guid-1")
		t.expect(archived).toBe(kL12WinningReplay)

		-- A garbage replay is refused (and counted as a cheat signal)
		remotes.ProcessReplay:FireServer_TEST(player, "L99;;;garbage")
		local refusal = remotes.ProcessReplay.FiredToClients[#remotes.ProcessReplay.FiredToClients]
		t.expect(refusal.Args[1]).toBe(false)
		-- ...and persisted to the failed-replay diagnostics store with the
		-- failure reason, ready to re-run offline
		task.wait(0.1) -- the diagnostic write is fire-and-forget
		local failedKeys = DataStoreService:ListFailedReplayKeys(10)
		t.expect(#failedKeys >= 1).toBeTruthy()
		local failedRecord = DataStoreService:GetFailedReplay(failedKeys[1])
		t.expect(failedRecord.Replay).toBe("L99;;;garbage")
		t.expect(failedRecord.Reason).toBe("MissingPlace L99")
		t.expect(failedRecord.UserId).toBe(player.UserId)

		-- A DESYNCED replay (valid shape, impossible action) is refused too.
		-- Its reason carries a coordinate comma ("MissingUnit 1,1"), so this
		-- also exercises the analytics field sanitizer (the violations test
		-- at the end of the spec catches any forbidden characters)
		remotes.ProcessReplay:FireServer_TEST(player, (kL12WinningReplay:gsub("S;", "S;U1,1Mn", 1)))
		local desyncRefusal = remotes.ProcessReplay.FiredToClients[#remotes.ProcessReplay.FiredToClients]
		t.expect(desyncRefusal.Args[1]).toBe(false)

		-- They buy a script at the warez shop
		local beforeBuy = remotes.Load:InvokeServer_TEST(player).Credits
		remotes.PurchaseUnit:FireServer_TEST(player, "wz1", "bitman")
		local afterBuy = remotes.Load:InvokeServer_TEST(player)
		t.expect(afterBuy.Credits).toBe(beforeBuy - Netmap.ById.wz1.Warez.bitman)
		local ownsBitman = false
		for _, entry in pairs(afterBuy.Units) do
			if entry.Id == "bitman" then
				ownsBitman = true
			end
		end
		t.expect(ownsBitman).toBeTruthy()

		-- They buy skips with Robux (marketplace receipt) and spend one
		local decision = marketplaceMock.ProcessReceipt({
			PlayerId = 1001,
			PurchaseId = "purchase-1",
			ProductId = DeveloperProduct.Skip1,
		})
		t.expect(decision).toBe(Enum.ProductPurchaseDecision.PurchaseGranted)
		local skipNotice = remotes.PurchaseSkip.FiredToClients[#remotes.PurchaseSkip.FiredToClients]
		t.expect(skipNotice.Player).toBe(player)
		t.expect(skipNotice.Args[1]).toBe(1)
		-- The same receipt retried is deduped
		t.expect(marketplaceMock.ProcessReceipt({
			PlayerId = 1001,
			PurchaseId = "purchase-1",
			ProductId = DeveloperProduct.Skip1,
		})).toBe(Enum.ProductPurchaseDecision.PurchaseGranted)

		remotes.SkipLevel:FireServer_TEST(player, "lm22")
		local afterSkip = remotes.Load:InvokeServer_TEST(player)
		t.expect(afterSkip.NodeStatus.lm22.Beaten).toBeTruthy()
		t.expect(#afterSkip.SkipsUsed).toBe(1)

		-- Badges earned along the way: the lossless win set the first-ever
		-- record on the node, and the purchase was their first. It was fought
		-- at security level 1 though, where Flawless doesn't count.
		task.wait() -- awards are fire-and-forget
		t.expect(badgeAwarded(1001, "FlawlessIntrusion")).toBeFalsy()
		t.expect(badgeAwarded(1001, "WorldRecordHolder")).toBeTruthy()
		t.expect(badgeAwarded(1001, "ConsumerGrade")).toBeTruthy()
		-- Unconfigured badges (id 0) never reach the service
		for _, award in pairs(badgeAwards) do
			t.expect(award.BadgeId ~= 0).toBeTruthy()
		end
	end)

	t.test("node records: my best vs a friend's best over the network", function()
		-- The rival wins L12 too (fresh player, fresh session)
		local rival = makePlayer(2002, "Rival")
		remotes.Load:InvokeServer_TEST(rival)
		remotes.BeatTutorial:FireServer_TEST(rival)
		remotes.ProcessReplay:FireServer_TEST(rival, kL12WinningReplay)

		-- Wait out the async record-store writes
		task.wait(0.1)

		-- The original player asks for the 3-split with the rival as friend
		local player = mockPlayers[1001]
		friendsGraph[1001] = { { Id = 2002, Username = "Rival", DisplayName = "Rival" } }
		local records = remotes.GetNodeRecords:InvokeServer_TEST(player, "lm12")
		t.expect(records ~= nil).toBeTruthy()
		t.expect(records.World.turns ~= nil).toBeTruthy()
		t.expect(records.Friend.turns ~= nil).toBeTruthy()
		t.expect(records.Friend.turns.Name).toBe("Rival")
		-- The world holder's name came through the (mock) name lookup API
		t.expect(records.World.turns.Name:match("^User%d+$") ~= nil).toBeTruthy()

		-- Bogus node ids are rejected
		t.expect(remotes.GetNodeRecords:InvokeServer_TEST(player, "nope")).toBe(nil)

		-- The stored winning replay comes back for thumbnail playback
		local replay = remotes.GetNodeReplay:InvokeServer_TEST(rival, "lm12")
		t.expect(replay).toBe(kL12WinningReplay)
		-- Never-won nodes and bogus ids have none
		t.expect(remotes.GetNodeReplay:InvokeServer_TEST(rival, "ph16")).toBe(nil)
		t.expect(remotes.GetNodeReplay:InvokeServer_TEST(rival, "nope")).toBe(nil)

		-- The replay pointer survives a save/load cycle (a load-time fixup
		-- used to wipe it, which left every fresh session replay-less)
		remotes.Load:InvokeServer_TEST(rival)
		t.expect(remotes.GetNodeReplay:InvokeServer_TEST(rival, "lm12")).toBe(kL12WinningReplay)
	end)

	t.test("skip-sweeping the netmap awards the progression badges", function()
		local player = makePlayer(5005, "Sweeper")
		remotes.Load:InvokeServer_TEST(player)
		remotes.BeatTutorial:FireServer_TEST(player)

		-- Count the battle nodes still to beat, buy enough skips (receipts),
		-- and skip every one — firing every story trigger along the way
		local toSkip = {}
		for id, node in pairs(Netmap.ById) do
			if not node.Warez and id ~= 'hq' then
				table.insert(toSkip, id)
			end
		end
		for i = 1, math.ceil(#toSkip / 5) do
			t.expect(marketplaceMock.ProcessReceipt({
				PlayerId = 5005,
				PurchaseId = "sweep-" .. i,
				ProductId = DeveloperProduct.Skip5,
			})).toBe(Enum.ProductPurchaseDecision.PurchaseGranted)
		end
		for _, nodeId in pairs(toSkip) do
			remotes.SkipLevel:FireServer_TEST(player, nodeId)
		end

		local final = remotes.Load:InvokeServer_TEST(player)
		t.expect(#final.SkipsUsed).toBe(#toSkip)

		task.wait() -- awards are fire-and-forget
		t.expect(badgeAwarded(5005, "SecurityClearance2")).toBeTruthy()
		t.expect(badgeAwarded(5005, "SecurityClearance3")).toBeTruthy()
		t.expect(badgeAwarded(5005, "SecurityClearance4")).toBeTruthy()
		t.expect(badgeAwarded(5005, "SecurityClearance5")).toBeTruthy()
		t.expect(badgeAwarded(5005, "MidnightAverted")).toBeTruthy()
		t.expect(badgeAwarded(5005, "NodeSweeper")).toBeTruthy()
	end)

	t.test("a solo win awards Minimalist (and Speedrunner within the limit)", function()
		local player = makePlayer(6006, "SoloRunner")
		remotes.Load:InvokeServer_TEST(player)
		remotes.BeatTutorial:FireServer_TEST(player)

		-- One golem, no losses expected; widen the speedrun limit so this
		-- real win exercises the Speedrunner wiring too
		local soloReplay = generateWinningReplay({ "golemstone" })
		local savedLimit = Badges.SpeedrunnerTurnLimit
		Badges.SpeedrunnerTurnLimit = 99
		remotes.ProcessReplay:FireServer_TEST(player, soloReplay)
		Badges.SpeedrunnerTurnLimit = savedLimit

		task.wait()
		t.expect(badgeAwarded(6006, "Minimalist")).toBeTruthy()
		t.expect(badgeAwarded(6006, "Speedrunner")).toBeTruthy()
	end)

	t.test("a kamikaze win awards KaBoom", function()
		local player = makePlayer(6007, "Bomber")
		remotes.Load:InvokeServer_TEST(player)
		remotes.BeatTutorial:FireServer_TEST(player)

		-- The buzzbomb's strongest command is Kamikazee: the auto-player
		-- fires it (losing the buzzbomb) and the golem finishes the level
		local boomReplay = generateWinningReplay({ "buzzbomb", "golemstone" })
		remotes.ProcessReplay:FireServer_TEST(player, boomReplay)

		task.wait()
		t.expect(badgeAwarded(6007, "KaBoom")).toBeTruthy()
		-- The buzzbomb died, so this win was NOT flawless
		t.expect(badgeAwarded(6007, "FlawlessIntrusion")).toBeFalsy()
	end)

	t.test("winning on the sixth attempt awards PersistencePays", function()
		local player = makePlayer(6008, "Perseverer")
		remotes.Load:InvokeServer_TEST(player)
		remotes.BeatTutorial:FireServer_TEST(player)

		-- Five early quits (a bare replay is a valid early-quit attempt)...
		for _ = 1, 5 do
			remotes.ProcessReplay:FireServer_TEST(player, "L12;")
		end
		t.expect(badgeAwarded(6008, "PersistencePays")).toBeFalsy()
		-- ...then the win on attempt six
		remotes.ProcessReplay:FireServer_TEST(player, kL12WinningReplay)

		task.wait()
		t.expect(badgeAwarded(6008, "PersistencePays")).toBeTruthy()
	end)

	t.test("win/purchase badge conditions (direct evaluation)", function()
		local function result(overrides)
			local base = {
				TurnCount = 10,
				UnitCount = 2,
				UnitsLost = 1,
				UsedSuicideCommand = false,
				UsedCommandTypes = { damage = true },
			}
			for k, v in pairs(overrides) do
				base[k] = v
			end
			return base
		end

		-- Speedrunner boundary: exactly at the limit awards, one over doesn't
		local atLimit = makePlayer(7001, "AtLimit")
		BadgeAwarder:EvaluateWinBadges(atLimit, result({ TurnCount = Badges.SpeedrunnerTurnLimit }), 1, 2)
		local overLimit = makePlayer(7002, "OverLimit")
		BadgeAwarder:EvaluateWinBadges(overLimit, result({ TurnCount = Badges.SpeedrunnerTurnLimit + 1 }), 1, 2)

		-- BitByBit: grid casts plus any NON-damage support qualify; any
		-- damage cast disqualifies, as does never casting a grid command
		local gridOnly = makePlayer(7003, "GridOnly")
		BadgeAwarder:EvaluateWinBadges(gridOnly, result({ UsedCommandTypes = { zero = true, one = true } }), 1, 2)
		local gridMixed = makePlayer(7004, "GridMixed")
		BadgeAwarder:EvaluateWinBadges(gridMixed, result({ UsedCommandTypes = { zero = true, damage = true } }), 1, 2)
		local gridSupport = makePlayer(7010, "GridSupport")
		BadgeAwarder:EvaluateWinBadges(gridSupport, result({ UsedCommandTypes = { one = true, grow = true, speedMod = true } }), 1, 2)
		local supportOnly = makePlayer(7011, "SupportOnly")
		BadgeAwarder:EvaluateWinBadges(supportOnly, result({ UsedCommandTypes = { grow = true } }), 1, 2)

		-- Flawless requires zero losses AND a battle at security level 2+;
		-- Persistence needs the attempt count
		local flawless = makePlayer(7005, "Flawless")
		BadgeAwarder:EvaluateWinBadges(flawless, result({ UnitsLost = 0 }), Badges.PersistenceWinAttempts - 1,
			Badges.FlawlessMinSecurityLevel)
		local flawlessEarly = makePlayer(7009, "FlawlessEarly")
		BadgeAwarder:EvaluateWinBadges(flawlessEarly, result({ UnitsLost = 0 }), 1,
			Badges.FlawlessMinSecurityLevel - 1)
		local persistent = makePlayer(7006, "Persistent")
		BadgeAwarder:EvaluateWinBadges(persistent, result({}), Badges.PersistenceWinAttempts, 2)

		-- FullyLoaded: the complete purchasable catalog qualifies, one short
		-- doesn't (ConsumerGrade fires either way)
		local purchasable = {}
		for _, node in pairs(Netmap.ById) do
			if node.Warez then
				for unitId in pairs(node.Warez) do
					purchasable[unitId] = true
				end
			end
		end
		local fullInventory = {}
		for unitId in pairs(purchasable) do
			table.insert(fullInventory, { Id = unitId, Count = 1 })
		end
		local collector = makePlayer(7007, "Collector")
		BadgeAwarder:EvaluatePurchaseBadges(collector, fullInventory)
		local almost = makePlayer(7008, "Almost")
		local partialInventory = table.clone(fullInventory)
		table.remove(partialInventory)
		BadgeAwarder:EvaluatePurchaseBadges(almost, partialInventory)

		task.wait() -- awards are fire-and-forget
		t.expect(badgeAwarded(7001, "Speedrunner")).toBeTruthy()
		t.expect(badgeAwarded(7002, "Speedrunner")).toBeFalsy()
		t.expect(badgeAwarded(7003, "BitByBit")).toBeTruthy()
		t.expect(badgeAwarded(7004, "BitByBit")).toBeFalsy()
		t.expect(badgeAwarded(7010, "BitByBit")).toBeTruthy()
		t.expect(badgeAwarded(7011, "BitByBit")).toBeFalsy()
		t.expect(badgeAwarded(7005, "FlawlessIntrusion")).toBeTruthy()
		t.expect(badgeAwarded(7009, "FlawlessIntrusion")).toBeFalsy()
		t.expect(badgeAwarded(7005, "PersistencePays")).toBeFalsy()
		t.expect(badgeAwarded(7006, "PersistencePays")).toBeTruthy()
		t.expect(badgeAwarded(7007, "FullyLoaded")).toBeTruthy()
		t.expect(badgeAwarded(7007, "ConsumerGrade")).toBeTruthy()
		t.expect(badgeAwarded(7008, "FullyLoaded")).toBeFalsy()
		t.expect(badgeAwarded(7008, "ConsumerGrade")).toBeTruthy()
	end)

	t.test("GetBadges lists earned badges with info from the badge APIs", function()
		-- A fresh player owns none of the (all-configured) badges
		local newcomer = makePlayer(6010, "Badgeless")
		remotes.Load:InvokeServer_TEST(newcomer)
		local result = remotes.GetBadges:InvokeServer_TEST(newcomer)
		t.expect(result.Total).toBe(#Badges.DisplayOrder)
		t.expect(#result.Earned).toBe(0)
		-- Everything is still to be earned, in display order
		t.expect(#result.Unearned).toBe(#Badges.DisplayOrder)
		t.expect(result.Unearned[1].Key).toBe("PluggedIn")

		-- A badge earned AFTER ownership was cached still shows up right away
		-- (unioned in from the session award record)
		remotes.BeatTutorial:FireServer_TEST(newcomer)
		task.wait() -- the award call is fire-and-forget
		result = remotes.GetBadges:InvokeServer_TEST(newcomer)
		t.expect(#result.Earned).toBe(1)
		-- The earned badge moved out of the unearned list
		t.expect(#result.Unearned).toBe(#Badges.DisplayOrder - 1)
		for _, badge in pairs(result.Unearned) do
			t.expect(badge.Key ~= "PluggedIn").toBeTruthy()
		end
		local entry = result.Earned[1]
		t.expect(entry.Key).toBe("PluggedIn")
		t.expect(entry.Name).toBe("Badge " .. Badges.Ids.PluggedIn)
		t.expect(entry.Description).toBe("Description " .. Badges.Ids.PluggedIn)
		t.expect(entry.IconImageId).toBe(Badges.Ids.PluggedIn + 5000)

		-- The skip-sweep player's badges come back in manifest display order
		-- (a fresh player object, so ownership is fetched via the badge API)
		local sweeper = makePlayer(5005, "Sweeper")
		result = remotes.GetBadges:InvokeServer_TEST(sweeper)
		local keys = {}
		for _, badge in pairs(result.Earned) do
			table.insert(keys, badge.Key)
		end
		t.expect(table.concat(keys, ",")).toBe(
			"PluggedIn,SecurityClearance2,SecurityClearance3,SecurityClearance4,"
			.. "SecurityClearance5,MidnightAverted,NodeSweeper")
	end)

	t.test("player data saves to the single modern key", function()
		local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
		local MockDataStore = require(game.ServerScriptService.MockDataStore)
		local player = makePlayer(6012, "ModernSaver")
		local data = ServerPlayerData.new(player)
		t.expect(DataStoreService:SavePlayerDataAsync(player, data)).toBeTruthy()
		local stored = MockDataStore:GetDataStore(DataStoreService.PlayerStoreName)
			:GetAsync(player.User:ToString())
		t.expect(stored ~= nil).toBeTruthy()
		t.expect(stored.SecurityLevel).toBe(1)
		-- Nothing writes the legacy versioned index anymore
		local ordered = MockDataStore:GetOrderedDataStore(
			DataStoreService.LegacyOrderedPrefix .. "_" .. player.User:ToString())
		t.expect(#ordered:GetSortedAsync(false, 10):GetCurrentPage()).toBe(0)
	end)

	t.test("legacy versioned-store data loads via the compat path", function()
		local MockDataStore = require(game.ServerScriptService.MockDataStore)
		local player = makePlayer(6013, "LegacyPlayer")
		local key = player.User:ToString()
		-- Seed ONLY the old scheme: a version index entry plus its data blob,
		-- marked with a security level a fresh player can't have
		local legacyData
		do
			local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
			legacyData = ServerPlayerData.new(player):Serialize()
			legacyData.SecurityLevel = 3
		end
		MockDataStore:GetOrderedDataStore(DataStoreService.LegacyOrderedPrefix .. "_" .. key)
			:SetAsync("1000", 1000)
		MockDataStore:GetDataStore(DataStoreService.LegacyDataPrefix .. "_" .. key)
			:SetAsync("1000", legacyData)

		local loaded = remotes.Load:InvokeServer_TEST(player)
		t.expect(loaded.SecurityLevel).toBe(3)

		-- A save moves them onto the modern key; the next load prefers it
		remotes.BeatTutorial:FireServer_TEST(player)
		local modern = MockDataStore:GetDataStore(DataStoreService.PlayerStoreName):GetAsync(key)
		t.expect(modern ~= nil).toBeTruthy()
		t.expect(modern.SecurityLevel).toBe(3)
		t.expect(modern.NodeStatus.hq.Beaten).toBeTruthy()
		playerLeaves(player)
		local rejoinPlayer = makePlayer(6013, "LegacyPlayer")
		local rejoined = remotes.Load:InvokeServer_TEST(rejoinPlayer)
		t.expect(rejoined.SecurityLevel).toBe(3)
		t.expect(rejoined.NodeStatus.hq.Beaten).toBeTruthy()
	end)

	t.test("session journeys record, persist on leave, and serve the viewer", function()
		local JourneyService = require(game.ServerScriptService.JourneyService)
		local MockDataStore = require(game.ServerScriptService.MockDataStore)

		-- Restrict viewing to one specific user for this test
		local originalIsViewer = JourneyService.IsViewer
		JourneyService.IsViewer = function(player)
			return player.UserId == 9001
		end

		local ok, err = pcall(function()
			local player = makePlayer(9000, "JourneyedPlayer")
			remotes.JourneyEvents:FireServer_TEST(player, {
				{ 0.5, "NetmapNodeClick", "hq" },
				{ 3.2, "DialogueLine", "Aeacus: Plug into the smart HQ node." },
				{ 9.9, "NetmapPan", "120 studs to 80,-40" },
			})
			remotes.JourneyEvents:FireServer_TEST(player, {
				{ 15.0, "BattleEnter", "lm12" },
			})
			-- Garbage batches are ignored outright
			remotes.JourneyEvents:FireServer_TEST(player, "not a table")
			remotes.JourneyEvents:FireServer_TEST(player, { { "bad", 123 } })

			-- Mid-session the stored record is marked ongoing (no Ended)
			local midKey = nil
			for _, key in pairs(DataStoreService:ListJourneyKeys(50)) do
				local record = DataStoreService:GetJourney(key)
				if record and record.UserId == 9000 then
					midKey = key
					t.expect(record.Ended).toBe(nil)
					t.expect(record.LastUpdate ~= nil).toBeTruthy()
				end
			end
			t.expect(midKey ~= nil).toBeTruthy()

			playerLeaves(player) -- flushes the session to the store
			-- ...and the final flush marks it completed
			t.expect(DataStoreService:GetJourney(midKey).Ended ~= nil).toBeTruthy()

			-- The viewer (and only the viewer) can list and read it
			local outsider = makePlayer(9002, "Nosy")
			t.expect(remotes.GetJourneyList:InvokeServer_TEST(outsider)).toBe(nil)
			local viewer = makePlayer(9001, "TheDev")
			local list = remotes.GetJourneyList:InvokeServer_TEST(viewer)
			t.expect(#list >= 1).toBeTruthy()
			local mine = nil
			for _, summary in pairs(list) do
				if summary.UserId == 9000 then
					mine = summary
				end
			end
			t.expect(mine ~= nil).toBeTruthy()
			t.expect(mine.Name).toBe("JourneyedPlayer")
			t.expect(mine.EventCount).toBe(4)
			t.expect(mine.Duration).toBe(15)
			-- The SUMMARY carries the completion status (the viewer's tags
			-- read these, not the store record)
			t.expect(mine.Ended ~= nil).toBeTruthy()
			t.expect(mine.LastUpdate ~= nil).toBeTruthy()

			local record = remotes.GetJourney:InvokeServer_TEST(viewer, mine.Key)
			t.expect(#record.Events).toBe(4)
			t.expect(record.Events[1][2]).toBe("NetmapNodeClick")
			t.expect(record.Events[1][3]).toBe("hq")
			t.expect(record.Events[3][2]).toBe("NetmapPan")
			t.expect(remotes.GetJourney:InvokeServer_TEST(outsider, mine.Key)).toBe(nil)

			-- And it round-trips the store itself
			local stored = MockDataStore:GetDataStore(DataStoreService.JourneyStoreName):GetAsync(mine.Key)
			t.expect(stored.Events[4][2]).toBe("BattleEnter")
		end)
		JourneyService.IsViewer = originalIsViewer
		if not ok then
			error(err, 0)
		end
	end)

	t.test("volume settings persist in the save data", function()
		local player = makePlayer(9100, "AudioTweaker")
		local loaded = remotes.Load:InvokeServer_TEST(player)
		-- Defaults for a fresh player
		t.expect(loaded.Settings.SoundVolume).toBe(1)
		t.expect(loaded.Settings.MusicVolume).toBe(1)

		remotes.SaveSettings:FireServer_TEST(player, { SoundVolume = 0.25, MusicVolume = 2, GameSpeed = 2 })
		-- A partial payload (netmap camera only) merges rather than clobbers
		remotes.SaveSettings:FireServer_TEST(player, { NetmapX = 120, NetmapZ = -40, NetmapZoom = 350 })
		-- Garbage and out-of-range input is rejected or clamped
		remotes.SaveSettings:FireServer_TEST(player, "junk")
		remotes.SaveSettings:FireServer_TEST(player, { SoundVolume = "loud", GameSpeed = 99 })
		playerLeaves(player)

		local rejoined = remotes.Load:InvokeServer_TEST(makePlayer(9100, "AudioTweaker"))
		t.expect(rejoined.Settings.SoundVolume).toBe(0.25)
		t.expect(rejoined.Settings.MusicVolume).toBe(2)
		t.expect(rejoined.Settings.NetmapX).toBe(120)
		t.expect(rejoined.Settings.NetmapZ).toBe(-40)
		t.expect(rejoined.Settings.NetmapZoom).toBe(350)
		-- GameSpeed saved; the out-of-range 99 was clamped to the max
		t.expect(rejoined.Settings.GameSpeed).toBe(2)
	end)

	t.test("a frozen legacy save (pre-Settings format) still loads and plays", function()
		-- HARDCODED snapshot of the save format from before Settings
		-- (volumes / netmap camera) existed: a fresh player who just beat
		-- the tutorial. DO NOT update this blob to match format changes —
		-- the entire point is that saves written by OLD versions must keep
		-- loading forever. Add new frozen blobs for future eras instead.
		local kLegacySave = {
			NodeStatus = {
				hq = { Beaten = true, Seen = true, Accessible = true, AttemptCount = 0 },
				wz1 = { Beaten = true, Seen = true, Accessible = true, AttemptCount = 0 },
				lm12 = { Beaten = false, Seen = true, Accessible = true, AttemptCount = 0 },
				ph11 = { Beaten = false, Seen = true, Accessible = true, AttemptCount = 0 },
			},
			Credits = 1500,
			SecurityLevel = 1,
			Units = {
				{ Id = 'slingshot', Count = 1 },
				{ Id = 'hack', Count = 1 },
			},
			SkipsPurchased = 0,
			SkipsUsed = {},
			SkipPurchaseIds = {},
		}
		local MockDataStore = require(game.ServerScriptService.MockDataStore)
		local player = makePlayer(9200, "LegacyFormatPlayer")
		MockDataStore:GetDataStore(DataStoreService.PlayerStoreName)
			:SetAsync(player.User:ToString(), kLegacySave)

		local loaded = remotes.Load:InvokeServer_TEST(player)
		t.expect(loaded.IsFirstTimeUser).toBeFalsy()
		t.expect(loaded.NodeStatus.hq.Beaten).toBeTruthy()
		t.expect(loaded.NodeStatus.lm12.Accessible).toBeTruthy()
		t.expect(#loaded.Units).toBe(2)
		-- Missing Settings defaults in rather than erroring
		t.expect(loaded.Settings.SoundVolume).toBe(1)
		t.expect(loaded.Settings.MusicVolume).toBe(1)
		t.expect(loaded.Settings.NetmapX).toBe(nil)
		local expectedCredits = 1500
		if DebugFlags:LotsOfCredits() then
			expectedCredits = math.max(expectedCredits, DebugFlags:GetInitialCredits())
		end
		t.expect(loaded.Credits).toBe(expectedCredits)

		-- The legacy data flows through gameplay: win a battle on it
		remotes.ProcessReplay:FireServer_TEST(player, kL12WinningReplay)
		playerLeaves(player)
		local rejoined = remotes.Load:InvokeServer_TEST(makePlayer(9200, "LegacyFormatPlayer"))
		t.expect(rejoined.NodeStatus.lm12.Beaten).toBeTruthy()
		t.expect(rejoined.NodeStatus.lm12.Wins).toBe(1)
		t.expect(rejoined.Settings.SoundVolume).toBe(1)
	end)

	t.test("the post-tutorial choice logs one whitelisted custom event", function()
		local player = makePlayer(9300, "Chooser")
		remotes.PostTutorialChoice:FireServer_TEST(player, "battle")
		-- Repeats, junk, and non-whitelisted values are all dropped
		remotes.PostTutorialChoice:FireServer_TEST(player, "battle")
		remotes.PostTutorialChoice:FireServer_TEST(player, "explore")
		remotes.PostTutorialChoice:FireServer_TEST(player, "banana")
		remotes.PostTutorialChoice:FireServer_TEST(player, 42)
		local count = 0
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Args[1] == "PostTutorialChoice" then
				count += 1
				t.expect(event.Player.UserId).toBe(9300)
				t.expect(event.Args[2]).toBe(1)
				t.expect(event.Args[3][Enum.AnalyticsCustomFieldKeys.CustomField01.Name]).toBe("battle")
			end
		end
		t.expect(count).toBe(1)
	end)

	t.test("placement method reports log whitelisted custom events", function()
		local player = makePlayer(9400, "Placer")
		remotes.PlacementMethod:FireServer_TEST(player, "drag")
		remotes.PlacementMethod:FireServer_TEST(player, "clickUnit")
		remotes.PlacementMethod:FireServer_TEST(player, "clickZone")
		remotes.PlacementMethod:FireServer_TEST(player, "drag")
		remotes.PlacementMethod:FireServer_TEST(player, "teleport")
		remotes.PlacementMethod:FireServer_TEST(player, 5)
		local counts = {}
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Args[1] == "PlacementMethod"
				and event.Player.UserId == 9400 then
				local method = event.Args[3][Enum.AnalyticsCustomFieldKeys.CustomField01.Name]
				counts[method] = (counts[method] or 0) + 1
			end
		end
		t.expect(counts.drag).toBe(2)
		t.expect(counts.clickUnit).toBe(1)
		t.expect(counts.clickZone).toBe(1)
		t.expect(counts.teleport).toBe(nil)

		-- Capped at 10 per session so marathon sessions can't skew the split
		local spammer = makePlayer(9401, "MarathonPlacer")
		for _ = 1, 25 do
			remotes.PlacementMethod:FireServer_TEST(spammer, "drag")
		end
		local spamCount = 0
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Args[1] == "PlacementMethod"
				and event.Player.UserId == 9401 then
				spamCount += 1
			end
		end
		t.expect(spamCount).toBe(10)
	end)

	t.test("stats page outcome reports log whitelisted custom events", function()
		local player = makePlayer(9500, "StatsBrowser")
		remotes.StatsPageOutcome:FireServer_TEST(player, "close", false)
		remotes.StatsPageOutcome:FireServer_TEST(player, "play_again", true)
		remotes.StatsPageOutcome:FireServer_TEST(player, "explode", false)
		remotes.StatsPageOutcome:FireServer_TEST(player, "close", "yes")
		local seen = {}
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Args[1] == "StatsPageOutcome"
				and event.Player.UserId == 9500 then
				local fields = event.Args[3]
				table.insert(seen, fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]
					.. "/" .. fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name])
			end
		end
		t.expect(#seen).toBe(2)
		t.expect(seen[1]).toBe("close/stayed")
		t.expect(seen[2]).toBe("play_again/browsed")
	end)

	t.test("leaving logs the session's last databattle", function()
		local player = makePlayer(9600, "Leaver")
		remotes.Load:InvokeServer_TEST(player)
		remotes.BeatTutorial:FireServer_TEST(player)
		remotes.ProcessReplay:FireServer_TEST(player, kL12WinningReplay)
		task.wait(0.1)
		playerLeaves(player)
		local found = nil
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Player == player and event.Args[1] == "LastPlayed" then
				found = event
			end
		end
		t.expect(found ~= nil).toBeTruthy()
		t.expect(found.Args[3][Enum.AnalyticsCustomFieldKeys.CustomField01.Name]).toBe("lm12")
		t.expect(found.Args[3][Enum.AnalyticsCustomFieldKeys.CustomField02.Name]).toBe("win")

		-- A pre-tutorial leaver still logs the event, with empty fields
		local fresh = makePlayer(9601, "FreshLeaver")
		remotes.Load:InvokeServer_TEST(fresh)
		playerLeaves(fresh)
		local freshEvent = nil
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Player == fresh and event.Args[1] == "LastPlayed" then
				freshEvent = event
			end
		end
		t.expect(freshEvent ~= nil).toBeTruthy()
		t.expect(freshEvent.Args[3]).toBe(nil)
	end)

	t.test("a marathon journey is cut off with a marker, well under 4MB", function()
		local JourneyService = require(game.ServerScriptService.JourneyService)
		local MockDataStore = require(game.ServerScriptService.MockDataStore)
		local originalCap = JourneyService.MaxEventsPerSession
		JourneyService.MaxEventsPerSession = 5
		local ok, err = pcall(function()
			local player = makePlayer(9500, "MarathonJourneyer")
			remotes.JourneyEvents:FireServer_TEST(player, {
				{ 1, "A" }, { 2, "B" }, { 3, "C" }, { 4, "D" },
			})
			-- This batch crosses the cap: one more event lands, then the
			-- truncation marker, then everything else is dropped
			remotes.JourneyEvents:FireServer_TEST(player, {
				{ 5, "E" }, { 6, "F" }, { 7, "G" },
			})
			remotes.JourneyEvents:FireServer_TEST(player, { { 8, "H" } })
			playerLeaves(player)

			-- Find the stored record via the store (the key embeds a random tail)
			local found = nil
			for _, key in pairs(DataStoreService:ListJourneyKeys(50)) do
				local record = DataStoreService:GetJourney(key)
				if record and record.UserId == 9500 then
					found = record
				end
			end
			t.expect(found ~= nil).toBeTruthy()
			t.expect(#found.Events).toBe(6) -- 5 events + the marker
			t.expect(found.Events[6][2]).toBe("RecordingCapped")
			-- Nothing after the marker (the H batch was dropped)
			for _, entry in pairs(found.Events) do
				t.expect(entry[2] ~= "H").toBeTruthy()
			end
		end)
		JourneyService.MaxEventsPerSession = originalCap
		if not ok then
			error(err, 0)
		end
	end)

	t.test("leaving before loading counts as a bounce", function()
		local ghost = makePlayer(4004, "Bouncer")
		-- Never invokes Load: PlayerRemoving fires with no cached data
		playerLeaves(ghost)
		local sawBounce = false
		for _, event in pairs(analyticsLog) do
			if event.Kind == "custom" and event.Player == ghost
				and event.Args[1] == "PlayerBounced" then
				sawBounce = true
			end
		end
		t.expect(sawBounce).toBeTruthy()
	end)

	-- LAST on purpose: sweeps every analytics event the whole spec fired.
	-- The real AnalyticsService rejects custom field values containing
	-- comma/quote characters; the mock records violations instead.
	t.test("no analytics event carried forbidden field characters", function()
		if #analyticsViolations > 0 then
			error("Analytics field violations: " .. table.concat(analyticsViolations, " | "))
		end
	end)
end
