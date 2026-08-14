--!strict
-- React conversion of MainMenuView. Public API is unchanged from the template
-- version: MainMenuView.new(container) parents the view into the container
-- and returns an imperative view object with Show/Hide/Destroy; the host is a
-- MenuMouseCatcher ImageButton whose contents are rendered by React (layout
-- matches ui-reference/ModuleTemplates/MainMenuView.json).
--
-- SoundManager integration: SoundManager:AddSoundSlider/AddMusicSlider expect
-- the imperative WindowsSlider API (a :Set(value) method plus a .Changed
-- signal). The view builds small adapter objects that bridge that API to the
-- React slider component: SoundManager:Set -> setState moves the knob, and
-- drags from the component call back into the adapter, which fires .Changed.

local Signal = require(game.ReplicatedStorage.Signal)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local BuyLevelSkipView = require(game.ReplicatedStorage.BuyLevelSkipView)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)
local WindowsSlider = require(game.ReplicatedStorage.Components.WindowsSlider)
local WindowsTabView = require(game.ReplicatedStorage.Components.WindowsTabView)
local Win95Scrollbar = require(game.ReplicatedStorage.Components.Win95Scrollbar)
local Netmap = require(game.ReplicatedStorage.Netmap)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kSkipImage = "rbxassetid://1396497422"
local kButtonImageNormal = "rbxassetid://1372686003"
local kButtonImageHover = "rbxassetid://1372686004"
local kButtonImagePressed = "rbxassetid://1372686005"

export type BattleContext = {
	skipText: string,
	disabled: boolean,
	onForfeit: () -> (),
	onSkip: () -> (),
}

type MainMenuState = {
	menuScale: number,
	soundValue: number,
	musicValue: number,
	skipsAvailableText: string,
	skipsUsedText: string,
	statsSummary: string?,
	statsCompareText: string?,
	statsSelectedId: string?,
	statsRows: { { Id: string, Text: string } }?,
	onStatsNodeClick: ((id: string) -> ())?,
	badgesEarnedHeader: string?,
	badgesUnearnedHeader: string?,
	badgeRows: { { Name: string, Description: string, Icon: string } }?,
	unearnedBadgeRows: { { Name: string, Description: string, Icon: string } }?,
	badgesPlaceholder: string?,
	battleContext: BattleContext?,
	menuSession: number,
	onDone: () -> (),
	onBuy: () -> (),
	onSoundChanged: (value: number) -> (),
	onMusicChanged: (value: number) -> (),
}

