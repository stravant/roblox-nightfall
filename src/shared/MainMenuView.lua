local SoundManager = require(game.ReplicatedStorage.SoundManager)
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)
local WindowsSlider = require(game.ReplicatedStorage.WindowsSlider)
local WindowsTabView = require(game.ReplicatedStorage.WindowsTabView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local BuyLevelSkipView = require(game.ReplicatedStorage.BuyLevelSkipView)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)

local MainMenuView = {}

function MainMenuView.new(container)
	local this = {}

	local mGui = script.MenuMouseCatcher:Clone()
	mGui.Parent = container
	local mMenu = mGui.Menu
	local mSoundTab = mMenu.TabPanel.Tabs.Sound
	local mSkipsTab = mMenu.TabPanel.Tabs.Skips
	local mStatsTab = mMenu.TabPanel.Tabs.Stats

	if DeviceInfo.ScreenHeight > 400 then
		mMenu.UIScale.Scale = 1.2
	end

	-- Tabbing
	WindowsTabView.new(mMenu.TabPanel.TabStrip, mMenu.TabPanel.Tabs, mSoundTab)

	-- Done button to close dialogue
	WindowsButton.new(mMenu.DoneButton)
	mMenu.DoneButton.MouseButton1Click:connect(function()
		this:Hide()
	end)

	-- Sound stuff
	local mMusicSlider = WindowsSlider.new(mSoundTab.MusicVolume)
	local mSoundSlider = WindowsSlider.new(mSoundTab.SoundVolume)
	SoundManager:AddSoundSlider(mSoundSlider)
	SoundManager:AddMusicSlider(mMusicSlider)

	-- Skips stuff
	WindowsButton.new(mSkipsTab.BuyButton)
	local function updateSkipsText()
		local available, used = LocalPlayerData:GetSkips()
		if available then
			mSkipsTab.SkipsAvailable.Text = available.." skips"
			mSkipsTab.SkipsUsed.Text = used.." skips"
		end
	end
	updateSkipsText()
	local mSkipsUpdateCn = LocalPlayerData.SkipsChanged:connect(updateSkipsText)
	mSkipsTab.BuyButton.MouseButton1Click:connect(function()
		BuyLevelSkipView.new(container)
	end)

	-- Stats
	-- TODO: implement stats


	-- Show / hide the menu
	function this:Show()
		ModalManager:SetModal(true)
		mGui.Visible = true
	end
	function this:Hide()
		mGui.Visible = false
		ModalManager:SetModal(false)
	end

	function this:Destroy()
		mSkipsUpdateCn:disconnect()
		mSoundSlider:Destroy()
		mMusicSlider:Destroy()
		mGui:Destroy()
	end

	return this
end

return MainMenuView
