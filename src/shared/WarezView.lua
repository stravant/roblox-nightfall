--!strict
-- The warez shop. One Win95-style window: the shop list lives in a native
-- ScrollingFrame on the left, and the right side is a detail panel for the
-- selected program (icon, stats, description, owned count). Replaces the old
-- layout that used a separate floating unit-info tray and the imperative
-- ScrollingFrame library.
--
-- Public API is unchanged: WarezView.new(warezNodeId, warez) returns an
-- imperative view with MadePurchase/Done signals and GetGui().

local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)
local Win95Scrollbar = require(game.ReplicatedStorage.Components.Win95Scrollbar)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"

local kBlueColor = Color3.new(0, 0, 0.5)
local kTextBlack = Color3.new(0, 0, 0)
local kTextWhite = Color3.new(1, 1, 1)

type ProgramEntryData = {
	Id: string,
	Cost: number,
	Name: string,
	Image: string,
	Color: Color3,
}

type WarezState = {
	selectedId: string?,
	purchaseVisible: boolean,
	insufficientVisible: boolean,
	ownedCounts: { [string]: number },
	bigScreen: boolean,
	programs: { ProgramEntryData },
	onSelect: (id: string) -> (),
	onPurchase: () -> (),
	onDone: () -> (),
}

local function programEntry(data: ProgramEntryData, selected: boolean, owned: number, onSelect: (id: string) -> (), layoutOrder: number)
	local textColor = if selected then kTextWhite else kTextBlack
	return e("ImageButton", {
		Active = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0, 26),
		LayoutOrder = layoutOrder,
		BackgroundColor3 = if selected then kBlueColor else kTextWhite,
		Image = "",
		[React.Event.MouseButton1Click] = function()
			onSelect(data.Id)
		end,
	}, {
		CostLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.new(0, 40, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 15,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(data.Cost),
		}),
		Icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 44, 0.5, 0),
			Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = data.Color,
			BorderColor3 = Color3.new(0, 0, 0),
			Image = data.Image,
		}),
		NameLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 72, 0.5, 0),
			Size = UDim2.new(1, -106, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = data.Name,
		}),
		OwnedLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.new(0, 32, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 15,
			TextColor3 = if selected then kTextWhite else Color3.fromRGB(0, 100, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = owned .. "x",
		}),
	})
end

-- One compact rich-text line per attack the program has
local function commandSummary(command: any): string
	local effect
	if command.Type == "damage" then
		effect = command.Amount .. " dmg"
	elseif command.Type == "one" then
		effect = "add a tile"
	elseif command.Type == "zero" then
		effect = "remove a tile"
	elseif command.Type == "speedMod" then
		effect = (if command.Amount > 0 then "+" else "") .. command.Amount .. " speed"
	elseif command.Type == "sizeMod" then
		effect = "+" .. command.Amount .. " max size"
	elseif command.Type == "grow" then
		effect = "+" .. command.Amount .. " sectors"
	else
		effect = ""
	end
	if command.Range and command.Range > 1 then
		effect = effect .. ", range " .. command.Range
	end
	if command.SizeReq and command.SizeReq > 0 then
		effect = effect .. ", needs size " .. command.SizeReq
	end
	return string.format("<b>%s</b> — %s", command.Name, effect)
end

local function detailPanel(selectedId: string?)
	if not selectedId then
		return {
			Hint = e("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 16,
				TextColor3 = Color3.new(0.35, 0.35, 0.35),
				TextWrapped = true,
				Text = "Select a script",
			}),
		}
	end
	local def = Scripts[selectedId]

	local attackLines = {}
	for _, command in def.CommandList do
		table.insert(attackLines, commandSummary(command))
	end

	-- Stacked with a list layout so the attacks block can WRAP and auto-size
	-- (some attack summaries are longer than the pane) with the description
	-- flowing below it. Compact: the pane is shallow so the whole window
	-- fits a phone screen.
	return {
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		-- One header row: icon with the name and core stats beside it
		Header = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
		}, {
			DetailIcon = e("ImageLabel", {
				Size = UDim2.new(0, 36, 0, 36),
				BackgroundColor3 = def.Color,
				BorderColor3 = Color3.new(0, 0, 0),
				Image = def.Image,
			}),
			DetailName = e("TextLabel", {
				Position = UDim2.new(0, 44, 0, 0),
				Size = UDim2.new(1, -44, 0, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 18,
				TextColor3 = kTextBlack,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = def.Name,
			}),
			StatsText = e("TextLabel", {
				Position = UDim2.new(0, 44, 0, 18),
				Size = UDim2.new(1, -44, 0, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 16,
				RichText = true,
				TextColor3 = kTextBlack,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.format("Move: <b>%d</b>   Max Size: <b>%d</b>", def.Move, def.MaxSize),
			}),
		}),
		Attacks = e("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			RichText = true,
			TextColor3 = kTextBlack,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = table.concat(attackLines, "\n"),
		}),
		FlavorText = e("TextLabel", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 15,
			TextColor3 = kTextBlack,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = def.Desc,
		}),
	}
