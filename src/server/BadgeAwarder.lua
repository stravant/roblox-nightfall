--!strict
-- Fire-and-forget badge awarding. Badge ids come from the Badges manifest
-- (src/shared/Badges.lua); unset ids (0) are skipped so partially-configured
-- rollouts are safe. AwardBadge is already a no-op for badges the player owns;
-- the per-session dedupe just avoids wasting the calls.

local Services = require(game.ReplicatedStorage.Services)
local Badges = require(game.ReplicatedStorage.Badges)
local Netmap = require(game.ReplicatedStorage.Netmap)

local BadgeService = Services:Get("BadgeService")

-- Everything sold at any warez node: the FullyLoaded universe. (Some scripts
-- are story-granted or starting gear; they don't gate the badge.)
local kPurchasableScripts: { [string]: boolean } = {}
for _, node in pairs(Netmap.ById) do
	if node.Warez then
		for unitId, _cost in pairs(node.Warez) do
			kPurchasableScripts[unitId] = true
		end
	end
end

local BadgeAwarder = {}

local mAwardedThisSession: { [string]: boolean } = {}

function BadgeAwarder:Award(player: any, badgeKey: string)
	local badgeId = Badges.Ids[badgeKey]
	if badgeId == nil then
		warn("BadgeAwarder | Unknown badge key " .. tostring(badgeKey))
		return
	end
	if badgeId == 0 then
		return -- not configured in the manifest yet
	end
	local dedupeKey = tostring(player.UserId) .. "_" .. badgeKey
	if mAwardedThisSession[dedupeKey] then
		return
	end
	mAwardedThisSession[dedupeKey] = true
	task.spawn(function()
		local ok, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			warn("BadgeAwarder | Failed to award " .. badgeKey .. ": " .. tostring(err))
		end
	end)
end

-- The badge keys awarded to this player during this server's lifetime. Used
-- to show freshly earned badges immediately even if the badge web API hasn't
-- caught up with (or a player's ownership was cached before) the award.
function BadgeAwarder:GetSessionAwards(player: any): { [string]: boolean }
	local awards = {}
	for key in pairs(Badges.Ids) do
		if mAwardedThisSession[tostring(player.UserId) .. "_" .. key] then
			awards[key] = true
		end
	end
	return awards
end

-- The win-condition badges that depend only on the validated replay result
-- (the world-record badge needs the leaderboards and stays with the caller).
-- attemptCount includes the winning attempt; securityLevel is the level the
-- battle was fought at (pre-trigger).
function BadgeAwarder:EvaluateWinBadges(player: any, replayResult: any, attemptCount: number, securityLevel: number)
	if replayResult.TurnCount <= Badges.SpeedrunnerTurnLimit then
		self:Award(player, "Speedrunner")
	end
	if replayResult.UnitCount == 1 then
		self:Award(player, "Minimalist")
	end
	-- Flawless is trivial on the early nodes, so it only counts once the
	-- netmap starts fighting back
	if replayResult.UnitsLost == 0 and securityLevel >= Badges.FlawlessMinSecurityLevel then
		self:Award(player, "FlawlessIntrusion")
	end
	if replayResult.UsedSuicideCommand then
		self:Award(player, "KaBoom")
	end
	-- Bit by Bit: won with Bit-Man doing the dirty work - at least one
	-- Zero/One cast and NO damage-dealing attacks. Support casts (grows,
	-- boosts, slows) don't disqualify: the point is winning without
	-- fighting, not swearing off every helper.
	local used = replayResult.UsedCommandTypes or {}
	if (used['zero'] or used['one']) and not used['damage'] then
		self:Award(player, "BitByBit")
	end
	if attemptCount >= Badges.PersistenceWinAttempts then
		self:Award(player, "PersistencePays")
	end
end

-- The purchase badges, from the player's inventory after a successful buy
function BadgeAwarder:EvaluatePurchaseBadges(player: any, unitInventory: any)
	self:Award(player, "ConsumerGrade")
	local owned: { [string]: boolean } = {}
	for _, entry in pairs(unitInventory) do
		owned[entry.Id] = true
	end
	for unitId in pairs(kPurchasableScripts) do
		if not owned[unitId] then
			return
		end
	end
	self:Award(player, "FullyLoaded")
end

return BadgeAwarder
