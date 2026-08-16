local UserInputService = game:GetService("UserInputService")

local Signal = require(game.ReplicatedStorage.Signal)
local Netmap = require(game.ReplicatedStorage.Netmap)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local TutorialArrow = require(game.ReplicatedStorage.TutorialArrowView)
local NetmapCamera = require(game.ReplicatedStorage.NetmapCamera)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)

local Netmap3DView = {}

-- The credits display itself lives in MainView's topbar (driven through the
-- topbarCredits interface); only the transient credit delta text is created
-- here because it's a fire-and-forget TweenPosition animation.

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

-- Node popup billboard size in pixels (the layout's authored size)
local kPopupWidthPx = 132
local kPopupHeightPx = kPopupWidthPx * 46 / 132
-- Popup anchor placement: studs pulled toward the camera along the sight ray
-- (in front of the node/ground without introducing parallax — and since the
-- ray rises toward the camera, pull is also what buys ground clearance), and
-- how far below the node's center the popup's top edge hangs. The down
-- offset is measured in pixels AT THE DEFAULT ZOOM but applied as a
-- world-space (camera-plane) offset, so the gap scales with the node's
-- on-screen size instead of sitting too low zoomed out / too high zoomed in.
local kPopupPullStuds = 16
local kPopupDownPx = 34
local kPopupDownReferenceDist = 300 -- the netmap camera's default zoom
-- Reference point on the node the popup hangs beneath (above the base pivot)
local kPopupNodeCenterY = 6
-- The window chrome texture has a little transparent margin around it, so the
-- backing part is trimmed slightly smaller than the billboard rect (the
-- height trim comes off the bottom; the top edge stays anchor-aligned)
local kBackingWidthTrimPx = 6
local kBackingHeightTrimPx = 6

-- `topbarCredits` is MainView's topbar credits interface: SetText(text) and
-- GetInset() (the sunken frame the fly-away delta text animates inside)
function Netmap3DView.new(topbarCredits)
	local this = {}

	local mTopbarCredits = topbarCredits

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
			-- Hit cylinders map by instance; node models map by parent model
			local id = mNodeModelToNodeIdMap[result.Instance]
				or mNodeModelToNodeIdMap[result.Instance.Parent]
			-- No hover/click affordance for nodes the player can't reach yet
			-- (e.g. a seen warez node before its neighbor is beaten)
			if id and LocalPlayerData:CanAccessNode(id) then
				return id
			end
		end
	end
	
	local mCamera = NetmapCamera.new()

	-- The camera position/zoom persist in the save data: restore them now,
	-- and send the state (with the volumes: the server merges per-field but
	-- sending everything keeps one payload shape) a beat after the user
	-- stops moving the camera
	do
		local settings = LocalPlayerData:GetSettings()
		if settings then
			if settings.NetmapX and settings.NetmapZ then
				mCamera:FocusOn(Vector3.new(settings.NetmapX, 0, settings.NetmapZ), false)
			end
			if settings.NetmapZoom then
				mCamera:SetZoom(settings.NetmapZoom)
			end
		end
		local pendingSend = false
		mCamera.Changed:connect(function()
			if pendingSend then
				return
			end
			pendingSend = true
			task.delay(2, function()
				pendingSend = false
				local position, zoom = mCamera:GetState()
				local sound, music = SoundManager:GetVolumes()
				pcall(function()
					game.ReplicatedStorage.Remotes.SaveSettings:FireServer({
						SoundVolume = sound,
						MusicVolume = music,
						NetmapX = position.X,
						NetmapZ = position.Z,
						NetmapZoom = zoom,
					})
				end)
			end)
		end)
	end

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

	local kNodeModelScale = 1

	-- Generous invisible hit cylinders so hovers/clicks can't miss a node.
	-- They live in their own folder rather than inside the node models: the
	-- hover/tutorial Highlights adorn the models, and a part inside the model
	-- would be included in the highlight silhouette.
	local mHitAreasContainer = Instance.new("Folder")
	mHitAreasContainer.Name = "NetmapNodeHitAreas"
	mHitAreasContainer.Parent = workspace

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

			local hitArea = Instance.new("Part")
			hitArea.Name = id
			hitArea.Shape = Enum.PartType.Cylinder
			hitArea.Transparency = 1
			hitArea.Anchored = true
			hitArea.CanCollide = false
			hitArea.CanTouch = false
			hitArea.CanQuery = false -- enabled once the node is seen
			-- Cylinder axis is X; stand it upright: 6 tall, 8 across
			hitArea.Size = Vector3.new(6, 8, 8)
			hitArea.CFrame = cf * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
			hitArea.Parent = mHitAreasContainer
			mNodeModelToNodeIdMap[hitArea] = id

			-- Idle-animation parts: whatever the designer placed under the
			-- model's "Animate" folder, with rest poses captured post-pivot.
			-- Sorted by X so sequenced animations (the shop's glint) have a
			-- deterministic order.
			local animateParts = nil
			local animateFolder = visibleModel:FindFirstChild("Animate")
			if animateFolder then
				animateParts = {}
				for _, part in pairs(animateFolder:GetDescendants()) do
					if part:IsA("BasePart") then
						table.insert(animateParts, {
							Part = part,
							Base = part.CFrame,
							Material = part.Material,
						})
					end
				end
				table.sort(animateParts, function(a, b)
					return a.Base.Position.X < b.Base.Position.X
				end)
			end

			mNodeView[id] = {
				Id = id;
				CFrame = cf;
				Seen = false;
				Beaten = false;
				VisibleModel = visibleModel;
				DisabledModel = disabledModel;
				HitArea = hitArea;
				AnimateParts = animateParts;
				AnimSeed = math.random() * 100;
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
		beam.Color = ColorSequence.new(Color3.new(1, 0, 0))
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		
		nodeView.AdjacentLinks[adjId] = {
			Beam = beam;
		}
	end
	
	-- Beaten links restyle to an ethereal green
	local function showLinks(nodeView)
		for adjId, beamView in pairs(nodeView.AdjacentLinks) do
			if not beamView.Active then
				beamView.Active = true
				local beam = beamView.Beam
				beam.Color = ColorSequence.new(Color3.new(0, 1, 0.3))
				beam.Transparency = NumberSequence.new(0.55)
				beam.Width0 = 0.9
				beam.Width1 = 0.9
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
	
	-- Win95-virus-popup style status billboards under nodes: a flashing status
	-- in the title bar ("Infected!" for unbeaten battle nodes, "New!" for
	-- unvisited warez shops) with the node's name in the body so players have
	-- a way to refer to a particular node. Anchored below the node's base so
	-- the node geometry itself stays visible.
	local nodeDisplayName = Netmap.GetNodeDisplayName

	-- The popups are part of their node's hover/click target
	local mPopupHoveredId = nil
	local function popupClicked(id)
		if not mGui.Visible or not mGui.Parent then
			return
		end
		if ModalManager:IsModal() then
			return
		end
		if not LocalPlayerData:CanAccessNode(id) then
			return
		end
		SoundManager:Play'SelectNode'
		this.NodeSelected:fire(id)
		updateHoveredNode()
	end

	local removeNodePopup
	-- kind: identity for the popup style; a state change to a different kind
	-- rebuilds the popup. flash: whether the body text blinks. lockedText:
	-- when set, a translucent black overlay showing it covers the (otherwise
	-- normal) popup.
	local function ensureNodePopup(nodeView, kind, titleText, statusText, statusColor, flash, lockedText)
		if nodeView.Popup then
			if nodeView.Popup.Kind == kind then
				return
			end
			removeNodePopup(nodeView)
		end
		-- Pixel-crisp BillboardGui, NOT AlwaysOnTop, paired with an opaque
		-- black backing part that is reverse-projected to sit exactly behind
		-- the billboard's screen rect every frame (updatePopupBacking). The
		-- backing writes depth, so it blocks exactly the piece of the
		-- (Occluded) hover Highlight that the popup covers, and scenery in
		-- front of the popup occludes both.
		local adornee = Instance.new("Part")
		adornee.Name = "NodePopupAdornee"
		adornee.Transparency = 1
		adornee.Anchored = true
		adornee.CanCollide = false
		adornee.CanQuery = false
		adornee.Size = Vector3.new(1, 1, 1)
		-- The anchor is repositioned every frame (updatePopupBackings): pulled
		-- toward the camera ALONG THE SIGHT RAY (which contributes zero
		-- parallax against the node) and offset screen-down in the camera
		-- plane by a fixed pixel amount. Parked at the node until then.
		adornee.CFrame = CFrame.new(nodeView.CFrame.Position)
		adornee.Parent = workspace

		local backing = Instance.new("Part")
		backing.Name = "NodePopupBacking"
		backing.Transparency = mGui.Visible and 0 or 1
		backing.Color = Color3.new(0, 0, 0)
		backing.Material = Enum.Material.SmoothPlastic
		backing.Anchored = true
		backing.CanCollide = false
		-- Queryable ON PURPOSE: the popup rect is part of the node's click
		-- area (see the map entry below), so hover/click raycasts landing on
		-- the parts of the popup that don't overlap the node geometry still
		-- resolve to the node
		backing.CanQuery = true
		backing.CastShadow = false
		backing.Size = Vector3.new(1, 1, 0.05)
		-- Parked far away until the first updatePopupBackings pass places it
		backing.CFrame = CFrame.new(0, -10000, 0)
		backing.Parent = workspace
		mNodeModelToNodeIdMap[backing] = nodeView.Id

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NodePopup"
		billboard.Adornee = adornee
		billboard.Size = UDim2.new(0, kPopupWidthPx, 0, kPopupHeightPx)
		-- Top edge anchored at the adornee point: zooming out grows the popup
		-- downward on screen instead of up over the node geometry
		billboard.SizeOffset = Vector2.new(0, -0.5)
		billboard.AlwaysOnTop = false
		billboard.LightInfluence = 0
		billboard.Enabled = mGui.Visible
		billboard.Parent = mPlayerGui

		local scale = Instance.new("UIScale")
		-- The layout is authored at 132x46
		scale.Scale = kPopupWidthPx / 132
		scale.Parent = billboard

		local window = Instance.new("ImageLabel")
		window.Size = UDim2.new(0, 132, 0, 46)
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
		title.TextSize = 13
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = titleText
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
		label.TextColor3 = statusColor
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.Text = statusText
		label.Parent = inset

		-- Locked nodes show the normal popup dimmed under a translucent black
		-- overlay with the lock notice filling it
		if lockedText then
			local overlay = Instance.new("Frame")
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundColor3 = Color3.new(0, 0, 0)
			overlay.BackgroundTransparency = 0.35
			overlay.BorderSizePixel = 0
			overlay.Parent = window
			local lockText = Instance.new("TextLabel")
			lockText.Position = UDim2.new(0, 8, 0, 6)
			lockText.Size = UDim2.new(1, -16, 1, -12)
			lockText.BackgroundTransparency = 1
			lockText.Font = Enum.Font.SourceSansBold
			lockText.TextScaled = true
			lockText.TextColor3 = Color3.new(1, 1, 1)
			lockText.TextStrokeColor3 = Color3.new(0, 0, 0)
			lockText.TextStrokeTransparency = 0
			lockText.Text = lockedText
			lockText.Parent = overlay
		end

		-- Invisible button spanning the popup: hovering highlights the node,
		-- clicking enters it (exactly matches the billboard's screen size)
		local clickButton = Instance.new("ImageButton")
		clickButton.Size = UDim2.new(1, 0, 1, 0)
		clickButton.BackgroundTransparency = 1
		clickButton.Image = ""
		clickButton.Parent = window
		clickButton.MouseEnter:Connect(function()
			mPopupHoveredId = nodeView.Id
		end)
		clickButton.MouseLeave:Connect(function()
			if mPopupHoveredId == nodeView.Id then
				mPopupHoveredId = nil
			end
		end)
		clickButton.MouseButton1Click:Connect(function()
			popupClicked(nodeView.Id)
		end)

		nodeView.Popup = {
			Kind = kind,
			NodeCenter = nodeView.CFrame.Position + Vector3.new(0, kPopupNodeCenterY, 0),
			Adornee = adornee,
			Backing = backing,
			Billboard = billboard,
			FlashLabel = if flash then label else nil,
			-- Flash alternates between the status color and a lightened
			-- version of it (transparency flashing reads badly with the stroke)
			FlashColor = statusColor:Lerp(Color3.new(1, 1, 1), 0.5),
			BaseColor = statusColor,
		}
	end
	removeNodePopup = function(nodeView)
		if nodeView.Popup then
			if mPopupHoveredId == nodeView.Id then
				mPopupHoveredId = nil
			end
			mNodeModelToNodeIdMap[nodeView.Popup.Backing] = nil
			nodeView.Popup.Billboard:Destroy()
			nodeView.Popup.Backing:Destroy()
			nodeView.Popup.Adornee:Destroy()
			nodeView.Popup = nil
		end
	end
	-- Per-frame popup transforms:
	-- 1. The billboard anchor: pulled toward the camera ALONG THE SIGHT RAY
	--    (points on the ray project exactly onto the node — no parallax when
	--    panning) and offset screen-down in the camera plane by a fixed pixel
	--    amount, so the popup stays glued below its node on screen.
	-- 2. The opaque backing part: reverse-projected to exactly cover the
	--    pixel-sized billboard's screen rect at the anchor's depth.
	local function updatePopupBackings()
		local camera = workspace.CurrentCamera
		local viewportY = camera.ViewportSize.Y
		if viewportY <= 0 then
			return
		end
		local camCF = camera.CFrame
		local worldPerPixelPerStud = 2 * math.tan(math.rad(camera.FieldOfView) / 2) / viewportY
		for _, nodeView in pairs(mNodeView) do
			local popup = nodeView.Popup
			if popup then
				local nodeToCam = camCF.Position - popup.NodeCenter
				local nodeDist = nodeToCam.Magnitude
				if nodeDist < kPopupPullStuds + 1 then
					continue -- degenerate: camera inside the node
				end
				local anchorPos = popup.NodeCenter
					+ nodeToCam.Unit * kPopupPullStuds
					- camCF.UpVector * (kPopupDownPx * kPopupDownReferenceDist * worldPerPixelPerStud)
				popup.Adornee.CFrame = CFrame.new(anchorPos)
				local dist = (anchorPos - camCF.Position).Magnitude
				local worldPerPixel = dist * worldPerPixelPerStud
				-- Additionally pulled in a stud per side: the depth offset
				-- makes the backing project slightly larger than the billboard
				-- (perspective), and the highlight only ever overlaps the
				-- popup towards the middle anyway
				local w = (kPopupWidthPx - kBackingWidthTrimPx) * worldPerPixel - 2
				-- Shrinking h moves only the bottom edge: the top edge is
				-- center + h/2 = the anchor point regardless of h
				local h = (kPopupHeightPx - kBackingHeightTrimPx) * worldPerPixel
				-- Matches the billboard's SizeOffset (0, -0.5) top-edge
				-- anchoring; pushed slightly away from the camera so the
				-- billboard depth-tests in front of the backing
				local center = anchorPos
					- camCF.UpVector * (h / 2)
					+ camCF.LookVector * 0.75
				popup.Backing.Size = Vector3.new(w, h, 0.05)
				popup.Backing.CFrame = CFrame.new(center) * camCF.Rotation
			end
		end
	end
	local function animatePopups(t)
		local flash = (t % 0.9) < 0.45
		for _, nodeView in pairs(mNodeView) do
			local popup = nodeView.Popup
			if popup and popup.FlashLabel then
				popup.FlashLabel.TextColor3 = flash and popup.BaseColor or popup.FlashColor
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
		-- The enlarged hit cylinder only intercepts hovers/clicks once the
		-- node is actually interactable (normalized: the and-chain can yield
		-- nil, which is not assignable to a boolean property)
		nodeView.HitArea.CanQuery = (nodeView.Seen and LocalPlayerData:CanAccessNode(nodeView.Id)) and true or false
		local isWarez = Netmap.ById[nodeView.Id].Warez ~= nil
		if nodeView.Seen and not nodeView.Beaten then
			local name = nodeDisplayName(nodeView.Id)
			if not LocalPlayerData:CanAccessNode(nodeView.Id) then
				if isWarez then
					-- Unreachable shops just stay quiet
					removeNodePopup(nodeView)
				else
					-- Revealed but unreachable: the normal infected popup,
					-- dimmed under a lock overlay stating why. Insufficient
					-- security takes priority; otherwise there's no link yet.
					local lockedText
					if Netmap.ById[nodeView.Id].Level > LocalPlayerData:GetSecurityLevel() then
						lockedText = "\u{1F512} Insufficient\nSecurity Level"
					else
						lockedText = "\u{1F512} No Link\nEstablished"
					end
					ensureNodePopup(nodeView, "locked:" .. lockedText, name,
						"\u{26A0}\u{FE0F} Infected!", Color3.fromRGB(200, 0, 0), true, lockedText)
				end
			elseif isWarez then
				-- Warez nodes are shops: advertise, don't alarm
				ensureNodePopup(nodeView, "new", name,
					"New!", Color3.fromRGB(0, 90, 20), true)
			else
				ensureNodePopup(nodeView, "infected", name,
					"\u{26A0}\u{FE0F} Infected!", Color3.fromRGB(200, 0, 0), true)
			end
		else
			removeNodePopup(nodeView)
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
	
	-- Hover highlight: outline on the hovered node's model (desktop only)
	local mHoverHighlight = Instance.new("Highlight")
	mHoverHighlight.FillTransparency = 1
	mHoverHighlight.OutlineColor = Color3.new(1, 1, 1)
	mHoverHighlight.OutlineTransparency = 0
	-- Occluded (not AlwaysOnTop) so the opaque popup parts can cover it
	mHoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	mHoverHighlight.Enabled = false
	mHoverHighlight.Parent = mPlayerGui

	-- Touch has no hover, so when the last input was a touch, outline EVERY
	-- node worth tapping instead: accessible warez shops and unbeaten
	-- infected nodes
	local function isInterestingNode(nodeView)
		if not nodeView.Seen or not LocalPlayerData:CanAccessNode(nodeView.Id) then
			return false
		end
		local isWarez = Netmap.ById[nodeView.Id].Warez ~= nil
		return isWarez or not nodeView.Beaten
	end
	local function updateTouchHighlights()
		local touchMode = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		local show = touchMode and mGui.Visible and not ModalManager:IsModal()
		for _, nodeView in pairs(mNodeView) do
			local want = show and isInterestingNode(nodeView)
			if want and not nodeView.TouchHighlight then
				local highlight = Instance.new("Highlight")
				highlight.FillTransparency = 1
				-- Red for infected nodes, white for warez shops
				highlight.OutlineColor = if Netmap.ById[nodeView.Id].Warez ~= nil
					then Color3.new(1, 1, 1)
					else Color3.new(1, 0, 0)
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.Adornee = nodeView.VisibleModel
				highlight.Parent = mPlayerGui
				nodeView.TouchHighlight = highlight
			elseif not want and nodeView.TouchHighlight then
				nodeView.TouchHighlight:Destroy()
				nodeView.TouchHighlight = nil
			end
		end
	end

	updateHoveredNode = function()
		if DeviceInfo.Touch then
			-- Don't show the hover thing on touch devices
			return
		end
		if not mGui.Visible then
			-- During a databattle the netmap sits far below the board and the
			-- hover raycast can still reach it; don't show the highlight
			mHoverHighlight.Enabled = false
			return
		end
		local id = getHoveredNodeId(getUnitRay())
		-- Hovering a node's popup counts as hovering the node
		if not id and mPopupHoveredId and LocalPlayerData:CanAccessNode(mPopupHoveredId) then
			id = mPopupHoveredId
		end
		if not ModalManager:IsModal() and id then
			-- The highlight doubles as a "something to do here" hint: beaten
			-- battle nodes don't get it, warez shops always do. Red for
			-- infected nodes, white for warez shops.
			local isWarez = Netmap.ById[id].Warez ~= nil
			if isWarez or not mNodeView[id].Beaten then
				mHoverHighlight.OutlineColor = if isWarez
					then Color3.new(1, 1, 1)
					else Color3.new(1, 0, 0)
				mHoverHighlight.Adornee = mNodeView[id].VisibleModel
				mHoverHighlight.Enabled = true
			else
				mHoverHighlight.Enabled = false
			end
		else
			mHoverHighlight.Enabled = false
		end
	end
	
	-- Journey playback: drive the camera from a recorded session
	function this:PanTo(position)
		mCamera:FocusOn(position, true)
	end
	function this:SetZoomLevel(level)
		mCamera:SetZoom(level)
	end

	function this:GetGui()
		return mGui
	end

	function this:SetNodeBeaten(id)
		local nodeView = mNodeView[id]
		if not nodeView then
			warn("Missing node to set beaten:", id)
			return
		end
		setBeaten(nodeView, true)
		for _, adjId in pairs(Netmap.ById[id].Links) do
			local adjNode = mNodeView[adjId]
			if adjNode then
				setVisible(adjNode, true)
			else
				warn("Missing adjacent node to make visible:", id)
			end
		end
		-- Accessibility may have rippled (adjacency, security upgrades):
		-- re-evaluate every node's popup state
		for _, nodeView in pairs(mNodeView) do
			applyNodeState(nodeView)
		end
	end	

	-- Bumped by every pointer show/replace: pending brief-pointer timers only
	-- clear the pointer if the session is still theirs (so they never clear a
	-- newer pointer, e.g. the tutorial's own)
	local mPointerSession = 0

	-- Glide the camera to a node WITHOUT the pointer arrow (e.g. landing on
	-- the node that was just beaten)
	function this:FocusOnNode(id)
		local node = mNodeView[id]
		if node then
			mCamera:FocusOn(node.CFrame.Position, true)
		else
			warn("Missing node to focus on:", id)
		end
	end

	function this:HighlightNode(id)
		print("Highlight node:", id)
		local node = mNodeView[id]
		if node then
			-- Glide the camera over, and point the node out briefly
			mCamera:FocusOn(node.CFrame.Position, true)
			this:TutorialPointAtNode(id)
			local session = mPointerSession
			task.delay(2.5, function()
				if mPointerSession == session then
					this:ClearTutorialPointer()
				end
			end)
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
		mPointerSession += 1
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
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
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
		mTopbarCredits.SetText(("Credits: %d"):format(credits))
		if mLastShownCredits ~= credits then
			local inset = mTopbarCredits.GetInset()
			if mLastShownCredits ~= nil and inset then
				local delta = credits - mLastShownCredits
				local text = makeCreditUpdateText()
				if delta > 0 then
					text.Text = "+"..delta
					text.TextColor3 = Color3.new(0, 0.4, 0)
				else
					text.Text = ""..delta
					text.TextColor3 = Color3.new(1, 0, 0)
					text.TextStrokeColor3 = Color3.new(0.5, 0, 0)
				end
				text.Parent = inset
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

	-- Idle animations for every REVEALED node (beaten ones too — the living
	-- netmap is the point): each node TYPE animates its "Animate" parts its
	-- own way. All part movement goes through one BulkMoveTo per frame. The
	-- final node keeps its particle effect and hq has no Animate folder, so
	-- neither shows up here.
	local kGlintCycle = 2.2 -- seconds per full shop glint sequence
	local kGlintStagger = 0.45 -- offset between the three signs
	local kGlintLength = 0.3 -- how long each sign glows
	local mBulkParts = {}
	local mBulkCFrames = {}
	local function pushMove(part, cframe)
		table.insert(mBulkParts, part)
		table.insert(mBulkCFrames, cframe)
	end
	local function animateNodeIdles(t)
		table.clear(mBulkParts)
		table.clear(mBulkCFrames)
		for id, nodeView in pairs(mNodeView) do
			local parts = nodeView.AnimateParts
			if parts then
				if nodeView.Seen then
					nodeView.AnimPlaying = true
					local kind = id:sub(1, 2)
					local seed = nodeView.AnimSeed
					if kind == 'ph' then
						-- The rings drift slightly, each on its own phase
						for i, entry in pairs(parts) do
							local phase = seed + i * 2.1
							pushMove(entry.Part, entry.Base * CFrame.new(
								math.sin(t * 0.7 + phase) * 0.15,
								math.sin(t * 0.9 + phase * 1.7) * 0.1,
								math.cos(t * 0.8 + phase) * 0.15))
						end
					elseif kind == 'lm' then
						-- Sporadic sideways glances: smooth noise cubed, so
						-- the head dwells facing forward and occasionally
						-- swings aside
						local noise = math.clamp(math.noise(t * 0.45, seed) * 2.5, -1, 1)
						local angle = noise * noise * noise * math.rad(35)
						for _, entry in pairs(parts) do
							pushMove(entry.Part, entry.Base * CFrame.Angles(0, angle, 0))
						end
					elseif kind == 'ca' then
						-- The globe turns about its axis
						for _, entry in pairs(parts) do
							pushMove(entry.Part, entry.Base * CFrame.Angles(0, t * 0.6, 0))
						end
					elseif kind == 'dr' then
						-- The whole donut floats up and down
						local bob = math.sin(t * 1.4 + seed) * 0.25
						for _, entry in pairs(parts) do
							pushMove(entry.Part, entry.Base + Vector3.new(0, bob, 0))
						end
					elseif kind == 'wz' then
						-- The dollar signs glint one after the other: a
						-- billboard sparkle pulsing over each sign in turn
						-- (world-sized, so it scales with zoom)
						local cycle = (t + seed) % kGlintCycle
						for i, entry in pairs(parts) do
							if not entry.Glint then
								local gui = Instance.new("BillboardGui")
								gui.Name = "Glint"
								gui.Size = UDim2.new(3, 0, 3, 0)
								gui.StudsOffset = Vector3.new(0.3, 0.6, 0)
								gui.LightInfluence = 0
								gui.Parent = entry.Part
								local image = Instance.new("ImageLabel")
								image.BackgroundTransparency = 1
								image.Size = UDim2.new(1, 0, 1, 0)
								image.Image = "rbxasset://textures/particles/sparkles_main.dds"
								image.ImageTransparency = 1
								image.Parent = gui
								entry.Glint = image
							end
							local progress = (cycle - (i - 1) * kGlintStagger) / kGlintLength
							if progress >= 0 and progress < 1 then
								-- One soft pulse with a twirl
								local pulse = math.sin(progress * math.pi)
								entry.Glint.ImageTransparency = 1 - pulse * 0.9
								entry.Glint.Rotation = progress * 90
							elseif entry.Glint.ImageTransparency < 1 then
								entry.Glint.ImageTransparency = 1
							end
						end
					elseif kind == 'pd' then
						-- Only the gavel turns (the chair shares the folder)
						for _, entry in pairs(parts) do
							if entry.Part.Name == "Gavel" then
								pushMove(entry.Part, entry.Base * CFrame.Angles(0, t * 0.9, 0))
							end
						end
					end
				elseif nodeView.AnimPlaying then
					-- Restore the rest pose once when the node un-reveals
					nodeView.AnimPlaying = false
					for _, entry in pairs(parts) do
						pushMove(entry.Part, entry.Base)
						entry.Part.Material = entry.Material
						if entry.Glint then
							entry.Glint.ImageTransparency = 1
						end
					end
				end
			end
		end
		if #mBulkParts > 0 then
			workspace:BulkMoveTo(mBulkParts, mBulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	local function update(dt)
		updateHoveredNode()
		updateTouchHighlights()
		updatePopupBackings()
		local t = os.clock()
		animatePopups(t)
		animateBlinkenlights(t)
		animateNodeIdles(t)
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
				-- The update loop stops while hidden: clear the touch-mode
				-- highlights now or they'd linger through the databattle
				updateTouchHighlights()
			end
		end
	end
	
	setupNetmap()
	setupLinks()
	setupNodes()

	-- Keep the node popups in sync with whether the netmap is actually on
	-- screen. Watching the gui's Visible property covers both SetVisible and
	-- the tutorial's direct Visible toggling.
	mGui:GetPropertyChangedSignal("Visible"):Connect(function()
		for _, nodeView in pairs(mNodeView) do
			if nodeView.Popup then
				nodeView.Popup.Billboard.Enabled = mGui.Visible
				-- The backing is world geometry: hide it too (the update loop
				-- that positions it only runs while the netmap is visible)
				nodeView.Popup.Backing.Transparency = mGui.Visible and 0 or 1
			end
		end
		if mGui.Visible then
			updatePopupBackings()
		end
	end)

	return this
end

return Netmap3DView
