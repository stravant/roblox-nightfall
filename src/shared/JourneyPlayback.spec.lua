-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- The playback engine itself needs a live client (real views, timers); what
-- is testable headlessly is the detail-string parsing that battle playback
-- correctness rides on, matched against the exact formats GameView records.
return function(t)
	local JourneyPlayback = require(game.ReplicatedStorage.JourneyPlayback)

	t.test("parses the recorded Move format", function()
		local id, fx, fy, tx, ty = JourneyPlayback.ParseMove("golemstone 7,10>7,8")
		t.expect(id).toBe("golemstone")
		t.expect(fx).toBe(7)
		t.expect(fy).toBe(10)
		t.expect(tx).toBe(7)
		t.expect(ty).toBe(8)
		t.expect(JourneyPlayback.ParseMove("garbage")).toBe(nil)
		-- The legacy pre-head-position format is rejected, not misparsed
		t.expect(JourneyPlayback.ParseMove("golemstone @7,8")).toBe(nil)
	end)

	t.test("parses the recorded Attack format", function()
		local id, command, fx, fy, tx, ty = JourneyPlayback.ParseAttack("golemstone crash 7,8>6,4")
		t.expect(id).toBe("golemstone")
		t.expect(command).toBe("crash")
		t.expect(fx).toBe(7)
		t.expect(fy).toBe(8)
		t.expect(tx).toBe(6)
		t.expect(ty).toBe(4)
		t.expect(JourneyPlayback.ParseAttack("golemstone crash")).toBe(nil)
	end)

	t.test("parses the recorded Place and Pan formats", function()
		local id, x, y = JourneyPlayback.ParsePlace("hack @4,5")
		t.expect(id).toBe("hack")
		t.expect(x).toBe(4)
		t.expect(y).toBe(5)
		local px, pz = JourneyPlayback.ParsePan("120 studs to 80,-40")
		t.expect(px).toBe(80)
		t.expect(pz).toBe(-40)
		t.expect(JourneyPlayback.ParsePan("no destination here")).toBe(nil)
	end)
end
