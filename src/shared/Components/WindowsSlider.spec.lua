-- Specs require game modules via game.* paths (NOT relative) so every module
-- resolves to the single copy installed into the runtests DataModel.
--
-- The slider's drag behavior needs real input events, so these specs only
-- cover what is testable without them: mount structure, knob positioning
-- from the Value prop, and that OnChanged is not called by rendering.
return function(t)
	local CoreGui = game:GetService("CoreGui")
	local React = require(game.ReplicatedStorage.Packages.React)
	local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
	local WindowsSlider = require(game.ReplicatedStorage.Components.WindowsSlider)

	local e = React.createElement

	local function withSlider(props, fn)
		local screen = Instance.new("ScreenGui")
		screen.Parent = CoreGui
		local root = ReactRoblox.createRoot(screen)
		ReactRoblox.act(function()
			root:render(e(WindowsSlider, props))
		end)
		local ok, err = pcall(fn, screen:FindFirstChildOfClass("Frame"), root)
		ReactRoblox.act(function()
			root:unmount()
		end)
		screen:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	local function knobPositionFor(value)
		return UDim2.new((value / 1.1 + 1) / 2, 0, 0.5, 0)
	end

	t.test("mounts the slider area with gutter, knob, and end labels", function()
		withSlider({
			Value = 0,
			LeftLabel = "Muted",
			RightLabel = "DAT BASS",
		}, function(frame)
			t.expect(frame).toBeTruthy()
			t.expect(frame.SliderArea.ClassName).toBe("ImageButton")
			t.expect(frame.SliderArea.Gutter.ClassName).toBe("ImageButton")
			t.expect(frame.SliderArea.Slider.ClassName).toBe("ImageLabel")
			t.expect(frame.SliderArea.Slider.Size).toBe(UDim2.new(0, 32, 0, 32))
			t.expect(frame.SliderArea.LeftLabel.Text).toBe("Muted")
			t.expect(frame.SliderArea.RightLabel.Text).toBe("DAT BASS")
		end)
	end)

	t.test("Value 0 centers the knob", function()
		withSlider({ Value = 0 }, function(frame)
			t.expect(frame.SliderArea.Slider.Position).toBe(knobPositionFor(0))
			t.expect(frame.SliderArea.Slider.Position).toBe(UDim2.new(0.5, 0, 0.5, 0))
		end)
	end)

	t.test("Value 1 and -1 position the knob at the extremes", function()
		withSlider({ Value = 1 }, function(frame)
			t.expect(frame.SliderArea.Slider.Position).toBe(knobPositionFor(1))
		end)
		withSlider({ Value = -1 }, function(frame)
			t.expect(frame.SliderArea.Slider.Position).toBe(knobPositionFor(-1))
		end)
	end)

	t.test("re-rendering with a new Value moves the knob", function()
		withSlider({ Value = 0 }, function(frame, root)
			ReactRoblox.act(function()
				root:render(e(WindowsSlider, { Value = 0.55 }))
			end)
			t.expect(frame.SliderArea.Slider.Position).toBe(knobPositionFor(0.55))
		end)
	end)

	t.test("OnChanged is not called by mounting or re-rendering", function()
		local calls = 0
		withSlider({
			Value = 0,
			OnChanged = function()
				calls += 1
			end,
		}, function(frame, root)
			ReactRoblox.act(function()
				root:render(e(WindowsSlider, {
					Value = 0.25,
					OnChanged = function()
						calls += 1
					end,
				}))
			end)
			t.expect(calls).toBe(0)
		end)
	end)
end
