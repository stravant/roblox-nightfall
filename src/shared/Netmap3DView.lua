local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(game.ReplicatedStorage.Signal)
local Netmap = require(game.ReplicatedStorage.Netmap)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local Scrollbar = require(game.ReplicatedStorage.ScrollingFrame)
local TutorialArrow = require(game.ReplicatedStorage.TutorialArrowView)
local NetmapCamera = require(game.ReplicatedStorage.NetmapCamera)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)

local e = React.createElement

local Netmap3DView = {}

-- The GUI overlay (formerly the script.Netmap template; see
-- ui-reference/ModuleTemplates/Netmap3DView.json). Only the credit display is
-- dynamic; the transient credit delta text stays imperative because it's a
-- fire-and-forget TweenPosition animation.
local function NetmapOverlayContent(props)
	return e("ImageLabel", {
		Name = "CreditDisplay",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 10),
		Size = UDim2.new(0, 120, 0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 2,
		Image = "rbxassetid://1378189463",
		ImageRectOffset = Vector2.new(32, 0),
		ImageRectSize = Vector2.new(32, 48),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(16, 24, 16, 24),
	}, {
		Title = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0, 12),
			Size = UDim2.new(0, 200, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Credits",
		}),
		Inset = e("ImageLabel", {
			Position = UDim2.new(0, 5, 0, 25),
			Size = UDim2.new(1, -10, 1, -29),
			BackgroundTransparency = 1,
			Image = "rbxassetid://1378143823",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(8, 8, 8, 8),
		}, {
			Text = e("TextLabel", {
				Position = UDim2.new(0, 4, 0, 0),
				Size = UDim2.new(1, -7, 1, -1),
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextSize = 20,
				TextColor3 = Color3.new(0, 0, 0),
				TextStrokeColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.9,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = props.creditsText,
			}),
		}),
	})
end

-- Replacement for the old script.CreditUpdateText template clone
local function makeCreditUpdateText()
	local text = Instance.new("TextLabel")
	text.Name = "CreditUpdateText"
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 4, 0, 0)
	text.Size = UDim2.new(1, -7, 1, -1)
	text.Font = Enum.Font.Code
	text.TextSize = 20
	text.TextColor3 = Color3.new(1, 0, 0.0156863)
	text.TextStrokeColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Right
	return text
end

local NETMAP_NODE_MODELS = workspace.Nodes
NETMAP_NODE_MODELS.Parent = nil
for _, ch in pairs(NETMAP_NODE_MODELS:GetChildren()) do
	ch.Base:Destroy()
end

local NOT_BEATEN_COLLISION_GROUP = PhysicsService:GetCollisionGroupId("NotBeatenGlow")

