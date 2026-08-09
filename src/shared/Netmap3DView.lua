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

local Netmap3DView = {}

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
	
	local mGui = script.Netmap:Clone()
	
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
			local light do
				local lightPart = Instance.new("Part")
				lightPart.Transparency = 1
				lightPart.Anchored = true
				lightPart:PivotTo(cf)
				light = Instance.new("PointLight")
				light.Parent = lightPart
				light.Range = 10
				light.Brightness = 6
				lightPart.Parent = disabledModel
			end
			mNodeModelToNodeIdMap[visibleModel] = id
			mNodeModelToNodeIdMap[disabledModel] = id
			mNodeView[id] = {
				Id = id;
				CFrame = cf;
				Model = disabledModel;
				VisibleModel = visibleModel;
				DisabledModel = disabledModel;
				UnknownModel = unknownModel;
				Light = light;
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
	
	local function setupNotBeatenGlow(nodeView)
		if nodeView.NotBeatenGlow then
			return
		end
		local expandyParts = {}
		for _, desc in pairs(nodeView.VisibleModel:GetDescendants()) do
			if desc:IsA('BasePart') then
				table.insert(expandyParts, {
					Part = desc:Clone(),
				})
			end
		end
		for _, entry in pairs(expandyParts) do
			entry.Part.Transparency = 0.7
			entry.Part.CollisionGroupId = NOT_BEATEN_COLLISION_GROUP
			entry.BaseSize = entry.Part.Size
			entry.BaseOffset = entry.Part.Position - nodeView.CFrame.Position
			entry.Part.Parent = mNotBeatenGlowContainer
			entry.Part.CastShadow = false
		end
		nodeView.NotBeatenGlow = expandyParts
	end
	local function clearNotBeatenGlow(nodeView)
		if nodeView.NotBeatenGlow then
			for _, entry in pairs(nodeView.NotBeatenGlow) do
				entry.Part:Destroy()
			end
			nodeView.NotBeatenGlow = nil
		end
	end
	local function setVisible(nodeView, visibility)
		nodeView.Model.Parent = visibility and mNetmapModel or nil
		if visibility then
			nodeView.UnknownModel.Parent = nil
		else
			nodeView.UnknownModel.Parent = mNetmapModel
		end
		if visibility and not LocalPlayerData:HasBeatenNode(nodeView.Id) then
			setupNotBeatenGlow(nodeView)
		end
	end
	local function setBeaten(nodeView, beaten)
		nodeView.Model.Parent = nil
		nodeView.Model = beaten and nodeView.VisibleModel or nodeView.DisabledModel
		if LocalPlayerData:HasSeenNode(nodeView.Id) then
			nodeView.Model.Parent = mNetmapModel
			if beaten then
				clearNotBeatenGlow(nodeView)
				showLinks(nodeView)
			else
				setupNotBeatenGlow(nodeView)
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
	
	local mNotBeatenGlowTime = 0
	local function animateGlow(dt)
		mNotBeatenGlowTime += 0.6 * dt
		local frac = math.max(0, math.fmod(mNotBeatenGlowTime, 0.8) - 0.5) / 0.3
		local scaleFrac = (frac > 0.8) and 0.8 * 2 - frac or frac
		local scale = 1.0 + scaleFrac^0.6 * 0.2
		for id, nodeView in pairs(mNodeView) do
			if nodeView.NotBeatenGlow then
				for _, entry in pairs(nodeView.NotBeatenGlow) do
					entry.Part.Transparency = 1
					--entry.Part.Size = entry.BaseSize * scale
					--entry.Part.Position = nodeView.CFrame.Position + (entry.BaseOffset + workspace.CurrentCamera.CFrame.LookVector * 2) * scale
					--if frac == 0 then
					--	entry.Part.Transparency = 1
					--else
					--	entry.Part.Transparency = 0.1 + 0.9 * frac
					--end
				end
				local x = mNotBeatenGlowTime * 4
				local frac = math.sin(x + 0.6*math.sin(x)^2)^2
				if LocalPlayerData:CanAccessNode(id) then
					nodeView.Light.Brightness = 2 + 4 * frac
				else
					nodeView.Light.Brightness = 0
				end
			end
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
		mGui.CreditDisplay.Inset.Text.Text = ("%d"):format(credits)
		if mLastShownCredits ~= credits then
			if mLastShownCredits ~= nil and mGui:IsDescendantOf(game) then
				local delta = credits - mLastShownCredits
				local text = script.CreditUpdateText:Clone()
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
		animateGlow(dt)
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
