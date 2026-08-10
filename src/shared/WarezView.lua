--!strict
-- React conversion of WarezView. Public API is unchanged from the template
-- version: WarezView.new(warezNodeId, warez) returns an imperative view with
-- MadePurchase/Done signals; GetGui() returns the host "Warez" frame whose
-- contents are rendered by React (layout matches
-- ui-reference/ModuleTemplates/WarezView.json).
--
-- Composition notes:
-- - The ScrollingFrame library stays imperative. It only ever writes the
--   content frame's Position (and reads sizes), and React never re-applies
--   the Content element's props (they never change between renders), so the
--   two don't fight. The scroller is hooked up in an onMounted callback fired
--   from useLayoutEffect, because the rendered instances don't exist until
--   the first flush (see REACT_CONVERSION.md pitfalls).
-- - The side tray is an (as yet unconverted) UnitInfoViewMobile which parents
--   its own template GUI into our host imperatively; React roots don't touch
--   children they didn't create, so it coexists with the rendered chrome.

local UnitInfoViewMobile = require(game.ReplicatedStorage.UnitInfoViewMobile)
local Signal = require(game.ReplicatedStorage.Signal)
local Scripts = require(game.ReplicatedStorage.Scripts)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local ScrollingFrame = require(game.ReplicatedStorage.ScrollingFrame)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectSize = Vector2.new(32, 48)
local kListImage = "rbxassetid://1380754137"
local kGutterImage = "rbxassetid://1372920646"
local kScrollPartsImage = "rbxassetid://1375318214"

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
	bigScreen: boolean,
	programs: { ProgramEntryData },
	onSelect: (id: string) -> (),
	onPurchase: () -> (),
	onDone: () -> (),
	onMounted: () -> (),
}

local function programEntry(data: ProgramEntryData, selected: boolean, onSelect: (id: string) -> ())
	local textColor = if selected then kTextWhite else kTextBlack
	return e("ImageButton", {
		Active = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = if selected then kBlueColor else kTextWhite,
		[React.Event.MouseButton1Click] = function()
			onSelect(data.Id)
		end,
	}, {
		CostLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -1, 0.5, 0),
			Size = UDim2.new(0, 36, 0, 50),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 16,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(data.Cost),
		}),
		Icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 48, 0.5, 0),
			Size = UDim2.new(0, 20, 0, 20),
			BackgroundColor3 = data.Color,
			BorderColor3 = Color3.new(0, 0, 0),
			Image = data.Image,
		}),
		NameLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 64, 0.5, 0),
			Size = UDim2.new(0, 50, 0, 50),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansLight,
			TextSize = 16,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = data.Name,
		}),
	})
end

