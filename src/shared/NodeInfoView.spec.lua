-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- LocalPlayerData is not loaded in the test place, and NodeStatsCache would
-- hit the network, so withView stubs LocalPlayerData:CanAccessNode /
-- GetSecurityLevel and NodeStatsCache:Get for the duration of each test:
-- either with a synchronous mock stats object, or (by default) with a fetch
-- that never completes so the template placeholder stats stay visible.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local NodeInfoView = require(game.ReplicatedStorage.NodeInfoView)
	local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
	local NodeStatsCache = require(game.ReplicatedStorage.NodeStatsCache)

	-- lm12 = "Tech Support" / "Lucky Monkey Media", Level 1, has a Mission
	local kNodeId = "lm12"
	local kNodeMission = "SMART uses this node's security as a test mission. Defeat all hostile scripts."

	local function mockStats()
		return {
			GetLeastMoves = function()
				return "MoverGuy", 7
			end,
			GetAverageMoves = function()
				return 6.5
			end,
			GetLeastTurns = function()
				return "TurnsGuy", 4
			end,
			GetAverageTurns = function()
				return 3.5
			end,
			GetLeastUnits = function()
				return "UnitsGuy", 2
			end,
		}
	end

	-- options: { canAccess: boolean, securityLevel: number?, stats: table? }
	local function withView(options, fn)
		local originalCanAccess = LocalPlayerData.CanAccessNode
		local originalGetSecurityLevel = LocalPlayerData.GetSecurityLevel
		local originalGet = NodeStatsCache.Get
		LocalPlayerData.CanAccessNode = function()
			return options.canAccess
		end
		LocalPlayerData.GetSecurityLevel = function()
			return options.securityLevel or 0
		end
		NodeStatsCache.Get = function()
			if options.stats then
				return options.stats
			end
			-- Leave the fetch pending forever; the view's Destroy cancels
			-- the fetching thread.
			coroutine.yield()
			return nil
		end

		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		ReactRoblox.act(function()
			view = NodeInfoView.new(screen, kNodeId)
		end)
		local ok, err = pcall(fn, view, screen:FindFirstChild("MenuMouseCatcher"))
		ReactRoblox.act(function()
			view:Destroy()
		end)
		screen:Destroy()

		LocalPlayerData.CanAccessNode = originalCanAccess
		LocalPlayerData.GetSecurityLevel = originalGetSecurityLevel
		NodeStatsCache.Get = originalGet
		if not ok then
			error(err, 0)
		end
	end

	t.test("mounts the mouse catcher host with the template structure", function()
		withView({ canAccess = true }, function(view, gui)
			t.expect(gui).toBeTruthy()
			t.expect(gui.ClassName).toBe("ImageButton")
			t.expect(gui.Size).toBe(UDim2.new(1, 0, 1, 0))
			t.expect(gui.BackgroundTransparency).toBe(0.5)
			t.expect(gui.ZIndex).toBe(6)
			t.expect(gui.Visible).toBeTruthy()
			t.expect(gui.Menu.ClassName).toBe("ImageLabel")
			t.expect(gui.Menu.Size).toBe(UDim2.new(0, 300, 0, 260))
			t.expect(gui.Menu.ZIndex).toBe(3)
			t.expect(gui.Menu.WindowTitle.Text).toBe("Access Node")
		end)
	end)

	t.test("shows the Info and Stats tabs with Info selected", function()
		withView({ canAccess = true }, function(view, gui)
			local tabPanel = gui.Menu.TabPanel
			t.expect(tabPanel.TabStrip.Info.Text.Text).toBe("Information")
			t.expect(tabPanel.TabStrip.Stats.Text.Text).toBe("Statistics")
			t.expect(tabPanel.TabStrip.Info.ImageRectOffset).toBe(Vector2.new(22, 0))
			t.expect(tabPanel.TabStrip.Stats.ImageRectOffset).toBe(Vector2.new(44, 0))
			t.expect(tabPanel.Tabs.Info.Visible).toBeTruthy()
			t.expect(tabPanel.Tabs.Stats.Visible).toBeFalsy()
		end)
	end)

	t.test("info tab shows the node's data", function()
		withView({ canAccess = true }, function(view, gui)
			local infoTab = gui.Menu.TabPanel.Tabs.Info
			t.expect(infoTab.NameText.Text).toBe("Tech Support")
			t.expect(infoTab.ProprietorText.Text).toBe("Lucky Monkey Media")
			t.expect(infoTab.MissionText.Text).toBe(kNodeMission)
		end)
	end)

	t.test("accessible node shows the enter button and hides no-entry", function()
		withView({ canAccess = true }, function(view, gui)
			t.expect(gui.Menu.EnterButton.Visible).toBeTruthy()
			t.expect(gui.Menu.NoEntryButton.Visible).toBeFalsy()
			t.expect(gui.Menu.EnterButton.Text.Text).toBe("Enter Databattle!")
			t.expect(gui.Menu.CancelButton.Text.Text).toBe("Return to Netmap")
		end)
	end)

	t.test("inaccessible node with enough security shows No Connection", function()
		withView({ canAccess = false, securityLevel = 5 }, function(view, gui)
			t.expect(gui.Menu.EnterButton.Visible).toBeFalsy()
			t.expect(gui.Menu.NoEntryButton.Visible).toBeTruthy()
			t.expect(gui.Menu.NoEntryButton.Text.Text).toBe("No Connection\nAvailable")
		end)
	end)

	t.test("inaccessible node with low security shows Insufficient Security", function()
		withView({ canAccess = false, securityLevel = 0 }, function(view, gui)
			t.expect(gui.Menu.NoEntryButton.Visible).toBeTruthy()
			t.expect(gui.Menu.NoEntryButton.Text.Text).toBe("Insufficient\nSecurity Level")
		end)
	end)

	t.test("stats tab shows template placeholders while the fetch is pending", function()
		withView({ canAccess = true }, function(view, gui)
			local statsTab = gui.Menu.TabPanel.Tabs.Stats
			t.expect(statsTab.TurnsText.Text).toBe("6 turns")
			t.expect(statsTab.TurnsText.Player.Text).toBe("by Stravant")
			t.expect(statsTab.MovesText.Text).toBe("5 moves")
			t.expect(statsTab.UnitsText.Text).toBe("5 units")
			t.expect(statsTab.TurnsLabel.Label.Text).toBe("Least Turns Taken")
			t.expect(statsTab.MovesLabel.Label.Text).toBe("Least Unit Moves")
			t.expect(statsTab.UnitsLabel.Label.Text).toBe("Least Units Used")
		end)
	end)

	t.test("stats tab renders fetched stats, preserving the template's quirks", function()
		withView({ canAccess = true, stats = mockStats() }, function(view, gui)
			local statsTab = gui.Menu.TabPanel.Tabs.Stats
			-- Turns section is straightforward
			t.expect(statsTab.TurnsText.Text).toBe("4 turns")
			t.expect(statsTab.TurnsText.Average.Text).toBe("(average turns taken = 3.5)")
			t.expect(statsTab.TurnsText.Player.Text).toBe("by TurnsGuy")
			-- The units section overwrites the moves line (template quirk):
			-- moves count with a " units" suffix, credited to the units
			-- record holder
			t.expect(statsTab.MovesText.Text).toBe("7 units")
			t.expect(statsTab.MovesText.Average.Text).toBe("(average moves used = 6.5)")
			t.expect(statsTab.MovesText.Player.Text).toBe("by UnitsGuy")
			-- The units line itself never updates (template quirk)
			t.expect(statsTab.UnitsText.Text).toBe("5 units")
			t.expect(statsTab.UnitsText.Player.Text).toBe("by Stravant")
		end)
	end)

	t.test("Show and Hide toggle the host frame", function()
		withView({ canAccess = true }, function(view, gui)
			view:Hide()
			t.expect(gui.Visible).toBeFalsy()
			view:Show()
			t.expect(gui.Visible).toBeTruthy()
		end)
	end)

	t.test("Destroy removes the gui and cancels a pending stats fetch", function()
		local originalCanAccess = LocalPlayerData.CanAccessNode
		local originalGetSecurityLevel = LocalPlayerData.GetSecurityLevel
		local originalGet = NodeStatsCache.Get
		LocalPlayerData.CanAccessNode = function()
			return true
		end
		LocalPlayerData.GetSecurityLevel = function()
			return 0
		end
		NodeStatsCache.Get = function()
			coroutine.yield() -- pending forever; Destroy must cancel this
			return nil
		end

		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		ReactRoblox.act(function()
			view = NodeInfoView.new(screen, kNodeId)
		end)
		local gui = screen:FindFirstChild("MenuMouseCatcher")
		ReactRoblox.act(function()
			view:Destroy()
		end)
		local guiRemoved = gui.Parent == nil
		screen:Destroy()

		LocalPlayerData.CanAccessNode = originalCanAccess
		LocalPlayerData.GetSecurityLevel = originalGetSecurityLevel
		NodeStatsCache.Get = originalGet

		t.expect(guiRemoved).toBeTruthy()
	end)
end
