--!strict
-- The unified battle HUD (replaces UnitInfoView / UnitInfoViewMobile inside
-- databattles): one responsive Win95-styled layout for desktop and mobile.
-- - Bottom center: the selected unit's commands as a row of buttons
--   (Move + each command; disabled ones greyed with their size requirement).
-- - Top left: a floating unit info window (image, stats, description).
-- - Left: a floating Programs window during the upload phase.
-- Exposes the same API surface GameView used with the old unit info views,
-- so the game flow is unchanged.

local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"

--------------------------------------------------------------------------------
-- Command text generation (same wording as the old views)
--------------------------------------------------------------------------------

local function sectorStr(sectors: number): string
	if sectors == 0 then
		return "zero sectors"
	elseif sectors == 1 then
		return "a sector"
	else
		return sectors .. " sectors"
	end
end

local function commandBodyText(unitName: string, command: any): string
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
	else
		bodyText = ""
	end
	if command.Cost > 0 then
		bodyText = bodyText .. ", and delete " .. sectorStr(command.Cost) .. " from " .. unitName
	end
	bodyText = bodyText .. "."
	if command.SizeReq > 0 then
		bodyText = bodyText .. " (requires " .. command.SizeReq .. " size)"
	end
	if command.Range > 1 then
		bodyText = "Range: " .. command.Range .. ". " .. bodyText
	end
	return bodyText
end

--------------------------------------------------------------------------------
-- Render types
--------------------------------------------------------------------------------

type CommandEntry = {
	Key: string, -- 'move' or the command id
	Label: string,
	Description: string,
	Disabled: boolean,
	IsMove: boolean,
}

type InfoPane = {
	name: string,
	image: string,
	color: Color3,
	moveText: string,
	maxSizeText: string,
	flavorText: string,
}

type ProgramRow = {
	Id: string,
	Count: number,
}

--------------------------------------------------------------------------------
-- Render helpers
--------------------------------------------------------------------------------

local function windowChrome(title: string, props: { [string]: any }, children: { [string]: any })
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 2,
		Image = kWindowImage,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = kWindowSliceCenter,
		ImageRectSize = kWindowImageRectSize,
	}
	for k, v in props do
		base[k] = v
	end
	local allChildren: { [string]: any } = {
		WindowTitle = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0, 12),
			Size = UDim2.new(1, -12, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = title,
		}),
		Inset = e("ImageLabel", {
			Position = UDim2.new(0, 5, 0, 25),
			Size = UDim2.new(1, -10, 1, -29),
			BackgroundTransparency = 1,
			Image = kInsetImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(8, 8, 8, 8),
		}, children),
	}
	return e("ImageLabel", base, allChildren)
end

