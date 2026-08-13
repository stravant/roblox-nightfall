-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local DialogueVoice = require(game.ReplicatedStorage.DialogueVoice)
	local Netmap = require(game.ReplicatedStorage.Netmap)

	t.test("every dialogue character in the netmap has a voice", function()
		local conversations = {
			Netmap.TutorialCallout,
			Netmap.PostTutorialConversation,
		}
		for _, node in pairs(Netmap.ById) do
			if node.Conversation then
				table.insert(conversations, node.Conversation)
			end
		end
		t.expect(#conversations > 2).toBeTruthy()
		for _, conversation in pairs(conversations) do
			t.expect(DialogueVoice:GetVoice(conversation.User) ~= nil).toBeTruthy()
		end
	end)

	t.test("speaking outside a running game is inert", function()
		-- Edit mode (the test place): no TTS instances get created and no
		-- speech requests are made
		DialogueVoice:Speak("Aeacus", "Hello there.")
		DialogueVoice:Stop()
		t.expect(game:GetService("SoundService"):FindFirstChild("DialogueVoice")).toBe(nil)
	end)
end
