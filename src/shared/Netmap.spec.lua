-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- Cross-reference validation of the netmap data: broken references here used
-- to only surface as errors during play (e.g. pd46 pointing at the
-- nonexistent place 'L56').
return function(t)
	local Netmap = require(game.ReplicatedStorage.Netmap)
	local Places = require(game.ReplicatedStorage.Places)
	local Scripts = require(game.ReplicatedStorage.Scripts)

	t.test("every node's PlaceId exists in Places", function()
		for id, node in pairs(Netmap.ById) do
			if Places[node.PlaceId] == nil then
				error("Node " .. id .. " references missing place " .. tostring(node.PlaceId))
			end
		end
	end)

	t.test("every node link points at an existing node", function()
		for id, node in pairs(Netmap.ById) do
			for _, adjId in pairs(node.Links) do
				if Netmap.ById[adjId] == nil then
					error("Node " .. id .. " links to missing node " .. tostring(adjId))
				end
			end
		end
	end)

	t.test("every node's entry Sound exists in the SoundManager", function()
		local SoundManager = require(game.ReplicatedStorage.SoundManager)
		local checked = 0
		for id, node in pairs(Netmap.ById) do
			if node.Sound then
				-- GetSound errors on an unknown name (this caught the
				-- 'EnterLuckyMonkey' vs 'EnterLuckMonkey' mismatch)
				local ok = pcall(function()
					return SoundManager:GetSound(node.Sound)
				end)
				if not ok then
					error("Node " .. id .. " references missing sound " .. tostring(node.Sound))
				end
				checked += 1
			end
		end
		t.expect(checked > 0).toBeTruthy()
	end)

	t.test("WarezOrder lists exactly the node's stock", function()
		for id, node in pairs(Netmap.ById) do
			if node.WarezOrder then
				local ordered = {}
				for _, unitId in pairs(node.WarezOrder) do
					if not node.Warez or node.Warez[unitId] == nil then
						error("Node " .. id .. " WarezOrder lists unsold script " .. tostring(unitId))
					end
					if ordered[unitId] then
						error("Node " .. id .. " WarezOrder repeats " .. tostring(unitId))
					end
					ordered[unitId] = true
				end
				for unitId in pairs(node.Warez) do
					if not ordered[unitId] then
						error("Node " .. id .. " WarezOrder is missing " .. tostring(unitId))
					end
				end
			end
		end
	end)

	t.test("every conversation target resolves to a part or an end", function()
		local conversations = { Netmap.TutorialCallout, Netmap.PostTutorialConversation }
		for _, node in pairs(Netmap.ById) do
			if node.Conversation then
				table.insert(conversations, node.Conversation)
			end
		end
		for _, convo in pairs(conversations) do
			for partName, part in pairs(convo.Parts) do
				for _, key in pairs({ "Target1", "Target2" }) do
					local target = part[key]
					if target ~= nil
						and target ~= "end"
						and target:sub(1, 4) ~= "end:"
						and convo.Parts[target] == nil then
						error("Conversation part " .. partName .. " targets missing part " .. tostring(target))
					end
				end
			end
		end
	end)

	t.test("every warez listing sells an existing script", function()
		for id, node in pairs(Netmap.ById) do
			if node.Warez then
				for unitId, cost in pairs(node.Warez) do
					if Scripts[unitId] == nil then
						error("Warez node " .. id .. " sells missing script " .. tostring(unitId))
					end
					if type(cost) ~= "number" then
						error("Warez node " .. id .. " has a non-number cost for " .. unitId)
					end
				end
			end
		end
	end)
end
