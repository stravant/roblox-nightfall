local SoundManager = require(game.ReplicatedStorage.SoundManager)
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)
local WindowsSlider = require(game.ReplicatedStorage.WindowsSlider)
local WindowsTabView = require(game.ReplicatedStorage.WindowsTabView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local BuyLevelSkipView = require(game.ReplicatedStorage.BuyLevelSkipView)
local NodeStatsCache = require(game.ReplicatedStorage.NodeStatsCache)
local Netmap = require(game.ReplicatedStorage.Netmap)

local NodeInfoView = {}

function NodeInfoView.new(container, nodeId)
	local this = {}

	local mGui = script.MenuMouseCatcher:Clone()
	mGui.Parent = container
	local mMenu = mGui.Menu
	local mInfoTab = mMenu.TabPanel.Tabs.Info
	local mStatsTab = mMenu.TabPanel.Tabs.Stats

	local mNodeData = Netmap.ById[nodeId]

	-- Wait for done
	local mWaitForDone = Instance.new('BindableEvent')

	-- Tabbing
	WindowsTabView.new(mMenu.TabPanel.TabStrip, mMenu.TabPanel.Tabs, mInfoTab)

	-- Cancel button
	WindowsButton.new(mMenu.CancelButton)
	mMenu.CancelButton.MouseButton1Click:connect(function()
		this:Hide()
	end)

	-- Enter button
	WindowsButton.new(mMenu.EnterButton)
	mMenu.EnterButton.MouseButton1Click:connect(function()
		mWaitForDone:Fire(true)
	end)

	-- Cancel button
	WindowsButton.new(mMenu.CancelButton)
	mMenu.CancelButton.MouseButton1Click:connect(function()
		mWaitForDone:Fire(false)
	end)

	do -- Set up enter / no entry button
		if LocalPlayerData:CanAccessNode(nodeId) then
			mMenu.NoEntryButton.Visible = false
			mMenu.EnterButton.Visible = true
		else
			mMenu.EnterButton.Visible = false
			mMenu.NoEntryButton.Visible = true
			if LocalPlayerData:GetSecurityLevel() >= mNodeData.Level then
				mMenu.NoEntryButton.Text.Text = "No Connection\nAvailable"
			else
				mMenu.NoEntryButton.Text.Text = "Insufficient\nSecurity Level"
			end
		end
	end

	do -- Set up info tab
		mInfoTab.NameText.Text = mNodeData.Name
		mInfoTab.ProprietorText.Text = mNodeData.Org
		mInfoTab.MissionText.Text = mNodeData.Mission
	end

	do -- Set up stats tab
		spawn(function()
			local stats = NodeStatsCache:Get(nodeId)

			-- Moves
			local name, moves = stats:GetLeastMoves()
			local avg = stats:GetAverageMoves()
			mStatsTab.MovesText.Text = moves.." moves"
			mStatsTab.MovesText.Average.Text = "(average moves used = "..avg..")"
			mStatsTab.MovesText.Player = "by "..name

			-- Turns
			local name, turns = stats:GetLeastTurns()
			local avg = stats:GetAverageTurns()
			mStatsTab.TurnsText.Text = turns.." turns"
			mStatsTab.TurnsText.Average.Text = "(average turns taken = "..avg..")"
			mStatsTab.TurnsText.Player = "by "..name

			-- Units
			local name, units = stats:GetLeastUnits()
			mStatsTab.MovesText.Text = moves.." units"
			mStatsTab.MovesText.Player = "by "..name
		end)
	end

	-- Show / hide the menu
	function this:Show()
		mGui.Visible = true
	end
	function this:Hide()
		mGui.Visible = false
	end
	function this:Destroy()
		mGui:Destroy()
	end

	return this
end

return NodeInfoView
