--!strict
-- Code-built versions of the 32x32 tile/overlay templates that used to live
-- as children of the GameView / UnitsView / FlashySquareView ModuleScripts
-- (property values from ui-reference/ModuleTemplates/*.json). These are
-- consumed by the imperative TileView/UnitsView machinery, which positions
-- and destroys them per game event — React adds nothing at this layer.

local TileTemplates = {}

local function makeTile(image: string, zIndex: number?): ImageLabel
	local tile = Instance.new("ImageLabel")
	tile.BackgroundTransparency = 1
	tile.BorderSizePixel = 0
	tile.Size = UDim2.new(0, 32, 0, 32)
	tile.Image = image
	if zIndex then
		tile.ZIndex = zIndex
	end
	return tile
end

function TileTemplates.MapTile(): ImageLabel
	return makeTile("rbxassetid://1333754686")
end

function TileTemplates.UploadOverlay(): ImageLabel
	return makeTile("rbxassetid://1333805802")
end

function TileTemplates.MoveOverlaySimple(): ImageLabel
	return makeTile("rbxassetid://1335091372")
end

function TileTemplates.MoveOverlayDirect(): ImageLabel
	return makeTile("rbxassetid://1335092647")
end

function TileTemplates.AttackDamage(): ImageLabel
	return makeTile("rbxassetid://1335928206")
end

function TileTemplates.AttackModify(): ImageLabel
	return makeTile("rbxassetid://1335928391")
end

function TileTemplates.AttackZeroOne(): ImageLabel
	return makeTile("rbxassetid://1335928533")
end

function TileTemplates.PickupCodes(): ImageLabel
	return makeTile("rbxassetid://1346714452")
end

function TileTemplates.PickupCredits(): ImageLabel
	return makeTile("rbxassetid://1346715274")
end

function TileTemplates.UnitSector(): ImageLabel
	return makeTile("rbxassetid://1335176664")
end

function TileTemplates.UnitJoinerVertical(): ImageLabel
	return makeTile("rbxassetid://1335178024", 2)
end

function TileTemplates.UnitJoinerHorizontal(): ImageLabel
	return makeTile("rbxassetid://1335178413", 2)
end

function TileTemplates.DoneMarker(): ImageLabel
	local marker = makeTile("rbxassetid://1335986152", 3)
	marker.Name = "DoneMarker"
	marker.AnchorPoint = Vector2.new(0, 1)
	marker.Position = UDim2.new(0.5, 0, 0.5, 0)
	return marker
end

function TileTemplates.FlashOverlay(): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "FlashOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.new(0, 32, 0, 32)
	local sprite = Instance.new("ImageLabel")
	sprite.Name = "Sprite"
	sprite.AnchorPoint = Vector2.new(0.5, 0.5)
	sprite.Position = UDim2.new(0.5, 0, 0.5, 0)
	sprite.Size = UDim2.new(0, 352, 0, 352)
	sprite.BackgroundTransparency = 1
	sprite.BorderSizePixel = 0
	sprite.Image = "rbxassetid://1333910837"
	sprite.Parent = overlay
	local scale = Instance.new("UIScale")
	scale.Parent = sprite
	return overlay
end

-- The animated "+N" credit pickup indicator (PickupCredits with Amount label)
function TileTemplates.PickupCreditsWithAmount(): ImageLabel
	local pickup = TileTemplates.PickupCredits()
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.AnchorPoint = Vector2.new(0.5, 0.5)
	amount.Position = UDim2.new(0.5, 0, 0.5, -20)
	amount.Size = UDim2.new(0, 200, 0, 50)
	amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.Code
	amount.TextSize = 16
	amount.TextColor3 = Color3.new(0.0470588, 1, 0)
	amount.TextStrokeTransparency = 0
	amount.Parent = pickup
	return pickup
end

return TileTemplates
