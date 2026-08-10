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
local UnitInfoView = require(game.ReplicatedStorage.UnitInfoView)
local UnitInfoViewMobile = require(game.ReplicatedStorage.UnitInfoViewMobile)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local ReplaySubmission = require(game.ReplicatedStorage.ReplaySubmission)

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
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)
local WindowsSlider = require(game.ReplicatedStorage.Components.WindowsSlider)

local e = React.createElement

local ShowDirectlyAdjacentSquaresDifferent = true

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"
local kInkColor = Color3.new(0.105882, 0.164706, 0.207843)
local kHeaderColor = Color3.new(0.737255, 0.784314, 0.886275)

local GameView = {}

--------------------------------------------------------------------------------
-- Chrome render helpers
--------------------------------------------------------------------------------

local function menuLabel(text: string, y: number)
	return e("TextLabel", {
		Position = UDim2.new(0, 10, 0, y),
		Size = UDim2.new(1, -5, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		TextSize = 18,
		TextColor3 = Color3.new(0, 0, 0),
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.9,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
end

-- The desktop Done Turn / Undo tiles (CommandListEntry style, not Windows buttons)
local function commandTile(name: string, position: UDim2, text1: string, visible: boolean, onClick)
	return e("ImageButton", {
		Active = true,
		AnchorPoint = Vector2.new(1, 1),
		Position = position,
		Size = UDim2.new(0, 100, 0, 100),
		BorderSizePixel = 2,
		ZIndex = 3,
		Visible = visible,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		CommandName = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundColor3 = kHeaderColor,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = kInkColor,
			Text = name,
		}),
		CommandText1 = e("TextLabel", {
			Position = UDim2.new(0, 2, 0, 16),
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = kInkColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = text1,
		}),
		CommandText2 = e("TextLabel", {
			Position = UDim2.new(0, 2, 0, 32),
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = kInkColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = "",
		}),
	})
end

-- The Windows-styled small command buttons (Code-font label filling the button)
local function codeLabel(text: string)
	return e("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 20,
		TextColor3 = Color3.new(0, 0, 0),
		Text = text,
	})
end

local function menuButtonCover()
	return e("Frame", {
		Position = UDim2.new(0, -75, 0, 0),
		Size = UDim2.new(0, 75, 0, 36),
		BackgroundColor3 = Color3.new(0.752941, 0.752941, 0.752941),
		BorderSizePixel = 0,
	})
end

local function startGameButton(visible: boolean, onClick)
	return e("TextButton", {
		Active = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 200, 0, 30),
		BackgroundColor3 = Color3.new(0.701961, 0, 0),
		Font = Enum.Font.Code,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Start Databattle",
		ZIndex = 3,
		Visible = visible,
		[React.Event.MouseButton1Click] = onClick,
	})
end

