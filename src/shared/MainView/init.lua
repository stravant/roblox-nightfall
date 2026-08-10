local GameState = require(game.ReplicatedStorage.GameState)
local GameController = require(game.ReplicatedStorage.GameController)
local GameView = require(game.ReplicatedStorage.GameView)
local Netmap3DView = require(game.ReplicatedStorage.Netmap3DView)
local UnitInfoView = require(game.ReplicatedStorage.UnitInfoView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local Places = require(game.ReplicatedStorage.Places)
local Netmap = require(game.ReplicatedStorage.Netmap)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DialogueView = require(game.ReplicatedStorage.DialogueView)
local WarezView = require(game.ReplicatedStorage.WarezView)
local Scripts = require(game.ReplicatedStorage.Scripts)
local MainMenuView = require(game.ReplicatedStorage.MainMenuView)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local UserInputService = game:GetService('UserInputService')

local Tutorial = require(script.Tutorial)

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
	-- The menu button renders via a portaled React root (mGui also holds the
	-- imperatively-parented netmap/dialogue/menu GUIs, and a plain root would
	-- clear them at mount)
	StatefulRoot.createPortaled(mGui, function(props)
		return e(WindowsButton, {
			Name = "MenuButton",
			Size = UDim2.new(0, 150, 0, 36),
			ZIndex = 4,
			OnClick = props.onMenuClick,
		}, {
			TextLabel = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 25, 0.5, 0),
				Size = UDim2.new(1, -50, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextSize = 20,
				TextColor3 = Color3.new(0, 0, 0),
				Text = "Menu",
			}),
		})
	end, {
		onMenuClick = function()
			mMainMenu:Show()
		end,
	})
	
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
		-- While the tutorial runs it owns node clicks
		if Tutorial:IsActive() then
			return
		end
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
		Tutorial:PlayTutorial(mGui, mNetmapView, mDialogue, mMainMenu, function()
			-- Mark hq beaten (reveals the adjacent nodes) before the wrap-up
			-- box tells the player to go click one
			this:ProcessWonBattle('hq', 1000)
			game.ReplicatedStorage.Remotes.BeatTutorial:FireServer()
		end)
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
		local gameView = GameView.new(gameState, gameController, mMainMenu)
		
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
	
	-- Replacement for the old script.NotificationBox template clone (see
	-- ui-reference/ModuleTemplates/MainView.json)
	local function makeNotificationBox(text)
		local box = Instance.new("ImageLabel")
		box.Name = "NotificationBox"
		box.AnchorPoint = Vector2.new(1, 1)
		box.Position = UDim2.new(1, -24, 1, 120)
		box.Size = UDim2.new(0, 120, 0, 120)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 2
		box.Image = "rbxassetid://1378189463"
		box.ImageRectOffset = Vector2.new(32, 0)
		box.ImageRectSize = Vector2.new(32, 48)
		box.ScaleType = Enum.ScaleType.Slice
		box.SliceCenter = Rect.new(16, 24, 16, 24)
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.AnchorPoint = Vector2.new(0, 0.5)
		title.Position = UDim2.new(0, 6, 0, 12)
		title.Size = UDim2.new(0, 200, 0, 30)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = 14
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Notification"
		title.Parent = box
		local inset = Instance.new("ImageLabel")
		inset.Name = "Inset"
		inset.Position = UDim2.new(0, 5, 0, 25)
		inset.Size = UDim2.new(1, -10, 1, -29)
		inset.BackgroundTransparency = 1
		inset.Image = "rbxassetid://1378143823"
		inset.ScaleType = Enum.ScaleType.Slice
		inset.SliceCenter = Rect.new(8, 8, 8, 8)
		inset.Parent = box
		local content = Instance.new("TextLabel")
		content.Name = "Content"
		content.Position = UDim2.new(0, 0, 0, 2)
		content.Size = UDim2.new(1, 0, 1, 0)
		content.BackgroundTransparency = 1
		content.Font = Enum.Font.SourceSans
		content.TextSize = 18
		content.TextColor3 = Color3.new(0, 0, 0)
		content.TextWrapped = true
		content.TextYAlignment = Enum.TextYAlignment.Top
		content.Text = text
		content.Parent = inset
		return box
	end

	local NotificationBoxTween = TweenInfo.new(1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, true)
	function this:ShowNotification(text)
		local box = makeNotificationBox(text)
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
	
	-- Replacement for the old script.ErrorBox template clone (see
	-- ui-reference/ModuleTemplates/MainView.json)
	local function handleError(title, body)
		local gui = Instance.new("ImageLabel")
		gui.Name = "ErrorBox"
		gui.Size = UDim2.new(0, 600, 0, 400)
		gui.ZIndex = 3
		gui.BackgroundTransparency = 1
		gui.BorderSizePixel = 2
		gui.Image = "rbxassetid://1353265347"
		gui.ScaleType = Enum.ScaleType.Slice
		gui.SliceCenter = Rect.new(32, 32, 32, 32)
		local content = Instance.new("TextLabel")
		content.Name = "Content"
		content.AnchorPoint = Vector2.new(0.5, 0.5)
		content.Position = UDim2.new(0.5, 0, 0.5, 0)
		content.Size = UDim2.new(1, -38, 1, -36)
		content.BackgroundTransparency = 1
		content.Font = Enum.Font.SourceSans
		content.TextSize = 14
		content.TextColor3 = Color3.new(0, 1, 0.968628)
		content.TextStrokeTransparency = 0
		content.TextWrapped = true
		content.TextXAlignment = Enum.TextXAlignment.Left
		content.TextYAlignment = Enum.TextYAlignment.Top
		content.Text = title.."\n"..body
		content.Parent = gui
		local closeButton = Instance.new("TextButton")
		closeButton.Name = "CloseButton"
		closeButton.AnchorPoint = Vector2.new(1, 0)
		closeButton.Position = UDim2.new(1, -10, 0, 10)
		closeButton.Size = UDim2.new(0, 32, 0, 32)
		closeButton.BackgroundColor3 = Color3.new(0, 0.8, 0.294118)
		closeButton.BorderColor3 = Color3.new(0.819608, 0, 0.0117647)
		closeButton.BorderSizePixel = 2
		closeButton.Font = Enum.Font.SourceSansBold
		closeButton.TextSize = 24
		closeButton.TextColor3 = Color3.new(0.784314, 0, 0.0117647)
		closeButton.Text = "X"
		closeButton.Parent = gui
		closeButton.MouseButton1Click:connect(function()
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