end

local function WarezContent(props: WarezState)
	-- Ref shared between the shop list and its Win95 scrollbar
	local scrollRef = React.useRef(nil)

	local rows: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			-- A hair of breathing room between rows on the white background
			Padding = UDim.new(0, 1),
		}),
	}
	for i, data in props.programs do
		rows[data.Id] = programEntry(data, props.selectedId == data.Id,
			props.ownedCounts[data.Id] or 0, props.onSelect, i)
	end

	local function columnHeading(name: string, x: number, width: number, alignment: Enum.TextXAlignment)
		return e("TextLabel", {
			Position = UDim2.new(0, x, 0, 0),
			Size = UDim2.new(0, width, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 13,
			TextColor3 = Color3.new(0.3, 0.3, 0.3),
			TextXAlignment = alignment,
			Text = name,
		})
	end

	return e(React.Fragment, nil, {
		MouseCatcher = e("ImageButton", {
			Active = true,
			AutoButtonColor = false,
			-- Extended past the topbar inset so the dim covers the full screen
			Position = UDim2.new(0, 0, 0, -game:GetService("GuiService"):GetGuiInset().Y),
			Size = UDim2.new(1, 0, 1, game:GetService("GuiService"):GetGuiInset().Y),
			-- Same shadowed backdrop as the menus and conversations
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Image = "",
		}),
		MainBox = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			-- Short and narrow enough to fit a phone screen at 1x scale
			Size = UDim2.new(0, 380, 0, 210),
			ZIndex = 2,
			BackgroundTransparency = 1,
			Image = kWindowImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = kWindowSliceCenter,
			ImageRectSize = kWindowImageRectSize,
		}, {
			UIScale = if props.bigScreen then e("UIScale", { Scale = 1.5 }) else nil,
			WindowTitle = e("TextLabel", {
				Position = UDim2.new(0, 6, 0, 2),
				Size = UDim2.new(1, -12, 0, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				TextColor3 = kTextWhite,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Warez Node",
			}),
			-- Column headings for the shop list (positions match the row layout
			-- inside the scroll frame: 4px scroll inset + row offsets)
			ShopHeadings = e("Frame", {
				Position = UDim2.new(0, 6, 0, 26),
				Size = UDim2.new(0, 190, 0, 16),
				BackgroundTransparency = 1,
			}, {
				HeadingCost = columnHeading("Cost", 6, 40, Enum.TextXAlignment.Right),
				HeadingName = columnHeading("Name", 76, 80, Enum.TextXAlignment.Left),
				HeadingOwned = columnHeading("Owned", 132, 48, Enum.TextXAlignment.Right),
			}),
			ShopInset = e("ImageLabel", {
				Position = UDim2.new(0, 6, 0, 44),
				Size = UDim2.new(0, 190, 1, -90),
				BackgroundTransparency = 1,
				Image = kInsetImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
			}, {
				-- Win95 listbox: white scroll area + the classic scrollbar,
				-- matching the battle setup's scripts list
				ListArea = e("Frame", {
					Name = "ListArea",
					Position = UDim2.new(0, 4, 0, 4),
					Size = UDim2.new(1, -8, 1, -8),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
				}, {
					ShopScroll = e("ScrollingFrame", {
						ref = scrollRef,
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						CanvasSize = UDim2.new(0, 0, 0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = 0,
					}, rows),
					Scrollbar = e(Win95Scrollbar, {
						scrollRef = scrollRef,
						lineScroll = 27,
					}),
				}),
			}),
			DetailInset = e("ImageLabel", {
				Position = UDim2.new(0, 202, 0, 26),
				Size = UDim2.new(1, -208, 1, -72),
				-- The shallow pane can't fit the longest description texts;
				-- clip rather than paint over the buttons below
				ClipsDescendants = true,
				BackgroundTransparency = 1,
				Image = kInsetImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
			}, detailPanel(props.selectedId)),
			-- Two equal-width buttons with symmetric margins
			InsufficientCreditsText = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 8, 1, -8),
				Size = UDim2.new(0.5, -12, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 18,
				TextColor3 = Color3.new(0.666667, 0, 0),
				Text = "Insufficient Credits",
				Visible = props.insufficientVisible,
			}),
			PurchaseButton = e(WindowsButton, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 8, 1, -8),
				Size = UDim2.new(0.5, -12, 0, 30),
				Text = "Purchase",
				Visible = props.purchaseVisible,
				OnClick = props.onPurchase,
			}),
			DoneButton = e(WindowsButton, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -8, 1, -8),
				Size = UDim2.new(0.5, -12, 0, 30),
				Text = "Done Shopping",
				OnClick = props.onDone,
			}),
		}),
	})
