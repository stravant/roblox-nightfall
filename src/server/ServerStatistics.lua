--!strict
-- Analytics seam. These hooks used to forward to Google Universal Analytics
-- (removed after Google shut UA down); the call sites in NetworkInterface and
-- DataStoreService are kept so a future analytics backend can be wired up
-- here without touching the game flow.

local ServerStatistics = {}

function ServerStatistics:PlayerCheated(userId: number)
end

function ServerStatistics:PlayerJoined(userId: number, isNewPlayer: boolean)
end

function ServerStatistics:PlayerPlayedLevel(nodeId: string, didWin: boolean)
end

function ServerStatistics:PlayerSkippedLevel(nodeId: string)
end

function ServerStatistics:PlayerBoughtSkips(amount: number)
end

function ServerStatistics:PlayerBoughtUnit(unitId: string)
end

function ServerStatistics:PlayerLeft(userId: number, completedTutorial: boolean)
end

-- When a player leaves before they even finish loading
function ServerStatistics:PlayerBounced(userId: number)
end

-- Loading failed for a player
function ServerStatistics:PlayerLoadFailed(userId: number)
end

-- Loading failed for a node's stats
function ServerStatistics:NodeStatsLoadFailed(err: string)
end

return ServerStatistics
