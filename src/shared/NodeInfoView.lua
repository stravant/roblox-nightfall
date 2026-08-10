--!strict
-- React conversion of NodeInfoView. Public API is unchanged from the template
-- version: NodeInfoView.new(container, nodeId) parents the view into the
-- container and returns an imperative view object with Show/Hide/Destroy; the
-- host is a MenuMouseCatcher ImageButton whose contents are rendered by React
-- (layout matches ui-reference/ModuleTemplates/NodeInfoView.json).
--
-- The stats tab starts on the template's placeholder text and re-renders from
-- state when the async NodeStatsCache fetch completes. The template version's
-- stats quirks are preserved verbatim (see the fetch task below).

local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local NodeStatsCache = require(game.ReplicatedStorage.NodeStatsCache)
local Netmap = require(game.ReplicatedStorage.Netmap)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)
local WindowsTabView = require(game.ReplicatedStorage.Components.WindowsTabView)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kSkipImage = "rbxassetid://1396497422"
local kDividerImage = "rbxassetid://1375318214"
local kButtonImageNormal = "rbxassetid://1372686003"
local kButtonImageHover = "rbxassetid://1372686004"
local kButtonImagePressed = "rbxassetid://1372686005"

type NodeInfoState = {
	canAccess: boolean,
	noEntryText: string,
	nodeName: string,
	nodeOrg: string,
	nodeMission: string,
	turnsText: string,
	turnsAverage: string,
	turnsPlayer: string,
	movesText: string,
	movesAverage: string,
	movesPlayer: string,
	unitsText: string,
	unitsPlayer: string,
	onEnter: () -> (),
	onCancel: () -> (),
}

-- Windows button with a tinted body and bold white label (the template's
-- EnterButton is the standard button image tinted blue; the imperative
-- WindowsButton.new applied its hover/press image swaps over the tint).
type ColoredButtonProps = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	Visible: boolean?,
	ImageColor3: Color3,
	Text: string,
	TextSize: number?,
	OnClick: (() -> ())?,
}

local function ColoredWindowsButton(props: ColoredButtonProps)
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)

	local image = kButtonImageNormal
	if pressed then
		image = kButtonImagePressed
	elseif hovered and not DeviceInfo.Touch then
		image = kButtonImageHover
	end

	return e("ImageButton", {
		Image = image,
		ImageColor3 = props.ImageColor3,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(8, 8, 8, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 2,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		Visible = props.Visible,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
	}, {
		Text = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -1),
			Size = UDim2.new(1, -20, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = props.TextSize or 18,
			TextColor3 = Color3.new(1, 1, 1),
			Text = props.Text,
		}),
	})
end

