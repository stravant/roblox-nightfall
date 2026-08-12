--!strict
-- Service locator: code that talks to Roblox services fetches them through
-- here so integration tests can substitute mocks.
--
--   local Services = require(game.ReplicatedStorage.Services)
--   local Players = Services:Get("Players")
--
-- Tests call Services:SetMock("Players", mock) BEFORE requiring the modules
-- under test (consumers capture their services at require time).

local Services = {}

local mMocks: { [string]: any } = {}

function Services:Get(name: string): any
	local mock = mMocks[name]
	if mock ~= nil then
		return mock
	end
	return game:GetService(name)
end

function Services:SetMock(name: string, mock: any)
	mMocks[name] = mock
end

return Services
