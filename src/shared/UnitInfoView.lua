--!strict
-- React conversion of UnitInfoView (the desktop unit info panels). Public API
-- is unchanged from the template version. The view owns TWO top-level GUIs
-- (ProgramList and ProgramInfo, both parented into the container), so it uses
-- two imperative hosts each with their own StatefulRoot (layout matches
-- ui-reference/ModuleTemplates/UnitInfoView.json). The list scrolls with a
-- native ScrollingFrame instance (not the ScrollingFrame library).

local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)

local e = React.createElement

local kInkColor = Color3.new(0.105882, 0.164706, 0.207843)
local kHeaderColor = Color3.new(0.737255, 0.784314, 0.886275)
local kSelectedOverlayImage = "rbxassetid://1338297982"

--------------------------------------------------------------------------------
-- Program list
--------------------------------------------------------------------------------

type ProgramRow = {
	Id: string,
	Count: number,
}

type ProgramListState = {
	programs: { ProgramRow },
	onProgramClick: (id: string) -> (),
}

local function ProgramListContent(props: ProgramListState)
	local rows: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
	}
	for i, row in props.programs do
		rows[row.Id] = e("TextButton", {
			Active = true,
			Size = UDim2.new(1, -16, 0, 30),
			LayoutOrder = i,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = kInkColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = " " .. row.Count .. "x " .. Scripts[row.Id].Name,
			[React.Event.MouseButton1Click] = function()
				props.onProgramClick(row.Id)
			end,
		})
	end

	return e(React.Fragment, nil, {
		Title = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = kHeaderColor,
			Font = Enum.Font.Code,
			TextSize = 18,
			TextColor3 = kInkColor,
			Text = "Programs",
		}),
		List = e("ScrollingFrame", {
			Position = UDim2.new(0, 1, 0, 34),
			Size = UDim2.new(1, -2, 1, -34),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			-- Quirk preserved: 33 per row (30 height + 3 padding, one extra)
			CanvasSize = UDim2.new(0, 0, 0, 33 * #props.programs),
			ScrollBarImageColor3 = Color3.new(1, 1, 1),
			ScrollBarThickness = 12,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, rows),
	})
end

--------------------------------------------------------------------------------
-- Program info pane
--------------------------------------------------------------------------------

type CommandEntry = {
	Key: string, -- 'move' or the command id
	Name: string,
	Text1: string,
	Text2: string,
	NotEnoughSize: boolean,
	SizeReqOk: boolean,
	IsMove: boolean,
}

type InfoPane = {
	name: string,
	image: string,
	color: Color3,
	moveText: string,
	maxSizeText: string,
	flavorText: string,
	entries: { CommandEntry },
}

type ProgramInfoState = {
	pane: InfoPane?,
	selectedCommandId: string?,
	onEntryDown: (entry: CommandEntry) -> (),
	onEntryClick: (entry: CommandEntry) -> (),
}

local function commandListEntry(
	entry: CommandEntry,
	order: number,
	selected: boolean,
	onDown: (entry: CommandEntry) -> (),
	onClick: (entry: CommandEntry) -> ()
)
	local function overlayPart(anchor: Vector2, position: UDim2, size: UDim2, rectOffset: Vector2)
		return e("ImageLabel", {
			Name = "Part",
			AnchorPoint = anchor,
			Position = position,
			Size = size,
			BackgroundTransparency = 1,
			Image = kSelectedOverlayImage,
			ImageRectOffset = rectOffset,
			ImageRectSize = Vector2.new(size.X.Offset, size.Y.Offset),
		})
	end
	return e("ImageButton", {
		Active = true,
		BorderSizePixel = 2,
		Size = UDim2.new(0, 100, 0, 100),
		LayoutOrder = order,
		[React.Event.MouseButton1Down] = function()
			onDown(entry)
		end,
		[React.Event.MouseButton1Click] = function()
			onClick(entry)
		end,
	}, {
		CommandName = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundColor3 = kHeaderColor,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = kInkColor,
			Text = entry.Name,
		}),
		CommandText1 = e("TextLabel", {
			Position = UDim2.new(0, 2, 0, 16),
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = kInkColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = entry.Text1,
		}),
		CommandText2 = e("TextLabel", {
			Position = UDim2.new(0, 2, 0, 32),
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = kInkColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = entry.Text2,
		}),
		NotEnoughSize = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.7, 0),
			Size = UDim2.new(0, 94, 0, 22),
			BackgroundColor3 = Color3.new(1, 0.0666667, 0),
			BackgroundTransparency = 0.3,
			BorderColor3 = Color3.new(0.866667, 0.866667, 0.866667),
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(1, 1, 1),
			Text = "Insufficient Size",
			Visible = entry.NotEnoughSize,
		}),
		SelectedOverlay = e("ImageLabel", {
			Size = UDim2.new(0, 100, 0, 100),
			BackgroundTransparency = 1,
			Visible = selected,
		}, {
			PartLeft = overlayPart(
				Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 16, 0, 32), Vector2.new(0, 16)),
			PartRight = overlayPart(
				Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0), UDim2.new(0, 16, 0, 32), Vector2.new(48, 16)),
			PartBottom = overlayPart(
				Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 32, 0, 16), Vector2.new(16, 48)),
		}),
	})
