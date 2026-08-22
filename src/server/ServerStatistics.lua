--!strict
-- Server analytics, backed by Roblox AnalyticsService.
--
-- What gets logged:
-- - Progression (path "Databattles"): one Start immediately followed by
--   Complete (win) or Fail (loss) per submitted replay; level = the node's
--   security level, levelName = the node id. Logged post-hoc at submission
--   time since the server only sees finished battles.
-- - Onboarding funnel: step 1 "Joined" (first session) -> step 2
--   "TutorialBeaten".
-- - Economy (currency "Credits"): battle and story rewards as Gameplay-type
--   sources, warez script purchases as Shop-type sinks (sku = script id),
--   always with the resulting balance.
-- - Custom events: EarlyQuit, LevelSkipped, SkipsPurchased, InvalidReplay,
--   PlayerBounced, PlayerDataLoadFailed.
--
-- Every call resolves ids to live Player instances (AnalyticsService requires
-- them) and is pcall-wrapped: analytics must never break gameplay.

local Services = require(game.ReplicatedStorage.Services)

local AnalyticsService = Services:Get("AnalyticsService")
local Players = Services:Get("Players")

local Netmap = require(game.ReplicatedStorage.Netmap)
local OnboardingSteps = require(game.ReplicatedStorage.OnboardingSteps)

local kCurrency = "Credits"
local kProgressionPath = "Databattles"

local ServerStatistics = {}

local function resolve(playerOrId: any): Player?
	if typeof(playerOrId) == "Instance" then
		return playerOrId :: Player
	end
	if type(playerOrId) == "table" and playerOrId.UserId then
		-- Mock Player object from an integration test
		return playerOrId :: any
	end
	return Players:GetPlayerByUserId(playerOrId)
end

local function try(what: string, f: () -> ())
	local st, err = pcall(f)
	if not st then
		warn("ServerStatistics | " .. what .. " failed: " .. tostring(err))
	end
end

local function context(value: string): { [string]: any }
	return { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = value }
end

local function nodeLevel(nodeId: string): number
	local node = Netmap.ById[nodeId]
	return (node and node.Level) or 0
end

--------------------------------------------------------------------------------
-- Onboarding (see OnboardingSteps for the full funnel definition)
--------------------------------------------------------------------------------

function ServerStatistics:OnboardingStep(playerOrId: any, step: number)
	local player = resolve(playerOrId)
	local stepName = OnboardingSteps.StepNames[step]
	if player and stepName then
		try("Onboarding " .. stepName, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
		end)
	end
end

function ServerStatistics:PlayerJoined(playerOrId: any, isNewPlayer: boolean)
	if isNewPlayer then
		self:OnboardingStep(playerOrId, OnboardingSteps.Joined)
	end
end

function ServerStatistics:PlayerBeatTutorial(playerOrId: any)
	self:OnboardingStep(playerOrId, OnboardingSteps.TutorialBeaten)
end

-- Which gesture placed a script during setup: 'drag', 'clickUnit' (script
-- clicked with no zone selected), or 'clickZone' (zone first, then script)
function ServerStatistics:PlacementMethod(playerOrId: any, method: string)
	local player = resolve(playerOrId)
	if player then
		try("PlacementMethod", function()
			AnalyticsService:LogCustomEvent(player, "PlacementMethod", 1, context(method))
		end)
	end
end

-- Which path the player picked in the post-tutorial wrap-up chat:
-- 'explore' (netmap) or 'battle' (straight into lm12). One custom event,
-- split by the custom field.
function ServerStatistics:PostTutorialChoice(playerOrId: any, choice: string)
	local player = resolve(playerOrId)
	if player then
		try("PostTutorialChoice", function()
			AnalyticsService:LogCustomEvent(player, "PostTutorialChoice", 1, context(choice))
		end)
	end
end

--------------------------------------------------------------------------------
-- Progression
--------------------------------------------------------------------------------

function ServerStatistics:PlayerPlayedLevel(playerOrId: any, nodeId: string, didWin: boolean)
	local player = resolve(playerOrId)
	if not player then
		return
	end
	local level = nodeLevel(nodeId)
	try("Progression", function()
		-- The server only sees completed battles, so the Start/end pair is
		-- logged together; attempt and completion rates stay meaningful
		AnalyticsService:LogProgressionStartEvent(player, kProgressionPath, level, nodeId)
		if didWin then
			AnalyticsService:LogProgressionCompleteEvent(player, kProgressionPath, level, nodeId)
		else
			AnalyticsService:LogProgressionFailEvent(player, kProgressionPath, level, nodeId)
		end
	end)
	if didWin and nodeId ~= 'hq' then
		-- First real (post-tutorial) win; Roblox keeps only the first instance
		self:OnboardingStep(player, OnboardingSteps.FirstRealWin)
	end
end

function ServerStatistics:PlayerQuitLevelEarly(playerOrId: any, nodeId: string)
	local player = resolve(playerOrId)
	if player then
		try("EarlyQuit", function()
			AnalyticsService:LogCustomEvent(player, "EarlyQuit", 1, context(nodeId))
		end)
	end
end

function ServerStatistics:PlayerSkippedLevel(playerOrId: any, nodeId: string)
	local player = resolve(playerOrId)
	if player then
		try("LevelSkipped", function()
			AnalyticsService:LogCustomEvent(player, "LevelSkipped", 1, context(nodeId))
		end)
	end
end

