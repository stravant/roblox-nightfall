local GA = require(game.ServerScriptService.GA)

local ServerStatistics = {}

local mPlayerJoinTime = {}

function ServerStatistics:PlayerCheated(userId)
	local dat = mPlayerJoinTime[userId]
	if dat then
		dat.Cheater = true
	end
end

function ServerStatistics:PlayerJoined(userId, isNewPlayer)
	mPlayerJoinTime[userId] = {Timestamp = tick(); IsNew = isNewPlayer}
end

function ServerStatistics:PlayerPlayedLevel(nodeId, didWin)
	-- Record in Google Anylitics
	GA.ReportEvent("Server", "SubmitPlay", nodeId, didWin and 1 or 0)
end

function ServerStatistics:PlayerSkippedLevel(nodeId)
	GA.ReportEvent("Server", "SkipLevel", nodeId, 0)
end

function ServerStatistics:PlayerBoughtSkips(amount)
	GA.ReportEvent("Server", "BoughtSkips", ""..amount, amount)
end

function ServerStatistics:PlayerBoughtUnit(unitId)
	GA.ReportEvent("Server", "BoughtUnit", unitId, 0)
end

function ServerStatistics:PlayerLeft(userId, completedTutorial)
	local timeSpent = math.floor(tick() - mPlayerJoinTime[userId].Timestamp)
	local roundedTimeSpent = math.floor(timeSpent / 30 + 0.5) * 30
	if mPlayerJoinTime[userId].IsNew then
		if completedTutorial then
			GA.ReportEvent("Server", "NewVisit", roundedTimeSpent.."completed", timeSpent)
		else
			GA.ReportEvent("Server", "NewVisit", roundedTimeSpent.."bailed", timeSpent)
		end
	else
		GA.ReportEvent("Server", "Visit", ""..roundedTimeSpent, timeSpent)
	end
	mPlayerJoinTime[userId] = nil
end

-- When a player leaves before they even finish loading
function ServerStatistics:PlayerBounced(userId)
	GA.ReportEvent("Server", "Bounce", "none", userId)
end

-- Loading failed for a player
function ServerStatistics:PlayerLoadFailed(userId)
	GA.ReportEvent("Server", "LoadFailed", "none", userId)
end

-- Loading failed for a node's stats
function ServerStatistics:NodeStatsLoadFailed(err)
	GA.ReportEvent("Server", "NodeStatsLoadFailed", err, 0)
end

return ServerStatistics
