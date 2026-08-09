local Places = require(game.ReplicatedStorage.Places)
local Scripts = require(game.ReplicatedStorage.Scripts)
local UnitInfoView = require(game.ReplicatedStorage.UnitInfoView)
local UnitInfoViewMobile = require(game.ReplicatedStorage.UnitInfoViewMobile)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local ReplaySubmission = require(game.ReplicatedStorage.ReplaySubmission)

local Signal = require(game.ReplicatedStorage.Signal)
local TileView = require(script.TileView)
local FlashySquareView = require(script.FlashySquareView)
local UnitsView = require(script.UnitsView)
local BattleSoundLooper = require(script.BattleSoundLooper)
local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)
local WindowsSlider = require(game.ReplicatedStorage.WindowsSlider)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local BuyLevelSkipView = require(game.ReplicatedStorage.BuyLevelSkipView)

local ShowDirectlyAdjacentSquaresDifferent = true

local GameView = {}

function GameView.new(gameState, controller)
	local this = {}

	this.CloseGame = Signal.new()
	this.SquareSelected = Signal.new()

	local mDestroyed = false

	-- Coordinates that are the only square allowed to be clicked...
	-- For the stupid tutorial of course
	local mOnlyAllowClick = nil
	local mOnlyAllowCommand = nil
	local mAutoSelectionEnabled = true
	this.CommandSelected = Signal.new()

	-- The main Roblox Gui
	local mTileSize = 32
	local mGui = script.Container:Clone()
	local mMenuGui = mGui.MenuMouseCatcher.Menu
	local mClickDetector = mGui.Board.ClickDetector
	mGui.Board.Size = UDim2.new(0, Places.PlaceWidth*mTileSize, 0, Places.PlaceHeight*mTileSize)
	function this:getGui()
		return mGui
	end
	mGui.PlaceBackground.Image = gameState:GetPlaceBackground()

	-- Big scale
	local mBoardScale = 1
	if DeviceInfo.ScreenHeight < 400 then
		mBoardScale = 0.9
	elseif DeviceInfo.ScreenHeight > 700 then
		mBoardScale = 1.8
	elseif DeviceInfo.ScreenHeight > 800 then
		mBoardScale = 2
	end
	do
		local scaler = Instance.new("UIScale")
		scaler.Scale = mBoardScale
		scaler.Parent = mGui.Board
	end

	local mUseDesktopUI = DeviceInfo.ScreenHeight > 700

	-- Which GUI commands to show
	local mGuiCommands;
	if mUseDesktopUI then
		mGuiCommands = mGui.LargeCommands
		WindowsButton.new(mGuiCommands.MenuButton)
		mGui.SmallCommands:Destroy()
	else
		mGuiCommands = mGui.SmallCommands
		WindowsButton.new(mGuiCommands.DoneTurnButton)
		WindowsButton.new(mGuiCommands.UndoCommand)
		WindowsButton.new(mGuiCommands.MenuButton)
		mGui.LargeCommands:Destroy()
	end

	-- Other buttons
	WindowsButton.new(mGui.EndGameOverlay.Box.OkayButton)
	WindowsButton.new(mGui.EndGameOverlay.Box.SkipButton)

	-- Battle sound
	local mBattleSoundLooper = BattleSoundLooper.new()
	mBattleSoundLooper:Play()

	-- Program info view
	local mUnitInfoView;
	if mUseDesktopUI then
		mUnitInfoView = UnitInfoView.new(mGui.Info, gameState:GetAvailableUnits())
	else
		mUnitInfoView = UnitInfoViewMobile.new(mGui.Info, gameState:GetAvailableUnits())
	end

	-- Upload zones for this place
	local mUploadZones = gameState:GetUploadZones()

	-- The main tile grids
	local mMapView = TileView.new(mTileSize, mGui.Board.Tiles)
	local mUploadView = TileView.new(mTileSize, mGui.Board.UploadZones)
	local mHighlightedTiles = TileView.new(mTileSize, mGui.Board.HighlightedTiles)
	local mPickups = TileView.new(mTileSize, mGui.Board.Effects)

	-- The stupid tutorial
	local mTutorialArrow = TutorialArrowView.new()

	-- The units
	local mUnitsView = UnitsView.new(mTileSize, mGui.Board.Units)

	-- Flashy square for selection, and effects view for attacks / unit deaths
	local mFlashySquare = FlashySquareView.new(mTileSize, mGui.Board.Effects)

	-- The currently selected square / unit
	local mSelection = nil
	local mSelectionType = 'none'
	local mSelectedCommand = nil
	local mActionableSquares = nil

	-- The last command used by each type of unit
	local mLastUsedCommandId = {}

	-- Clear the selection
	local function clearSelection()
		mSelection = nil
		mSelectionType = 'none'
		mSelectedCommand = nil
		mFlashySquare:Hide()
		mUnitsView:ClearFlashUnit()
		mHighlightedTiles:ClearAll()
		mActionableSquares = nil
		mGuiCommands.UndoCommand.Visible = gameState:CanUndo()
		mUnitInfoView:ClearSelectedUnit()
	end

	-- Select a command with a unit selected
	local mTileForCommandType = {
		damage = script.AttackDamage;
		zero = script.AttackZeroOne;
		one = script.AttackZeroOne;
		sizeMod = script.AttackModify;
		speedMod = script.AttackModify;
		grow = script.AttackModify;
	}
	local function setSelectedCommand(commandId)
		mSelectedCommand = commandId
		if not mSelection.Enemy then
			mActionableSquares = {}
			for x = 1, Places.PlaceWidth do
				mActionableSquares[x] = {}
			end
		end
		mHighlightedTiles:ClearAll()
		local attackTargets = gameState:GetCommandRange(mSelection, commandId)
		local command = mSelection.Definition.Commands[commandId]
		for _, tile in pairs(attackTargets) do
			if not mSelection.Enemy then
				mActionableSquares[tile.x][tile.y] = true
			end
			local tileGui = mTileForCommandType[command.Type]:Clone()
			if command.Type == 'damage' and (not gameState:GetUnit(tile.x, tile.y) or mSelection.Enemy) then
				tileGui.ImageTransparency = 0.5
			end
			mHighlightedTiles:Set(tile.x, tile.y, tileGui)
		end
		mUnitInfoView:SetSelectedCommand(commandId)
	end

	-- The the command that this unit can use
	local function getUsableCommand(unit)
		-- If we can use the last selected command, use that
		local lastCommandForThisUnitType = mLastUsedCommandId[unit.Definition.Id]
		if lastCommandForThisUnitType and #unit.Tail >= unit.Definition.Commands[lastCommandForThisUnitType].SizeReq then
			return lastCommandForThisUnitType
		end

		-- The "better" commands are last, so start with them
		for i = #unit.Definition.CommandList, 1, -1 do
			local command = unit.Definition.CommandList[i]
			if #unit.Tail >= command.SizeReq then
				return command.Id
			end
		end
	end

	-- Change the selection to a unit
	local function setSelectionUnit(unit)
		if mSelection ~= unit then
			SoundManager:Play('SelectUnit')
		end
		mSelection = unit
		mSelectedCommand = nil
		mSelectionType = 'unit'
		if unit.MoveLeft > 0 and not unit.Enemy and #unit.Tail == unit.MaxSize and unit.MaxSize > 1 then
			mUnitsView:SetFlashUnit(unit)
		else
			mUnitsView:ClearFlashUnit()
		end
		mFlashySquare:Show(unit.Tail[1].x, unit.Tail[1].y)
		mHighlightedTiles:ClearAll()
		mUnitInfoView:SetSelectedUnit(unit)

		mGuiCommands.UndoCommand.Visible = gameState:CanUndo()

		if not unit.Done and gameState:IsGameStarted() then
			if unit.MoveLeft > 0 then
				local headX, headY = unit.Tail[1].x, unit.Tail[1].y
				local tentativeCommandId = getUsableCommand(unit)
				local points, attackFrom = gameState:GetMovementAndCommandRange(unit, tentativeCommandId)
				if not unit.Enemy then
					mActionableSquares = {}
					for x = 1, Places.PlaceWidth do
						mActionableSquares[x] = {}
					end
				end
				for _, point in pairs(points) do
					local dx = math.abs(point.x - headX)
					local dy = math.abs(point.y - headY)
					local tileGui;
					if ShowDirectlyAdjacentSquaresDifferent and dx + dy == 1 then
						tileGui = script.MoveOverlayDirect:Clone()
					else
						tileGui = script.MoveOverlaySimple:Clone()
					end
					if unit.Enemy then
						tileGui.ImageTransparency = 0.4
					end
					mHighlightedTiles:Set(point.x, point.y, tileGui)
					if not unit.Enemy then
						mActionableSquares[point.x][point.y] = 'move'
					end
				end
				local command = unit.Definition.Commands[tentativeCommandId]
				for targetPoint, from in pairs(attackFrom) do
					if not unit.Enemy then
						mActionableSquares[targetPoint.x][targetPoint.y] = from
					end
					local tileGui = mTileForCommandType[command.Type]:Clone()
					if unit.Enemy then
						tileGui.ImageTransparency = 0.5
					end
					mHighlightedTiles:Set(targetPoint.x, targetPoint.y, tileGui)
				end
				if not unit.Enemy then
					mUnitInfoView:SetSelectedCommand('move')
				end
			else
				if mAutoSelectionEnabled then
					-- If done moving, select an attack
					setSelectedCommand(getUsableCommand(unit))
				end
			end
		end
	end

	-- Change the selection to an upload zone
	local function setSelectionUpload(coord)
		mSelection = coord
		mSelectedCommand = nil
		mSelectionType = 'upload'
		mUnitsView:ClearFlashUnit()
		mFlashySquare:Show(coord.x, coord.y)
	end

	local function doAutoSelectNextUnit()
		-- If we won the game, bail out
		if gameState:HasWon() or gameState:HasLost() then
			return
		end

		if mAutoSelectionEnabled then
			-- Try to select a next unit
			for unit in pairs(gameState:GetUnits()) do
				if not unit.Done and not unit.Enemy and unit ~= mSelection then
					setSelectionUnit(unit)
					return
				end
			end

			-- Did not find a next unit. End the turn automatically
			controller:EndTurn()
		end
	end

	local function hasNoAttackTargets(unit)
		local autoCommandId = getUsableCommand(unit)
		if not autoCommandId then
			return true
		end
		local attackTargets = gameState:GetCommandRange(unit, autoCommandId)
		local command = unit.Definition.Commands[autoCommandId]
		for _, tile in pairs(attackTargets) do
			if gameState:GetUnit(tile.x, tile.y) then
				return false
			end
		end
		return true
	end

	-- Do an action
	local function doAction(x, y)
		-- Move, or if an action is selected, attack
		if mSelectedCommand then
			-- Action
			if mActionableSquares[x][y] then
				mLastUsedCommandId[mSelection.Definition.Id] = mSelectedCommand
				controller:UnitExecute(mSelection, mSelectedCommand, x, y)
				mActionableSquares = nil
				doAutoSelectNextUnit()
			end
		else
			-- Move
			local action = mActionableSquares[x][y]
			if action == 'move' then
				controller:UnitMove(mSelection, x, y)
				-- We may win as a result of moving and collecting the access codes
				if gameState:HasWon() then
					return
				end
				if mSelection.MoveLeft == 0 and hasNoAttackTargets(mSelection) then
					doAutoSelectNextUnit()
				end
			else
				-- Attack, but need to move first
				controller:UnitMove(mSelection, action.x, action.y)
				gameState:DelayFunc('AttackIntent')
				controller:UnitExecute(mSelection, getUsableCommand(mSelection), x, y)
				mActionableSquares = nil
				doAutoSelectNextUnit()
			end
		end
	end

	function this:ShowTutorialArrowSquare(x, y)
		mUnitInfoView:TutorialHide()
		mTutorialArrow:Show(mGui.Board.Effects, 0, UDim2.new(0, (x-0.5)*mTileSize, 0, (y-0.5)*mTileSize))
	end
	function this:ShowTutorialArrowStartGame()
		mUnitInfoView:TutorialHide()
		mTutorialArrow:Show(mGuiCommands.StartGameButton, 90, UDim2.new(0, 0, 0.5, 0))
	end
	function this:ShowTutorialArrowProgramList(unitId)
		mUnitInfoView:TutorialHighlightUnit(unitId)
	end
	function this:ShowTutorialArrowCommand(commandId)
		mUnitInfoView:TutorialHighlightCommand(commandId)
	end
	function this:ClearTutorialArrow()
		mUnitInfoView:TutorialHide()
		mTutorialArrow:Hide()
	end

	function this:SetOnlyAllowClick(x, y)
		mOnlyAllowClick = {x = x, y = y}
	end
	function this:SetOnlyAllowCommand(commandId)
		if commandId == 'move' then
			commandId = nil
		end
		mOnlyAllowCommand = {Id = commandId}
	end
	function this:DisableAutoSelection()
		mAutoSelectionEnabled = false

		-- Tutorial disables
		mMenuGui.Inset.SkipButton.ImageColor3 = Color3.new(0.5, 0.5, 0.5)
		mMenuGui.Inset.SkipButton.Text.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		mMenuGui.Inset.ConcedeButton.ImageColor3 = Color3.new(0.5, 0.5, 0.5)
		mMenuGui.Inset.ConcedeButton.Text.TextColor3 = Color3.new(0.6, 0.6, 0.6)
	end

	-- Clear the selection, for tutorial
	function this:ClearSelection()
		clearSelection()
	end

	-- Upload zone handling through unit info view
	mUnitInfoView.UnitSelected:connect(function(id)
		if mSelectionType == 'upload' and mUnitInfoView:GetCount(id) > 0 then
			-- We should upload a unit there
			local currentUnit = gameState:GetUnit(mSelection.x, mSelection.y)

			-- Is there a unit of that type already there?
			if currentUnit and currentUnit.Definition.Id == id then
				return -- don't need to do anything
			end

			-- Do we have any of the chosen unit available?
			local foundValidFlag = false
			for _, info in pairs(gameState:GetAvailableUnits()) do
				if info.Id == id then
					if info.Count > 0 then
						foundValidFlag = true
					end
					break
				end
			end

			-- First return the unit that was uploaded there before if there is one
			if currentUnit then
				mUnitInfoView:UpdateCount(currentUnit.Definition.Id, 1)
			end

			-- Now upload the new unit
			mUnitInfoView:UpdateCount(id, -1)
			gameState:UploadUnit(mSelection.x, mSelection.y, Scripts[id])

			-- Show the start game button now that we have at least one unit uploaded
			mGuiCommands.StartGameButton.Visible = true
		else
			-- Deselect the current selection if there is one
			clearSelection()
		end
	end)
	mUnitInfoView.CommandSelected:connect(function(commandId)
		if mSelectionType == 'upload' then
			mUnitInfoView:SetSelectedCommand(commandId)
		elseif mSelection then
			print("Try to select command:", commandId)
			if mOnlyAllowCommand then
				print("Only: ", mOnlyAllowCommand.Id, "is allowed")
				if commandId ~= mOnlyAllowCommand.Id then
					return
				end
			end
			if commandId == nil then
				this.CommandSelected:fire('move')
			else
				this.CommandSelected:fire(commandId)
			end
			if commandId == nil then
				-- Reselect movement
				setSelectionUnit(mSelection)
			else
				setSelectedCommand(commandId)
			end
		end
	end)

	local mDidWin = nil
	local function handleGameEnded(wonGame, creditsEarned, skipLevel)
		if mDestroyed then
			return
		end
		if not wonGame and not gameState:IsGameStarted() then
			-- They didn't even start the game, just bail out
			SoundManager:Play('LoseBattle')
			this.CloseGame:fire(false, nil, false)
			return
		end
		clearSelection()
		for _, button in pairs(mGuiCommands:GetChildren()) do
			button.Visible = false
		end
		mUnitInfoView:Hide()
		mDidWin = wonGame
		if mAutoSelectionEnabled then
			mGui.EndGameOverlay.Visible = true
			if skipLevel then
				ReplaySubmission:Skip(gameState:GetMapId())
			else
				ReplaySubmission:Submit(gameState:GetReplay())
			end
		end
		if wonGame then
			-- Play victory sound?
			mGui.EndGameOverlay.Box.SkipButton.Visible = false
			mGui.EndGameOverlay.Box.Size = UDim2.new(0, 300, 0, 130)
			mGui.EndGameOverlay.Box.Body.Text = "You won the battle!"
			SoundManager:Play('WinBattle')
		else
			mGui.EndGameOverlay.Box.SkipButton.Visible = true
			mGui.EndGameOverlay.Box.Size = UDim2.new(0, 300, 0, 180)
			mGui.EndGameOverlay.Box.Body.Text = "You were defeated."
			SoundManager:Play('LoseBattle')
		end
	end

	-- Hook up start game button
	mGuiCommands.StartGameButton.MouseButton1Click:connect(function()
		controller:StartGame()
	end)

	-- Concede game
	mMenuGui.Inset.ConcedeButton.MouseButton1Click:connect(function()
		-- TODO: "Are you sure?" dialgue
		if mAutoSelectionEnabled then
			mGui.MenuMouseCatcher.Visible = false
			handleGameEnded(false, 0)
		end
	end)
	mGuiCommands.MenuButton.MouseButton1Click:connect(function()
		mGui.MenuMouseCatcher.Visible = true
	end)

	-- Skip node
	local function trySkip()
		if mAutoSelectionEnabled then
			if LocalPlayerData:GetSkips() > 0 then
				handleGameEnded(--[[wonGame=]] true, --[[creditsEarned=]] 0, --[[skipping=]] true)
				mGui.MenuMouseCatcher.Visible = false
			else
				BuyLevelSkipView.new(mGui)
			end
		end
	end
	mMenuGui.Inset.SkipButton.MouseButton1Click:connect(trySkip)
	mGui.EndGameOverlay.Box.SkipButton.MouseButton1Click:connect(trySkip)
	local function updateSkipsButton()
		local skips = LocalPlayerData:GetSkips()
		local text;
		if skips > 0 then
			text = "Skip Node ("..skips.." skip"..((skips == 1) and "" or "s").." available)"
		else
			text = "Skip Node"
		end
		mMenuGui.Inset.SkipButton.Text.Text = text
		mGui.EndGameOverlay.Box.SkipButton.Text.Text = text
	end
	updateSkipsButton()
	local mUpdateSkipsCn = LocalPlayerData.SkipsChanged:connect(updateSkipsButton)

	-- End turn
	mGuiCommands.DoneTurnButton.MouseButton1Click:connect(function()
		controller:EndTurn()
	end)

	-- Menu
	WindowsButton.new(mMenuGui.DoneButton)
	WindowsButton.new(mMenuGui.Inset.ConcedeButton)
	WindowsButton.new(mMenuGui.Inset.SkipButton)
	local mMusicSlider = WindowsSlider.new(mMenuGui.Inset.MusicVolume)
	SoundManager:AddMusicSlider(mMusicSlider)
	local mSoundSlider = WindowsSlider.new(mMenuGui.Inset.SoundVolume)
	SoundManager:AddSoundSlider(mSoundSlider)
	mMenuGui.DoneButton.MouseButton1Click:connect(function()
		mGui.MenuMouseCatcher.Visible = false
	end)

	-- Undo
	mGuiCommands.UndoCommand.MouseButton1Click:connect(function()
		local unit = controller:Undo()
		if unit then
			setSelectionUnit(unit)
		end
	end)

	-- When the game actually starts
	gameState.GameStarted:connect(function()
		mUploadView:ClearAll()
		mGuiCommands.StartGameButton.Visible = false
		mUnitInfoView:SetProgramListVisible(false)
		mGuiCommands.DoneTurnButton.Visible = true
		if mAutoSelectionEnabled then
			-- TODO: Show / hide in menu
			--mGuiCommands.ConcedeButton.Visible = true
		end
		clearSelection()
	end)

	-- Game over
	gameState.GameEnded:connect(function(wonGame, creditsEarned)
		handleGameEnded(wonGame, creditsEarned)
	end)

	ReplaySubmission.SubmissionRecieved:connect(function()
		if not mDestroyed then
			mGui.EndGameOverlay.Box.SubmittingText.Text = "(Play successfully recorded)"
		end
	end)

	-- User done with game
	mGui.EndGameOverlay.Box.OkayButton.MouseButton1Click:connect(function()
		this.CloseGame:fire(mDidWin, gameState:GetReplay(), gameState:IsGameStarted())
	end)

	-- Show attack intent
	gameState.ShowEnemyIntention:connect(function(squares, attackType)
		mHighlightedTiles:ClearAll()
		for _, sq in pairs(squares) do
			mHighlightedTiles:Set(sq.x, sq.y, mTileForCommandType[attackType]:Clone())
		end
	end)

	gameState.SectorDeleted:connect(function(x, y, color)
		mUnitsView:ShowDamage(x, y, color)
	end)

	-- Set up tile grid and events for tile grid
	for x = 1, Places.PlaceWidth do
		for y = 1, Places.PlaceHeight do
			if gameState:IsFilled(x, y) then
				mMapView:Set(x, y, script.MapTile:Clone())
			end
		end
	end
	gameState.TileAdded:connect(function(x, y)
		mMapView:Set(x, y, script.MapTile:Clone())
	end)
	gameState.TileRemoved:connect(function(x, y)
		mMapView:Clear(x, y)
	end)

	-- Pickups
	for _, coord in pairs(gameState:GetInitialCodes()) do
		mPickups:Set(coord.x, coord.y, script.PickupCodes:Clone())
	end
	for _, coord in pairs(gameState:GetInitialCredits()) do
		mPickups:Set(coord.x, coord.y, script.PickupCredits:Clone())
	end
	gameState.CreditsRestored:connect(function(x, y)
		mPickups:Set(x, y, script.PickupCredits:Clone())
	end)
	gameState.CreditsCollected:connect(function(x, y, amount)
		SoundManager:Play('GrabCredit')
		mPickups:Clear(x, y)
		mFlashySquare:ShowCreditPickup(x, y, amount)
	end)
	gameState.CodesCollected:connect(function(x, y)
		mPickups:Clear(x, y)
	end)

	-- Targeted, play sound
	gameState.ActionTargeted:connect(function(x, y, actionType)
		mUnitsView:ShowDamageSparks(x, y)
		if actionType == 'damage' then
			SoundManager:Play('Damage')
		end
	end)

	gameState.EnemySelectUnit:connect(function(unit)
		SoundManager:Play('SelectUnit')
		mUnitInfoView:SetSelectedUnit(unit)
	end)
	gameState.UnitMoved:connect(function(unit)
		SoundManager:Play('MoveUnit')
	end)

	-- Turn changed, modify selection
	gameState.TurnChanged:connect(function()
		if gameState:IsEnemyTurn() then
			-- Start of enemy turn, clear our selection
			clearSelection()

			-- Hide end turn button
			mGuiCommands.DoneTurnButton.Visible = false
		else
			-- Start of our turn,
			if mAutoSelectionEnabled then
				local firstUnit = nil
				for unit in pairs(gameState:GetUnits()) do
					if not unit.Enemy then
						firstUnit = unit
						break
					end
				end
				setSelectionUnit(firstUnit) -- must not be nil since if we had no units the game would be over
			end

			-- Show end turn button
			mGuiCommands.DoneTurnButton.Visible = true
		end
	end)

	-- Set up upload zones
	for _, coord in pairs(mUploadZones) do
		mUploadView:Set(coord.x, coord.y, script.UploadOverlay:Clone())
	end

	-- Set up units
	gameState.UnitAdded:connect(function(unit) mUnitsView:AddUnit(unit) end)
	gameState.UnitRemoved:connect(function(unit)
		if unit == mSelection then
			clearSelection()
		end
		mUnitsView:RemoveUnit(unit)
	end)
	gameState.UnitUpdated:connect(function(unit)
		-- Refresh the selection
		if unit == mSelection then
			setSelectionUnit(unit)
		end
		mUnitsView:UpdateUnit(unit)
	end)
	for unit in pairs(gameState:GetUnits()) do
		mUnitsView:AddUnit(unit)
	end

	-- Clicks
	mClickDetector.MouseButton1Up:connect(function(x, y)
		-- To local coords
		local GuiInset = game:GetService('GuiService'):GetGuiInset()
		x = x - mClickDetector.AbsolutePosition.x - GuiInset.x
		y = y - mClickDetector.AbsolutePosition.y - GuiInset.y

		-- Translate to grid square
		x = math.ceil(x / (mTileSize * mBoardScale))
		y = math.ceil(y / (mTileSize * mBoardScale))

		-- Tutorial nonsense... sigh
		if mOnlyAllowClick then
			if x ~= mOnlyAllowClick.x or y ~= mOnlyAllowClick.y then
				return
			end
		end

		-- Handle it

		-- If it's the enemy turn, don't do anything. No selecting stuff on their turn
		if gameState:IsEnemyTurn() then
			return
		end

		-- First, if we haven't started yet, try to select an upload zone
		if not gameState:IsGameStarted() then
			for _, zone in pairs(mUploadZones) do
				if zone.x == x and zone.y == y then
					setSelectionUpload(zone)
					-- Show upload zone selected, but only if it's still empty
					if gameState:GetUnit(x, y) then
						mUnitInfoView:SetSelectedUnitDefinition(gameState:GetUnit(x, y).Definition.Id)
					else
						mUnitInfoView:SetSelectedUpload()
					end
					-- For the tutorial
					this.SquareSelected:fire(x, y)
					return
				end
			end
		end

		-- If we have a selected unit, see if the square is actionable
		if mSelectionType == 'unit' and mActionableSquares and mActionableSquares[x] and mActionableSquares[x][y] then
			-- Square is actionable
			doAction(x, y)
		else
			-- If we couldn't select an upload zone, or take an action, try selecting a unit
			-- If there was no unit or upload zone we DO want to clear the selection
			local unit = gameState:GetUnit(x, y)
			if unit then
				setSelectionUnit(unit)
			else
				-- Nothing found, clear the selection
				clearSelection()

				-- If there's a pickup there we still might want to show it in the unit info view
				local pickup = gameState:GetPickup(x, y)
				if pickup then
					mUnitInfoView:SetSelectedPickup(pickup)
				end
			end
		end

		-- For the tutorial
		this.SquareSelected:fire(x, y)
	end)

	-- Stop any animation cycles, disconnect any events
	function this:Destroy()
		SoundManager:RemoveSlider(mSoundSlider)
		SoundManager:RemoveSlider(mMusicSlider)
		mDestroyed = true
		mFlashySquare:Destroy()
		mUnitsView:Destroy()
		mBattleSoundLooper:Destroy()
		mTutorialArrow:Destroy()
		mUnitInfoView:Destroy()
		mGui:Destroy()
		mUpdateSkipsCn:disconnect()
	end

	return this
end

return GameView
