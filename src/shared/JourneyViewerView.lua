--!strict
-- Dev-only viewer for recorded session journeys (the UX study tool): a list
-- of recent sessions, and per session a timeline of every recorded event
-- with the GAP since the previous event highlighted — the gaps are the
-- point: they show where players hesitate.
--
-- provider: { List = () -> {summary}?, Get = (key) -> record? } — MainView
-- passes remote-backed functions; specs pass fakes. Summaries: {Key, Name,
-- UserId, Start, EventCount, Duration}. Records: {Name, Start, Events =
-- {{t, event, detail?}}}.

local Signal = require(game.ReplicatedStorage.Signal)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)
local Win95Scrollbar = require(game.ReplicatedStorage.Components.Win95Scrollbar)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"

local function formatClock(t: number): string
	return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end

local function formatDate(unixTime: number): string
	return os.date("%m-%d %H:%M", unixTime) :: any
end

-- Gap color: fast = quiet gray, thinking = amber, stuck = red
local function gapColor(gap: number): Color3
	if gap >= 10 then
		return Color3.fromRGB(200, 40, 40)
	elseif gap >= 3 then
		return Color3.fromRGB(190, 130, 0)
	else
		return Color3.new(0.45, 0.45, 0.45)
	end
end

type ViewerState = {
	mode: string, -- 'list' | 'timeline'
	statusText: string,
	sessions: { any },
	timelineTitle: string,
	events: { any }, -- {{t, event, detail?}}
	onPick: (key: string, title: string) -> (),
	onBack: () -> (),
	onClose: () -> (),
	onWatch: () -> (),
}

local function sessionRow(summary: any, i: number, onPick: (key: string, title: string) -> ())
	local title = string.format("%s  %s  (%d ev, %s)",
		formatDate(summary.Start or 0), summary.Name or "?", summary.EventCount or 0,
		formatClock(summary.Duration or 0))
	return e("TextButton", {
		LayoutOrder = i,
		Size = UDim2.new(1, -18, 0, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = Color3.new(0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = title,
		[React.Event.MouseButton1Click] = function()
			onPick(summary.Key, title)
		end,
	})
end

local function timelineRow(entry: any, previousT: number, i: number)
	local t, event, detail = entry[1], entry[2], entry[3]
	local gap = math.max(0, t - previousT)
	return e("Frame", {
		LayoutOrder = i,
		Size = UDim2.new(1, -18, 0, 18),
		BackgroundTransparency = 1,
	}, {
		Gap = e("TextLabel", {
			Size = UDim2.new(0, 64, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = gapColor(gap),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = if i == 1 then "" else string.format("+%.1fs", gap),
		}),
		Clock = e("TextLabel", {
			Position = UDim2.new(0, 72, 0, 0),
			Size = UDim2.new(0, 52, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = Color3.new(0.35, 0.35, 0.35),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = formatClock(t),
		}),
		Event = e("TextLabel", {
			Position = UDim2.new(0, 128, 0, 0),
			Size = UDim2.new(1, -128, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = Color3.new(0, 0, 0.5),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			RichText = true,
			Text = "<b>" .. event .. "</b>" .. (if detail then "  " .. detail else ""),
		}),
	})
end

local function JourneyViewerContent(props: ViewerState)
	local scrollRef = React.useRef(nil)

	local items: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 3),
		}),
	}
	if props.mode == "list" then
		for i, summary in pairs(props.sessions) do
			items["Row" .. i] = sessionRow(summary, i, props.onPick)
		end
	else
		local previousT = 0
		for i, entry in pairs(props.events) do
			items["Row" .. i] = timelineRow(entry, previousT, i)
			previousT = entry[1]
		end
	end

	return e("ImageLabel", {
		Name = "JourneyWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 620, 0, 360),
		ZIndex = 2,
		BackgroundTransparency = 1,
		Image = kWindowImage,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = kWindowSliceCenter,
		ImageRectSize = kWindowImageRectSize,
	}, {
		WindowTitle = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0, 12),
			Size = UDim2.new(1, -12, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if props.mode == "list" then "Player Journeys" else props.timelineTitle,
		}),
		StatusText = e("TextLabel", {
			Position = UDim2.new(0, 10, 0, 26),
			Size = UDim2.new(1, -20, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			TextColor3 = Color3.new(0.35, 0.35, 0.35),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = props.statusText,
		}),
		ListArea = e("Frame", {
			Position = UDim2.new(0, 10, 0, 44),
			Size = UDim2.new(1, -20, 1, -96),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, {
			JourneyScroll = e("ScrollingFrame", {
				ref = scrollRef,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
			}, items),
			Scrollbar = e(Win95Scrollbar, {
				scrollRef = scrollRef,
				lineScroll = 19,
			}),
		}),
		BackButton = e(WindowsButton, {
			Name = "BackButton",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -8),
			Size = UDim2.new(0, 140, 0, 36),
			Visible = props.mode == "timeline",
			Text = "Back to List",
			OnClick = props.onBack,
		}),
		WatchButton = e(WindowsButton, {
			Name = "WatchButton",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(0, 160, 0, 36),
			ImageColor3 = Color3.new(0, 0, 1),
			Visible = props.mode == "timeline" and #props.events > 0,
			OnClick = props.onWatch,
		}, {
			Text = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -1),
				Size = UDim2.new(1, -20, 0, 24),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 18,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "Watch Playback",
			}),
		}),
		CloseButton = e(WindowsButton, {
			Name = "CloseButton",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.new(0, 140, 0, 36),
			Text = "Close",
			OnClick = props.onClose,
		}),
	})