--------------------------------------------------------------------------------
-- Economy (credits)
--------------------------------------------------------------------------------

-- reason: short label like "BattleReward" / "StoryReward"
function ServerStatistics:CreditsEarned(playerOrId: any, amount: number, endingBalance: number, reason: string)
	local player = resolve(playerOrId)
	if player and amount > 0 then
		try("CreditsEarned", function()
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				kCurrency,
				amount,
				endingBalance,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				nil,
				context(reason))
		end)
	end
end

function ServerStatistics:UnitPurchased(playerOrId: any, unitId: string, price: number, endingBalance: number)
	local player = resolve(playerOrId)
	if player then
		try("UnitPurchased", function()
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Sink,
				kCurrency,
				price,
				endingBalance,
				Enum.AnalyticsEconomyTransactionType.Shop.Name,
				unitId)
		end)
		self:OnboardingStep(player, OnboardingSteps.ScriptPurchased)
	end
end

function ServerStatistics:SecurityLevelReached(playerOrId: any, level: number)
	if level >= 2 then
		self:OnboardingStep(playerOrId, OnboardingSteps.ReachedSecurity2)
	end
end

function ServerStatistics:PlayerBoughtSkips(playerOrId: any, amount: number)
	-- The Robux transaction itself is tracked by Roblox natively; this tracks
	-- how many skips enter circulation
	local player = resolve(playerOrId)
	if player then
		try("SkipsPurchased", function()
			AnalyticsService:LogCustomEvent(player, "SkipsPurchased", amount)
		end)
	end
end

--------------------------------------------------------------------------------
-- Health / abuse signals
--------------------------------------------------------------------------------

-- An invalid replay, with everything needed to diagnose it remotely:
-- field 1 = the failed-replay store key (pull the full replay string with
-- DataStoreService:GetFailedReplay and re-run it in a spec), field 2 = the
-- first failure reason from the re-simulation, field 3 = play context
-- (place, how far it got, replay size).
-- AnalyticsService rejects custom field values containing , " or '
-- (failure reasons carry coordinates like "MissingUnit 7,4") and values
-- longer than 50 characters
local function sanitizeField(value: string): string
	return (value:gsub("[,\"']", ";")):sub(1, 50)
end

-- One event per unit fielded in a finished battle, split by unit id and
-- outcome: which scripts do players actually take into battle, and which
-- ones carry wins
function ServerStatistics:UnitUsed(playerOrId: any, unitId: string, won: boolean)
	local player = resolve(playerOrId)
	if player then
		try("UnitUsed", function()
			AnalyticsService:LogCustomEvent(player, "UnitUsed", 1, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = sanitizeField(unitId),
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = if won then "win" else "loss",
			})
		end)
	end
end

-- What a player did after a beaten netmap node dropped them on its stats
-- page: how they left ('close' or 'play_again') and whether they browsed
-- other nodes' stats while there ('browsed' or 'stayed')
function ServerStatistics:StatsPageOutcome(playerOrId: any, exit: string, browsedOthers: boolean)
	local player = resolve(playerOrId)
	if player then
		try("StatsPageOutcome", function()
			AnalyticsService:LogCustomEvent(player, "StatsPageOutcome", 1, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = exit,
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = if browsedOthers then "browsed" else "stayed",
			})
		end)
	end
end

function ServerStatistics:PlayerCheated(playerOrId: any, replayId: string?, reason: string?, contextInfo: string?)
	local player = resolve(playerOrId)
	if player then
		try("InvalidReplay", function()
			AnalyticsService:LogCustomEvent(player, "InvalidReplay", 1, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = sanitizeField(replayId or "none"),
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = sanitizeField(reason or "Unknown"),
				[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = sanitizeField(contextInfo or ""),
			})
		end)
	end
end

function ServerStatistics:PlayerLeft(playerOrId: any, completedTutorial: boolean)
	-- Session length / retention are tracked by Roblox natively; nothing to do
end

-- The session's last databattle, logged as the player leaves: which node
-- they last attempted and whether they won it. Logged with EMPTY fields
-- when no battle was attempted this session (e.g. the tutorial isn't
-- beaten yet) - the event still counts the departure.
function ServerStatistics:LastPlayed(playerOrId: any, nodeId: string?, won: boolean?)
	local player = resolve(playerOrId)
	if player then
		try("LastPlayed", function()
			local fields = nil
			if nodeId then
				fields = {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = sanitizeField(nodeId),
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = if won then "win" else "loss",
				}
			end
			AnalyticsService:LogCustomEvent(player, "LastPlayed", 1, fields)
		end)
	end
end

-- When a player leaves before they even finish loading
function ServerStatistics:PlayerBounced(playerOrId: any)
	local player = resolve(playerOrId)
	if player then
		try("PlayerBounced", function()
			AnalyticsService:LogCustomEvent(player, "PlayerBounced", 1)
		end)
	end
end

-- Loading failed for a player
function ServerStatistics:PlayerLoadFailed(playerOrId: any)
	local player = resolve(playerOrId)
	if player then
		try("PlayerDataLoadFailed", function()
			AnalyticsService:LogCustomEvent(player, "PlayerDataLoadFailed", 1)
		end)
	end
end

-- Loading failed for a node's stats (no player context: AnalyticsService
-- custom events are player-scoped, so this stays log-only)
function ServerStatistics:NodeStatsLoadFailed(err: string)
	warn("ServerStatistics | Node stats load failed: " .. tostring(err))
end

return ServerStatistics
