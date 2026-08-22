--!strict

local Badges = {}

Badges.Ids = {
	-- Progression
	PluggedIn = 2096139484827836, -- completed the tutorial
	SecurityClearance2 = 851575149038434, -- reached security level 2 -- Pharmhaus
	SecurityClearance3 = 3798393750720345, -- reached security level 3 -- LM
	SecurityClearance4 = 3164300490270514, -- reached security level 4 -- Donut
	SecurityClearance5 = 1395203055660421, -- reached security level 5 -- PED
	MidnightAverted = 398208957033352, -- beat Dignity's headquarters (the final node)

	-- Core loop
	ConsumerGrade = 3151849355976100, -- first warez purchase
	FullyLoaded = 1941657718797642, -- own every purchasable script
	NodeSweeper = 230198718671557, -- beat every battle node on the netmap

	-- Skill
	FlawlessIntrusion = 1414974788771631, -- win without losing a single script
	Speedrunner = 562548415723946, -- win a node in very few turns
	Minimalist = 662831199291353, -- win a post-tutorial node with a single script
	WorldRecordHolder = 0, -- set a world best on any node leaderboard

	-- Flavor / secret
	KaBoom = 2520022461701687, -- win a battle in which a suicide command fired
	BitByBit = 1133927120334893, -- win with Zero/One casts and NO damage attacks
	PersistencePays = 3123775208724163, -- win a node after many failed attempts
}

-- The order badges are listed in UI (the Ids table is a hash)
Badges.DisplayOrder = {
	"PluggedIn",
	"SecurityClearance2",
	"SecurityClearance3",
	"SecurityClearance4",
	"SecurityClearance5",
	"MidnightAverted",
	"ConsumerGrade",
	"FullyLoaded",
	"NodeSweeper",
	"FlawlessIntrusion",
	"Speedrunner",
	"Minimalist",
	"WorldRecordHolder",
	"KaBoom",
	"BitByBit",
	"PersistencePays",
}

-- Tuning
Badges.SpeedrunnerTurnLimit = 2 -- Speedrunner: win in at most this many turns
Badges.FlawlessMinSecurityLevel = 2 -- FlawlessIntrusion: too easy below this level
Badges.PersistenceWinAttempts = 4 -- PersistencePays: the winning attempt number (3 fails + the win)

return Badges
