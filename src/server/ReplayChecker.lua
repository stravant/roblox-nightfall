local Places = require(game.ReplicatedStorage.Places)
local Scripts = require(game.ReplicatedStorage.Scripts)
local Netmap = require(game.ReplicatedStorage.Netmap)
local GameState = require(game.ReplicatedStorage.GameState)

-- L12;hack,7,10;slingshot,10,10;S;U10,10MnnCstone,10,7U7,10MnnCslice,7,7EU10,8MnnCstone,10,5U7,8MnnCslice,7,5EU10,6MnwCstone,7,4U7,6MnCslice,7,4EU7,5MeeCslice,9,4EU9,5MenCslice,9,4E

-- L13;hack,5,7;hack,6,7;hack,6,8;S;U6,7MneCslice,8,6U6,8MeeCslice,9,8U5,7MnnCslice,5,4EU7,6MnnCslice,7,3U8,8MeeCslice,10,7U5,5MneCslice,6,5EU7,4MneCslice,8,4U10,8MnnCslice,10,5U6,4MssCslice,7,6EU8,3MesCslice,10,4U10,6MenCslice,10,5U6,6MeeCslice,9,6EU11,5MneCslice,12,3U8,6MneCslice,9,4EU12,4MwCslice,10,4E

local ReplayChecker = {}

local function getPlaceId(replay)
	local index = replay:find(";")
	if index then
		return replay:sub(1, index-1), replay:sub(index+1, -1)
	else
		return "", replay
	end
end

local function getUploadsGameplay(replay)
	local index = replay:find("S;")
	if index then
		local uploads = {}
		for upload in replay:sub(1, index-1):gmatch("([^;]*);") do
			local name, x, y = upload:gmatch("(%w*),(%d*),(%d*)")()
			table.insert(uploads, {
				Id = name;
				X = tonumber(x) or 0;
				Y = tonumber(y) or 0;
			})
		end
		return uploads, replay:sub(index+2, -1)
	else
		return nil
	end
end

local function getTurnActions(replay)
	local index = replay:find("E")
	if not index then
		return nil
	end
	
	local turnData = replay:sub(1, index-1)
	local rest = replay:sub(index+1, -1)
	
	local unitMoves = {}
	for x, y, activity in turnData:gmatch("U(%d+),(%d+)([^U]*)") do
		local unitMove = {
			X = tonumber(x) or 0;
			Y = tonumber(y) or 0;			
		}
		local moves = activity:gmatch("M([nesw]+)")()
		local command, cx, cy = activity:gmatch("C(%w+),(%d+),(%d+)")()
		if moves then
			local moveData = {}
			for i = 1, #moves do
				local c = moves:sub(i, i)
				local dx, dy = 0, 0;
				if c == 'n' then
					dy = -1
				elseif c == 's' then
					dy = 1
				elseif c == 'e' then
					dx = 1
				elseif c == 'w' then
					dx = -1
				end
				table.insert(moveData, {
					DX = dx;
					DY = dy;
				})
			end
			unitMove.MoveData = moveData
		end
		if command then
			unitMove.CommandData = {
				Id = command;
				X = tonumber(cx) or 0;
				Y = tonumber(cy) or 0;
			}
		end
		table.insert(unitMoves, unitMove)
	end
	return unitMoves, rest
end

local unitInventory = {}
for id, unit in pairs(Scripts) do
	if not unit.Enemy then
		table.insert(unitInventory, {
			Id = id;
			Count = 2;
		})
	end
end

local function inBounds(x, y)
	return x >= 1 and y >= 1 and x <= Places.PlaceWidth and y <= Places.PlaceHeight
end

