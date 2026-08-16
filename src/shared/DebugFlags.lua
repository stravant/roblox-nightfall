--!strict
-- Developer debug switches, driven by ATTRIBUTES on Workspace: toggle them
-- from the "Nightfall Debug Flags" plugin panel (they persist with the
-- place file and replicate into playtests).
--
-- FAILSAFE: outside Studio every switch reads its PRODUCTION value below,
-- so an accidentally published attribute can never hit real players.

local RunService = game:GetService("RunService")

-- name -> production value (also the in-Studio default when no attribute
-- is set). The plugin panel keeps its own copy of this list.
local kProduction: { [string]: boolean } = {
	UseMockData = false,
	PlayTutorial = true,
	HasBeatenAllNodes = false,
	ShowDebugUI = false,
	EnableDialogueVoices = false,
	LotsOfCredits = false,
}

local function flag(name: string): boolean
	if not RunService:IsStudio() then
		return kProduction[name]
	end
	local value = workspace:GetAttribute("Debug" .. name)
	if value == nil then
		return kProduction[name]
	end
	return value == true
end

local DebugFlags = {}

-- Whether the tutorial plays for players who haven't beaten it
function DebugFlags:PlayTutorial(): boolean
	return flag("PlayTutorial")
end

-- Use MockDataStore instead of real datastores on the server
function DebugFlags:UseMockData(): boolean
	return flag("UseMockData")
end

-- Pretend every node is beaten (unlocks the whole netmap)
function DebugFlags:HasBeatenAllNodes(): boolean
	return flag("HasBeatenAllNodes")
end

-- Master switch for ALL debug UI (checkpoint picker, debug win button, ...)
function DebugFlags:ShowDebugUI(): boolean
	return flag("ShowDebugUI")
end

-- Show the checkpoint picker overlay before entering the netmap (jump
-- straight to the first entry of a given security level)
function DebugFlags:ShowDebugCheckpoints(): boolean
	return self:ShowDebugUI()
end

-- Speak dialogue lines with text-to-speech voices (off until the narration
-- quality is up to scratch; also broken in Studio, see memory)
function DebugFlags:EnableDialogueVoices(): boolean
	return flag("EnableDialogueVoices")
end

-- Start with a huge credit balance (shop/economy testing). Tops up existing
-- saves on load too, and the boosted balance persists on save.
function DebugFlags:LotsOfCredits(): boolean
	return flag("LotsOfCredits")
end

-- Starting credits for fresh player data
function DebugFlags:GetInitialCredits(): number
	return if self:LotsOfCredits() then 999999 else 500
end

return DebugFlags
