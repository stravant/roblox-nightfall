-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- Note: the Skips1/3/5 buttons call MarketplaceService:PromptProductPurchase
-- when clicked, so these specs never simulate clicks on them — they only
-- assert the mounted UI state.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local BuyLevelSkipView = require(game.ReplicatedStorage.BuyLevelSkipView)

	local function withView(fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local view
		ReactRoblox.act(function()
			view = BuyLevelSkipView.new(screen)
		end)
		local ok, err = pcall(fn, view, screen:FindFirstChild("MenuMouseCatcher"))
		ReactRoblox.act(function()
			view:Destroy()
		end)
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	t.test("mounts the mouse catcher host into the container", function()
		withView(function(view, gui)
			t.expect(gui).toBeTruthy()
			t.expect(gui.ClassName).toBe("ImageButton")
			t.expect(gui.Size).toBe(UDim2.new(1, 0, 1, 0))
			t.expect(gui.BackgroundTransparency).toBe(0.5)
			t.expect(gui.ZIndex).toBe(7)
		end)
	end)

	t.test("mounts the menu window with the template structure", function()
		withView(function(view, gui)
			t.expect(gui.Menu.ClassName).toBe("ImageLabel")
			t.expect(gui.Menu.Size).toBe(UDim2.new(0, 500, 0, 256))
			t.expect(gui.Menu.WindowTitle.Text).toBe("Buy Level Skips")
			t.expect(gui.Menu.Text.Text).toBe(
				"Level skips can be used at any time to beat a level. Select an option to buy."
			)
			t.expect(gui.Menu.Inset.ClassName).toBe("ImageLabel")
			t.expect(gui.Menu.Inset.UIPadding.PaddingTop).toBe(UDim.new(0, 20))
		end)
	end)

	t.test("shows the three skip purchase options", function()
		withView(function(view, gui)
			local inset = gui.Menu.Inset
			t.expect(inset.Skips1.ClassName).toBe("ImageButton")
			t.expect(inset.Skips1.Text.Text).toBe("1 Skip - R$200")
			t.expect(inset.Skips3.ClassName).toBe("ImageButton")
			t.expect(inset.Skips3.Text.Text).toBe("3 Skips - R$450")
			t.expect(inset.Skips5.ClassName).toBe("ImageButton")
			t.expect(inset.Skips5.Text.Text).toBe("5 Skips - R$400")
		end)
	end)

	t.test("shows the cancel button", function()
		withView(function(view, gui)
			t.expect(gui.Menu.CancelButton.ClassName).toBe("ImageButton")
			t.expect(gui.Menu.CancelButton.Text.Text).toBe("Cancel")
			t.expect(gui.Menu.CancelButton.AnchorPoint).toBe(Vector2.new(1, 1))
		end)
	end)

	t.test("Destroy removes the gui without firing Done", function()
		withView(function(view, gui)
			local doneFired = false
			local cn = view.Done:connect(function()
				doneFired = true
			end)
			ReactRoblox.act(function()
				view:Destroy()
			end)
			cn:Disconnect()
			t.expect(gui.Parent).toBe(nil)
			t.expect(doneFired).toBeFalsy()
		end)
	end)

	t.test("Destroy is safe to call twice", function()
		withView(function(view, gui)
			ReactRoblox.act(function()
				view:Destroy()
			end)
			ReactRoblox.act(function()
				view:Destroy()
			end)
			t.expect(gui.Parent).toBe(nil)
		end)
	end)
end
