--!strict
-- The onboarding funnel step numbers, shared between the client fire sites
-- (Remotes.FunnelStep) and the server (ServerStatistics). Roblox counts only
-- the first instance of each step per player, and skipped steps auto-complete
-- the earlier ones, so sites can log unconditionally.
--
-- Steps marked [client] are reported by the client via Remotes.FunnelStep
-- (detail steps, best-effort); the rest are logged directly by the server
-- from authoritative events.

local OnboardingSteps = {
	Joined = 1, -- first-session load
	TutorialEntered = 2, -- [client] plugged into the HQ node
	ScriptPlaced = 3, -- [client] first script dragged onto an upload zone
	BattleStarted = 4, -- [client] pressed Start Databattle
	FirstAttack = 5, -- [client] landed the tutorial's first attack
	TutorialBeaten = 6, -- BeatTutorial remote processed
	NodeChosen = 7, -- [client] entered a first real (non-tutorial) battle
	FirstRealWin = 8, -- first valid winning replay
	ShopVisited = 9, -- [client] opened a warez shop
	ScriptPurchased = 10, -- first shop purchase
	ReachedSecurity2 = 11, -- security level 2 story trigger
}

OnboardingSteps.StepNames = {
	[1] = "Joined",
	[2] = "TutorialEntered",
	[3] = "ScriptPlaced",
	[4] = "BattleStarted",
	[5] = "FirstAttack",
	[6] = "TutorialBeaten",
	[7] = "NodeChosen",
	[8] = "FirstRealWin",
	[9] = "ShopVisited",
	[10] = "ScriptPurchased",
	[11] = "ReachedSecurity2",
}

-- The steps the client is allowed to report (everything else is
-- server-authoritative and ignored if a client claims it)
OnboardingSteps.ClientReportable = {
	[OnboardingSteps.TutorialEntered] = true,
	[OnboardingSteps.ScriptPlaced] = true,
	[OnboardingSteps.BattleStarted] = true,
	[OnboardingSteps.FirstAttack] = true,
	[OnboardingSteps.NodeChosen] = true,
	[OnboardingSteps.ShopVisited] = true,
}

return OnboardingSteps
