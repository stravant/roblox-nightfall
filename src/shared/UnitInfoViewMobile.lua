--!strict
-- React conversion of UnitInfoViewMobile (the mobile / warez side tray).
-- Public API is unchanged from the template version, including the module
-- statics. The host is the "SideTray" ImageLabel; contents render via React
-- (layout matches ui-reference/ModuleTemplates/UnitInfoViewMobile.json).
--
-- Conversion notes:
-- - The template's UIListLayouts used SortOrder=Name over identically-named
--   entry clones (effectively insertion order). React children need distinct
--   names to stay addressable (tutorial arrows, specs), so the lists use
--   SortOrder=LayoutOrder with explicit LayoutOrder = insertion index, which
--   pins the same visual order deterministically.
-- - ScrollingFrame stays imperative (it only writes the Content frame's
--   Position, which React never re-applies); it hooks up in an onMounted
--   callback fired from useLayoutEffect.
-- - Text measuring uses constants from the template dump instead of reading
--   the (deleted) template instances.

local TextService = game:GetService("TextService")

local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local ScrollingFrame = require(game.ReplicatedStorage.ScrollingFrame)
local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)

local e = React.createElement

-- Colors
local kGreyColor = Color3.new(0.752941, 0.752941, 0.752941)
local kBlueColor = Color3.new(0, 0, 0.5)
local kTextBlack = Color3.new(0, 0, 0)
local kTextWhite = Color3.new(1, 1, 1)
local kHeadingColor = Color3.new(0.105882, 0.164706, 0.207843)

-- Template images
local kTrayImage = "rbxassetid://1372689281"
local kListImage = "rbxassetid://1372688216"
local kGutterImage = "rbxassetid://1372920646"
local kScrollPartsImage = "rbxassetid://1375318214"

-- Template metrics (from ui-reference/ModuleTemplates/UnitInfoViewMobile.json)
local kProgramListEntryHeight = 24
local kActionListTextWidth = 133
local kActionBodyFont = Enum.Font.SourceSans
local kActionBodyTextSize = 14
local kActionNameFont = Enum.Font.SourceSans
local kActionNameTextSize = 16
local kActionListYOffset = 52 -- ProgramInfo.ActionList.Position.Y.Offset
local kActionEntryPadding = 4 -- ActionList UIListLayout padding
local kInfoPanePadding = 8 -- ProgramInfo UIPadding, all sides

local UnitInfoViewMobile = {}

function UnitInfoViewMobile.getProgramListHeight(programCount: number): number
	return kProgramListEntryHeight * programCount + 2 * (programCount - 1)
end

function UnitInfoViewMobile.getActionListBodyTextHeight(text: string): number
	return TextService:GetTextSize(
		text,
		kActionBodyTextSize,
		kActionBodyFont,
		Vector2.new(kActionListTextWidth, 500)).y
end

function UnitInfoViewMobile.getActionListNameTextWidth(text: string): number
	return TextService:GetTextSize(
		text,
		kActionNameTextSize,
		kActionNameFont,
		Vector2.new(500, 500)).x
end

function UnitInfoViewMobile.getCommandText(unitId: string, command: any): (string, string)
	local function sectorStr(sectors)
		if sectors == 0 then
			return "zero sectors"
		elseif sectors == 1 then
			return "a sector"
		else
			return sectors .. " sectors"
		end
	end
	local nameText
	if command.SizeReq > 0 then
		nameText = command.Name .. " (" .. command.SizeReq .. ")"
	else
		nameText = command.Name
	end
	local bodyText
	if command.Type == "one" then
		bodyText = "Add a tile to the grid"
	elseif command.Type == "zero" then
		bodyText = "Remove a tile from the grid"
	elseif command.Type == "damage" then
		bodyText = "Delete " .. sectorStr(command.Amount) .. " from the target"
	elseif command.Type == "speedMod" then
		if command.Amount > 0 then
			bodyText = "Increase target speed by " .. command.Amount
		else
			bodyText = "Decrease target speed by " .. (-command.Amount)
		end
	elseif command.Type == "sizeMod" then
		bodyText = "Increase target max size by " .. command.Amount
	elseif command.Type == "grow" then
		bodyText = "Add " .. command.Amount .. " sectors to the target"
	end
	if command.Cost > 0 then
		bodyText = bodyText .. ", and delete " .. sectorStr(command.Cost) .. " from " .. Scripts[unitId].Name
	end
	bodyText = bodyText .. "."
	if command.SizeReq > 0 then
		bodyText = bodyText .. " (requires " .. command.SizeReq .. " size)"
	end
	if command.Range > 1 then
		bodyText = "Range: " .. command.Range .. "\n" .. bodyText
	end
	return nameText, bodyText
