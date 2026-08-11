--!strict
-- Thin gate between the views and the GameState: prevents re-entrant actions
-- (double-clicks during action animations) and lets the tutorial disable
-- start/end-turn/undo.

local GameController = {}

function GameController.new(gameState: any)
	local this = {}

	local mIsLocked = false

	local mStartEndEnabled = true

	function this:SetStartEndEnabled(state: boolean)
		mStartEndEnabled = state
	end

	local function tryLock(): boolean
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

	function this:UnitMove(unit: any, x: number, y: number)
		if mIsLocked then return end
		gameState:UnitMove(unit, x, y)
	end

	function this:UnitExecute(unit: any, commandId: string, x: number, y: number)
		if not tryLock() then return end
		-- Always release the lock, or one throw soft-locks the whole battle
		local ok, err = pcall(function()
			gameState:UnitExecute(unit, commandId, x, y)
		end)
		unlock()
		if not ok then
			error(err, 0)
		end
	end

	function this:EndTurn()
		if mStartEndEnabled then
			if not tryLock() then return end
			local ok, err = pcall(function()
				gameState:EndTurn()
			end)
			unlock()
			if not ok then
				error(err, 0)
			end
		end
	end

	function this:Undo()
		if mStartEndEnabled then
			if mIsLocked then return end
			return gameState:Undo()
		end
		return nil
	end

	return this
end

return GameController
