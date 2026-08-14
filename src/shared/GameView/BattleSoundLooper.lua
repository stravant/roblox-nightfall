local SoundManager = require(game.ReplicatedStorage.SoundManager)

local BattleSoundLooper = {}

-- The looper mutates section volumes while fading in after a node entry
-- sting; capture the authored volumes ONCE, before any looper has touched
-- them, so an interrupted fade can never redefine a section's base volume
local kSectionNames = { 'DataBattleLoop1', 'DataBattleLoop2', 'DataBattleLoop3', 'DataBattleLoop4' }
local kBaseVolumes = {}
for _, name in pairs(kSectionNames) do
	kBaseVolumes[name] = SoundManager:GetSound(name).Volume
end

-- Start fading the loop in when this much of the entry sting remains
local kFadeLeadSeconds = 3
-- Give the entry sting this long to start playing before giving up on it
local kStartGraceSeconds = 3
-- Never hold the battle silent longer than this (unloaded/looping sting)
local kMaxHoldSeconds = 30

function BattleSoundLooper.new()
	local this = {}

	local mLoopSections = {}
	for _, name in pairs(kSectionNames) do
		table.insert(mLoopSections, SoundManager:GetSound(name))
	end

	local mStepCn = nil
	local mWaitCn = nil
	local mCurrentSound = nil

	local function setVolumeScale(scale)
		for _, sound in pairs(mLoopSections) do
			sound.Volume = kBaseVolumes[sound.Name] * scale
		end
	end

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
		setVolumeScale(1)
		mCurrentSound = mLoopSections[1]
		mCurrentSound:Play()
		mStepCn = game:GetService('RunService').RenderStepped:connect(mStepHandler)
	end

	-- Hold the loop while the node entry sting plays, then fade the loop in
	-- over the sting's final seconds. Degrades to a plain Play if the sting
	-- never starts or never ends.
	function this:PlayAfter(entrySound: Sound)
		local started = false
		local heldFor = 0
		local fadeTime = kFadeLeadSeconds
		local fadedFor = 0
		local fading = false
		mWaitCn = game:GetService('RunService').RenderStepped:connect(function(dt)
			if fading then
				fadedFor += dt
				local alpha = math.min(fadedFor / fadeTime, 1)
				setVolumeScale(alpha)
				if alpha >= 1 then
					mWaitCn:disconnect()
					mWaitCn = nil
				end
				return
			end
			heldFor += dt
			if not started then
				if entrySound.Playing then
					started = true
				elseif heldFor > kStartGraceSeconds then
					fading = true -- never started: just fade the loop in now
					this:Play()
					setVolumeScale(0)
				end
				return
			end
			local remaining = entrySound.TimeLength - entrySound.TimePosition
			if not entrySound.Playing
				or (entrySound.TimeLength > 0 and remaining <= kFadeLeadSeconds)
				or heldFor > kMaxHoldSeconds then
				fading = true
				if entrySound.Playing and remaining > 0.5 then
					fadeTime = math.min(remaining, kFadeLeadSeconds)
				end
				this:Play()
				setVolumeScale(0)
			end
		end)
	end

	function this:Destroy()
		if mCurrentSound then
			mCurrentSound:Stop()
		end
		if mStepCn then
			mStepCn:disconnect()
		end
		if mWaitCn then
			mWaitCn:disconnect()
		end
		-- An interrupted fade must not leave the shared section sounds quiet
		setVolumeScale(1)
	end

	return this
end

return BattleSoundLooper
