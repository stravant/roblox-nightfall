-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- Note: LocalPlayerData is not loaded from the server in the test place, so
-- GetSkips() returns nil and the view keeps its template placeholder skip
-- counts unless the spec stubs GetSkips. The BuyButton is never clicked here
-- (it would open a BuyLevelSkipView with purchase prompts).
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local MainMenuView = require(game.ReplicatedStorage.MainMenuView)
	local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
	local ModalManager = require(game.ReplicatedStorage.ModalManager)
	local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)

	local function withView(fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		ReactRoblox.act(function()
			view = MainMenuView.new(screen)
		end)
		local ok, err = pcall(fn, view, screen:FindFirstChild("MenuMouseCatcher"))
		ReactRoblox.act(function()
			view:Destroy()
		end)
		ModalManager:SetModal(false) -- don't leak modal state between tests
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	t.test("mounts the mouse catcher host into the container, hidden", function()
		withView(function(view, gui)
			t.expect(gui).toBeTruthy()
			t.expect(gui.ClassName).toBe("ImageButton")
			t.expect(gui.Size).toBe(UDim2.new(1, 0, 1, 0))
			t.expect(gui.BackgroundTransparency).toBe(0.5)
			t.expect(gui.ZIndex).toBe(6)
			t.expect(gui.Visible).toBeFalsy()
		end)
	end)

	t.test("mounts the menu window with the template structure", function()
		withView(function(view, gui)
			t.expect(gui.Menu.ClassName).toBe("ImageLabel")
			t.expect(gui.Menu.Size).toBe(UDim2.new(0, 400, 0, 250))
			t.expect(gui.Menu.WindowTitle.Text).toBe("Game Menu")
			t.expect(gui.Menu.CloseButton.Text.Text).toBe("Close")
			-- Scale is a float32 property, so compare with a tolerance
			local expectedScale = if DeviceInfo.ScreenHeight > 400 then 1.2 else 1
			t.expect(math.abs(gui.Menu.UIScale.Scale - expectedScale) < 1e-6).toBeTruthy()
		end)
	end)

	t.test("shows the four tabs with the Sound tab selected", function()
		withView(function(view, gui)
			local tabPanel = gui.Menu.TabPanel
			t.expect(tabPanel.TabStrip.Sound.Text.Text).toBe("Sound")
			t.expect(tabPanel.TabStrip.Skips.Text.Text).toBe("Level Skips")
			t.expect(tabPanel.TabStrip.Stats.Text.Text).toBe("Statistics")
			t.expect(tabPanel.TabStrip.Badges.Text.Text).toBe("Badges")
			-- Selected tab uses the raised image rect and sits on top
			t.expect(tabPanel.TabStrip.Sound.ImageRectOffset).toBe(Vector2.new(22, 0))
			t.expect(tabPanel.TabStrip.Sound.ZIndex).toBe(2)
			t.expect(tabPanel.TabStrip.Skips.ImageRectOffset).toBe(Vector2.new(44, 0))
			t.expect(tabPanel.Tabs.Sound.Visible).toBeTruthy()
			t.expect(tabPanel.Tabs.Skips.Visible).toBeFalsy()
			t.expect(tabPanel.Tabs.Stats.Visible).toBeFalsy()
			t.expect(tabPanel.Tabs.Badges.Visible).toBeFalsy()
		end)
	end)

	t.test("sound tab has both sliders centered by SoundManager (volume 1 -> value 0)", function()
		withView(function(view, gui)
			local soundTab = gui.Menu.TabPanel.Tabs.Sound
			t.expect(soundTab.SoundVolumeLabel.Text).toBe("Sound Effect  Volume")
			t.expect(soundTab.MusicVolumeLabel.Text).toBe("Music Volume")
			t.expect(soundTab.SoundVolume.SliderArea.Slider.Position).toBe(UDim2.new(0.5, 0, 0.5, 0))
			t.expect(soundTab.MusicVolume.SliderArea.Slider.Position).toBe(UDim2.new(0.5, 0, 0.5, 0))
			t.expect(soundTab.SoundVolume.SliderArea.RightLabel.Text).toBe("RIP Eardrums")
			t.expect(soundTab.MusicVolume.SliderArea.RightLabel.Text).toBe("DAT BASS")
		end)
	end)

	t.test("skips tab shows template placeholders when player data is not loaded", function()
		withView(function(view, gui)
			local skipsTab = gui.Menu.TabPanel.Tabs.Skips
			t.expect(skipsTab.SkipsAvailable.Text).toBe("5 skips")
			t.expect(skipsTab.SkipsUsed.Text).toBe("5 skips")
			t.expect(skipsTab.BuyButton.Text.Text).toBe("BUY MORE LEVEL SKIPS")
			t.expect(skipsTab.BuyButton.ImageColor3).toBe(Color3.new(0, 0, 1))
		end)
	end)

	t.test("skips tab shows GetSkips counts when available at construction", function()
		local originalGetSkips = LocalPlayerData.GetSkips
		LocalPlayerData.GetSkips = function()
			return 3, 2
		end
		local ok, err = pcall(withView, function(view, gui)
			local skipsTab = gui.Menu.TabPanel.Tabs.Skips
			t.expect(skipsTab.SkipsAvailable.Text).toBe("3 skips")
			t.expect(skipsTab.SkipsUsed.Text).toBe("2 skips")
		end)
		LocalPlayerData.GetSkips = originalGetSkips
		if not ok then
			error(err, 0)
		end
	end)

	t.test("skips text updates when SkipsChanged fires", function()
		local originalGetSkips = LocalPlayerData.GetSkips
		local ok, err = pcall(withView, function(view, gui)
			LocalPlayerData.GetSkips = function()
				return 7, 1
			end
			LocalPlayerData.SkipsChanged:fire()
			task.wait() -- let the signal's BindableEvent deliver
			ReactRoblox.act(function() end)
			local skipsTab = gui.Menu.TabPanel.Tabs.Skips
			t.expect(skipsTab.SkipsAvailable.Text).toBe("7 skips")
			t.expect(skipsTab.SkipsUsed.Text).toBe("1 skips")
		end)
		LocalPlayerData.GetSkips = originalGetSkips
		if not ok then
			error(err, 0)
		end
	end)

	t.test("stats tab holds the summary and the bests list", function()
		withView(function(view, gui)
			local statsTab = gui.Menu.TabPanel.Tabs.Stats
			t.expect(statsTab:FindFirstChild("SummaryLabel")).toBeTruthy()
			t.expect(statsTab:FindFirstChild("StatsScroll", true).ClassName).toBe("ScrollingFrame")
		end)
	end)

	t.test("badges tab holds the summary and the earned-badges list", function()
		withView(function(view, gui)
			local badgesTab = gui.Menu.TabPanel.Tabs.Badges
			t.expect(badgesTab:FindFirstChild("SummaryLabel")).toBeTruthy()
			t.expect(badgesTab:FindFirstChild("BadgesScroll", true).ClassName).toBe("ScrollingFrame")
			-- No fetch has completed in the test place: the placeholder shows
			t.expect(badgesTab:FindFirstChild("Placeholder", true).Text).toBe("Fetching badges...")
		end)
	end)

	t.test("a battle context adds a default-selected Databattle tab", function()
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		local ok, err = pcall(function()
			ReactRoblox.act(function()
				view = MainMenuView.new(screen)
			end)
			local gui = screen:FindFirstChild("MenuMouseCatcher")
			-- No context: no Databattle tab
			t.expect(gui.Menu.TabPanel.Tabs:FindFirstChild("Databattle")).toBe(nil)

			local forfeited = false
			ReactRoblox.act(function()
				view:SetBattleContext({
					skipText = "Skip Node (3 skips available)",
					disabled = false,
					onForfeit = function()
						forfeited = true
					end,
					onSkip = function() end,
				})
			end)
			ReactRoblox.act(function()
				view:Show()
			end)
			t.expect(gui.Menu.WindowTitle.Text).toBe("Databattle Menu")
			local tabs = gui.Menu.TabPanel.Tabs
			t.expect(tabs:FindFirstChild("Databattle") ~= nil).toBeTruthy()
			-- Default selected on open
			t.expect(tabs.Databattle.Visible).toBeTruthy()
			t.expect(tabs.Sound.Visible).toBeFalsy()
			t.expect(tabs.Databattle.SkipButton.Text.Text).toBe("Skip Node (3 skips available)")
			t.expect(tabs.Databattle.ForfeitButton.Text.Text).toBe("Forfeit")

			-- Clearing the context removes the tab and reverts the title
			ReactRoblox.act(function()
				view:SetBattleContext(nil)
				view:Hide()
			end)
			ReactRoblox.act(function()
				view:Show()
			end)
			t.expect(gui.Menu.WindowTitle.Text).toBe("Game Menu")
			t.expect(gui.Menu.TabPanel.Tabs:FindFirstChild("Databattle")).toBe(nil)
			t.expect(gui.Menu.TabPanel.Tabs.Sound.Visible).toBeTruthy()
		end)
		if view then
			ReactRoblox.act(function()
				view:Destroy()
			end)
		end
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end)

	t.test("Show and Hide toggle the host and the modal state", function()
		withView(function(view, gui)
			view:Show()
			t.expect(gui.Visible).toBeTruthy()
			t.expect(ModalManager:IsModal()).toBeTruthy()
			view:Hide()
			t.expect(gui.Visible).toBeFalsy()
			t.expect(ModalManager:IsModal()).toBeFalsy()
		end)
	end)

	t.test("Destroy removes the gui and disconnects the skips listener", function()
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		ReactRoblox.act(function()
			view = MainMenuView.new(screen)
		end)
		local gui = screen:FindFirstChild("MenuMouseCatcher")
		ReactRoblox.act(function()
			view:Destroy()
		end)
		t.expect(gui.Parent).toBe(nil)
		-- Firing SkipsChanged after Destroy must not reach the dead view
		LocalPlayerData.SkipsChanged:fire()
		task.wait()
		screen:Destroy()
	end)
end