end

--------------------------------------------------------------------------------
-- Render types
--------------------------------------------------------------------------------

type ProgramRow = {
	Id: string,
	Count: number,
}

type ActionEntry = {
	Key: string, -- instance name / lookup key ('move', command id, or 'flavor')
	NameText: string?, -- nil for flavor entries (NameLine hidden)
	BodyText: string,
	Height: number,
	IsMove: boolean,
}

type InfoPane = {
	name: string,
	image: string,
	color: Color3,
	move: number?,
	maxSize: number?,
	entries: { ActionEntry },
}

type TrayState = {
	programs: { ProgramRow },
	selectedProgramId: string?,
	programListVisible: boolean,
	infoPane: InfoPane?,
	selectedCommandId: string?,
	onProgramClick: (id: string) -> (),
	onEntryDown: (key: string, isMove: boolean) -> (),
	onEntryClick: (key: string, isMove: boolean) -> (),
	onScrollTop: () -> (),
	onScrollBottom: () -> (),
	onScrollInput: (inputObject: InputObject) -> (),
	onMounted: () -> (),
}

--------------------------------------------------------------------------------
-- Render helpers
--------------------------------------------------------------------------------

local function programListEntry(
	row: ProgramRow,
	order: number,
	selected: boolean,
	onClick: (id: string) -> (),
	onScrollInput: (inputObject: InputObject) -> ()
)
	local textColor = if selected then kTextWhite else kTextBlack
	local def = Scripts[row.Id]
	return e("ImageButton", {
		Active = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, kProgramListEntryHeight),
		BackgroundColor3 = if selected then kBlueColor else Color3.new(1, 1, 1),
		LayoutOrder = order,
		[React.Event.MouseButton1Click] = function()
			onClick(row.Id)
		end,
		-- Pass on the event rather than stealing it (lets the list scroll)
		[React.Event.InputBegan] = function(_rbx, inputObject: InputObject)
			onScrollInput(inputObject)
		end,
	}, {
		CountLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 16, 0, 50),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 16,
			TextColor3 = textColor,
			Text = tostring(row.Count),
		}),
		Icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 27, 0.5, 0),
			Size = UDim2.new(0, 20, 0, 20),
			BackgroundColor3 = def.Color,
			BorderColor3 = Color3.new(0, 0, 0),
			Image = def.Image,
		}),
		NameLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 40, 0.5, 0),
			Size = UDim2.new(0, 50, 0, 50),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 16,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.Name,
		}),
	})
end

local function actionListEntry(
	entry: ActionEntry,
	order: number,
	selected: boolean,
	onDown: (key: string, isMove: boolean) -> (),
	onClick: (key: string, isMove: boolean) -> ()
)
	local bgColor = if selected then kBlueColor else kGreyColor
	local textColor = if selected then kTextWhite else kTextBlack
	return e("ImageButton", {
		Active = true,
		BorderSizePixel = 0,
		BackgroundColor3 = bgColor,
		Size = UDim2.new(1, 0, 0, entry.Height),
		LayoutOrder = order,
		[React.Event.MouseButton1Down] = function()
			onDown(entry.Key, entry.IsMove)
		end,
		[React.Event.MouseButton1Click] = function()
			onClick(entry.Key, entry.IsMove)
		end,
	}, {
		NameLine = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundTransparency = 1,
			Image = kScrollPartsImage,
			ImageRectOffset = Vector2.new(12, 64),
			ImageRectSize = Vector2.new(4, 2),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(0, 2, 0, 2),
		}, {
			Label = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0, 0),
				Size = UDim2.new(0, if entry.NameText then UnitInfoViewMobile.getActionListNameTextWidth(entry.NameText) else 23, 0, 16),
				BackgroundColor3 = bgColor,
				BorderSizePixel = 0,
				Font = kActionNameFont,
				TextSize = kActionNameTextSize,
				TextColor3 = textColor,
				Text = entry.NameText or "",
				Visible = entry.NameText ~= nil,
			}),
		}),
		BodyText = e("TextLabel", {
			Position = UDim2.new(0, 0, 0, 16),
			Size = UDim2.new(1, 2, 0, entry.Height - 18),
			BackgroundTransparency = 1,
			Font = kActionBodyFont,
			TextSize = kActionBodyTextSize,
			TextColor3 = textColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = entry.BodyText,
		}),
	})
