-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- Smoke test for the full databattle screen driven by a real GameState.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local GameView = require(game.ReplicatedStorage.GameView)
	local GameState = require(game.ReplicatedStorage.GameState)
	local GameController = require(game.ReplicatedStorage.GameController)
	local Places = require(game.ReplicatedStorage.Places)
	local Scripts = require(game.ReplicatedStorage.Scripts)
	local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)

	local function makeInventory()
		local inventory = {}
		for id, unit in pairs(Scripts) do
			if not unit.Enemy then
				table.insert(inventory, { Id = id, Count = 2 })
			end
		end
		return inventory
	end

	local function withView(fn)
		local originalGetSkips = LocalPlayerData.GetSkips
		LocalPlayerData.GetSkips = function()
			return 2
		end

		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local gameState = GameState.new(Places.L12, makeInventory(), GameState.ServerDelayFunc)
		local controller = GameController.new(gameState)
		-- Records the topbar state the view drives
		local fakeTopbar = { startVisible = false, doneTurnVisible = false, undoVisible = false }
		function fakeTopbar:SetStartVisible(visible)
			self.startVisible = visible
		end
		function fakeTopbar:SetDoneTurnVisible(visible)
			self.doneTurnVisible = visible
		end
		function fakeTopbar:SetUndoVisible(visible)
			self.undoVisible = visible
		end
		function fakeTopbar:SetOnUndo(callback)
			self.onUndo = callback
		end
		function fakeTopbar:GetStartButton()
			return nil
		end
		local view
		local ok, err = pcall(function()
			ReactRoblox.act(function()
				view = GameView.new(gameState, controller, nil, fakeTopbar)
			end)
			view:getGui().Parent = screen
			fn(view, view:getGui(), gameState, fakeTopbar)
		end)

		LocalPlayerData.GetSkips = originalGetSkips
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

	t.test("mounts the 3D board with map tiles, upload zones, and background", function()
		withView(function(view, gui, gameState)
			t.expect(view:getBoard3D():GetBackgroundImage()).toBe(gameState:GetPlaceBackground())
			-- The board lives on a SurfaceGui in the workspace
			t.expect(workspace:FindFirstChild("BattleBoard3D") ~= nil).toBeTruthy()

			local board = view:getBoardGui()
			local filledCount = 0
			for x = 1, Places.PlaceWidth do
				for y = 1, Places.PlaceHeight do
					if gameState:IsFilled(x, y) then
						filledCount = filledCount + 1
					end
				end
			end
			t.expect(#board.Tiles:GetChildren()).toBe(filledCount)
			t.expect(#board.UploadZones:GetChildren()).toBe(#gameState:GetUploadZones())

			t.expect(gui.EndGameOverlay.Visible).toBeFalsy()
		end)
	end)

	t.test("end game overlay's skip button shows the stubbed skip count", function()
		withView(function(view, gui)
			t.expect(gui.EndGameOverlay.Box.SkipButton.Text.Text).toBe("Skip Node (2 skips available)")
		end)
	end)

	t.test("uploading a unit and starting the game flips the chrome state", function()
		withView(function(view, gui, gameState, topbar)
			local board = view:getBoardGui()
			-- The place's own enemy units are already rendered at mount
			local unitsBefore = #board.Units:GetChildren()
			local zone = gameState:GetUploadZones()[1]
			gameState:UploadUnit(zone.x, zone.y, Scripts.hack)
			task.wait() -- game signals are BindableEvent-based (async)
			ReactRoblox.act(function() end)
			-- The uploaded unit gained a rendered tail container
			t.expect(#board.Units:GetChildren()).toBe(unitsBefore + 1)

			gameState:StartGame()
			task.wait()
			ReactRoblox.act(function() end)
			t.expect(topbar.startVisible).toBeFalsy()
			t.expect(topbar.doneTurnVisible).toBeTruthy()
			t.expect(#board.UploadZones:GetChildren()).toBe(0)
		end)
	end)

	t.test("Destroy removes the gui and the 3D board", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:Destroy()
			end)
			t.expect(gui.Parent).toBe(nil)
			t.expect(workspace:FindFirstChild("BattleBoard3D")).toBe(nil)
			-- Camera restored for the editor
			t.expect(workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable).toBeTruthy()
		end)
	end)
end
