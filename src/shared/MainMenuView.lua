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
local GameSpeed = require(game.ReplicatedStorage.GameSpeed)
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
local Places = require(game.ReplicatedStorage.Places)
local JourneyRecorder = require(game.ReplicatedStorage.JourneyRecorder)

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
	menuWidth: number,
	menuHeight: number,
	speedValue: number,
	soundValue: number,
	musicValue: number,
	skipsAvailableText: string,
	skipsUsedText: string,
	statsSummary: string?,
	statsSelectedId: string?,
	-- Node thumbnail rail: nodes in security-level order with dividers
	statsNodeList: { { Kind: string, Id: string?, Text: string?, PlaceId: string?, Beaten: boolean?, Y: number } }?,
	-- nil = the general overview pane; set = the selected node's rich view
	statsDetail: {
		Id: string,
		Name: string,
		PlaceId: string?,
		SubLine: string,
		You: { turns: number?, moves: number?, units: number? }?,
		Friend: any, -- "pending" | "unavailable" | { [stat]: {Value, Name} }
		World: any,
	}?,
	defaultTab: string?,
	onPlayAgain: ((nodeId: string) -> ())?,
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
	onSpeedChanged: (value: number) -> (),
}

-- Windows button with a tinted body and bold white label (the template's
-- BuyButton is the standard button image tinted blue; the imperative
-- WindowsButton.new applied its hover/press image swaps over the tint).
type ColoredButtonProps = {
	Name: string?,
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
		Name = props.Name,
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

-- Miniature copy of a node's databattle layout (board tiles, upload zones,
-- pickups, pre-placed units) at cellPx pixels per board square, as the
-- children of a (16*cellPx) x (12*cellPx) frame. dimmed renders just a dark
-- silhouette of the board shape (unbeaten nodes). Horizontal runs of tiles
-- merge into single frames: the stats rail shows dozens of these minis, and
-- per-tile frames would be thousands of instances.
local function miniLayoutItems(placeId: string?, cellPx: number, dimmed: boolean): { [string]: any }
	local place = placeId and Places[placeId]
	local items: { [string]: any } = {}
	if not place then
		return items
	end
	local tileColor = if dimmed then Color3.fromRGB(40, 42, 50) else Color3.fromRGB(185, 196, 214)
	for y = 1, 12 do
		local runStart = nil
		for x = 1, 17 do
			local filled = x <= 16 and place.MapData[x][y]
			if filled and not runStart then
				runStart = x
			elseif not filled and runStart then
				items["R" .. y .. "_" .. runStart] = e("Frame", {
					Position = UDim2.new(0, (runStart - 1) * cellPx, 0, (y - 1) * cellPx),
					Size = UDim2.new(0, (x - runStart) * cellPx - 1, 0, cellPx - 1),
					BackgroundColor3 = tileColor,
					BorderSizePixel = 0,
				})
				runStart = nil
			end
		end
	end
	if dimmed then
		return items
	end
	local function overlay(key, coord, color)
		items[key] = e("Frame", {
			Position = UDim2.new(0, (coord.x - 1) * cellPx, 0, (coord.y - 1) * cellPx),
			Size = UDim2.new(0, cellPx - 1, 0, cellPx - 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	end
	for i, zone in ipairs(place.UploadZones) do
		overlay("Z" .. i, zone, Color3.fromRGB(60, 140, 255))
	end
	for i, coord in ipairs(place.ExtraCreditList) do
		overlay("C" .. i, coord, Color3.fromRGB(222, 185, 50))
	end
	for i, coord in ipairs(place.CodeList) do
		overlay("K" .. i, coord, Color3.fromRGB(70, 200, 100))
	end
	for u, unitEntry in ipairs(place.ProgramList) do
		local color = if unitEntry.Type == 'enemy'
			then Color3.fromRGB(200, 45, 45)
			else Color3.fromRGB(90, 190, 90)
		for s, coord in ipairs(unitEntry.Tail) do
			overlay("U" .. u .. "_" .. s, coord, color)
		end
	end
	return items
end

-- A Windows-95 inset groove ruler (1px dark line beside 1px light line)
local function groove(items, key: string, position: UDim2, size: UDim2, vertical: boolean)
	items[key .. "Dark"] = e("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(128, 128, 128),
		BorderSizePixel = 0,
	})
	items[key .. "Light"] = e("Frame", {
		Position = position + (if vertical then UDim2.new(0, 1, 0, 0) else UDim2.new(0, 0, 0, 1)),
		Size = size,
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
	})
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
				Size = UDim2.new(1, -18, 0, 48),
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
				-- Two wrapped lines (truncating the tail) instead of one
				-- clipped line: badge descriptions rarely fit a single row
				DescriptionLabel = e("TextLabel", {
					Position = UDim2.new(0, 36, 0, 17),
					Size = UDim2.new(1, -36, 0, 28),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 12,
					TextColor3 = if dimmed then Color3.new(0.55, 0.55, 0.55) else Color3.new(0.35, 0.35, 0.35),
					TextWrapped = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
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
				lineScroll = 49,
			}),
		})
	end

	-- Stats tab: a narrow node-thumbnail rail (security-level dividers,
	-- unbeaten nodes blacked out) beside a pane showing either the general
	-- overview or the selected node's you/friend/world record view
	local railItems: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		-- PaddingRight matches the scrollbar width so thumbnails center
		-- within the VISIBLE area, not the frame the scrollbar covers
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 18),
		}),
	}
	for i, entry in ipairs(props.statsNodeList or {}) do
		if entry.Kind == "divider" then
			railItems["Item" .. i] = e("TextLabel", {
				LayoutOrder = i,
				Size = UDim2.new(1, -4, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 12,
				TextColor3 = Color3.new(0.35, 0.35, 0.35),
				Text = entry.Text,
			})
		else
			local selected = entry.Id == props.statsSelectedId
			-- Each thumbnail is a mini copy of the node's databattle layout
			-- (a dark silhouette while unbeaten)
			local miniItems = miniLayoutItems(entry.PlaceId, 4, not entry.Beaten)
			miniItems.Stroke = if selected
				then e("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0.5) })
				else nil
			miniItems.IdLabel = if entry.Beaten
				then e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 12),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.45,
					BorderSizePixel = 0,
					Font = Enum.Font.SourceSansBold,
					TextSize = 11,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 3,
					Text = entry.Id,
				})
				else nil
			railItems["Item" .. i] = e("ImageButton", {
				Name = "Node_" .. entry.Id,
				LayoutOrder = i,
				Size = UDim2.new(0, 64, 0, 48),
				BackgroundColor3 = Color3.fromRGB(24, 26, 34),
				BorderSizePixel = 0,
				AutoButtonColor = entry.Beaten,
				Image = "",
				[React.Event.MouseButton1Click] = function()
					if entry.Beaten and props.onStatsNodeClick then
						props.onStatsNodeClick(entry.Id)
					end
				end,
			}, miniItems)
		end
	end

	-- The right-hand stats pane
	local statsPaneItems: { [string]: any }
	if props.statsDetail then
		local d = props.statsDetail
		-- One value cell of the records grid: value, with the holder's name
		-- beneath for friend/world columns
		local function recordCell(rec, statKey): (string, string)
			if rec == "pending" then
				return "…", ""
			elseif type(rec) ~= "table" then
				return "—", ""
			end
			local cell = rec[statKey]
			if not cell then
				return "—", ""
			end
			return tostring(cell.Value), cell.Name or ""
		end
		-- Small screens (base-size menu) get a compact single-line grid; the
		-- grown desktop menu gets the battle-setup preview and big numbers
		local compact = (props.menuHeight or 250) < 420

		statsPaneItems = {
			NodeName = e("TextLabel", {
				Position = UDim2.new(0, if compact then 0 else 104, 0, 2),
				Size = UDim2.new(1, (if compact then 0 else -104) - 122, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 16,
				TextColor3 = Color3.new(0, 0, 0.5),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = d.Name,
			}),
			SubLine = e("TextLabel", {
				Position = UDim2.new(0, if compact then 0 else 104, 0, 22),
				Size = UDim2.new(1, (if compact then 0 else -104) - 122, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 14,
				TextColor3 = Color3.new(0, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = d.SubLine,
			}),
			PlayAgain = e(ColoredWindowsButton, {
				Name = "PlayAgainButton",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 4),
				Size = UDim2.new(0, 110, 0, 34),
				ImageColor3 = Color3.new(0, 0, 1),
				Text = "Play Again",
				TextSize = 16,
				OnClick = function()
					if props.onPlayAgain then
						props.onPlayAgain(d.Id)
					end
				end,
			}),
		}

		-- Mini battle-setup preview: the node's board at a glance (tiles,
		-- enemy layout, upload zones, pickups) instead of repeating the
		-- node thumbnail
		if not compact and d.PlaceId and Places[d.PlaceId] then
			statsPaneItems.SetupPreview = e("Frame", {
				Position = UDim2.new(0, 0, 0, 2),
				Size = UDim2.new(0, 16 * 6, 0, 12 * 6),
				BackgroundColor3 = Color3.fromRGB(24, 26, 34),
				BorderSizePixel = 0,
			}, miniLayoutItems(d.PlaceId, 6, false))
		end

		-- Records grid, spreadsheet style: a narrow two-line stat-label
		-- column, then a right-aligned column each for You / Friend / World,
		-- separated by Win95 groove rulers.
		local kGridTop = if compact then 40 else 82
		local kHeaderH = if compact then 16 else 18
		local kRowHeight = if compact then 30 else 44
		-- Column widths: label and You are FIXED and narrow (two short
		-- lines / a bare number); Friend and World split everything left,
		-- since they're the ones holding usernames
		local kLabelColW = if compact then 40 else 46
		local kYouColW = if compact then 44 else 56
		local kNameColsStart = kLabelColW + kYouColW
		local kGridStats = {
			{ Key = "turns", Label = "Turns\nTaken", You = d.You and d.You.turns },
			{ Key = "moves", Label = "Tiles\nMoved", You = d.You and d.You.moves },
			{ Key = "units", Label = "Scripts\nUsed", You = d.You and d.You.units },
		}
		local kColumns = { "You", "Friend", "World" }
		-- {posScale, posOffset, sizeScale, sizeOffset} per value column
		local kCols = {
			You = { 0, kLabelColW, 0, kYouColW },
			Friend = { 0, kNameColsStart, 0.5, -kNameColsStart / 2 },
			World = { 0.5, kNameColsStart / 2, 0.5, -kNameColsStart / 2 },
		}
		local gridHeight = kHeaderH + 4 + 3 * kRowHeight
		local gridItems: { [string]: any } = {}
		for _, columnName in ipairs(kColumns) do
			local col = kCols[columnName]
			gridItems["Head" .. columnName] = e("TextLabel", {
				Position = UDim2.new(col[1], col[2] + 6, 0, 0),
				Size = UDim2.new(col[3], col[4] - 14, 0, kHeaderH - 2),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 13,
				TextColor3 = Color3.new(0, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = columnName,
			})
		end
		for r, stat in ipairs(kGridStats) do
			local y = kHeaderH + 4 + (r - 1) * kRowHeight
			-- Two-line stat label, tight to the left
			gridItems["Label" .. stat.Key] = e("TextLabel", {
				Position = UDim2.new(0, 0, 0, y + 2),
				Size = UDim2.new(0, kLabelColW - 4, 0, kRowHeight - 6),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = if compact then 11 else 13,
				TextColor3 = Color3.new(0, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = stat.Label,
			})
			for c = 1, 3 do
				local value, holder
				if c == 1 then
					value = if stat.You then tostring(stat.You) else "—"
					holder = ""
				else
					value, holder = recordCell(if c == 2 then d.Friend else d.World, stat.Key)
				end
				if compact and holder ~= "" then
					value = value .. " (" .. holder .. ")"
				end
				local col = kCols[kColumns[c]]
				-- The numbers are the star: big, bold, right-aligned
				gridItems[kColumns[c] .. stat.Key] = e("TextLabel", {
					Position = UDim2.new(col[1], col[2] + 6, 0, y + 2),
					Size = UDim2.new(col[3], col[4] - 14, 0, if compact then 20 else 24),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = if compact then 15 else 22,
					TextColor3 = Color3.new(0, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = value,
				})
				if not compact and c > 1 then
					-- Record holder beneath the number; the WORLD record
					-- holder in bold - that name is an achievement
					gridItems[kColumns[c] .. stat.Key .. "Name"] = e("TextLabel", {
						Position = UDim2.new(col[1], col[2] + 6, 0, y + 27),
						Size = UDim2.new(col[3], col[4] - 14, 0, 12),
						BackgroundTransparency = 1,
						Font = if c == 3 then Enum.Font.SourceSansBold else Enum.Font.SourceSans,
						TextSize = 11,
						TextColor3 = if c == 3 then Color3.new(0, 0, 0) else Color3.new(0.35, 0.35, 0.35),
						TextXAlignment = Enum.TextXAlignment.Right,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Text = holder,
					})
				end
			end
		end
		-- Win95 groove rulers: vertical between the label column and each
		-- value column, horizontal under the header and between rows
		for b, columnName in ipairs(kColumns) do
			local col = kCols[columnName]
			groove(gridItems, "VRule" .. b,
				UDim2.new(col[1], col[2], 0, 0), UDim2.new(0, 1, 0, gridHeight), true)
		end
		groove(gridItems, "HRuleHead",
			UDim2.new(0, 0, 0, kHeaderH), UDim2.new(1, -2, 0, 1), false)
		for r = 1, 2 do
			groove(gridItems, "HRule" .. r,
				UDim2.new(0, 0, 0, kHeaderH + 4 + r * kRowHeight - 4), UDim2.new(1, -2, 0, 1), false)
		end
		statsPaneItems.Grid = e("Frame", {
			Position = UDim2.new(0, 0, 0, kGridTop),
			Size = UDim2.new(1, 0, 0, gridHeight),
			BackgroundTransparency = 1,
		}, gridItems)
		statsPaneItems.BackHint = e("TextButton", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 13,
			TextColor3 = Color3.new(0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "< Back to overview",
			[React.Event.MouseButton1Click] = function()
				if props.onStatsNodeClick and props.statsDetail then
					-- Clicking the selected node toggles back to overview
					props.onStatsNodeClick(props.statsDetail.Id)
				end
			end,
		})
	else
		statsPaneItems = {
			SummaryLabel = e("TextLabel", {
				Position = UDim2.new(0, 0, 0, 4),
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 16,
				TextColor3 = Color3.new(0, 0, 0.5),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = props.statsSummary or "",
			}),
			Hint = e("TextLabel", {
				Position = UDim2.new(0, 0, 0, 68),
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 14,
				-- Full black: grey body text doesn't read against the grey
				-- tab background
				TextColor3 = Color3.new(0, 0, 0),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = "Select a beaten node on the left to compare your records with friends and the world.",
			}),
		}
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
		-- Menu window (the ClickSink child keeps window-body clicks from
		-- reaching the backdrop, which closes the menu)
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- The backdrop host extends UP past the gui inset to dim the whole
		-- screen, so its center sits above the VISIBLE center - nudge down
		-- by half the inset or the window pokes under the Roblox topbar
		Position = UDim2.new(0.5, 0, 0.5,
			math.floor(game:GetService("GuiService"):GetGuiInset().Y / 2)),
		-- 400x250 fits a phone; larger viewports stretch the window (the
		-- tab panel is edge-relative, so tab content gets real extra room
		-- at native UI size rather than scaling up)
		Size = UDim2.new(0, props.menuWidth, 0, props.menuHeight),
		ZIndex = 2,
		BackgroundTransparency = 1,
		Image = kWindowImage,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = kWindowSliceCenter,
		ImageRectSize = kWindowImageRectSize,
	}, {
		-- Swallows clicks on the window body: the backdrop host is an
		-- ANCESTOR button (children can't sink input away from their own
		-- ancestor - Active on the window did nothing), so an inert button
		-- over the window's extent must claim them. ZIndex 0 keeps it under
		-- every real control.
		ClickSink = e("ImageButton", {
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 0,
			BackgroundTransparency = 1,
			Image = "",
			AutoButtonColor = false,
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
			DefaultTab = props.defaultTab or (if props.battleContext then "Databattle" else "Settings"),
			Tabs = appendTabs(tabs, {
				{
					Name = "Settings",
					Label = "Settings",
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
						GameSpeedLabel = sectionLabel("Gameplay Speed", UDim2.new(0, 10, 0, 77)),
						GameSpeed = e(WindowsSlider, {
							Position = UDim2.new(0.4, 0, 0, 77),
							Size = UDim2.new(0.6, -6, 0, 36),
							Value = props.speedValue,
							LeftLabel = "Slow",
							RightLabel = "Fast",
							OnChanged = props.onSpeedChanged,
						}),
					},
				},
				{
					Name = "Stats",
					Label = "Statistics",
					Content = {
						-- Node thumbnail rail, Win95 listbox style
						RailArea = e("Frame", {
							Position = UDim2.new(0, 10, 0, 4),
							Size = UDim2.new(0, 84, 1, -10),
							BackgroundColor3 = Color3.new(1, 1, 1),
							BorderSizePixel = 0,
						}, {
							StatsRailScroll = e("ScrollingFrame", {
								ref = statsScrollRef,
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								ScrollBarThickness = 0,
							}, railItems),
							Scrollbar = e(Win95Scrollbar, {
								scrollRef = statsScrollRef,
								lineScroll = 50,
							}),
						}),
						-- Overview or selected-node detail
						StatsPane = e("Frame", {
							Position = UDim2.new(0, 104, 0, 4),
							Size = UDim2.new(1, -114, 1, -10),
							BackgroundTransparency = 1,
						}, statsPaneItems),
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
			}),
		}),
	})
end

local MainMenuView = {}

function MainMenuView.new(container: Instance)
	local this = {}

	-- Fired by the stats detail pane's Play Again button (nodeId)
	this.PlayNodeRequested = Signal.new()

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
	-- Clicking the dimmed backdrop outside the menu window closes it (the
	-- window body itself is Active, so its clicks never reach this)
	mGui.MouseButton1Click:Connect(function()
		this:Hide()
	end)

	-- Forward-declared so the slider adapters (whose callbacks are wired up
	-- during create) can setState; assigned right after StatefulRoot.create.
	local mRoot: StatefulRoot.StatefulRoot? = nil

	-- Statistics panel: a node thumbnail rail (all battle nodes in security
	-- level order, unbeaten blacked out) beside an overview pane that a
	-- selected node replaces with its you/friend/world record view (records
	-- fetched from the server's per-node ordered stores; friends via
	-- GetFriendsAsync)
	local mStatsNodes = {} -- id -> { BestTurns, BestMoves, BestUnits, Wins, Attempts }
	local mStatsNodeList = {} -- the rail model (for scroll-to-node)
	local mSelectedStatsNode = nil

	-- Push the selected node's detail pane (friendRec/worldRec: "pending",
	-- "unavailable", or the { [stat] = {Value, Name} } record tables)
	local function pushStatsDetail(nodeId, friendRec, worldRec)
		local node = Netmap.ById[nodeId]
		local mine = mStatsNodes[nodeId]
		if mRoot then
			mRoot.setState({
				statsSelectedId = nodeId,
				statsDetail = {
					Id = nodeId,
					Name = Netmap.GetNodeDisplayName(nodeId),
					PlaceId = node.PlaceId,
					SubLine = if mine
						then string.format("Wins %d  ·  Attempts %d", mine.Wins or 0, mine.Attempts or 0)
						else "",
					You = if mine and mine.BestTurns
						then { turns = mine.BestTurns, moves = mine.BestMoves, units = mine.BestUnits }
						else nil,
					Friend = friendRec,
					World = worldRec,
				},
			})
		end
	end

	local function selectStatsNode(nodeId)
		mSelectedStatsNode = nodeId
		pushStatsDetail(nodeId, "pending", "pending")
		task.spawn(function()
			local ok, records = pcall(function()
				return game.ReplicatedStorage.Remotes.GetNodeRecords:InvokeServer(nodeId)
			end)
			if mSelectedStatsNode ~= nodeId then
				return -- a different node was picked while fetching
			end
			if ok and records then
				pushStatsDetail(nodeId, records.Friend or {}, records.World or {})
			else
				pushStatsDetail(nodeId, "unavailable", "unavailable")
			end
		end)
	end

	local function clearStatsSelection()
		mSelectedStatsNode = nil
		if mRoot then
			mRoot.setState({
				statsSelectedId = StatefulRoot.None,
				statsDetail = StatefulRoot.None,
			})
		end
	end

	-- Refresh the statistics panel content from local player data
	local function updateStats()
		local ok, stats = pcall(function()
			return LocalPlayerData:GetProgressStats()
		end)
		if not ok then
			return -- player data not loaded yet
		end
		mStatsNodes = {}
		for _, node in pairs(stats.Nodes) do
			mStatsNodes[node.Id] = node
		end
		-- The rail: battle nodes in security-level order with dividers. Y
		-- mirrors the rendered layout (3px top pad; 16px dividers and 48px
		-- cells, 2px apart) so scroll-to-node needs no layout queries.
		local ordered = {}
		for id, node in pairs(Netmap.ById) do
			if not node.Warez and id ~= 'hq' then
				table.insert(ordered, { Id = id, Level = node.Level })
			end
		end
		table.sort(ordered, function(a, b)
			if a.Level ~= b.Level then
				return a.Level < b.Level
			end
			return a.Id < b.Id
		end)
		local list = {}
		local y = 3
		local lastLevel = nil
		for _, item in ipairs(ordered) do
			local node = Netmap.ById[item.Id]
			if item.Level ~= lastLevel then
				lastLevel = item.Level
				table.insert(list, { Kind = "divider", Text = "— Level " .. item.Level .. " —", Y = y })
				y += 18
			end
			local beaten = LocalPlayerData:HasBeatenNode(item.Id)
			table.insert(list, {
				Kind = "node",
				Id = item.Id,
				Y = y,
				Beaten = beaten,
				PlaceId = node.PlaceId,
			})
			y += 50
		end
		mStatsNodeList = list
		if mRoot then
			mRoot.setState({
				statsSummary = string.format("Nodes beaten: %d / %d\nWins: %d\nAttempts: %d",
					stats.BattleNodesBeaten, stats.BattleNodesTotal, stats.Wins, stats.Attempts),
				statsNodeList = list,
				statsSelectedId = StatefulRoot.None,
				statsDetail = StatefulRoot.None,
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
	local function showInternal(defaultTab)
		JourneyRecorder:Record("MenuOpen")
		ModalManager:SetModal(true)
		updateStats()
		updateBadges()
		-- Remount the tab view so the default tab re-applies on each open
		mSession += 1
		if mRoot then
			-- Size like the warez shop: height up to 2x the base on larger
			-- viewports with the width growing in proportion, read LIVE at
			-- open (the viewport isn't settled at construction time)
			local viewport = workspace.CurrentCamera.ViewportSize
			-- Floor raised 250 -> 280: at the old floor the phone menus ran
			-- slightly too short for their content
			local menuHeight = math.clamp(viewport.Y - 180, 280, 500)
			mRoot.setState({
				menuSession = mSession,
				-- With the session key: the remounted tab view reads it
				defaultTab = defaultTab or StatefulRoot.None,
				menuHeight = menuHeight,
				menuWidth = math.clamp(math.min(
					viewport.X - 120,
					400 + (menuHeight - 250) * 4 / 5), 400, 600),
			})
		end
		mGui.Visible = true
	end
	function this:Show()
		showInternal(nil)
	end

	-- Open straight to the Statistics tab with a node selected and its rail
	-- thumbnail scrolled into view (the netmap routes beaten-node clicks
	-- here; the detail pane's Play Again re-enters the battle)
	function this:ShowStats(nodeId)
		showInternal("Stats")
		if nodeId then
			selectStatsNode(nodeId)
			task.defer(function()
				local scroll = mGui:FindFirstChild("StatsRailScroll", true)
				if scroll then
					for _, entry in ipairs(mStatsNodeList) do
						if entry.Id == nodeId then
							scroll.CanvasPosition = Vector2.new(0, math.max(0, entry.Y - 60))
							break
						end
					end
				end
			end)
		end
	end
	function this:Hide()
		JourneyRecorder:Record("MenuClose")
		mGui.Visible = false
		ModalManager:SetModal(false)
	end

	function this:IsVisible()
		return mGui.Visible
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
	local mSpeedSlider = makeSliderAdapter("speedValue")

	mRoot = StatefulRoot.create(mGui, MainMenuContent, {
		menuWidth = 400,
		menuHeight = 250,
		speedValue = 0,
		soundValue = 0,
		musicValue = 0,
		-- Template placeholder text, replaced once player data is available
		skipsAvailableText = "5 skips",
		skipsUsedText = "5 skips",
		statsSummary = "",
		statsSelectedId = nil,
		statsNodeList = {},
		statsDetail = nil,
		defaultTab = nil,
		onStatsNodeClick = function(id: string)
			-- Clicking the selected node again returns to the overview
			if mSelectedStatsNode == id then
				clearStatsSelection()
			else
				selectStatsNode(id)
			end
		end,
		onPlayAgain = function(id: string)
			this:Hide()
			this.PlayNodeRequested:fire(id)
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
		onSpeedChanged = function(value: number)
			mSpeedSlider:Set(value)
		end,
	})
	local root = mRoot :: StatefulRoot.StatefulRoot

	-- Sound stuff
	SoundManager:AddSoundSlider(mSoundSlider)
	SoundManager:AddMusicSlider(mMusicSlider)
	-- Gameplay speed: the continuous -1..1 slider maps to GameSpeed 0..2
	mSpeedSlider:Set(GameSpeed:Get() - 1)
	mSpeedSlider.Changed:connect(function(value: number)
		GameSpeed:Set(value + 1)
	end)

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
