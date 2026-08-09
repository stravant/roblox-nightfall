local Signal = require(game.ReplicatedStorage.Signal)
local Netmap = require(game.ReplicatedStorage.Netmap)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)

local ReplaySubmission = {}

ReplaySubmission.SubmissionRecieved = Signal.new()
game.ReplicatedStorage.Remotes.ProcessReplay.OnClientEvent:connect(function(status)
	ReplaySubmission.SubmissionRecieved:fire(status)
end)

function ReplaySubmission:Submit(replay)
	game.ReplicatedStorage.Remotes.ProcessReplay:FireServer(replay)
end

function ReplaySubmission:Skip(placeId)
	local nodeId = nil
	for id, node in pairs(Netmap.ById) do
		if node.PlaceId == placeId then
			nodeId = id
			break
		end
	end
	if nodeId then
		-- Don't really need the if, since the server checks it again,
		-- but nice for debugging
		LocalPlayerData:UseSkip()
		game.ReplicatedStorage.Remotes.SkipLevel:FireServer(nodeId)
	else
		error("Place without nodeId?")
	end
end

return ReplaySubmission
