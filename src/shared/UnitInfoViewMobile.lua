local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local ScrollingFrame = require(game.ReplicatedStorage.ScrollingFrame)
local TextService = game:GetService('TextService')

local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)

local UnitInfoViewMobile = {}

-- Colors
local GreyColor = Color3.new(0.75, 0.75, 0.75)
local BlueColor = Color3.new(0, 0, 0.5)
local TextBlack = Color3.new(0, 0, 0)
local TextWhite = Color3.new(1, 1, 1)

local ProgramListEntryHeight = script.ProgramListEntry.Size.Y.Offset
function UnitInfoViewMobile.getProgramListHeight(programCount)
	return ProgramListEntryHeight*programCount + 2*(programCount - 1)
end

local ActionListTextWidth = 133
local ActionListEntryBodyText = script.ActionListEntry.BodyText
function UnitInfoViewMobile.getActionListBodyTextHeight(text)
	return TextService:GetTextSize(
		text,
		ActionListEntryBodyText.TextSize,
		ActionListEntryBodyText.Font,
		Vector2.new(ActionListTextWidth, 500)).y
end

local ActionListEntryNameText = script.ActionListEntry.NameLine.Label
function UnitInfoViewMobile.getActionListNameTextWidth(text)
	return TextService:GetTextSize(
		text,
		ActionListEntryNameText.TextSize,
		ActionListEntryNameText.Font,
		Vector2.new(500, 500)).x
end

function UnitInfoViewMobile.getCommandText(unitId, command)
	local function sectorStr(sectors)
		if sectors == 0 then
			return "zero sectors"
		elseif sectors == 1 then
			return "a sector"
		else
			return sectors.." sectors"
		end
	end
	local nameText;
	local bodyText;
	if command.SizeReq > 0 then
		nameText = command.Name.." ("..command.SizeReq..")"
	else
		nameText = command.Name
	end
	local bodyText;
	if command.Type == 'one' then
		bodyText = "Add a tile to the grid"
	elseif command.Type == 'zero' then
		bodyText = "Remove a tile from the grid"
	elseif command.Type == 'damage' then
		bodyText = "Delete "..sectorStr(command.Amount).. " from the target"
	elseif command.Type == 'speedMod' then
		if command.Amount > 0 then
			bodyText = "Increase target speed by "..command.Amount
		else
			bodyText = "Decrease target speed by "..(-command.Amount)
		end
	elseif command.Type == 'sizeMod' then
		bodyText = "Increase target max size by "..command.Amount
	elseif command.Type == 'grow' then
		bodyText = "Add "..command.Amount.." sectors to the target"
	end
	if command.Cost > 0 then
		bodyText = bodyText..", and delete ".. sectorStr(command.Cost).." from "..Scripts[unitId].Name
	end
	bodyText = bodyText.."."
	if command.SizeReq > 0 then
		bodyText = bodyText.." (requires "..command.SizeReq.." size)"
	end
	if command.Range > 1 then
		bodyText = "Range: "..command.Range.."\n"..bodyText
	end
	return nameText, bodyText
end

