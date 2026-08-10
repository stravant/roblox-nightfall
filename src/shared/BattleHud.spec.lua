-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local BattleHud = require(game.ReplicatedStorage.BattleHud)
	local Scripts = require(game.ReplicatedStorage.Scripts)

	local kPrograms = {
		{ Id = "hack", Count = 2 },
		{ Id = "slingshot", Count = 0 },
	}

	local function withHud(fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local hud
		local ok, err = pcall(function()
			ReactRoblox.act(function()
				hud = BattleHud.new(screen, kPrograms)
			end)
			fn(hud, screen:FindFirstChild("BattleHud"))
		end)
		if hud then
			ReactRoblox.act(function()
				hud:Destroy()
			end)
		end
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	t.test("mounts with the programs window and an empty command row", function()
		withHud(function(hud, gui)
			local column = gui.LeftColumn
			-- Rows live inside the window's scrolling list
			local hack = column.ProgramsWindow:FindFirstChild("hack", true)
			local slingshot = column.ProgramsWindow:FindFirstChild("slingshot", true)
			t.expect(hack.CountLabel.Text).toBe("2x")
			t.expect(hack.NameLabel.Text).toBe(Scripts.hack.Name)
			t.expect(slingshot.CountLabel.Text).toBe("0x")
			t.expect(column:FindFirstChild("InfoWindow")).toBe(nil)
			-- Command row exists but holds only its layout
			t.expect(#column.CommandRow:GetChildren()).toBe(1)
		end)
	end)

	t.test("selecting a unit definition fills the info window and command row", function()
		withHud(function(hud, gui)
			ReactRoblox.act(function()
				hud:SetSelectedUnitDefinition("hack")
			end)
			local column = gui.LeftColumn
			t.expect(column.InfoWindow.WindowTitle.Text).toBe(Scripts.hack.Name)
			t.expect(column.InfoWindow.Inset.FlavorText.Text).toBe(Scripts.hack.Desc)
			-- Dummy definition has no moves left: no move button
			t.expect(column.CommandRow:FindFirstChild("move")).toBe(nil)
			for _, command in pairs(Scripts.hack.CommandList) do
				t.expect(column.CommandRow:FindFirstChild(command.Id) ~= nil).toBeTruthy()
			end
		end)
	end)

	t.test("a movable unit gets a move button and command selection highlights", function()
		withHud(function(hud, gui)
			local unit = {
				Enemy = false,
				MoveLeft = 2,
				Move = 3,
				MaxSize = 4,
				Tail = { 1 },
				Definition = Scripts.hack,
			}
			ReactRoblox.act(function()
				hud:SetSelectedUnit(unit)
			end)
			local column = gui.LeftColumn
			t.expect(column.CommandRow:FindFirstChild("move") ~= nil).toBeTruthy()
			local commandId = Scripts.hack.CommandList[1].Id
			ReactRoblox.act(function()
				hud:SetSelectedCommand(commandId)
			end)
			t.expect(column.CommandRow[commandId].ImageColor3).toBe(Color3.new(0, 0, 1))
			-- Move selection maps nil -> the move button
			ReactRoblox.act(function()
				hud:SetSelectedCommand(nil)
			end)
			t.expect(column.CommandRow.move.ImageColor3).toBe(Color3.new(0, 0, 1))
		end)
	end)

	t.test("UpdateCount rewrites the row and GetCount tracks it", function()
		withHud(function(hud, gui)
			ReactRoblox.act(function()
				hud:UpdateCount("hack", -1)
			end)
			t.expect(gui.LeftColumn.ProgramsWindow:FindFirstChild("hack", true).CountLabel.Text).toBe("1x")
			t.expect(hud:GetCount("hack")).toBe(1)
		end)
	end)

	t.test("program window visibility and Hide", function()
		withHud(function(hud, gui)
			ReactRoblox.act(function()
				hud:SetProgramListVisible(false)
			end)
			t.expect(gui:FindFirstChild("ProgramsWindow", true)).toBe(nil)
			ReactRoblox.act(function()
				hud:Hide()
			end)
			t.expect(gui:FindFirstChild("CommandRow", true)).toBe(nil)
		end)
	end)
end
