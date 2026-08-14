--!strict
-- React conversion of TutorialArrowView. Public API is unchanged from the
-- template version: TutorialArrow.new() returns a view with
-- Show(container, angle, position), Hide(), and Destroy(). The host frame
-- ("TutArrowContainer") is created imperatively and reparented by Show/Hide;
-- its contents (the Rotate frame + Arrow image) are rendered by React
-- (layout matches ui-reference/ModuleTemplates/TutorialArrowView.json).
--
-- The bobbing animation is deliberately NOT React state: driving a per-frame
-- Position through setState would re-render every frame for no benefit.
-- Instead the Arrow instance is looked up under the host lazily (the mount
-- may not have flushed yet under the test mock scheduler) and its Position is
-- updated imperatively from RenderStepped, exactly like the original code.
-- React never fights the imperative writes because the Arrow element's
-- Position prop is the animation's baseline value and never changes between
-- renders, so the reconciler never re-applies it.

local RunService = game:GetService("RunService")

local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)

local e = React.createElement

local kArrowImage = "rbxassetid://1354410067"

type ArrowState = {
	rotation: number,
}

local function TutorialArrowContent(props: ArrowState)
	return e(React.Fragment, nil, {
		Rotate = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 100, 0, 100),
			BackgroundTransparency = 1,
			Rotation = props.rotation,
		}, {
			Arrow = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				-- Baseline of the imperative bob animation (see module comment)
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 48, 0, 48),
				BackgroundTransparency = 1,
				Image = kArrowImage,
			}),
		}),
	})
end

local TutorialArrow = {}

function TutorialArrow.new()
	local this = {}

	-- The container can be destroyed out from under us: Show may parent it
	-- into React-rendered UI (e.g. the topbar Start button), and a re-render
	-- that unmounts that host destroys the container with it. createGui is
	-- called again to rebuild when Show finds the old container dead.
	local mGui: Frame
	local mRoot: StatefulRoot.StatefulRoot
	local mArrow: ImageLabel? = nil
	local function createGui()
		mGui = Instance.new("Frame")
		mGui.Name = "TutArrowContainer"
		mGui.AnchorPoint = Vector2.new(0.5, 0.5)
		mGui.Size = UDim2.new(0, 100, 0, 100)
		mGui.BackgroundTransparency = 1
		mRoot = StatefulRoot.create(mGui, TutorialArrowContent, {
			rotation = 0,
		})
		mArrow = nil
	end
	createGui()

	local mAnimateCn: RBXScriptConnection? = nil
	local function mAnimateFunc()
		if not mArrow then
			local rotate = mGui:FindFirstChild("Rotate")
			mArrow = if rotate then rotate:FindFirstChild("Arrow") :: ImageLabel? else nil
			if not mArrow then
				return
			end
		end
		local f = math.sin(tick() * 2) ^ 2
		mArrow.Position = UDim2.new(0.5, 0, 0.5, f * 10)
	end

	function this:Show(container: Instance, angle: number, position: UDim2)
		if not pcall(function()
			mGui.Parent = container
		end) then
			-- Old container was destroyed (Parent locked): rebuild it
			mRoot.unmount()
			createGui()
			mGui.Parent = container
		end
		mGui.Position = position
		mRoot.setState({ rotation = angle })
		if not mAnimateCn then
			mAnimateCn = RunService.RenderStepped:Connect(mAnimateFunc)
		end
	end

	function this:Hide()
		pcall(function()
			mGui.Parent = nil
		end)
		if mAnimateCn then
			mAnimateCn:Disconnect()
			mAnimateCn = nil
		end
	end

	local mDestroyed = false
	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		this:Hide()
		mRoot.unmount()
		mGui:Destroy()
	end

	return this
end

return TutorialArrow
