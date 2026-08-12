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
	local function logEvent(kind)
		return function(_self, player, ...)
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

	----------------------------------------------------------------------
	-- Remote mocks (the network itself)
	----------------------------------------------------------------------

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
		-- Simulates a client firing the remote (synchronous, like the server
		-- receiving the packet)
		function remote:FireServer_TEST(player, ...)
			for _, fn in pairs(handlers) do
				fn(player, ...)
			end
		end
		function remote:FireClient(player, ...)
			table.insert(self.FiredToClients, { Player = player, Args = { ... } })
		end
		return remote
	end
	local function mockRemoteFunction(name)
		local remote = { Name = name, OnServerInvoke = nil }
		function remote:InvokeServer_TEST(player, ...)
			return self.OnServerInvoke(player, ...)
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
			if event.Kind == kind and (player == nil or event.Player == player) then
				n += 1
			end
		end
		return n
	end

	-- Play L12 for real through the game logic and return the winning replay
	-- string: proves the client simulation and ReplayChecker agree on rules
	local function generateWinningReplay()
		local inventory = {}
		for id, unit in pairs(Scripts) do
			if not unit.Enemy then
				table.insert(inventory, { Id = id, Count = 2 })
			end
		end
		local gs = GameState.new(Places.L12, inventory, GameState.ServerDelayFunc)
		local zones = gs:GetUploadZones()
		gs:UploadUnit(zones[1].x, zones[1].y, Scripts.golemstone)
		gs:UploadUnit(zones[2].x, zones[2].y, Scripts.golemstone)
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

	t.test("full journey over the network: join, tutorial, rejoin, win, buy, skip", function()
		local player = makePlayer(1001, "IntegrationTester")

		-- Session 1: joining invokes Load like the client bootstrap does
		local clientData = remotes.Load:InvokeServer_TEST(player)
		t.expect(clientData ~= nil).toBeTruthy()
		t.expect(clientData.IsFirstTimeUser).toBeTruthy()
		t.expect(clientData.Credits).toBe(DebugFlags:GetInitialCredits())
		t.expect(clientData.NodeStatus.hq.Accessible).toBeTruthy()
		t.expect(countAnalytics("onboarding", player)).toBe(1) -- Joined

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

		-- A garbage replay is refused (and counted as a cheat signal)
		remotes.ProcessReplay:FireServer_TEST(player, "L99;;;garbage")
		local refusal = remotes.ProcessReplay.FiredToClients[#remotes.ProcessReplay.FiredToClients]
		t.expect(refusal.Args[1]).toBe(false)

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

		-- Bogus node ids are rejected
		t.expect(remotes.GetNodeRecords:InvokeServer_TEST(player, "nope")).toBe(nil)
	end)
end
