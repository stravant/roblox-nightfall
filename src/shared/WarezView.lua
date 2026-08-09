local UnitInfoView = require(game.ReplicatedStorage.UnitInfoView)
local UnitInfoViewMobile = require(game.ReplicatedStorage.UnitInfoViewMobile)
local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)
local ScrollingFrame = require(game.ReplicatedStorage.ScrollingFrame)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)

local WarezView = {}

local GreyColor = Color3.new(0.75, 0.75, 0.75)
local BlueColor = Color3.new(0, 0, 0.5)
local TextBlack = Color3.new(0, 0, 0)
local TextWhite = Color3.new(1, 1, 1)

function WarezView.new(warezNodeId, warez)
	local this = {}
	
	this.MadePurchase = Signal.new()
	this.Done = Signal.new()	
	
	-- The GUI
	local mGui = script.Warez:Clone()
	function this:GetGui()
		return mGui
	end
	
	if DeviceInfo.ScreenHeight > 500 then
		local scale = Instance.new("UIScale")
		scale.Scale = 1.5
		scale.Parent = mGui.MainBox
	end
	
	-- Scroll
	local mScroller = ScrollingFrame.new(mGui.MainBox.ProgramList.ContentClip.Content)
	mScroller:AddScrollbar(mGui.MainBox.ProgramList.ScrollGutter.ScrollbarContainer.Scrollbar)
	mScroller:UpdateRender()

	-- The unit info view
	local mUnitInfoView = UnitInfoViewMobile.new(mGui, LocalPlayerData:GetProgramList())
	
	mUnitInfoView.UnitSelected:connect(function()
		this:SelectProgram(nil)
	end)
	
	local mProgramGuis = {}
	for id, cost in pairs(warez) do
		local row = script.ProgramEntry:Clone()
		local data = Scripts[id]
		if not data then
			print("Missing script:", id)
		end
		row.CostLabel.Text = tonumber(cost)
		row.NameLabel.Text = data.Name
		row.Icon.Image = data.Image
		row.Icon.BackgroundColor3 = data.Color
		row.Parent = mGui.MainBox.ProgramList.ContentClip.Content
		row.MouseButton1Click:connect(function()
			this:SelectProgram(id)
		end)
		mProgramGuis[id] = row
	end

	local mSelectedProgram = nil
	function this:SelectProgram(id)
		if mSelectedProgram then
			local gui = mProgramGuis[mSelectedProgram]
			gui.BackgroundColor3 = TextWhite
			gui.CostLabel.TextColor3 = TextBlack
			gui.NameLabel.TextColor3 = TextBlack
		end
		mSelectedProgram = id
		if id then
			mUnitInfoView:SetSelectedUnitDefinition(id)
			mUnitInfoView:ClearProgramListSelection()
			local gui = mProgramGuis[mSelectedProgram]
			gui.BackgroundColor3 = BlueColor
			gui.CostLabel.TextColor3 = TextWhite
			gui.NameLabel.TextColor3 = TextWhite
			local canAfford = LocalPlayerData:GetCredits() >= warez[id]
			if canAfford then
				mGui.MainBox.InsufficientCreditsText.Visible = false
				mGui.MainBox.PurchaseButton.Visible = true
			else
				mGui.MainBox.InsufficientCreditsText.Visible = true
				mGui.MainBox.PurchaseButton.Visible = false			
			end
		else
			mGui.MainBox.InsufficientCreditsText.Visible = false
			mGui.MainBox.PurchaseButton.Visible = false
		end
	end
	
	function this:PurchaseSelectedProgram()
		local cost = warez[mSelectedProgram]
		if LocalPlayerData:GetCredits() >= cost then
			LocalPlayerData:AddCredits(-cost)
			LocalPlayerData:AddUnit(mSelectedProgram)
			mUnitInfoView:UpdateCount(mSelectedProgram, 1)
			game.ReplicatedStorage.Remotes.PurchaseUnit:FireServer(warezNodeId, mSelectedProgram)
			this.MadePurchase:fire(mSelectedProgram)
		end
	end
	
	-- Set up buttons
	WindowsButton.new(mGui.MainBox.PurchaseButton)
	WindowsButton.new(mGui.MainBox.DoneButton)

	mGui.MainBox.PurchaseButton.MouseButton1Click:connect(function()
		SoundManager:Play('SelectUnit')
		this:PurchaseSelectedProgram()
	end)
	
	mGui.MainBox.DoneButton.MouseButton1Click:connect(function()
		SoundManager:Play('SelectUnit')
		this.Done:fire()
	end)
	
	this:SelectProgram(next(warez))
	
	return this	
end

return WarezView