-- Info tab row label ("Node Id" / "Proprietor" / "Mission")
local function infoLabel(text: string, y: number)
	return e("TextLabel", {
		Position = UDim2.new(0, 10, 0, y),
		Size = UDim2.new(1, -5, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		TextSize = 18,
		TextColor3 = Color3.new(0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = text,
	})
end

-- Info tab row value (bold, right of the label)
local function infoText(text: string, y: number)
	return e("TextLabel", {
		Position = UDim2.new(0, 90, 0, y),
		Size = UDim2.new(0.65, -6, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		TextSize = 20,
		TextColor3 = Color3.new(0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
end

-- Stats tab section divider: a horizontal rule with a small solid-background
-- caption sitting on top of it
local function statDivider(text: string, width: number, y: number)
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.new(1, -8, 0, 2),
		BackgroundTransparency = 1,
		Image = kDividerImage,
		ImageRectOffset = Vector2.new(12, 64),
		ImageRectSize = Vector2.new(4, 2),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(0, 2, 0, 2),
	}, {
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(0, width, 0, 16),
			BackgroundColor3 = Color3.new(0.752941, 0.752941, 0.752941),
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			TextColor3 = Color3.new(0, 0, 0),
			Text = text,
		}),
	})
end

-- Stats tab value line with optional Average / Player sub-labels
local function statText(text: string, y: number, averageText: string?, playerText: string?)
	local children: { [string]: any } = {}
	if averageText ~= nil then
		children.Average = e("TextLabel", {
			Position = UDim2.new(0, 0, 0, 18),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			TextColor3 = Color3.new(0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = averageText,
		})
	end
	if playerText ~= nil then
		children.Player = e("TextLabel", {
			Position = UDim2.new(0, 80, 0, 0),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 20,
			TextColor3 = Color3.new(0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = playerText,
		})
	end
	return e("TextLabel", {
		Position = UDim2.new(0, 8, 0, y),
		Size = UDim2.new(0.65, -6, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		TextSize = 20,
		TextColor3 = Color3.new(0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = text,
	}, children)
end

local function NodeInfoContent(props: NodeInfoState)
	return e("ImageLabel", {
		-- Menu window
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 300, 0, 260),
		ZIndex = 3,
		BackgroundTransparency = 1,
		Image = kWindowImage,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = kWindowSliceCenter,
		ImageRectSize = kWindowImageRectSize,
	}, {
		WindowTitle = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0, 12),
			Size = UDim2.new(0, 200, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Access Node",
		}),
		TabPanel = e(WindowsTabView, {
			Position = UDim2.new(0, 5, 0, 61),
			Size = UDim2.new(1, -10, 1, -105),
			DefaultTab = "Info",
			Tabs = {
				{
					Name = "Info",
					Label = "Information",
					Content = {
						NameLabel = infoLabel("Node Id", 0),
						ProprietorLabel = infoLabel("Proprietor", 28),
						MissionLabel = infoLabel("Mission", 56),
						NameText = infoText(props.nodeName, 0),
						ProprietorText = infoText(props.nodeOrg, 28),
						MissionText = e("TextLabel", {
							Position = UDim2.new(0, 90, 0, 66),
							Size = UDim2.new(1, -90, 0, 100),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSans,
							TextSize = 16,
							TextColor3 = Color3.new(0, 0, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							TextWrapped = true,
							Text = props.nodeMission,
						}),
						SkipImage = e("ImageLabel", {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -5, 0, 5),
							Size = UDim2.new(0, 72, 0, 72),
							BackgroundTransparency = 1,
							Image = kSkipImage,
							Visible = false,
						}),
					},
				},
				{
					Name = "Stats",
					Label = "Statistics",
					Content = {
						TurnsLabel = statDivider("Least Turns Taken", 91, 8),
						MovesLabel = statDivider("Least Unit Moves", 86, 60),
						UnitsLabel = statDivider("Least Units Used", 84, 112),
						TurnsText = statText(props.turnsText, 16, props.turnsAverage, props.turnsPlayer),
						MovesText = statText(props.movesText, 68, props.movesAverage, props.movesPlayer),
						UnitsText = statText(props.unitsText, 120, nil, props.unitsPlayer),
						SkipImage = e("ImageLabel", {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -5, 0, 5),
							Size = UDim2.new(0, 72, 0, 72),
							BackgroundTransparency = 1,
							Visible = false,
						}),
					},
				},
			},
		}),
		EnterButton = e(ColoredWindowsButton, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -5, 1, -5),
			Size = UDim2.new(0.5, -7, 0, 36),
			Visible = props.canAccess,
			ImageColor3 = Color3.new(0, 0, 1),
			Text = "Enter Databattle!",
			OnClick = props.onEnter,
		}),
		CancelButton = e(WindowsButton, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 5, 1, -5),
			Size = UDim2.new(0.5, -7, 0, 36),
			Text = "Return to Netmap",
			OnClick = props.onCancel,
		}),
		-- Static red button; the template version never gave the no-entry
		-- button WindowsButton hover/press behavior.
		NoEntryButton = e("ImageButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -5, 1, -5),
			Size = UDim2.new(0.5, -7, 0, 36),
			Visible = not props.canAccess,
			BackgroundTransparency = 1,
			Image = kButtonImagePressed,
			ImageColor3 = Color3.new(1, 0, 0),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(8, 8, 8, 8),
			BorderSizePixel = 2,
		}, {
			Text = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -1),
				Size = UDim2.new(1, -20, 0, 24),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1),
				Text = props.noEntryText,
			}),
		}),
	})
