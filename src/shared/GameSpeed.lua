--!strict
-- Gameplay pacing setting: scales the client-side battle animation delays
-- (multi-square ally moves, enemy turn pacing). Purely visual - the server
-- re-simulates replays with no delays at all, so validation is unaffected.
-- CONTINUOUS 0 (slow, the original pacing) through 2 (fast), interpolating
-- between the anchor scales. Persisted in the save Settings (see Setup /
-- ServerPlayerData).

local Signal = require(game.ReplicatedStorage.Signal)

local GameSpeed = {}

GameSpeed.Changed = Signal.new()

local kAnchorScales = { [0] = 1, [1] = 0.55, [2] = 0.3 }

local mSpeed = 0

function GameSpeed:Get(): number
	return mSpeed
end

-- Multiplier applied to the battle pacing delays: piecewise-linear between
-- the anchors
function GameSpeed:GetDelayScale(): number
	local low = math.floor(mSpeed)
	local a = kAnchorScales[low]
	local b = kAnchorScales[math.min(low + 1, 2)]
	return a + (b - a) * (mSpeed - low)
end

function GameSpeed:Set(speed: number)
	speed = math.clamp(speed, 0, 2)
	if mSpeed ~= speed then
		mSpeed = speed
		GameSpeed.Changed:fire()
	end
end

return GameSpeed