end

local function statValueLabel(name: string, labelText: string, yScale: number, value: number?, showMax: boolean)
	return e("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, yScale, 0),
		Size = UDim2.new(0, 53, 0, 16),
		BackgroundColor3 = kGreyColor,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		TextSize = 16,
		TextColor3 = kTextBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = labelText,
		Visible = value ~= nil,
	}, {
		Value = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 4, 0.5, 0),
			Size = UDim2.new(0, 20, 0, 16),
			BackgroundColor3 = kGreyColor,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			TextSize = 16,
			TextColor3 = kTextBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if value then tostring(value) else "",
		}, {
			MaxText = if name == "MoveLabel"
				then e("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0, 3),
					Size = UDim2.new(0, 40, 0, 40),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					TextSize = 11,
					TextColor3 = Color3.new(0.890196, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "(max)",
					Visible = showMax,
				})
				else nil,
		}),
	})
end

local function heading(name: string, props: { [string]: any })
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = kHeadingColor,
		Size = UDim2.new(0, 50, 0, 50),
	}
	for k, v in props do
		base[k] = v
	end
	return e("TextLabel", base)
end

local function TrayContent(props: TrayState)
	React.useLayoutEffect(function()
		props.onMounted()
	end, {})

	-- Program list rows
	local rows: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	}
	for i, row in props.programs do
		rows[row.Id] = programListEntry(
			row, i, props.selectedProgramId == row.Id, props.onProgramClick, props.onScrollInput)
	end

	-- Info pane layout (translation of the original updateLayout())
	local infoPane = props.infoPane
	local offset = 0
	local entryElements: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, kActionEntryPadding),
		}),
	}
	if infoPane then
		local count = #infoPane.entries
		for i, entry in infoPane.entries do
			offset += entry.Height
			entryElements[entry.Key] = actionListEntry(
				entry, i, props.selectedCommandId == entry.Key, props.onEntryDown, props.onEntryClick)
		end
		offset += math.max(0, count - 1) * kActionEntryPadding
		offset += kActionListYOffset
		offset += 2 * kInfoPanePadding
	end

	local infoPosition, infoSize
	if props.programListVisible then
		infoPosition = UDim2.new(0, 0, 1, -offset)
		infoSize = UDim2.new(1, 0, 0, offset)
	else
		infoPosition = UDim2.new(0, 0, 0, 0)
		infoSize = UDim2.new(1, 0, 0, offset)
	end

	return e("Frame", {
		Name = "Content",
		Position = UDim2.new(0, 0, 0, 3),
		Size = UDim2.new(1, -3, 1, -6),
		BackgroundTransparency = 1,
	}, {
		ProgramList = e("ImageLabel", {
			Size = UDim2.new(1, 0, 1, -offset),
			BorderSizePixel = 0,
			Image = kListImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(56, 24, 120, 25),
			Visible = props.programListVisible,
		}, {
			Headings = e("Folder", nil, {
				HeadingNumber = heading("HeadingNumber", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 10, 0, 10),
					Font = Enum.Font.SourceSansLight,
					TextSize = 16,
					Text = "#",
				}),
				HeadingIcon = heading("HeadingIcon", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 28, 0, 9),
					Font = Enum.Font.SourceSansLight,
					TextSize = 11,
					Text = "img",
				}),
				HeadingName = heading("HeadingName", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 42, 0, 9),
					Font = Enum.Font.SourceSans,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Name",
				}),
			}),
			ContentClip = e("Frame", {
				Position = UDim2.new(0, 2, 0, 19),
				Size = UDim2.new(1, -20, 1, -21),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			}, {
				-- No Position prop: the ScrollingFrame library owns Position
				Content = e("Frame", {
					Size = UDim2.new(1, 0, 0, UnitInfoViewMobile.getProgramListHeight(#props.programs)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, rows),
			}),
			ScrollGutter = e("ImageLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 2),
				Size = UDim2.new(0, 16, 1, -4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = kGutterImage,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.new(0, 16, 0, 16),
			}, {
				UpArrow = e("ImageButton", {
					Active = true,
					Size = UDim2.new(0, 16, 0, 16),
					BackgroundTransparency = 1,
					Image = kScrollPartsImage,
					ImageRectSize = Vector2.new(16, 16),
					[React.Event.MouseButton1Click] = props.onScrollTop,
				}),
				DownArrow = e("ImageButton", {
					Active = true,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(0, 16, 0, 16),
					BackgroundTransparency = 1,
					Image = kScrollPartsImage,
					ImageRectOffset = Vector2.new(0, 48),
					ImageRectSize = Vector2.new(16, 16),
					[React.Event.MouseButton1Click] = props.onScrollBottom,
				}),
				ScrollbarContainer = e("Frame", {
					Position = UDim2.new(0, 0, 0, 16),
					Size = UDim2.new(0, 16, 1, -32),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, {
					Scrollbar = e("ImageButton", {
						Active = true,
						Size = UDim2.new(0, 16, 0, 100),
						BackgroundTransparency = 1,
						Image = kScrollPartsImage,
						ImageRectOffset = Vector2.new(0, 32),
						ImageRectSize = Vector2.new(16, 16),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(8, 8, 8, 8),
					}),
				}),
			}),
		}),
		ProgramInfo = if infoPane
			then e("Frame", {
				Position = infoPosition,
				Size = infoSize,
				BackgroundTransparency = 1,
			}, {
				UIPadding = e("UIPadding", {
					PaddingTop = UDim.new(0, kInfoPanePadding),
					PaddingBottom = UDim.new(0, kInfoPanePadding),
					PaddingLeft = UDim.new(0, kInfoPanePadding),
					PaddingRight = UDim.new(0, kInfoPanePadding),
				}),
				NameLine = e("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 4),
					Size = UDim2.new(1, 0, 0, 2),
					BackgroundTransparency = 1,
					Image = kScrollPartsImage,
					ImageRectOffset = Vector2.new(12, 64),
					ImageRectSize = Vector2.new(4, 2),
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(0, 2, 0, 2),
				}, {
					Label = e("TextLabel", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 4, 0, 0),
						Size = UDim2.new(0, UnitInfoViewMobile.getActionListNameTextWidth(infoPane.name), 0, 16),
						BackgroundColor3 = kGreyColor,
						BorderSizePixel = 0,
						Font = kActionNameFont,
						TextSize = kActionNameTextSize,
						TextColor3 = kTextBlack,
						Text = infoPane.name,
					}),
				}),
				Icon = e("ImageLabel", {
					Position = UDim2.new(0, 0, 0, 16),
					Size = UDim2.new(0, 32, 0, 32),
					BackgroundColor3 = infoPane.color,
					Image = infoPane.image,
				}, {
					MoveLabel = statValueLabel("MoveLabel", "Move:", 0.25, infoPane.move, infoPane.move == 10),
					MaxSizeLabel = statValueLabel("MaxSizeLabel", "Max size:", 0.75, infoPane.maxSize, false),
				}),
				ActionList = e("Frame", {
					Position = UDim2.new(0, 0, 0, kActionListYOffset),
					Size = UDim2.new(1, 0, 1, -kActionListYOffset),
					BackgroundTransparency = 1,
				}, entryElements),
			})
			else nil,
	})
