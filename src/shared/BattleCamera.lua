--!strict
-- Camera controller for the 3D databattle view. Straight top-down (screen-up
-- is world -Z, NOT isometric), zoom = camera height driven by scroll wheel /
-- pinch, pan by dragging (mouse or touch) with tap-vs-drag disambiguated by a
-- small movement threshold. Fires Tapped with the world-space point on the
-- board plane. Input that UIs already handled (gameProcessedEvent) is
-- ignored, so clicks on the floating windows never reach the board.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Signal = require(game.ReplicatedStorage.Signal)

local kBindName = "BattleCameraBind"
local kFieldOfView = 20
local kDragThresholdPx = 14

export type Config = {
	surfaceY: number, -- world Y of the board surface
	center: Vector2, -- board center in world XZ
	panExtents: Vector2, -- how far the focus point may wander from center (XZ)
	minHeight: number,
	maxHeight: number,
}

local BattleCamera = {}

function BattleCamera.new(config: Config)
	local this = {}

	this.Tapped = Signal.new() -- (worldHitPoint: Vector3)

	local mCamera = workspace.CurrentCamera
	local mSavedFieldOfView = mCamera.FieldOfView
	local mSavedCameraType = mCamera.CameraType

	local mHeight = config.maxHeight
	local mFocus = Vector2.new(config.center.X, config.center.Y)
	local mConnections: { RBXScriptConnection } = {}

	local function applyCamera()
		local eye = Vector3.new(mFocus.X, config.surfaceY + mHeight, mFocus.Y)
		local target = Vector3.new(mFocus.X, config.surfaceY, mFocus.Y)
		mCamera.CFrame = CFrame.lookAt(eye, target, Vector3.new(0, 0, -1))
		mCamera.Focus = CFrame.new(target)
	end

	local function setFocus(focus: Vector2)
		mFocus = Vector2.new(
			math.clamp(focus.X, config.center.X - config.panExtents.X, config.center.X + config.panExtents.X),
			math.clamp(focus.Y, config.center.Y - config.panExtents.Y, config.center.Y + config.panExtents.Y))
	end

	local function setHeight(height: number)
		mHeight = math.clamp(height, config.minHeight, config.maxHeight)
	end

	-- GuiInset note: InputObject.Position is in GUI ("screen") space, which
	-- excludes the top inset -> pair it with ScreenPointToRay. GetMouseLocation
	-- is in viewport space (inset included) -> pair it with ViewportPointToRay.
	-- Mixing these up offsets every hit by the inset height.

	local function rayHit(unitRay: Ray): Vector3
		local scale = (config.surfaceY - unitRay.Origin.Y) / unitRay.Direction.Y
		return unitRay.Origin + unitRay.Direction * scale
	end

	-- Where an InputObject.Position lands on the board plane, in world space
	local function screenHit(screenPos: Vector2): Vector3
		return rayHit(mCamera:ScreenPointToRay(screenPos.X, screenPos.Y))
	end

	local function mouseHit(): Vector3
		local mouseAt = UserInputService:GetMouseLocation()
		return rayHit(mCamera:ViewportPointToRay(mouseAt.X, mouseAt.Y))
	end

	-- Drag state. The drag is OWNED by the input object (touch) that started
	-- it: a second concurrent touch (the start of a pinch) must not restart
	-- the gesture with its own anchor, or the first finger's next move pans
	-- the camera by the distance between the two fingers in one frame.
	local mDown = false
	local mDownInput: InputObject? = nil
	local mDownScreenPos = Vector2.new()
	local mDragging = false
	local mDragStartHit = Vector3.new()
	local mPinching = false
	local mPinchStartHeight = mHeight

	-- Optional gesture claim: called with (worldHit, screenPos) on press; if
	-- it returns true the camera ignores the whole gesture (no pan, no tap) —
	-- used so dragging a unit off an upload zone doesn't pan the board
	local mPressCapture = nil
	function this:SetPressCapture(fn)
		mPressCapture = fn
	end

	table.insert(mConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if mDown or mPinching then
				return -- extra touch during a gesture: never restart the drag
			end
			local screenPos = Vector2.new(input.Position.X, input.Position.Y)
			local hit = screenHit(screenPos)
			if mPressCapture and mPressCapture(hit, screenPos) then
				return -- gesture claimed; mDown stays false
			end
			mDown = true
			mDownInput = input
			mDragging = false
			mDownScreenPos = screenPos
			mDragStartHit = hit
		end
	end))

	table.insert(mConnections, UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if not gameProcessed then
				setHeight(mHeight * (1 - input.Position.Z * 0.15))
				applyCamera()
			end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if not mDown or mPinching then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and input ~= mDownInput then
			return -- some other finger: only the owning touch drives the pan
		end
		local screenPos = Vector2.new(input.Position.X, input.Position.Y)
		if not mDragging then
			if (screenPos - mDownScreenPos).Magnitude < kDragThresholdPx then
				return
			end
			mDragging = true
		end
		-- Keep the world point that was grabbed under the cursor
		local hitNow = screenHit(screenPos)
		local delta = mDragStartHit - hitNow
		setFocus(mFocus + Vector2.new(delta.X, delta.Z))
		applyCamera()
	end))

	table.insert(mConnections, UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if input.UserInputType == Enum.UserInputType.Touch and input ~= mDownInput then
				return -- a non-owning finger lifting doesn't end the gesture
			end
			if mDown and not mDragging and not mPinching then
				this.Tapped:fire(screenHit(Vector2.new(input.Position.X, input.Position.Y)))
			end
			mDown = false
			mDownInput = nil
			mDragging = false
		end
	end))

	table.insert(mConnections, UserInputService.TouchPinch:Connect(function(_touchPositions, scale, _velocity, state, gameProcessed)
		if gameProcessed and state == Enum.UserInputState.Begin then
			return
		end
		if state == Enum.UserInputState.Begin then
			mPinching = true
			mPinchStartHeight = mHeight
			-- Cancel any in-progress pan outright: resuming it after the
			-- pinch would yank the camera to a stale pre-pinch anchor
			mDown = false
			mDownInput = nil
			mDragging = false
		elseif state == Enum.UserInputState.Change then
			if mPinching then
				setHeight(mPinchStartHeight / scale)
				applyCamera()
			end
		else
			mPinching = false
		end
	end))

	function this:FocusOn(worldPos: Vector3)
		setFocus(Vector2.new(worldPos.X, worldPos.Z))
		applyCamera()
	end

	-- Shift the focus by a world-space delta (clamped to the pan extents
	-- like any other pan). Used for edge-panning during placement drags.
	function this:PanBy(deltaX: number, deltaZ: number)
		setFocus(mFocus + Vector2.new(deltaX, deltaZ))
		applyCamera()
	end

	function this:GetMouseHit(): Vector3
		return mouseHit()
	end

	-- For positions sourced from InputObject.Position (GUI/screen space)
	function this:HitAtScreen(screenPos: Vector2): Vector3
		return screenHit(screenPos)
	end

	function this:Install()
		mSavedFieldOfView = mCamera.FieldOfView
		mSavedCameraType = mCamera.CameraType
		if mSavedCameraType == Enum.CameraType.Scriptable then
			-- Never restore to Scriptable: a session that died mid-battle
			-- (e.g. an erroring test run in the edit place) leaves the camera
			-- Scriptable, and faithfully restoring that would wedge it forever
			mSavedCameraType = Enum.CameraType.Custom
		end
		mCamera.CameraType = Enum.CameraType.Scriptable
		mCamera.FieldOfView = kFieldOfView
		applyCamera()
		-- Re-apply every frame so nothing else (e.g. the netmap camera during
		-- handover) can fight the battle view for the camera
		RunService:BindToRenderStep(kBindName, Enum.RenderPriority.Camera.Value - 1, applyCamera)
	end

	function this:Uninstall()
		RunService:UnbindFromRenderStep(kBindName)
		mCamera.FieldOfView = mSavedFieldOfView
		mCamera.CameraType = mSavedCameraType
	end

	local mDestroyed = false
	function this:Destroy()
		if mDestroyed then
			return
		end
		mDestroyed = true
		this:Uninstall()
		for _, cn in mConnections do
			cn:Disconnect()
		end
	end

	return this
end

return BattleCamera