-- Windows button with a tinted body and bold white label (the template's
-- BuyButton is the standard button image tinted blue; the imperative
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

local function sectionLabel(text: string, position: UDim2)
	return e("TextLabel", {
		Position = position,
		Size = UDim2.new(1, -5, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		TextSize = 18,
		TextColor3 = Color3.new(0, 0, 0),
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = text,
	})
end

local function skipsCountText(text: string, position: UDim2)
	return e("TextLabel", {
		Position = position,
		Size = UDim2.new(0.6, -6, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		TextSize = 20,
		TextColor3 = Color3.new(0, 0, 0),
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.8,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
end

local function appendTabs(tabs, more)
	for _, tab in more do
		table.insert(tabs, tab)
	end
	return tabs
end

local function MainMenuContent(props: MainMenuState)
	-- Refs shared between each list and its Win95 scrollbar
	local statsScrollRef = React.useRef(nil)
	local earnedScrollRef = React.useRef(nil)
	local unearnedScrollRef = React.useRef(nil)

	-- One row per badge: icon plus name over description (badge info fetched
	-- from the server, which queries the badge web APIs). Unearned rows
	-- render dimmed.
	local function badgeRowItems(rows, placeholder: string, dimmed: boolean): { [string]: any }
		local items: { [string]: any } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 1),
			}),
			UIPadding = e("UIPadding", {
				PaddingTop = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 2),
			}),
		}
		if #(rows or {}) == 0 then
			items.Placeholder = e("TextLabel", {
				Size = UDim2.new(1, -20, 0, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 14,
				TextColor3 = Color3.new(0.35, 0.35, 0.35),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = placeholder,
			})
		end
		for i, badge in pairs(rows or {}) do
			items["Badge" .. i] = e("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(1, -18, 0, 34),
				BackgroundTransparency = 1,
			}, {
				Icon = e("ImageLabel", {
					Position = UDim2.new(0, 0, 0, 3),
					Size = UDim2.new(0, 28, 0, 28),
					BackgroundTransparency = 1,
					ImageTransparency = if dimmed then 0.55 else 0,
					Image = badge.Icon,
				}),
				NameLabel = e("TextLabel", {
					Position = UDim2.new(0, 36, 0, 2),
					Size = UDim2.new(1, -36, 0, 15),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = 15,
					TextColor3 = if dimmed then Color3.new(0.45, 0.45, 0.45) else Color3.new(0, 0, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = badge.Name,
				}),
				DescriptionLabel = e("TextLabel", {
					Position = UDim2.new(0, 36, 0, 17),
					Size = UDim2.new(1, -36, 0, 13),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 12,
					TextColor3 = if dimmed then Color3.new(0.55, 0.55, 0.55) else Color3.new(0.35, 0.35, 0.35),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = badge.Description,
				}),
			})
		end
		return items
	end

	-- A Win95 listbox holding badge rows (half of the side-by-side pair)
	local function badgeListArea(name: string, scrollRef, xScale: number, rows, placeholder: string, dimmed: boolean)
		return e("Frame", {
			Position = UDim2.new(xScale, if xScale == 0 then 10 else 5, 0, 24),
			Size = UDim2.new(0.5, -15, 1, -30),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, {
			[name .. "Scroll"] = e("ScrollingFrame", {
				ref = scrollRef,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
			}, badgeRowItems(rows, placeholder, dimmed)),
			Scrollbar = e(Win95Scrollbar, {
				scrollRef = scrollRef,
				lineScroll = 35,
			}),
		})
	end

	-- One row per beaten node with its personal bests; clicking a row loads
	-- the my-best / friend-best / world-best comparison
	local statsRowItems: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 2),
		}),
	}
	for i, row in pairs(props.statsRows or {}) do
		local selected = row.Id ~= nil and row.Id == props.statsSelectedId
		statsRowItems["Row" .. i] = e("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1, -20, 0, 18),
			BackgroundColor3 = if selected then Color3.new(0, 0, 0.5) else Color3.new(1, 1, 1),
			BackgroundTransparency = if selected then 0 else 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = 15,
			TextColor3 = if selected then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = row.Text,
			[React.Event.MouseButton1Click] = function()
				if row.Id and props.onStatsNodeClick then
					props.onStatsNodeClick(row.Id)
				end
			end,
		})
	end

	-- During a databattle a "Databattle" tab (forfeit / skip) leads, and is the
	-- default-selected tab
	local tabs = {}
	if props.battleContext then
		local ctx = props.battleContext
		table.insert(tabs, {
			Name = "Databattle",
			Label = "Databattle",
			Content = {
				ForfeitLabel = sectionLabel("Forfeit Databattle", UDim2.new(0, 10, 0, 5)),
				ForfeitButton = e(WindowsButton, {
					Name = "ForfeitButton",
					Position = UDim2.new(0.4, 0, 0, 5),
					Size = UDim2.new(0.6, -6, 0, 36),
					ImageColor3 = if ctx.disabled then Color3.new(0.5, 0.5, 0.5) else nil,
					Text = "Forfeit",
					OnClick = ctx.onForfeit,
				}),
				SkipLabel = sectionLabel("Skip Databattle", UDim2.new(0, 10, 0, 41)),
				SkipButton = e(ColoredWindowsButton, {
					Position = UDim2.new(0.4, 0, 0, 41),
					Size = UDim2.new(0.6, -6, 0, 36),
					ImageColor3 = if ctx.disabled then Color3.new(0.5, 0.5, 0.5) else Color3.new(0, 0, 1),
					Text = ctx.skipText,
					TextSize = 15,
					OnClick = ctx.onSkip,
				}),
			},
		})
	end

	return e("ImageLabel", {
		-- Menu window
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 400, 0, 250),
		ZIndex = 2,
		BackgroundTransparency = 1,
		Image = kWindowImage,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = kWindowSliceCenter,
		ImageRectSize = kWindowImageRectSize,
	}, {
		UIScale = e("UIScale", {
			Scale = props.menuScale,
		}),
		WindowTitle = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0, 12),
			Size = UDim2.new(0, 200, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if props.battleContext then "Databattle Menu" else "Game Menu",
		}),
		CloseButton = e(WindowsButton, {
			Name = "CloseButton",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(0, 160, 0, 36),
			Text = "Close",
			OnClick = props.onDone,
		}),
		-- Keyed by menuSession: each Show remounts the tab view so DefaultTab
		-- re-applies (tab selection is internal component state)
		["TabPanel@" .. props.menuSession] = e(WindowsTabView, {
			Name = "TabPanel",
			Position = UDim2.new(0, 5, 0, 61),
			Size = UDim2.new(1, -10, 1, -105),
			DefaultTab = if props.battleContext then "Databattle" else "Sound",
			Tabs = appendTabs(tabs, {
				{
					Name = "Sound",
					Label = "Sound",
					Content = {
						-- Note the template's double space in the label text
						SoundVolumeLabel = sectionLabel("Sound Effect  Volume", UDim2.new(0, 10, 0, 5)),
						MusicVolumeLabel = sectionLabel("Music Volume", UDim2.new(0, 10, 0, 41)),
						SoundVolume = e(WindowsSlider, {
							Position = UDim2.new(0.4, 0, 0, 5),
							Size = UDim2.new(0.6, -6, 0, 36),
							Value = props.soundValue,
							LeftLabel = "Muted",
							RightLabel = "RIP Eardrums",
							OnChanged = props.onSoundChanged,
						}),
						MusicVolume = e(WindowsSlider, {
							Position = UDim2.new(0.4, 0, 0, 41),
							Size = UDim2.new(0.6, -6, 0, 36),
							Value = props.musicValue,
							LeftLabel = "Muted",
							RightLabel = "DAT BASS",
							OnChanged = props.onMusicChanged,
						}),
					},
				},
				{
					Name = "Skips",
					Label = "Level Skips",
					Content = {
						SkipsAvailableLabel = sectionLabel("Level skips available", UDim2.new(0, 10, 0, 5)),
						SkipsUsedLabel = sectionLabel("Level skips used", UDim2.new(0, 10, 0, 41)),
						SkipsAvailable = skipsCountText(props.skipsAvailableText, UDim2.new(0.4, 0, 0, 5)),
						SkipsUsed = skipsCountText(props.skipsUsedText, UDim2.new(0.4, 0, 0, 41)),
						SkipImage = e("ImageLabel", {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -5, 0, 5),
							Size = UDim2.new(0, 72, 0, 72),
							BackgroundTransparency = 1,
							Image = kSkipImage,
						}),
						BuyButton = e(ColoredWindowsButton, {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, 41),
							Size = UDim2.new(0, 180, 0, 36),
							ImageColor3 = Color3.new(0, 0, 1),
							Text = "BUY MORE LEVEL SKIPS",
							OnClick = props.onBuy,
						}),
					},
				},
				{
					Name = "Stats",
					Label = "Statistics",
					Content = {
						SummaryLabel = e("TextLabel", {
							Position = UDim2.new(0, 10, 0, 4),
							Size = UDim2.new(1, -20, 0, 20),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSansBold,
							TextSize = 16,
							TextColor3 = Color3.new(0, 0, 0.5),
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = props.statsSummary or "",
						}),
						-- The my/friend/world comparison for the clicked node
						CompareText = e("TextLabel", {
							Position = UDim2.new(0, 10, 0, 24),
							Size = UDim2.new(1, -20, 0, 58),
							BackgroundTransparency = 1,
							Font = Enum.Font.Code,
							TextSize = 13,
							TextColor3 = Color3.new(0, 0, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							Text = props.statsCompareText or "",
						}),
						-- Personal bests per beaten node, Win95 listbox style
						ListArea = e("Frame", {
							Position = UDim2.new(0, 10, 0, 86),
							Size = UDim2.new(1, -20, 1, -92),
							BackgroundColor3 = Color3.new(1, 1, 1),
							BorderSizePixel = 0,
						}, {
							StatsScroll = e("ScrollingFrame", {
								ref = statsScrollRef,
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								ScrollBarThickness = 0,
							}, statsRowItems),
							Scrollbar = e(Win95Scrollbar, {
								scrollRef = statsScrollRef,
								lineScroll = 19,
							}),
						}),
					},
				},
				{
					Name = "Badges",
					Label = "Badges",
					Content = {
						-- Side-by-side listboxes: earned on the left, still
						-- to be earned (dimmed) on the right
						EarnedHeader = e("TextLabel", {
							Position = UDim2.new(0, 10, 0, 4),
							Size = UDim2.new(0.5, -15, 0, 18),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSansBold,
							TextSize = 16,
							TextColor3 = Color3.new(0, 0, 0.5),
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = props.badgesEarnedHeader or "Earned",
						}),
						UnearnedHeader = e("TextLabel", {
							Position = UDim2.new(0.5, 5, 0, 4),
							Size = UDim2.new(0.5, -15, 0, 18),
							BackgroundTransparency = 1,
							Font = Enum.Font.SourceSansBold,
							TextSize = 16,
							TextColor3 = Color3.new(0, 0, 0.5),
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = props.badgesUnearnedHeader or "Not Yet",
						}),
						EarnedArea = badgeListArea("Earned", earnedScrollRef, 0,
							props.badgeRows, props.badgesPlaceholder or "None yet.", false),
						UnearnedArea = badgeListArea("Unearned", unearnedScrollRef, 0.5,
							props.unearnedBadgeRows, props.badgesPlaceholder or "You got them all!", true),
					},
				},
			}),
		}),
	})