end

local function ProgramInfoContent(props: ProgramInfoState)
	local pane = props.pane

	local entryElements: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
		}),
	}
	if pane then
		for i, entry in pane.entries do
			entryElements[entry.Key] = commandListEntry(
				entry, i, props.selectedCommandId == entry.Key, props.onEntryDown, props.onEntryClick)
		end
	end

	return e(React.Fragment, nil, {
		Title = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = kHeaderColor,
			Font = Enum.Font.Code,
			TextSize = 18,
			TextColor3 = kInkColor,
			Text = "Information",
		}),
		UnitName = e("TextLabel", {
			Position = UDim2.new(0, 2, 0, 34),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = kInkColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if pane then pane.name else "",
		}),
		UnitImage = e("ImageLabel", {
			Position = UDim2.new(0, 2, 0, 51),
			Size = UDim2.new(0, 32, 0, 32),
			BackgroundColor3 = if pane then pane.color else Color3.new(1, 1, 1),
			Image = if pane then pane.image else "",
		}),
		UnitMaxSize = e("TextLabel", {
			Position = UDim2.new(0, 37, 0, 50),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = kInkColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if pane then pane.maxSizeText else "",
		}),
		UnitMove = e("TextLabel", {
			Position = UDim2.new(0, 37, 0, 66),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = kInkColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if pane then pane.moveText else "",
		}),
		UnitFlavorText = e("TextLabel", {
			Position = UDim2.new(0, 2, 0, 82),
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansItalic,
			TextSize = 14,
			TextColor3 = kInkColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if pane then pane.flavorText else "",
		}),
		CommandList = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(1, 5, 1, 0),
			Size = UDim2.new(0, 100, 0, 100),
			BackgroundTransparency = 1,
		}, entryElements),
	})
end

--------------------------------------------------------------------------------
-- View object
--------------------------------------------------------------------------------

local UnitInfoView = {}

