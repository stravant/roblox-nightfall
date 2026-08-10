--!strict
-- React version of the Windows-98-style slider (see WindowsSlider.lua for the
-- imperative original, which survives until its last template consumer is
-- converted). Controlled component: the knob position renders from
-- props.Value (-1..1) and dragging the slider area calls props.OnChanged with
-- the new value; the owner is responsible for feeding the value back in
-- (layout matches the SoundVolume/MusicVolume trees in
-- ui-reference/ModuleTemplates/MainMenuView.json).
--
-- Note: the template named both end labels "Label"; React children need
-- unique names, so they mount as LeftLabel/RightLabel (no code addressed
-- them by path).

local UserInputService = game:GetService("UserInputService")
local React = require(game.ReplicatedStorage.Packages.React)

local e = React.createElement

local kSliderImage = "rbxassetid://1384578857"

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	Visible: boolean?,
	ZIndex: number?,
	LayoutOrder: number?,
	Value: number,
	LeftLabel: string?,
	RightLabel: string?,
	OnChanged: ((value: number) -> ())?,
}

local function endLabel(text: string, anchorX: number, alignment: Enum.TextXAlignment)
	return e("TextLabel", {
		AnchorPoint = Vector2.new(anchorX, 1),
		Position = UDim2.new(anchorX, 0, 1, 0),
		Size = UDim2.new(0, 200, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		TextSize = 14,
		TextColor3 = Color3.new(0, 0, 0),
		TextXAlignment = alignment,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = text,
	})
end

local function WindowsSlider(props: Props)
	local frameRef = React.useRef(nil :: Frame?)
	local touchDragging = React.useRef(false)

	-- Same mapping as the imperative original: pixel x across the slider
	-- frame -> value in [-1, 1] (with 1.1 overshoot so the extremes are
	-- reachable without pixel-perfect aim).
	local function handleInput(xPixel: number)
		local frame = frameRef.current
		if not frame then
			return
		end
		local x = xPixel - frame.AbsolutePosition.X
		x = x / frame.AbsoluteSize.X
		x = x * 2 - 1
		x = x * 1.1
		if x > 1 then
			x = 1
		end
		if x < -1 then
			x = -1
		end
		if props.OnChanged then
			props.OnChanged(x)
		end
	end

	return e("Frame", {
		ref = frameRef,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		SliderArea = e("ImageButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = "",
			[React.Event.InputBegan] = function(_rbx, input: InputObject)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					touchDragging.current = true
					handleInput(input.Position.X)
				end
			end,
			[React.Event.InputChanged] = function(_rbx, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					-- Matches the imperative original: mouse movement only
					-- drags while the button is held down.
					if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
						handleInput(input.Position.X)
					end
				elseif input.UserInputType == Enum.UserInputType.Touch and touchDragging.current then
					handleInput(input.Position.X)
				end
			end,
			[React.Event.InputEnded] = function(_rbx, input: InputObject)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					touchDragging.current = false
				end
			end,
		}, {
			Gutter = e("ImageButton", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundTransparency = 1,
				Image = kSliderImage,
				ImageRectOffset = Vector2.new(32, 14),
				ImageRectSize = Vector2.new(8, 4),
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(4, 2, 4, 2),
			}),
			Slider = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new((props.Value / 1.1 + 1) / 2, 0, 0.5, 0),
				Size = UDim2.new(0, 32, 0, 32),
				ZIndex = 2,
				Active = true,
				BackgroundTransparency = 1,
				Image = kSliderImage,
				ImageRectSize = Vector2.new(32, 32),
			}),
			LeftLabel = endLabel(props.LeftLabel or "", 0, Enum.TextXAlignment.Left),
			RightLabel = endLabel(props.RightLabel or "", 1, Enum.TextXAlignment.Right),
		}),
	})
end

return WindowsSlider
