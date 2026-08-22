--!strict
-- React conversion of BuyLevelSkipView. Public API is unchanged from the
-- template version: BuyLevelSkipView.new(container) parents the view into the
-- container and returns an imperative view object with a Done signal; the host
-- is a MenuMouseCatcher ImageButton whose contents are rendered by React
-- (layout matches ui-reference/ModuleTemplates/BuyLevelSkipView.json).

local Signal = require(game.ReplicatedStorage.Signal)
local DeveloperProduct = require(game.ReplicatedStorage.DeveloperProduct)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"
local kSkips1Image = "rbxassetid://1396644114"
local kSkips3Image = "rbxassetid://1396653499"
local kSkips5Image = "rbxassetid://1397114413"

type BuyLevelSkipState = {
	price1Text: string,
	price3Text: string,
	price5Text: string,
	onSkips1: () -> (),
	onSkips3: () -> (),
	onSkips5: () -> (),
	onCancel: () -> (),
}

local function skipOption(image: string, label: string, xScale: number, onClick: () -> ())
	return e("ImageButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(xScale, 0, 0, 64),
		Size = UDim2.new(0, 128, 0, 128),
		BackgroundTransparency = 1,
		Image = image,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		Text = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(1, -20, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.ArialBold,
			TextSize = 20,
			TextColor3 = Color3.new(0, 0.501961, 0),
			Text = label,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.new(0.384314, 1, 0),
				Transparency = 0.8,
				Thickness = 1.5,
			}),
		}),
	})
end

local function BuyLevelSkipContent(props: BuyLevelSkipState)
	return e("ImageLabel", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 500, 0, 256),
		ZIndex = 2,
		BackgroundTransparency = 1,
		Image = kWindowImage,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = kWindowSliceCenter,
		ImageRectSize = kWindowImageRectSize,
	}, {
		WindowTitle = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0, 12),
			Size = UDim2.new(0, 200, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Buy Level Skips",
		}),
		Text = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 38),
			Size = UDim2.new(1, -20, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = Color3.new(0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Level skips can be used at any time to beat a level. Select an option to buy.",
		}),
		Inset = e("ImageLabel", {
			Position = UDim2.new(0, 5, 0, 55),
			Size = UDim2.new(1, -10, 1, -99),
			BackgroundTransparency = 1,
			Image = kInsetImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(8, 8, 8, 8),
		}, {
			UIPadding = e("UIPadding", {
				PaddingTop = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
			Skips1 = skipOption(kSkips1Image, "1 Skip - " .. props.price1Text, 0.167, props.onSkips1),
			Skips3 = skipOption(kSkips3Image, "3 Skips - " .. props.price3Text, 0.5, props.onSkips3),
			Skips5 = skipOption(kSkips5Image, "5 Skips - " .. props.price5Text, 0.833, props.onSkips5),
		}),
		CancelButton = e(WindowsButton, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -5, 1, -5),
			Size = UDim2.new(0, 180, 0, 36),
			Text = "Cancel",
			OnClick = props.onCancel,
		}),
	})
end

local BuyLevelSkipView = {}

function BuyLevelSkipView.new(container: Instance)
	local this = {}

	this.Done = Signal.new()

	local mDestroyed = false

	local mGui = Instance.new("ImageButton")
	mGui.Name = "MenuMouseCatcher"
	-- Extended past the topbar inset so the dim covers the full screen
	local guiInset = game:GetService("GuiService"):GetGuiInset()
	mGui.Position = UDim2.new(0, 0, 0, -guiInset.Y)
	mGui.Size = UDim2.new(1, 0, 1, guiInset.Y)
	mGui.BackgroundColor3 = Color3.new(0, 0, 0)
	mGui.BackgroundTransparency = 0.5
	mGui.BorderSizePixel = 0
	mGui.ZIndex = 7
	mGui.Image = ""
	mGui.AutoButtonColor = false

	-- Forward-declared so the button callbacks (registered during create)
	-- can Destroy the view; assigned right after StatefulRoot.create returns.
	local mRoot: StatefulRoot.StatefulRoot? = nil

	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		if mRoot then
			mRoot.unmount()
		end
		mGui:Destroy()
	end

	local function promptPurchase(productId: number)
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		this:Destroy()
		this.Done:fire()
	end

	mRoot = StatefulRoot.create(mGui, BuyLevelSkipContent, {
		price1Text = "...",
		price3Text = "...",
		price5Text = "...",
		onSkips1 = function()
			promptPurchase(DeveloperProduct.Skip1)
		end,
		onSkips3 = function()
			promptPurchase(DeveloperProduct.Skip3)
		end,
		onSkips5 = function()
			promptPurchase(DeveloperProduct.Skip5)
		end,
		onCancel = function()
			this:Destroy()
			this.Done:fire()
		end,
	})

	-- Prices come from live product info rather than hardcoded numbers, so
	-- price changes (and dynamic/regional pricing) show correctly. Each
	-- fetch fills in as it lands; a failed fetch leaves the placeholder.
	for _, product in pairs({
		{ Key = "price1Text", ProductId = DeveloperProduct.Skip1 },
		{ Key = "price3Text", ProductId = DeveloperProduct.Skip3 },
		{ Key = "price5Text", ProductId = DeveloperProduct.Skip5 },
	}) do
		task.spawn(function()
			local st, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.ProductId, Enum.InfoType.Product)
			end)
			if mDestroyed or not mRoot then
				return
			end
			if st and info and info.PriceInRobux then
				mRoot.setState({ [product.Key] = "R$" .. info.PriceInRobux })
			end
		end)
	end

	mGui.Parent = container

	return this
end

return BuyLevelSkipView