local function GameViewChrome(props)
	local hidden = props.commandsHidden
	local disabledTint = Color3.new(0.5, 0.5, 0.5)
	local disabledText = Color3.new(0.6, 0.6, 0.6)

	local commands
	if props.desktopUI then
		commands = e("Frame", {
			Name = "LargeCommands",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			DoneTurnButton = commandTile(
				"Done Turn", UDim2.new(1, 0, 1, 0),
				"I'm done moving my scripts, end my turn.",
				props.doneTurnVisible and not hidden, props.onDoneTurn),
			UndoCommand = commandTile(
				"Undo", UDim2.new(1, -101, 1, 0),
				"Undo the actions and movement of the last script you used.",
				props.undoVisible and not hidden, props.onUndo),
			MenuButton = e(WindowsButton, {
				Name = "MenuButton",
				Position = UDim2.new(0, 75, 0, 0),
				Size = UDim2.new(0, 75, 0, 36),
				ZIndex = 4,
				Visible = not hidden,
				OnClick = props.onMenuOpen,
			}, {
				TextLabel = codeLabel("Menu"),
				Cover = menuButtonCover(),
			}),
			StartGameButton = startGameButton(props.startGameVisible and not hidden, props.onStartGame),
		})
	else
		commands = e("Frame", {
			Name = "SmallCommands",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			DoneTurnButton = e(WindowsButton, {
				Name = "DoneTurnButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 74, 1, -30),
				Size = UDim2.new(0, 130, 0, 36),
				ZIndex = 4,
				Visible = props.doneTurnVisible and not hidden,
				OnClick = props.onDoneTurn,
			}, {
				TextLabel = codeLabel("Done Turn"),
			}),
			UndoCommand = e(WindowsButton, {
				Name = "UndoCommand",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 74, 1, -74),
				Size = UDim2.new(0, 130, 0, 36),
				ZIndex = 4,
				Visible = props.undoVisible and not hidden,
				OnClick = props.onUndo,
			}, {
				TextLabel = codeLabel("Undo"),
			}),
			MenuButton = e(WindowsButton, {
				Name = "MenuButton",
				Position = UDim2.new(0, 75, 0, 0),
				Size = UDim2.new(0, 75, 0, 36),
				ZIndex = 4,
				Visible = not hidden,
				OnClick = props.onMenuOpen,
			}, {
				TextLabel = codeLabel("Menu"),
				Cover = menuButtonCover(),
			}),
			StartGameButton = startGameButton(props.startGameVisible and not hidden, props.onStartGame),
		})
	end

	return e(React.Fragment, nil, {
		Commands = commands,
		MenuMouseCatcher = e("ImageButton", {
			Active = true,
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Image = "",
			ZIndex = 6,
			Visible = props.menuOpen,
		}, {
			Menu = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 400, 0, 242),
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
					Text = "Databattle Menu",
				}),
				Inset = e("ImageLabel", {
					Position = UDim2.new(0, 5, 0, 25),
					Size = UDim2.new(1, -10, 1, -29),
					BackgroundTransparency = 1,
					Image = kInsetImage,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(8, 8, 8, 8),
				}, {
					ConcedeLabel = menuLabel("Forfeit Databattle", 6),
					ConcedeButton = e(WindowsButton, {
						Name = "ConcedeButton",
						Position = UDim2.new(0.4, 0, 0, 6),
						Size = UDim2.new(0.6, -6, 0, 36),
						ImageColor3 = if props.tutorialDisabled then disabledTint else nil,
						OnClick = props.onConcede,
					}, {
						Text = e("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, -1),
							Size = UDim2.new(1, -20, 0, 24),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSans,
							TextSize = 18,
							TextColor3 = if props.tutorialDisabled then disabledText else Color3.new(0, 0, 0),
							Text = "Forfeit",
						}),
					}),
					SkipLabel = menuLabel("Skip Databattle", 46),
					SkipButton = e(WindowsButton, {
						Name = "SkipButton",
						Position = UDim2.new(0.4, 0, 0, 46),
						Size = UDim2.new(0.6, -6, 0, 36),
						ImageColor3 = if props.tutorialDisabled then disabledTint else Color3.new(0, 0, 1),
						OnClick = props.onSkip,
					}, {
						Text = e("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, -1),
							Size = UDim2.new(1, -20, 0, 24),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSansBold,
							TextSize = 18,
							TextColor3 = if props.tutorialDisabled then disabledText else Color3.new(1, 1, 1),
							Text = props.skipText,
						}),
					}),
					-- Note the template's double space in the label text
					SoundVolumeLabel = menuLabel("Sound Effect  Volume", 86),
					SoundVolume = e(WindowsSlider, {
						Position = UDim2.new(0.4, 0, 0, 86),
						Size = UDim2.new(0.6, -6, 0, 36),
						Value = props.soundValue,
						LeftLabel = "Muted",
						RightLabel = "RIP Eardrums",
						OnChanged = props.onSoundChanged,
					}),
					MusicVolumeLabel = menuLabel("Music Volume", 126),
					MusicVolume = e(WindowsSlider, {
						Position = UDim2.new(0.4, 0, 0, 126),
						Size = UDim2.new(0.6, -6, 0, 36),
						Value = props.musicValue,
						LeftLabel = "Muted",
						RightLabel = "DAT BASS",
						OnChanged = props.onMusicChanged,
					}),
				}),
				DoneButton = e(WindowsButton, {
					Name = "DoneButton",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0.25, 0, 1, -10),
					Size = UDim2.new(0.5, 0, 0, 36),
					Text = "Return to Databattle",
					OnClick = props.onMenuClose,
				}),
			}),
		}),
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
					then UDim2.new(0, 300, 0, 180)
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
					TextStrokeColor3 = Color3.new(1, 1, 1),
					TextStrokeTransparency = 0.9,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = if props.endGameWon == true
						then "You won the battle!"
						elseif props.endGameWon == false then "You were defeated."
						else "",
				}),
				SubmittingText = e("TextLabel", {
					Position = UDim2.new(0, 0, 0, 50),
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = 11,
					TextColor3 = Color3.new(0, 0.482353, 1),
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = props.submittingText,
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
				OkayButton = e(WindowsButton, {
					Name = "OkayButton",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 16, 1, -12),
					Size = UDim2.new(1, -32, 0, 36),
					Text = "Continue",
					OnClick = props.onOkay,
				}),
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- Imperative board construction
--------------------------------------------------------------------------------

local function buildBoard(tileSize, boardScale)
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.Position = UDim2.new(0.5, 75, 0.5, 16)
	board.Size = UDim2.new(0, Places.PlaceWidth * tileSize, 0, Places.PlaceHeight * tileSize)
	board.BackgroundTransparency = 1
	board.ZIndex = 2
	local scaler = Instance.new("UIScale")
	scaler.Scale = boardScale
	scaler.Parent = board
	local function layer(name: string, zIndex: number?)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = 1
		if zIndex then
			frame.ZIndex = zIndex
		end
		frame.Parent = board
		return frame
	end
	layer("Tiles")
	layer("UploadZones", 2)
	layer("Units", 3)
	layer("HighlightedTiles", 4)
	layer("Effects", 5)
	local clickDetector = Instance.new("ImageButton")
	clickDetector.Name = "ClickDetector"
	clickDetector.Active = true
	clickDetector.Size = UDim2.new(1, 0, 1, 0)
	clickDetector.BackgroundTransparency = 1
	clickDetector.Image = ""
	clickDetector.Parent = board
	return board
end

--------------------------------------------------------------------------------
-- View object
--------------------------------------------------------------------------------

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

	-- Big scale
	local mBoardScale = 1
	if DeviceInfo.ScreenHeight < 400 then
		mBoardScale = 0.9
	elseif DeviceInfo.ScreenHeight > 700 then
		mBoardScale = 1.8
	elseif DeviceInfo.ScreenHeight > 800 then
		mBoardScale = 2
	end

	local mUseDesktopUI = DeviceInfo.ScreenHeight > 700

	-- The main Roblox Gui
	local mTileSize = 32
	local mGui = Instance.new("Frame")
	mGui.Name = "Container"
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.ZIndex = 5
	function this:getGui()
		return mGui
	end

	local mPlaceBackground = Instance.new("ImageLabel")
	mPlaceBackground.Name = "PlaceBackground"
	mPlaceBackground.Size = UDim2.new(1, 0, 1, 0)
	mPlaceBackground.BackgroundTransparency = 1
	mPlaceBackground.BorderSizePixel = 0
	mPlaceBackground.Image = gameState:GetPlaceBackground()
	mPlaceBackground.Parent = mGui

	local mBoard = buildBoard(mTileSize, mBoardScale)
	mBoard.Parent = mGui
	local mClickDetector = mBoard.ClickDetector

	local mInfo = Instance.new("Frame")
	mInfo.Name = "Info"
	mInfo.Size = UDim2.new(1, 0, 1, 0)
	mInfo.BackgroundTransparency = 1
	mInfo.ZIndex = 3
	mInfo.Parent = mGui

	-- Slider adapters bridging the React sliders to SoundManager's imperative
	-- slider API (SoundManager itself is unchanged)
	local mRoot: StatefulRoot.StatefulRoot? = nil
	local function root(): StatefulRoot.StatefulRoot
		return mRoot :: StatefulRoot.StatefulRoot
	end
	local function makeSliderAdapter(stateKey: string)
		local adapter = {}
		adapter.Changed = Signal.new()
		local mValue = 0
		function adapter:Get()
			return mValue
		end
		function adapter:Set(value)
			if value == mValue then
				return
			end
			local old = mValue
			mValue = value
			root().setState({ [stateKey] = value })
			adapter.Changed:fire(value, old)
		end
		return adapter
	end
	local mSoundSlider = makeSliderAdapter("soundValue")
	local mMusicSlider = makeSliderAdapter("musicValue")

	local mDidWin = nil

	-- Forward declarations used by chrome callbacks
	local clearSelection
	local setSelectionUnit
	local handleGameEnded
	local trySkip

	-- Portaled: mGui also holds the imperative Board/Info/PlaceBackground
	mRoot = StatefulRoot.createPortaled(mGui, GameViewChrome, {
		desktopUI = mUseDesktopUI,
		startGameVisible = false,
		doneTurnVisible = false,
		undoVisible = false,
		commandsHidden = false,
		menuOpen = false,
		tutorialDisabled = false,
		endGameOverlayVisible = false,
		endGameWon = nil,
		submittingText = "(Submitting play...)",
		skipText = "Skip Node",
		soundValue = 0,
		musicValue = 0,
		onStartGame = function()
			controller:StartGame()
		end,
		onDoneTurn = function()
			controller:EndTurn()
		end,
		onUndo = function()
			local unit = controller:Undo()
			if unit then
				setSelectionUnit(unit)
			end
		end,
		onMenuOpen = function()
			root().setState({ menuOpen = true })
		end,
		onMenuClose = function()
			root().setState({ menuOpen = false })
		end,
		onConcede = function()
			-- TODO: "Are you sure?" dialgue
			if mAutoSelectionEnabled then
				root().setState({ menuOpen = false })
				handleGameEnded(false, 0)
			end
		end,
		onSkip = function()
			trySkip()
		end,
		onOkay = function()
			this.CloseGame:fire(mDidWin, gameState:GetReplay(), gameState:IsGameStarted())
		end,
		onSoundChanged = function(value)
			mSoundSlider:Set(value)
		end,
		onMusicChanged = function(value)
			mMusicSlider:Set(value)
		end,
	})

	-- Sound sliders
	SoundManager:AddMusicSlider(mMusicSlider)
	SoundManager:AddSoundSlider(mSoundSlider)

	-- Rendered chrome lookups (post-flush only)
	local function findCommandsFrame(): Instance
		return mGui:FindFirstChild(mUseDesktopUI and "LargeCommands" or "SmallCommands") :: Instance
	end

	-- Battle sound
	local mBattleSoundLooper = BattleSoundLooper.new()
	mBattleSoundLooper:Play()

	-- Program info view
	local mUnitInfoView;
	if mUseDesktopUI then
		mUnitInfoView = UnitInfoView.new(mInfo, gameState:GetAvailableUnits())
	else
		mUnitInfoView = UnitInfoViewMobile.new(mInfo, gameState:GetAvailableUnits())
	end

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
		root().setState({ undoVisible = gameState:CanUndo() })
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
	setSelectionUnit = function(unit)
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

		root().setState({ undoVisible = gameState:CanUndo() })

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
						tileGui = TileTemplates.MoveOverlayDirect()
					else
						tileGui = TileTemplates.MoveOverlaySimple()
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
		mTutorialArrow:Show(mBoard.Effects, 0, UDim2.new(0, (x-0.5)*mTileSize, 0, (y-0.5)*mTileSize))
	end
	function this:ShowTutorialArrowStartGame()
		mUnitInfoView:TutorialHide()
		mTutorialArrow:Show(findCommandsFrame():FindFirstChild("StartGameButton") :: Instance, 90, UDim2.new(0, 0, 0.5, 0))
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
		root().setState({ tutorialDisabled = true })
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
			root().setState({ startGameVisible = true })
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

	handleGameEnded = function(wonGame, creditsEarned, skipLevel)
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
		root().setState({ commandsHidden = true })
		mUnitInfoView:Hide()
		mDidWin = wonGame
		if mAutoSelectionEnabled then
			root().setState({ endGameOverlayVisible = true })
			if skipLevel then
				ReplaySubmission:Skip(gameState:GetMapId())
			else
				ReplaySubmission:Submit(gameState:GetReplay())
			end
		end
		root().setState({ endGameWon = wonGame })
		if wonGame then
			-- Play victory sound?
			SoundManager:Play('WinBattle')
		else
			SoundManager:Play('LoseBattle')
		end
	end

	-- Skip node
	trySkip = function()
		if mAutoSelectionEnabled then
			if LocalPlayerData:GetSkips() > 0 then
				handleGameEnded(--[[wonGame=]] true, --[[creditsEarned=]] 0, --[[skipping=]] true)
				root().setState({ menuOpen = false })
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
		root().setState({ skipText = text })
	end
	updateSkipsButton()
	local mUpdateSkipsCn = LocalPlayerData.SkipsChanged:connect(updateSkipsButton)

	-- When the game actually starts
	gameState.GameStarted:connect(function()
		mUploadView:ClearAll()
		root().setState({ startGameVisible = false, doneTurnVisible = true })
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
			root().setState({ doneTurnVisible = false })
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
			root().setState({ doneTurnVisible = true })
		end
	end)

	-- Set up upload zones
	for _, coord in pairs(mUploadZones) do
		mUploadView:Set(coord.x, coord.y, TileTemplates.UploadOverlay())
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
		if mDestroyed then
			return
		end
		SoundManager:RemoveSlider(mSoundSlider)
		SoundManager:RemoveSlider(mMusicSlider)
		mDestroyed = true
		mFlashySquare:Destroy()
		mUnitsView:Destroy()
		mBattleSoundLooper:Destroy()
		mTutorialArrow:Destroy()
		mUnitInfoView:Destroy()
		root().unmount()
		mGui:Destroy()
		mUpdateSkipsCn:disconnect()
	end

	return this
end

return GameView
