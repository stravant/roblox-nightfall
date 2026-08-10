--!strict
-- Developer debug switches (formerly the __TEST module). All of these should
-- be in their default state in the published game.

local DebugFlags = {}

-- Use MockDataStore instead of real datastores on the server
function DebugFlags:UseMockData(): boolean
	return true
end

-- Whether the tutorial plays for players who haven't beaten it
function DebugFlags:PlayTutorial(): boolean
	return true
end

-- Pretend every node is beaten (unlocks the whole netmap)
function DebugFlags:HasBeatenAllNodes(): boolean
	return false
end

-- Starting credits for fresh player data
function DebugFlags:GetInitialCredits(): number
	return 500
end

return DebugFlags
