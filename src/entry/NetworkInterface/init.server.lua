-- Thin entry: all handler logic lives in the requireable NetworkController
-- module (so integration tests can install it onto mock remotes); this script
-- just installs it against the real remotes and owns the things only an entry
-- script can (BindToClose, the debug Check hook).

local NetworkController = require(game.ServerScriptService.NetworkController)
local DataStoreService = require(game.ServerScriptService.DataStoreService)
local ReplayChecker = require(game.ServerScriptService.ReplayChecker)
local GameState = require(game.ReplicatedStorage.GameState)

NetworkController.install(game.ReplicatedStorage.Remotes)

-- Debug: paste a replay string into the Check StringValue to validate it
script.Check.Changed:connect(function()
	local result = ReplayChecker:Check(script.Check.Value, GameState.ServerDelayFunc)
	print("Checking, valid=", result.Valid, "won=", result.Won)
end)

game:BindToClose(function()
	DataStoreService:WaitForSavesToComplete()
end)
