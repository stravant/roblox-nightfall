local TutorialArrow = {}

function TutorialArrow.new()
	local this = {}

	local mGui = script.TutArrowContainer:Clone()

	local mAnimateCn = nil
	local function mAnimateFunc()
		local f = math.sin(tick()*2)^2
		mGui.Rotate.Arrow.Position = UDim2.new(0.5, 0, 0.5, (f)*10)
	end

	function this:Show(container, angle, position)
		mGui.Position = position
		mGui.Rotate.Rotation = angle
		mGui.Parent = container
		if not mAnimateCn then
			mAnimateCn = game:GetService('RunService').RenderStepped:connect(mAnimateFunc)
		end
	end

	function this:Hide()
		mGui.Parent = nil
		if mAnimateCn then
			mAnimateCn:disconnect()
			mAnimateCn = nil
		end
	end

	function this:Destroy()
		this:Hide()
	end

	return this
end

return TutorialArrow
