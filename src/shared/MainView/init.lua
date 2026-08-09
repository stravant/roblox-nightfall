local GameState = require(game.ReplicatedStorage.GameState)
local GameController = require(game.ReplicatedStorage.GameController)
local GameView = require(game.ReplicatedStorage.GameView)
local NetmapView = require(game.ReplicatedStorage.NetmapView)
local Netmap3DView = require(game.ReplicatedStorage.Netmap3DView)
local UnitInfoView = require(game.ReplicatedStorage.UnitInfoView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local Places = require(game.ReplicatedStorage.Places)
local Netmap = require(game.ReplicatedStorage.Netmap)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DialogueView = require(game.ReplicatedStorage.DialogueView)
local WarezView = require(game.ReplicatedStorage.WarezView)
local Scripts = require(game.ReplicatedStorage.Scripts)
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)
local MainMenuView = require(game.ReplicatedStorage.MainMenuView)
local ModalManager = require(game.ReplicatedStorage.ModalManager)

local UserInputService = game:GetService('UserInputService')

local UglyTutorialNonsense = require(script.UglyTutorialNonsense)

local MainView = {}

function MainView.getSize()
	local Mouse = game.Players.LocalPlayer:GetMouse()
	--if UserInputService.TouchEnabled then
	--return UDim2.new(0, math.min(800, Mouse.ViewSizeX), 0, math.min(600, Mouse.ViewSizeY + 2*ExtraY))
	return UDim2.new(1, 0, 1, 0)
end

