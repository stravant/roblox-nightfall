--!strict
-- Server side of session journey recording (the UX study tool): accumulates
-- the client's batched event stream per session, persists it (debounced),
-- and serves the viewer's list/get requests to eligible viewers only.
--
-- Journeys are diagnostics: everything is best-effort, capped, and never
-- affects gameplay.

local Services = require(game.ReplicatedStorage.Services)

local PlayersService = Services:Get('Players')

local DataStoreService = require(game.ServerScriptService.DataStoreService)

local kMaxEventsPerSession = 4000
local kMaxBatchSize = 200
local kMaxDetailLength = 80
local kSaveInterval = 30 -- seconds between persists of a live session
local kMaxListedJourneys = 30

local JourneyService = {}

-- Who may view journeys: the game's owner (or anyone in Studio). Injectable
-- so tests can exercise both the allow and deny paths.
JourneyService.IsViewer = function(player: any): boolean
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

function JourneyService.install(remotes: any)
	-- player -> { Key, Record = {UserId, Name, Start, Events}, LastSave }
	local mSessions: { [any]: any } = {}

	local function sessionFor(player)
		local session = mSessions[player]
		if not session then
			-- Time-prefixed key (chronological listing) with a random tail:
			-- the log has no per-player linkage, sessions are just entries
			session = {
				Key = ("j_%010d_%04d"):format(os.time(), math.random(0, 9999)),
				Record = {
					UserId = player.UserId,
					Name = player.Name,
					Start = os.time(),
					Events = {},
				},
				LastSave = -math.huge,
			}
			mSessions[player] = session
		end
		return session
	end

	local function saveSession(session)
		session.LastSave = os.clock()
		DataStoreService:SaveJourney(session.Key, session.Record)
	end

	remotes.JourneyEvents.OnServerEvent:connect(function(player, batch)
		if type(batch) ~= "table" or #batch > kMaxBatchSize then
			return
		end
		local session = sessionFor(player)
		local events = session.Record.Events
		for _, entry in pairs(batch) do
			if #events >= kMaxEventsPerSession then
				break
			end
			if type(entry) == "table"
				and type(entry[1]) == "number"
				and type(entry[2]) == "string"
				and (entry[3] == nil or type(entry[3]) == "string") then
				table.insert(events, {
					entry[1],
					entry[2]:sub(1, kMaxDetailLength),
					if entry[3] then entry[3]:sub(1, kMaxDetailLength) else nil,
				})
			end
		end
		if os.clock() - session.LastSave > kSaveInterval then
			saveSession(session)
		end
	end)

	-- Viewer: summaries of the most recent sessions, newest first
	local mSummaryCache = nil -- { At, List }
	remotes.GetJourneyList.OnServerInvoke = function(player)
		if not JourneyService.IsViewer(player) then
			return nil
		end
		if mSummaryCache and os.clock() - mSummaryCache.At < 60 then
			return mSummaryCache.List
		end
		local list = {}
		for _, key in pairs(DataStoreService:ListJourneyKeys(kMaxListedJourneys)) do
			local record = DataStoreService:GetJourney(key)
			if record then
				local events = record.Events or {}
				local last = events[#events]
				table.insert(list, {
					Key = key,
					UserId = record.UserId,
					Name = record.Name,
					Start = record.Start,
					EventCount = #events,
					Duration = if last then last[1] else 0,
				})
			end
		end
		mSummaryCache = { At = os.clock(), List = list }
		return list
	end

	remotes.GetJourney.OnServerInvoke = function(player, key)
		if not JourneyService.IsViewer(player) then
			return nil
		end
		if type(key) ~= "string" then
			return nil
		end
		-- Serve the live copy when the session is still in progress
		for _, session in pairs(mSessions) do
			if session.Key == key then
				return session.Record
			end
		end
		return DataStoreService:GetJourney(key)
	end

	PlayersService.PlayerRemoving:connect(function(player)
		local session = mSessions[player]
		if session then
			mSessions[player] = nil
			if #session.Record.Events > 0 then
				saveSession(session)
			end
		end
	end)
end

return JourneyService
