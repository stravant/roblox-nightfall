-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local UnitInfoView = require(game.ReplicatedStorage.UnitInfoView)
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
				view = UnitInfoView.new(screen, kPrograms)
			end)
			fn(view, screen:FindFirstChild("ProgramList"), screen:FindFirstChild("ProgramInfo"))
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

	t.test("mounts both panels with rows and canvas size", function()
		withView(function(view, list, info)
			t.expect(list.Title.Text).toBe("Programs")
			t.expect(info.Title.Text).toBe("Information")
			t.expect(list.List.hack.Text).toBe(" 2x " .. Scripts.hack.Name)
			t.expect(list.List.slingshot.Text).toBe(" 1x " .. Scripts.slingshot.Name)
			t.expect(list.List.CanvasSize).toBe(UDim2.new(0, 0, 0, 66))
		end)
	end)

	t.test("UpdateCount rewrites the row text and grows the canvas", function()
		withView(function(view, list)
			ReactRoblox.act(function()
				view:UpdateCount("hack", 1)
			end)
			t.expect(list.List.hack.Text).toBe(" 3x " .. Scripts.hack.Name)
			t.expect(view:GetCount("hack")).toBe(3)
			-- New program
			local newId = nil
			for id, def in pairs(Scripts) do
				if not def.Enemy and id ~= "hack" and id ~= "slingshot" then
					newId = id
					break
				end
			end
			ReactRoblox.act(function()
				view:UpdateCount(newId, 1)
			end)
			t.expect(list.List:FindFirstChild(newId) ~= nil).toBeTruthy()
			t.expect(list.List.CanvasSize).toBe(UDim2.new(0, 0, 0, 99))
		end)
	end)

	t.test("SetSelectedUnitDefinition fills the info pane", function()
		withView(function(view, list, info)
			ReactRoblox.act(function()
				view:SetSelectedUnitDefinition("hack")
			end)
			t.expect(info.UnitName.Text).toBe(Scripts.hack.Name)
			t.expect(info.UnitImage.Image).toBe(Scripts.hack.Image)
			t.expect(info.UnitMove.Text).toBe("Move: " .. Scripts.hack.Move)
			t.expect(info.UnitMaxSize.Text).toBe("Max Size: " .. Scripts.hack.MaxSize)
			t.expect(info.UnitFlavorText.Text).toBe(Scripts.hack.Desc)
			-- Dummy definition has MoveLeft = 0, so no move entry
			t.expect(info.CommandList:FindFirstChild("move")).toBe(nil)
			for _, command in pairs(Scripts.hack.CommandList) do
				t.expect(info.CommandList:FindFirstChild(command.Id) ~= nil).toBeTruthy()
			end
		end)
	end)

	t.test("unit with moves shows the move entry and size warnings", function()
		withView(function(view, list, info)
			-- Find a command with a SizeReq > 1 to exercise NotEnoughSize
			local unit = {
				Enemy = false,
				MoveLeft = 1,
				Move = 10,
				MaxSize = 4,
				Tail = { 1 }, -- length 1: anything with SizeReq > 1 shows the warning
				Definition = Scripts.hack,
			}
			ReactRoblox.act(function()
				view:SetSelectedUnit(unit)
			end)
			t.expect(info.CommandList:FindFirstChild("move") ~= nil).toBeTruthy()
			t.expect(info.CommandList.move.CommandText1.Text).toBe("Move the unit.")
			t.expect(info.UnitMove.Text).toBe("Move: 10 (max)")
			for _, command in pairs(Scripts.hack.CommandList) do
				local entry = info.CommandList[command.Id]
				t.expect(entry.NotEnoughSize.Visible).toBe(command.SizeReq > 1)
			end
		end)
	end)

	t.test("SetSelectedCommand toggles the selection overlay", function()
		withView(function(view, list, info)
			ReactRoblox.act(function()
				view:SetSelectedUnitDefinition("hack")
			end)
			local commandId = Scripts.hack.CommandList[1].Id
			ReactRoblox.act(function()
				view:SetSelectedCommand(commandId)
			end)
			t.expect(info.CommandList[commandId].SelectedOverlay.Visible).toBeTruthy()
		end)
	end)

	t.test("special panes show flavor content", function()
		withView(function(view, list, info)
			ReactRoblox.act(function()
				view:SetSelectedUpload()
			end)
			t.expect(info.UnitName.Text).toBe("Upload Zone")
			t.expect(info.UnitMove.Text).toBe("")
			t.expect(info.UnitFlavorText.Text).toBe("Upload your units here to do battle!")
			ReactRoblox.act(function()
				view:SetSelectedPickup("credits")
			end)
			t.expect(info.UnitName.Text).toBe("Credits")
		end)
	end)

	t.test("visibility controls", function()
		withView(function(view, list, info)
			ReactRoblox.act(function()
				view:SetSelectedUnitDefinition("hack")
			end)
			t.expect(info.Visible).toBeTruthy()
			view:ClearSelectedUnit()
			t.expect(info.Visible).toBeFalsy()
			view:Hide()
			t.expect(list.Visible).toBeFalsy()
			view:SetProgramListVisible(true)
			t.expect(list.Visible).toBeTruthy()
		end)
	end)
end
