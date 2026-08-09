local SoundManager = require(game.ReplicatedStorage.SoundManager)

local BattleSoundLooper = {}

function BattleSoundLooper.new()
	local this = {}

	local mLoopSections = {
		SoundManager:GetSound('DataBattleLoop1');
		SoundManager:GetSound('DataBattleLoop2');
		SoundManager:GetSound('DataBattleLoop3');
		SoundManager:GetSound('DataBattleLoop4');
	}

	local mStepCn = nil
	local mCurrentSound = nil

	local function mStepHandler()
		local timeToGo = not mCurrentSound.Playing or (mCurrentSound.TimeLength - mCurrentSound.TimePosition) < 0.3
		if timeToGo then
			local otherSounds = {}
			for _, sound in pairs(mLoopSections) do
				if sound ~= mCurrentSound then
					table.insert(otherSounds, sound)
				end
			end
			mCurrentSound = otherSounds[math.random(1, #otherSounds)]
			mCurrentSound:Play()
		end
	end

	function this:Play()
		mCurrentSound = mLoopSections[1]
		mCurrentSound:Play()
		mStepCn = game:GetService('RunService').RenderStepped:connect(mStepHandler)
	end

	function this:Destroy()
		if mCurrentSound then
			mCurrentSound:Stop()
		end
		if mStepCn then
			mStepCn:disconnect()
		end
	end

	return this
end

return BattleSoundLooper