function ReplayChecker:Check(replay, delayFunc, viewPlaybackFunc)
	local result = {
		Valid = false;
		Won = false;
		Credits = 0;
		MoveCount = 0;
		TurnCount = 0;
		UnitCount = 0;
		NodeId = nil;
		EarlyQuit = false;
		-- Badge/analysis signals
		UnitsLost = 0; -- friendly units that didn't survive
		UsedSuicideCommand = false; -- Kamikazee / Self-Destruct fired
		UsedCommandTypes = {}; -- set of command Type strings used
		-- Diagnostics for invalid replays (see the InvalidReplay analytics
		-- event / the failed-replay store)
		PlaceId = nil;
		FailureReason = nil; -- set whenever Valid comes back false
		UnitsUsed = {}; -- uploaded unit ids, duplicates included
	}

	-- Get the place
	local placeId, rest = getPlaceId(replay)
	result.PlaceId = placeId
	local place = Places[placeId]
	if not place then
		warn("ReplayChecker | Missing place")
		result.FailureReason = "MissingPlace " .. placeId
		return result
	end
	
	-- Check that it is in a node
	local foundInNode = nil;
	for nodeId, data in pairs(Netmap.ById) do
		if data.PlaceId == placeId then
			foundInNode = nodeId
			break
		end
	end
	if foundInNode then
		result.NodeId = foundInNode
	else
		warn("ReplayChecker | Missing node for place")
		result.FailureReason = "MissingNode " .. placeId
		return result
	end
	
	-- Did they concede before doing starting? 
	--  That's fine, in that case it's valid but they lost
	if rest == "" then
		result.EarlyQuit = true
		result.Valid = true
		return result
	end
	
	-- Get the uploads and gameplay
	local uploads, gameplay = getUploadsGameplay(rest)
	if not uploads then
		warn("ReplayChecker | Failed to parse uploads.")
		result.FailureReason = "ParseUploads"
		return result
	end
	
	-- Create the state
	local gameState = GameState.new(place, unitInventory, delayFunc)
	
	-- If we want a reference to the game state, then pass it out
	if viewPlaybackFunc then
		viewPlaybackFunc(gameState)
	end
	
	-- Upload the units
	for _, upload in pairs(uploads) do
		gameState:UploadUnit(upload.X, upload.Y, Scripts[upload.Id])
		-- Add upload to count tracking (ids kept for the UnitUsed analytics)
		result.UnitCount = result.UnitCount + 1
		table.insert(result.UnitsUsed, upload.Id)
	end
	if gameState:HasErrors() then
		warn("ReplayChecker | Errors after uploading units.")
		result.FailureReason = "UploadErrors: " .. (gameState:GetFirstInvalidReason() or "unknown")
		return result
	end
	
	-- Start the game
	gameState:StartGame()
	
	-- Do the turns
	while true do
		-- Add turn to count tracking
		result.TurnCount = result.TurnCount + 1
		local unitMoves;
		unitMoves, gameplay = getTurnActions(gameplay)
		if not unitMoves or gameState:HasErrors() or gameState:HasLost() then
			-- Game is over, or we ran into invalidity
			break
		end
		for _, unitMove in pairs(unitMoves) do
			if not inBounds(unitMove.X, unitMove.Y) then
				warn("ReplayChecker | Out of bounds unit location")
				result.FailureReason = "OutOfBoundsUnit " .. unitMove.X .. "," .. unitMove.Y
				return result
			end
			local unit = gameState:GetUnit(unitMove.X, unitMove.Y)
			if not unit then
				warn("ReplayChecker | Missing unit")
				result.FailureReason = "MissingUnit " .. unitMove.X .. "," .. unitMove.Y
					.. " turn " .. result.TurnCount
				return result
			end
			if unitMove.MoveData then
				-- Add move to count tracking
				result.MoveCount = result.MoveCount + 1
				for _, delta in pairs(unitMove.MoveData) do
					gameState:UnitMove(unit, unit.Tail[1].x + delta.DX, unit.Tail[1].y + delta.DY)
				end
			end
			if unitMove.CommandData then
				if not inBounds(unitMove.CommandData.X, unitMove.CommandData.Y) then
					warn("ReplayChecker | Out of bounds command target")
					result.FailureReason = "OutOfBoundsTarget " .. unitMove.CommandData.X .. "," .. unitMove.CommandData.Y
					return result
				end
				-- Track what kinds of commands the play used (badge signals)
				local commandDef = unit.Definition.Commands[unitMove.CommandData.Id]
				if commandDef then
					result.UsedCommandTypes[commandDef.Type] = true
					if commandDef.Cost >= unit.Definition.MaxSize then
						result.UsedSuicideCommand = true
					end
				end
				gameState:UnitExecute(unit, unitMove.CommandData.Id, unitMove.CommandData.X, unitMove.CommandData.Y)
			end
		end
		-- Next turn if we haven't won yet
		-- Note that we don't have to 
		if not gameState:HasWon() then
			gameState:EndTurn()
		end
	end
	
	-- How many of the uploaded units made it to the end
	local survivors = 0
	for unit in pairs(gameState:GetUnits()) do
		if not unit.Enemy then
			survivors = survivors + 1
		end
	end
	result.UnitsLost = math.max(0, result.UnitCount - survivors)

	if gameState:HasErrors() then
		warn("ReplayChecker | Play had internal errors")
		-- The first rejected action is the diagnostic that matters: it
		-- marks where the re-simulation diverged from the client's play
		result.FailureReason = "Sim: " .. (gameState:GetFirstInvalidReason() or "unknown")
			.. " (turn " .. result.TurnCount .. ")"
	elseif gameState:HasWon() then
		result.Valid = true
		result.Won = true
		result.Credits = gameState:GetCreditsEarned()
	else
		-- They need not have HasLost() in order to have lost, they may have conceded the battle
		-- HasLost vs conceded is mostly for statistics tracking.
		result.Valid = true
		result.Won = false
	end
	
	return result
end

return ReplayChecker





