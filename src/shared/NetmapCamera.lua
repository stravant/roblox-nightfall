local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Signal = require(game.ReplicatedStorage.Signal)
local ModalManager = require(game.ReplicatedStorage.ModalManager)
local JourneyRecorder = require(game.ReplicatedStorage.JourneyRecorder)

local NetmapCamera = {}

local BIND_NAME = "NetmapCameraBind"
-- Dead zone: presses that move less than this stay clicks (no pan)
local DRAG_THRESHOLD_PX = 14

-- A moderately wide FOV keeps the camera CLOSE to the map: the old FOV-10
-- telephoto look needed 200-500 studs of distance, far enough that low-end
-- devices culled netmap geometry when zoomed out. The zoom range scales by
-- tan(5)/tan(15) to preserve the same on-screen framing.
local kFieldOfView = 30
local kDefaultZoom = 98 -- was 300 at FOV 10
local MIN_ZOOM = 65 -- was 200
local MAX_ZOOM = 163 -- was 500
-- Wheel studs per notch, scaled with the zoom range (was 80)
local kWheelZoomStep = 26

function NetmapCamera.new()
	local this = {}
	
	this.Clicked = Signal.new()
	-- The USER moved the camera (pan finished / zoom settled): consumers
	-- persist the position from this
	this.Changed = Signal.new()
	