end

local MainMenuView = {}

function MainMenuView.new(container: Instance)
	local this = {}

	local mGui = Instance.new("ImageButton")
	mGui.Name = "MenuMouseCatcher"
	-- Extended past the topbar inset so the dim covers the full screen
	local guiInset = game:GetService("GuiService"):GetGuiInset()
	mGui.Position = UDim2.new(0, 0, 0, -guiInset.Y)
	mGui.Size = UDim2.new(1, 0, 1, guiInset.Y)
	mGui.BackgroundColor3 = Color3.new(0, 0, 0)
	mGui.BackgroundTransparency = 0.5
	mGui.BorderSizePixel = 0
	mGui.ZIndex = 6
	mGui.Image = ""
	mGui.AutoButtonColor = false
	mGui.Visible = false

	-- Forward-declared so the slider adapters (whose callbacks are wired up
	-- during create) can setState; assigned right after StatefulRoot.create.
	local mRoot: StatefulRoot.StatefulRoot? = nil

	-- Statistics panel: summary + per-node rows, and the my/friend/world
	-- comparison for a clicked row (records fetched from the server's
	-- per-node ordered stores; friends via GetFriendsAsync)
	local mStatsNodes = {} -- id -> { BestTurns, BestMoves, BestUnits }
	local mSelectedStatsNode = nil

	local kStatOrder = { "turns", "moves", "units" }
	local kStatLetter = { turns = "T", moves = "M", units = "S" }
	local function formatRecordLine(rec)
		if not rec or not next(rec) then
			return "no record yet"
		end
		local parts = {}
		local singleName = nil
		local mixedNames = false
		for _, stat in pairs(kStatOrder) do
			local entry = rec[stat]
			if entry then
				if singleName == nil then
					singleName = entry.Name
				elseif entry.Name ~= singleName then
					mixedNames = true
				end
			end
		end
		for _, stat in pairs(kStatOrder) do
			local entry = rec[stat]
			if entry then
				local part = entry.Value .. kStatLetter[stat]
				if mixedNames and entry.Name then
					part = part .. " (" .. entry.Name .. ")"
				end
				table.insert(parts, part)
			end
		end
		local line = table.concat(parts, " · ")
		if not mixedNames and singleName then
			line = line .. "  (" .. singleName .. ")"
		end
		return line
	end

	local function setCompareText(nodeId, friendLine, worldLine)
		local mine = mStatsNodes[nodeId]
		local youLine = if mine
			then string.format("%dT · %dM · %dS", mine.BestTurns, mine.BestMoves, mine.BestUnits)
			else "no win yet"
		if mRoot then
			mRoot.setState({
				statsSelectedId = nodeId,
				statsCompareText = Netmap.GetNodeDisplayName(nodeId) .. "\n"
					.. "You:    " .. youLine .. "\n"
					.. "Friend: " .. friendLine .. "\n"
					.. "World:  " .. worldLine,
			})
		end
	end

	local function selectStatsNode(nodeId)
		mSelectedStatsNode = nodeId
		setCompareText(nodeId, "fetching...", "fetching...")
		task.spawn(function()
			local ok, records = pcall(function()
				return game.ReplicatedStorage.Remotes.GetNodeRecords:InvokeServer(nodeId)
			end)
			if mSelectedStatsNode ~= nodeId then
				return -- a different node was picked while fetching
			end
			if ok and records then
				setCompareText(nodeId, formatRecordLine(records.Friend), formatRecordLine(records.World))
			else
				setCompareText(nodeId, "unavailable", "unavailable")
			end
		end)
	end

	-- Refresh the statistics panel content from local player data
	local function updateStats()
		local ok, stats = pcall(function()
			return LocalPlayerData:GetProgressStats()
		end)
		if not ok then
			return -- player data not loaded yet
		end
		local rows = {}
		mStatsNodes = {}
		for _, node in pairs(stats.Nodes) do
			mStatsNodes[node.Id] = node
			table.insert(rows, {
				Id = node.Id,
				Text = string.format("%s  —  %d turns, %d moves, %d scripts",
					Netmap.GetNodeDisplayName(node.Id), node.BestTurns, node.BestMoves, node.BestUnits),
			})
		end
		if #rows == 0 then
			rows = { { Text = "No battles won yet." } }
		end
		if mRoot then
			mRoot.setState({
				statsSummary = string.format("Nodes beaten: %d/%d    Wins: %d    Attempts: %d",
					stats.BattleNodesBeaten, stats.BattleNodesTotal, stats.Wins, stats.Attempts),
				statsRows = rows,
				statsCompareText = if #rows > 0 and rows[1].Id
					then "Click a node to compare with friends and the world."
					else "",
				statsSelectedId = StatefulRoot.None,
			})
		end
		mSelectedStatsNode = nil
	end

	-- Refresh the badges panel from the server (which queries the badge web
	-- APIs and caches; no badge data is stored in player data). Existing rows
	-- stay up while a refresh is in flight.
	local mBadgesFetching = false
	local function updateBadges()
		if mBadgesFetching then
			return
		end
		mBadgesFetching = true
		task.spawn(function()
			local ok, result = pcall(function()
				return game.ReplicatedStorage.Remotes.GetBadges:InvokeServer()
			end)
			mBadgesFetching = false
			if not mRoot then
				return
			end
			if ok and result then
				local function toRows(entries)
					local rows = {}
					for _, badge in pairs(entries) do
						table.insert(rows, {
							Name = badge.Name,
							Description = badge.Description,
							Icon = if badge.IconImageId ~= 0 then "rbxassetid://" .. badge.IconImageId else "",
						})
					end
					return rows
				end
				local earned = toRows(result.Earned)
				local unearned = toRows(result.Unearned or {})
				mRoot.setState({
					badgesEarnedHeader = string.format("Earned (%d)", #earned),
					badgesUnearnedHeader = string.format("Not Yet (%d)", #unearned),
					badgeRows = earned,
					unearnedBadgeRows = unearned,
					-- Per-list defaults take over ("None yet." / "You got them all!")
					badgesPlaceholder = StatefulRoot.None,
				})
			else
				mRoot.setState({ badgesPlaceholder = "Badge list unavailable." })
			end
		end)
	end

	-- Show / hide the menu
	local mSession = 0
	function this:Show()
		ModalManager:SetModal(true)
		updateStats()
		updateBadges()
		-- Remount the tab view so the default tab re-applies on each open
		mSession += 1
		if mRoot then
			mRoot.setState({ menuSession = mSession })
		end
		mGui.Visible = true
	end
	function this:Hide()
		mGui.Visible = false
		ModalManager:SetModal(false)
	end

	-- Attach/detach the in-databattle context (adds the default-selected
	-- Databattle tab with forfeit/skip). Pass nil when the battle ends.
	function this:SetBattleContext(context: BattleContext?)
		if mRoot then
			mRoot.setState({ battleContext = context or StatefulRoot.None })
		end
	end

	local function makeSliderAdapter(stateKey: string)
		local adapter = {}

		adapter.Changed = Signal.new(--[[new, old]])

		local mValue = 0

		function adapter:Set(value: number)
			if mValue ~= value then
				local old = mValue
				mValue = value
				if mRoot then
					mRoot.setState({ [stateKey] = value })
				end
				adapter.Changed:fire(value, old)
			end
		end

		function adapter:Get()
			return mValue
		end

		function adapter:Destroy()
			-- The imperative slider disconnected its input connections here;
			-- the React slider's connections are torn down with the render
			-- tree instead.
		end

		return adapter
	end

	local mMusicSlider = makeSliderAdapter("musicValue")
	local mSoundSlider = makeSliderAdapter("soundValue")

	mRoot = StatefulRoot.create(mGui, MainMenuContent, {
		menuScale = if DeviceInfo.ScreenHeight > 400 then 1.2 else 1,
		soundValue = 0,
		musicValue = 0,
		-- Template placeholder text, replaced once player data is available
		skipsAvailableText = "5 skips",
		skipsUsedText = "5 skips",
		statsSummary = "",
		statsCompareText = "",
		statsSelectedId = nil,
		statsRows = {},
		onStatsNodeClick = function(id: string)
			selectStatsNode(id)
		end,
		badgesEarnedHeader = nil,
		badgesUnearnedHeader = nil,
		badgeRows = {},
		unearnedBadgeRows = {},
		badgesPlaceholder = "Fetching badges...",
		battleContext = nil,
		menuSession = 0,
		onDone = function()
			this:Hide()
		end,
		onBuy = function()
			BuyLevelSkipView.new(container)
		end,
		onSoundChanged = function(value: number)
			mSoundSlider:Set(value)
		end,
		onMusicChanged = function(value: number)
			mMusicSlider:Set(value)
		end,
	})
	local root = mRoot :: StatefulRoot.StatefulRoot

	-- Sound stuff
	SoundManager:AddSoundSlider(mSoundSlider)
	SoundManager:AddMusicSlider(mMusicSlider)

	-- Skips stuff
	local function updateSkipsText()
		local available, used = LocalPlayerData:GetSkips()
		if available then
			root.setState({
				skipsAvailableText = available .. " skips",
				skipsUsedText = used .. " skips",
			})
		end
	end
	updateSkipsText()
	local mSkipsUpdateCn = LocalPlayerData.SkipsChanged:connect(updateSkipsText)

	-- Stats
	-- TODO: implement stats

	function this:Destroy()
		mSkipsUpdateCn:disconnect()
		mSoundSlider:Destroy()
		mMusicSlider:Destroy()
		root.unmount()
		mGui:Destroy()
	end

	mGui.Parent = container

	return this
end

return MainMenuView