end

local WarezView = {}

function WarezView.new(warezNodeId: string, warez: { [string]: number })
	local this = {}

	this.MadePurchase = Signal.new()
	this.Done = Signal.new()

	local mGui = Instance.new("Frame")
	mGui.Name = "Warez"
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.Position = UDim2.new(0.5, 0, 0.5, 0)
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundTransparency = 1
	mGui.ZIndex = 4

	function this:GetGui()
		return mGui
	end

	local mPrograms: { ProgramEntryData } = {}
	for id, cost in pairs(warez) do
		local data = Scripts[id]
		if not data then
			print("Missing script:", id)
		end
		table.insert(mPrograms, {
			Id = id,
			Cost = tonumber(cost) :: number,
			Name = data.Name,
			Image = data.Image,
			Color = data.Color,
		})
	end
	-- Cheapest first
	table.sort(mPrograms, function(a, b)
		return a.Cost < b.Cost
	end)

	local function ownedCounts(): { [string]: number }
		local counts = {}
		for _, info in pairs(LocalPlayerData:GetProgramList()) do
			counts[info.Id] = info.Count
		end
		return counts
	end

	local mSelectedProgram: string? = nil
	local mRoot: StatefulRoot.StatefulRoot? = nil

	function this:SelectProgram(id: string?)
		mSelectedProgram = id
		if id then
			local canAfford = LocalPlayerData:GetCredits() >= warez[id]
			;(mRoot :: StatefulRoot.StatefulRoot).setState({
				selectedId = id,
				purchaseVisible = canAfford,
				insufficientVisible = not canAfford,
			})
		else
			(mRoot :: StatefulRoot.StatefulRoot).setState({
				selectedId = StatefulRoot.None,
				purchaseVisible = false,
				insufficientVisible = false,
			})
		end
	end

	function this:PurchaseSelectedProgram()
		local cost = warez[mSelectedProgram :: string]
		if LocalPlayerData:GetCredits() >= cost then
			LocalPlayerData:AddCredits(-cost)
			LocalPlayerData:AddUnit(mSelectedProgram)
			game.ReplicatedStorage.Remotes.PurchaseUnit:FireServer(warezNodeId, mSelectedProgram)
			this.MadePurchase:fire(mSelectedProgram)
			-- Refresh the owned column and affordability with the new balance
			;(mRoot :: StatefulRoot.StatefulRoot).setState({ ownedCounts = ownedCounts() })
			this:SelectProgram(mSelectedProgram)
		end
	end

	mRoot = StatefulRoot.create(mGui, WarezContent, {
		selectedId = nil,
		purchaseVisible = false,
		insufficientVisible = false,
		ownedCounts = ownedCounts(),
		bigScreen = DeviceInfo.ScreenHeight > 500,
		programs = mPrograms,
		onSelect = function(id: string)
			this:SelectProgram(id)
		end,
		onPurchase = function()
			SoundManager:Play("SelectUnit")
			this:PurchaseSelectedProgram()
		end,
		onDone = function()
			SoundManager:Play("SelectUnit")
			this.Done:fire()
		end,
	})

	this:SelectProgram(if #mPrograms > 0 then mPrograms[1].Id else nil)

	return this
end

return WarezView
