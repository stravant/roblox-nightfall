--!strict
-- Developer debug switches (formerly the __TEST module). All of these should
-- be in their default state in the published game.

local DebugFlags = {}

-- Use MockDataStore instead of real datastores on the server
function DebugFlags:UseMockData(): boolean
	return false
end

-- Whether the tutorial plays for players who haven't beaten it
function DebugFlags:PlayTutorial(): boolean
	return true
end

-- Pretend every node is beaten (unlocks the whole netmap)
function DebugFlags:HasBeatenAllNodes(): boolean
	return false
end

-- Master switch for ALL debug UI (checkpoint picker, debug win button, ...)
function DebugFlags:ShowDebugUI(): boolean
	return false
end

-- Show the checkpoint picker on the title screen (jump straight to the first
-- entry of a given security level)
function DebugFlags:ShowDebugCheckpoints(): boolean
	return self:ShowDebugUI()
end

-- Speak dialogue lines with text-to-speech voices (off until the narration
-- quality is up to scratch)
function DebugFlags:EnableDialogueVoices(): boolean
	return false
end

-- Starting credits for fresh player data
function DebugFlags:GetInitialCredits(): number
	return 500
end

return DebugFlags
