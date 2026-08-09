-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local ReplayChecker = require(game.ServerScriptService.ReplayChecker)
	local GameState = require(game.ReplicatedStorage.GameState)

	-- Replay quoted in ReplayChecker.lua's header comment. NOTE: it is stale —
	-- it diverges from current game balance mid-game (verified identical
	-- behavior against the original place), so it parses and plays but ends
	-- with internal errors rather than a win. Kept as a characterization test
	-- of the full parse/simulate pipeline.
	local STALE_REPLAY_L12 = "L12;hack,7,10;slingshot,10,10;S;U10,10MnnCstone,10,7U7,10MnnCslice,7,7EU10,8MnnCstone,10,5U7,8MnnCslice,7,5EU10,6MnwCstone,7,4U7,6MnCslice,7,4EU7,5MeeCslice,9,4EU9,5MenCslice,9,4E"

	t.test("stale dev replay parses, resolves its node, and is rejected", function()
		local result = ReplayChecker:Check(STALE_REPLAY_L12, GameState.ServerDelayFunc)
		t.expect(result.NodeId).toBe("lm12")
		t.expect(result.UnitCount).toBe(2)
		t.expect(result.TurnCount).toBe(6)
		t.expect(result.MoveCount).toBe(8)
		t.expect(result.Valid).toBeFalsy()
		t.expect(result.Won).toBeFalsy()
	end)

	t.test("replay for unknown place is invalid", function()
		local result = ReplayChecker:Check("NOSUCHPLACE;hack,7,10;S;E", GameState.ServerDelayFunc)
		t.expect(result.Valid).toBeFalsy()
		t.expect(result.Won).toBeFalsy()
	end)

	t.test("bare concede replay is a valid early quit", function()
		local result = ReplayChecker:Check("L12;", GameState.ServerDelayFunc)
		t.expect(result.Valid).toBeTruthy()
		t.expect(result.Won).toBeFalsy()
		t.expect(result.EarlyQuit).toBeTruthy()
	end)

	t.test("truncated replay is a valid loss, not a win", function()
		-- Cut the replay off after the first turn: game neither errors nor is won.
		local firstTurnEnd = STALE_REPLAY_L12:find("E")
		local truncated = STALE_REPLAY_L12:sub(1, firstTurnEnd)
		local result = ReplayChecker:Check(truncated, GameState.ServerDelayFunc)
		t.expect(result.Valid).toBeTruthy()
		t.expect(result.Won).toBeFalsy()
	end)
end
