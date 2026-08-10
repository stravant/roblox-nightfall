local Places = require(game.ReplicatedStorage.Places)
local TileTemplates = require(game.ReplicatedStorage.GameView.TileTemplates)

local FlashySquareView = {}

function FlashySquareView.new(tileSize, container)
	local this = {}

	local mGui = TileTemplates.FlashOverlay()
	mGui.Visible = false
	mGui.Parent = container

	local mDestroyed = false

	local mCycleStart = 0
	local mStepCn = nil

	local function curve(x)
		return 0.0 + 0.8*(x)^1.7 - 0.3*(0.6*x^0.8 + 0.4*x^1.5)
	end

	local function animate()
		local delta = tick() - mCycleStart
		--mGui.Sprite.UIScale.Scale = curve(delta % 0.6 / 0.6)
		mGui.Sprite.ImageTransparency = curve(delta % 0.6 / 0.6)
	end

	function this:Show(x, y)
		if mDestroyed then
			error("Show while destroyed")
		end
		mGui.Position = UDim2.new(0, (x-1)*tileSize, 0, (y-1)*tileSize)
		mGui.Visible = true
		mCycleStart = tick()
		if not mStepCn then
			mStepCn = game:GetService('RunService').RenderStepped:connect(animate)
		end
	end

	-- I'm lazy so I'm throwing this in here instead of making a separate view just for it
	function this:ShowCreditPickup(x, y, amount)
		local show = TileTemplates.PickupCreditsWithAmount()
		show.Position = UDim2.new(0, (x-1)*tileSize, 0, (y-1)*tileSize)
		show.Amount.Text = "+" .. amount
		show.Parent = container
		show:TweenPosition(
			UDim2.new(0, (x-1)*tileSize, 0, (y-1)*tileSize - 15),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quad,
			0.8,
			true,
			function() show:Destroy() end)
	end

	function this:Hide()
		mGui.Visible = false
		if mStepCn then
			mStepCn:disconnect()
			mStepCn = nil
		end
	end

	function this:Destroy()
		mDestroyed = true
		if mStepCn then
			mStepCn:disconnect()
			mStepCn = nil
		end
	end

	return this
end

return FlashySquareView
