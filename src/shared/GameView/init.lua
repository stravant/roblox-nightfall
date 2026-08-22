-- React conversion of GameView (the databattle screen). Public API unchanged.
--
-- Split of responsibilities (see REACT_CONVERSION.md):
-- - The Board and its tile/unit layers stay imperative: TileView / UnitsView /
--   FlashySquareView position and destroy per-tile instances driven by game
--   events, built from TileTemplates factories (formerly template clones).
-- - The chrome with dynamic state (command buttons, in-game menu, end game
--   overlay) renders via a React root on the host Container frame; imperative
--   siblings (Board, Info, PlaceBackground) coexist with it.
-- Layout matches ui-reference/ModuleTemplates/GameView.json.

local Places = require(game.ReplicatedStorage.Places)
local Scripts = require(game.ReplicatedStorage.Scripts)
local Netmap = require(game.ReplicatedStorage.Netmap)
local BattleHud = require(game.ReplicatedStorage.BattleHud)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local JourneyRecorder = require(game.ReplicatedStorage.JourneyRecorder)
local ReplaySubmission = require(game.ReplicatedStorage.ReplaySubmission)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local Signal = require(game.ReplicatedStorage.Signal)
local TileView = require(script.TileView)
local FlashySquareView = require(script.FlashySquareView)
local UnitsView = require(script.UnitsView)
local BattleSoundLooper = require(script.BattleSoundLooper)
local TileTemplates = require(script.TileTemplates)
local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local BuyLevelSkipView = require(game.ReplicatedStorage.BuyLevelSkipView)
local BattleBoard3D = require(game.ReplicatedStorage.BattleBoard3D)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local ShowDirectlyAdjacentSquaresDifferent = true

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"
local kInkColor = Color3.new(0.105882, 0.164706, 0.207843)
local kHeaderColor = Color3.new(0.737255, 0.784314, 0.886275)

local GameView = {}

-- The win overlay's "new personal best" showcase: compares this play's
-- stats against the pre-battle bests (client-known; only set for nodes
-- already beaten through a real win) and, when known, the world records
-- (a stat strictly better than the cached world record upgrades the
-- headline). Returns nil when nothing improved.
-- Exposed on the module for direct testing.
function GameView.BuildImprovementText(priorBests, playStats, worldBests)
	if not priorBests or not playStats then
		return nil
	end
	local lines = {}
	local anyWorldRecord = false
	local kStats = {
		{ Key = "Turns", Label = "Turns Taken" },
		{ Key = "Moves", Label = "Tiles Moved" },
		{ Key = "Units", Label = "Scripts Used" },
	}
	for _, stat in ipairs(kStats) do
		local prior = priorBests[stat.Key]
		local now = playStats[stat.Key]
		local world = worldBests and worldBests[stat.Key]
		local beatWorld = world and now and now < world
		if prior and now and (now < prior or beatWorld) then
			local line = string.format("%s  %d → %d", stat.Label, prior, now)
			if beatWorld then
				line ..= "  (world record!)"
				anyWorldRecord = true
			end
			table.insert(lines, line)
		end
	end
	if #lines == 0 then
		return nil
	end
	local headline = if anyWorldRecord then "NEW WORLD RECORD!" else "NEW PERSONAL BEST!"
	return headline .. "\n" .. table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Chrome render helpers
--------------------------------------------------------------------------------

