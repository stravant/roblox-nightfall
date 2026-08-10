--!strict
-- React version of the Windows-98-style button (see WindowsButton.lua for the
-- imperative original, which survives until its last template consumer is
-- converted). Renders an ImageButton with the classic normal/hover/pressed
-- images, and an optional centered "Text" label child.

local React = require(game.ReplicatedStorage.Packages.React)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)

local e = React.createElement

local kImageNormal = "rbxassetid://1372686003"
local kImageHover = "rbxassetid://1372686004"
local kImagePressed = "rbxassetid://1372686005"

export type Props = {
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	Visible: boolean?,
	ZIndex: number?,
	LayoutOrder: number?,
	Text: string?,
	TextSize: number?,
	OnClick: (() -> ())?,
	children: any?,
}

local function WindowsButton(props: Props)
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)

	local image = kImageNormal
	if pressed then
		image = kImagePressed
	elseif hovered and not DeviceInfo.Touch then
		image = kImageHover
	end

	local children: { [string]: any } = {}
	if props.Text ~= nil then
		children.Text = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -1),
			Size = UDim2.new(1, -20, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			TextSize = props.TextSize or 18,
			TextColor3 = Color3.new(0, 0, 0),
			Text = props.Text,
		})
	end
	if props.children ~= nil then
		for key, child in props.children :: { [string]: any } do
			children[key] = child
		end
	end

	return e("ImageButton", {
		Name = props.Name,
		Image = image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(8, 8, 8, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 2,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
	}, children)
end

return WindowsButton
