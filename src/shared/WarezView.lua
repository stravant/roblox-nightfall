--!strict
-- The warez shop. One Win95-style window: the shop list lives in a native
-- ScrollingFrame on the left, and the right side is a detail panel for the
-- selected program (icon, stats, description, owned count). Replaces the old
-- layout that used a separate floating unit-info tray and the imperative
-- ScrollingFrame library.
--
-- Public API is unchanged: WarezView.new(warezNodeId, warez) returns an
-- imperative view with MadePurchase/Done signals and GetGui().

local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"

local kBlueColor = Color3.new(0, 0, 0.5)
local kTextBlack = Color3.new(0, 0, 0)
local kTextWhite = Color3.new(1, 1, 1)

type ProgramEntryData = {
	Id: string,
	Cost: number,
	Name: string,
	Image: string,
	Color: Color3,
}

type WarezState = {
	selectedId: string?,
	purchaseVisible: boolean,
	insufficientVisible: boolean,
	ownedCount: number,
	bigScreen: boolean,
	programs: { ProgramEntryData },
	onSelect: (id: string) -> (),
	onPurchase: () -> (),
	onDone: () -> (),
}

local function programEntry(data: ProgramEntryData, selected: boolean, onSelect: (id: string) -> (), layoutOrder: number)
	local textColor = if selected then kTextWhite else kTextBlack
	return e("ImageButton", {
		Active = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, 24),
		LayoutOrder = layoutOrder,
		BackgroundColor3 = if selected then kBlueColor else kTextWhite,
		Image = "",
		[React.Event.MouseButton1Click] = function()
			onSelect(data.Id)
		end,
	}, {
		CostLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.new(0, 40, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 15,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(data.Cost),
		}),
		Icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 50, 0.5, 0),
			Size = UDim2.new(0, 20, 0, 20),
			BackgroundColor3 = data.Color,
			BorderColor3 = Color3.new(0, 0, 0),
			Image = data.Image,
		}),
		NameLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 76, 0.5, 0),
			Size = UDim2.new(1, -80, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = data.Name,
		}),
	})
end

local function detailPanel(selectedId: string?, ownedCount: number)
	if not selectedId then
		return {
			Hint = e("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 16,
				TextColor3 = Color3.new(0.35, 0.35, 0.35),
				TextWrapped = true,
				Text = "Select a program",
			}),
		}
	end
	local def = Scripts[selectedId]
	return {
		DetailName = e("TextLabel", {
			Position = UDim2.new(0, 8, 0, 6),
			Size = UDim2.new(1, -16, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 18,
			TextColor3 = kTextBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.Name,
		}),
		DetailIcon = e("ImageLabel", {
			Position = UDim2.new(0, 8, 0, 32),
			Size = UDim2.new(0, 40, 0, 40),
			BackgroundColor3 = def.Color,
			BorderColor3 = Color3.new(0, 0, 0),
			Image = def.Image,
		}),
		MoveText = e("TextLabel", {
			Position = UDim2.new(0, 56, 0, 32),
			Size = UDim2.new(1, -60, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 15,
			TextColor3 = kTextBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Move: " .. def.Move,
		}),
		MaxSizeText = e("TextLabel", {
			Position = UDim2.new(0, 56, 0, 52),
			Size = UDim2.new(1, -60, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 15,
			TextColor3 = kTextBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Max Size: " .. def.MaxSize,
		}),
		FlavorText = e("TextLabel", {
			Position = UDim2.new(0, 8, 0, 80),
			Size = UDim2.new(1, -16, 1, -106),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = 15,
			TextColor3 = kTextBlack,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = def.Desc,
		}),
		OwnedLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -6),
			Size = UDim2.new(1, -16, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(0, 100, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "You own: " .. ownedCount .. "x",
		}),
	}
end

local function WarezContent(props: WarezState)
	local rows: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	}
	for i, data in props.programs do
		rows[data.Id] = programEntry(data, props.selectedId == data.Id, props.onSelect, i)
	end

	return e(React.Fragment, nil, {
		MouseCatcher = e("ImageButton", {
			Active = true,
			AutoButtonColor = false,
			-- Extended past the topbar inset so the dim covers the full screen
			Position = UDim2.new(0, 0, 0, -game:GetService("GuiService"):GetGuiInset().Y),
			Size = UDim2.new(1, 0, 1, game:GetService("GuiService"):GetGuiInset().Y),
			-- Same shadowed backdrop as the menus and conversations
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Image = "",
		}),
		MainBox = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 470, 0, 300),
			ZIndex = 2,
			BackgroundTransparency = 1,
			Image = kWindowImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = kWindowSliceCenter,
			ImageRectSize = kWindowImageRectSize,
		}, {
			UIScale = if props.bigScreen then e("UIScale", { Scale = 1.5 }) else nil,
			WindowTitle = e("TextLabel", {
				Position = UDim2.new(0, 6, 0, 2),
				Size = UDim2.new(1, -12, 0, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				TextColor3 = kTextWhite,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Warez Node",
			}),
			ShopInset = e("ImageLabel", {
				Position = UDim2.new(0, 6, 0, 26),
				Size = UDim2.new(0, 210, 1, -72),
				BackgroundTransparency = 1,
				Image = kInsetImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
			}, {
				ShopScroll = e("ScrollingFrame", {
					Position = UDim2.new(0, 4, 0, 4),
					Size = UDim2.new(1, -8, 1, -8),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(0, 0, 0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarThickness = 8,
					ScrollBarImageColor3 = Color3.new(0, 0, 0),
				}, rows),
			}),
			DetailInset = e("ImageLabel", {
				Position = UDim2.new(0, 222, 0, 26),
				Size = UDim2.new(1, -228, 1, -72),
				BackgroundTransparency = 1,
				Image = kInsetImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
			}, detailPanel(props.selectedId, props.ownedCount)),
			InsufficientCreditsText = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 6, 1, -8),
				Size = UDim2.new(0, 210, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 18,
				TextColor3 = Color3.new(0.666667, 0, 0),
				Text = "Insufficient Credits",
				Visible = props.insufficientVisible,
			}),
			PurchaseButton = e(WindowsButton, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 6, 1, -8),
				Size = UDim2.new(0, 210, 0, 30),
				Text = "Purchase",
				Visible = props.purchaseVisible,
				OnClick = props.onPurchase,
			}),
			DoneButton = e(WindowsButton, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -8),
				Size = UDim2.new(0, 160, 0, 30),
				Text = "Done Shopping",
				OnClick = props.onDone,
			}),
		}),
	})
