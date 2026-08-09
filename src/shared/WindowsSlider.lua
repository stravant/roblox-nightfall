local Signal = require(game.ReplicatedStorage.Signal)

local WindowsSlider = {}

function WindowsSlider.new(gui, value)
	local this = {}

	value = value or 0

	this.Changed = Signal.new(--[[new, old]])

	local mValue = value

	local function updateSlider()
		gui.SliderArea.Slider.Position = UDim2.new((mValue/1.1 + 1)/2, 0, 0.5, 0)
	end

	function this:Set(value)
		if mValue ~= value then
			local old = mValue
			mValue = value
			updateSlider()
			this.Changed:fire(value, old)
		end
	end

	function this:Get()
		return mValue
	end

	local UserInputService = game:GetService('UserInputService')
	local function handleInput(x)
		x = x - gui.AbsolutePosition.x
		x = x / gui.AbsoluteSize.x
		x = x*2 - 1
		x = x * 1.1
		if x > 1 then x = 1 end
		if x < -1 then x = -1 end
		this:Set(x)
	end
	local mMovedCn = gui.SliderArea.MouseMoved:connect(function(x, y)
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			handleInput(x)
		end
	end)
	local mClickedCn = gui.SliderArea.MouseButton1Down:connect(function(x, y)
		handleInput(x)
	end)

	-- initial update
	updateSlider()

	function this:Destroy()
		mMovedCn:disconnect()
		mClickedCn:disconnect()
	end

	return this
end

return WindowsSlider