local function GameViewChrome(props)
	-- All the battle action buttons (Start Databattle / Done Turn / Undo)
	-- live in the topbar gui via the topbar interface; the chrome here is
	-- the setup-phase mission box and the end-of-game overlay.
	return e(React.Fragment, nil, {
		-- Debug: instantly win the battle (setup phase only)
		DebugWinButton = if props.debugWinVisible
			then e("TextButton", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = UDim2.new(0, 130, 0, 32),
				BackgroundColor3 = Color3.fromRGB(180, 90, 0),
				Font = Enum.Font.SourceSansBold,
				TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "DEBUG: Win",
				ZIndex = 5,
				[React.Event.MouseButton1Click] = props.onDebugWin,
			})
			else nil,
		-- Debug: poison the outgoing replay with an action the server must
		-- reject, to exercise the invalid-replay analytics/store end to end
		-- (finish the battle afterwards so the replay gets submitted)
		DebugInvalidButton = if props.debugWinVisible
			then e("TextButton", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 150, 1, -12),
				Size = UDim2.new(0, 130, 0, 32),
				BackgroundColor3 = Color3.fromRGB(140, 0, 20),
				Font = Enum.Font.SourceSansBold,
				TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "DEBUG: Bad Replay",
				ZIndex = 5,
				[React.Event.MouseButton1Click] = props.onDebugInvalid,
			})
			else nil,
		-- The node's mission text, shown until the player starts uploading
		MissionBox = if props.missionText and props.missionVisible
			then e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -12),
				AutomaticSize = Enum.AutomaticSize.Y,
				-- Narrow enough to read roughly square once the text wraps:
				-- there's free height down here but width eats into the board
				Size = UDim2.new(0, 210, 0, 0),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				UIPadding = e("UIPadding", {
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),
				Title = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = 16,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Mission",
				}),
				Body = e("TextLabel", {
					Position = UDim2.new(0, 0, 0, 20),
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					TextColor3 = Color3.new(1, 1, 1),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = props.missionText,
				}),
			})
			else nil,
		EndGameOverlay = e("ImageButton", {
			Active = true,
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = "",
			ZIndex = 4,
			Visible = props.endGameOverlayVisible,
		}, {
			Box = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.6, 0),
				Size = if props.endGameWon == false
					then UDim2.new(0, 300, 0, 224)
					elseif props.improvementText then UDim2.new(0, 300, 0, 202)
					else UDim2.new(0, 300, 0, 130),
				ZIndex = 2,
				BackgroundTransparency = 1,
				BorderSizePixel = 2,
				Image = kWindowImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = kWindowSliceCenter,
				ImageRectSize = kWindowImageRectSize,
			}, {
				WindowTitle = e("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 6, 0, 12),
					Size = UDim2.new(0, 200, 0, 30),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = 14,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Databattle Ended",
				}),
				Body = e("TextLabel", {
					Position = UDim2.new(0, 4, 0, 28),
					Size = UDim2.new(1, -5, 1, -1),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 18,
					TextColor3 = Color3.new(0, 0, 0),
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = if props.endGameWon == true
						then "You won the battle!"
						elseif props.endGameWon == false then "You were defeated."
						else "",
				}, {
					UIStroke = e("UIStroke", {
						Color = Color3.new(1, 1, 1),
						Transparency = 0.9,
						Thickness = 1.5,
					}),
				}),
				-- Re-beat a node with better stats: celebrate them
				ImprovementText = if props.improvementText
					then e("TextLabel", {
						Position = UDim2.new(0, 4, 0, 48),
						Size = UDim2.new(1, -8, 0, 72),
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSansBold,
						TextSize = 16,
						TextColor3 = Color3.fromRGB(0, 130, 30),
						TextYAlignment = Enum.TextYAlignment.Top,
						Text = props.improvementText,
					})
					else nil,
				SubmittingText = e("TextLabel", {
					Position = UDim2.new(0, 0, 0, if props.improvementText then 122 else 50),
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = 11,
					TextColor3 = Color3.new(0, 0.482353, 1),
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = props.submittingText,
				}),
				RetryButton = e(WindowsButton, {
					Name = "RetryButton",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 16, 1, -100),
					Size = UDim2.new(1, -32, 0, 36),
					Visible = props.endGameWon == false,
					Text = "Retry (same setup)",
					OnClick = props.onRetry,
				}),
				SkipButton = e(WindowsButton, {
					Name = "SkipButton",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 16, 1, -56),
					Size = UDim2.new(1, -32, 0, 36),
					ImageColor3 = Color3.new(0, 0, 1),
					Visible = props.endGameWon == false,
					OnClick = props.onSkip,
				}, {
					Text = e("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, -1),
						Size = UDim2.new(1, -20, 0, 24),
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSansBold,
						TextSize = 18,
						TextColor3 = Color3.new(1, 1, 1),
						Text = props.skipText,
					}),
				}),
				-- On a re-beat win the bottom row splits: Continue + View Stats
				OkayButton = e(WindowsButton, {
					Name = "OkayButton",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 16, 1, -12),
					Size = if props.viewStatsVisible
						then UDim2.new(0.5, -20, 0, 36)
						else UDim2.new(1, -32, 0, 36),
					Text = "Continue",
					OnClick = props.onOkay,
				}),
				ViewStatsButton = if props.viewStatsVisible
					then e(WindowsButton, {
						Name = "ViewStatsButton",
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -16, 1, -12),
						Size = UDim2.new(0.5, -20, 0, 36),
						Text = "View Stats",
						OnClick = props.onViewStats,
					})
					else nil,
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- Board layer construction (renders onto the 3D board's surface)
--------------------------------------------------------------------------------

local function buildBoardLayers(container: Frame)
	local function layer(name: string, zIndex: number?)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = 1
		if zIndex then
			frame.ZIndex = zIndex
		end
		frame.Parent = container
	end
	layer("Tiles")
	layer("UploadZones", 2)
	layer("Units", 3)
	layer("HighlightedTiles", 4)
	layer("Effects", 5)
end

--------------------------------------------------------------------------------
-- View object
--------------------------------------------------------------------------------

-- `menu` is the shared MainMenuView; while this battle is up it gains a
-- default-selected "Databattle" tab (forfeit / skip). May be nil in tests.
-- `topbar` drives the Start Databattle button in the topbar gui (may be nil
-- in tests).
-- entrySoundName: optional SoundManager name of the node's entry sting; the
-- battle music holds until it finishes and fades in over its final seconds
function GameView.new(gameState, controller, menu, topbar, entrySoundName)
	local this = {}

	local mTopbar = topbar or {
		SetStartVisible = function() end,
		SetLeaveVisible = function() end,
		SetOnLeave = function() end,
		SetDoneTurnVisible = function() end,
		SetUndoVisible = function() end,
		SetOnUndo = function() end,
		GetStartButton = function()
			return nil
		end,
	}

	this.CloseGame = Signal.new()
	this.SquareSelected = Signal.new()

	local RunService = game:GetService("RunService")
	local mDestroyed = false
	local mDraggingProgram = false
	-- An allied unit's move animation is playing (selection allowed, but the
	-- move/attack UI defers until it finishes)
	local mUnitMoveInProgress = false
	local mPulseCn = nil

	-- Coordinates that are the only square allowed to be clicked...
	-- For the stupid tutorial of course
	local mOnlyAllowClick = nil
	local mOnlyAllowCommand = nil
	local mAutoSelectionEnabled = true
	this.CommandSelected = Signal.new()

	-- The chrome GUI (transparent; the board renders in 3D behind it)
	local mTileSize = 32
	local mGui = Instance.new("Frame")
	mGui.Name = "Container"
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundTransparency = 1
	mGui.ZIndex = 5
	function this:getGui()
		return mGui
	end

	-- The 3D board (world geometry + camera + tap-to-grid mapping)
	local mBattleBoard = BattleBoard3D.new(gameState:GetPlaceBackground())
	mBattleBoard:Install()
	local mBoard = mBattleBoard:GetBoardContainer()
	buildBoardLayers(mBoard)
	function this:getBoardGui()
		return mBoard
	end
	function this:getBoard3D()
		return mBattleBoard
	end


	local mRoot: StatefulRoot.StatefulRoot? = nil
	local function root(): StatefulRoot.StatefulRoot
		return mRoot :: StatefulRoot.StatefulRoot
	end

	local mDidWin = nil
	local mWasSkipped = false
	local mSkipText = "Skip Node"
	-- Pre-battle personal bests for this node ({Turns, Moves, Units}), set
	-- by MainView for already-won nodes so the win overlay can showcase
	-- improvements
	local mPriorBests = nil
	function this:SetPriorBests(bests)
		mPriorBests = bests
	end
	-- Cached world-record values for this node ({Turns, Moves, Units}), set
	-- asynchronously by MainView; strictly beating one upgrades the win
	-- overlay's showcase headline
	local mWorldBests = nil
	function this:SetWorldRecords(bests)
		mWorldBests = bests
	end

	-- Forward declarations used by chrome callbacks
	local clearSelection
	local setSelectionUnit
	local handleGameEnded
	local trySkip

	-- The shared main menu gains the default-selected Databattle tab
	-- (forfeit / skip) while this battle exists
	local function updateMenuContext()
		if menu then
			menu:SetBattleContext({
				skipText = mSkipText,
				disabled = not mAutoSelectionEnabled,
				onForfeit = function()
					-- TODO: "Are you sure?" dialgue
					if mAutoSelectionEnabled then
						menu:Hide()
						if gameState:IsGameStarted() then
							-- Concede through the game state: forfeiting
							-- mid-enemy-turn must stop the AI and end via the
							-- normal GameEnded path, not yank the battle out
							-- from under the running AI
							gameState:Concede()
						else
							handleGameEnded(false, 0)
						end
					end
				end,
				onSkip = function()
					trySkip()
				end,
			})
		end
	end

	-- Portaled: mGui also holds the imperative Board/Info/PlaceBackground
	mRoot = StatefulRoot.createPortaled(mGui, GameViewChrome, {
		missionText = nil,
		missionVisible = true,
		debugWinVisible = DebugFlags:ShowDebugUI(),
		onDebugWin = function()
			handleGameEnded(--[[wonGame=]] true, 0)
		end,
		onDebugInvalid = function()
			gameState:DebugCorruptReplay()
			print("DEBUG: spliced an invalid action into the replay; finish"
				.. " the battle to submit it")
		end,
		endGameOverlayVisible = false,
		endGameWon = nil,
		improvementText = nil,
		viewStatsVisible = false,
		submittingText = "(Submitting play...)",
		skipText = "Skip Node",
		onSkip = function()
			trySkip()
		end,
		onOkay = function()
			this.CloseGame:fire(mDidWin, gameState:GetReplay(), gameState:IsGameStarted(), mWasSkipped)
		end,
		onViewStats = function()
			-- Same teardown as Continue, plus a request to land on this
			-- node's statistics page
			this.CloseGame:fire(mDidWin, gameState:GetReplay(), gameState:IsGameStarted(), mWasSkipped,
				--[[retryRequested=]] false, --[[viewStatsRequested=]] true)
		end,
		onRetry = function()
			-- Same teardown as Continue, plus a request to re-enter the
			-- battle with this run's setup pre-placed
			this.CloseGame:fire(mDidWin, gameState:GetReplay(), gameState:IsGameStarted(), mWasSkipped, true)
		end,
	})

	updateMenuContext()

	-- The node's mission text, shown in the setup-phase mission box
	function this:SetMissionText(text)
		root().setState({ missionText = text or StatefulRoot.None })
	end

	-- Undo lives in the topbar; its handler needs this view's selection state
	mTopbar:SetOnUndo(function()
		JourneyRecorder:Record("Undo")
		local unit = controller:Undo()
		if unit then
			setSelectionUnit(unit)
		end
	end)

	-- During setup the topbar offers Leave (back out without playing)
	mTopbar:SetOnLeave(function()
		handleGameEnded(false, 0)
	end)
	mTopbar:SetLeaveVisible(true)

	-- Battle sound (held back until the node entry sting finishes, if any)
	local mBattleSoundLooper = BattleSoundLooper.new()
	if entrySoundName then
		mBattleSoundLooper:PlayAfter(SoundManager:GetSound(entrySoundName))
	else
		mBattleSoundLooper:Play()
	end

	-- The battle HUD (floating unit info window, programs window, command row)
	local mUnitInfoView = BattleHud.new(mGui, gameState:GetAvailableUnits())

	-- Upload zones for this place
	local mUploadZones = gameState:GetUploadZones()

	-- The main tile grids
	local mMapView = TileView.new(mTileSize, mBoard.Tiles)
	local mUploadView = TileView.new(mTileSize, mBoard.UploadZones)
	local mHighlightedTiles = TileView.new(mTileSize, mBoard.HighlightedTiles)
	local mPickups = TileView.new(mTileSize, mBoard.Effects)

	-- The stupid tutorial
	local mTutorialArrow = TutorialArrowView.new()

	-- The units
	local mUnitsView = UnitsView.new(mTileSize, mBoard.Units)

	-- Flashy square for selection, and effects view for attacks / unit deaths
	local mFlashySquare = FlashySquareView.new(mTileSize, mBoard.Effects)

	-- The currently selected square / unit
	local mSelection = nil
	local mSelectionType = 'none'
	local mSelectedCommand = nil
	local mActionableSquares = nil

	-- The last command used by each type of unit
	local mLastUsedCommandId = {}

	-- Clear the selection
	clearSelection = function()
		mSelection = nil
		mSelectionType = 'none'
		mSelectedCommand = nil
		mFlashySquare:Hide()
		mUnitsView:ClearFlashUnit()
		mHighlightedTiles:ClearAll()
		mActionableSquares = nil
		mTopbar:SetUndoVisible(gameState:CanUndo())
		mUnitInfoView:ClearSelectedUnit()
	end

	-- Select a command with a unit selected
	local mTileForCommandType = {
		damage = TileTemplates.AttackDamage;
		zero = TileTemplates.AttackZeroOne;
		one = TileTemplates.AttackZeroOne;
		sizeMod = TileTemplates.AttackModify;
		speedMod = TileTemplates.AttackModify;
		grow = TileTemplates.AttackModify;
	}
	local function setSelectedCommand(commandId)
		-- A unit may have NO usable command (e.g. all commands cost more
		-- sectors than it has left): nothing to select or highlight
		if not commandId or not mSelection then
			return
		end
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
			local tileGui = mTileForCommandType[command.Type]()
			if command.Type == 'damage' and (not gameState:GetUnit(tile.x, tile.y) or mSelection.Enemy) then
				tileGui.ImageTransparency = 0.5
			end
			mHighlightedTiles:Set(tile.x, tile.y, tileGui)
		end
		mUnitInfoView:SetSelectedCommand(commandId)
	end

	-- The the command that this unit can use
	-- Usable: meets the size requirement AND survives the sector cost —
	-- except deliberate suicide commands (cost >= max size, e.g.
	-- Self-Destruct), which are always their own reward
	local function canUseCommand(unit, command)
		return #unit.Tail >= command.SizeReq
			and (#unit.Tail > command.Cost or command.Cost >= unit.Definition.MaxSize)
	end
	local function getUsableCommand(unit)
		-- If we can use the last selected command, use that
		local lastCommandForThisUnitType = mLastUsedCommandId[unit.Definition.Id]
		if lastCommandForThisUnitType and canUseCommand(unit, unit.Definition.Commands[lastCommandForThisUnitType]) then
			return lastCommandForThisUnitType
		end

		-- The "better" commands are last, so start with them
		for i = #unit.Definition.CommandList, 1, -1 do
			local command = unit.Definition.CommandList[i]
			if canUseCommand(unit, command) then
				return command.Id
			end
		end
	end

	-- Change the selection to a unit
	setSelectionUnit = function(unit)
		if mSelection ~= unit then
			SoundManager:Play('SelectUnit')
		end
		mSelection = unit
		mSelectedCommand = nil
		mSelectionType = 'unit'
		-- Always drop the previous selection's actionable squares here: the
		-- rebuild below only runs for friendly, live selections, and stale
		-- entries would let a tap act with the wrong unit/command pairing
		-- (e.g. indexing a boolean 'true' left by a command selection)
		mActionableSquares = nil
		if unit.MoveLeft > 0 and not unit.Enemy and #unit.Tail == unit.MaxSize and unit.MaxSize > 1 then
			mUnitsView:SetFlashUnit(unit)
		else
			mUnitsView:ClearFlashUnit()
		end
		mFlashySquare:Show(unit.Tail[1].x, unit.Tail[1].y)
		mHighlightedTiles:ClearAll()
		mUnitInfoView:SetSelectedUnit(unit)
		-- Anything populating the info window dismisses the mission text
		root().setState({ missionVisible = false })

		mTopbar:SetUndoVisible(gameState:CanUndo())

		if not unit.Done and gameState:IsGameStarted() then
			if mUnitMoveInProgress then
				-- Another unit's move is still animating: allow the selection
				-- (info pane, flash) but defer the move/attack UI until it
				-- completes — doAnimatedMove re-renders the selection then.
				-- Clearing the actionable squares also stops clicks from
				-- acting on the stale previous selection's squares.
				mActionableSquares = nil
			elseif unit.MoveLeft > 0 then
				local headX, headY = unit.Tail[1].x, unit.Tail[1].y
				local tentativeCommandId = getUsableCommand(unit)
				local points, attackFrom = gameState:GetMovementAndCommandRange(unit, tentativeCommandId)
				if not unit.Enemy then
					mActionableSquares = {}
					for x = 1, Places.PlaceWidth do
						mActionableSquares[x] = {}
					end
				end
				local movePoints = {}
				for _, point in pairs(points) do
					local dx = math.abs(point.x - headX)
					local dy = math.abs(point.y - headY)
					local tileGui;
					if ShowDirectlyAdjacentSquaresDifferent and dx + dy == 1 then
						tileGui = TileTemplates.MoveOverlayDirect()
					else
						tileGui = TileTemplates.MoveOverlaySimple()
					end
					if unit.Enemy then
						tileGui.ImageTransparency = 0.4
					end
					mHighlightedTiles:Set(point.x, point.y, tileGui)
					movePoints[point.x + point.y * Places.PlaceWidth] = true
					if not unit.Enemy then
						mActionableSquares[point.x][point.y] = 'move'
					end
				end
				local command = unit.Definition.Commands[tentativeCommandId]
				for targetPoint, from in pairs(attackFrom) do
					-- Tile-targeting commands (e.g. Bit-Man's Zero/One) can
					-- target squares inside the movement range; movement wins
					-- in this combined view or the two overlays checkerboard.
					-- Explicitly selecting the command shows the full range.
					if movePoints[targetPoint.x + targetPoint.y * Places.PlaceWidth] then
						continue
					end
					if not unit.Enemy then
						mActionableSquares[targetPoint.x][targetPoint.y] = from
					end
					local tileGui = mTileForCommandType[command.Type]()
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
		-- Anything populating the info window dismisses the mission text
		root().setState({ missionVisible = false })
	end

	-- Auto-selection order: damage dealers act first, then non-damage
	-- attackers (debuffs like Clog's slow, Bit-Man's grid edits), and units
	-- that only buff/heal (Medic, Data Doctors, Turbo, Fiddle) go last — you
	-- want to see where the fight ends up before spending the support moves
	local function unitAutoRank(unit)
		local commandList = unit.Definition.CommandList
		if #commandList == 0 then
			return 2
		end
		local rank = 3
		for _, command in pairs(commandList) do
			if command.Type == 'damage' then
				return 1
			end
			if not gameState:IsBeneficialCommand(command) then
				rank = 2
			end
		end
		return rank
	end
	local function pickNextAutoUnit(exclude)
		local best, bestRank = nil, math.huge
		for unit in pairs(gameState:GetUnits()) do
			if not unit.Done and not unit.Enemy and unit ~= exclude then
				local rank = unitAutoRank(unit)
				if rank < bestRank then
					best, bestRank = unit, rank
					if rank == 1 then
						break
					end
				end
			end
		end
		return best
	end

	local function doAutoSelectNextUnit()
		-- If we won the game, bail out
		if gameState:HasWon() or gameState:HasLost() then
			return
		end

		if mAutoSelectionEnabled then
			-- Try to select a next unit (attackers before support units)
			local unit = pickNextAutoUnit(mSelection)
			if unit then
				setSelectionUnit(unit)
				return
			end

			-- Did not find a next unit. End the turn automatically
			JourneyRecorder:Record("DoneTurn", "(auto)")
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

	-- Animated move wrapper: while the move plays out the player may select
	-- other units (their move/attack UI is deferred — see setSelectionUnit);
	-- when the move completes, re-render whatever is selected with full UI
	local function doAnimatedMove(unit, x, y)
		mUnitMoveInProgress = true
		local ok, err = pcall(function()
			controller:UnitMove(unit, x, y)
		end)
		mUnitMoveInProgress = false
		if not ok then
			error(err, 0)
		end
		if mSelection and mSelectionType == 'unit' then
			setSelectionUnit(mSelection)
		end
	end

	-- Do an action
	local function doAction(x, y)
		-- The unit this action is for: the player may change mSelection while
		-- the move animation below is still playing
		local unit = mSelection
		-- Move, or if an action is selected, attack
		if mSelectedCommand then
			-- Action
			if mActionableSquares[x][y] then
				mLastUsedCommandId[unit.Definition.Id] = mSelectedCommand
				JourneyRecorder:Record("Attack", unit.Definition.Id .. " " .. mSelectedCommand
					.. " " .. unit.Tail[1].x .. "," .. unit.Tail[1].y .. ">" .. x .. "," .. y)
				-- Cleared BEFORE the execute: it yields through the damage
				-- animation, and a click landing mid-animation re-entered
				-- here with the stale squares and a now-Done unit (an
				-- INVALID warn plus a bogus journey Attack record per spam
				-- click). The tap handler's mActionableSquares guard
				-- deflects those clicks now.
				mActionableSquares = nil
				controller:UnitExecute(unit, mSelectedCommand, x, y)
				doAutoSelectNextUnit()
			end
		else
			-- Move
			local action = mActionableSquares[x][y]
			if action == 'move' then
				JourneyRecorder:Record("Move", unit.Definition.Id
					.. " " .. unit.Tail[1].x .. "," .. unit.Tail[1].y .. ">" .. x .. "," .. y)
				doAnimatedMove(unit, x, y)
				-- We may win as a result of moving and collecting the access codes
				if gameState:HasWon() then
					return
				end
				if mSelection ~= unit then
					-- The player moved on to another unit mid-animation:
					-- leave their selection alone
					return
				end
				if unit.MoveLeft == 0 and hasNoAttackTargets(unit) then
					doAutoSelectNextUnit()
				end
			else
				-- Attack, but need to move first (recorded as Move + Attack so
				-- playback can replay two uniform actions)
				JourneyRecorder:Record("Move", unit.Definition.Id
					.. " " .. unit.Tail[1].x .. "," .. unit.Tail[1].y .. ">" .. action.x .. "," .. action.y)
				doAnimatedMove(unit, action.x, action.y)
				-- The move can win the game (collecting the last codes),
				-- ending the battle and clearing the selection under us
				if gameState:HasWon() then
					return
				end
				gameState:DelayFunc('AttackIntent')
				if gameState:HasWon() then
					return
				end
				local commandId = getUsableCommand(unit)
				if commandId then
					JourneyRecorder:Record("Attack", unit.Definition.Id .. " " .. commandId
						.. " " .. unit.Tail[1].x .. "," .. unit.Tail[1].y .. ">" .. x .. "," .. y)
					controller:UnitExecute(unit, commandId, x, y)
				end
				if mSelection ~= unit then
					return
				end
				mActionableSquares = nil
				doAutoSelectNextUnit()
			end
		end
	end

	-- Tutorial drag demonstration: a finger icon repeatedly glides from the
	-- program row to the target upload zone. Hidden while the player is
	-- performing a real drag themselves.
	local mDragDemo = nil
	function this:ClearDragDemo()
		if mDragDemo then
			mDragDemo.Cn:Disconnect()
			mDragDemo.Finger:Destroy()
			mDragDemo = nil
		end
	end
	function this:ShowDragDemo(programId, x, y)
		this:ClearDragDemo()
		local finger = Instance.new("TextLabel")
		finger.Name = "DragDemoFinger"
		-- Anchored at the top so the fingertip traces the drag path and the
		-- hand body hangs below it
		finger.AnchorPoint = Vector2.new(0.5, 0)
		finger.Size = UDim2.new(0, 60, 0, 60)
		finger.BackgroundTransparency = 1
		finger.Text = "\u{1F446}" -- pointing finger
		finger.TextSize = 44
		finger.ZIndex = 11
		local fingerStroke = Instance.new("UIStroke")
		fingerStroke.Color = Color3.new(0, 0, 0)
		fingerStroke.Transparency = 0.6
		fingerStroke.Thickness = 1.5
		fingerStroke.Parent = finger
		finger.Visible = false
		finger.Parent = mGui
		local startTime = os.clock()
		local kPeriod = 1.8
		local cn = RunService.RenderStepped:Connect(function()
			local hud = mGui:FindFirstChild("BattleHud")
			local window = hud and hud:FindFirstChild("ProgramsWindow", true)
			local row = window and window:FindFirstChild(programId, true)
			if not row or mDraggingProgram then
				finger.Visible = false
				return
			end
			local from = row.AbsolutePosition + row.AbsoluteSize / 2
			local to = mBattleBoard:ScreenFromGrid(x, y)
			local alpha = ((os.clock() - startTime) % kPeriod) / kPeriod
			-- Dwell briefly at the start, glide with easing, fade at the end
			local travel = math.clamp((alpha - 0.15) / 0.6, 0, 1)
			local eased = travel * travel * (3 - 2 * travel)
			local pos = from:Lerp(to, eased)
			finger.Position = UDim2.new(0, pos.X, 0, pos.Y)
			finger.TextTransparency = if alpha > 0.9 then (alpha - 0.9) / 0.1
				elseif alpha < 0.08 then 1 - alpha / 0.08
				else 0
			finger.Visible = true
		end)
		mDragDemo = { Finger = finger, Cn = cn }
	end

	function this:ShowTutorialArrowSquare(x, y)
		mUnitInfoView:TutorialHide()
		mTutorialArrow:Show(mBoard.Effects, 0, UDim2.new(0, (x-0.5)*mTileSize, 0, (y-0.5)*mTileSize))
	end
	function this:ShowTutorialArrowStartGame()
		mUnitInfoView:TutorialHide()
		local button = mTopbar:GetStartButton()
		if button then
			-- On the right side of the button (the left side sits near the
			-- Roblox topbar menu), pointing left at it
			mTutorialArrow:Show(button, -90, UDim2.new(1, 0, 0.5, 0))
		end
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

		-- Tutorial disables (greys out forfeit/skip in the shared menu; the
		-- Done Turn and Leave buttons stay hidden since the tutorial drives
		-- the battle)
		updateMenuContext()
		mTopbar:SetDoneTurnVisible(false)
		mTopbar:SetLeaveVisible(false)
		-- No Auto Place during the tutorial: placement is the lesson
		mTopbar:SetAutoPlaceVisible(false)
		-- The tutorial guides click-to-place but accepts drags: show the
		-- hint prominently (it starts as "Drag to Place" and flips to
		-- "Click to Place" once a zone is selected).
		-- No debug win either: the tutorial script must play out for real.
		mUnitInfoView:SetDragHintProminent(true)
		root().setState({ debugWinVisible = false })
	end

	-- Clear the selection, for tutorial
	function this:ClearSelection()
		clearSelection()
	end

	-- Tutorial: retitle the prominent scripts-window hint
	function this:SetProgramsHintText(text)
		mUnitInfoView:SetDragHintText(text)
	end

	-- Tutorial: restrict program clicks/drags to one script (cleared by
	-- ClearTutorialArrow along with the highlight)
	function this:SetOnlyAllowProgram(unitId)
		mUnitInfoView:SetOnlySelectUnit(unitId)
	end

	-- Select a command on the current unit programmatically, for tutorial
	-- steps that shouldn't make the player do the selection themselves
	function this:TutorialSelectCommand(commandId)
		setSelectedCommand(commandId)
	end

	-- Upload a program onto a zone (shared by drag-drop and the click flow).
	-- Returns true on success.
	local mOnlyAllowUpload = nil -- {x, y} tutorial restriction
	function this:SetOnlyAllowUpload(x, y)
		if x then
			mOnlyAllowUpload = { x = x, y = y }
		else
			mOnlyAllowUpload = nil
		end
	end
	local function isUploadZone(x, y)
		for _, zone in pairs(mUploadZones) do
			if zone.x == x and zone.y == y then
				return true
			end
		end
		return false
	end
	local function tryUploadProgram(id, x, y)
		if gameState:IsGameStarted() then
			return false
		end
		if not isUploadZone(x, y) then
			return false
		end
		if mOnlyAllowUpload and (mOnlyAllowUpload.x ~= x or mOnlyAllowUpload.y ~= y) then
			return false
		end
		if mUnitInfoView:GetCount(id) <= 0 then
			return false
		end

		local currentUnit = gameState:GetUnit(x, y)

		-- Is there a unit of that type already there?
		if currentUnit and currentUnit.Definition.Id == id then
			return false -- don't need to do anything
		end

		-- First return the unit that was uploaded there before if there is one
		if currentUnit then
			mUnitInfoView:UpdateCount(currentUnit.Definition.Id, 1)
		end

		-- Now upload the new unit
		mUnitInfoView:UpdateCount(id, -1)
		gameState:UploadUnit(x, y, Scripts[id])
		JourneyRecorder:Record("Place", id .. " @" .. x .. "," .. y)

		-- Show the start game button now that we have at least one unit uploaded
		mTopbar:SetStartVisible(true)
		return true
	end

	-- Re-place a previous run's setup (the fail screen's Retry): units land
	-- on their old zones but the battle is NOT started, so the player can
	-- adjust before pressing Start Databattle
	function this:ApplyInitialPlacement(placement)
		for _, entry in pairs(placement) do
			tryUploadProgram(entry.Id, entry.x, entry.y)
		end
	end

	-- Auto Place: fill every empty upload zone, strongest roles first (same
	-- ordering philosophy as auto-selection: damage dealers, then debuffers,
	-- then support)
	local function definitionAutoRank(def)
		if #def.CommandList == 0 then
			return 2
		end
		local rank = 3
		for _, command in pairs(def.CommandList) do
			if command.Type == 'damage' then
				return 1
			end
			if not gameState:IsBeneficialCommand(command) then
				rank = 2
			end
		end
		return rank
	end
	local function doAutoPlace()
		if gameState:IsGameStarted() then
			return
		end
		JourneyRecorder:Record("AutoPlace")
		local pool = {}
		for _, info in pairs(gameState:GetAvailableUnits()) do
			table.insert(pool, info.Id)
		end
		table.sort(pool, function(a, b)
			local rankA, rankB = definitionAutoRank(Scripts[a]), definitionAutoRank(Scripts[b])
			if rankA ~= rankB then
				return rankA < rankB
			end
			-- Within a role, strongest first: the highest-level (most
			-- valuable) programs the player owns get placed
			local valueA, valueB = Netmap.GetProgramValue(a), Netmap.GetProgramValue(b)
			if valueA ~= valueB then
				return valueA > valueB
			end
			return a < b -- deterministic within a rank
		end)
		for _, zone in pairs(mUploadZones) do
			if not gameState:GetUnit(zone.x, zone.y) then
				for _, id in pairs(pool) do
					if mUnitInfoView:GetCount(id) > 0 and tryUploadProgram(id, zone.x, zone.y) then
						break
					end
				end
			end
		end
	end

	-- The Auto Place topbar button shows until the first unit lands (however
	-- it lands: manually, via Auto Place itself, or a Retry pre-placement)
	if not gameState:IsGameStarted() then
		mTopbar:SetOnAutoPlace(doAutoPlace)
		mTopbar:SetAutoPlaceVisible(true)
		local autoPlaceCn
		autoPlaceCn = gameState.UnitAdded:connect(function()
			mTopbar:SetAutoPlaceVisible(false)
			autoPlaceCn:disconnect()
		end)
	end

	-- Adhoc analytic: which gesture places scripts (drag vs the two click
	-- flows). Server whitelists and caps.
	local function reportPlacementMethod(method)
		pcall(function()
			game.ReplicatedStorage.Remotes.PlacementMethod:FireServer(method)
		end)
	end

	-- Upload zone handling through the HUD: click a zone then a program to
	-- place there, or click a program with NO zone selected to drop it onto
	-- the first free spot (dragging remains the way to pick a specific spot)
	mUnitInfoView.UnitSelected:connect(function(id)
		if mSelectionType == 'upload' then
			if not tryUploadProgram(id, mSelection.x, mSelection.y) then
				return
			end
			reportPlacementMethod('clickZone')
		elseif not gameState:IsGameStarted() then
			for _, zone in pairs(mUploadZones) do
				-- Free spots only: tryUploadProgram would happily REPLACE an
				-- occupied zone's unit, which a blind click must not do
				if not gameState:GetUnit(zone.x, zone.y) and tryUploadProgram(id, zone.x, zone.y) then
					reportPlacementMethod('clickUnit')
					return
				end
			end
			clearSelection()
		else
			-- Deselect the current selection if there is one
			clearSelection()
		end
	end)

	-- Where a program drop should land. A direct hit on an upload zone always
	-- wins; otherwise fall back to the nearest zone whose DOUBLED hit box
	-- (half a tile beyond each edge) contains the drop point — zones are
	-- small and sometimes adjacent, so exact hits must take priority.
	local function uploadZoneDropTarget(screenPos)
		local x, y = mBattleBoard:GridAtScreen(screenPos)
		if x and y and isUploadZone(x, y) then
			return x, y
		end
		local gx, gy = mBattleBoard:GridPointAtScreen(screenPos)
		local best, bestDist = nil, math.huge
		for _, zone in pairs(mUploadZones) do
			-- The tutorial restricts uploads to one zone: only snap to it
			if not mOnlyAllowUpload or (mOnlyAllowUpload.x == zone.x and mOnlyAllowUpload.y == zone.y) then
				local dx = math.abs(gx - zone.x)
				local dy = math.abs(gy - zone.y)
				if dx <= 1 and dy <= 1 then
					local d = dx * dx + dy * dy
					if d < bestDist then
						bestDist = d
						best = zone
					end
				end
			end
		end
		if best then
			return best.x, best.y
		end
		return x, y
	end

	-- Shared drag session: a ghost icon follows the pointer; releasing over an
	-- upload zone uploads the program there, anywhere else leaves it in the
	-- inventory. Used both for dragging out of the Programs window and for
	-- dragging an already-placed unit back off its upload zone (sourceZone is
	-- then that zone, letting a drop on an occupied zone SWAP the two units).
	local UserInputService = game:GetService('UserInputService')
	local function startDragSession(id, screenPos, sourceZone)
		mDraggingProgram = true
		-- Show what's being dragged in the info window right away
		mUnitInfoView:SetSelectedUnitDefinition(id)
		root().setState({ missionVisible = false })
		local def = Scripts[id]

		local ghost = Instance.new("ImageLabel")
		ghost.Name = "DragGhost"
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Size = UDim2.new(0, 48, 0, 48)
		-- Clamped: the ScreenGui clips at the screen edges, and a ghost
		-- centered on a pointer near the bottom would render cut off
		local function ghostPosition(px, py)
			local view = mGui.AbsoluteSize
			return UDim2.new(
				0, math.clamp(px, 24, math.max(24, view.X - 24)),
				0, math.clamp(py, 24, math.max(24, view.Y - 24)))
		end
		ghost.Position = ghostPosition(screenPos.X, screenPos.Y)
		ghost.BackgroundColor3 = def.Color
		ghost.BackgroundTransparency = 0.3
		ghost.BorderColor3 = Color3.new(0, 0, 0)
		ghost.Image = def.Image
		ghost.ImageTransparency = 0.2
		ghost.ZIndex = 10
		ghost.Parent = mGui

		-- Holding the ghost near a screen edge pans the map toward it,
		-- scroll-at-edge style (full speed at the edge, easing in across
		-- the margin). Screen-up is world -Z on the top-down battle camera.
		local kEdgePanMarginPx = 48
		local kEdgePanSpeedStuds = 50 -- per second at the very edge
		local lastPointer = Vector2.new(screenPos.X, screenPos.Y)
		local function edgeStrength(distFromEdge)
			return math.clamp((kEdgePanMarginPx - distFromEdge) / kEdgePanMarginPx, 0, 1)
		end
		local panCn = RunService.RenderStepped:Connect(function(dt)
			local view = mGui.AbsoluteSize
			local panX = edgeStrength(view.X - lastPointer.X) - edgeStrength(lastPointer.X)
			local panZ = edgeStrength(view.Y - lastPointer.Y) - edgeStrength(lastPointer.Y)
			if panX ~= 0 or panZ ~= 0 then
				mBattleBoard:PanBy(
					panX * kEdgePanSpeedStuds * dt,
					panZ * kEdgePanSpeedStuds * dt)
			end
		end)

		local moveCn, endCn
		moveCn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				lastPointer = Vector2.new(input.Position.X, input.Position.Y)
				ghost.Position = ghostPosition(input.Position.X, input.Position.Y)
			end
		end)
		endCn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			moveCn:Disconnect()
			endCn:Disconnect()
			panCn:Disconnect()
			ghost:Destroy()
			mDraggingProgram = false
			if mDestroyed then
				-- The battle was torn down mid-drag (e.g. forfeit from the
				-- menu with a second touch)
				return
			end
			local x, y = uploadZoneDropTarget(Vector2.new(input.Position.X, input.Position.Y))
			if x and y then
				-- A unit already on the target zone gets displaced back to
				-- the inventory by the upload...
				local occupant = gameState:GetUnit(x, y)
				local displacedId = if occupant and not occupant.Enemy
					then occupant.Definition.Id
					else nil
				if tryUploadProgram(id, x, y) then
					SoundManager:Play('SelectUnit')
					mUnitInfoView:SetSelectedUnitDefinition(id)
					reportPlacementMethod('drag')
					-- ...and when the drag came off another zone, lands
					-- there instead: zone-to-zone drops swap the two units
					if displacedId and sourceZone
						and not (sourceZone.x == x and sourceZone.y == y) then
						tryUploadProgram(displacedId, sourceZone.x, sourceZone.y)
					end
				end
			end
		end)
	end

	-- Drag out of the Programs window
	mUnitInfoView.ProgramDragBegan:connect(function(id, viewportPos)
		if gameState:IsGameStarted() or mDestroyed or mDraggingProgram then
			-- mDraggingProgram: never start a second session mid-drag (the
			-- held pointer transiting other list rows must keep the original)
			return
		end
		startDragSession(id, viewportPos)
	end)

	-- Drag a placed unit back off its upload zone (claims the gesture before
	-- the camera pans). The unit returns to the inventory immediately;
	-- dropping it on a zone re-places it, anywhere else it stays in inventory.
	local function hasPlayerUnits()
		for unit in pairs(gameState:GetUnits()) do
			if not unit.Enemy then
				return true
			end
		end
		return false
	end
	mBattleBoard:SetPressCapture(function(x, y, screenPos)
		if mDestroyed or gameState:IsGameStarted() then
			return false
		end
		if not mAutoSelectionEnabled then
			return false -- no repositioning during the scripted tutorial
		end
		if not isUploadZone(x, y) then
			return false -- pre-placed friendly units can't be picked up
		end
		local unit = gameState:GetUnit(x, y)
		if not unit or unit.Enemy then
			return false
		end
		local id = gameState:RemoveUploadedUnit(x, y)
		if not id then
			return false
		end
		mUnitInfoView:UpdateCount(id, 1)
		if not hasPlayerUnits() then
			mTopbar:SetStartVisible(false)
		end
		startDragSession(id, screenPos, { x = x, y = y })
		return true
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

	handleGameEnded = function(wonGame, creditsEarned, skipLevel)
		if mDestroyed then
			return
		end
		if not wonGame and not gameState:IsGameStarted() then
			-- They didn't even start the game (Leave / pre-start forfeit):
			-- just bail out quietly, that's not a loss
			this.CloseGame:fire(false, nil, false)
			return
		end
		clearSelection()
		mTopbar:SetDoneTurnVisible(false)
		mTopbar:SetUndoVisible(false)
		mUnitInfoView:Hide()
		mDidWin = wonGame
		mWasSkipped = skipLevel and true or false
		if mAutoSelectionEnabled then
			root().setState({ endGameOverlayVisible = true })
			if skipLevel then
				ReplaySubmission:Skip(gameState:GetMapId())
			else
				ReplaySubmission:Submit(gameState:GetReplay())
			end
		end
		root().setState({
			endGameWon = wonGame,
			-- Re-beating a node: showcase any stat improvements (the
			-- stats-minded player's payoff). Real wins only - not skips.
			improvementText = if wonGame and not skipLevel
				then GameView.BuildImprovementText(mPriorBests, gameState:GetPlayStats(), mWorldBests) or StatefulRoot.None
				else StatefulRoot.None,
			-- Re-beat wins also offer jumping straight to the stats page
			viewStatsVisible = wonGame and not skipLevel and mPriorBests ~= nil,
		})
		if wonGame then
			-- Play victory sound?
			SoundManager:Play('WinBattle')
		else
			SoundManager:Play('LoseBattle')
		end
	end

	-- Skip node
	trySkip = function()
		if gameState:IsEnemyTurn() then
			-- Skipping tears the battle down; wait out the enemy turn
			return
		end
		if mAutoSelectionEnabled then
			if LocalPlayerData:GetSkips() > 0 then
				handleGameEnded(--[[wonGame=]] true, --[[creditsEarned=]] 0, --[[skipping=]] true)
				if menu then
					menu:Hide()
				end
			else
				BuyLevelSkipView.new(mGui)
			end
		end
	end
	local function updateSkipsButton()
		local skips = LocalPlayerData:GetSkips()
		local text;
		if skips > 0 then
			text = "Skip Node ("..skips.." skip"..((skips == 1) and "" or "s").." available)"
		else
			text = "Skip Node"
		end
		mSkipText = text
		root().setState({ skipText = text })
		updateMenuContext()
	end
	updateSkipsButton()
	local mUpdateSkipsCn = LocalPlayerData.SkipsChanged:connect(updateSkipsButton)

	-- When the game actually starts
	gameState.GameStarted:connect(function()
		if mPulseCn then
			mPulseCn:Disconnect()
		end
		mUploadView:ClearAll()
		-- The tutorial (auto-selection disabled) drives turns itself: no button
		mTopbar:SetStartVisible(false)
		mTopbar:SetLeaveVisible(false)
		mTopbar:SetDoneTurnVisible(mAutoSelectionEnabled)
		-- Setup is over: the mission box and debug win button leave with it
		root().setState({ missionVisible = false, debugWinVisible = false })
		mUnitInfoView:SetProgramListVisible(false)
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
			root().setState({ submittingText = "(Play successfully recorded)" })
		end
	end)

	-- Show attack intent
	gameState.ShowEnemyIntention:connect(function(squares, attackType)
		mHighlightedTiles:ClearAll()
		for _, sq in pairs(squares) do
			mHighlightedTiles:Set(sq.x, sq.y, mTileForCommandType[attackType]())
		end
	end)

	gameState.SectorDeleted:connect(function(x, y, color)
		mUnitsView:ShowDamage(x, y, color)
	end)

	-- Set up tile grid and events for tile grid
	for x = 1, Places.PlaceWidth do
		for y = 1, Places.PlaceHeight do
			if gameState:IsFilled(x, y) then
				mMapView:Set(x, y, TileTemplates.MapTile())
			end
		end
	end
	gameState.TileAdded:connect(function(x, y)
		mMapView:Set(x, y, TileTemplates.MapTile())
	end)
	gameState.TileRemoved:connect(function(x, y)
		mMapView:Clear(x, y)
	end)

	-- Pickups
	for _, coord in pairs(gameState:GetInitialCodes()) do
		mPickups:Set(coord.x, coord.y, TileTemplates.PickupCodes())
	end
	for _, coord in pairs(gameState:GetInitialCredits()) do
		mPickups:Set(coord.x, coord.y, TileTemplates.PickupCredits())
	end
	gameState.CreditsRestored:connect(function(x, y)
		mPickups:Set(x, y, TileTemplates.PickupCredits())
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
			mTopbar:SetDoneTurnVisible(false)
		else
			-- Start of our turn, prefer attackers over support units
			if mAutoSelectionEnabled then
				local firstUnit = pickNextAutoUnit(nil)
				setSelectionUnit(firstUnit) -- must not be nil since if we had no units the game would be over
			end

			-- Show end turn button (not during the tutorial)
			mTopbar:SetDoneTurnVisible(mAutoSelectionEnabled)
		end
	end)

	-- Set up upload zones. Empty zones pulse until a unit is placed on them.
	local mUploadZoneTiles = {}
	for _, coord in pairs(mUploadZones) do
		local tile = TileTemplates.UploadOverlay()
		-- Counter-phase borders: fade IN as the main image flashes out, so
		-- the zone is never just an empty square mid-flash. Two variants
		-- distinguish selection without any tinting: non-selected zones
		-- flash an INSET border, the selected zone an OUTSET one (a stroke
		-- always draws outward from its host, so the inset variant lives on
		-- a shrunken inner frame).
		local border = Instance.new("UIStroke")
		border.Color = Color3.new(1, 1, 1)
		border.Thickness = 2
		border.Transparency = 1
		border.Parent = tile
		local insetFrame = Instance.new("Frame")
		insetFrame.BackgroundTransparency = 1
		insetFrame.Position = UDim2.new(0, 3, 0, 3)
		insetFrame.Size = UDim2.new(1, -6, 1, -6)
		insetFrame.Parent = tile
		local insetBorder = Instance.new("UIStroke")
		insetBorder.Color = Color3.new(1, 1, 1)
		insetBorder.Thickness = 2
		insetBorder.Transparency = 1
		insetBorder.Parent = insetFrame
		mUploadView:Set(coord.x, coord.y, tile)
		table.insert(mUploadZoneTiles, {
			x = coord.x, y = coord.y, Gui = tile,
			Border = border, InsetBorder = insetBorder,
		})
	end
	mPulseCn = RunService.RenderStepped:Connect(function()
		-- Full-swing flash (solid to nearly gone) so the zones read
		-- unmistakably as "put things here" during setup
		local pulse = 0.85 * (0.5 + 0.5 * math.sin(os.clock() * 5))
		for _, entry in mUploadZoneTiles do
			if entry.Gui.Parent then
				if gameState:GetUnit(entry.x, entry.y) then
					entry.Gui.ImageTransparency = 0
					entry.Border.Transparency = 1
					entry.InsetBorder.Transparency = 1
				else
					-- The SELECTED zone keeps its image solid (only the
					-- border keeps flashing): it's the click-flow target,
					-- dimming it read as deselection. Its border draws
					-- OUTSET; non-selected zones flash the INSET one.
					local selected = mSelectionType == 'upload'
						and mSelection ~= nil
						and mSelection.x == entry.x and mSelection.y == entry.y
					entry.Gui.ImageTransparency = if selected then 0 else pulse
					-- Counter-phase: strongest exactly when the image is
					-- most faded (pulse peaks at 0.85)
					local borderTransparency = 1 - pulse / 0.85
					entry.Border.Transparency = if selected then borderTransparency else 1
					entry.InsetBorder.Transparency = if selected then 1 else borderTransparency
				end
			end
		end
	end)

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

	-- Taps on the 3D board arrive as grid coordinates
	mBattleBoard.Tapped:connect(function(x, y)
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
					-- Anything populating the info window dismisses the
					-- mission text
					root().setState({ missionVisible = false })
				end
			end
		end

		-- For the tutorial
		this.SquareSelected:fire(x, y)
	end)

	-- Stop any animation cycles, disconnect any events
	function this:Destroy()
		if mDestroyed then
			return
		end
		if menu then
			menu:SetBattleContext(nil)
		end
		mDestroyed = true
		if mPulseCn then
			mPulseCn:Disconnect()
		end
		this:ClearDragDemo()
		mFlashySquare:Destroy()
		mUnitsView:Destroy()
		mBattleSoundLooper:Destroy()
		mTutorialArrow:Destroy()
		mUnitInfoView:Destroy()
		mBattleBoard:Destroy()
		root().unmount()
		mGui:Destroy()
		mUpdateSkipsCn:disconnect()
	end

	return this
end

return GameView
