-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- WarezView constructs a UnitInfoViewMobile side tray (still template-based,
-- so it can't run in the runtests place) and reads LocalPlayerData — both are
-- stubbed here and restored in cleanup. Purchase clicks are never simulated
-- (they would FireServer / touch player data).
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local WarezView = require(game.ReplicatedStorage.WarezView)
	local UnitInfoViewMobile = require(game.ReplicatedStorage.UnitInfoViewMobile)
	local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
	local Signal = require(game.ReplicatedStorage.Signal)

	local kWarez = { hack = 100, slingshot = 500 }

	local function withView(credits, fn)
		local originalNew = UnitInfoViewMobile.new
		local originalGetProgramList = LocalPlayerData.GetProgramList
		local originalGetCredits = LocalPlayerData.GetCredits

		local tray = {
			UnitSelected = Signal.new(),
			SelectedDefinitions = {},
			ClearCalls = 0,
		}
		function tray:SetSelectedUnitDefinition(id)
			table.insert(self.SelectedDefinitions, id)
		end
		function tray:ClearProgramListSelection()
			self.ClearCalls += 1
		end
		function tray:UpdateCount() end

		UnitInfoViewMobile.new = function()
			return tray
		end
		LocalPlayerData.GetProgramList = function()
			return {}
		end
		LocalPlayerData.GetCredits = function()
			return credits
		end

		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		local ok, err = pcall(function()
			ReactRoblox.act(function()
				view = WarezView.new("wz1", kWarez)
			end)
			view:GetGui().Parent = screen
			fn(view, view:GetGui(), tray)
		end)

		UnitInfoViewMobile.new = originalNew
		LocalPlayerData.GetProgramList = originalGetProgramList
		LocalPlayerData.GetCredits = originalGetCredits
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	t.test("mounts the window chrome and one row per program", function()
		withView(10000, function(view, gui)
			t.expect(gui.MainBox.WindowTitle.Text).toBe("Warez Node Level 1")
			t.expect(gui.MainBox.DoneButton.Text.Text).toBe("Done Shopping")
			local content = gui.MainBox.ProgramList.ContentClip.Content
			t.expect(content.hack.NameLabel.Text).toBe("Hack")
			t.expect(content.hack.CostLabel.Text).toBe("100")
			t.expect(content.slingshot.NameLabel.Text).toBe("Slingshot")
			t.expect(content.slingshot.CostLabel.Text).toBe("500")
			t.expect(gui.MainBox.ProgramList.ScrollGutter.ScrollbarContainer.Scrollbar.ClassName).toBe("ImageButton")
		end)
	end)

	t.test("construction selects a program and notifies the side tray", function()
		withView(10000, function(view, gui, tray)
			t.expect(#tray.SelectedDefinitions).toBe(1)
			t.expect(tray.ClearCalls).toBe(1)
			-- Affordable -> purchase visible, no warning
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeTruthy()
			t.expect(gui.MainBox.InsufficientCreditsText.Visible).toBeFalsy()
		end)
	end)

	t.test("selecting a program highlights only its row", function()
		withView(10000, function(view, gui)
			ReactRoblox.act(function()
				view:SelectProgram("hack")
			end)
			local content = gui.MainBox.ProgramList.ContentClip.Content
			t.expect(content.hack.BackgroundColor3).toBe(Color3.new(0, 0, 0.5))
			t.expect(content.hack.NameLabel.TextColor3).toBe(Color3.new(1, 1, 1))
			t.expect(content.slingshot.BackgroundColor3).toBe(Color3.new(1, 1, 1))
			t.expect(content.slingshot.NameLabel.TextColor3).toBe(Color3.new(0, 0, 0))
		end)
	end)

	t.test("unaffordable selection shows the insufficient credits warning", function()
		withView(200, function(view, gui)
			ReactRoblox.act(function()
				view:SelectProgram("slingshot")
			end)
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeFalsy()
			t.expect(gui.MainBox.InsufficientCreditsText.Visible).toBeTruthy()
			ReactRoblox.act(function()
				view:SelectProgram("hack")
			end)
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeTruthy()
			t.expect(gui.MainBox.InsufficientCreditsText.Visible).toBeFalsy()
		end)
	end)

	t.test("clearing the selection hides purchase UI and unhighlights rows", function()
		withView(10000, function(view, gui)
			ReactRoblox.act(function()
				view:SelectProgram("hack")
			end)
			ReactRoblox.act(function()
				view:SelectProgram(nil)
			end)
			local content = gui.MainBox.ProgramList.ContentClip.Content
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeFalsy()
			t.expect(gui.MainBox.InsufficientCreditsText.Visible).toBeFalsy()
			t.expect(content.hack.BackgroundColor3).toBe(Color3.new(1, 1, 1))
		end)
	end)

	t.test("side tray unit selection clears the program selection", function()
		withView(10000, function(view, gui, tray)
			ReactRoblox.act(function()
				view:SelectProgram("hack")
			end)
			tray.UnitSelected:fire()
			task.wait() -- signal delivery is BindableEvent-based (async)
			ReactRoblox.act(function() end)
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeFalsy()
			local content = gui.MainBox.ProgramList.ContentClip.Content
			t.expect(content.hack.BackgroundColor3).toBe(Color3.new(1, 1, 1))
		end)
	end)
end
