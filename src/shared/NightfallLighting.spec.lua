-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local NightfallLighting = require(game.ReplicatedStorage.NightfallLighting)
	local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
	local Netmap = require(game.ReplicatedStorage.Netmap)
	local Lighting = game:GetService("Lighting")

	t.test("the story data wires up both nightfall triggers", function()
		t.expect(Netmap.ById.ph49.Conversation.Function.Type).toBe("beginNightfall")
		t.expect(Netmap.ById['end'].Conversation.Function.Type).toBe("endNightfall")
	end)

	t.test("nightfall is derived from security level 5 + the final node", function()
		-- LocalPlayerData is not loaded in the test place, so stub the
		-- final-node beaten check and drive the real security level
		local originalHasBeaten = LocalPlayerData.HasBeatenNode
		local originalLevel = LocalPlayerData:GetSecurityLevel()
		local endBeaten = false
		LocalPlayerData.HasBeatenNode = function(_self, id)
			t.expect(id).toBe('end')
			return endBeaten
		end

		LocalPlayerData:SetSecurityLevel(4)
		t.expect(LocalPlayerData:IsNightfallActive()).toBeFalsy()

		LocalPlayerData:SetSecurityLevel(5)
		t.expect(LocalPlayerData:IsNightfallActive()).toBeTruthy()

		endBeaten = true
		t.expect(LocalPlayerData:IsNightfallActive()).toBeFalsy()

		LocalPlayerData.HasBeatenNode = originalHasBeaten
		LocalPlayerData:SetSecurityLevel(originalLevel)
	end)

	t.test("activating dims the lighting, deactivating restores it exactly", function()
		local before = Lighting.Brightness
		local beforeAmbient = Lighting.OutdoorAmbient

		NightfallLighting:SetActive(true, true)
		t.expect(NightfallLighting:IsActive()).toBeTruthy()
		t.expect(Lighting.Brightness < before).toBeTruthy()

		-- Repeat activation is a no-op (won't restart a transition)
		NightfallLighting:SetActive(true, true)
		t.expect(NightfallLighting:IsActive()).toBeTruthy()

		NightfallLighting:SetActive(false, true)
		t.expect(NightfallLighting:IsActive()).toBeFalsy()
		t.expect(Lighting.Brightness).toBe(before)
		t.expect(Lighting.OutdoorAmbient).toBe(beforeAmbient)
	end)
end
