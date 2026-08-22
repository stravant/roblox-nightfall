-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local JourneyViewerView = require(game.ReplicatedStorage.JourneyViewerView)
	local ModalManager = require(game.ReplicatedStorage.ModalManager)

	local function withViewer(provider, fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		ReactRoblox.act(function()
			view = JourneyViewerView.new(screen, provider)
		end)
		task.wait() -- let the provider fetch task run
		ReactRoblox.act(function() end)
		local ok, err = pcall(fn, view, screen:FindFirstChild("JourneyMouseCatcher"))
		ReactRoblox.act(function()
			view:Destroy()
		end)
		ModalManager:SetModal(false)
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	t.test("lists sessions from the provider", function()
		withViewer({
			List = function()
				return {
					{ Key = "j_1", Name = "Alice", Start = 1786000000, EventCount = 12, Duration = 95 },
					{ Key = "j_2", Name = "Bob", Start = 1786001000, EventCount = 3, Duration = 20 },
				}
			end,
			Get = function()
				return nil
			end,
		}, function(view, gui)
			t.expect(gui.JourneyWindow.WindowTitle.Text).toBe("Player Journeys")
			t.expect(gui.JourneyWindow.StatusText.Text).toBe("2 recent sessions. Click one for its timeline.")
			local scroll = gui.JourneyWindow:FindFirstChild("JourneyScroll", true)
			-- Tabular rows: header + one cell per column. (":FindFirstChild
			-- rather than dot access: a child literally named "Name" is
			-- shadowed by the Instance.Name property)
			t.expect(scroll.Header:FindFirstChild("Name").Text).toBe("Name")
			t.expect(scroll.Row1:FindFirstChild("Name").Text).toBe("Alice")
			t.expect(scroll.Row1.Events.Text).toBe("12")
			t.expect(scroll.Row2:FindFirstChild("Name").Text).toBe("Bob")
			-- No Ended/LastUpdate fields: classified as old
			t.expect(scroll.Row1.Status.Text).toBe("old")
			-- Timeline chrome hidden in list mode
			t.expect(gui.JourneyWindow.BackButton.Visible).toBeFalsy()
		end)
	end)

	t.test("a nil provider result shows the failure status", function()
		withViewer({
			List = function()
				return nil
			end,
			Get = function()
				return nil
			end,
		}, function(view, gui)
			t.expect(gui.JourneyWindow.StatusText.Text).toBe("Failed to load sessions (viewer is owner-only).")
		end)
	end)

	t.test("opening and closing manages the modal state", function()
		withViewer({
			List = function()
				return {}
			end,
			Get = function()
				return nil
			end,
		}, function(view, gui)
			t.expect(ModalManager:IsModal()).toBeTruthy()
			t.expect(gui.JourneyWindow.StatusText.Text).toBe("No recorded sessions yet.")
		end)
		t.expect(ModalManager:IsModal()).toBeFalsy()
	end)

	t.test("pan details get annotated with the nearest netmap node", function()
		-- Stub the place's netmap model (absent in the test place) for the
		-- position lookup
		local netmapFolder = Instance.new("Folder")
		netmapFolder.Name = "Netmap"
		local function node(id, x, z)
			local part = Instance.new("Part")
			part.Name = id
			part.Anchored = true
			part.CFrame = CFrame.new(x, 0, z)
			part.Parent = netmapFolder
		end
		node("lm12", 80, -40)
		node("ph16", 300, 200)
		netmapFolder.Parent = workspace

		local ok, err = pcall(function()
			t.expect(JourneyViewerView.AnnotatePanDetail("120 studs to 75,-38"))
				.toBe("120 studs to 75,-38 (near lm12)")
			t.expect(JourneyViewerView.AnnotatePanDetail("40 studs to 280,190"))
				.toBe("40 studs to 280,190 (near ph16)")
			-- Unparseable details pass through untouched
			t.expect(JourneyViewerView.AnnotatePanDetail("garbage")).toBe("garbage")
		end)
		netmapFolder:Destroy()
		if not ok then
			error(err, 0)
		end
	end)
end