local mCamera = workspace.CurrentCamera
	mCamera.CameraType = Enum.CameraType.Scriptable
	mCamera.FieldOfView = kFieldOfView

	local mZoomLevel = kDefaultZoom
	
	local mCurrentPosition = Vector3.new()
	local LAST_POSITION_COUNT = 30
	local mLastPositions = {}
	for i = 1, LAST_POSITION_COUNT do
		mLastPositions[i] = {tick() - i * 1/60, mCurrentPosition}
	end
	
	local function computeExtraVelocity()
		local firstFewZeroVelocity = true
		for i = LAST_POSITION_COUNT - 4, LAST_POSITION_COUNT - 1 do
			if mLastPositions[i + 1][2] ~= mLastPositions[i][2] then
				firstFewZeroVelocity = false
				break
			end
		end
		if firstFewZeroVelocity then
			return Vector3.new()
		end
		local mTotalVelocity = Vector3.new()
		local mTotalVelocityCount = 0
		for i = LAST_POSITION_COUNT - 20, LAST_POSITION_COUNT - 1 do
			local newPos = mLastPositions[i + 1]
			local lastPos = mLastPositions[i]
			local velocity = (newPos[2] - lastPos[2]) / (newPos[1] - lastPos[1])
			local weight = 1 - (((LAST_POSITION_COUNT - 1) - i) / 22)^0.25
			mTotalVelocity += velocity * weight
			mTotalVelocityCount += weight
		end
		return mTotalVelocity / mTotalVelocityCount
	end
	
	local function applyCamera()
		mCamera.Focus = CFrame.new(mCurrentPosition)
		mCamera.CFrame = CFrame.new(mCurrentPosition) * CFrame.Angles(0, math.pi/4, 0) * CFrame.Angles(-math.pi/4 + 0.25, 0, 0) * CFrame.new(0, 0, mZoomLevel)
	end

	local function setPosition(vec)
		local BOTTOM_EDGE = 60
		local TOP_EDGE = -140
		local LEFT_EDGE = -60
		local RIGHT_EDGE = 550
		local vertical = vec.X + vec.Z
		local horizontal = vec.X - vec.Z
		if vertical > BOTTOM_EDGE then
			local extra = vertical - BOTTOM_EDGE
			vec = Vector3.new(vec.X - 0.5 * extra, vec.Y, vec.Z - 0.5 * extra)
		end
		if vertical < TOP_EDGE then
			local extra = TOP_EDGE - vertical
			vec = Vector3.new(vec.X + 0.5 * extra, vec.Y, vec.Z + 0.5 * extra)
		end
		if horizontal < LEFT_EDGE then
			local extra = LEFT_EDGE - horizontal
			vec = Vector3.new(vec.X + 0.5 * extra, vec.Y, vec.Z - 0.5 * extra)
		end
		if horizontal > RIGHT_EDGE then
			local extra = horizontal - RIGHT_EDGE
			vec = Vector3.new(vec.X - 0.5 * extra, vec.Y, vec.Z + 0.5 * extra)
		end	
		
		mCurrentPosition = vec
		applyCamera()
	end
	
	setPosition(mCurrentPosition)

	-- The camera only reacts to input while installed: its connections are
	-- global, and un-gated they would silently pan the hidden netmap camera
	-- during databattles (whose board drags share the same input events).
	-- MUST be declared before every closure that references it: handleWheel
	-- captured a global nil here once, silently killing scroll zoom.
	local mInstalled = false

	-- Journey: one zoom event per burst of wheel/pinch zooming (a second of
	-- quiet after the first change), with the level it settled at
	local mZoomRecordPending = false
	local function recordZoomSettled()
		if mZoomRecordPending then
			return
		end
		mZoomRecordPending = true
		task.delay(1, function()
			mZoomRecordPending = false
			JourneyRecorder:Record("NetmapZoom", tostring(math.floor(mZoomLevel)))
			this.Changed:fire()
		end)
	end

	local function handleWheel(delta)
		if not mInstalled or ModalManager:IsModal() then
			return
		end
		mZoomLevel -= delta * kWheelZoomStep
		mZoomLevel = math.clamp(mZoomLevel, MIN_ZOOM, MAX_ZOOM)
		setPosition(mCurrentPosition)
		recordZoomSettled()
	end
	
	local function getUnitRay()
		local mouseAt = UserInputService:GetMouseLocation()
		return mCamera:ViewportPointToRay(mouseAt.X, mouseAt.Y)
	end
	
	local function rayHit(unitRay)
		local scale = -unitRay.Origin.Y / unitRay.Direction.Y
		return unitRay.Origin + unitRay.Direction * scale
	end

	local function getMouseHit()
		return rayHit(getUnitRay())
	end

	-- For a touch, use ITS OWN reported position (gui space -> ScreenPointToRay):
	-- GetMouseLocation reflects whichever finger last moved, so with two fingers
	-- down it alternates between them and the pan anchor jumps by the finger
	-- separation. The mouse keeps the GetMouseLocation path.
	local function getInputHit(inputObject: InputObject?)
		if inputObject and inputObject.UserInputType == Enum.UserInputType.Touch then
			return rayHit(mCamera:ScreenPointToRay(inputObject.Position.X, inputObject.Position.Y))
		else
			return getMouseHit()
		end
	end

	local function getInputScreenPos(inputObject: InputObject?): Vector2
		if inputObject and inputObject.UserInputType == Enum.UserInputType.Touch then
			return Vector2.new(inputObject.Position.X, inputObject.Position.Y)
		else
			return UserInputService:GetMouseLocation()
		end
	end

	local mPanStartHit = nil
	-- The touch that owns the current gesture: a second concurrent finger (the
	-- start of a pinch) must not restart or drive the pan
	local mDownInput: InputObject? = nil
	local mDownScreenPos = Vector2.new()
	local mDidPan = false
	local mIsPanning = false
	local mPinching = false
	local mPinchStartZoom = mZoomLevel
	local mInertialVelocity = Vector3.new()
	-- In-flight FocusOn glide ({Start, Target, T, Duration}); cancelled by any
	-- user pan/pinch
	local mFocusTween = nil
	local mPanStartPosition = Vector3.new()
	local function button1Down(inputObject: InputObject?)
		if not mInstalled or ModalManager:IsModal() or mPinching then
			return
		end
		if mIsPanning then
			return -- extra touch during a gesture: never restart the pan
		end
		mFocusTween = nil
		mDownInput = inputObject
		mPanStartHit = getInputHit(inputObject)
		mDownScreenPos = getInputScreenPos(inputObject)
		mPanStartPosition = mCurrentPosition
		mDidPan = false
		mIsPanning = true
	end
	local function button1Up()
		mPanStartHit = nil
		mDownInput = nil
		if mDidPan then
			mInertialVelocity = computeExtraVelocity()
			-- Journey: how far the camera moved and where it ended up (are
			-- they exploring toward the locked/upcoming nodes?)
			local moved = mCurrentPosition - mPanStartPosition
			JourneyRecorder:Record("NetmapPan", string.format("%d studs to %d,%d",
				math.floor(moved.Magnitude), math.floor(mCurrentPosition.X), math.floor(mCurrentPosition.Z)))
			this.Changed:fire()
		elseif mIsPanning then
			this.Clicked:fire(getUnitRay())
		end
		mIsPanning = false
	end
	local function mousePan(inputObject: InputObject?)
		if not mInstalled or ModalManager:IsModal() or mPinching then
			return
		end
		if mPanStartHit then
			if not mDidPan then
				local screenAt = getInputScreenPos(inputObject)
				if (screenAt - mDownScreenPos).Magnitude < DRAG_THRESHOLD_PX then
					return
				end
				mDidPan = true
				-- Re-anchor at the point the drag actually began so the map
				-- doesn't jump by the dead-zone distance
				mPanStartHit = getInputHit(inputObject)
				return
			end
			setPosition(mCurrentPosition - (getInputHit(inputObject) - mPanStartHit))
		end
	end
	
	local function intertialPan(dt)
		mInertialVelocity -= mInertialVelocity * 3.0 * dt
		local factor = 100 * dt
		if factor > mInertialVelocity.Magnitude then
			mInertialVelocity = Vector3.new()
		else
			mInertialVelocity -= mInertialVelocity.Unit * factor
		end
		if mInertialVelocity ~= Vector3.new() then
			setPosition(mCurrentPosition + mInertialVelocity * dt)
		end
	end
	
	UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed then
			-- CoreGui (chat, topbar) or game UI handled this press: never
			-- start a camera gesture underneath it. Gestures already in
			-- flight still see Changed/Ended so they can't get stuck.
			return
		end
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			button1Down(inputObject)
		end
	end)
	UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			if inputObject.UserInputType == Enum.UserInputType.Touch and inputObject ~= mDownInput then
				return -- a non-owning finger lifting doesn't end the gesture
			end
			button1Up()
		end
	end)
	UserInputService.InputChanged:Connect(function(inputObject: InputObject, gameProcessed: boolean)
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			-- Scrolling over UI (e.g. the chat window) must not zoom the map
			if not gameProcessed then
				handleWheel(inputObject.Position.Z)
			end
		elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			-- Movement deliberately NOT gated on gameProcessed: a pan in
			-- flight must keep tracking while the pointer crosses UI
			mousePan(inputObject)
		elseif inputObject.UserInputType == Enum.UserInputType.Touch then
			if inputObject == mDownInput then
				mousePan(inputObject)
			end
		end
	end)
	UserInputService.TouchPinch:Connect(function(_touchPositions, scale, _velocity, state, gameProcessed)
		if not mInstalled or ModalManager:IsModal() then
			return
		end
		if state == Enum.UserInputState.Begin then
			if gameProcessed then
				return
			end
			mPinching = true
			mFocusTween = nil
			mPinchStartZoom = mZoomLevel
			-- The first finger already started a pan/click gesture: cancel it
			mPanStartHit = nil
			mDownInput = nil
			mIsPanning = false
			mDidPan = false
			mInertialVelocity = Vector3.new()
		elseif state == Enum.UserInputState.Change then
			if mPinching then
				mZoomLevel = math.clamp(mPinchStartZoom / scale, MIN_ZOOM, MAX_ZOOM)
				setPosition(mCurrentPosition)
				recordZoomSettled()
			end
		else
			mPinching = false
		end
	end)
	
	function this:GetState()
		return mCurrentPosition, mZoomLevel
	end

	-- Journey playback: set the zoom level directly
	function this:SetZoom(level)
		mZoomLevel = math.clamp(level, MIN_ZOOM, MAX_ZOOM)
		setPosition(mCurrentPosition)
	end

	-- animate: glide there over a moment instead of snapping
	function this:FocusOn(position, animate)
		if animate then
			mInertialVelocity = Vector3.new()
			mFocusTween = {
				Start = mCurrentPosition,
				Target = position,
				T = 0,
				Duration = 0.8,
			}
		else
			mFocusTween = nil
			setPosition(position)
		end
	end
	
	function this:Install()
		mInstalled = true
		-- Discard any motion residue so the camera comes back EXACTLY where
		-- it was: pending focus glides, fling inertia, half-finished gestures
		mFocusTween = nil
		mInertialVelocity = Vector3.new()
		mPanStartHit = nil
		mIsPanning = false
		mDidPan = false
		mPinching = false
		-- Re-assert the camera state: the battle camera changes type/FOV/CFrame
		-- while a databattle is up
		mCamera.CameraType = Enum.CameraType.Scriptable
		mCamera.FieldOfView = kFieldOfView
		setPosition(mCurrentPosition)
		local lastTime = os.clock()
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value - 1, function()
			local thisTime = os.clock()
			local dt = thisTime - lastTime
			lastTime = thisTime
			table.remove(mLastPositions, 1)
			table.insert(mLastPositions, {thisTime, mCurrentPosition})
			if mFocusTween then
				mFocusTween.T = math.min(mFocusTween.T + dt, mFocusTween.Duration)
				local alpha = mFocusTween.T / mFocusTween.Duration
				alpha = alpha * alpha * (3 - 2 * alpha) -- smoothstep
				setPosition(mFocusTween.Start:Lerp(mFocusTween.Target, alpha))
				if mFocusTween and mFocusTween.T >= mFocusTween.Duration then
					mFocusTween = nil
				end
			elseif not mIsPanning then
				intertialPan(dt)
			end
			-- Re-apply every frame so the handover back from the battle camera
			-- takes effect immediately (its last top-down CFrame would
			-- otherwise stick until the next pan). Assert type/FOV too: the
			-- battle camera's teardown restore can land AFTER our Install
			-- (the netmap is shown before the battle view is destroyed), and
			-- a non-Scriptable type lets the default camera controller stomp
			-- our CFrame every frame
			mCamera.CameraType = Enum.CameraType.Scriptable
			mCamera.FieldOfView = kFieldOfView
			applyCamera()
		end)
	end
	
	function this:Uninstall()
		mInstalled = false
		RunService:UnbindFromRenderStep(BIND_NAME)
	end
	
	return this
end

return NetmapCamera