end

local JourneyViewerView = {}

function JourneyViewerView.new(container: Instance, provider: any)
	local this = {}

	this.Done = Signal.new()
	this.WatchRequested = Signal.new() -- (record)

	local mCurrentRecord = nil

	local mGui = Instance.new("ImageButton")
	mGui.Name = "JourneyMouseCatcher"
	local guiInset = game:GetService("GuiService"):GetGuiInset()
	mGui.Position = UDim2.new(0, 0, 0, -guiInset.Y)
	mGui.Size = UDim2.new(1, 0, 1, guiInset.Y)
	mGui.BackgroundColor3 = Color3.new(0, 0, 0)
	mGui.BackgroundTransparency = 0.5
	mGui.BorderSizePixel = 0
	mGui.ZIndex = 7
	mGui.Image = ""
	mGui.AutoButtonColor = false

	local mDestroyed = false
	local mRoot

	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		ModalManager:SetModal(false)
		mRoot.unmount()
		mGui:Destroy()
		this.Done:fire()
	end

	mRoot = StatefulRoot.create(mGui, JourneyViewerContent, {
		mode = "list",
		statusText = "Loading sessions...",
		sessions = {},
		timelineTitle = "",
		events = {},
		onPick = function(key: string, title: string)
			mRoot.setState({ mode = "timeline", timelineTitle = title, events = {}, statusText = "Loading..." })
			task.spawn(function()
				local record = provider.Get(key)
				if mDestroyed then
					return
				end
				if record and record.Events then
					mCurrentRecord = record
					mRoot.setState({
						events = record.Events,
						statusText = #record.Events .. " events. Gap column = time since previous event.",
					})
				else
					mRoot.setState({ statusText = "Failed to load session." })
				end
			end)
		end,
		onBack = function()
			mCurrentRecord = nil
			mRoot.setState({ mode = "list", events = {} })
		end,
		onWatch = function()
			if mCurrentRecord then
				local record = mCurrentRecord
				this:Destroy()
				this.WatchRequested:fire(record)
			end
		end,
		onClose = function()
			this:Destroy()
		end,
	})

	task.spawn(function()
		local sessions = provider.List()
		if mDestroyed then
			return
		end
		if sessions then
			mRoot.setState({
				sessions = sessions,
				statusText = if #sessions == 0
					then "No recorded sessions yet."
					else #sessions .. " recent sessions. Click one for its timeline.",
			})
		else
			mRoot.setState({ statusText = "Failed to load sessions (viewer is owner-only)." })
		end
	end)

	ModalManager:SetModal(true)
	mGui.Parent = container

	return this
end

return JourneyViewerView
