-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- Note: the bob animation itself (RenderStepped moving Rotate.Arrow) needs
-- real render frames to elapse, so we don't assert exact animated positions;
-- assertions on Arrow.Position only check the invariant part (anchored at the
-- center, offset within the 0..10 bob range).
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local TutorialArrowView = require(game.ReplicatedStorage.TutorialArrowView)

	-- The view has no GetGui(); consumers only ever hand it containers via
	-- Show. The helper provides a container and a lookup for the mounted host.
	local function withView(fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local container = Instance.new("Frame")
		container.Name = "Container"
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundTransparency = 1
		container.Parent = screen
		local view
		ReactRoblox.act(function()
			view = TutorialArrowView.new()
		end)
		local ok, err = pcall(fn, view, container)
		ReactRoblox.act(function()
			view:Destroy()
		end)
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	local function showInto(view, container, angle, position)
		ReactRoblox.act(function()
			view:Show(container, angle, position)
		end)
		return container:FindFirstChild("TutArrowContainer")
	end

	t.test("Show mounts the template structure into the container", function()
		withView(function(view, container)
			local gui = showInto(view, container, 0, UDim2.new(0, 0, 0, 0))
			t.expect(gui).toBeTruthy()
			t.expect(gui.ClassName).toBe("Frame")
			t.expect(gui.AnchorPoint).toBe(Vector2.new(0.5, 0.5))
			t.expect(gui.Size).toBe(UDim2.new(0, 100, 0, 100))
			local rotate = gui:FindFirstChild("Rotate")
			t.expect(rotate).toBeTruthy()
			t.expect(rotate.ClassName).toBe("Frame")
			t.expect(rotate.AnchorPoint).toBe(Vector2.new(0.5, 0.5))
			t.expect(rotate.Position).toBe(UDim2.new(0.5, 0, 0.5, 0))
			t.expect(rotate.Size).toBe(UDim2.new(0, 100, 0, 100))
			t.expect(rotate.Rotation).toBe(0)
			local arrow = rotate:FindFirstChild("Arrow")
			t.expect(arrow).toBeTruthy()
			t.expect(arrow.ClassName).toBe("ImageLabel")
			t.expect(arrow.Image).toBe("rbxassetid://1354410067")
			t.expect(arrow.AnchorPoint).toBe(Vector2.new(0.5, 0))
			t.expect(arrow.Size).toBe(UDim2.new(0, 48, 0, 48))
			-- Animated: only the invariant part of the position is asserted
			t.expect(arrow.Position.X.Scale).toBe(0.5)
			t.expect(arrow.Position.Y.Scale).toBe(0.5)
			t.expect(arrow.Position.Y.Offset >= 0).toBeTruthy()
			t.expect(arrow.Position.Y.Offset <= 10).toBeTruthy()
		end)
	end)

	t.test("Show applies position and rotation", function()
		withView(function(view, container)
			local gui = showInto(view, container, 180, UDim2.new(0.5, 0, 0.3, 0))
			t.expect(gui.Position).toBe(UDim2.new(0.5, 0, 0.3, 0))
			t.expect(gui.Rotate.Rotation).toBe(180)
		end)
	end)

	t.test("Show again updates position and rotation", function()
		withView(function(view, container)
			showInto(view, container, 180, UDim2.new(0.5, 0, 0.3, 0))
			local gui = showInto(view, container, -90, UDim2.new(0.7, 0, 0.5, 0))
			t.expect(gui.Position).toBe(UDim2.new(0.7, 0, 0.5, 0))
			t.expect(gui.Rotate.Rotation).toBe(-90)
		end)
	end)

	t.test("Show moves the arrow between containers", function()
		withView(function(view, container)
			local otherContainer = Instance.new("Frame")
			otherContainer.BackgroundTransparency = 1
			otherContainer.Parent = container.Parent
			local ok, err = pcall(function()
				showInto(view, container, 0, UDim2.new(0, 0, 0, 0))
				local gui = showInto(view, otherContainer, 90, UDim2.new(0, 0, 0.5, 0))
				t.expect(gui).toBeTruthy()
				t.expect(container:FindFirstChild("TutArrowContainer")).toBeFalsy()
				t.expect(gui.Rotate.Rotation).toBe(90)
			end)
			otherContainer:Destroy()
			if not ok then
				error(err, 0)
			end
		end)
	end)

	t.test("Hide removes the arrow from the container", function()
		withView(function(view, container)
			showInto(view, container, 180, UDim2.new(0.5, 0, 0.3, 0))
			ReactRoblox.act(function()
				view:Hide()
			end)
			t.expect(container:FindFirstChild("TutArrowContainer")).toBeFalsy()
		end)
	end)

	t.test("Show after Hide re-shows", function()
		withView(function(view, container)
			showInto(view, container, 180, UDim2.new(0.5, 0, 0.3, 0))
			ReactRoblox.act(function()
				view:Hide()
			end)
			local gui = showInto(view, container, 0, UDim2.new(0, 16, 0, 16))
			t.expect(gui).toBeTruthy()
			t.expect(gui.Position).toBe(UDim2.new(0, 16, 0, 16))
			t.expect(gui.Rotate.Rotation).toBe(0)
		end)
	end)

	t.test("Destroy hides the arrow and is idempotent", function()
		withView(function(view, container)
			showInto(view, container, 180, UDim2.new(0.5, 0, 0.3, 0))
			ReactRoblox.act(function()
				view:Destroy()
			end)
			t.expect(container:FindFirstChild("TutArrowContainer")).toBeFalsy()
			-- withView's cleanup calls Destroy a second time; reaching the end
			-- of this callback without erroring covers idempotence.
		end)
	end)
end
