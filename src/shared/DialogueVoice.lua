--!strict
-- Text-to-speech voices for the dialogue characters, via the engine's
-- AudioTextToSpeech API. Only the character being talked to is voiced:
-- DialogueView speaks its Text lines through here, and the player's response
-- choices (the buttons) are never narrated.
--
-- One shared speech channel: starting a new line (or hiding the dialogue)
-- cancels whatever was still playing. Speech generation happens on the TTS
-- web service and is rate limited, so every step is best-effort: if the
-- service throttles us or the API is unavailable, the line just shows
-- silently like it always did.

local SoundManager = require(game.ReplicatedStorage.SoundManager)

local RunService = game:GetService("RunService")

-- Voice assignments. VoiceId values are from the text-to-speech guide
-- (create.roblox.com/docs/audio/objects#text-to-speech): 1/2 British m/f,
-- 3/4 US m/f #1, 5/6 US m/f #2, 7/8 Australian m/f, 9/10 retro, 11 host.
-- Pitch is in semitones (-12..12), Speed is 0.5..2.
type VoiceDef = {
	VoiceId: string,
	Pitch: number?,
	Speed: number?,
}
local kVoices: { [string]: VoiceDef } = {
	["Aeacus"] = { VoiceId = "3" }, -- the mentor guiding you
	["Vexedly"] = { VoiceId = "5" },
	["Minish"] = { VoiceId = "4" },
	["Are92"] = { VoiceId = "6" },
	["Dignity"] = { VoiceId = "1", Pitch = -2 }, -- the villain: lowered British male
}

-- Scales the sound-effects volume from the menu slider (which can exceed 1;
-- AudioTextToSpeech.Volume caps at 3)
local kBaseVolume = 0.65

local DialogueVoice = {}

local mTts: any = nil
local mUnavailable = false
local mGeneration = 0

function DialogueVoice:GetVoice(userName: string): VoiceDef?
	return kVoices[userName]
end

local function ensureTts(): any
	if mTts or mUnavailable then
		return mTts
	end
	local ok, err = pcall(function()
		local tts = Instance.new("AudioTextToSpeech")
		tts.Name = "DialogueVoice"
		local output = Instance.new("AudioDeviceOutput")
		output.Name = "Output"
		output.Parent = tts
		local wire = Instance.new("Wire")
		wire.SourceInstance = tts
		wire.TargetInstance = output
		wire.Parent = tts
		tts.Parent = game:GetService("SoundService")
		mTts = tts
	end)
	if not ok then
		mUnavailable = true
		warn("DialogueVoice | Text-to-speech unavailable: " .. tostring(err))
	end
	return mTts
end

-- Speak a dialogue line as the given character. Unvoiced speakers and empty
-- lines just cancel any speech still playing.
function DialogueVoice:Speak(userName: string, text: string)
	if not RunService:IsRunning() then
		return -- edit mode (the test place): never touch the TTS service
	end
	mGeneration += 1
	local generation = mGeneration
	local tts = ensureTts()
	if not tts then
		return
	end
	pcall(function()
		tts:Pause()
	end)
	local voice = kVoices[userName]
	if not voice or text == "" then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			tts.Text = string.sub(text, 1, 300) -- service limit per request
			tts.VoiceId = voice.VoiceId
			tts.Pitch = voice.Pitch or 0
			tts.Speed = voice.Speed or 1
			tts.Volume = math.clamp(kBaseVolume * SoundManager:GetSoundEffectVolume(), 0, 3)
			local status = tts:LoadAsync()
			if generation ~= mGeneration then
				return -- a newer line (or a Stop) superseded this one
			end
			if status == Enum.AssetFetchStatus.Success then
				tts.TimePosition = 0
				tts:Play()
			end
		end)
		if not ok then
			warn("DialogueVoice | Failed to speak line: " .. tostring(err))
		end
	end)
end

-- Cancel any speech in progress (dialogue hidden or destroyed)
function DialogueVoice:Stop()
	mGeneration += 1
	if mTts then
		pcall(function()
			mTts:Pause()
		end)
	end
end

return DialogueVoice