local function commandButton(entry: CommandEntry, selected: boolean, onClick: (entry: CommandEntry) -> ())
	local textColor = if selected then Color3.new(1, 1, 1)
		elseif entry.Disabled then Color3.new(0.4, 0.4, 0.4)
		else Color3.new(0, 0, 0)
	return e(WindowsButton, {
		Name = entry.Key,
		Size = UDim2.new(0, 160, 0, 54),
		-- Attacks first, the move action last
		LayoutOrder = entry.IsMove and 1 or 0,
		ImageColor3 = if selected
			then Color3.new(0, 0, 1)
			elseif entry.Disabled then Color3.new(0.55, 0.55, 0.55)
			else nil,
		OnClick = function()
			onClick(entry)
		end,
	}, {
		Label = e("TextLabel", {
			Position = UDim2.new(0, 6, 0, 3),
			Size = UDim2.new(1, -12, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 20,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = entry.Label,
		}),
		Description = e("TextLabel", {
			Position = UDim2.new(0, 6, 0, 25),
			Size = UDim2.new(1, -12, 1, -28),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			TextColor3 = if selected then Color3.new(0.85, 0.85, 1)
				elseif entry.Disabled then Color3.new(0.45, 0.45, 0.45)
				else Color3.new(0.25, 0.25, 0.25),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = entry.Description,
		}),
	})
end

type HudState = {
	pane: InfoPane?,
	commands: { CommandEntry },
	selectedCommandId: string?,
	programs: { ProgramRow },
	programsVisible: boolean,
	hidden: boolean,
	onCommandClick: (entry: CommandEntry) -> (),
	onProgramClick: (id: string) -> (),
	onProgramPress: (id: string, viewportPos: Vector2) -> (),
}

local function BattleHudContent(props: HudState)
	if props.hidden then
		return nil
	end

	-- The selected unit's commands, stacked below the info window
	local commandItems: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	for _, entry in props.commands do
		commandItems[entry.Key] = commandButton(entry, props.selectedCommandId == entry.Key, props.onCommandClick)
	end

	-- Programs window rows
	local programItems: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Header = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 22,
			TextColor3 = Color3.new(0, 0, 0.5),
			Text = "Drag to Place",
			LayoutOrder = 0,
		}),
	}
	for i, row in props.programs do
		local def = Scripts[row.Id]
		local hasAny = row.Count > 0
		programItems[row.Id] = e("ImageButton", {
			Active = true,
			AutoButtonColor = hasAny,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if hasAny then 0 else 0.5,
			BorderSizePixel = 0,
			Image = "",
			LayoutOrder = i,
			[React.Event.MouseButton1Click] = function()
				props.onProgramClick(row.Id)
			end,
			[React.Event.InputBegan] = function(_rbx, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					props.onProgramPress(row.Id, Vector2.new(input.Position.X, input.Position.Y))
				end
			end,
		}, {
			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.new(0, 28, 0, 28),
				BackgroundColor3 = def.Color,
				BorderColor3 = Color3.new(0, 0, 0),
				Image = def.Image,
				ImageTransparency = if hasAny then 0 else 0.5,
			}),
			CountLabel = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 34, 0.5, 0),
				Size = UDim2.new(0, 26, 0, 28),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 18,
				TextColor3 = if hasAny then Color3.new(0, 0, 0) else Color3.new(0.5, 0.5, 0.5),
				Text = row.Count .. "x",
			}),
			NameLabel = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 62, 0.5, 0),
				Size = UDim2.new(1, -66, 0, 28),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 16,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = if hasAny then Color3.new(0, 0, 0) else Color3.new(0.5, 0.5, 0.5),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = def.Name,
			}),
		})
	end

	local pane = props.pane

	-- Everything on the left stacks in one column: the Programs window during
	-- setup, then the unit info window with its commands right below it
	local commandCount = #props.commands
	local commandRowHeight = commandCount * 54 + math.max(0, commandCount - 1) * 8

	return e(React.Fragment, nil, {
		LeftColumn = e("Frame", {
			Position = UDim2.new(0, 12, 0, 12),
			Size = UDim2.new(0, 160, 1, -24),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		CommandRow = e("Frame", {
			Size = UDim2.new(0, 160, 0, commandRowHeight),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, commandItems),
		InfoWindow = if pane
			then windowChrome(pane.name, {
				Name = "InfoWindow",
				Size = UDim2.new(0, 160, 0, 130),
				LayoutOrder = 1,
			}, {
				UnitImage = e("ImageLabel", {
					Position = UDim2.new(0, 6, 0, 6),
					Size = UDim2.new(0, 40, 0, 40),
					BackgroundColor3 = pane.color,
					BorderColor3 = Color3.new(0, 0, 0),
					Image = pane.image,
				}),
				MoveText = e("TextLabel", {
					Position = UDim2.new(0, 54, 0, 6),
					Size = UDim2.new(1, -58, 0, 18),
					BackgroundTransparency = 1,
					Font = Enum.Font.Code,
					TextSize = 15,
					TextColor3 = Color3.new(0, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = pane.moveText,
				}),
				MaxSizeText = e("TextLabel", {
					Position = UDim2.new(0, 54, 0, 26),
					Size = UDim2.new(1, -58, 0, 18),
					BackgroundTransparency = 1,
					Font = Enum.Font.Code,
					TextSize = 15,
					TextColor3 = Color3.new(0, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = pane.maxSizeText,
				}),
				FlavorText = e("TextLabel", {
					Position = UDim2.new(0, 6, 0, 52),
					Size = UDim2.new(1, -12, 1, -56),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 15,
					TextColor3 = Color3.new(0, 0, 0),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = pane.flavorText,
				}),
			})
			else nil,
		ProgramsWindow = if props.programsVisible
			then windowChrome("Programs", {
				Name = "ProgramsWindow",
				Size = UDim2.new(0, 160, 0, 40 * math.max(1, #props.programs) + 78),
				LayoutOrder = 0,
			}, programItems)
			else nil,
		}),
	})
end

--------------------------------------------------------------------------------
-- View object (API-compatible with the old unit info views)
--------------------------------------------------------------------------------

local BattleHud = {}

function BattleHud.new(container: Instance, availablePrograms: { any })
	local this = {}

	this.UnitSelected = Signal.new()
	this.CommandSelected = Signal.new()
	this.ProgramDragBegan = Signal.new() -- (id: string, viewportPos: Vector2)

	local mGui = Instance.new("Frame")
	mGui.Name = "BattleHud"
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundTransparency = 1
	mGui.ZIndex = 3

	local mPrograms: { ProgramRow } = {}
	local mProgramsById: { [string]: ProgramRow } = {}
	local function addProgram(id: string, count: number): ProgramRow
		local row = { Id = id, Count = count }
		table.insert(mPrograms, row)
		mProgramsById[id] = row
		return row
	end
	for _, info in availablePrograms do
		addProgram(info.Id, info.Count)
	end

	-- For tutorial, restrict program selection to a given unit
	local mTutorialArrow = TutorialArrowView.new()
	local mOnlySelectUnit: string? = nil

	local mRoot = StatefulRoot.create(mGui, BattleHudContent, {
		pane = nil,
		commands = {},
		selectedCommandId = nil,
		programs = table.clone(mPrograms),
		programsVisible = true,
		hidden = false,
		onCommandClick = function(entry: CommandEntry)
			if entry.Disabled then
				return
			end
			-- Same semantics as the old views: move fires nil
			this.CommandSelected:fire(if entry.IsMove then nil else entry.Key)
		end,
		onProgramClick = function(id: string)
			if not mOnlySelectUnit or mOnlySelectUnit == id then
				this.UnitSelected:fire(id)
			end
		end,
		onProgramPress = function(id: string, viewportPos: Vector2)
			if mProgramsById[id].Count > 0 and (not mOnlySelectUnit or mOnlySelectUnit == id) then
				this.ProgramDragBegan:fire(id, viewportPos)
			end
		end,
	})

	local function setPane(pane: InfoPane?, commands: { CommandEntry })
		mRoot.setState({
			pane = pane or StatefulRoot.None,
			commands = commands,
			selectedCommandId = StatefulRoot.None,
		})
	end

	local function unitPane(unit: any): InfoPane
		return {
			name = unit.Definition.Name,
			image = unit.Definition.Image,
			color = unit.Definition.Color,
			moveText = "Move: " .. unit.Move .. ((unit.Move == 10) and " (max)" or ""),
			maxSizeText = "Max Size: " .. unit.MaxSize,
			flavorText = unit.Definition.Desc,
		}
	end

	local function unitCommands(unit: any): { CommandEntry }
		local commands: { CommandEntry } = {}
		if not unit.Enemy and unit.MoveLeft > 0 then
			table.insert(commands, {
				Key = "move",
				Label = "Move",
				Description = "Move the script.",
				Disabled = false,
				IsMove = true,
			})
		end
		for _, command in unit.Definition.CommandList do
			table.insert(commands, {
				Key = command.Id,
				Label = if command.SizeReq > 0 then command.Name .. " (" .. command.SizeReq .. ")" else command.Name,
				Description = commandBodyText(unit.Definition.Name, command),
				Disabled = #unit.Tail < command.SizeReq,
				IsMove = false,
			})
		end
		return commands
	end

	local kDummyTail = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }

	function this:SetSelectedUnit(unit: any)
		setPane(unitPane(unit), unitCommands(unit))
	end

	function this:SetSelectedUnitDefinition(unitId: string)
		local dummyUnit = {
			MoveLeft = 0,
			Tail = kDummyTail,
			Definition = Scripts[unitId],
			Move = Scripts[unitId].Move,
			MaxSize = Scripts[unitId].MaxSize,
		}
		this:SetSelectedUnit(dummyUnit)
	end

	local function specialPane(name: string, image: string, flavorText: string)
		setPane({
			name = name,
			image = image,
			color = Color3.new(0, 0, 0),
			moveText = "",
			maxSizeText = "",
			flavorText = flavorText,
		}, {})
	end

	function this:SetSelectedUpload()
		specialPane("Upload Zone", "rbxassetid://1333805802", "Upload your units here to do battle!")
	end

	function this:SetSelectedPickup(pickup: string)
		if pickup == "credits" then
			specialPane("Credits", "rbxassetid://1346715274", "Extra credits... see if you can grab them on your way to victory.")
		elseif pickup == "codes" then
			specialPane("Decryption Codes", "rbxassetid://1346714452", "Your objective is to grab these, no need to terminate all the enemy scripts.")
		end
	end

	function this:ClearSelectedUnit()
		setPane(nil, {})
	end

	function this:SetSelectedCommand(commandId: string?)
		mRoot.setState({ selectedCommandId = commandId or "move" })
	end

	function this:UpdateCount(unitId: string, delta: number)
		local row = mProgramsById[unitId]
		if row then
			row.Count = row.Count + delta
		else
			row = addProgram(unitId, delta)
		end
		mRoot.setState({ programs = table.clone(mPrograms) })
	end

	function this:GetCount(unitId: string): number
		return mProgramsById[unitId].Count
	end

	function this:SetProgramListVisible(state: boolean)
		mRoot.setState({ programsVisible = state })
	end

	function this:ClearProgramListSelection()
		-- Nothing to do
	end

	function this:Hide()
		mRoot.setState({ hidden = true })
	end

	-- Rendered lookups for the tutorial arrows (post-flush only; recursive
	-- since the windows live inside the left column stack)
	local function findProgramRow(unitId: string): Instance?
		local window = mGui:FindFirstChild("ProgramsWindow", true)
		local inset = window and window:FindFirstChild("Inset")
		return inset and inset:FindFirstChild(unitId)
	end
	local function findCommandButton(key: string): Instance?
		local row = mGui:FindFirstChild("CommandRow", true)
		return row and row:FindFirstChild(key)
	end

	function this:TutorialHighlightUnit(unitId: string)
		mOnlySelectUnit = unitId
		local row = findProgramRow(unitId)
		if row then
			mTutorialArrow:Show(row, -90, UDim2.new(1, 20, 0.5, 0))
		end
	end

	function this:TutorialHighlightCommand(commandId: string)
		local button = findCommandButton(commandId)
		if button then
			-- At the button's right edge pointing left at it: unambiguous
			-- about which button in the stack is meant
			mTutorialArrow:Show(button, -90, UDim2.new(1, 20, 0.5, 0))
		end
	end

	function this:TutorialHide()
		mTutorialArrow:Hide()
	end

	local mDestroyed = false
	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		mTutorialArrow:Destroy()
		mRoot.unmount()
		mGui:Destroy()
	end

	mGui.Parent = container

	return this
end

return BattleHud
