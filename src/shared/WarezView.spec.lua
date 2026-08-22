-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- WarezView reads LocalPlayerData (credits + owned programs) — stubbed here
-- and restored in cleanup. Purchase clicks are never simulated (they would
-- FireServer / touch player data).
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local WarezView = require(game.ReplicatedStorage.WarezView)
	local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)

	local kWarez = { hack = 100, slingshot = 500 }

	local function withView(credits, fn)
		local originalGetProgramList = LocalPlayerData.GetProgramList
		local originalGetCredits = LocalPlayerData.GetCredits

		LocalPlayerData.GetProgramList = function()
			return { { Id = "hack", Count = 2 } }
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
			fn(view, view:GetGui())
		end)

		LocalPlayerData.GetProgramList = originalGetProgramList
		LocalPlayerData.GetCredits = originalGetCredits
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	local function shopRow(gui, id)
		return gui.MainBox.ShopInset:FindFirstChild("ShopScroll", true):FindFirstChild(id)
	end

	t.test("mounts the window with one scroll row per program, cheapest first", function()
		withView(10000, function(view, gui)
			t.expect(gui.MainBox.WindowTitle.Text).toBe("Warez Node")
			t.expect(gui.MainBox.DoneButton.Text.Text).toBe("Done Shopping")
			t.expect(gui.MainBox.ShopInset:FindFirstChild("ShopScroll", true).ClassName).toBe("ScrollingFrame")
			t.expect(gui.MainBox.ShopHeadings.HeadingOwned.Text).toBe("Owned")
			local hack = shopRow(gui, "hack")
			local slingshot = shopRow(gui, "slingshot")
			t.expect(hack.NameLabel.Text).toBe("Hack")
			t.expect(hack.CostLabel.Text).toBe("100")
			-- Owned column comes from the player's inventory
			t.expect(hack.OwnedLabel.Text).toBe("2x")
			t.expect(slingshot.NameLabel.Text).toBe("Slingshot")
			t.expect(slingshot.CostLabel.Text).toBe("500")
			t.expect(slingshot.OwnedLabel.Text).toBe("0x")
			-- Cheapest first
			t.expect(hack.LayoutOrder < slingshot.LayoutOrder).toBeTruthy()
		end)
	end)

	t.test("wz1 pins its shop order (Bit-Man off the top)", function()
		local Netmap = require(game.ReplicatedStorage.Netmap)
		local originalGetProgramList = LocalPlayerData.GetProgramList
		local originalGetCredits = LocalPlayerData.GetCredits
		LocalPlayerData.GetProgramList = function()
			return {}
		end
		LocalPlayerData.GetCredits = function()
			return 10000
		end
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		local ok, err = pcall(function()
			ReactRoblox.act(function()
				view = WarezView.new("wz1", Netmap.ById.wz1.Warez)
			end)
			view:GetGui().Parent = screen
			local gui = view:GetGui()
			local lastOrder = -1
			for _, id in pairs({ "bug", "hack", "dr", "bitman", "slingshot" }) do
				local row = shopRow(gui, id)
				t.expect(row ~= nil).toBeTruthy()
				t.expect(row.LayoutOrder > lastOrder).toBeTruthy()
				lastOrder = row.LayoutOrder
			end
		end)
		LocalPlayerData.GetProgramList = originalGetProgramList
		LocalPlayerData.GetCredits = originalGetCredits
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end)

	t.test("construction selects the cheapest program and fills the detail panel", function()
		withView(10000, function(view, gui)
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeTruthy()
			t.expect(gui.MainBox.InsufficientCreditsText.Visible).toBeFalsy()
			local detail = gui.MainBox.DetailInset
			t.expect(detail:FindFirstChild("DetailName", true).Text).toBe("Hack")
			-- Stats and attacks are rich text (stat numbers enlarged)
			local moveText = detail:FindFirstChild("MoveText", true)
			t.expect(moveText.Text:find("Move") ~= nil).toBeTruthy()
			t.expect(moveText.Text:find('<font size="20">2</font>', 1, true) ~= nil).toBeTruthy()
			local maxSizeText = detail:FindFirstChild("MaxSizeText", true)
			t.expect(maxSizeText.Text:find("Max Size") ~= nil).toBeTruthy()
			t.expect(detail.Attacks.Text:find("Slice") ~= nil).toBeTruthy()
			t.expect(detail.Attacks.Text:find("2 dmg") ~= nil).toBeTruthy()
		end)
	end)

	t.test("selecting a program highlights only its row", function()
		withView(10000, function(view, gui)
			ReactRoblox.act(function()
				view:SelectProgram("hack")
			end)
			t.expect(shopRow(gui, "hack").BackgroundColor3).toBe(Color3.new(0, 0, 0.5))
			t.expect(shopRow(gui, "hack").NameLabel.TextColor3).toBe(Color3.new(1, 1, 1))
			t.expect(shopRow(gui, "slingshot").BackgroundColor3).toBe(Color3.new(1, 1, 1))
			t.expect(shopRow(gui, "slingshot").NameLabel.TextColor3).toBe(Color3.new(0, 0, 0))
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

	t.test("clearing the selection hides purchase UI and shows the hint", function()
		withView(10000, function(view, gui)
			ReactRoblox.act(function()
				view:SelectProgram("hack")
			end)
			ReactRoblox.act(function()
				view:SelectProgram(nil)
			end)
			t.expect(gui.MainBox.PurchaseButton.Visible).toBeFalsy()
			t.expect(gui.MainBox.InsufficientCreditsText.Visible).toBeFalsy()
			t.expect(shopRow(gui, "hack").BackgroundColor3).toBe(Color3.new(1, 1, 1))
			t.expect(gui.MainBox.DetailInset:FindFirstChild("Hint") ~= nil).toBeTruthy()
		end)
	end)
end
