--!strict
-- The 3D databattle board. Hosts the existing 2D board GUI (512x384, 32px
-- tiles) on a SurfaceGui atop a flat part floating far above the netmap
-- scene, with a background image plane a bit below for parallax. All the
-- per-tile rendering machinery (TileView / UnitsView / FlashySquareView)
-- renders into GetBoardContainer() unchanged; this module owns the world
-- geometry, the camera, and tap -> grid-coordinate mapping.
--
-- Orientation note (empirically verified): a Top-face SurfaceGui's canvas X+
-- runs along the part's local -Z and canvas Y+ along local +X. With the part
-- rotated -90 degrees about Y (local Size 48x1x64), canvas X+ = world +X and
-- canvas Y+ = world +Z, so the board GUI renders upright under the
-- straight-down camera (screen-up = world -Z).

local Places = require(game.ReplicatedStorage.Places)
local Signal = require(game.ReplicatedStorage.Signal)
local BattleCamera = require(game.ReplicatedStorage.BattleCamera)

local kTileStuds = 4
local kTilePx = 32
local kPixelsPerStud = 24 -- 96 px/tile on the canvas: crisp when zoomed in
local kSurfaceY = 500.5
local kCenter = Vector3.new(0, 500, 0)
local kBackgroundDrop = 30 -- background plane distance below the board

local BattleBoard3D = {}

function BattleBoard3D.new(backgroundImage: string)
	local this = {}

	this.Tapped = Signal.new() -- (gridX: number, gridY: number)

	local boardStudsX = Places.PlaceWidth * kTileStuds -- world X extent
	local boardStudsZ = Places.PlaceHeight * kTileStuds -- world Z extent

	local mRoot = Instance.new("Folder")
	mRoot.Name = "BattleBoard3D"

	-- Background plane (oversized for pan slack; slight parallax vs board)
	local mBackground = Instance.new("Part")
	mBackground.Name = "Background"
	mBackground.Anchored = true
	mBackground.CanCollide = false
	mBackground.CanQuery = false
	mBackground.CastShadow = false
	mBackground.Color = Color3.new(0, 0, 0)
	mBackground.Material = Enum.Material.SmoothPlastic
	mBackground.Size = Vector3.new(boardStudsZ * 4, 1, boardStudsX * 4)
	mBackground.CFrame = CFrame.new(kCenter - Vector3.new(0, kBackgroundDrop, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
	mBackground.Parent = mRoot
	local backgroundGui = Instance.new("SurfaceGui")
	backgroundGui.Face = Enum.NormalId.Top
	backgroundGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	backgroundGui.PixelsPerStud = 4
	backgroundGui.LightInfluence = 0
	backgroundGui.Parent = mBackground
	local mBackgroundImage = Instance.new("ImageLabel")
	mBackgroundImage.Size = UDim2.new(1, 0, 1, 0)
	mBackgroundImage.BackgroundColor3 = Color3.new(0, 0, 0)
	mBackgroundImage.BorderSizePixel = 0
	mBackgroundImage.Image = backgroundImage
	mBackgroundImage.Parent = backgroundGui

	-- The board part itself
	local mBoard = Instance.new("Part")
	mBoard.Name = "Board"
	mBoard.Anchored = true
	mBoard.CanCollide = false
	mBoard.CanQuery = false
	mBoard.CastShadow = false
	mBoard.Transparency = 1
	mBoard.Size = Vector3.new(boardStudsZ, 1, boardStudsX)
	mBoard.CFrame = CFrame.new(kCenter) * CFrame.Angles(0, -math.pi / 2, 0)
	mBoard.Parent = mRoot

	local mSurfaceGui = Instance.new("SurfaceGui")
	mSurfaceGui.Face = Enum.NormalId.Top
	mSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	mSurfaceGui.PixelsPerStud = kPixelsPerStud
	mSurfaceGui.LightInfluence = 0
	mSurfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mSurfaceGui.Parent = mBoard

	local scale = Instance.new("UIScale")
	scale.Scale = kPixelsPerStud * kTileStuds / kTilePx
	scale.Parent = mSurfaceGui

	local mBoardContainer = Instance.new("Frame")
	mBoardContainer.Name = "BoardRoot"
	mBoardContainer.Size = UDim2.new(0, Places.PlaceWidth * kTilePx, 0, Places.PlaceHeight * kTilePx)
	mBoardContainer.BackgroundTransparency = 1
	mBoardContainer.Parent = mSurfaceGui

	mRoot.Parent = workspace

	-- Camera
	local mCamera = BattleCamera.new({
		surfaceY = kSurfaceY,
		center = Vector2.new(kCenter.X, kCenter.Z),
		panExtents = Vector2.new(boardStudsX / 2, boardStudsZ / 2),
		minHeight = 25,
		maxHeight = 160,
	})

	mCamera.Tapped:connect(function(worldHit: Vector3)
		local gridX = math.floor((worldHit.X - (kCenter.X - boardStudsX / 2)) / kTileStuds) + 1
		local gridY = math.floor((worldHit.Z - (kCenter.Z - boardStudsZ / 2)) / kTileStuds) + 1
		if gridX >= 1 and gridX <= Places.PlaceWidth and gridY >= 1 and gridY <= Places.PlaceHeight then
			this.Tapped:fire(gridX, gridY)
		end
	end)

	function this:GetBoardContainer(): Frame
		return mBoardContainer
	end

	function this:GetBackgroundImage(): string
		return mBackgroundImage.Image
	end

	function this:Install()
		mCamera:Install()
	end

	function this:Uninstall()
		mCamera:Uninstall()
	end

	local mDestroyed = false
	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		mCamera:Destroy()
		mRoot:Destroy()
	end

	return this
end

return BattleBoard3D