end

local NodeInfoView = {}

function NodeInfoView.new(container: Instance, nodeId: string)
	local this = {}

	local mNodeData = Netmap.ById[nodeId]

	local mGui = Instance.new("ImageButton")
	mGui.Name = "MenuMouseCatcher"
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundColor3 = Color3.new(0, 0, 0)
	mGui.BackgroundTransparency = 0.5
	mGui.BorderSizePixel = 0
	mGui.ZIndex = 6
	mGui.Image = ""
	mGui.AutoButtonColor = false

	-- Wait for done
	local mWaitForDone = Instance.new("BindableEvent")

	-- Show / hide the menu
	function this:Show()
		mGui.Visible = true
	end
	function this:Hide()
		mGui.Visible = false
	end

	-- Set up enter / no entry button state
	local canAccess = LocalPlayerData:CanAccessNode(nodeId)
	local noEntryText = "No Connection\nAvailable"
	if not canAccess then
		if LocalPlayerData:GetSecurityLevel() >= mNodeData.Level then
			noEntryText = "No Connection\nAvailable"
		else
			noEntryText = "Insufficient\nSecurity Level"
		end
	end

	local mRoot = StatefulRoot.create(mGui, NodeInfoContent, {
		canAccess = canAccess,
		noEntryText = noEntryText,
		nodeName = mNodeData.Name,
		nodeOrg = mNodeData.Org,
		nodeMission = mNodeData.Mission,
		-- Stats tab placeholders from the template, shown until the async
		-- fetch completes. (The template's moves placeholder said "turns
		-- taken"; kept verbatim.)
		turnsText = "6 turns",
		turnsAverage = "(average turns taken = 5.5)",
		turnsPlayer = "by Stravant",
		movesText = "5 moves",
		movesAverage = "(average turns taken = 5.5)",
		movesPlayer = "by Stravant",
		unitsText = "5 units",
		unitsPlayer = "by Stravant",
		onEnter = function()
			mWaitForDone:Fire(true)
		end,
		onCancel = function()
			-- The template version connected the cancel button twice — once
			-- hiding the view and once firing false — so a click does both.
			this:Hide()
			mWaitForDone:Fire(false)
		end,
	})

	-- Set up stats tab
	local mStatsThread = task.spawn(function()
		local stats = NodeStatsCache:Get(nodeId)

		-- Moves
		local name, moves = stats:GetLeastMoves()
		local avg = stats:GetAverageMoves()
		mRoot.setState({
			movesText = moves .. " moves",
			movesAverage = "(average moves used = " .. avg .. ")",
			movesPlayer = "by " .. name,
		})

		-- Turns
		local name, turns = stats:GetLeastTurns()
		local avg = stats:GetAverageTurns()
		mRoot.setState({
			turnsText = turns .. " turns",
			turnsAverage = "(average turns taken = " .. avg .. ")",
			turnsPlayer = "by " .. name,
		})

		-- Units
		-- Preserved verbatim from the template version, which wrote the
		-- units stats over the moves line, using the moves count for the
		-- text and the units record holder for the player.
		local name, units = stats:GetLeastUnits()
		mRoot.setState({
			movesText = moves .. " units",
			movesPlayer = "by " .. name,
		})
	end)

	function this:Destroy()
		if coroutine.status(mStatsThread) ~= "dead" then
			task.cancel(mStatsThread)
		end
		mRoot.unmount()
		mGui:Destroy()
	end

	mGui.Parent = container

	return this
end

return NodeInfoView
