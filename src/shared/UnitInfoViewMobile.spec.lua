-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local UnitInfoViewMobile = require(game.ReplicatedStorage.UnitInfoViewMobile)
	local Scripts = require(game.ReplicatedStorage.Scripts)

	local kPrograms = {
		{ Id = "hack", Count = 2 },
		{ Id = "slingshot", Count = 1 },
	}

	local function withView(fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		local ok, err = pcall(function()
			ReactRoblox.act(function()
				view = UnitInfoViewMobile.new(screen, kPrograms)
			end)
			fn(view, screen:FindFirstChild("SideTray"))
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
	end

	local function content(gui)
		return gui.Content.ProgramList.ContentClip.Content
	end

	t.test("mounts the tray with one row per available program", function()
		withView(function(view, gui)
			t.expect(gui.ClassName).toBe("ImageLabel")
			local c = content(gui)
			t.expect(c.hack.NameLabel.Text).toBe(Scripts.hack.Name)
			t.expect(c.hack.CountLabel.Text).toBe("2")
			t.expect(c.slingshot.CountLabel.Text).toBe("1")
			t.expect(c.Size).toBe(UDim2.new(1, 0, 0, UnitInfoViewMobile.getProgramListHeight(2)))
			-- No info pane until a unit is selected
			t.expect(gui.Content:FindFirstChild("ProgramInfo")).toBe(nil)
		end)
	end)

	t.test("UpdateCount changes an existing row and GetCount reflects it", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:UpdateCount("hack", 1)
			end)
			t.expect(content(gui).hack.CountLabel.Text).toBe("3")
			t.expect(view:GetCount("hack")).toBe(3)
			ReactRoblox.act(function()
				view:UpdateCount("hack", -2)
			end)
			t.expect(content(gui).hack.CountLabel.Text).toBe("1")
		end)
	end)

	t.test("UpdateCount adds a new program row", function()
		-- Find a program id not already in the list
		local newId = nil
		for id, def in pairs(Scripts) do
			if not def.Enemy and id ~= "hack" and id ~= "slingshot" then
				newId = id
				break
			end
		end
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:UpdateCount(newId, 1)
			end)
			t.expect(content(gui):FindFirstChild(newId) ~= nil).toBeTruthy()
			t.expect(content(gui)[newId].CountLabel.Text).toBe("1")
			t.expect(content(gui).Size).toBe(UDim2.new(1, 0, 0, UnitInfoViewMobile.getProgramListHeight(3)))
		end)
	end)

	t.test("SetSelectedUnitDefinition shows the info pane with commands", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:SetSelectedUnitDefinition("hack")
			end)
			local info = gui.Content.ProgramInfo
			t.expect(info.NameLine.Label.Text).toBe(Scripts.hack.Name)
			t.expect(info.Icon.Image).toBe(Scripts.hack.Image)
			-- Dummy definition has MoveLeft = 0, so no move entry
			t.expect(info.ActionList:FindFirstChild("move")).toBe(nil)
			for _, command in pairs(Scripts.hack.CommandList) do
				t.expect(info.ActionList:FindFirstChild(command.Id) ~= nil).toBeTruthy()
			end
		end)
	end)

	t.test("SetSelectedUnit with moves left shows the move entry", function()
		withView(function(view, gui)
			local unit = {
				Enemy = false,
				MoveLeft = 2,
				Move = 3,
				MaxSize = 4,
				Tail = { 1 },
				Definition = Scripts.hack,
			}
			ReactRoblox.act(function()
				view:SetSelectedUnit(unit)
			end)
			local info = gui.Content.ProgramInfo
			t.expect(info.ActionList:FindFirstChild("move") ~= nil).toBeTruthy()
			t.expect(info.ActionList.move.BodyText.Text).toBe("Move the script.")
			t.expect(info.Icon.MoveLabel.Visible).toBeTruthy()
			t.expect(info.Icon.MoveLabel.Value.Text).toBe("3")
			t.expect(info.Icon.MaxSizeLabel.Value.Text).toBe("4")
		end)
	end)

	t.test("SetSelectedCommand highlights the entry", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:SetSelectedUnitDefinition("hack")
			end)
			local commandId = Scripts.hack.CommandList[1].Id
			ReactRoblox.act(function()
				view:SetSelectedCommand(commandId)
			end)
			local entry = gui.Content.ProgramInfo.ActionList[commandId]
			t.expect(entry.BackgroundColor3).toBe(Color3.new(0, 0, 0.5))
			t.expect(entry.BodyText.TextColor3).toBe(Color3.new(1, 1, 1))
			ReactRoblox.act(function()
				view:SetSelectedCommand(nil)
			end)
			t.expect(entry.BackgroundColor3).toBe(Color3.new(0.752941, 0.752941, 0.752941))
		end)
	end)

	t.test("SetSelectedUpload shows flavor text with hidden name line", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:SetSelectedUpload()
			end)
			local info = gui.Content.ProgramInfo
			t.expect(info.NameLine.Label.Text).toBe("Upload Zone")
			t.expect(info.ActionList.flavor.BodyText.Text).toBe("Upload your units here to do battle!")
			t.expect(info.ActionList.flavor.NameLine.Label.Visible).toBeFalsy()
		end)
	end)

	t.test("ClearSelectedUnit hides the info pane again", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:SetSelectedUnitDefinition("hack")
			end)
			ReactRoblox.act(function()
				view:ClearSelectedUnit()
			end)
			t.expect(gui.Content:FindFirstChild("ProgramInfo")).toBe(nil)
			t.expect(gui.Content.ProgramList.Size).toBe(UDim2.new(1, 0, 1, 0))
		end)
	end)

	t.test("SetProgramListVisible toggles the list", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:SetProgramListVisible(false)
			end)
			t.expect(gui.Content.ProgramList.Visible).toBeFalsy()
			ReactRoblox.act(function()
				view:SetProgramListVisible(true)
			end)
			t.expect(gui.Content.ProgramList.Visible).toBeTruthy()
		end)
	end)

	t.test("Hide hides the whole tray and Destroy removes it", function()
		withView(function(view, gui)
			view:Hide()
			t.expect(gui.Visible).toBeFalsy()
			ReactRoblox.act(function()
				view:Destroy()
			end)
			t.expect(gui.Parent).toBe(nil)
			ReactRoblox.act(function()
				view:Destroy() -- idempotent
			end)
		end)
	end)
end
