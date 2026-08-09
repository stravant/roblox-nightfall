local SoundManager = {}

local mInstalled = false
local mFolder = script.Sounds:Clone()

local mSoundEffectVolume = mFolder.MusicGroup.Volume
local mMusicVolume = mFolder.SoundEffectGroup.Volume

function SoundManager:Install()
	mInstalled = true
	mFolder.Parent = game.Players.LocalPlayer
	for _, sound in pairs(mFolder:GetChildren()) do
		if sound:IsA('Sound') and sound.SoundGroup == nil then
			error("Sound `"..sound.."` missing sound group")
		end
	end
end

function SoundManager:Play(name)
	if not mInstalled then
		SoundManager:Install()
	end
	mFolder[name]:Play()
end

function SoundManager:Stop(name)
	if mInstalled then
		mFolder[name]:Stop()
	end
end

function SoundManager:GetSound(name)
	if not mInstalled then
		SoundManager:Install()
	end
	return mFolder[name]
end

local mSliderCns = {}

local function posToVolume(sliderValue)
	if sliderValue > 0 then
		return math.exp(sliderValue)
	else
		return 1 + sliderValue
	end
end
local function volumeToPos(volume)
	if volume > 1 then
		return math.log(volume)
	else
		return volume - 1
	end
end

function SoundManager:AddMusicSlider(slider)
	slider:Set(volumeToPos(mMusicVolume))
	mSliderCns[slider] = slider.Changed:connect(function(value)
		mMusicVolume = posToVolume(value)
		mFolder.MusicGroup.Volume = mMusicVolume
	end)
end
local mLastSoundSliderTest = 0
function SoundManager:AddSoundSlider(slider)
	slider:Set(volumeToPos(mSoundEffectVolume))
	mSliderCns[slider] = slider.Changed:connect(function(value)
		mSoundEffectVolume = posToVolume(value)
		mFolder.SoundEffectGroup.Volume = mSoundEffectVolume
		if not mFolder.SelectUnit.Playing then
			mFolder.SelectUnit:Play()
		end
	end)
end
function SoundManager:RemoveSlider(slider)
	mSliderCns[slider]:disconnect()
	mSliderCns[slider] = nil
end


return SoundManager
