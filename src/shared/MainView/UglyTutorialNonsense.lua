local Places = require(game.ReplicatedStorage.Places)
local Netmap = require(game.ReplicatedStorage.Netmap)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local GameState = require(game.ReplicatedStorage.GameState)
local GameController = require(game.ReplicatedStorage.GameController)
local GameView = require(game.ReplicatedStorage.GameView)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DialogueView = require(game.ReplicatedStorage.DialogueView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

local UglyTutorialNonsense = {}

function UglyTutorialNonsense:PlayTutorial(container, netmapView, mainDialogue)
	if not DebugFlags:PlayTutorial() then
		return
	end
	
	ModalManager:SetModal(true)
	mainDialogue:SetVisible(true)
	mainDialogue:ExecuteConversation(Netmap.PreTutorialConversation)
	mainDialogue:SetVisible(false)
	ModalManager:SetModal(false)

	local placeData = Places.tutorial
	local gameState = GameState.new(placeData, LocalPlayerData:GetProgramList(), GameState.ClientDelayFunc)
	local gameController = GameController.new(gameState)		
	local gameView = GameView.new(gameState, gameController)
	
	local inGameDialogue = DialogueView.new()
	inGameDialogue:SetUser(Netmap.PreTutorialConversation.User, Netmap.PreTutorialConversation.Image)
	inGameDialogue:SetVisible(true)
	inGameDialogue:SetTutorial()
	inGameDialogue:GetGui().Parent = gameView:getGui()
	
	gameView:getGui().Position = UDim2.new(0.5, 0, 0.5, 0)
	gameView:getGui().Board.AnchorPoint = Vector2.new(0, 0)
	gameView:getGui().Board.Position = UDim2.new(0, 160, 0, 10)
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
	inGameDialogue:SetText("Welcome to your first databattle. Here you scripts duke it out with the enemy scripts for control of a node.", "Tell me more.")
	inGameDialogue.OptionSelected:wait()
	inGameDialogue:SetText("First you have to upload your scripts. Start by clicking on this upload spot.")
	waitForClick(4, 5) -- hack
	inGameDialogue:SetText("Now click on this script to upload it.")
	gameView:ShowTutorialArrowProgramList('hack')
	gameState.UnitAdded:wait()
	inGameDialogue:SetText("Now click the next upload spot.")
	waitForClick(3, 3)
	inGameDialogue:SetText("Now upload this script.")
	gameView:ShowTutorialArrowProgramList('slingshot')
	gameState.UnitAdded:wait()
	inGameDialogue:SetText("Alright. Let's get this battle started.")
	gameController:SetStartEndEnabled(true)
	gameView:ShowTutorialArrowStartGame()
	gameState.TurnChanged:wait()
	gameController:SetStartEndEnabled(false)
	gameView:ClearTutorialArrow()
	gameView:ClearSelection()
	inGameDialogue:SetText("All of your scripts move and execute commands first, and then all of the enemy scripts get their chance.", "Next")
	inGameDialogue.OptionSelected:wait()
	inGameDialogue:SetText("First click on this script to select it.")
	waitForClick(4, 5)
	inGameDialogue:SetText("The highlighted grid squares show how far this script can move. Before we move it, let's see what it can do. Hack is a simple battle script with only one command. Click on the command to show its range.")
	waitForCommand('slice')
	inGameDialogue:SetText("The red squares show you the range for this command. This script has to move next to an enemy script to attack, so let's move it first. Click on move to cancel go back to moving the script.")
	waitForCommand('move')
	inGameDialogue:SetText("Now click on this square to move the script.")
	waitForClick(5, 5)
	inGameDialogue:SetText("When a script moves through memory, it expands. Each square of a script is called a sector. The max size shows how much a script will expand as it moves. When a script reaches its max size, it can still move but the older sectors will disappear.", "Next")
	inGameDialogue.OptionSelected:wait()
	inGameDialogue:SetText("We're still out of range. Click this square to move the script again.")
	waitForClick(6, 5)
	inGameDialogue:SetText("Okay, now that we're next to the script, let's use the attack command. Click the command button.")
	waitForCommand('slice')
	inGameDialogue:SetText("To execute an attack command, click on any sector of an enemy script that is within range. Click here to execute this command.")
	waitForClick(7, 5)
	inGameDialogue:SetText("Kapow! Now, let's move our other script, click here to select it.")
	waitForClick(3, 3)
	inGameDialogue:SetText("Move the script closer to your target.")
	waitForClick(4, 3)
	inGameDialogue:SetText("Slingshot is a ranged attack script. I think we're in range now. Click on the command to activate it.")
	waitForCommand('stone')
	inGameDialogue:SetText("Good. Now click on the enemy script to execute the command.")
	waitForClick(7, 3)
	inGameDialogue:SetText("Way to go. You just won your first databattle!", "Next")
	inGameDialogue.OptionSelected:wait()
	inGameDialogue:SetText("Of course, most databattles won't be as easy as this one. You'll need to pick up more powerful scripts from warez nodes on the network. Some advanced scripts have more than one command. Special scripts can be used to increase the power of your own scripts or even change the grid.", "Next")
	inGameDialogue.OptionSelected:wait()
	inGameDialogue:SetText("Ok, those are the basics. When you get back to the netmap, you'll be on your own. Click a node and see what you can find out there. Good luck!", "Done")
	inGameDialogue.OptionSelected:wait()

	gameView:Destroy()
	netmapView:GetGui().Visible = true
	SoundManager:Play('MainBackgroundLoop')
end

return UglyTutorialNonsense
