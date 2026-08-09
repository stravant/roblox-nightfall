local Places = require(game.ReplicatedStorage.Places)

local AILogic = {}

-- Flood fill out from the player units, filling the board with an unsigned
-- distance field which represents how far each square is from a player unit.
-- The first [range] number of squares may not be empty or movable at all,
-- as they represent the range of the enemy trying to move through this
-- distance field.
function AILogic:ComputeDistanceToPlayerUnits(board, unitList, sourceUnit, range, nonce)
	-- Setup
	local openPoints = {}
	
	-- Add all the friendly unit squares as starting points
	for _, unit in pairs(unitList) do
		if not unit.Enemy then
			for _, coord in pairs(unit.Tail) do
				local tile = board[coord.x][coord.y]
				openPoints[tile] = true
				tile.Nonce = nonce
				tile.Distance = 0
			end
		end
	end			
					
	-- Flood fill
	local w = Places.PlaceWidth
	local h = Places.PlaceHeight
	local currentDistance = 0
	while next(openPoints) do
		currentDistance = currentDistance + 1
		local inRange = (currentDistance < range)
		local nextOpenPoints = {}
		for point, _ in pairs(openPoints) do
			local x = point.Coord.x
			local y = point.Coord.y
			-- Unrolled for performance reasons so we can skip an additional iteration
			-- or function call here
			if x > 1 then
				local adj = board[x-1][y]
				if adj.Nonce ~= nonce and ((adj.Filled and not adj.Pickup and (adj.Unit == nil or adj.Unit == sourceUnit)) or inRange) then
					adj.Nonce = nonce
					adj.Distance = currentDistance
					nextOpenPoints[adj] = true
				end
			end
			if x < w then
				local adj = board[x+1][y]
				if adj.Nonce ~= nonce and ((adj.Filled and not adj.Pickup and (adj.Unit == nil or adj.Unit == sourceUnit)) or inRange) then
					adj.Nonce = nonce
					adj.Distance = currentDistance
					nextOpenPoints[adj] = true
				end
			end
			if y > 1 then
				local adj = board[x][y-1]
				if adj.Nonce ~= nonce and ((adj.Filled and not adj.Pickup and (adj.Unit == nil or adj.Unit == sourceUnit)) or inRange) then
					adj.Nonce = nonce
					adj.Distance = currentDistance
					nextOpenPoints[adj] = true
				end
			end
			if y < h then
				local adj = board[x][y+1]
				if adj.Nonce ~= nonce and ((adj.Filled and not adj.Pickup and (adj.Unit == nil or adj.Unit == sourceUnit)) or inRange) then
					adj.Nonce = nonce
					adj.Distance = currentDistance
					nextOpenPoints[adj] = true
				end
			end
		end
		openPoints = nextOpenPoints
	end
end

return AILogic
