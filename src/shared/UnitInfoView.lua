local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)

local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)

local UnitInfoView = {}

function UnitInfoView.new(container, availablePrograms)
	local this = {}

	this.UnitSelected = Signal.new()
	this.CommandSelected = Signal.new()

	local mProgramInfo = script.ProgramInfo:Clone()
	local mProgramList = script.ProgramList:Clone()

	local mTutorialArrow = TutorialArrowView.new()

	-- For tutorial, restrict unit selection to a given unit in the program list
	local mOnlySelectUnit = nil

	-- Set up the available programs
	local mAvailablePrograms = {}
	local mProgramCount = 0
	local function addProgram(id, initialCount)
		mProgramCount = mProgramCount + 1
		local newInfo = {
			Id = id;
			Count = initialCount;
			Gui = script.ProgramListEntry:Clone();
		}
		mAvailablePrograms[newInfo.Id] = newInfo
		newInfo.Gui.Parent = mProgramList.List
		newInfo.Gui.Text = " "..initialCount.."x "..Scripts[id].Name
		newInfo.Gui.MouseButton1Click:connect(function()
			if not mOnlySelectUnit or mOnlySelectUnit == id then
				this.UnitSelected:fire(newInfo.Id)
			end
		end)
		mProgramList.List.CanvasSize = UDim2.new(0, 0, 0, 33*mProgramCount)
		return newInfo
	end
	for i, info in pairs(availablePrograms) do
		addProgram(info.Id, info.Count)
	end

	-- Update the count of a program
	function this:UpdateCount(unitId, delta)
		local data = mAvailablePrograms[unitId]
		if data then
			data.Count = data.Count + delta
			data.Gui.Text = " "..data.Count.."x "..Scripts[unitId].Name
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

	-- The entries in our command list
	local mCommandListEntries = {}

	function this:TutorialHighlightCommand(commandId)
		mTutorialArrow:Show(mCommandListEntries[commandId], 180, UDim2.new(0.5, 0, 0, 0))
	end

	function this:TutorialHide()
		mTutorialArrow:Hide()
	end

	local function sectorStr(sectors)
		if sectors == 0 then
			return "zero sectors"
		elseif sectors == 1 then
			return "a sector"
		else
			return sectors.." sectors"
		end
	end

	local function setProgramInfoPane(unit)
		mProgramInfo.Visible = true

		mTutorialArrow:Hide()
		for commandId, gui in pairs(mCommandListEntries) do
			gui:Destroy()
			mCommandListEntries[commandId] = nil
		end

		-- Special cases for info on other things on the board
		if unit == 'upload' then
			mProgramInfo.UnitImage.Image = 'rbxassetid://1333805802'
			mProgramInfo.UnitImage.BackgroundColor3 = Color3.new(0, 0, 0)
			mProgramInfo.UnitMove.Text = ""
			mProgramInfo.UnitMaxSize.Text = ""
			mProgramInfo.UnitName.Text = "Upload Zone"
			mProgramInfo.UnitFlavorText.Text = "Upload your units here to do battle!"
			return
		elseif unit == 'credits' then
			mProgramInfo.UnitImage.Image = 'rbxassetid://1346715274'
			mProgramInfo.UnitImage.BackgroundColor3 = Color3.new(0, 0, 0)
			mProgramInfo.UnitMove.Text = ""
			mProgramInfo.UnitMaxSize.Text = ""
			mProgramInfo.UnitName.Text = "Credits"
			mProgramInfo.UnitFlavorText.Text = "Extra credits... see if you can grab them on your way to victory."
			return
		elseif unit == 'codes' then
			mProgramInfo.UnitImage.Image = 'rbxassetid://1346714452'
			mProgramInfo.UnitImage.BackgroundColor3 = Color3.new(0, 0, 0)
			mProgramInfo.UnitMove.Text = ""
			mProgramInfo.UnitMaxSize.Text = ""
			mProgramInfo.UnitName.Text = "Decryption Codes"
			mProgramInfo.UnitFlavorText.Text = "Your objective is to grab these, no need to terminate all the enemy scripts."
			return
		end

		-- Set the info
		mProgramInfo.UnitImage.Image = unit.Definition.Image
		mProgramInfo.UnitImage.BackgroundColor3 = unit.Definition.Color
		mProgramInfo.UnitFlavorText.Text = unit.Definition.Desc
		mProgramInfo.UnitMove.Text = "Move: "..unit.Move..((unit.Move == 10) and " (max)" or "")
		mProgramInfo.UnitMaxSize.Text = "Max Size: "..unit.MaxSize
		mProgramInfo.UnitName.Text = unit.Definition.Name

		if not unit.Enemy and unit.MoveLeft > 0 then
			local moveCommand = script.CommandListEntry:Clone()
			moveCommand.CommandName.Text = "Move"
			moveCommand.CommandText1.Text = "Move the unit."
			moveCommand.CommandText2.Text = ""
			moveCommand.MouseButton1Down:connect(function()
				this.CommandSelected:fire(nil)
			end)
			moveCommand.Parent = mProgramInfo.CommandList
			mCommandListEntries.move = moveCommand
		end
		for _, command in pairs(unit.Definition.CommandList) do
			local gui = script.CommandListEntry:Clone()
			if command.SizeReq > 0 then
				gui.CommandName.Text = command.Name.." ("..command.SizeReq..")"
			else
				gui.CommandName.Text = command.Name
			end
			if #unit.Tail < command.SizeReq then
				gui.NotEnoughSize.Visible = true
			end
			local bodyText;
			if command.Type == 'one' then
				bodyText = "Add a tile to the grid"
			elseif command.Type == 'zero' then
				bodyText = "Remove a tile from the grid"
			elseif command.Type == 'damage' then
				bodyText = "Delete "..sectorStr(command.Amount).. " from the target"
			elseif command.Type == 'speedMod' then
				bodyText = "Modify target speed by "..command.Amount
			elseif command.Type == 'sizeMod' then
				bodyText = "Increase target max size by "..command.Amount
			elseif command.Type == 'grow' then
				bodyText = "Add "..command.Amount.." sectors to the target"
			end
			if command.Cost > 0 then
				bodyText = bodyText..", and delete ".. sectorStr(command.Cost).." from "..unit.Definition.Name
			end
			bodyText = bodyText.."."
			if command.SizeReq > 0 then
				bodyText = bodyText.." (requires "..command.SizeReq.." size)"
			end
			if command.Range > 1 then
				gui.CommandText1.Text = "Range: "..command.Range
				gui.CommandText2.Text = bodyText
			else
				gui.CommandText1.Text = bodyText
				gui.CommandText2.Text = ""
			end
			gui.Parent = mProgramInfo.CommandList
			gui.MouseButton1Click:connect(function()
				if #unit.Tail >= command.SizeReq then
					this.CommandSelected:fire(command.Id)
				end
			end)
			mCommandListEntries[command.Id] = gui
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

	function this:SetSelectedCommand(commandId)
		for _, gui in pairs(mCommandListEntries) do
			gui.SelectedOverlay.Visible = false
		end
		mCommandListEntries[commandId].SelectedOverlay.Visible = true
	end

	-- Set the selected unit
	function this:SetSelectedUnit(unit)
		setProgramInfoPane(unit)
	end
	function this:SetSelectedUnitDefinition(unitId)
		setProgramInfoPaneDef(unitId)
	end
	function this:ClearSelectedUnit()
		mProgramInfo.Visible = false
	end

	function this:SetSelectedUpload()
		setProgramInfoPane('upload')
	end
	function this:SetSelectedPickup(pickup)
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

	function this:SetProgramListVisible(state)
		mProgramList.Visible = state
	end
	function this:Destroy()
		mTutorialArrow:Destroy()
	end

	mProgramInfo.Parent = container
	mProgramList.Parent = container

	return this
end

return UnitInfoView
