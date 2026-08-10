--!strict
-- Sounds are defined in code. (They used to be a template Sounds folder under
-- this ModuleScript in the place, but Sound.SoundGroup references can't be
-- expressed in Rojo model.json files, so the folder is built at require time.)

type SoundDef = {
	Name: string,
	Id: string,
	Group: string,
	Volume: number,
	Speed: number?,
	Looped: boolean?,
}

local kSoundGroups = { "MusicGroup", "SoundEffectGroup" }

local kSounds: { SoundDef } = {
	{ Name = "Damage", Id = "rbxassetid://1336149560", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "SelectUnit", Id = "rbxassetid://1336157251", Group = "SoundEffectGroup", Volume = 0.5, Speed = 1.8 },
	{ Name = "DataBattleLoop1", Id = "rbxassetid://1336204035", Group = "MusicGroup", Volume = 0.5 },
	{ Name = "DataBattleLoop2", Id = "rbxassetid://1336204129", Group = "MusicGroup", Volume = 0.5 },
	{ Name = "DataBattleLoop3", Id = "rbxassetid://1337579870", Group = "MusicGroup", Volume = 0.5 },
	{ Name = "DataBattleLoop4", Id = "rbxassetid://1337580172", Group = "MusicGroup", Volume = 0.5 },
	{ Name = "MoveUnitBroken", Id = "rbxassetid://1337575761", Group = "SoundEffectGroup", Volume = 0.7 },
	{ Name = "LoseBattle", Id = "rbxassetid://1337731028", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "GrabCredit", Id = "rbxassetid://1347506109", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "MoveUnit", Id = "rbxassetid://1347535735", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "WinBattle", Id = "rbxassetid://1347543844", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "MainBackgroundLoop", Id = "rbxassetid://1347499378", Group = "MusicGroup", Volume = 0.5, Looped = true },
	{ Name = "SelectNode", Id = "rbxassetid://1336184405", Group = "SoundEffectGroup", Volume = 0.5, Speed = 1.75 },
	{ Name = "ErrorSound", Id = "rbxassetid://130840811", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "EnterLuckMonkey", Id = "rbxassetid://1413403674", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "EnterCelularAutoma", Id = "rbxassetid://1413807128", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "EnterDisarray", Id = "rbxassetid://1413807621", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "EnterDrDonut", Id = "rbxassetid://1413808051", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "EnterPED", Id = "rbxassetid://1413808367", Group = "SoundEffectGroup", Volume = 0.5 },
	{ Name = "EnterPharmhaus", Id = "rbxassetid://1413809028", Group = "SoundEffectGroup", Volume = 0.5 },
}

local function buildSoundFolder(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Sounds"

	local groups: { [string]: SoundGroup } = {}
	for _, groupName in kSoundGroups do
		local group = Instance.new("SoundGroup")
		group.Name = groupName
		group.Volume = 1
		group.Parent = folder
		groups[groupName] = group
	end

	for _, def in kSounds do
		local sound = Instance.new("Sound")
		sound.Name = def.Name
		sound.SoundId = def.Id
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.Speed or 1
		sound.Looped = def.Looped or false
		sound.SoundGroup = groups[def.Group]
		sound.Parent = folder
	end

	return folder
end

local SoundManager = {}

local mInstalled = false
local mFolder = buildSoundFolder()

local mMusicVolume = (mFolder:FindFirstChild("MusicGroup") :: SoundGroup).Volume
local mSoundEffectVolume = (mFolder:FindFirstChild("SoundEffectGroup") :: SoundGroup).Volume

function SoundManager:Install()
	mInstalled = true
	mFolder.Parent = game.Players.LocalPlayer
end

function SoundManager:Play(name: string)
	if not mInstalled then
		SoundManager:Install()
	end
	(mFolder :: any)[name]:Play()
end

function SoundManager:Stop(name: string)
	if mInstalled then
		(mFolder :: any)[name]:Stop()
	end
end

function SoundManager:GetSound(name: string): Sound
	if not mInstalled then
		SoundManager:Install()
	end
	return (mFolder :: any)[name]
end

local mSliderCns: { [any]: any } = {}

local function posToVolume(sliderValue: number): number
	if sliderValue > 0 then
		return math.exp(sliderValue)
	else
		return 1 + sliderValue
	end
end
local function volumeToPos(volume: number): number
	if volume > 1 then
		return math.log(volume)
	else
		return volume - 1
	end
end

function SoundManager:AddMusicSlider(slider: any)
	slider:Set(volumeToPos(mMusicVolume))
	mSliderCns[slider] = slider.Changed:connect(function(value: number)
		mMusicVolume = posToVolume(value);
		(mFolder :: any).MusicGroup.Volume = mMusicVolume
	end)
end

function SoundManager:AddSoundSlider(slider: any)
	slider:Set(volumeToPos(mSoundEffectVolume))
	mSliderCns[slider] = slider.Changed:connect(function(value: number)
		mSoundEffectVolume = posToVolume(value);
		(mFolder :: any).SoundEffectGroup.Volume = mSoundEffectVolume
		if not (mFolder :: any).SelectUnit.Playing then
			(mFolder :: any).SelectUnit:Play()
		end
	end)
end

function SoundManager:RemoveSlider(slider: any)
	mSliderCns[slider]:disconnect()
	mSliderCns[slider] = nil
end

return SoundManager
