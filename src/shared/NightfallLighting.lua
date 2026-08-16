--!strict
-- Nightfall's visual state: while Dignity's Nightfall script is live (see
-- LocalPlayerData:IsNightfallActive) the net goes dark — the sun-driven
-- place lighting dims to a moonlit remnant and the self-lit elements
-- (neon node glow, link beams, popups) carry the netmap.

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Captured before any dimming so deactivation restores the place's
-- authored lighting exactly
local kNormal = {
	Brightness = Lighting.Brightness,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ColorShift_Top = Lighting.ColorShift_Top,
}

-- The place lights with a plain Brightness-4 sun and black ambients: keep
-- just enough cold light to silhouette the node geometry
local kDimmed = {
	Brightness = 0.35,
	OutdoorAmbient = Color3.fromRGB(14, 18, 38),
	ColorShift_Top = Color3.fromRGB(40, 55, 110),
}

-- "Three, Two, One, nightfall!" — darkness falls slowly for drama; the
-- restore is a bit quicker
local kBeginTweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local kEndTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local NightfallLighting = {}

local mActive = false
local mTween: Tween? = nil

-- instant skips the transition (applying the persisted state on login)
function NightfallLighting:SetActive(active: boolean, instant: boolean?)
	if active == mActive then
		return
	end
	mActive = active
	if mTween then
		mTween:Cancel()
		mTween = nil
	end
	local target = if active then kDimmed else kNormal
	if instant then
		for property, value in pairs(target) do
			(Lighting :: any)[property] = value
		end
	else
		mTween = TweenService:Create(
			Lighting,
			if active then kBeginTweenInfo else kEndTweenInfo,
			target
		)
		mTween:Play()
	end
end

function NightfallLighting:IsActive(): boolean
	return mActive
end

return NightfallLighting