local function WarezContent(props: WarezState)
	React.useLayoutEffect(function()
		props.onMounted()
	end, {})

	local rows: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 2),
		}),
	}
	for _, data in props.programs do
		rows[data.Id] = programEntry(data, props.selectedId == data.Id, props.onSelect)
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
			Position = UDim2.new(0.5, 75, 0.5, 0),
			Size = UDim2.new(0, 300, 0, 250),
			ZIndex = 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 2,
			Image = kWindowImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = kWindowSliceCenter,
			ImageRectSize = kWindowImageRectSize,
		}, {
			UIScale = if props.bigScreen then e("UIScale", { Scale = 1.5 }) else nil,
			WindowTitle = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0, 12),
				Size = UDim2.new(0, 200, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				TextColor3 = kTextWhite,
				TextXAlignment = Enum.TextXAlignment.Left,
				-- Static in the template (never updated by the original code)
				Text = "Warez Node Level 1",
			}),
			ProgramList = e("ImageLabel", {
				Position = UDim2.new(0, 4, 0, 25),
				Size = UDim2.new(1, -8, 1, -66),
				BorderSizePixel = 0,
				Image = kListImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(120, 24, 120, 25),
			}, {
				Headings = e("Folder", nil, {
					HeadingCost = e("TextLabel", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 9, 0, 10),
						Size = UDim2.new(0, 50, 0, 50),
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSans,
						TextSize = 14,
						TextColor3 = Color3.new(0.105882, 0.164706, 0.207843),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "Cost",
					}),
					HeadingIcon = e("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0, 49, 0, 9),
						Size = UDim2.new(0, 50, 0, 50),
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSansLight,
						TextSize = 11,
						TextColor3 = Color3.new(0.105882, 0.164706, 0.207843),
						Text = "img",
					}),
					HeadingName = e("TextLabel", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 64, 0, 9),
						Size = UDim2.new(0, 50, 0, 50),
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSans,
						TextSize = 14,
						TextColor3 = Color3.new(0.105882, 0.164706, 0.207843),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "Name",
					}),
				}),
				ContentClip = e("Frame", {
					Position = UDim2.new(0, 2, 0, 19),
					Size = UDim2.new(1, -20, 1, -21),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = true,
				}, {
					-- No Position prop: the ScrollingFrame library owns
					-- Position on this instance (see module header comment)
					Content = e("Frame", {
						Size = UDim2.new(1, 0, 0, 500),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					}, rows),
				}),
				ScrollGutter = e("ImageLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -2, 0, 2),
					Size = UDim2.new(0, 16, 1, -4),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = kGutterImage,
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.new(0, 16, 0, 16),
				}, {
					UpArrow = e("ImageButton", {
						Active = true,
						Size = UDim2.new(0, 16, 0, 16),
						BackgroundTransparency = 1,
						Image = kScrollPartsImage,
						ImageRectSize = Vector2.new(16, 16),
					}),
					DownArrow = e("ImageButton", {
						Active = true,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 0, 1, 0),
						Size = UDim2.new(0, 16, 0, 16),
						BackgroundTransparency = 1,
						Image = kScrollPartsImage,
						ImageRectOffset = Vector2.new(0, 48),
						ImageRectSize = Vector2.new(16, 16),
					}),
					ScrollbarContainer = e("Frame", {
						Position = UDim2.new(0, 0, 0, 16),
						Size = UDim2.new(0, 16, 1, -32),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					}, {
						Scrollbar = e("ImageButton", {
							Active = true,
							Size = UDim2.new(0, 16, 0, 100),
							BackgroundTransparency = 1,
							Image = kScrollPartsImage,
							ImageRectOffset = Vector2.new(0, 32),
							ImageRectSize = Vector2.new(16, 16),
							ScaleType = Enum.ScaleType.Slice,
							SliceCenter = Rect.new(8, 8, 8, 8),
						}),
					}),
				}),
			}),
			InsufficientCreditsText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.25, 6, 1, -8),
				Size = UDim2.new(0.5, -16, 0, 28),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 18,
				TextColor3 = Color3.new(0.666667, 0, 0),
				Text = "Insufficient Credits",
				Visible = props.insufficientVisible,
			}),
			PurchaseButton = e(WindowsButton, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.25, 6, 1, -8),
				Size = UDim2.new(0.5, -16, 0, 28),
				Text = "Purchase",
				Visible = props.purchaseVisible,
				OnClick = props.onPurchase,
			}),
			DoneButton = e(WindowsButton, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.75, -6, 1, -8),
				Size = UDim2.new(0.5, -16, 0, 28),
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

	-- The unit info side tray (unconverted; parents its own GUI into mGui)
	local mUnitInfoView = UnitInfoViewMobile.new(mGui, LocalPlayerData:GetProgramList())

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

	local mSelectedProgram: string? = nil
	local mScroller: any = nil
	local mRoot: StatefulRoot.StatefulRoot? = nil

	function this:SelectProgram(id: string?)
		mSelectedProgram = id
		if id then
			mUnitInfoView:SetSelectedUnitDefinition(id)
			mUnitInfoView:ClearProgramListSelection()
			local canAfford = LocalPlayerData:GetCredits() >= warez[id]
			;(mRoot :: StatefulRoot.StatefulRoot).setState({
				selectedId = id,
				purchaseVisible = canAfford,
				insufficientVisible = not canAfford,
			})
		else
			(mRoot :: StatefulRoot.StatefulRoot).setState({
				selectedId = StatefulRoot.None,
				purchaseVisible = false,
				insufficientVisible = false,
			})
		end
	end

	function this:PurchaseSelectedProgram()
		local cost = warez[mSelectedProgram :: string]
		if LocalPlayerData:GetCredits() >= cost then
			LocalPlayerData:AddCredits(-cost)
			LocalPlayerData:AddUnit(mSelectedProgram)
			mUnitInfoView:UpdateCount(mSelectedProgram, 1)
			game.ReplicatedStorage.Remotes.PurchaseUnit:FireServer(warezNodeId, mSelectedProgram)
			this.MadePurchase:fire(mSelectedProgram)
		end
	end

	-- Portaled: mGui also holds the imperatively-parented side tray
	mRoot = StatefulRoot.createPortaled(mGui, WarezContent, {
		selectedId = nil,
		purchaseVisible = false,
		insufficientVisible = false,
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
		onMounted = function()
			if mScroller then
				return
			end
			local programList = (mGui:FindFirstChild("MainBox") :: Instance):FindFirstChild("ProgramList") :: Instance
			local content = (programList:FindFirstChild("ContentClip") :: Instance):FindFirstChild("Content") :: Frame
			local scrollbar = ((programList:FindFirstChild("ScrollGutter") :: Instance)
				:FindFirstChild("ScrollbarContainer") :: Instance):FindFirstChild("Scrollbar") :: ImageButton
			mScroller = ScrollingFrame.new(content)
			mScroller:AddScrollbar(scrollbar)
			mScroller:UpdateRender()
		end,
	})

	mUnitInfoView.UnitSelected:connect(function()
		this:SelectProgram(nil)
	end)

	this:SelectProgram(next(warez))

	return this
end

return WarezView