function UnitInfoView.new(container: Instance, availablePrograms: { any })
	local this = {}

	this.UnitSelected = Signal.new()
	this.CommandSelected = Signal.new()

	local mTutorialArrow = TutorialArrowView.new()

	-- For tutorial, restrict unit selection to a given unit in the program list
	local mOnlySelectUnit: string? = nil

	local mProgramInfo = Instance.new("Frame")
	mProgramInfo.Name = "ProgramInfo"
	mProgramInfo.Position = UDim2.new(0, 2, 1, -131)
	mProgramInfo.Size = UDim2.new(0, 150, 0, 130)
	mProgramInfo.BorderSizePixel = 2

	local mProgramList = Instance.new("Frame")
	mProgramList.Name = "ProgramList"
	mProgramList.Position = UDim2.new(0, 2, 0, 2)
	mProgramList.Size = UDim2.new(0, 150, 0, 250)
	mProgramList.BorderSizePixel = 2

	local mPrograms: { ProgramRow } = {}
	local mProgramsById: { [string]: ProgramRow } = {}
	local function addProgram(id: string, initialCount: number): ProgramRow
		local newInfo = { Id = id, Count = initialCount }
		table.insert(mPrograms, newInfo)
		mProgramsById[id] = newInfo
		return newInfo
	end
	for _, info in availablePrograms do
		addProgram(info.Id, info.Count)
	end

	local mListRoot = StatefulRoot.create(mProgramList, ProgramListContent, {
		programs = table.clone(mPrograms),
		onProgramClick = function(id: string)
			if not mOnlySelectUnit or mOnlySelectUnit == id then
				this.UnitSelected:fire(id)
			end
		end,
	})

	local mInfoRoot = StatefulRoot.create(mProgramInfo, ProgramInfoContent, {
		pane = nil,
		selectedCommandId = nil,
		onEntryDown = function(entry: CommandEntry)
			if entry.IsMove then
				this.CommandSelected:fire(nil)
			end
		end,
		onEntryClick = function(entry: CommandEntry)
			if not entry.IsMove and entry.SizeReqOk then
				this.CommandSelected:fire(entry.Key)
			end
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
		mListRoot.setState({ programs = table.clone(mPrograms) })
	end
	function this:GetCount(unitId: string): number
		return mProgramsById[unitId].Count
	end

	-- Rendered instance lookups (post-flush only)
	local function findProgramRow(unitId: string): Instance
		return ((mProgramList:FindFirstChild("List") :: Instance):FindFirstChild(unitId)) :: Instance
	end
	local function findCommandEntry(key: string): Instance
		return ((mProgramInfo:FindFirstChild("CommandList") :: Instance):FindFirstChild(key)) :: Instance
	end

	-- Show a tutorial arrow on a program
	function this:TutorialHighlightUnit(unitId: string)
		mOnlySelectUnit = unitId
		mTutorialArrow:Show(findProgramRow(unitId), -90, UDim2.new(0.7, 0, 0.5, 0))
	end

	function this:TutorialHighlightCommand(commandId: string)
		mTutorialArrow:Show(findCommandEntry(commandId), 180, UDim2.new(0.5, 0, 0, 0))
	end

	function this:TutorialHide()
		mTutorialArrow:Hide()
	end

	local function sectorStr(sectors: number): string
		if sectors == 0 then
			return "zero sectors"
		elseif sectors == 1 then
			return "a sector"
		else
			return sectors .. " sectors"
		end
	end

	local function setProgramInfoPane(unit: any)
		mProgramInfo.Visible = true
		mTutorialArrow:Hide()

		-- Special cases for info on other things on the board
		local function specialPane(name: string, image: string, flavorText: string)
			mInfoRoot.setState({
				pane = {
					name = name,
					image = image,
					color = Color3.new(0, 0, 0),
					moveText = "",
					maxSizeText = "",
					flavorText = flavorText,
					entries = {},
				},
				selectedCommandId = StatefulRoot.None,
			})
		end
		if unit == "upload" then
			specialPane("Upload Zone", "rbxassetid://1333805802", "Upload your units here to do battle!")
			return
		elseif unit == "credits" then
			specialPane("Credits", "rbxassetid://1346715274", "Extra credits... see if you can grab them on your way to victory.")
			return
		elseif unit == "codes" then
			specialPane("Decryption Codes", "rbxassetid://1346714452", "Your objective is to grab these, no need to terminate all the enemy scripts.")
			return
		end

		local entries: { CommandEntry } = {}
		if not unit.Enemy and unit.MoveLeft > 0 then
			table.insert(entries, {
				Key = "move",
				Name = "Move",
				Text1 = "Move the unit.",
				Text2 = "",
				NotEnoughSize = false,
				SizeReqOk = true,
				IsMove = true,
			})
		end
		for _, command in unit.Definition.CommandList do
			local name
			if command.SizeReq > 0 then
				name = command.Name .. " (" .. command.SizeReq .. ")"
			else
				name = command.Name
			end
			local bodyText
			if command.Type == "one" then
				bodyText = "Add a tile to the grid"
			elseif command.Type == "zero" then
				bodyText = "Remove a tile from the grid"
			elseif command.Type == "damage" then
				bodyText = "Delete " .. sectorStr(command.Amount) .. " from the target"
			elseif command.Type == "speedMod" then
				bodyText = "Modify target speed by " .. command.Amount
			elseif command.Type == "sizeMod" then
				bodyText = "Increase target max size by " .. command.Amount
			elseif command.Type == "grow" then
				bodyText = "Add " .. command.Amount .. " sectors to the target"
			end
			if command.Cost > 0 then
				bodyText = bodyText .. ", and delete " .. sectorStr(command.Cost) .. " from " .. unit.Definition.Name
			end
			bodyText = bodyText .. "."
			if command.SizeReq > 0 then
				bodyText = bodyText .. " (requires " .. command.SizeReq .. " size)"
			end
			local text1, text2
			if command.Range > 1 then
				text1 = "Range: " .. command.Range
				text2 = bodyText
			else
				text1 = bodyText
				text2 = ""
			end
			table.insert(entries, {
				Key = command.Id,
				Name = name,
				Text1 = text1,
				Text2 = text2,
				NotEnoughSize = #unit.Tail < command.SizeReq,
				SizeReqOk = #unit.Tail >= command.SizeReq,
				IsMove = false,
			})
		end

		mInfoRoot.setState({
			pane = {
				name = unit.Definition.Name,
				image = unit.Definition.Image,
				color = unit.Definition.Color,
				moveText = "Move: " .. unit.Move .. ((unit.Move == 10) and " (max)" or ""),
				maxSizeText = "Max Size: " .. unit.MaxSize,
				flavorText = unit.Definition.Desc,
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

	function this:SetSelectedCommand(commandId: string)
		mInfoRoot.setState({ selectedCommandId = commandId })
	end

	-- Set the selected unit
	function this:SetSelectedUnit(unit: any)
		setProgramInfoPane(unit)
	end
	function this:SetSelectedUnitDefinition(unitId: string)
		setProgramInfoPaneDef(unitId)
	end
	function this:ClearSelectedUnit()
		mProgramInfo.Visible = false
	end

	function this:SetSelectedUpload()
		setProgramInfoPane("upload")
	end
	function this:SetSelectedPickup(pickup: string)
		setProgramInfoPane(pickup)
	end

	function this:Hide()
		this:ClearSelectedUnit()
		this:SetProgramListVisible(false)
	end

	function this:ClearProgramListSelection()
		-- Nothing to do
	end

	this.UnitSelected:connect(function(unitId)
		setProgramInfoPaneDef(unitId)
	end)

	function this:SetProgramListVisible(state: boolean)
		mProgramList.Visible = state
	end

	local mDestroyed = false
	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		mTutorialArrow:Destroy()
		mListRoot.unmount()
		mInfoRoot.unmount()
		mProgramInfo:Destroy()
		mProgramList:Destroy()
	end

	mProgramInfo.Parent = container
	mProgramList.Parent = container

	return this
end

return UnitInfoView
