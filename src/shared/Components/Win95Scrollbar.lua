--!strict
-- Classic Win95-style scrollbar driving a native ScrollingFrame: tiled
-- gutter, up/down arrow buttons, a draggable proportional thumb, and paging
-- when the gutter is clicked. Uses the game's original scrollbar sprite
-- sheet. Anchored to the right edge of its parent, 16px wide.
--
-- Usage: give the ScrollingFrame `ScrollBarThickness = 0` and a ref, leave
-- 16px of content space clear on the right, and render
-- e(Win95Scrollbar, { scrollRef = theRef }) as a sibling.

local UserInputService = game:GetService("UserInputService")

local React = require(game.ReplicatedStorage.Packages.React)

local e = React.createElement

local kGutterImage = "rbxassetid://1372920646"
local kPartsImage = "rbxassetid://1375318214"
local kBarWidth = 16
local kMinThumb = 16

type Props = {
	scrollRef: any,
	lineScroll: number?, -- pixels per arrow click
}

local function Win95Scrollbar(props: Props)
	local thumbRef = React.useRef(nil)
	local trackRef = React.useRef(nil)

	local lineScroll = props.lineScroll or 28
	local function scrollBy(dy: number)
		local scroll = props.scrollRef.current :: ScrollingFrame?
		if scroll then
			-- The engine clamps CanvasPosition for us
			scroll.CanvasPosition = scroll.CanvasPosition + Vector2.new(0, dy)
		end
	end

	React.useEffect(function()
		local scroll = props.scrollRef.current :: ScrollingFrame?
		local thumb = thumbRef.current :: ImageButton?
		local track = trackRef.current :: ImageButton?
		if not scroll or not thumb or not track then
			return nil
		end
		local cns: { RBXScriptConnection } = {}

		local function maxScroll(): number
			return math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
		end

		local function updateThumb()
			local trackH = track.AbsoluteSize.Y
			local contentH = math.max(scroll.AbsoluteCanvasSize.Y, 1)
			local frac = math.clamp(scroll.AbsoluteWindowSize.Y / contentH, 0, 1)
			local thumbH = math.clamp(math.floor(trackH * frac + 0.5), kMinThumb, math.max(trackH, kMinThumb))
			local m = maxScroll()
			local scrollFrac = if m > 0 then math.clamp(scroll.CanvasPosition.Y / m, 0, 1) else 0
			thumb.Size = UDim2.new(1, 0, 0, thumbH)
			thumb.Position = UDim2.new(0, 0, 0, math.floor((trackH - thumbH) * scrollFrac + 0.5))
		end

		table.insert(cns, scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateThumb))
		table.insert(cns, scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateThumb))
		table.insert(cns, scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateThumb))
		table.insert(cns, track:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateThumb))
		updateThumb()

		-- Thumb dragging
		local dragStartY: number? = nil
		local dragStartScroll = 0
		table.insert(cns, thumb.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragStartY = input.Position.Y
				dragStartScroll = scroll.CanvasPosition.Y
			end
		end))
		table.insert(cns, UserInputService.InputChanged:Connect(function(input: InputObject)
			if not dragStartY then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local usable = track.AbsoluteSize.Y - thumb.AbsoluteSize.Y
			if usable <= 0 then
				return
			end
			local delta = input.Position.Y - dragStartY :: number
			local target = dragStartScroll + delta / usable * maxScroll()
			scroll.CanvasPosition = Vector2.new(0, math.clamp(target, 0, maxScroll()))
		end))
		table.insert(cns, UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragStartY = nil
			end
		end))

		-- Clicking the gutter above/below the thumb pages a window at a time
		table.insert(cns, track.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local y = input.Position.Y
			if y >= thumb.AbsolutePosition.Y and y <= thumb.AbsolutePosition.Y + thumb.AbsoluteSize.Y then
				return -- on the thumb: that's a drag, not a page
			end
			local page = scroll.AbsoluteWindowSize.Y
			scrollBy(if y < thumb.AbsolutePosition.Y then -page else page)
		end))

		return function()
			for _, cn in cns do
				cn:Disconnect()
			end
		end
	end, {})

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, kBarWidth, 1, 0),
		BackgroundTransparency = 1,
	}, {
		Gutter = e("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = kGutterImage,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.new(0, 16, 0, 16),
		}),
		UpArrow = e("ImageButton", {
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundTransparency = 1,
			Image = kPartsImage,
			ImageRectOffset = Vector2.new(0, 0),
			ImageRectSize = Vector2.new(16, 16),
			ZIndex = 2,
			[React.Event.MouseButton1Click] = function()
				scrollBy(-lineScroll)
			end,
		}),
		DownArrow = e("ImageButton", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundTransparency = 1,
			Image = kPartsImage,
			ImageRectOffset = Vector2.new(0, 48),
			ImageRectSize = Vector2.new(16, 16),
			ZIndex = 2,
			[React.Event.MouseButton1Click] = function()
				scrollBy(lineScroll)
			end,
		}),
		Track = e("ImageButton", {
			ref = trackRef,
			Position = UDim2.new(0, 0, 0, 16),
			Size = UDim2.new(1, 0, 1, -32),
			BackgroundTransparency = 1,
			Image = "",
			ZIndex = 2,
		}, {
			Thumb = e("ImageButton", {
				ref = thumbRef,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Image = kPartsImage,
				ImageRectOffset = Vector2.new(0, 32),
				ImageRectSize = Vector2.new(16, 16),
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
				ZIndex = 3,
			}),
		}),
	})
end

return Win95Scrollbar
