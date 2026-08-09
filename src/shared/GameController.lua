local GameController = {}

function GameController.new(gameState)
	local this = {}
	
	local mIsLocked = false
	
	local mStartEndEnabled = true
	
	function this:SetStartEndEnabled(state)
		mStartEndEnabled = state
	end
	
	local function tryLock()
		if mIsLocked then
			return false
		else
			mIsLocked = true
			return true
		end
	end
	
	local function unlock()
		mIsLocked = false
	end
	
	function this:StartGame()
		if mStartEndEnabled then
			gameState:StartGame()
		end
	end
	
	function this:UnitMove(unit, x, y)
		if mIsLocked then return end
		gameState:UnitMove(unit, x, y)
	end
	
	function this:UnitExecute(unit, commandId, x, y)
		if not tryLock() then return end
		gameState:UnitExecute(unit, commandId, x, y)
		unlock()
	end
	
	function this:EndTurn()
		if mStartEndEnabled then
			if not tryLock() then return end
			gameState:EndTurn()
			unlock()
		end
	end
	
	function this:Undo()
		if mStartEndEnabled then
			if mIsLocked then return end
			return gameState:Undo()
		end
	end
	
	return this	
end

return GameController
