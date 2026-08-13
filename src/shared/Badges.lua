--!strict
-- BADGE MANIFEST
--
-- >>> FILL THIS IN: create each badge in Creator Hub (your experience ->
-- >>> Engagement -> Badges) and paste its badge id here. <<<
--
-- A badge left at 0 is simply never awarded, so partial rollout is fine.
-- The award hooks live server-side in BadgeAwarder / ServerPlayerData.

local Badges = {}

Badges.Ids = {
	-- Progression
	PluggedIn = 0, -- completed the tutorial
	SecurityClearance2 = 0, -- reached security level 2
	SecurityClearance3 = 0, -- reached security level 3
	SecurityClearance4 = 0, -- reached security level 4
	SecurityClearance5 = 0, -- reached security level 5
	MidnightAverted = 0, -- beat Dignity's headquarters (the final node)

	-- Core loop
	ConsumerGrade = 0, -- first warez purchase
	FullyLoaded = 0, -- own every purchasable script
	NodeSweeper = 0, -- beat every battle node on the netmap

	-- Skill
	FlawlessIntrusion = 0, -- win without losing a single script
	Speedrunner = 0, -- win a node in very few turns
	Minimalist = 0, -- win a post-tutorial node with a single script
	WorldRecordHolder = 0, -- set a world best on any node leaderboard

	-- Flavor / secret
	KaBoom = 0, -- win a battle in which a suicide command fired
	BitByBit = 0, -- win using only Bit-Man style grid commands
	PersistencePays = 0, -- win a node after many failed attempts
}

-- Tuning
Badges.SpeedrunnerTurnLimit = 3 -- Speedrunner: win in at most this many turns
Badges.PersistenceWinAttempts = 6 -- PersistencePays: the winning attempt number (5 fails + the win)

return Badges