function Netmap3DView.new()
	local this = {}
	
	local mNetmapModel = workspace.Netmap

	this.NodeSelected = Signal.new()
	
	local mGui = Instance.new("Frame")
	mGui.Name = "Netmap"
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.Position = UDim2.new(0, 6, 0, 0)
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundTransparency = 1
	mGui.Selectable = true
	mGui.ZIndex = 3
	local mGuiRoot = StatefulRoot.create(mGui, NetmapOverlayContent, {
		creditsText = "",
	})
	
	local mNotBeatenGlowContainer = Instance.new('Folder', workspace)
	local mConnectionsContainer = Instance.new('Folder', workspace)
	
	local mNodeModelToNodeIdMap = {}
	
	local updateHoveredNode;
	
	local function getUnitRay()
		local mouseAt = UserInputService:GetMouseLocation()
		return workspace.CurrentCamera:ViewportPointToRay(mouseAt.X, mouseAt.Y)
	end
	
	local function getHoveredNodeId(unitRay)
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000)
		if result then
			local nodeModel = result.Instance.Parent
			if mNodeModelToNodeIdMap[nodeModel] then
				return mNodeModelToNodeIdMap[nodeModel]
			end
		end
	end
	
	local mCamera = NetmapCamera.new()
	mCamera.Clicked:connect(function(unitRay)
		if not mGui.Visible or not mGui.Parent then
			return
		end
		if ModalManager:IsModal() then
			return
		end
		
		local id = getHoveredNodeId(unitRay)
		if id then
			SoundManager:Play'SelectNode'
			this.NodeSelected:fire(id)
			-- Do this so that the hover immediately hides when we click on something
			-- interesting
			updateHoveredNode()
		end
	end)
	
	local mNodeView = {}
	
	local function setupNetmap()
		for _, ch in pairs(mNetmapModel:GetChildren()) do
			local id = ch.Name
			local cf = ch:GetPivot()
			local visibleModel = NETMAP_NODE_MODELS[id:sub(1, 2)]:Clone()
			visibleModel:PivotTo(cf)
			local disabledModel = NETMAP_NODE_MODELS[id:sub(1, 2)..'_disabled']:Clone()
			local unknownModel = NETMAP_NODE_MODELS['unknown']:Clone()
			unknownModel:PivotTo(cf)
			disabledModel:PivotTo(cf)
			mNodeModelToNodeIdMap[visibleModel] = id
			mNodeModelToNodeIdMap[disabledModel] = id
			mNodeView[id] = {
				Id = id;
				CFrame = cf;
				Model = disabledModel;
				VisibleModel = visibleModel;
				DisabledModel = disabledModel;
				UnknownModel = unknownModel;
			}
			ch:Destroy()
		end
	end
	
	local function setupLink(nodeView, adjId)
		local adjNodeView = mNodeView[adjId]
		if not adjNodeView then
			warn("Missing adjacent node:", adjId)
			return
		end
		
		local dir = adjNodeView.CFrame.Position - nodeView.CFrame.Position
		local orientation = CFrame.fromMatrix(Vector3.new(), Vector3.new(0, 1, 0), dir:Cross(Vector3.new(0, 1, 0)))
		local attach0 = Instance.new("Attachment")
		attach0.CFrame = nodeView.CFrame * orientation
		attach0.Parent = workspace.Terrain
		local attach1 = Instance.new("Attachment")
		attach1.CFrame = adjNodeView.CFrame * orientation
		attach1.Parent = workspace.Terrain
		local beam = Instance.new("Beam")
		beam.Attachment0 = attach0
		beam.Attachment1 = attach1
		beam.Parent = mConnectionsContainer
		beam.Transparency = NumberSequence.new(0)
		beam.Color = ColorSequence.new(Color3.new(0, 0, 0))
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		
		nodeView.AdjacentLinks[adjId] = {
			Beam = beam;
		}
	end
	
	local function showLinks(nodeView)
		for adjId, beamView in pairs(nodeView.AdjacentLinks) do
			beamView.Beam.Color = ColorSequence.new(Color3.new(0, 1, 0))
			beamView.Beam.Width0 = 1.5
			beamView.Beam.Width1 = 1.5
		end
	end
	
	local function setupLinks()
		for id, nodeView in pairs(mNodeView) do
			nodeView.AdjacentLinks = {}
			for _, adjId in pairs(Netmap.ById[id].Links) do
				setupLink(nodeView, adjId)
			end
		end
	end
	
	local function setVisible(nodeView, visibility)
		nodeView.Model.Parent = visibility and mNetmapModel or nil
		if visibility then
			nodeView.UnknownModel.Parent = nil
		else
			nodeView.UnknownModel.Parent = mNetmapModel
		end
	end
	local function setBeaten(nodeView, beaten)
		nodeView.Model.Parent = nil
		nodeView.Model = beaten and nodeView.VisibleModel or nodeView.DisabledModel
		if LocalPlayerData:HasSeenNode(nodeView.Id) then
			nodeView.Model.Parent = mNetmapModel
			if beaten then
				showLinks(nodeView)
			end
		end
	end
	
	local function setupNodes()
		for id, node in pairs(Netmap.ById) do
			local nodeView = mNodeView[id]
			if not nodeView then
				continue
			end
			setBeaten(nodeView, LocalPlayerData:HasBeatenNode(id))
			setVisible(nodeView, LocalPlayerData:HasSeenNode(id) or node.Warez)
		end
	end
	
	local mPlayerGui = game.Players.LocalPlayer.PlayerGui
	local mHoverDisplayGui = Instance.new("BillboardGui", mPlayerGui)
	local mHoverDisplayAdornee = Instance.new("Part")
	do
		mHoverDisplayAdornee.Transparency = 1
		mHoverDisplayAdornee.CollisionGroupId = NOT_BEATEN_COLLISION_GROUP
		mHoverDisplayAdornee.Anchored = true
		mHoverDisplayAdornee.Parent = workspace
		mHoverDisplayAdornee.Name = "HoverDisplayAdornee"
		mHoverDisplayGui.Adornee = mHoverDisplayAdornee
		mHoverDisplayGui.Enabled = false
		mHoverDisplayGui.AlwaysOnTop = true
		mHoverDisplayGui.Size = UDim2.new(0, 1, 0, 1)
		local frame = Instance.new("TextLabel", mHoverDisplayGui)
		frame.BackgroundTransparency = 1
		frame.TextStrokeTransparency = 0
		frame.Text = "[   ]"
		frame.TextSize = 96
		frame.TextScaled = true
		frame.TextColor3 = Color3.new(0.603922, 0, 0)
		local hoverSize = math.min(400, DeviceInfo.ScreenHeight * 0.3)
		frame.Size = UDim2.new(0, hoverSize , 0, hoverSize)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	updateHoveredNode = function()
		if DeviceInfo.Touch then
			-- Don't show the hover thing on touch devices
			return
		end
		local id = getHoveredNodeId(getUnitRay())
		if not ModalManager:IsModal() and id then
			mHoverDisplayGui.Enabled = true
			mHoverDisplayAdornee.CFrame = mNodeView[id].CFrame * CFrame.new(0, 4, 0)
		else
			mHoverDisplayGui.Enabled = false
		end
	end
	
	function this:GetGui()
		return mGui
	end

	function this:SetNodeBeaten(id)
		setBeaten(mNodeView[id], true)
		for _, adjId in pairs(Netmap.ById[id].Links) do
			local adjNode = mNodeView[adjId]
			if adjNode then
				setVisible(adjNode, true)
			else
				warn("Missing adjacent node to make visible:", id)
			end
		end
	end	

	function this:HighlightNode(id)
		print("Highlight node:", id)
		local node = mNodeView[id]
		if node then
			mCamera:FocusOn(node.CFrame.Position)
		else
			warn("Missing node to focus on:", id)
		end
	end

	-- Tutorial pointer: the bobbing arrow floating over a node (billboarded at
	-- constant screen size) plus a Highlight on the node model
	local mTutorialArrow = TutorialArrow.new()
	local mTutorialPointerParts = nil
	function this:ClearTutorialPointer()
		mTutorialArrow:Hide()
		if mTutorialPointerParts then
			mTutorialPointerParts.Billboard:Destroy()
			mTutorialPointerParts.Adornee:Destroy()
			mTutorialPointerParts.Highlight:Destroy()
			mTutorialPointerParts = nil
		end
	end
	function this:TutorialPointAtNode(id)
		this:ClearTutorialPointer()
		local nodeView = mNodeView[id]
		if not nodeView then
			warn("Missing node to point at:", id)
			return
		end

		local adornee = Instance.new("Part")
		adornee.Name = "TutorialPointerAdornee"
		adornee.Transparency = 1
		adornee.Anchored = true
		adornee.CanCollide = false
		adornee.CanQuery = false
		adornee.Size = Vector3.new(1, 1, 1)
		adornee.CFrame = nodeView.CFrame * CFrame.new(0, 6, 0)
		adornee.Parent = workspace

		-- Pixel-sized billboard: the arrow stays readable at any zoom level
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TutorialNodePointer"
		billboard.Adornee = adornee
		billboard.Size = UDim2.new(0, 200, 0, 200)
		billboard.AlwaysOnTop = true
		billboard.Parent = mPlayerGui
		mTutorialArrow:Show(billboard, 180, UDim2.new(0.5, 0, 0.3, 0))

		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(0, 255, 120)
		highlight.OutlineTransparency = 0
		highlight.Adornee = nodeView.Model
		highlight.Parent = nodeView.Model

		mTutorialPointerParts = {
			Billboard = billboard,
			Adornee = adornee,
			Highlight = highlight,
		}
	end

	function this:SetNodeVisible(id)
		local nodeView = mNodeView[id]
		if nodeView then
			setVisible(nodeView, true)
		else
			warn("Missing node to make visible:", id)
		end
	end

	local mLastShownCredits = nil
	function this:UpdateCreditDisplay()
		local credits = LocalPlayerData:GetCredits()
		mGuiRoot.setState({ creditsText = ("%d"):format(credits) })
		if mLastShownCredits ~= credits then
			if mLastShownCredits ~= nil and mGui:IsDescendantOf(game) then
				local delta = credits - mLastShownCredits
				local text = makeCreditUpdateText()
				if delta > 0 then
					text.Text = "+"..delta
					text.TextColor3 = Color3.new(0, 0.8, 0)
					text.TextColor3 = Color3.new(0, 0.4, 0)
				else
					text.Text = ""..delta
					text.TextColor3 = Color3.new(1, 0, 0)
					text.TextStrokeColor3 = Color3.new(0.5, 0, 0)
				end
				text.Parent = mGui.CreditDisplay.Inset
				text:TweenPosition(UDim2.new(0, 4, 1.1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 1, false, function()
					text:Destroy()
				end)
			end
			mLastShownCredits = credits
		end
	end
	
	local function update(dt)
		updateHoveredNode()
	end
	
	local mVisible = false
	local mLoopIdent = 0
	local function loopTask(loopIdent)
		while mLoopIdent == loopIdent do
			update(wait())
		end
	end
	function this:SetVisible(state)
		mGui.Visible = state
		if mVisible ~= state then
			mVisible = state
			mLoopIdent += 1
			if mVisible then
				spawn(function() loopTask(mLoopIdent) end)
				mCamera:Install()
				this:UpdateCreditDisplay()
			else
				mCamera:Uninstall()
			end
		end
	end
	
	setupNetmap()
	setupLinks()
	setupNodes()
	
	return this
end

return Netmap3DView
