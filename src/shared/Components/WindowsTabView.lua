--!strict
-- React version of the Windows-98-style tab view (see WindowsTabView.lua for
-- the imperative original, which survives until its last template consumer is
-- converted). Renders the TabPanel window inset containing a TabStrip of tab
-- buttons and a Tabs frame with one content frame per tab; only the selected
-- tab's content frame is visible. Selected tabs use the raised image rect
-- (22, 0) at ZIndex 2, unselected use (44, 0) at ZIndex 1, matching the
-- imperative module's behavior (layout matches the TabPanel trees in
-- ui-reference/ModuleTemplates/MainMenuView.json and NodeInfoView.json).

local React = require(game.ReplicatedStorage.Packages.React)

local e = React.createElement

local kTabImage = "rbxassetid://1396391045"
local kTabRectSelected = Vector2.new(22, 0)
local kTabRectUnselected = Vector2.new(44, 0)

export type TabEntry = {
	Name: string,
	Label: string,
	Content: { [string]: any },
}

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	ZIndex: number?,
	Tabs: { TabEntry },
	DefaultTab: string,
}

local function WindowsTabView(props: Props)
	local selected, setSelected = React.useState(props.DefaultTab)

	local tabButtons: { [string]: any } = {}
	local tabContents: { [string]: any } = {}
	for index, tab in props.Tabs do
		local isSelected = tab.Name == selected
		tabButtons[tab.Name] = e("ImageButton", {
			Position = UDim2.new(0, (index - 1) * 100, 0, 0),
			Size = UDim2.new(0, 104, 0, 36),
			BackgroundTransparency = 1,
			Selectable = false,
			Image = kTabImage,
			ImageRectOffset = if isSelected then kTabRectSelected else kTabRectUnselected,
			ImageRectSize = Vector2.new(22, 22),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(8, 8, 8, 8),
			ZIndex = if isSelected then 2 else 1,
			[React.Event.MouseButton1Click] = function()
				setSelected(tab.Name)
			end,
		}, {
			Text = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -1),
				Size = UDim2.new(1, -20, 0, 24),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				TextSize = 18,
				TextColor3 = Color3.new(0, 0, 0),
				Text = tab.Label,
			}),
		})
		tabContents[tab.Name] = e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Visible = isSelected,
		}, tab.Content)
	end

	return e("ImageLabel", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
		Image = kTabImage,
		ImageRectSize = Vector2.new(22, 22),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(8, 8, 8, 8),
	}, {
		-- The strip anchors to its own bottom 2px inside the panel top, so
		-- the tab buttons stick up above the panel edge.
		TabStrip = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 0, 2),
			Size = UDim2.new(1, -4, 0, 36),
			BackgroundTransparency = 1,
		}, tabButtons),
		Tabs = e("Frame", {
			Position = UDim2.new(0, 3, 0, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
		}, tabContents),
	})
end

return WindowsTabView
