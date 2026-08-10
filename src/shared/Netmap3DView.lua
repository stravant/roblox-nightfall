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
	
	local mConnectionsContainer = Instance.new('Folder', workspace)
	local mPlayerGui = game.Players.LocalPlayer.PlayerGui
	
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
	
	local kNodeModelScale = 1.3

	local function setupNetmap()
		for _, ch in pairs(mNetmapModel:GetChildren()) do
			local id = ch.Name
			local cf = ch:GetPivot()
			local visibleModel = NETMAP_NODE_MODELS[id:sub(1, 2)]:Clone()
			visibleModel:ScaleTo(kNodeModelScale)
			visibleModel:PivotTo(cf)
			local disabledModel = NETMAP_NODE_MODELS[id:sub(1, 2)..'_disabled']:Clone()
			disabledModel:ScaleTo(kNodeModelScale)
			disabledModel:PivotTo(cf)
			-- Only the live (seen) model is clickable; undiscovered nodes show
			-- the disabled model purely as scenery
			mNodeModelToNodeIdMap[visibleModel] = id
			mNodeView[id] = {
				Id = id;
				CFrame = cf;
				Seen = false;
				Beaten = false;
				VisibleModel = visibleModel;
				DisabledModel = disabledModel;
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
	
	-- Beaten links become ethereal green arcs with a stream of 0/1 digits
	-- flowing from the source node to its neighbors
	local mActiveLinkAnims = {}
	local function showLinks(nodeView)
		for adjId, beamView in pairs(nodeView.AdjacentLinks) do
			if not beamView.Active then
				beamView.Active = true
				beamView.Beam.Color = ColorSequence.new(Color3.new(0, 1, 0.3))
				beamView.Beam.Transparency = NumberSequence.new(0.55)
				beamView.Beam.Width0 = 0.9
				beamView.Beam.Width1 = 0.9

				beamView.From = nodeView.CFrame.Position
				beamView.To = mNodeView[adjId].CFrame.Position
				local dir = (beamView.To - beamView.From)
				local flat = Vector3.new(dir.X, 0, dir.Z)
				beamView.Perp = if flat.Magnitude > 0.01
					then Vector3.new(-flat.Unit.Z, 0, flat.Unit.X)
					else Vector3.new(1, 0, 0)
				beamView.Particles = {}
				for i = 1, 4 do
					-- Terrain-adorned billboard: StudsOffsetWorldSpace is then
					-- an absolute world position, no adornee part needed
					local bb = Instance.new("BillboardGui")
					bb.Adornee = workspace.Terrain
					bb.Size = UDim2.new(0, 24, 0, 24)
					bb.LightInfluence = 0
					bb.Parent = mConnectionsContainer
					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Font = Enum.Font.Code
					label.TextSize = 18
					label.TextColor3 = Color3.new(0.3, 1, 0.45)
					label.Text = (i % 2 == 0) and "0" or "1"
					label.Parent = bb
					table.insert(beamView.Particles, {
						Gui = bb,
						Label = label,
						Phase = (i - 1) / 4,
						Speed = 0.28 + 0.07 * ((i * 7) % 3),
						Seed = i * 2.61,
						NextFlip = 0,
					})
				end
				table.insert(mActiveLinkAnims, beamView)
			end
		end
	end

	local function animateLinks(t)
		for _, link in pairs(mActiveLinkAnims) do
			for _, p in pairs(link.Particles) do
				local alpha = (t * p.Speed + p.Phase) % 1
				local arc = math.sin(alpha * math.pi)
				local wobble = math.sin(t * 2.7 + p.Seed) * 0.6
				local pos = link.From:Lerp(link.To, alpha)
					+ Vector3.new(0, 1 + arc * 2.2, 0)
					+ link.Perp * wobble
				p.Gui.StudsOffsetWorldSpace = pos
				p.Label.TextTransparency = 0.1 + 0.65 * (1 - arc)
				if t > p.NextFlip then
					p.NextFlip = t + 0.12 + 0.25 * math.random()
					p.Label.Text = (math.random() < 0.5) and "0" or "1"
				end
			end
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
	
	-- The flashing Win95-virus-popup style "Infected!" billboard shown over
	-- nodes that are discovered but not yet beaten
	local function ensureInfectedBillboard(nodeView)
		if nodeView.Infected then
			return
		end
		local adornee = Instance.new("Part")
		adornee.Name = "InfectedAdornee"
		adornee.Transparency = 1
		adornee.Anchored = true
		adornee.CanCollide = false
		adornee.CanQuery = false
		adornee.Size = Vector3.new(1, 1, 1)
		adornee.CFrame = nodeView.CFrame * CFrame.new(0, 5, 0)
		adornee.Parent = workspace

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "InfectedPopup"
		billboard.Adornee = adornee
		billboard.Size = UDim2.new(0, 132, 0, 46)
		billboard.AlwaysOnTop = true
		-- AlwaysOnTop renders through the battle board, so only enable while
		-- the netmap is actually being shown (kept in sync below)
		billboard.Enabled = mGui.Visible
		billboard.Parent = mPlayerGui

		local window = Instance.new("ImageLabel")
		window.Size = UDim2.new(1, 0, 1, 0)
		window.BackgroundTransparency = 1
		window.Image = "rbxassetid://1378189463"
		window.ImageRectSize = Vector2.new(32, 48)
		window.ScaleType = Enum.ScaleType.Slice
		window.SliceCenter = Rect.new(16, 24, 16, 24)
		window.Parent = billboard
		local title = Instance.new("TextLabel")
		title.Position = UDim2.new(0, 6, 0, 2)
		title.Size = UDim2.new(1, -12, 0, 18)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = 12
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "System Alert"
		title.Parent = window
		local inset = Instance.new("ImageLabel")
		inset.Position = UDim2.new(0, 5, 0, 20)
		inset.Size = UDim2.new(1, -10, 1, -24)
		inset.BackgroundTransparency = 1
		inset.Image = "rbxassetid://1378143823"
		inset.ScaleType = Enum.ScaleType.Slice
		inset.SliceCenter = Rect.new(8, 8, 8, 8)
		inset.Parent = window
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.SourceSansBold
		label.TextSize = 16
		label.TextColor3 = Color3.new(0.8, 0, 0)
		label.Text = "\u{26A0}\u{FE0F} Infected!"
		label.Parent = inset

		nodeView.Infected = {
			Adornee = adornee,
			Billboard = billboard,
			Label = label,
		}
	end
	local function removeInfectedBillboard(nodeView)
		if nodeView.Infected then
			nodeView.Infected.Billboard:Destroy()
			nodeView.Infected.Adornee:Destroy()
			nodeView.Infected = nil
		end
	end
	local function animateInfected(t)
		local flash = (t % 0.9) < 0.45
		for _, nodeView in pairs(mNodeView) do
			if nodeView.Infected then
				nodeView.Infected.Label.TextTransparency = flash and 0 or 0.6
			end
		end
	end

	-- Node display states:
	--   undiscovered      -> disabled model (scenery, not clickable)
	--   seen, not beaten  -> live model + flashing "Infected!" popup
	--   seen and beaten   -> live model, links stream green
	local function applyNodeState(nodeView)
		nodeView.DisabledModel.Parent = (not nodeView.Seen) and mNetmapModel or nil
		nodeView.VisibleModel.Parent = nodeView.Seen and mNetmapModel or nil
		-- Warez nodes are shops, not infected battle nodes
		local isWarez = Netmap.ById[nodeView.Id].Warez ~= nil
		if nodeView.Seen and not nodeView.Beaten and not isWarez then
			ensureInfectedBillboard(nodeView)
		else
			removeInfectedBillboard(nodeView)
		end
		if nodeView.Seen and nodeView.Beaten then
			showLinks(nodeView)
		end
	end
	local function setVisible(nodeView, visibility)
		nodeView.Seen = visibility
		applyNodeState(nodeView)
	end
	local function setBeaten(nodeView, beaten)
		nodeView.Beaten = beaten
		applyNodeState(nodeView)
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
		if not mGui.Visible then
			-- During a databattle the netmap sits far below the board and the
			-- hover raycast can still reach it; don't show the bracket
			mHoverDisplayGui.Enabled = false
			return
		end
		local id = getHoveredNodeId(getUnitRay())
		if not ModalManager:IsModal() and id then
			mHoverDisplayGui.Enabled = true
			mHoverDisplayAdornee.CFrame = mNodeView[id].CFrame * CFrame.new(0, 5.5, 0)
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
		adornee.CFrame = nodeView.CFrame * CFrame.new(0, 8, 0)
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
		highlight.Adornee = nodeView.VisibleModel
		highlight.Parent = nodeView.VisibleModel

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
	
	-- Blinkenlights: decorative LEDs on the netmap islands (place assets under
	-- NetmapBackground.Blinkenlights), each blinking on its own rhythm
	local mBlinkenlights = {}
	do
		local folder = workspace.NetmapBackground:FindFirstChild("Blinkenlights")
		if folder then
			for i, part in pairs(folder:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(mBlinkenlights, {
						Part = part,
						OnColor = part.Color,
						OffColor = Color3.new(part.Color.R * 0.12, part.Color.G * 0.12, part.Color.B * 0.12),
						Phase = i * 1.73,
						Speed = 0.7 + (i % 5) * 0.45,
					})
				end
			end
		end
	end
	local function animateBlinkenlights(t)
		for _, light in pairs(mBlinkenlights) do
			local on = math.sin(t * light.Speed + light.Phase) > 0.2
			light.Part.Color = on and light.OnColor or light.OffColor
		end
	end

	local function update(dt)
		updateHoveredNode()
		local t = os.clock()
		animateInfected(t)
		animateLinks(t)
		animateBlinkenlights(t)
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

	-- Keep the AlwaysOnTop infected popups in sync with whether the netmap is
	-- actually on screen. Watching the gui's Visible property covers both
	-- SetVisible and the tutorial's direct Visible toggling.
	mGui:GetPropertyChangedSignal("Visible"):Connect(function()
		for _, nodeView in pairs(mNodeView) do
			if nodeView.Infected then
				nodeView.Infected.Billboard.Enabled = mGui.Visible
			end
		end
	end)

	return this
end

return Netmap3DView