function MainView.new()
	local this = {}
	
	-- Make root GUI
	local mGui = Instance.new('Frame')
	mGui.BackgroundColor3 = Color3.new(0, 0, 0)
	mGui.Size = MainView.getSize()
	mGui.Position = UDim2.new(0.5, 0, 0.5, 0)
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.BorderSizePixel = 0
	mGui.BackgroundTransparency = 1
	function this:GetGui()
		return mGui
	end
	
	-- Make menu
	local mMainMenu = MainMenuView.new(mGui)
	local mMenuButton = script.MenuButton:Clone()
	WindowsButton.new(mMenuButton)
	mMenuButton.Parent = mGui
	mMenuButton.MouseButton1Click:connect(function()
		mMainMenu:Show()
	end)
	
	-- Make netmap
	local mNetmapView = Netmap3DView.new()
	mNetmapView:GetGui().Position = UDim2.new(0.5, 0, 0.5, 0)
	mNetmapView:GetGui().Parent = mGui
	mNetmapView:SetVisible(true)

	-- Give the netmap a unitInfoView
	local mUnitInfo = UnitInfoView.new(mNetmapView:GetGui(), LocalPlayerData:GetProgramList())
	mUnitInfo:SetProgramListVisible(false)
	mUnitInfo:ClearSelectedUnit()
	
	-- Dialogue
	local mDialogue = DialogueView.new()
	mDialogue:SetVisible(false)
	mDialogue:GetGui().Parent = mGui
	
	-- Setup events
	mNetmapView.NodeSelected:connect(function(nodeId)
		if LocalPlayerData:CanAccessNode(nodeId) then
			local node = Netmap.ById[nodeId]
			if node.Id == 'hq' then
				-- Special behavior
				mMainMenu:Show()
				
			elseif node.Warez then
				-- Visit warez node
				this:VisitWarez(nodeId)
			else
				-- Do the battle
				this:PlayGame(node.PlaceId, nodeId)
			end
		end
	end)
	
	-- Warez node
	function this:VisitWarez(nodeId)
		ModalManager:SetModal(true)
		this:ProcessWonBattle(nodeId, 0) -- make it visible / beaten
		
		-- Show the GUI and handle the events for it
		local warezGui = WarezView.new(nodeId, Netmap.ById[nodeId].Warez)
		local purchaseConnection = warezGui.MadePurchase:connect(function(id)
			mNetmapView:UpdateCreditDisplay()
			this:ShowNotification("Acquired program "..Scripts[id].Name)
		end)
		local doneConnection;
		doneConnection = warezGui.Done:connect(function()
			warezGui:GetGui().Parent = nil
			purchaseConnection:Disconnect()
			doneConnection:Disconnect()
			ModalManager:SetModal(false)
		end)
		warezGui:GetGui().Parent = mGui
	end
	
	-- Play the tutorial dialogue and tutorial
	function this:PlayTutorial()
		UglyTutorialNonsense:PlayTutorial(mGui, mNetmapView, mDialogue)
		this:ProcessWonBattle('hq', 1000)
		game.ReplicatedStorage.Remotes.BeatTutorial:FireServer()
	end
	
	-- Play a game at a place
	function this:PlayGame(placeId, nodeId)
		ModalManager:SetModal(true)
		local placeData = Places[placeId]
		if not placeData then
			error("Missing place "..placeId)
		end
		local gameState = GameState.new(placeData, LocalPlayerData:GetProgramList(), GameState.ClientDelayFunc)
		local gameController = GameController.new(gameState)		
		local gameView = GameView.new(gameState, gameController)
		
		-- Restore the main state when the game is over
		local gameCompletedConnection;
		gameCompletedConnection = gameView.CloseGame:connect(function(didWin, replay, didStart)
			mNetmapView:SetVisible(true)
			SoundManager:Play('MainBackgroundLoop')
			gameView:Destroy()
			
			-- Did we win?
			if didWin then
				this:ProcessWonBattle(nodeId, gameState:GetCreditsEarned())
			end
			gameCompletedConnection:Disconnect()
			ModalManager:SetModal(false)
		end)
		
		gameView:getGui().Position = UDim2.new(0.5, 0, 0.5, 0)
		gameView:getGui().Parent = mGui
		mNetmapView:SetVisible(false)
		SoundManager:Stop('MainBackgroundLoop')
	end
	
	-- We won a battle, process the node revealing, and
	-- play through the win-triggers for that node
	function this:ProcessWonBattle(nodeId, creditsCollected)
		-- Get credits
		LocalPlayerData:AddCredits(creditsCollected)
		mNetmapView:UpdateCreditDisplay()
		
		-- Did we already beat this node?
		if LocalPlayerData:HasBeatenNode(nodeId) then
			return -- Don't update the node or play the win triggers again
		end		
		
		-- Update the state
		LocalPlayerData:SetNodeBeaten(nodeId)
		mNetmapView:SetNodeBeaten(nodeId)
		
		-- Handle the win-triggers
		local conversation = Netmap.ById[nodeId].Conversation
		if conversation then
			-- Show it
			ModalManager:SetModal(true)
			mDialogue:SetVisible(true)
			mDialogue:ExecuteConversation(conversation)
			mDialogue:SetVisible(false)
			ModalManager:SetModal(false)
			
			-- Process the result
			if conversation.Function then
				local f = conversation.Function
				if f.Type == 'revealNode' then
					LocalPlayerData:RevealNode(f.Id)
					mNetmapView:SetNodeVisible(f.Id)
					mNetmapView:HighlightNode(f.Id)
				elseif f.Type == 'upgradeSecurity' then
					LocalPlayerData:SetSecurityLevel(f.Level)
					-- We need to call again to make sure that the nodes that are now accessible appear that way
					mNetmapView:SetNodeBeaten(nodeId)
					this:ShowNotification("Upgraded security level to "..f.Level)
				elseif f.Type == 'getProgram' then
					LocalPlayerData:AddUnit(f.Id)
					this:ShowNotification("Received program: "..Scripts[f.Id].Name)
				elseif f.Type == 'getCredits' then
					LocalPlayerData:AddCredits(f.Amount)
					mNetmapView:UpdateCreditDisplay()
					this:ShowNotification("Received credits: "..f.Amount)
				elseif f.Type == 'beginNightfall' then
					LocalPlayerData:SetSecurityLevel(5)
					mNetmapView:SetNodeBeaten('ph45') -- Special case, do this to show the access to the boss node
					-- TODO:
				elseif f.Type == 'endNightfall' then
					-- TODO:
				else
					error("Bad function type: "..tostring(f.Type))
				end
			end
		end
	end
	
	local NotificationBoxTween = TweenInfo.new(1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, true)
	function this:ShowNotification(text)
		local box = script.NotificationBox:Clone()
		box.Inset.Content.Text = text
		box.Parent = mNetmapView:GetGui()
		local TweenService = game:GetService('TweenService')
		local inAnim = TweenService:Create(box, NotificationBoxTween, {
			Position = UDim2.new(1, -24, 1, -10);
		})
		inAnim:Play()
		inAnim.Completed:connect(function()
			box:Destroy()
		end)
	end
	
	SoundManager:Play('MainBackgroundLoop')
	
	local function handleError(title, body)
		local gui = script.ErrorBox:Clone()
		gui.Content.Text = title.."\n"..body
		gui.CloseButton.MouseButton1Click:connect(function()
			gui:Destroy()
		end)
		gui.Parent = mGui
	end
	game:GetService('LogService').MessageOut:connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageError then
			handleError("A CLIENT ERROR OCURRED - Please screenshot this and send it to Stravant", message)
		end
	end)
	game.ReplicatedStorage.Remotes.ServerError.OnClientEvent:connect(function(message)
		handleError("A SERVER ERROR OCURRED - Please screenshot this and send it to Stravant", message)
	end)
	
	if not LocalPlayerData:HasBeatenNode('hq') then
		spawn(function()
			this:PlayTutorial()
		end)
	end
	
	return this
end

return MainView
