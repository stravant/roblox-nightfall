--!strict
-- Developer debug switches (formerly the __TEST module). All of these should
-- be in their default state in the published game.

local DebugFlags = {}

-- FAILSAFE: the dev-only switches below force off outside Studio, so an
-- accidental publish with one still enabled can't hit real players (mock
-- datastores silently dropping live saves, debug UI, credit boosts, ...)
local function studioOnly(enabled: boolean): boolean
	return enabled and game:GetService("RunService"):IsStudio()
end

-- Whether the tutorial plays for players who haven't beaten it
function DebugFlags:PlayTutorial(): boolean
	return true
end

-- Use MockDataStore instead of real datastores on the server
function DebugFlags:UseMockData(): boolean
	return studioOnly(true)
end

-- Pretend every node is beaten (unlocks the whole netmap)
function DebugFlags:HasBeatenAllNodes(): boolean
	return studioOnly(false)
end

-- Master switch for ALL debug UI (checkpoint picker, debug win button, ...)
function DebugFlags:ShowDebugUI(): boolean
	return studioOnly(false)
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

-- Start fresh players with a huge credit balance (shop/economy testing).
-- Only affects NEW player data, so with real datastores an existing save
-- keeps its balance; with UseMockData every playtest starts fresh anyway.
function DebugFlags:LotsOfCredits(): boolean
	return studioOnly(false)
end

-- Starting credits for fresh player data
function DebugFlags:GetInitialCredits(): number
	return if self:LotsOfCredits() then 999999 else 500
end

return DebugFlags