function UnitInfoViewMobile.new(container, availablePrograms)
	local this = {}

	this.UnitSelected = Signal.new()
	this.CommandSelected = Signal.new()

	local mGui = script.SideTray:Clone()
	local mProgramList = mGui.Content.ProgramList
	local mProgramInfo = mGui.Content.ProgramInfo

	local mProgramListVisible = true
	local mProgramInfoVisible = false

	-- For tutorial, restrict unit selection to a given unit in the program list
	local mTutorialArrow = TutorialArrowView.new()
	local mOnlySelectUnit = nil

	-- Add all of the initial programs
	local mAvailablePrograms = {}
	local mProgramListCurrentlySelected = nil
	local mProgramCount = 0
	local function setProgramListSelection(id)
		if mProgramListCurrentlySelected then
			mProgramListCurrentlySelected.BackgroundColor3 = Color3.new(1, 1, 1)
			mProgramListCurrentlySelected.CountLabel.TextColor3 = TextBlack
			mProgramListCurrentlySelected.NameLabel.TextColor3 = TextBlack
		end
		if id then
			mProgramListCurrentlySelected = mAvailablePrograms[id].Gui
		else
			mProgramListCurrentlySelected = nil
		end
		if mProgramListCurrentlySelected then
			mProgramListCurrentlySelected.BackgroundColor3 = BlueColor
			mProgramListCurrentlySelected.CountLabel.TextColor3 = TextWhite
			mProgramListCurrentlySelected.NameLabel.TextColor3 = TextWhite
		end
	end
	local mScrollbar;
	local function addProgram(id, initialCount)
		mProgramCount = mProgramCount + 1
		local newInfo = {
			Id = id;
			Count = initialCount;
			Gui = script.ProgramListEntry:Clone();
		}
		mAvailablePrograms[newInfo.Id] = newInfo
		newInfo.Gui.CountLabel.Text = tostring(initialCount)
		newInfo.Gui.NameLabel.Text = Scripts[id].Name
		newInfo.Gui.Icon.Image = Scripts[id].Image
		newInfo.Gui.Icon.BackgroundColor3 = Scripts[id].Color
		newInfo.Gui.MouseButton1Click:connect(function()
			if not mOnlySelectUnit or mOnlySelectUnit == id then
				setProgramListSelection(newInfo.Id)
				this.UnitSelected:fire(newInfo.Id)
			end
		end)
		-- Pass on the event rather than stealing it
		newInfo.Gui.InputBegan:connect(function(inputObject)
			mScrollbar:InputBegan(inputObject)
		end)
		newInfo.Gui.Parent = mProgramList.ContentClip.Content
		mProgramList.ContentClip.Content.Size = UDim2.new(1, 0, 0, UnitInfoViewMobile.getProgramListHeight(mProgramCount))
		return newInfo
	end
	for i, info in pairs(availablePrograms) do
		addProgram(info.Id, info.Count)
	end

	-- Build the scrollbar
	mScrollbar = ScrollingFrame.new(mProgramList.ContentClip.Content)
	mScrollbar:AddScrollbar(mProgramList.ScrollGutter.ScrollbarContainer.Scrollbar)
	mProgramList.ScrollGutter.DownArrow.MouseButton1Click:connect(function()
		-- TODO: Figure out how to scroll up / down the right amount for these presses
		mScrollbar:ScrollToBottom()
	end)
	mProgramList.ScrollGutter.UpArrow.MouseButton1Click:connect(function()
		mScrollbar:ScrollToTop()
	end)

	-- Update the count of a program
	function this:UpdateCount(unitId, delta)
		local data = mAvailablePrograms[unitId]
		if data then
			data.Count = data.Count + delta
			data.Gui.CountLabel.Text = tostring(data.Count)
		else
			data = addProgram(unitId, delta)
		end
	end
	function this:GetCount(unitId)
		return mAvailablePrograms[unitId].Count
	end

	-- Show a tutorial arrow on a program
	function this:TutorialHighlightUnit(unitId)
		mOnlySelectUnit = unitId
		mTutorialArrow:Show(mAvailablePrograms[unitId].Gui, -90, UDim2.new(0.7, 0, 0.5, 0))
	end

	-- Generate an action list entry
	local mActionListEntryCache = {}
	local function getActionListEntry(unitId, command)
		local entry = mActionListEntryCache[unitId..'_'..command.Id]
		if not entry then
			entry = script.ActionListEntry:Clone()
			local nameText = nil
			local bodyText = nil
			if command.Id == 'move' then
				-- Movement
				nameText = "Move"
				bodyText = "Move the script."
				entry.MouseButton1Click:connect(function()
					this.CommandSelected:fire(nil)
				end)
			else
				-- Normal command
				nameText, bodyText = UnitInfoViewMobile.getCommandText(unitId, command)
				entry.MouseButton1Down:connect(function()
					this.CommandSelected:fire(command.Id)
				end)
			end
			entry.NameLine.Label.Text = nameText
			entry.BodyText.Text = bodyText
			entry.NameLine.Label.Size = UDim2.new(0, UnitInfoViewMobile.getActionListNameTextWidth(nameText), 0, 16)
			local bodyHeight = UnitInfoViewMobile.getActionListBodyTextHeight(bodyText)
			entry.BodyText.Size = UDim2.new(entry.BodyText.Size.X, UDim.new(0, bodyHeight))
			entry.Size = UDim2.new(entry.Size.X, UDim.new(0, entry.BodyText.Position.Y.Offset + bodyHeight + 2))
			mActionListEntryCache[unitId..'_'..command.Id] = entry
		end
		return entry
	end

	local function getActionListFlavorTextEntry(text)
		local entry = script.ActionListEntry:Clone()
		entry.NameLine.Label.Visible = false
		entry.BodyText.Text = text
		local bodyHeight = UnitInfoViewMobile.getActionListBodyTextHeight(text)
		entry.BodyText.Size = UDim2.new(entry.BodyText.Size.X, UDim.new(0, bodyHeight))
		entry.Size = UDim2.new(entry.Size.X, UDim.new(0, entry.BodyText.Position.Y.Offset + bodyHeight + 2))
		return entry
	end

	-- The entries currently in our command list
	local mCurrentCommandListEntries = {}
	local mSelectedCommandListEntry = nil

	local function setSelectedCommand(commandId)
		if mSelectedCommandListEntry then
			mSelectedCommandListEntry.NameLine.Label.BackgroundColor3 = GreyColor
			mSelectedCommandListEntry.BackgroundColor3 = GreyColor
			mSelectedCommandListEntry.NameLine.Label.TextColor3 = TextBlack
			mSelectedCommandListEntry.BodyText.TextColor3 = TextBlack
		end
		if commandId then
			mSelectedCommandListEntry = mCurrentCommandListEntries[commandId]
		else
			mSelectedCommandListEntry = nil
		end
		if mSelectedCommandListEntry then
			mSelectedCommandListEntry.BackgroundColor3 = BlueColor
			mSelectedCommandListEntry.NameLine.Label.BackgroundColor3 = BlueColor
			mSelectedCommandListEntry.NameLine.Label.TextColor3 = TextWhite
			mSelectedCommandListEntry.BodyText.TextColor3 = TextWhite
		end
	end

	function this:TutorialHighlightCommand(commandId)
		mTutorialArrow:Show(mCurrentCommandListEntries[commandId], 180, UDim2.new(0.5, 0, 0.2, 0))
	end

	function this:TutorialHide()
		mTutorialArrow:Hide()
	end

	local function setProgramInfoStats(name, image, bgColor, move, maxSize)
		mProgramInfo.NameLine.Label.Text = name
		mProgramInfo.NameLine.Label.Size = UDim2.new(0, UnitInfoViewMobile.getActionListNameTextWidth(name), 0, 16)
		mProgramInfo.Icon.Image = image
		mProgramInfo.Icon.BackgroundColor3 = bgColor
		if move then
			mProgramInfo.Icon.MoveLabel.Visible = true
			mProgramInfo.Icon.MoveLabel.Value.Text = tostring(move)
			if move == 10 then
				mProgramInfo.Icon.MoveLabel.Value.MaxText.Visible = true
			end
		else
			mProgramInfo.Icon.MoveLabel.Visible = false
		end
		if maxSize then
			mProgramInfo.Icon.MaxSizeLabel.Visible = true
			mProgramInfo.Icon.MaxSizeLabel.Value.Text = tostring(maxSize)
		else
			mProgramInfo.Icon.MaxSizeLabel.Visible = false
		end
	end

	local function setProgramInfoPane(unit)
		mProgramInfoVisible = true

		mTutorialArrow:Hide()
		setSelectedCommand(nil) -- clear the selection highlight
		for commandId, gui in pairs(mCurrentCommandListEntries) do
			gui.Parent = nil
			mCurrentCommandListEntries[commandId] = nil
		end

		local function addEntry(id, entry)
			mCurrentCommandListEntries[id] = entry
			entry.Parent = mProgramInfo.ActionList
		end

		-- Special cases for info on other things on the board
		if unit == 'upload' then
			setProgramInfoStats(
				"Upload Zone", 'rbxassetid://1333805802', Color3.new(0, 0, 0),
				nil, nil)
			addEntry('flavor', getActionListFlavorTextEntry("Upload your units here to do battle!"))
			return
		elseif unit == 'credits' then
			setProgramInfoStats(
				"Credits", 'rbxassetid://1346715274', Color3.new(0, 0, 0),
				nil, nil)
			addEntry('flavor', getActionListFlavorTextEntry("Extra credits... see if you can grab them on your way to victory."))
			return
		elseif unit == 'codes' then
			setProgramInfoStats(
				"Decryption Codes", 'rbxassetid://1346714452', Color3.new(0, 0, 0),
				nil, nil)
			addEntry('flavor', getActionListFlavorTextEntry("Your objective is to grab these, no need to terminate all the enemy scripts."))
			return
		end

		-- Set the info
		setProgramInfoStats(
			unit.Definition.Name, unit.Definition.Image, unit.Definition.Color,
			unit.Move, unit.MaxSize)

		-- Add the commands
		if not unit.Enemy and unit.MoveLeft > 0 then
			addEntry('move', getActionListEntry(unit.Definition.Id, {Id = 'move'}))
		end
		for _, command in pairs(unit.Definition.CommandList) do
			addEntry(command.Id, getActionListEntry(unit.Definition.Id, command))
		end
	end

	local DummyTail = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1} -- Long enough to satisfy any requirement
	local function setProgramInfoPaneDef(unitId)
		local dummyUnit = {}
		dummyUnit.MoveLeft = 0
		dummyUnit.Tail = DummyTail
		dummyUnit.Definition = Scripts[unitId]
		dummyUnit.Move = dummyUnit.Definition.Move
		dummyUnit.MaxSize = dummyUnit.Definition.MaxSize
		setProgramInfoPane(dummyUnit)
	end

	local function updateLayout()
		local offset = 0
		if mProgramInfoVisible then
			mProgramInfo.Visible = true

			-- Calculate the height of the command list
			local count = 0
			for id, gui in pairs(mCurrentCommandListEntries) do
				count = count + 1
				local sz = gui.Size.Y.Offset
				offset = offset + sz
			end
			offset = offset + math.max(0, count - 1)*4 -- Add padding
			offset = offset + mProgramInfo.ActionList.Position.Y.Offset

			-- Add extra padding from UIPadding
			offset = offset + 2*8

			-- Size / position the program info
			if mProgramListVisible then
				mProgramInfo.Size = UDim2.new(1, 0, 0, offset)
				mProgramInfo.Position = UDim2.new(0, 0, 1, -offset)
			else
				mProgramInfo.Size = UDim2.new(1, 0, 0, offset)
				mProgramInfo.Position = UDim2.new(0, 0, 0, 0)
			end
		else
			mProgramInfo.Visible = false
		end

		if mProgramListVisible then
			mProgramList.Visible = true
			mProgramList.Size = UDim2.new(1, 0, 1, -offset)
		else
			mProgramList.Visible = false
		end
	end

	function this:SetSelectedCommand(commandId)
		setSelectedCommand(commandId)
		updateLayout()
	end

	function this:ClearProgramListSelection()
		setProgramListSelection(nil)
	end

		-- Set the selected unit
	function this:SetSelectedUnit(unit)
		setProgramInfoPane(unit)
		updateLayout()
	end
	function this:SetSelectedUnitDefinition(unitId)
		setProgramInfoPaneDef(unitId)
		updateLayout()
	end
	function this:ClearSelectedUnit()
		mProgramInfoVisible = false
		updateLayout()
	end

	function this:SetSelectedUpload()
		setProgramInfoPane('upload')
		updateLayout()
	end
	function this:SetSelectedPickup(pickup)
		setProgramInfoPane(pickup)
		updateLayout()
	end

	function this:Hide()
		mGui.Visible = false
	end


	this.UnitSelected:connect(function(unitId)
		setProgramInfoPaneDef(unitId)
		updateLayout()
	end)

	function this:SetProgramListVisible(state)
		mProgramListVisible = state
		updateLayout()
	end
	function this:Destroy()
		mTutorialArrow:Destroy()
		mGui:Destroy()
		for _, gui in pairs(mActionListEntryCache) do
			gui:Destroy()
		end
	end

	updateLayout()
	mGui.Parent = container

	return this
end

return UnitInfoViewMobile
