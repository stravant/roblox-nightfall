local Signal = require(game.ReplicatedStorage.Signal)
local Netmap = require(game.ReplicatedStorage.Netmap)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local Scrollbar = require(game.ReplicatedStorage.ScrollingFrame)
local TutorialArrow = require(game.ReplicatedStorage.TutorialArrowView)

local NetmapView = {}

NetmapView.NodeTransparency = 0.4

function NetmapView.new()
	local this = {}
	
	this.NodeSelected = Signal.new()

	-- Our GUI	
	local mGui = script.Netmap:Clone()
	function this:GetGui()
		return mGui
	end
	
	-- Scrolling that doesn't suck
	local mScrollbar = Scrollbar.new(mGui.Content)
	mScrollbar:AddScrollbar(mGui.ScrollbarContainer.Scrollbar)
	
	-- Tutorial arrow
	local mTutorialArrow = TutorialArrow.new()
	
	-- Add the connections
	local mNodes = {}
	for id, node in pairs(Netmap.ById) do
		local nodeView = {
			Id = id;
			Links = {};
		}
		mNodes[id] = nodeView
		local nodeContainer = mGui.Content.Nodes[id]
		nodeView.Container = nodeContainer
		nodeView.x = nodeView.Container.Position.X.Offset
		nodeView.y = nodeView.Container.Position.Y.Offset
		local dot = script.NodeDot:Clone()
		dot.Parent = nodeContainer
		nodeView.Dot = dot
		if id == 'end' then
			dot.UnknownLabel.TextSize = 28
			dot.UnknownLabel.Text = "??"
		end
		local nodeImage = script.NodeImage:Clone()
		nodeImage.Parent = nodeContainer
		nodeImage.Visible = false
		nodeImage.ImageTransparency = NetmapView.NodeTransparency
		if node.Warez then
			--nodeImage.NodeText.Text = "Warez Node LvL"..node.Level
			--nodeImage.NodeText.Visible = true
		end
		-- Set icon
		if node.Conversation and node.Conversation.Function then
			local f = node.Conversation.Function
			if not LocalPlayerData:CanAccessNode(id) then
				nodeImage.NodeIcon.Image = 'rbxassetid://1446155063'
			elseif f.Type == 'getProgram' or f.Type == 'getCredits' then
				nodeImage.NodeIcon.Image = 'rbxassetid://1446155062'
			elseif f.Type == 'upgradeSecurity' then
				nodeImage.NodeIcon.Image = 'rbxassetid://1446155060'
			end
		elseif not LocalPlayerData:CanAccessNode(id) then
			nodeImage.NodeIcon.Image = 'rbxassetid://1446155063'
		end
		nodeView.NodeImage = nodeImage
		nodeImage.MouseButton1Click:connect(function()
			this.NodeSelected:fire(id)
		end)
		if LocalPlayerData:HasSeenNode(id) or node.Warez then
			nodeImage.Visible = true
			dot.UnknownLabel.Visible = false
		end
	end	
	for id, node in pairs(mNodes) do
		for _, adjId in pairs(Netmap.ById[id].Links) do
			local adjNode = mNodes[adjId]
			local link = script.ConnectionWeak:Clone()
			local dx = adjNode.x - node.x
			local dy = adjNode.y - node.y
			link.Position = UDim2.new(0, node.x + 0.5*dx, 0, node.y + 0.5*dy)
			link.Size = UDim2.new(0, 16, 0, math.sqrt(dx*dx + dy*dy))
			link.Parent = mGui.Content.Connections
			node.Links[adjId] = link
			link.Rotation = math.deg(math.atan2(-dx, dy))
			if LocalPlayerData:HasBeatenNode(id) then
				adjNode.NodeImage.Visible = true
				link.ImageRectOffset = script.ConnectionStrong.ImageRectOffset
			end
		end
	end
	for id, node in pairs(mNodes) do
		if LocalPlayerData:HasBeatenNode(id) then
			node.NodeImage.Visible = true
			node.NodeImage.Image = Netmap.ById[id].BeatenImage
			node.NodeImage.NodeIcon.Visible = false
			node.NodeImage.ImageTransparency = 0
		else
			node.NodeImage.Image = Netmap.ById[id].Image
		end
	end

	local function updateNodeIcon(id)
		local node = mNodes[id]
		if node.NodeImage.NodeIcon.Image == 'rbxassetid://1358147886' and LocalPlayerData:CanAccessNode(id) then
			local dat = Netmap.ById[id]
			if dat.Conversation and dat.Conversation.Function then
				local f = dat.Conversation.Function
				if f.Type == 'getProgram' or f.Type == 'getCredits' then
					node.NodeImage.NodeIcon.Image = 'rbxassetid://1358147885'
				elseif f.Type == 'upgradeSecurity' then
					node.NodeImage.NodeIcon.Image = 'rbxassetid://1358147884'
				else
					node.NodeImage.NodeIcon.Image = ''
				end
			else
				node.NodeImage.NodeIcon.Image = ''
			end
		end
	end
	
	-- They beat a given node
	function this:SetNodeBeaten(id)
		local dat = Netmap.ById[id]
		local node = mNodes[id]
		node.NodeImage.Visible = true
		node.NodeImage.Image = dat.BeatenImage	
		node.NodeImage.NodeIcon.Visible = false
		node.NodeImage.ImageTransparency = 0
		for _, adjId in pairs(Netmap.ById[id].Links) do
			mNodes[adjId].NodeImage.Visible = true
			node.Links[adjId].ImageRectOffset = script.ConnectionStrong.ImageRectOffset
			updateNodeIcon(adjId)
		end
		if dat.Conversation and dat.Conversation.Function and dat.Conversation.Function.Type == 'upgradeSecurity' then
			-- Upgraded security, Go through each node and update the image if it was blocked before
			for id, node in pairs(mNodes) do
				updateNodeIcon(id)
			end
		end
	end	
	
	function this:HighlightNode(id)
		local node = mNodes[id]
		local gui = mGui.Content.Nodes[id]
		mScrollbar:ScrollTo(gui.Position.Y.Offset - 0.5*mGui.AbsoluteSize.Y)
		mScrollbar:FreeScroll()
		mTutorialArrow:Show(node.NodeImage, 180, UDim2.new(0.5, 0, 0.3, 0))
		delay(2, function()
			mTutorialArrow:Hide()
		end)
	end

	function this:SetNodeVisible(id)
		local node = mNodes[id]
		if not node.NodeImage.Visible then
			node.Dot.UnknownLabel.Visible = false
			node.NodeImage.Visible = true
		end
	end
	
	local mLastShownCredits = nil
	function this:UpdateCreditDisplay()
		if not mGui:IsDescendantOf(game) then
			return
		end
		local credits = LocalPlayerData:GetCredits()
		mGui.CreditDisplay.Inset.Text.Text = ("%d"):format(credits)
		if mLastShownCredits ~= credits then
			if mLastShownCredits ~= nil then
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
	
	this:UpdateCreditDisplay()
	
	return this
end

return NetmapView
