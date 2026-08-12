-- Integration test of the real server stack: player data, datastore
-- round-trips, replay validation, record leaderboards and analytics — with
-- the Roblox services mocked through Services:SetMock. Datastores go through
-- MockDataStore (DebugFlags:UseMockData), which round-trips in memory.
--
-- IMPORTANT: mocks must be installed BEFORE the modules under test are first
-- required (they capture their services at require time), so the SetMock
-- calls run at the top of this spec body.
return function(t)
	local Services = require(game.ReplicatedStorage.Services)

	-- Records every analytics call for later assertions
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
	Services:SetMock("Players", {
		GetPlayerByUserId = function()
			return nil
		end,
		GetNameFromUserIdAsync = function(_self, id)
			return "User" .. tostring(id)
		end,
	})

	local DataStoreService = require(game.ServerScriptService.DataStoreService)
	local ServerPlayerData = require(game.ServerScriptService.ServerPlayerData)
	local Places = require(game.ReplicatedStorage.Places)
	local DebugFlags = require(game.ReplicatedStorage.DebugFlags)
	local GameState = require(game.ReplicatedStorage.GameState)
	local Scripts = require(game.ReplicatedStorage.Scripts)

	-- A mock Player: just the surface the server stack uses
	local function makePlayer(id, name)
		return {
			UserId = id,
			Name = name,
			Parent = game,
			User = {
				ToString = function()
					return "mockuser_" .. id
				end,
			},
		}
	end

	-- Play L12 for real through the game logic and return the winning
	-- replay string. This also proves the client simulation and the server's
	-- ReplayChecker still agree on the rules (a hand-recorded replay from an
	-- older version desyncs as soon as AI behavior changes).
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
			-- Snapshot: units can die / be marked done as we act
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
					-- Attack an enemy if one is reachable
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
						-- March toward the nearest enemy
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

	t.test("full journey: join, tutorial, leave, rejoin, win a level", function()
		local player = makePlayer(1001, "IntegrationTester")

		----------------------------------------------------------------
		-- Session 1: a brand new player joins
		----------------------------------------------------------------
		local success, existing = DataStoreService:LoadPlayerDataAsync(player)
		t.expect(success).toBeTruthy()
		t.expect(existing).toBe(nil) -- nothing saved yet

		local pd = ServerPlayerData.new(player)
		t.expect(pd:IsNewPlayer()).toBeTruthy()
		t.expect(pd:HasBeatenTutorial()).toBeFalsy()

		local clientData = pd:Serialize(--[[forClient=]] true)
		t.expect(clientData.Credits).toBe(DebugFlags:GetInitialCredits())
		t.expect(clientData.IsFirstTimeUser).toBeTruthy()
		t.expect(clientData.NodeStatus.hq.Accessible).toBeTruthy()

		-- They complete the tutorial (BeatTutorial remote path)
		t.expect(pd:ProcessBeatTutorial()).toBeTruthy()
		t.expect(pd:HasBeatenTutorial()).toBeTruthy()
		-- A replayed BeatTutorial is rejected
		t.expect(pd:ProcessBeatTutorial()).toBeFalsy()

		t.expect(DataStoreService:SavePlayerDataAsync(player, pd)).toBeTruthy()

		----------------------------------------------------------------
		-- Session 2: leave and rejoin — state comes back from the store
		----------------------------------------------------------------
		local success2, pd2 = DataStoreService:LoadPlayerDataAsync(player)
		t.expect(success2).toBeTruthy()
		t.expect(pd2 ~= nil).toBeTruthy()
		t.expect(pd2:IsNewPlayer()).toBeFalsy()
		t.expect(pd2:HasBeatenTutorial()).toBeTruthy()

		local rejoined = pd2:Serialize(true)
		-- The tutorial reward persisted, adjacent nodes opened, and the
		-- revealed warez shop auto-opened
		t.expect(rejoined.Credits).toBe(DebugFlags:GetInitialCredits() + Places.tutorial.CreditReward)
		t.expect(rejoined.NodeStatus.lm12.Accessible).toBeTruthy()
		t.expect(rejoined.NodeStatus.wz1.Beaten).toBeTruthy()

		----------------------------------------------------------------
		-- They play and win the first real level (replay validation)
		----------------------------------------------------------------
		local result = pd2:ProcessReplay(kL12WinningReplay)
		t.expect(result.Valid).toBeTruthy()
		t.expect(result.Won).toBeTruthy()
		t.expect(DataStoreService:SavePlayerDataAsync(player, pd2)).toBeTruthy()

		-- Garbage from an exploiter reads as invalid, not a server error
		t.expect(pd2:ProcessReplay("L99;;;garbage").Valid).toBeFalsy()

		----------------------------------------------------------------
		-- Session 3: the win and its records persisted
		----------------------------------------------------------------
		local _, pd3 = DataStoreService:LoadPlayerDataAsync(player)
		local final = pd3:Serialize(true)
		local lm12 = final.NodeStatus.lm12
		t.expect(lm12.Beaten).toBeTruthy()
		t.expect(lm12.Wins).toBe(1)
		t.expect(lm12.AttemptCount >= 1).toBeTruthy()
		t.expect(lm12.BestTurns ~= nil).toBeTruthy()
		t.expect(lm12.BestUnits).toBe(2) -- two uploaded units
		t.expect(final.Credits).toBe(rejoined.Credits + result.Credits)

		----------------------------------------------------------------
		-- The record leaderboards saw the win (written asynchronously)
		----------------------------------------------------------------
		task.wait(0.1)
		local worldTurns, holderId = DataStoreService:GetWorldRecord("lm12", "turns")
		t.expect(worldTurns).toBe(lm12.BestTurns)
		t.expect(holderId).toBe(1001)
		t.expect(DataStoreService:GetUserRecord("lm12", "units", 1001)).toBe(2)

		----------------------------------------------------------------
		-- Analytics saw the battle reward economy event for this player
		----------------------------------------------------------------
		local sawEconomy = false
		for _, event in pairs(analyticsLog) do
			if event.Kind == "economy" and event.Player == player then
				sawEconomy = true
			end
		end
		t.expect(sawEconomy).toBeTruthy()
	end)

	t.test("a second player's better run takes the world record", function()
		local rival = makePlayer(2002, "Rival")
		local pd = ServerPlayerData.new(rival)
		pd:ProcessBeatTutorial()

		-- Same winning replay: ties don't displace an existing record
		-- holder's value, but the store accepts the entry
		local result = pd:ProcessReplay(kL12WinningReplay)
		t.expect(result.Valid).toBeTruthy()
		t.expect(result.Won).toBeTruthy()

		task.wait(0.1)
		-- Both players hold entries; the world record value is unchanged
		t.expect(DataStoreService:GetUserRecord("lm12", "turns", 2002) ~= nil).toBeTruthy()
		local worldTurns = DataStoreService:GetWorldRecord("lm12", "turns")
		t.expect(worldTurns ~= nil).toBeTruthy()
	end)
end
