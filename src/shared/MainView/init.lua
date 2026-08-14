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
local OnboardingSteps = require(game.ReplicatedStorage.OnboardingSteps)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local UserInputService = game:GetService('UserInputService')
local SocialService = game:GetService('SocialService')

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

	-- Topbar-inset gui: the Menu button lives in the top bar (top right), and
	-- during a databattle the current node's name shows in a bar beside it
	local mTopbarGui = Instance.new("ScreenGui")
	mTopbarGui.Name = "NightfallTopbar"
	mTopbarGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	mTopbarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mTopbarGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Shared label for the topbar buttons: bold, properly centered (the old
	-- Code font sat visibly off-center vertically)
	local function topbarButtonLabel(text)
		return e("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 18,
			TextColor3 = Color3.new(0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = text,
		})
	end
	-- The feedback prompt yields until dismissed; one at a time
	local mFeedbackPrompting = false
	local mTopbarRoot = StatefulRoot.create(mTopbarGui, function(props)
		-- One flex row: the node-name title sizes to its content on the left,
		-- Start Databattle / Done Turn float centered between the two fill
		-- spacers, and the Menu button sits at the right
		return e("Frame", {
			Name = "TopbarRow",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			-- The row must never be taller than the topbar strip: with all
			-- CoreGui disabled the live client can hand the TopbarSafeInsets
			-- ScreenGui full-viewport bounds (Studio always reports the 58px
			-- strip), and the centered flex row would float mid-screen
			UISizeConstraint = e("UISizeConstraint", {
				MaxSize = Vector2.new(math.huge, 58),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			BattleTitle = if props.battleTitle
				then e("TextLabel", {
					-- Solid Win95 title-bar blue; the whole bar is the title
					LayoutOrder = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 38),
					BackgroundColor3 = Color3.fromRGB(0, 0, 128),
					BorderSizePixel = 0,
					Font = Enum.Font.SourceSansBold,
					TextSize = 20,
					TextColor3 = Color3.new(1, 1, 1),
					Text = props.battleTitle,
				}, {
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					}),
				})
				else nil,
			SpacerLeft = e("Frame", {
				LayoutOrder = 2,
				Size = UDim2.new(0, 0, 0, 1),
				BackgroundTransparency = 1,
			}, {
				UIFlexItem = e("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			}),
			AutoPlaceButton = if props.autoPlaceVisible
				then e(WindowsButton, {
					Name = "AutoPlaceButton",
					LayoutOrder = 3,
					Size = UDim2.new(0, 110, 0, 36),
					OnClick = props.onAutoPlaceClick,
				}, {
					TextLabel = topbarButtonLabel("Auto Place"),
				})
				else nil,
			StartGameButton = if props.startVisible
				then e("TextButton", {
					Name = "StartGameButton",
					LayoutOrder = 3,
					Active = true,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 36),
					BackgroundColor3 = Color3.new(0.701961, 0, 0),
					Font = Enum.Font.SourceSansBold,
					TextSize = 19,
					TextColor3 = Color3.new(1, 1, 1),
					Text = "Start Databattle",
					[React.Event.MouseButton1Click] = function()
						if props.onStartClick then
							props.onStartClick()
						end
					end,
				}, {
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
					}),
				})
				else nil,
			LeaveButton = if props.leaveVisible
				then e(WindowsButton, {
					Name = "LeaveButton",
					LayoutOrder = 4,
					Size = UDim2.new(0, 90, 0, 36),
					OnClick = props.onLeaveClick,
				}, {
					TextLabel = topbarButtonLabel("Leave"),
				})
				else nil,
			UndoButton = if props.undoVisible
				then e(WindowsButton, {
					Name = "UndoButton",
					LayoutOrder = 3,
					Size = UDim2.new(0, 90, 0, 36),
					OnClick = props.onUndoClick,
				}, {
					TextLabel = topbarButtonLabel("Undo"),
				})
				else nil,
			DoneTurnButton = if props.doneTurnVisible
				then e(WindowsButton, {
					Name = "DoneTurnButton",
					LayoutOrder = 4,
					Size = UDim2.new(0, 130, 0, 36),
					OnClick = props.onDoneTurnClick,
				}, {
					TextLabel = topbarButtonLabel("Done Turn"),
				})
				else nil,
			SpacerRight = e("Frame", {
				LayoutOrder = 5,
				Size = UDim2.new(0, 0, 0, 1),
				BackgroundTransparency = 1,
			}, {
				UIFlexItem = e("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			}),
			CreditsDisplay = if props.creditsText and not props.creditsHidden
				then e("ImageLabel", {
					-- Auto-width chain: every level uses offset/automatic
					-- widths only (a scale-sized child inside an AutomaticSize
					-- parent measures circularly and overflows the chrome)
					Name = "CreditsDisplay",
					LayoutOrder = 6,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 36),
					BackgroundTransparency = 1,
					Image = "rbxassetid://1378189463",
					ImageRectOffset = Vector2.new(32, 0),
					ImageRectSize = Vector2.new(32, 48),
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(16, 24, 16, 24),
				}, {
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 5),
						PaddingRight = UDim.new(0, 5),
						PaddingTop = UDim.new(0, 5),
						PaddingBottom = UDim.new(0, 5),
					}),
					Inset = e("ImageLabel", {
						Name = "Inset",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.new(0, 0, 1, 0),
						BackgroundTransparency = 1,
						Image = "rbxassetid://1378143823",
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(8, 8, 8, 8),
					}, {
						UIPadding = e("UIPadding", {
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
						Text = e("TextLabel", {
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.new(0, 0, 1, -1),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSansBold,
							TextSize = 20,
							TextColor3 = Color3.fromRGB(0, 100, 0),
							Text = props.creditsText,
						}),
					}),
				})
				else nil,
			-- Netmap only (rides the credits' hidden flag, like the credits):
			-- opens Roblox's own feedback dialog, results in Creator
			-- Dashboard under Audience > Feedback. Only works in the
			-- published place, not Studio playtests.
			FeedbackButton = if not props.creditsHidden
				then e(WindowsButton, {
					Name = "FeedbackButton",
					LayoutOrder = 7,
					Size = UDim2.new(0, 120, 0, 36),
					OnClick = props.onFeedbackClick,
				}, {
					TextLabel = topbarButtonLabel("Give Feedback"),
				})
				else nil,
			MenuButton = e(WindowsButton, {
				Name = "MenuButton",
				LayoutOrder = 8,
				Size = UDim2.new(0, 110, 0, 36),
				OnClick = props.onMenuClick,
			}, {
				TextLabel = topbarButtonLabel("Menu"),
			}),
		})
	end, {
		battleTitle = nil,
		startVisible = false,
		autoPlaceVisible = false,
		leaveVisible = false,
		doneTurnVisible = false,
		undoVisible = false,
		creditsText = nil,
		creditsHidden = false,
		onStartClick = nil,
		onAutoPlaceClick = nil,
		onLeaveClick = nil,
		onDoneTurnClick = nil,
		onUndoClick = nil,
		onMenuClick = function()
			mMainMenu:Show()
		end,
		onFeedbackClick = function()
			if mFeedbackPrompting or ModalManager:IsModal() then
				return
			end
			mFeedbackPrompting = true
			task.spawn(function()
				local st, err = pcall(function()
					SocialService:PromptFeedbackSubmissionAsync()
				end)
				if not st then
					warn("MainView | Feedback prompt failed: " .. tostring(err))
				end
				mFeedbackPrompting = false
			end)
		end,
	})
	local function setBattleTitle(title)
		mTopbarRoot.setState({ battleTitle = title or StatefulRoot.None })
	end
	-- Interface handed to GameView so it can drive the topbar Start button
	local mTopbarBattleInterface = {}
	function mTopbarBattleInterface:SetStartVisible(visible)
		mTopbarRoot.setState({ startVisible = visible })
	end
	function mTopbarBattleInterface:SetOnStart(callback)
		mTopbarRoot.setState({ onStartClick = callback or StatefulRoot.None })
	end
	function mTopbarBattleInterface:SetAutoPlaceVisible(visible)
		mTopbarRoot.setState({ autoPlaceVisible = visible })
	end
	function mTopbarBattleInterface:SetOnAutoPlace(callback)
		mTopbarRoot.setState({ onAutoPlaceClick = callback or StatefulRoot.None })
	end
	function mTopbarBattleInterface:SetDoneTurnVisible(visible)
		mTopbarRoot.setState({ doneTurnVisible = visible })
	end
	function mTopbarBattleInterface:SetOnDoneTurn(callback)
		mTopbarRoot.setState({ onDoneTurnClick = callback or StatefulRoot.None })
	end
	function mTopbarBattleInterface:SetLeaveVisible(visible)
		mTopbarRoot.setState({ leaveVisible = visible })
	end
	function mTopbarBattleInterface:SetOnLeave(callback)
		mTopbarRoot.setState({ onLeaveClick = callback or StatefulRoot.None })
	end
	function mTopbarBattleInterface:SetUndoVisible(visible)
		mTopbarRoot.setState({ undoVisible = visible })
	end
	function mTopbarBattleInterface:SetOnUndo(callback)
		mTopbarRoot.setState({ onUndoClick = callback or StatefulRoot.None })
	end
	function mTopbarBattleInterface:SetCreditsVisible(visible)
		mTopbarRoot.setState({ creditsHidden = not visible })
	end
	function mTopbarBattleInterface:GetStartButton()
		return mTopbarGui:FindFirstChild("StartGameButton", true)
	end
	-- Interface handed to Netmap3DView so it can drive the credits display
	local mTopbarCredits = {
		SetText = function(text)
			mTopbarRoot.setState({ creditsText = text })
		end,
		GetInset = function()
			local display = mTopbarGui:FindFirstChild("CreditsDisplay", true)
			return display and display:FindFirstChild("Inset")
		end,
	}
	
	-- Make netmap
	local mNetmapView = Netmap3DView.new(mTopbarCredits)
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
		-- Onboarding funnel: found the shop (server dedupes)
		game.ReplicatedStorage.Remotes.FunnelStep:FireServer(OnboardingSteps.ShopVisited)
		ModalManager:SetModal(true)
		this:ProcessWonBattle(nodeId, 0) -- make it visible / beaten
		
		-- Show the GUI and handle the events for it
		local warezGui = WarezView.new(nodeId, Netmap.ById[nodeId].Warez)
		local purchaseConnection = warezGui.MadePurchase:connect(function(id)
			mNetmapView:UpdateCreditDisplay()
			this:ShowNotification("Acquired script "..Scripts[id].Name, Scripts[id])
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
		local ranTutorial = Tutorial:PlayTutorial(mGui, mNetmapView, mDialogue, mMainMenu, mTopbarBattleInterface, function()
			-- Mark hq beaten (reveals the adjacent nodes) before the wrap-up
			-- box tells the player to go click one
			this:ProcessWonBattle('hq', 1000)
			game.ReplicatedStorage.Remotes.BeatTutorial:FireServer()
		end)
		if ranTutorial then
			-- NOT part of the tutorial (it's complete): fresh graduates get
			-- one pointer at the first infected node so the next action is
			-- obvious, cleared the moment they select anything
			mNetmapView:TutorialPointAtNode('lm12')
			task.spawn(function()
				mNetmapView.NodeSelected:wait()
				mNetmapView:ClearTutorialPointer()
			end)
		end
	end
	
	-- Play a game at a place. initialPlacement (from the fail screen's Retry):
	-- a list of {x, y, Id} pre-placed on the upload zones without starting.
	function this:PlayGame(placeId, nodeId, initialPlacement)
		-- Onboarding funnel: entered a first real battle (server dedupes)
		game.ReplicatedStorage.Remotes.FunnelStep:FireServer(OnboardingSteps.NodeChosen)
		ModalManager:SetModal(true)
		local placeData = Places[placeId]
		if not placeData then
			error("Missing place "..placeId)
		end
		-- The node's entry track (nil for hq/warez nodes); the GameView holds
		-- its battle music until the track finishes. A Retry re-entry
		-- (initialPlacement set) skips the sting — they just heard it.
		local entrySound = if initialPlacement then nil else Netmap.ById[nodeId].Sound
		local gameState = GameState.new(placeData, LocalPlayerData:GetProgramList(), GameState.ClientDelayFunc)
		local gameController = GameController.new(gameState)
		local gameView = GameView.new(gameState, gameController, mMainMenu, mTopbarBattleInterface, entrySound)
		if initialPlacement then
			gameView:ApplyInitialPlacement(initialPlacement)
		end
		-- Snapshot the setup as the battle starts so a post-loss Retry can
		-- re-place the exact same units
		local startingPlacement = nil
		mTopbarBattleInterface:SetOnStart(function()
			startingPlacement = {}
			for _, zone in pairs(gameState:GetUploadZones()) do
				local unit = gameState:GetUnit(zone.x, zone.y)
				if unit then
					table.insert(startingPlacement, { x = zone.x, y = zone.y, Id = unit.Definition.Id })
				end
			end
			gameController:StartGame()
		end)
		mTopbarBattleInterface:SetOnDoneTurn(function()
			gameController:EndTurn()
		end)
		mTopbarBattleInterface:SetCreditsVisible(false)
		setBattleTitle(Netmap.GetNodeDisplayName(nodeId))
		gameView:SetMissionText(Netmap.ById[nodeId].Mission)
		
		-- Restore the main state when the game is over
		local gameCompletedConnection;
		gameCompletedConnection = gameView.CloseGame:connect(function(didWin, replay, didStart, skipped, retryRequested)
			setBattleTitle(nil)
			mTopbarBattleInterface:SetStartVisible(false)
			mTopbarBattleInterface:SetAutoPlaceVisible(false)
			mTopbarBattleInterface:SetLeaveVisible(false)
			mTopbarBattleInterface:SetDoneTurnVisible(false)
			mTopbarBattleInterface:SetUndoVisible(false)
			mTopbarBattleInterface:SetOnStart(nil)
			mTopbarBattleInterface:SetOnAutoPlace(nil)
			mTopbarBattleInterface:SetOnLeave(nil)
			mTopbarBattleInterface:SetOnDoneTurn(nil)
			mTopbarBattleInterface:SetOnUndo(nil)
			mTopbarBattleInterface:SetCreditsVisible(true)
			mNetmapView:SetVisible(true)
			if entrySound then
				SoundManager:Stop(entrySound) -- may still be playing on a quick leave
			end
			SoundManager:Play('MainBackgroundLoop')
			gameView:Destroy()
			
			-- Record local play statistics (skips and debug wins record
			-- nothing: only battles actually played through)
			if didStart and not skipped then
				if didWin then
					LocalPlayerData:RecordNodeCompletion(nodeId, gameState:GetPlayStats())
				else
					LocalPlayerData:RecordNodeAttempt(nodeId)
				end
			end

			-- Did we win?
			if didWin then
				this:ProcessWonBattle(nodeId, gameState:GetCreditsEarned())
			end
			gameCompletedConnection:Disconnect()
			ModalManager:SetModal(false)

			-- Fail screen Retry: straight back in with the same setup
			-- pre-placed (but not started, so it can be adjusted)
			if retryRequested and not didWin then
				this:PlayGame(placeId, nodeId, startingPlacement)
			end
		end)
		
		gameView:getGui().Position = UDim2.new(0.5, 0, 0.5, 0)
		gameView:getGui().Parent = mGui
		mNetmapView:SetVisible(false)
		SoundManager:Stop('MainBackgroundLoop')
		if entrySound then
			SoundManager:Play(entrySound)
		end
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
					this:ShowNotification("Received script: "..Scripts[f.Id].Name, Scripts[f.Id])
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
	-- ui-reference/ModuleTemplates/MainView.json). iconDef is an optional
	-- program definition (Image + Color) shown beside the text.
	local function makeNotificationBox(text, iconDef)
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
		if iconDef then
			local icon = Instance.new("ImageLabel")
			icon.Name = "Icon"
			icon.Position = UDim2.new(0, 4, 0, 4)
			icon.Size = UDim2.new(0, 32, 0, 32)
			icon.BackgroundColor3 = iconDef.Color
			icon.BorderColor3 = Color3.new(0, 0, 0)
			icon.Image = iconDef.Image
			icon.Parent = inset
		end
		local content = Instance.new("TextLabel")
		content.Name = "Content"
		content.Position = UDim2.new(0, if iconDef then 40 else 0, 0, 2)
		content.Size = UDim2.new(1, if iconDef then -42 else 0, 1, 0)
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
	function this:ShowNotification(text, iconDef)
		local box = makeNotificationBox(text, iconDef)
		-- Sibling of (and above) the modal views like the warez shop, so the
		-- notification isn't dimmed by their backdrops
		box.ZIndex = 10
		box.Parent = mGui
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