end

--------------------------------------------------------------------------------
-- View object
--------------------------------------------------------------------------------

function UnitInfoViewMobile.new(container: Instance, availablePrograms: { any })
	local this = {}

	this.UnitSelected = Signal.new()
	this.CommandSelected = Signal.new()

	local mGui = Instance.new("ImageLabel")
	mGui.Name = "SideTray"
	mGui.Position = UDim2.new(0, 0, 0, 36)
	mGui.Size = UDim2.new(0, 150, 1, -38)
	mGui.BorderSizePixel = 0
	mGui.Image = kTrayImage
	mGui.ScaleType = Enum.ScaleType.Slice
	mGui.SliceCenter = Rect.new(4, 4, 4, 4)

	-- For tutorial, restrict unit selection to a given unit in the program list
	local mTutorialArrow = TutorialArrowView.new()
	local mOnlySelectUnit: string? = nil

	local mPrograms: { ProgramRow } = {}
	local mProgramsById: { [string]: ProgramRow } = {}
	local mScrollbar: any = nil
	local mRoot: StatefulRoot.StatefulRoot? = nil
	local function root(): StatefulRoot.StatefulRoot
		return mRoot :: StatefulRoot.StatefulRoot
	end

	local function addProgram(id: string, initialCount: number): ProgramRow
		local newInfo = { Id = id, Count = initialCount }
		table.insert(mPrograms, newInfo)
		mProgramsById[id] = newInfo
		return newInfo
	end
	for _, info in availablePrograms do
		addProgram(info.Id, info.Count)
	end

	-- Rendered instance lookups (post-flush only)
	local function findProgramList(): Instance
		return (mGui:FindFirstChild("Content") :: Instance):FindFirstChild("ProgramList") :: Instance
	end
	local function findProgramRow(unitId: string): Instance
		return ((findProgramList():FindFirstChild("ContentClip") :: Instance)
			:FindFirstChild("Content") :: Instance):FindFirstChild(unitId) :: Instance
	end
	local function findActionEntry(key: string): Instance
		return (((mGui:FindFirstChild("Content") :: Instance):FindFirstChild("ProgramInfo") :: Instance)
			:FindFirstChild("ActionList") :: Instance):FindFirstChild(key) :: Instance
	end

	-- Info pane construction (translation of setProgramInfoPane and friends)

	local function makeCommandEntry(unitId: string, command: any): ActionEntry
		local nameText, bodyText
		local isMove = command.Id == "move"
		if isMove then
			nameText = "Move"
			bodyText = "Move the script."
		else
			nameText, bodyText = UnitInfoViewMobile.getCommandText(unitId, command)
		end
		local bodyHeight = UnitInfoViewMobile.getActionListBodyTextHeight(bodyText)
		return {
			Key = command.Id,
			NameText = nameText,
			BodyText = bodyText,
			Height = 16 + bodyHeight + 2,
			IsMove = isMove,
		}
	end

	local function makeFlavorEntry(text: string): ActionEntry
		local bodyHeight = UnitInfoViewMobile.getActionListBodyTextHeight(text)
		return {
			Key = "flavor",
			NameText = nil,
			BodyText = text,
			Height = 16 + bodyHeight + 2,
			IsMove = false,
		}
	end

	local function setProgramInfoPane(unit: any)
		mTutorialArrow:Hide()

		-- Special cases for info on other things on the board
		if unit == "upload" then
			root().setState({
				infoPane = {
					name = "Upload Zone",
					image = "rbxassetid://1333805802",
					color = Color3.new(0, 0, 0),
					entries = { makeFlavorEntry("Upload your units here to do battle!") },
				},
				selectedCommandId = StatefulRoot.None,
			})
			return
		elseif unit == "credits" then
			root().setState({
				infoPane = {
					name = "Credits",
					image = "rbxassetid://1346715274",
					color = Color3.new(0, 0, 0),
					entries = { makeFlavorEntry("Extra credits... see if you can grab them on your way to victory.") },
				},
				selectedCommandId = StatefulRoot.None,
			})
			return
		elseif unit == "codes" then
			root().setState({
				infoPane = {
					name = "Decryption Codes",
					image = "rbxassetid://1346714452",
					color = Color3.new(0, 0, 0),
					entries = { makeFlavorEntry("Your objective is to grab these, no need to terminate all the enemy scripts.") },
				},
				selectedCommandId = StatefulRoot.None,
			})
			return
		end

		local entries: { ActionEntry } = {}
		if not unit.Enemy and unit.MoveLeft > 0 then
			table.insert(entries, makeCommandEntry(unit.Definition.Id, { Id = "move" }))
		end
		for _, command in unit.Definition.CommandList do
			table.insert(entries, makeCommandEntry(unit.Definition.Id, command))
		end

		root().setState({
			infoPane = {
				name = unit.Definition.Name,
				image = unit.Definition.Image,
				color = unit.Definition.Color,
				move = unit.Move,
				maxSize = unit.MaxSize,
				entries = entries,
			},
			selectedCommandId = StatefulRoot.None,
		})
	end

	local kDummyTail = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } -- Long enough to satisfy any requirement
	local function setProgramInfoPaneDef(unitId: string)
		local dummyUnit = {}
		dummyUnit.MoveLeft = 0
		dummyUnit.Tail = kDummyTail
		dummyUnit.Definition = Scripts[unitId]
		dummyUnit.Move = dummyUnit.Definition.Move
		dummyUnit.MaxSize = dummyUnit.Definition.MaxSize
		setProgramInfoPane(dummyUnit)
	end

	mRoot = StatefulRoot.create(mGui, TrayContent, {
		programs = table.clone(mPrograms),
		selectedProgramId = nil,
		programListVisible = true,
		infoPane = nil,
		selectedCommandId = nil,
		onProgramClick = function(id: string)
			if not mOnlySelectUnit or mOnlySelectUnit == id then
				root().setState({ selectedProgramId = id })
				this.UnitSelected:fire(id)
			end
		end,
		onEntryDown = function(key: string, isMove: boolean)
			if not isMove then
				this.CommandSelected:fire(key)
			end
		end,
		onEntryClick = function(key: string, isMove: boolean)
			if isMove then
				this.CommandSelected:fire(nil)
			end
		end,
		onScrollTop = function()
			if mScrollbar then
				mScrollbar:ScrollToTop()
			end
		end,
		onScrollBottom = function()
			-- TODO: Figure out how to scroll up / down the right amount for these presses
			if mScrollbar then
				mScrollbar:ScrollToBottom()
			end
		end,
		onScrollInput = function(inputObject: InputObject)
			if mScrollbar then
				mScrollbar:InputBegan(inputObject)
			end
		end,
		onMounted = function()
			if mScrollbar then
				return
			end
			local programList = findProgramList()
			local content = (programList:FindFirstChild("ContentClip") :: Instance):FindFirstChild("Content") :: Frame
			local scrollbar = ((programList:FindFirstChild("ScrollGutter") :: Instance)
				:FindFirstChild("ScrollbarContainer") :: Instance):FindFirstChild("Scrollbar") :: ImageButton
			mScrollbar = ScrollingFrame.new(content)
			mScrollbar:AddScrollbar(scrollbar)
		end,
	})

	-- Update the count of a program
	function this:UpdateCount(unitId: string, delta: number)
		local data = mProgramsById[unitId]
		if data then
			data.Count = data.Count + delta
		else
			data = addProgram(unitId, delta)
		end
		root().setState({ programs = table.clone(mPrograms) })
	end
	function this:GetCount(unitId: string): number
		return mProgramsById[unitId].Count
	end

	-- Show a tutorial arrow on a program
	function this:TutorialHighlightUnit(unitId: string)
		mOnlySelectUnit = unitId
		mTutorialArrow:Show(findProgramRow(unitId), -90, UDim2.new(0.7, 0, 0.5, 0))
	end

	function this:TutorialHighlightCommand(commandId: string)
		mTutorialArrow:Show(findActionEntry(commandId), 180, UDim2.new(0.5, 0, 0.2, 0))
	end

	function this:TutorialHide()
		mTutorialArrow:Hide()
	end

	function this:SetSelectedCommand(commandId: string?)
		root().setState({ selectedCommandId = commandId or StatefulRoot.None })
	end

	function this:ClearProgramListSelection()
		root().setState({ selectedProgramId = StatefulRoot.None })
	end

	-- Set the selected unit
	function this:SetSelectedUnit(unit: any)
		setProgramInfoPane(unit)
	end
	function this:SetSelectedUnitDefinition(unitId: string)
		setProgramInfoPaneDef(unitId)
	end
	function this:ClearSelectedUnit()
		root().setState({ infoPane = StatefulRoot.None })
	end

	function this:SetSelectedUpload()
		setProgramInfoPane("upload")
	end
	function this:SetSelectedPickup(pickup: string)
		setProgramInfoPane(pickup)
	end

	function this:Hide()
		mGui.Visible = false
	end

	this.UnitSelected:connect(function(unitId)
		setProgramInfoPaneDef(unitId)
	end)

	function this:SetProgramListVisible(state: boolean)
		root().setState({ programListVisible = state })
	end

	local mDestroyed = false
	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		mTutorialArrow:Destroy()
		root().unmount()
		mGui:Destroy()
	end

	mGui.Parent = container

	return this
end

return UnitInfoViewMobile