end

local WarezView = {}

function WarezView.new(warezNodeId: string, warez: { [string]: number })
	local this = {}

	this.MadePurchase = Signal.new()
	this.Done = Signal.new()

	local mGui = Instance.new("Frame")
	mGui.Name = "Warez"
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.Position = UDim2.new(0.5, 0, 0.5, 0)
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundTransparency = 1
	mGui.ZIndex = 4

	function this:GetGui()
		return mGui
	end

	local mPrograms: { ProgramEntryData } = {}
	for id, cost in pairs(warez) do
		local data = Scripts[id]
		if not data then
			print("Missing script:", id)
		end
		table.insert(mPrograms, {
			Id = id,
			Cost = tonumber(cost) :: number,
			Name = data.Name,
			Image = data.Image,
			Color = data.Color,
		})
	end
	-- Cheapest first
	table.sort(mPrograms, function(a, b)
		return a.Cost < b.Cost
	end)

	local function ownedCountOf(id: string?): number
		if not id then
			return 0
		end
		for _, info in pairs(LocalPlayerData:GetProgramList()) do
			if info.Id == id then
				return info.Count
			end
		end
		return 0
	end

	local mSelectedProgram: string? = nil
	local mRoot: StatefulRoot.StatefulRoot? = nil

	function this:SelectProgram(id: string?)
		mSelectedProgram = id
		if id then
			local canAfford = LocalPlayerData:GetCredits() >= warez[id]
			;(mRoot :: StatefulRoot.StatefulRoot).setState({
				selectedId = id,
				purchaseVisible = canAfford,
				insufficientVisible = not canAfford,
				ownedCount = ownedCountOf(id),
			})
		else
			(mRoot :: StatefulRoot.StatefulRoot).setState({
				selectedId = StatefulRoot.None,
				purchaseVisible = false,
				insufficientVisible = false,
				ownedCount = 0,
			})
		end
	end

	function this:PurchaseSelectedProgram()
		local cost = warez[mSelectedProgram :: string]
		if LocalPlayerData:GetCredits() >= cost then
			LocalPlayerData:AddCredits(-cost)
			LocalPlayerData:AddUnit(mSelectedProgram)
			game.ReplicatedStorage.Remotes.PurchaseUnit:FireServer(warezNodeId, mSelectedProgram)
			this.MadePurchase:fire(mSelectedProgram)
			-- Refresh owned count and affordability with the new balance
			this:SelectProgram(mSelectedProgram)
		end
	end

	mRoot = StatefulRoot.create(mGui, WarezContent, {
		selectedId = nil,
		purchaseVisible = false,
		insufficientVisible = false,
		ownedCount = 0,
		bigScreen = DeviceInfo.ScreenHeight > 500,
		programs = mPrograms,
		onSelect = function(id: string)
			this:SelectProgram(id)
		end,
		onPurchase = function()
			SoundManager:Play("SelectUnit")
			this:PurchaseSelectedProgram()
		end,
		onDone = function()
			SoundManager:Play("SelectUnit")
			this.Done:fire()
		end,
	})

	this:SelectProgram(if #mPrograms > 0 then mPrograms[1].Id else nil)

	return this
end

return WarezView
