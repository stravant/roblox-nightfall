local Places = require(game.ReplicatedStorage.Places)
local Scripts = require(game.ReplicatedStorage.Scripts)
local Signal = require(game.ReplicatedStorage.Signal)

local AILogic = require(script.AILogic)

local GameState = {}

function GameState.ServerDelayFunc(which)
	return -- nothing to do 
end

GameState.ClientDelays = {
	DeleteSector = 0.2;
	GrowSector = 0.2;
	MoveEnemy = 0.2;
	AttackIntent = 0.4;
	MoveAlly = 0.2;
}

function GameState.ClientDelayFunc(which)
	local GameSpeed = require(game.ReplicatedStorage.GameSpeed)
	wait(GameState.ClientDelays[which] * GameSpeed:GetDelayScale())
end

function GameState.new(placeData, unitInventory, delayFunc)
	local this = {}
	
	this.GameStarted = Signal.new()
	this.UnitAdded = Signal.new()
	this.UnitRemoved = Signal.new()
	this.UnitUpdated = Signal.new()
	this.TurnChanged = Signal.new()
	this.TileAdded = Signal.new()
	this.TileRemoved = Signal.new()
	
	-- Pickups collected
	this.CreditsCollected = Signal.new()
	this.CreditsRestored = Signal.new()
	this.CodesCollected = Signal.new()
	
	-- Sector of a program deleted at x/y
	this.SectorDeleted = Signal.new()
	
	-- Sector of a program added at x/y
	this.SectorAdded = Signal.new()
	
	-- Action from a program targeted x/y
	this.ActionTargeted = Signal.new()	
	
	-- Show the enemy attack intention, set of squares to target
	this.ShowEnemyIntention = Signal.new()
	this.EnemySelectUnit = Signal.new()	
	
	-- Move a unit
	this.UnitMoved = Signal.new()
	
	-- Game is over (did we win?)
	this.GameEnded = Signal.new()
	
	-- 2d array of the units on the board
	local mBoard = {--[[
		Coord(x, y), 
		Filled,
		Pickup,
		Unit, 
		Nonce
	]]}
	-- Utility accesor function for the board
	local function getBoard(c)
		return mBoard[c.x][c.y]
	end
	local function getBoardXY(x, y)
		local col = mBoard[x]
		return col and col[y]
	end
	
	local function printBoard()
		for y = 1, Places.PlaceHeight do
			local row = ""
			for x = 1, Places.PlaceWidth do
				local tile = mBoard[x][y]
				if tile.Unit then
					row = row.."O"
				elseif tile.Filled then
					row = row.."#"
				else
					row = row.."_"
				end
			end
			print(row)
		end
	end
	
	function this:GetMapId()
		return placeData.Id
	end
	
	-- The replay
	local mReplay = ""..placeData.Id..";"
	
	-- List of the upload zones
	local mUploadZoneList = {}
	
	-- Codes
	local mHasCodes = false
	local mCodesLeft = 0
	
	-- Total extra credits collected
	local mExtraCreditsCollected = 0
	
	-- Units available for upload
	local mUnitInventory = {}
	
	-- Units on the board
	local mUnitSet = {}
	local mUnitList = {}
	-- Monotonic creation order, for iteration that must be REPLAY-STABLE
	-- (see startAITurn); resurrection via undo reuses the unit and keeps it
	local mNextUnitOrder = 0

	-- Fire UnitUpdated only for still-live units: some paths (marking the
	-- previous mover Done, undo actions) can reach a unit that already fired
	-- UnitRemoved, and view code drops its per-unit state on UnitRemoved.
	local function fireUnitUpdated(unit)
		if mUnitSet[unit] then
			this.UnitUpdated:fire(unit)
		end
	end
	
	-- Last unit that the user moved, unit to mark as done if they start moving
	-- a different unit or use an action
	local mLastMovedUnit = nil
	
	-- The history of units moved / activated this turn and how to undo them
	local mThisTurnHistory = {}
	
	-- Has the game started and what turn is it if it has?
	local mGameStarted = false
	local mIsEnemyTurn = false
	local mConceded = false
	
	-- Used to flag during flood-filling operations of the board without having to do
	-- an extra "clear flag" pass first.
	local mNonce = 1
	
	-- Have invalid actions been attempted? (Cheating detection)
	local mInvalidActionCount = 0
	-- The FIRST invalid reason: when the server re-simulation rejects a
	-- replay, this is the diagnostic that explains why (surfaced through
	-- ReplayChecker into the InvalidReplay analytics event and the
	-- failed-replay store). print, NOT warn: the message variants
	-- (coordinates, sizes) would each become their own error-report entry
	-- and spam the log.
	local mFirstInvalidReason = nil
	local function invalidAction(message)
		print("INVALID: " .. message)
		mInvalidActionCount = mInvalidActionCount + 1
		if not mFirstInvalidReason then
			mFirstInvalidReason = message
		end
	end

	-- Play statistics (mirrors what ReplayChecker computes server-side)
	local mPlayTurnCount = 0
	local mPlayMoveCount = 0
	local mPlayUnitCount = 0
	
	-- Utility function for creating enemies and creating units 
	-- when they are uploaded
	-- optOriginalUnit is the original unit when we are undoing the death
	-- of a unit
	local function createUnit(unitData, isEnemy, tail, optOriginalUnit)
		local unit;
		if optOriginalUnit then
			unit = optOriginalUnit
			unit.Done = false
			unit.MoveLeft = unit.Move
			unit.Tail = tail
		else
			-- Copy the tail so we don't trash the place data copy of it
			local tailCopy = {}
			for i, coord in pairs(tail) do
				tailCopy[i] = coord
			end
			mNextUnitOrder = mNextUnitOrder + 1
			unit  = {
				Definition = unitData;
				Tail = tailCopy;
				Enemy = isEnemy;
				MaxSize = unitData.MaxSize;
				Move = unitData.Move;
				MoveLeft = unitData.Move;
				Color = unitData.Color;
				Done = false;
				OrderIndex = mNextUnitOrder;
			}
		end
		for _, coord in pairs(tail) do
			getBoard(coord).Unit = unit
		end
		mUnitSet[unit] = true
		table.insert(mUnitList, unit)
		return unit
	end
	
	local function finishPlayerTurn()
		-- Clear done markers
		for _, unit in pairs(mUnitList) do
			if not unit.Enemy then
				unit.Done = false
				fireUnitUpdated(unit)
			end		
		end
		
		-- No more last moved unit
		mLastMovedUnit = nil
		-- Move mThisTurnHistory into the total game history
		for _, entry in pairs(mThisTurnHistory) do
			if entry.MoveString ~= "" or entry.CommandString then
				local str = "U"..entry.OriginalTail[1].x..","..entry.OriginalTail[1].y
				if entry.MoveString ~= "" then
					str = str.."M"..entry.MoveString
				end
				if entry.CommandString then
					str = str.."C"..entry.CommandString
				end
				mReplay = mReplay..str
			end
		end
		mReplay = mReplay.."E"
		mPlayTurnCount = mPlayTurnCount + 1
		-- Emptied, NOT nil'd: the game can end mid-turn (winning move), after
		-- which stray actions from the same interaction still consult it
		mThisTurnHistory = {}
	end
	
	local function getThisTurnHistoryEntry(unit)
		if #mThisTurnHistory > 0 and mThisTurnHistory[#mThisTurnHistory].Unit == unit then
			return mThisTurnHistory[#mThisTurnHistory]
		end
		local tailCopy = {}
		for i, coord in pairs(unit.Tail) do
			tailCopy[i] = coord
		end
		local entry = {
			Unit = unit;
			OriginalTail = tailCopy;
			MoveString = ""; -- NESW characters -> direction moved
			CreditsCollected = {};
		}
		table.insert(mThisTurnHistory, entry)
		return entry
	end
	
	local function restoreUnit(unit, tail)
		if mUnitSet[unit] then
			-- If the unit is still around, just modify it's tail
			for _, coord in pairs(unit.Tail) do --> uninstall from board
				getBoard(coord).Unit = nil
			end
			unit.Tail = tail
			for _, coord in pairs(unit.Tail) do --> install into board
				getBoard(coord).Unit = unit
			end
			unit.Done = false
			unit.MoveLeft = unit.Move
			fireUnitUpdated(unit)
		else
			-- Otherwise, we need to recreate it
			createUnit(unit.Definition, unit.Enemy, tail, unit)
			this.UnitAdded:fire(unit)
		end
	end
	
	local function endGame(didWin)
		-- Fire the ended signal with the amount of credits we earned
		this.GameEnded:fire(didWin, this:GetCreditsEarned())
	end
	
	local function moveUnitImpl(unit, targetSq)
		-- Add to the history
		if not mIsEnemyTurn then
			mPlayMoveCount = mPlayMoveCount + 1
			local history = getThisTurnHistoryEntry(unit)
			
			-- Add the move to the moves list
			if targetSq.Coord.x == unit.Tail[1].x + 1 then
				history.MoveString = history.MoveString .. 'e'
			elseif targetSq.Coord.x == unit.Tail[1].x - 1 then
				history.MoveString = history.MoveString .. 'w'
			elseif targetSq.Coord.y == unit.Tail[1].y + 1 then
				history.MoveString = history.MoveString .. 's'
			elseif targetSq.Coord.y == unit.Tail[1].y - 1 then
				history.MoveString = history.MoveString .. 'n'
			else
				error("Screwed up move?? ("..unit.Tail[1].x..","..unit.Tail[1].y.." -> "..targetSq.Coord.x..","..targetSq.Coord.y..")")
			end
		end		
		
		-- If there is a different last moved unit, it becomes done
		if mLastMovedUnit and mLastMovedUnit ~= unit and not mLastMovedUnit.Done then
			if not mLastMovedUnit.Enemy then
				mLastMovedUnit.Done = true
				fireUnitUpdated(mLastMovedUnit)
			end
		end
		-- ALWAYS track the mover (this used to only happen in the else branch,
		-- so the unit moved after a partial-mover was never itself marked done
		-- when a third unit moved)
		mLastMovedUnit = unit
		
		-- We have a valid move. Perform it
		if targetSq.Unit == unit then
			-- We are moving onto ourself. First delete the square in question from the
			-- tail
			for i, coord in pairs(unit.Tail) do
				if coord.x == targetSq.Coord.x and coord.y == targetSq.Coord.y then
					table.remove(unit.Tail, i)
					break
				end
			end
		end
		
		-- Now move onto the new square
		table.insert(unit.Tail, 1, targetSq.Coord)
		targetSq.Unit = unit
		
		-- Finally, if we are over-length thanks to this move, remove the
		-- last square from the tail
		if #unit.Tail > unit.MaxSize then
			getBoard(unit.Tail[#unit.Tail]).Unit = nil
			table.remove(unit.Tail, #unit.Tail)
		end
		
		if not unit.Enemy then
			-- And record the move
			unit.MoveLeft = unit.MoveLeft - 1
			
			-- Did we move onto a pickup?
			if targetSq.Pickup then
				if targetSq.Pickup == 'codes' then
					mCodesLeft = mCodesLeft - 1
					this.CodesCollected:fire(targetSq.Coord.x, targetSq.Coord.y)
				elseif targetSq.Pickup == 'credits' then
					mExtraCreditsCollected = mExtraCreditsCollected + 1
					this.CreditsCollected:fire(targetSq.Coord.x, targetSq.Coord.y, placeData.CreditReward * 0.5)
					table.insert(getThisTurnHistoryEntry(unit).CreditsCollected, targetSq.Coord)
				else
					error("Unknown pickup `"..tostring(targetSq.Pickup).."`??")
				end
				targetSq.Pickup = nil
			end
		end		
		
		-- Update the UI
		fireUnitUpdated(unit)
		
		-- For sounds
		this.UnitMoved:fire(unit)
	end
	
	local function unitExecuteImpl(unit, command, x, y)
		local function deleteSector(unit)
			local coord = unit.Tail[#unit.Tail]
			unit.Tail[#unit.Tail] = nil
			getBoard(coord).Unit = nil
			if #unit.Tail == 0 then
				mUnitSet[unit] = nil
				for i, r in pairs(mUnitList) do
					if r == unit then
						table.remove(mUnitList, i)
						break
					end
				end
				this.UnitRemoved:fire(unit)
			else
				fireUnitUpdated(unit)
			end
			this.SectorDeleted:fire(coord.x, coord.y, unit.Color)
			delayFunc('DeleteSector')
		end
		
		local function shuffle(list, seed)
			local r = Random.new(seed)
			for i = #list, 2, -1 do
				local target = r:NextInteger(1, i)
				list[target], list[i] = list[i], list[target]
			end
		end

		local function addSector(unit)
			for i = #unit.Tail, 1, -1 do
				local coord = unit.Tail[i]
				-- All four orthogonal neighbors (the old direction decode only
				-- ever produced right/down/diagonal, so grow silently failed
				-- when the free space was up or left of the tail)
				local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
				shuffle(dirs, coord.x * Places.PlaceWidth + coord.y)
				for j = 1, 4 do
					local x = coord.x + dirs[j][1]
					local y = coord.y + dirs[j][2]
					local square = getBoardXY(x, y)
					if square and square.Filled and not square.Unit and not square.Pickup then
						square.Unit = unit
						table.insert(unit.Tail, {x = x, y = y})
						fireUnitUpdated(unit)
						this.SectorAdded:fire(x, y, unit.Color)
						delayFunc('GrowSector')
						return
					end
				end
			end
		end
		
		-- Make sure that we have an undo entry
		if not mIsEnemyTurn then
			local history = getThisTurnHistoryEntry(unit)	
			
			-- And once they do, record what they did
			history.CommandString = command.Id..","..x..","..y
		end
		
		-- Check target
		local target = this:GetUnit(x, y)
		if not target and command.Type ~= 'zero' and command.Type ~= 'one' then
			-- Done
			unit.Done = true
			fireUnitUpdated(unit)
			return
		end		
		
		-- Notify about targeting
		this.ActionTargeted:fire(x, y, command.Type)
		
		-- Perform attack
		if command.Type == 'damage' then
			if not mIsEnemyTurn then
				local historyEntry = mThisTurnHistory[#mThisTurnHistory]
				local originalEnemyTail = {}
				for i, coord in pairs(target.Tail) do
					originalEnemyTail[i] = coord
				end
				historyEntry.UndoAction = function()
					restoreUnit(target, originalEnemyTail)
				end
			end
			for i = 1, math.min(#target.Tail, command.Amount) do
				deleteSector(target)
			end
		elseif command.Type == 'sizeMod' then
			if not mIsEnemyTurn then
				local historyEntry = mThisTurnHistory[#mThisTurnHistory]
				local originalMaxSize = target.MaxSize
				historyEntry.UndoAction = function()
					target.MaxSize = originalMaxSize
					fireUnitUpdated(target)
				end
			end
			target.MaxSize = target.MaxSize + command.Amount
			fireUnitUpdated(target)
		elseif command.Type == 'speedMod' then
			if not mIsEnemyTurn then
				local historyEntry = mThisTurnHistory[#mThisTurnHistory]
				local originalMove = target.Move
				local originalMoveLeft = target.MoveLeft
				historyEntry.UndoAction = function()
					target.Move = originalMove
					target.MoveLeft = originalMoveLeft
					fireUnitUpdated(target)
				end
			end
			target.Move = math.min(10, math.max(0, target.Move + command.Amount))
			-- Also adjust the movement remaining THIS turn, so a boost is
			-- usable immediately (and a slow takes effect immediately)
			target.MoveLeft = math.min(10, math.max(0, target.MoveLeft + command.Amount))
			fireUnitUpdated(target)
		elseif command.Type == 'zero' then
			if mBoard[x][y].Filled then
				if not mIsEnemyTurn then
					local historyEntry = mThisTurnHistory[#mThisTurnHistory]
					historyEntry.UndoAction = function()
						mBoard[x][y].Filled = true
						this.TileAdded:fire(x, y)
					end
				end
				mBoard[x][y].Filled = false
				this.TileRemoved:fire(x, y)
			end
		elseif command.Type == 'one' then
			if not mBoard[x][y].Filled then
				if not mIsEnemyTurn then
					local historyEntry = mThisTurnHistory[#mThisTurnHistory]
					historyEntry.UndoAction = function()
						mBoard[x][y].Filled = false
						this.TileRemoved:fire(x, y)
					end
				end
				mBoard[x][y].Filled = true
				this.TileAdded:fire(x, y)
			end
		elseif command.Type == 'grow' then
			if not mIsEnemyTurn then
				local historyEntry = mThisTurnHistory[#mThisTurnHistory]
				local originalEnemyTail = {}
				for i, coord in pairs(target.Tail) do
					originalEnemyTail[i] = coord
				end
				historyEntry.UndoAction = function()
					restoreUnit(target, originalEnemyTail)
				end
			end
			for i = 1, command.Amount do
				addSector(target)
			end
		else
			error("Bad command type: "..tostring(command.Type))
		end
		
		-- Perform cost
		for i = 1, math.min(#unit.Tail, command.Cost) do
			deleteSector(unit)
		end

		-- Done
		if not unit.Enemy then
			unit.Done = true
		end
		-- The cost may have consumed the unit entirely (deleteSector already
		-- fired UnitRemoved); fireUnitUpdated skips dead units
		fireUnitUpdated(unit)
	end
	
	-- Start the player's turn (Refresh their units)
	local function startPlayerTurn()
		mLastMovedUnit = nil	
		mThisTurnHistory = {}	
		
		for _, unit in pairs(mUnitList) do
			if not unit.Enemy then
				unit.Done = false
				unit.MoveLeft = unit.Move
				fireUnitUpdated(unit)
			end
		end
	end
	
	local function getAdjacentSquares(coord)
		local adj = {}
		if coord.x > 1 then
			table.insert(adj, mBoard[coord.x-1][coord.y])
		end
		if coord.y > 1 then
			table.insert(adj, mBoard[coord.x][coord.y-1])
		end
		if coord.x < Places.PlaceWidth then
			table.insert(adj, mBoard[coord.x+1][coord.y])
		end
		if coord.y < Places.PlaceHeight then
			table.insert(adj, mBoard[coord.x][coord.y+1])
		end
		return adj
	end
	
	-- Enemy AI movement
	local function doAIMove(unit)
		-- Select
		this.EnemySelectUnit:fire(unit)		
		
		-- The attack it will be using
		local attack = unit.Definition.CommandList[1]
		
		-- Compute the gradient towards the player units
		mNonce = mNonce + 1
		local nonce = mNonce
		AILogic:ComputeDistanceToPlayerUnits(mBoard, mUnitList, unit, attack.Range, nonce)
		
		-- Now have the unit walk down the gradient map, towards the player
		-- units, but only as fast as gets it there right as it runs out of
		-- available moves plus attack range.
		-- TODO: Inserting extra moves when the unit has more move than it needs to get there
		-- TODO: Need a different strategy if 
		local finalBestDistance;
		local initialSquare = getBoard(unit.Tail[1])
		if initialSquare.Nonce == nonce then
			finalBestDistance = initialSquare.Distance
		end
		for i = 1, unit.Move do
			local moveLeft = unit.Move - i + 1
			local adjs = getAdjacentSquares(unit.Tail[1])
			local bestSquare = nil
			local bestDistance = math.huge
			local longestInrangeSquare = nil
			local longestInrangeDistance = 0
			for _, adj in pairs(adjs) do
				local movable = (adj.Filled and (adj.Unit == nil or adj.Unit == unit))
				if adj.Nonce == nonce and movable then
					if adj.Distance < bestDistance then
						bestSquare = adj
						bestDistance = adj.Distance
					end
					if adj.Distance > longestInrangeDistance and adj.Distance <= (moveLeft - 1) + attack.Range then
						longestInrangeSquare = adj
						longestInrangeDistance = adj.Distance
					end
				end
			end
			-- If we are in range, try to move towards them while making as many moves as
			-- possible to increase our size
			if longestInrangeSquare then
				bestSquare = longestInrangeSquare
				bestDistance = longestInrangeDistance
			end
			if bestSquare then
				local inRangeDistance = (moveLeft - 1) + attack.Range
				if getBoard(unit.Tail[1]).Distance <= inRangeDistance and bestDistance > inRangeDistance then
					-- Make sure we don't move out of range from in range on our last move of the turn
					-- just because it's the only move we have.
					break
				elseif #unit.Tail == unit.MaxSize and getBoard(unit.Tail[1]).Distance <= attack.Range then
					-- If we're already at max size and in range, then stop moving
					break
				else
					-- Otherwise, do the move
					finalBestDistance = bestDistance
					moveUnitImpl(unit, bestSquare)
					delayFunc('MoveEnemy')
				end
			end
		end

		-- Show enemy trying to attack
		local attackSquares = this:GetCommandRange(unit, attack.Id)
		this.ShowEnemyIntention:fire(attackSquares, attack.Type)
		
		-- Find where to attack, if able. The distance field can claim
		-- in-range with no attackable target: the flood fill seeds from
		-- player squares regardless of Filled, while the command range only
		-- covers filled squares (e.g. a player unit standing on a tile
		-- Bit-Man zeroed out from under it) — so never trust the distance
		-- alone, attack only when a target actually exists.
		local targetCoord = nil
		if finalBestDistance and finalBestDistance <= attack.Range and #unit.Tail >= attack.SizeReq then
			for _, coord in pairs(attackSquares) do
				local sq = getBoard(coord)
				local target = sq.Unit
				if target and not target.Enemy then
					targetCoord = coord
					break
				end
			end
		end

		-- Wait a bit before clearing the intention either way: even without
		-- an attack it reminds the player how much range the unit has
		delayFunc('AttackIntent')
		this.ShowEnemyIntention:fire({}) --> clear the intention
		if targetCoord then
			unitExecuteImpl(unit, attack, targetCoord.x, targetCoord.y)
		end
	end
	
	-- Do the AI turn
	local function startAITurn()
		-- Iterate a snapshot: doAIMove can remove units from mUnitList
		-- (killing a player unit), and mutating the list mid-pairs made the
		-- iterator skip the enemy that shifted into the removed slot
		local units = {}
		for i, unit in ipairs(mUnitList) do
			units[i] = unit
		end
		-- Act in CREATION order, not list order: undoing a kill re-appends
		-- the resurrected unit to mUnitList, and undo is invisible to the
		-- replay - so the live client's list order diverges from the
		-- server re-simulation's, and enemy acting order changes outcomes
		-- (the source of the live MissingUnit replay rejections). Creation
		-- order is identical on both sides: place enemies, then uploads in
		-- recorded order, with resurrection reusing the unit and its index.
		table.sort(units, function(a, b)
			return a.OrderIndex < b.OrderIndex
		end)
		for _, unit in ipairs(units) do
			-- The unit itself may have died meanwhile (e.g. cost/self-damage)
			if unit.Enemy and mUnitSet[unit] then
				doAIMove(unit)
				if this:HasLost() then
					break -- don't keep moving units (AI won, or player conceded)
				end
			end
		end
	end
	
	
	
	-----------------------------------------------------
	-------------------- Public API ---------------------
	-----------------------------------------------------
	
	function this:DelayFunc(ident)
		delayFunc(ident)
	end
	
	function this:GetPlaceBackground()
		return placeData.Background
	end	
	
	function this:GetAvailableUnits()
		return mUnitInventory
	end	
	
	function this:GetUnits()
		return mUnitSet
	end
	
	function this:GetUploadZones()
		return mUploadZoneList
	end
	
	function this:GetInitialCodes()
		return placeData.CodeList
	end
	
	function this:GetInitialCredits()
		return placeData.ExtraCreditList
	end
	
	function this:IsFilled(x, y)
		return mBoard[x][y].Filled
	end
	
	function this:HasErrors()
		return mInvalidActionCount > 0
	end

	-- The first rejected action's reason, for replay-failure diagnostics
	function this:GetFirstInvalidReason()
		return mFirstInvalidReason
	end

	-- DEBUG (invalid-replay pipeline testing): splice an action the server
	-- re-simulation must reject into the replay's current turn. The local
	-- sim is untouched - the divergence only exists in the serialized
	-- replay, exactly like a real client/server desync.
	function this:DebugCorruptReplay()
		mReplay = mReplay .. "U1,1Mn"
	end
	
	function this:IsGameStarted()
		return mGameStarted
	end
	
	function this:UploadUnit(x, y, unitData)
		-- Unknown program id in a replay reaches here as a nil definition
		if not unitData then
			invalidAction("Upload of unknown unit at "..tostring(x)..", "..tostring(y))
			return
		end
		-- Check that it's a valid upload zone
		local isValid = false
		for _, c in pairs(mUploadZoneList) do
			if x == c.x and y == c.y then
				isValid = true
				break
			end
		end
		if not isValid then
			invalidAction("Upload "..unitData.Id.." at "..x..", "..y)
			return
		end
		
		-- Check that we have a unit to upload
		local haveUnitToUploadFlag = false
		for _, info in pairs(mUnitInventory) do
			if info.Id == unitData.Id then
				if info.Count > 0 then
					haveUnitToUploadFlag = true
				end
				break
			end
		end
		if not haveUnitToUploadFlag then
			invalidAction("Upload "..unitData.Id.." when none available")
			return
		end
		
		-- Check if there's a unit already there, get rid of it
		local sq = mBoard[x][y]
		if sq.Unit then
			this.UnitRemoved:fire(sq.Unit)
			
			-- Add it back to our inventory
			local def = sq.Unit.Definition
			for _, info in pairs(mUnitInventory) do
				if info.Id == def.Id then
					info.Count = info.Count + 1
					break
				end
			end
			mUnitSet[sq.Unit] = nil
			for i, r in pairs(mUnitList) do
				if r == sq.Unit then
					table.remove(mUnitList, i)
					break
				end
			end
		end
		
		-- Add new unit
		local unit = createUnit(unitData, --[[isEnemy=]]false, {{x = x, y = y}})
		this.UnitAdded:fire(unit)
	end	
	
	function this:GetUnit(x, y)
		return mBoard[x][y].Unit
	end

	-- Remove a not-yet-started player unit from an upload zone, returning it
	-- to the inventory (dragging a unit back out during setup). Returns the
	-- removed unit's definition id, or nil if there was nothing to remove.
	-- Safe for the replay: uploads are only serialized at StartGame.
	function this:RemoveUploadedUnit(x, y)
		if mGameStarted then
			return nil
		end
		-- Only actual uploads can be taken back: pre-placed friendly units
		-- don't sit on upload zones and were never in the inventory
		local onUploadZone = false
		for _, c in pairs(mUploadZoneList) do
			if x == c.x and y == c.y then
				onUploadZone = true
				break
			end
		end
		if not onUploadZone then
			return nil
		end
		local sq = mBoard[x][y]
		local unit = sq.Unit
		if not unit or unit.Enemy then
			return nil
		end
		this.UnitRemoved:fire(unit)
		local def = unit.Definition
		for _, info in pairs(mUnitInventory) do
			if info.Id == def.Id then
				info.Count = info.Count + 1
				break
			end
		end
		mUnitSet[unit] = nil
		for i, r in pairs(mUnitList) do
			if r == unit then
				table.remove(mUnitList, i)
				break
			end
		end
		-- Clear the unit's board squares (a single square before the game starts)
		for _, coord in pairs(unit.Tail) do
			mBoard[coord.x][coord.y].Unit = nil
		end
		return def.Id
	end
	
	function this:StartGame()
		-- Record uploads in the log
		for _, upload in pairs(mUploadZoneList) do
			local unit = getBoard(upload).Unit
			if unit then
				mReplay = mReplay..unit.Definition.Id..","..upload.x..","..upload.y..";"
				mPlayUnitCount = mPlayUnitCount + 1
			end
		end
		mReplay = mReplay.."S;"
		
		-- Pass to view
		mGameStarted = true
		this.GameStarted:fire()
		this.TurnChanged:fire()
	end
	
	function this:Undo()
		if mThisTurnHistory and #mThisTurnHistory > 0 then
			-- No more last moved unit
			mLastMovedUnit = nil			
			
			-- Pop the most recently added entry
			local entry = mThisTurnHistory[#mThisTurnHistory]
			mThisTurnHistory[#mThisTurnHistory] = nil
			
			-- First undo the action if there was one
			if entry.UndoAction then
				entry.UndoAction()
			end
			
			-- Undo any credit pickus
			for _, coord in pairs(entry.CreditsCollected) do
				mExtraCreditsCollected = mExtraCreditsCollected - 1
				getBoard(coord).Pickup = 'credits'
				this.CreditsRestored:fire(coord.x, coord.y)
			end
			
			-- Then undo the move
			restoreUnit(entry.Unit, entry.OriginalTail)
			
			-- Return the unit whose stuff we undid
			return entry.Unit
		end
	end
	
	function this:CanUndo()
		return mThisTurnHistory and #mThisTurnHistory > 0
	end
	
	local function isBeneficialCommand(command)
		local commandType = command.Type
		if commandType == 'grow' then
			return true
		end
		if commandType == 'sizeMod' or commandType == 'speedMod' then
			return command.Amount > 0
		end
		return false
	end
	-- Public: whether a command targets allies (heals / buffs)
	function this:IsBeneficialCommand(command)
		return isBeneficialCommand(command)
	end
	
	function this:GetMovementAndCommandRange(unit, commandId)
		-- Setup
		local movementArea = {}
		local attackFrom = {}
		local startPoint = getBoard(unit.Tail[1])
		local openPoints = {[startPoint] = true}
		mNonce = mNonce + 1
		local nonce = mNonce
		startPoint.Nonce = nonce
						
		-- Flood fill
		local w = Places.PlaceWidth
		local h = Places.PlaceHeight
		local isFriendly = not unit.Enemy
		local attackTargetsEnemies = isFriendly
		if commandId and isBeneficialCommand(unit.Definition.Commands[commandId]) then
			attackTargetsEnemies = not attackTargetsEnemies
		end

		-- Command targets are recorded per ring of movement, closest ring
		-- first, and never overwritten: attacking always uses the MINIMUM
		-- walk needed to get the target in range. Ring 0 is the unmoved start
		-- point (attack without moving at all).
		local command = if commandId then unit.Definition.Commands[commandId] else nil
		local function recordAttackFrom(ringPoints)
			if not command then
				return
			end
			local range = command.Range
			-- One is special because it can be used on empty squares, while
			-- no other attack can
			local isOne = (command.Type == 'one')
			for square, _ in pairs(ringPoints) do
				local xc = square.Coord.x
				local yc = square.Coord.y
				for dx = -range, range do
					local yRangeHere = range - math.abs(dx)
					for dy = -yRangeHere, yRangeHere do
						if dx ~= 0 or dy ~= 0 then
							local x = xc + dx
							if x >= 1 and x <= Places.PlaceWidth then
								local sq = mBoard[x][yc + dy]
								if sq and not attackFrom[sq.Coord] then
									if (isOne or (sq.Unit and sq.Unit ~= unit and sq.Unit.Enemy == attackTargetsEnemies)) then
										attackFrom[sq.Coord] = square.Coord
									end
								end
							end
						end
					end
				end
			end
		end
		recordAttackFrom(openPoints)

		for i = 1, unit.MoveLeft do
			local nextOpenPoints = {}
			for point, _ in pairs(openPoints) do
				local x = point.Coord.x
				local y = point.Coord.y
				-- Unrolled for performance reasons so we can skip an additional iteration
				-- or function call here
				if x > 1 then
					local adj = mBoard[x-1][y]
					if adj.Filled and adj.Nonce ~= nonce then 
						if (adj.Unit == nil or adj.Unit == unit) and (isFriendly or not adj.Pickup) then
							adj.Nonce = nonce
							adj.From = point
							nextOpenPoints[adj] = true
							table.insert(movementArea, adj.Coord)
						elseif adj.Unit and adj.Unit.Enemy == attackTargetsEnemies and commandId and not attackFrom[adj.Coord] then
							attackFrom[adj.Coord] = point.Coord
						end
					end
				end
				if x < w then
					local adj = mBoard[x+1][y]
					if adj.Filled and adj.Nonce ~= nonce then
						if (adj.Unit == nil or adj.Unit == unit) and (isFriendly or not adj.Pickup) then
							adj.Nonce = nonce
							adj.From = point
							nextOpenPoints[adj] = true
							table.insert(movementArea, adj.Coord)
						elseif adj.Unit and adj.Unit.Enemy == attackTargetsEnemies and commandId and not attackFrom[adj.Coord] then
							attackFrom[adj.Coord] = point.Coord
						end
					end
				end
				if y > 1 then
					local adj = mBoard[x][y-1]
					if adj.Filled and adj.Nonce ~= nonce then
						if (adj.Unit == nil or adj.Unit == unit) and (isFriendly or not adj.Pickup) then
							adj.Nonce = nonce
							adj.From = point
							nextOpenPoints[adj] = true
							table.insert(movementArea, adj.Coord)
						elseif adj.Unit and adj.Unit.Enemy == attackTargetsEnemies and commandId and not attackFrom[adj.Coord] then
							attackFrom[adj.Coord] = point.Coord
						end
					end
				end
				if y < h then
					local adj = mBoard[x][y+1]
					if adj.Filled and adj.Nonce ~= nonce then
						if (adj.Unit == nil or adj.Unit == unit) and (isFriendly or not adj.Pickup) then
							adj.Nonce = nonce
							adj.From = point
							nextOpenPoints[adj] = true
							table.insert(movementArea, adj.Coord)
						elseif adj.Unit and adj.Unit.Enemy == attackTargetsEnemies and commandId and not attackFrom[adj.Coord] then
							attackFrom[adj.Coord] = point.Coord
						end
					end
				end
			end
			openPoints = nextOpenPoints
			recordAttackFrom(openPoints)
		end
		
		-- (Command targets were recorded per ring above — closest ring wins —
		-- rather than from the final ring only, which used to make units walk
		-- their full movement before a ranged attack)
		return movementArea, attackFrom
	end
	
	function this:GetCommandRange(unit, commandId)
		local command = unit.Definition.Commands[commandId]
		local range = command.Range
		local xc = unit.Tail[1].x
		local yc = unit.Tail[1].y
		local attackArea = {}
		-- One is special because it can be used on empty squares, while no other attack can
		local isOne = (command.Type == 'one') 
		for dx = -range, range do
			local yRangeHere = range - math.abs(dx)
			for dy = -yRangeHere, yRangeHere do
				if dx ~= 0 or dy ~= 0 then
					local x, y = xc + dx, yc + dy
					if x >= 1 and x <= Places.PlaceWidth and y >= 1 and y <= Places.PlaceHeight then
						local sq = mBoard[x][y]
						if isOne or sq.Filled and sq.Unit ~= unit then
							table.insert(attackArea, sq.Coord)
						end
					end
				end
			end
		end
		return attackArea
	end
	
	function this:UnitMove(unit, x, y)
		-- Actions during the ENEMY turn are dropped, not recorded: on the
		-- client the enemy turn plays out over real time, and an action
		-- slipped between enemy moves executes against a half-finished
		-- board. It would record into the next turn's replay entries, but
		-- the server re-simulates enemy turns atomically, so its enemies
		-- react to different player positions and the sims diverge
		-- (ReplayChecker's "Missing unit at" rejections). Not counted as an
		-- invalid action: it's a legitimate UI race, and this guard can
		-- only ever fire client-side.
		if mIsEnemyTurn then
			print("Ignored: move during the enemy turn")
			return
		end
		-- Valid action check, can only move our units
		if unit.Enemy then
			invalidAction("Move enemy unit "..unit.Definition.Id.." to "..x..", "..y)
			return
		end
		
		-- Valid action check, check that square is in bounds
		--local x = unit.Tail[1].x + dx
		--local y = unit.Tail[1].y + dy
		if x < 1 or x > Places.PlaceWidth or y < 1 or y > Places.PlaceHeight then
			invalidAction("Move unit out of bounds")
			return
		end
		
		-- Valid action check, check that square can be moved to
		-- We can move onto an empty square or one that is already part of our tail
		this:GetMovementAndCommandRange(unit)
		local targetSq = mBoard[x][y]
		if not targetSq.Filled or targetSq.Nonce ~= mNonce then
			invalidAction("Attempt to move `"..unit.Definition.Id.."` to non-movable square ("..x..","..y..")")
			return
		end
		
		-- Figure out what sequence of moves to do
		local currentSq = mBoard[unit.Tail[1].x][unit.Tail[1].y]
		local squares = {}
		while targetSq ~= currentSq do
			table.insert(squares, targetSq)
			targetSq = targetSq.From
		end
		
		for i = #squares, 1, -1 do	
			moveUnitImpl(unit, squares[i])
			if i ~= 1 then
				delayFunc('MoveAlly')
			end
		end
		
		-- Did we win? We need to do this check here because
		-- collecting the codes when there's no enemies left
		-- is one of the win conditions
		if this:HasWon() then
			finishPlayerTurn()
			endGame(true)
		end
	end
	
	function this:UnitExecute(unit, commandId, x, y)
		-- See UnitMove: mid-enemy-turn actions desync the replay
		if mIsEnemyTurn then
			print("Ignored: command during the enemy turn")
			return
		end
		local command = unit.Definition.Commands[commandId]

		-- Valid action check, the command must belong to this unit (replays
		-- can name arbitrary command ids)
		if not command then
			invalidAction("Unknown command "..tostring(commandId).." for "..unit.Definition.Id)
			return
		end

		-- Valid action check, can only move our units
		if unit.Enemy then
			invalidAction("Activate command of enemy unit "..unit.Definition.Id.." targeting "..x..", "..y)
			return
		end
		
		-- Valid action check, attack in range
		local range = math.abs(x - unit.Tail[1].x) + math.abs(y - unit.Tail[1].y)		
		if range > command.Range then
			invalidAction("Attack out of range ("..range.." > "..command.Range..")")
			return
		end

		-- Valid action check, unit is ready and big enough
		if unit.Done or #unit.Tail < command.SizeReq then
			invalidAction("Attack with Done = "..tostring(unit.Done)..", size="..#unit.Tail.." vs req "..command.SizeReq)
			return
		end

		-- Valid action check, the unit must survive the command's sector cost.
		-- EXCEPT deliberate suicide commands (Kamikazee / Self-Destruct),
		-- marked by a cost the unit could never satisfy (>= its max size).
		if #unit.Tail <= command.Cost and command.Cost < unit.Definition.MaxSize then
			invalidAction("Attack costs "..command.Cost.." squares but the unit only has "..#unit.Tail)
			return
		end
		
		-- Valid action check, in bounds
		if x < 1 or x > Places.PlaceWidth or y < 1 or y > Places.PlaceHeight then
			invalidAction("Attack square out of bounds")
			return
		end
		
		unitExecuteImpl(unit, command, x, y)
		
		-- Check if we've won
		if this:HasWon() then
			finishPlayerTurn()
			endGame(true)
		end
	end
	
	function this:GetPickup(x, y)
		return mBoard[x][y].Pickup
	end
	
	function this:GetCreditsEarned()
		return (1 + 0.5*mExtraCreditsCollected)*placeData.CreditReward
	end
	
	function this:IsEnemyTurn()
		return mIsEnemyTurn
	end
	
	function this:HasLost()
		if mConceded then
			return true
		end
		for _, unit in pairs(mUnitList) do
			if not unit.Enemy then
				return false
			end
		end
		return true
	end

	-- Forfeit the battle. Safe to call at any time, INCLUDING mid-enemy-turn:
	-- the AI loop stops at its next unit (HasLost reads the flag) and the loss
	-- flows through the normal EndTurn -> endGame -> GameEnded path. On the
	-- player's turn the loss is processed immediately.
	function this:Concede()
		if mConceded or not mGameStarted then
			return
		end
		mConceded = true
		if not mIsEnemyTurn then
			endGame(false)
		end
	end

	function this:HasWon()
		if mHasCodes then
			return mCodesLeft == 0			
		else
			for _, unit in pairs(mUnitList) do
				if unit.Enemy then
					return false
				end
			end	
			return true
		end
	end
	
	-- Passes things off to the enemy AI turn and lets it proceed
	function this:EndTurn()
		-- A second End Turn while the enemy turn is still animating would
		-- nest a whole extra AI turn and serialize a spurious empty turn
		-- into the replay
		if mIsEnemyTurn then
			print("Ignored: end turn during the enemy turn")
			return
		end
		-- Finish the player turn
		finishPlayerTurn()
		
		-- Are there any enemy units left? If no skip to the next player turn
		-- Note: The game may not be over yet if the player still has to collect
		-- the codes, even if all the enemies are dead
		local hasEnemyUnits = false
		for _, unit in pairs(mUnitList) do
			if unit.Enemy then
				hasEnemyUnits = true
				break
			end
		end
		
		if hasEnemyUnits then
			-- The player can't interact right now
			mIsEnemyTurn = true
			this.TurnChanged:fire()
			
			-- Start and perform the enemy AI turn
			startAITurn()
		end

		-- Did they beat us?		
		if this:HasLost() then
			endGame(false)
			return
		end
		
		-- Start the player turn
		startPlayerTurn()
		
		-- The player can interact
		mIsEnemyTurn = false
		this.TurnChanged:fire()
	end	
	
	function this:GetReplay()
		return mReplay
	end

	-- Client-side play statistics for the finished (or in-progress) battle
	function this:GetPlayStats()
		return {
			Turns = mPlayTurnCount,
			Moves = mPlayMoveCount,
			Units = mPlayUnitCount,
		}
	end
	
	-----------------------------------------------------
	------------------ Initialization -------------------
	-----------------------------------------------------
	-- Copy the board data into our state
	for x, col in pairs(placeData.MapData) do
		local copy = {}
		mBoard[x] = copy
		for y, v in pairs(col) do
			copy[y] = {
				Coord = {x = x, y = y};
				Filled = v;
				Unit = nil;
				Nonce = 0;
			}
		end
	end
	
	-- Copy the upload zones into our state
	for _, p in pairs(placeData.UploadZones) do
		table.insert(mUploadZoneList, p)
	end
	
	-- Copy the pickups into our state
	for _, extraCredits in pairs(placeData.ExtraCreditList) do
		local sq = getBoard(extraCredits)
		sq.Pickup = 'credits'
	end
	
	-- Cody the codes into our state
	for _, codesLocation in pairs(placeData.CodeList) do
		local sq = getBoard(codesLocation)
		sq.Pickup = 'codes'
		mHasCodes = true
		mCodesLeft = mCodesLeft + 1
	end
	
	-- Copy the units into our state
	for _, unitEntry in pairs(placeData.ProgramList) do
		createUnit(Scripts[unitEntry.Id], unitEntry.Type == 'enemy', unitEntry.Tail)
	end
	
	-- Copy in unit inventory
	for i, unit in pairs(unitInventory) do
		mUnitInventory[i] = {
			Id = unit.Id;
			Count = unit.Count;
		}
	end
	
	return this
end

return GameState