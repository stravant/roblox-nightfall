-- The first-time-player tutorial (formerly UglyTutorialNonsense).
--
-- Design: get the player acting immediately and stay out of their way.
-- - One callout box on the netmap, then a non-blocking corner dialogue tells
--   them which node to jack into.
-- - During the databattle the dialogue never blocks: each box explains the
--   next action (with a tutorial arrow pointing at it) and advances when the
--   player performs it, not when they dismiss a prompt.
-- - One wrap-up box about the netmap after the battle is won.
--
-- While the tutorial is running, Tutorial:IsActive() is true and MainView
-- suppresses its normal node-click handling; the tutorial owns node clicks.

local Places = require(game.ReplicatedStorage.Places)
local Netmap = require(game.ReplicatedStorage.Netmap)
local GameState = require(game.ReplicatedStorage.GameState)
local GameController = require(game.ReplicatedStorage.GameController)
local GameView = require(game.ReplicatedStorage.GameView)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DialogueView = require(game.ReplicatedStorage.DialogueView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local Tutorial = {}

local mActive = false

function Tutorial:IsActive()
	return mActive
end

-- onBattleWon is called after the battle is won and the netmap is visible
-- again, right before the wrap-up box (MainView uses it to mark the hq node
-- beaten, which reveals the adjacent nodes the wrap-up box tells the player
-- to click). `topbar` is MainView's topbar interface: the tutorial's battle
-- needs the Start Databattle button (and its arrow target) like any other.
function Tutorial:PlayTutorial(container, netmapView, mainDialogue, mainMenu, topbar, onBattleWon)
	if not DebugFlags:PlayTutorial() then
		return
	end

	mActive = true

	----------------------------------------------------------------------
	-- Netmap: one callout, then a non-blocking pointer at the HQ node
	----------------------------------------------------------------------

	ModalManager:SetModal(true)
	mainDialogue:SetVisible(true)
	mainDialogue:ExecuteConversation(Netmap.TutorialCallout)
	mainDialogue:SetVisible(false)
	ModalManager:SetModal(false)

	-- Corner dialogue that never blocks input
	local tutorialDialogue = DialogueView.new()
	tutorialDialogue:SetUser(Netmap.TutorialCallout.User, Netmap.TutorialCallout.Image)
	tutorialDialogue:SetTutorial()
	tutorialDialogue:SetVisible(true)
	tutorialDialogue:GetGui().Parent = container

	tutorialDialogue:SetText("Jack into the smart HQ node.")
	netmapView:HighlightNode('hq')
	netmapView:TutorialPointAtNode('hq')
	while netmapView.NodeSelected:wait() ~= 'hq' do
	end
	netmapView:ClearTutorialPointer()

	----------------------------------------------------------------------
	-- The guided databattle
	----------------------------------------------------------------------

	local placeData = Places.tutorial
	local gameState = GameState.new(placeData, LocalPlayerData:GetProgramList(), GameState.ClientDelayFunc)
	local gameController = GameController.new(gameState)
	local gameView = GameView.new(gameState, gameController, mainMenu, topbar)
	topbar:SetOnStart(function()
		gameController:StartGame()
	end)
	topbar:SetCreditsVisible(false)

	tutorialDialogue:GetGui().Parent = gameView:getGui()

	gameView:getGui().Position = UDim2.new(0.5, 0, 0.5, 0)
	gameView:getGui().Parent = container
	netmapView:GetGui().Visible = false
	SoundManager:Stop('MainBackgroundLoop')

	local function waitForClick(x, y)
		gameView:SetOnlyAllowClick(x, y)
		gameView:ShowTutorialArrowSquare(x, y)
		gameView.SquareSelected:wait()
		gameView:ClearTutorialArrow()
		gameView:SetOnlyAllowClick(0, 0)
	end

	local function waitForCommand(id)
		wait()
		gameView:SetOnlyAllowCommand(id)
		gameView:ShowTutorialArrowCommand(id)
		gameView.CommandSelected:wait()
		gameView:ClearTutorialArrow()
		gameView:SetOnlyAllowCommand('invalid')
	end

	gameController:SetStartEndEnabled(false)
	gameView:DisableAutoSelection()
	gameView:SetOnlyAllowCommand('invalid')
	gameView:ClearSelection()
	gameView:SetOnlyAllowClick(0, 0)

	-- Upload phase (drag-drop; the gliding hand demo is the pointer, an
	-- arrow on the upload zone on top of it is too much at once)
	tutorialDialogue:SetText("This is a databattle: your scripts against the node's defenses. Drag the Hack script onto the upload spot.")
	gameView:SetOnlyAllowUpload(4, 5)
	gameView:ShowTutorialArrowProgramList('hack')
	gameView:ShowDragDemo('hack', 4, 5)
	gameState.UnitAdded:wait()
	gameView:ClearDragDemo()
	gameView:ClearTutorialArrow()
	tutorialDialogue:SetText("One more: drag Slingshot onto the next spot.")
	gameView:SetOnlyAllowUpload(3, 3)
	gameView:ShowTutorialArrowProgramList('slingshot')
	gameView:ShowDragDemo('slingshot', 3, 3)
	gameState.UnitAdded:wait()
	gameView:ClearDragDemo()
	gameView:ClearTutorialArrow()
	gameView:SetOnlyAllowUpload(nil)
	tutorialDialogue:SetText("Hit the start button when you're ready.")
	gameController:SetStartEndEnabled(true)
	gameView:ShowTutorialArrowStartGame()
	gameState.TurnChanged:wait()
	gameController:SetStartEndEnabled(false)
	gameView:ClearTutorialArrow()
	gameView:ClearSelection()

	-- First script: select, move in, attack
	tutorialDialogue:SetText("All your scripts act first, then the enemy's. Click your Hack script to select it.")
	waitForClick(4, 5)
	tutorialDialogue:SetText("The highlighted squares show where it can move. Move here.")
	waitForClick(5, 5)
	tutorialDialogue:SetText("Scripts stretch out as they move. Each square is a sector, up to the script's max size. One more move: click here.")
	waitForClick(6, 5)
	-- Select the attack for the player; making them click Slice here feels bad
	gameView:TutorialSelectCommand('slice')
	tutorialDialogue:SetText("In range! Click the enemy script to attack.")
	waitForClick(7, 5)

	-- Second script: teach command selection explicitly with the ranged attack
	tutorialDialogue:SetText("Direct hit! Now your Slingshot: click it.")
	waitForClick(3, 3)
	tutorialDialogue:SetText("Move it up.")
	waitForClick(4, 3)
	tutorialDialogue:SetText("Slingshot attacks at range. Its commands are listed on the left: pick Stone.")
	waitForCommand('stone')
	tutorialDialogue:SetText("Finish it off: click the enemy script.")
	waitForClick(7, 3)

	-- Let the win land, then back to the netmap. (Poll rather than wait on
	-- GameEnded: it fires during the final attack's click processing, before
	-- this coroutine has woken from the last waitForClick.)
	while not gameState:HasWon() do
		wait()
	end
	tutorialDialogue:SetText("")
	wait(1.2)

	tutorialDialogue:Destroy()
	gameView:Destroy()
	topbar:SetStartVisible(false)
	topbar:SetUndoVisible(false)
	topbar:SetOnStart(nil)
	topbar:SetOnUndo(nil)
	topbar:SetCreditsVisible(true)
	netmapView:GetGui().Visible = true
	-- Land the camera on the node that was just beaten
	netmapView:HighlightNode('hq')
	SoundManager:Play('MainBackgroundLoop')

	if onBattleWon then
		onBattleWon()
	end

	----------------------------------------------------------------------
	-- One wrap-up box about the netmap
	----------------------------------------------------------------------

	ModalManager:SetModal(true)
	mainDialogue:SetVisible(true)
	mainDialogue:ExecuteConversation(Netmap.PostTutorialConversation)
	mainDialogue:SetVisible(false)
	ModalManager:SetModal(false)

	mActive = false
end

return Tutorial
