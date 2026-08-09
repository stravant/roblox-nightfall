local Signal = require(game.ReplicatedStorage.Signal)
local DeveloperProduct = require(game.ReplicatedStorage.DeveloperProduct)
local MarketplaceService = game:GetService('MarketplaceService')
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)

local BuyLevelSkipView = {}

function BuyLevelSkipView.new(container)
	local this = {}

	this.Done = Signal.new()

	local mGui = script.MenuMouseCatcher:Clone()
	mGui.Parent = container

	-- Purchase buttons
	mGui.Menu.Inset.Skips1.MouseButton1Click:connect(function()
		MarketplaceService:PromptProductPurchase(game.Players.LocalPlayer, DeveloperProduct.Skip1)
		this:Destroy()
		this.Done:fire()
	end)
	mGui.Menu.Inset.Skips3.MouseButton1Click:connect(function()
		MarketplaceService:PromptProductPurchase(game.Players.LocalPlayer, DeveloperProduct.Skip3)
		this:Destroy()
		this.Done:fire()
	end)
	mGui.Menu.Inset.Skips5.MouseButton1Click:connect(function()
		MarketplaceService:PromptProductPurchase(game.Players.LocalPlayer, DeveloperProduct.Skip5)
		this:Destroy()
		this.Done:fire()
	end)
	WindowsButton.new(mGui.Menu.CancelButton)
	mGui.Menu.CancelButton.MouseButton1Click:connect(function()
		this:Destroy()
		this.Done:fire()
	end)

	function this:Destroy()
		mGui:Destroy()
	end

	return this
end

return BuyLevelSkipView
