-- The first-time-player tutorial (formerly UglyTutorialNonsense).
--
-- Design: get the player acting immediately and stay out of their way.
-- - One callout box on the netmap, then a non-blocking corner dialogue tells
--   them which node to plug into.
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
local OnboardingSteps = require(game.ReplicatedStorage.OnboardingSteps)
local JourneyRecorder = require(game.ReplicatedStorage.JourneyRecorder)

-- Onboarding funnel detail: best-effort, the server validates/dedupes
local function funnelStep(step)
	game.ReplicatedStorage.Remotes.FunnelStep:FireServer(step)
end

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
-- Returns true if the tutorial actually ran to completion
function Tutorial:PlayTutorial(container, netmapView, mainDialogue, mainMenu, topbar, onBattleWon)
	if not DebugFlags:PlayTutorial() then
		return false
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
	tutorialDialogue:SetUser(Netmap.TutorialCallout.User, Netmap.TutorialCallout.Image, Netmap.TutorialCallout.Color)
	tutorialDialogue:SetTutorial()
	tutorialDialogue:SetVisible(true)
	tutorialDialogue:GetGui().Parent = container

	tutorialDialogue:SetText("Plug into the smart HQ node.")
	netmapView:FocusOnNode('hq')
	netmapView:TutorialPointAtNode('hq')
	while netmapView.NodeSelected:wait() ~= 'hq' do
	end
	netmapView:ClearTutorialPointer()
	funnelStep(OnboardingSteps.TutorialEntered)

	----------------------------------------------------------------------
	-- The guided databattle
	----------------------------------------------------------------------

	-- Journey: the tutorial battle doesn't go through MainView:PlayGame, so
	-- record its own battle boundary events for playback
	JourneyRecorder:Record("BattleEnter", "hq (tutorial)")
	local placeData = Places.tutorial
	local gameState = GameState.new(placeData, LocalPlayerData:GetProgramList(), GameState.ClientDelayFunc)
	local gameController = GameController.new(gameState)
	local gameView = GameView.new(gameState, gameController, mainMenu, topbar)
	topbar:SetOnStart(function()
		JourneyRecorder:Record("BattleStart", "hq")
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

	-- Upload phase: guided clicks (click the spot, then the script). Funnel
	-- data showed a big drop-off when a guided drag was the only path — the
	-- drag was too precise an ask this early. A player who drags the script
	-- on their own found an equally valid path: accept it and move on. The
	-- scripts window hints "Drag to Place" until a zone is selected, then
	-- flips to "Click to Place" to match the guidance.
	local function placementStep(unitId, zoneX, zoneY, introText, placeText)
		local placed = false
		local placedCn = gameState.UnitAdded:connect(function()
			placed = true
		end)
		local clickedZone = false
		local clickedCn = gameView.SquareSelected:connect(function()
			clickedZone = true
		end)
		gameView:SetOnlyAllowUpload(zoneX, zoneY)
		tutorialDialogue:SetText(introText)
		gameView:SetOnlyAllowClick(zoneX, zoneY)
		gameView:ShowTutorialArrowSquare(zoneX, zoneY)
		-- Restrict drags to this step's script (a freestyle drag of the OTHER
		-- script would soft-lock the next step). AFTER the arrow: showing an
		-- arrow clears the restriction via TutorialHide.
		gameView:SetOnlyAllowProgram(unitId)
		while not placed and not clickedZone do
			wait()
		end
		gameView:ClearTutorialArrow() -- also drops the program restriction
		gameView:SetOnlyAllowClick(0, 0)
		if not placed then
			-- Zone selected: the scripts window is click-to-place from here on
			gameView:SetProgramsHintText("Click to Place")
			tutorialDialogue:SetText(placeText)
			gameView:ShowTutorialArrowProgramList(unitId)
			while not placed do
				wait()
			end
			gameView:ClearTutorialArrow()
		end
		placedCn:disconnect()
		clickedCn:disconnect()
		gameView:SetOnlyAllowUpload(nil)
	end

	placementStep('hack', 4, 5,
		"This is a databattle: your scripts against the node's defenses. Click the highlighted upload spot.",
		"Now click the Hack script to place it there.")
	funnelStep(OnboardingSteps.ScriptPlaced)
	placementStep('slingshot', 3, 3,
		"One more: click the next spot.",
		"And click Slingshot to place it.")
	tutorialDialogue:SetText("Hit the start button when you're ready.")
	gameController:SetStartEndEnabled(true)
	gameView:ShowTutorialArrowStartGame()
	gameState.TurnChanged:wait()
	funnelStep(OnboardingSteps.BattleStarted)
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
	funnelStep(OnboardingSteps.FirstAttack)

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

	JourneyRecorder:Record("BattleExit", "hq won (tutorial)")
	tutorialDialogue:Destroy()
	gameView:Destroy()
	topbar:SetStartVisible(false)
	topbar:SetLeaveVisible(false)
	topbar:SetUndoVisible(false)
	topbar:SetAutoPlaceVisible(false)
	topbar:SetOnStart(nil)
	topbar:SetOnLeave(nil)
	topbar:SetOnUndo(nil)
	topbar:SetOnAutoPlace(nil)
	topbar:SetCreditsVisible(true)
	netmapView:GetGui().Visible = true
	-- Land the camera on the node that was just beaten (no pointer arrow:
	-- there's nothing to do at a defeated node)
	netmapView:FocusOnNode('hq')
	SoundManager:Play('MainBackgroundLoop')

	if onBattleWon then
		onBattleWon()
	end

	----------------------------------------------------------------------
	-- One wrap-up box about the netmap
	----------------------------------------------------------------------

	ModalManager:SetModal(true)
	mainDialogue:SetVisible(true)
	local outcome = mainDialogue:ExecuteConversation(Netmap.PostTutorialConversation)
	mainDialogue:SetVisible(false)
	ModalManager:SetModal(false)

	mActive = false
	-- outcome: 'end:explore' or 'end:battle' (MainView routes the latter
	-- straight into the next fight)
	return true, outcome
end

return Tutorial
