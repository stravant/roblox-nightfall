--!strict
-- Fire-and-forget badge awarding. Badge ids come from the Badges manifest
-- (src/shared/Badges.lua); unset ids (0) are skipped so partially-configured
-- rollouts are safe. AwardBadge is already a no-op for badges the player owns;
-- the per-session dedupe just avoids wasting the calls.

local Services = require(game.ReplicatedStorage.Services)
local Badges = require(game.ReplicatedStorage.Badges)

local BadgeService = Services:Get("BadgeService")

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

return BadgeAwarder
