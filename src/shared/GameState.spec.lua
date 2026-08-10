-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local GameState = require(game.ReplicatedStorage.GameState)
	local Places = require(game.ReplicatedStorage.Places)
	local Scripts = require(game.ReplicatedStorage.Scripts)

	local function makeInventory()
		local inventory = {}
		for id, unit in pairs(Scripts) do
			if not unit.Enemy then
				table.insert(inventory, { Id = id, Count = 2 })
			end
		end
		return inventory
	end

	t.test("new game state exposes the place's upload zones", function()
		local gs = GameState.new(Places.L12, makeInventory(), GameState.ServerDelayFunc)
		t.expect(gs:IsGameStarted()).toBeFalsy()
		t.expect(#gs:GetUploadZones() > 0).toBeTruthy()
		t.expect(gs:GetMapId()).toBe("L12")
	end)

	t.test("uploading a unit onto an upload zone places it", function()
		local gs = GameState.new(Places.L12, makeInventory(), GameState.ServerDelayFunc)
		local zone = gs:GetUploadZones()[1]
		gs:UploadUnit(zone.x, zone.y, Scripts.hack)
		t.expect(gs:HasErrors()).toBeFalsy()
		local unit = gs:GetUnit(zone.x, zone.y)
		t.expect(unit).toBeTruthy()
		t.expect(unit.Tail[1].x).toBe(zone.x)
		t.expect(unit.Tail[1].y).toBe(zone.y)
	end)

	t.test("starting the game flips game state and keeps board valid", function()
		local gs = GameState.new(Places.L12, makeInventory(), GameState.ServerDelayFunc)
		local zone = gs:GetUploadZones()[1]
		gs:UploadUnit(zone.x, zone.y, Scripts.hack)
		gs:StartGame()
		t.expect(gs:IsGameStarted()).toBeTruthy()
		t.expect(gs:HasErrors()).toBeFalsy()
		t.expect(gs:HasWon()).toBeFalsy()
		t.expect(gs:HasLost()).toBeFalsy()
	end)

	t.test("RemoveUploadedUnit returns the unit to inventory before the game starts", function()
		local gs = GameState.new(Places.L12, makeInventory(), GameState.ServerDelayFunc)
		local zone = gs:GetUploadZones()[1]
		gs:UploadUnit(zone.x, zone.y, Scripts.hack)
		local function hackCount()
			for _, info in pairs(gs:GetAvailableUnits()) do
				if info.Id == "hack" then
					return info.Count
				end
			end
		end
		local countAfterUpload = hackCount()

		local removedId = gs:RemoveUploadedUnit(zone.x, zone.y)
		t.expect(removedId).toBe("hack")
		t.expect(gs:GetUnit(zone.x, zone.y)).toBe(nil)
		t.expect(hackCount()).toBe(countAfterUpload + 1)

		-- Nothing there anymore: removing again is a no-op
		t.expect(gs:RemoveUploadedUnit(zone.x, zone.y)).toBe(nil)

		-- The zone accepts a fresh upload afterwards
		gs:UploadUnit(zone.x, zone.y, Scripts.hack)
		t.expect(gs:GetUnit(zone.x, zone.y) ~= nil).toBeTruthy()
		t.expect(gs:HasErrors()).toBeFalsy()

		-- After the game starts, units can't be removed
		gs:StartGame()
		t.expect(gs:RemoveUploadedUnit(zone.x, zone.y)).toBe(nil)
		t.expect(gs:GetUnit(zone.x, zone.y) ~= nil).toBeTruthy()
	end)

	t.test("replay string records place id and uploads", function()
		local gs = GameState.new(Places.L12, makeInventory(), GameState.ServerDelayFunc)
		local zone = gs:GetUploadZones()[1]
		gs:UploadUnit(zone.x, zone.y, Scripts.hack)
		gs:StartGame()
		local replay = gs:GetReplay()
		t.expect(replay:sub(1, 4)).toBe("L12;")
		t.expect(replay:find("hack," .. zone.x .. "," .. zone.y, 1, true) ~= nil).toBeTruthy()
	end)
end
