--!strict
-- Gameplay pacing setting: scales the client-side battle animation delays
-- (multi-square ally moves, enemy turn pacing). Purely visual - the server
-- re-simulates replays with no delays at all, so validation is unaffected.
-- 0 = slow (the original pacing), 1 = medium, 2 = fast. Persisted in the
-- save Settings (see Setup / ServerPlayerData).

local Signal = require(game.ReplicatedStorage.Signal)

local GameSpeed = {}

GameSpeed.Changed = Signal.new()

local kDelayScales = { [0] = 1, [1] = 0.55, [2] = 0.3 }

local mSpeed = 0

function GameSpeed:Get(): number
	return mSpeed
end

-- Multiplier applied to the battle pacing delays
function GameSpeed:GetDelayScale(): number
	return kDelayScales[mSpeed]
end

function GameSpeed:Set(speed: number)
	speed = math.clamp(math.round(speed), 0, 2)
	if mSpeed ~= speed then
		mSpeed = speed
		GameSpeed.Changed:fire()
	end
end

return GameSpeed
